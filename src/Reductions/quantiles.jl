# Segmented quantiles and their exact inverse: docs/plans/fiddlybits-52v.7-
# kernels.md, section "The reductions", decision 0005 (the 4^k segment) and
# decision 0027 (reference path).

using ..Backends: Backend, CPU, GPU, launch!, bitwise, array_type, on
using ..Verdicts: refuse
using KernelAbstractions: @kernel, @index, @Const, @localmem, @synchronize

"""
    QUANTILE_K_MIN, QUANTILE_K_MAX

The declared range of the hierarchy depth `k` `segmented_quantile` accepts:
a segment holds `4^k` elements. `QUANTILE_K_MIN` is `1`, one step of
decision 0005's four-way fan-out below the trivial single-cell segment
(`k = 0`, where every quantile is that one element and no sort runs).
`QUANTILE_K_MAX` is `5`, decision 0005's own stated ceiling: "a bitonic
sort fits a segment of up to 1024 for quantiles", `4^5 = 1024`.
"""
const QUANTILE_K_MIN = 1
const QUANTILE_K_MAX = 5

"""
    at_workgroup(backend, workgroup)

`backend` with its KernelAbstractions workgroup size replaced by
`workgroup`, keeping its kind (`CPU` or `GPU`) and its `bitwise` flag.
"""
at_workgroup(backend::CPU, workgroup::Integer) = CPU(workgroup; bitwise = bitwise(backend))
at_workgroup(backend::GPU, workgroup::Integer) = GPU(workgroup; bitwise = bitwise(backend))

"""
    segment_depth_host(starts_host, nseg)

`segment_depth`'s check, given `starts` already on the host.
"""
function segment_depth_host(starts_host::AbstractVector{<:Integer}, nseg::Integer)
    seglen = starts_host[2] - starts_host[1]
    for s in 1:nseg
        starts_host[s+1] - starts_host[s] == seglen ||
            refuse("quantile segment depth", "Reductions.segment_depth",
                   "segment $s has length $(starts_host[s+1] - starts_host[s]), " *
                   "segment 1 has length $seglen; segmented_quantile requires every " *
                   "segment to have the same length")
    end
    ispow2(seglen) ||
        refuse("quantile segment depth", "Reductions.segment_depth",
               "segment length $seglen is not a power of two")
    e = trailing_zeros(seglen)
    iseven(e) ||
        refuse("quantile segment depth", "Reductions.segment_depth",
               "segment length $seglen is not a power of four")
    k = e ÷ 2
    QUANTILE_K_MIN <= k <= QUANTILE_K_MAX ||
        refuse("quantile segment depth", "Reductions.segment_depth",
               "segment length $seglen is depth k=$k, outside the declared range " *
               "$QUANTILE_K_MIN:$QUANTILE_K_MAX")
    return k
end

"""
    segment_depth(starts, nseg)

The hierarchy depth `k` (`QUANTILE_K_MIN` to `QUANTILE_K_MAX`) such that
every one of the `nseg` segments `starts` describes (`segment_extent`) has
length `4^k`. `starts` is read element by element for this check, so it is
copied to the host first when it is not already there (a boundary array,
not the reduced data, so the copy is cheap). Refuses when the segments are
not all the same length, when that length is not a power of four, or when
its `k` falls outside the declared range.
"""
function segment_depth(starts::AbstractVector{<:Integer}, nseg::Integer)
    return segment_depth_host(starts_on_host(starts), nseg)
end

"""
    quantile_rank(n, q)

The 1-based index `segmented_quantile` reads from a segment of `n`
elements sorted ascending, at probability `q`: `clamp(ceil(Int, q * n), 1,
n)`. This always names one element of the data and never a value between
two of them. Refuses when `n` is not positive or `q` is outside `[0, 1]`.
"""
function quantile_rank(n::Integer, q::Real)
    n > 0 ||
        refuse("quantile rank", "Reductions.quantile_rank", "n=$n is not positive")
    0 <= q <= 1 ||
        refuse("quantile rank", "Reductions.quantile_rank", "q=$q is outside [0, 1]")
    return clamp(ceil(Int, q * n), 1, n)
end

"""
    bitonic_network_pow2(n)

`(partner, ascending)` for a bitonic sort of `n` elements, where `n` is
a power of two. Builds the network for a power-of-two `n` without checking it.
"""
function bitonic_network_pow2(n::Integer)
    nbits = trailing_zeros(n)
    steps = Tuple{Int,Int}[]
    for stage in 1:nbits, pass in stage:-1:1
        push!(steps, (stage, pass))
    end
    nsteps = length(steps)
    partner = Matrix{Int}(undef, n, nsteps)
    ascending = falses(n, nsteps)
    for (col, (stage, pass)) in enumerate(steps)
        kk = 1 << stage
        distance = 1 << (pass - 1)
        for pos in 1:n
            zero_based = pos - 1
            mate = xor(zero_based, distance)
            partner[pos, col] = mate + 1
            ascending[pos, col] = (zero_based & kk) == 0
        end
    end
    return partner, ascending
end

"""
    bitonic_network(n)

`(partner, ascending)` for a bitonic sort of `n` (`ispow2(n)`) elements,
each 1-based, `n` by `nsteps`, one column per step of the standard
iterative bitonic network (stage in `1:log2(n)`, pass in `stage:-1:1`).
Column `step`: `partner[pos, step]` is the 1-based position `pos` compares
against, and `ascending[pos, step]` is whether `pos` sorts its pair
ascending, both at that step. Computed once at the host boundary so a
bitonic-sort kernel reads its own comparisons by position with no
arithmetic on the position at all (decision F7): the kernel binds its
local position through `@index` and only ever indexes `partner` and
`ascending` with it, never offsets it.
"""
function bitonic_network(n::Integer)
    ispow2(n) ||
        refuse("bitonic network size", "Reductions.bitonic_network",
               "n=$n is not a power of two")
    return bitonic_network_pow2(n)
end

"""
    QUANTILE_BITONIC_NETWORK

`k => bitonic_network_pow2(4^k)` for every `k` in `QUANTILE_K_MIN:
QUANTILE_K_MAX`, computed once at module load.
"""
const QUANTILE_BITONIC_NETWORK = Dict(k => bitonic_network_pow2(4^k) for k in QUANTILE_K_MIN:QUANTILE_K_MAX)

# One bitonic-sort kernel per declared k, generated with its segment length
# and its step count as literal constants so @localmem's size is fixed at
# compile time. Each kernel sorts its own segment in workgroup shared
# memory (one workgroup per segment) and writes back a single selected
# element; xs itself is left unchanged. base[seg] is the segment's own
# start minus one, computed at the host boundary, so adding the kernel's
# own local position to it is not an offset of that position (decision
# F7); the bitonic comparisons come from bitonic_network the same way.
for k in QUANTILE_K_MIN:QUANTILE_K_MAX
    local seglen = 4^k
    local nsteps = size(QUANTILE_BITONIC_NETWORK[k][1], 2)
    local kernel_name = Symbol(:segmented_bitonic_kernel_, seglen, :!)
    @eval @kernel function $kernel_name(out, @Const(xs), @Const(base), rank,
                                         @Const(partner), @Const(ascending))
        seg = @index(Group, Linear)
        li = @index(Local, Linear)
        shared = @localmem eltype(xs) ($seglen,)
        shared[li] = xs[base[seg] + li]
        @synchronize
        for step in 1:$nsteps
            p = partner[li, step]
            if p > li
                a = shared[li]
                b = shared[p]
                swap = ascending[li, step] ? (a > b) : (a < b)
                if swap
                    shared[li] = b
                    shared[p] = a
                end
            end
            @synchronize
        end
        if li == 1
            out[seg] = shared[rank]
        end
    end
end

"""
    quantile_kernel(::Val{k})

The bitonic-sort kernel generated for segment length `4^k`, `k` in
`QUANTILE_K_MIN:QUANTILE_K_MAX`.
"""
function quantile_kernel end

for k in QUANTILE_K_MIN:QUANTILE_K_MAX
    local seglen = 4^k
    local kernel_name = Symbol(:segmented_bitonic_kernel_, seglen, :!)
    @eval quantile_kernel(::Val{$k}) = $kernel_name
end

"""
    QUANTILE_BITONIC_NETWORK_DEVICE

A module-level, process-lifetime cache: `(array_type(backend), k) =>
(partner, ascending)` on that array type, for every `(array_type(backend),
k)` `device_bitonic_network` has built so far. Keyed on the array type and
`k` alone, never on a `backend` value, because the copy depends on neither
the workgroup size nor the `bitwise` flag. `QUANTILE_BITONIC_NETWORK[k]` is
a constant of `k` alone, so its copy on a given array type is built once
here and reused by every later call at that array type and `k`, rather
than rebuilt and re-copied to the device on every call. Entries are never
evicted: the key space is `QUANTILE_K_MIN:QUANTILE_K_MAX` crossed with the
array types the process actually runs on, both small and fixed.
"""
const QUANTILE_BITONIC_NETWORK_DEVICE = Dict{Tuple{Type,Int},Any}()

"""
    QUANTILE_BITONIC_NETWORK_DEVICE_LOCK

Guards `QUANTILE_BITONIC_NETWORK_DEVICE` against two calls populating the
same key at once.
"""
const QUANTILE_BITONIC_NETWORK_DEVICE_LOCK = ReentrantLock()

"""
    device_bitonic_network(backend, k)

`(partner, ascending)` from `QUANTILE_BITONIC_NETWORK[k]`, copied to
`array_type(backend)` the first time this array type and `k` are asked
for and cached in `QUANTILE_BITONIC_NETWORK_DEVICE` under
`(array_type(backend), k)` for every later call.

The copy does not go through `Backends.on` and records no `Events.moved`:
docs/decisions/0047-a-kernels-own-constant-table-is-not-a-device-move.md.
"""
function device_bitonic_network(backend::Backend, k::Integer)
    AT = array_type(backend)
    key = (AT, Int(k))
    return lock(QUANTILE_BITONIC_NETWORK_DEVICE_LOCK) do
        get!(QUANTILE_BITONIC_NETWORK_DEVICE, key) do
            partner, ascending = QUANTILE_BITONIC_NETWORK[k]
            (AT(partner), AT(ascending))
        end
    end
end

"""
    segmented_quantile(xs, starts, q, backend = CPU(BLOCKSIZE))
    segmented_quantile(xs, segmentation, q, backend = CPU(BLOCKSIZE))

The `q`-quantile of each segment `starts` describes (`segment_extent`),
selected rather than interpolated: every segment is sorted by a bitonic
network run in one workgroup's shared memory, and the element at
`quantile_rank(segment length, q)` of the sorted segment is read back,
unchanged in type and value from whatever `xs` held at that rank. `xs` is
never reordered. Every segment must share one length, `4^k` for a `k` in
`QUANTILE_K_MIN:QUANTILE_K_MAX` (`segment_depth`); a segment is a coarse
cell's `4^k` descendants at depth `k` (decision 0005). `xs` and `starts`
must already live on `backend`; the workgroup size `backend` carries is
replaced with the segment length regardless of what was passed in
(`at_workgroup`), because the sort's barriers apply across exactly one
workgroup.

The `Segmentation` form takes the boundaries already checked and refuses
when `xs` does not have the length they were checked against. A
`Segmentation` carries no depth: `segment_depth` runs on every call over
the host boundaries it holds, which is host work and no device-to-host
copy.
"""
function segmented_quantile(xs::AbstractVector, segmentation::Segmentation, q::Real,
                             backend::Backend = CPU(BLOCKSIZE))
    require_extent(segmentation, xs, "Reductions.segmented_quantile")
    nseg = segmentation.nseg
    out = similar(xs, nseg)
    nseg == 0 && return out
    k = segment_depth_host(segmentation.starts_host, nseg)
    seglen = 4^k
    rank = quantile_rank(seglen, q)
    base = segmentation.lo .- 1
    partner, ascending = device_bitonic_network(backend, k)
    kernel = quantile_kernel(Val(k))
    launch!(kernel, at_workgroup(backend, seglen), nseg * seglen,
            out, xs, base, rank, partner, ascending)
    return out
end

function segmented_quantile(xs::AbstractVector, starts::AbstractVector{<:Integer}, q::Real,
                             backend::Backend = CPU(BLOCKSIZE))
    return segmented_quantile(xs, Segmentation(xs, starts), q, backend)
end

"""
    segmented_quantile_reference(xs, starts, q)
    segmented_quantile_reference(xs, segmentation, q)

The naive serial reference for `segmented_quantile` (decision 0027): each
segment's slice sorted by `Base.sort` and the element at `quantile_rank`
read out, one segment after another. `xs` and `starts` must be host
arrays. The `Segmentation` form reads the boundaries it holds and checks
them again here.
"""
function segmented_quantile_reference(xs::AbstractVector, starts::AbstractVector{<:Integer}, q::Real)
    nseg = segment_extent(xs, starts)
    out = Vector{eltype(xs)}(undef, nseg)
    for s in 1:nseg
        slice = sort(xs[starts[s]:starts[s+1]-1])
        out[s] = slice[quantile_rank(length(slice), q)]
    end
    return out
end

function segmented_quantile_reference(xs::AbstractVector, segmentation::Segmentation, q::Real)
    require_extent(segmentation, xs, "Reductions.segmented_quantile_reference")
    return segmented_quantile_reference(xs, segmentation.starts_host, q)
end

@kernel function area_weighted_block_kernel!(partials, @Const(xs), @Const(areas), x, blocksize, n)
    i = @index(Global)
    base = blocksize * i
    lo = base - blocksize + 1
    hi = min(i * blocksize, n)
    T = eltype(partials)
    acc = zero(T)
    for j in lo:hi
        acc += T(ifelse(xs[j] >= x, areas[j], zero(eltype(areas))))
    end
    partials[i] = acc
end

@kernel function area_weighted_block_shared_kernel!(partials, @Const(xs), @Const(areas), x,
                                                     width, nb, lastcount)
    block = @index(Group, Linear)
    lane = @index(Local, Linear)
    element = @index(Global, Linear)
    shared = @localmem eltype(areas) (block_width(width),)
    shared[lane] = ifelse(xs[element] >= x, areas[element], zero(eltype(areas)))
    @synchronize
    if lane == 1
        T = eltype(partials)
        acc = zero(T)
        for j in 1:(block == nb ? lastcount : block_width(width))
            acc += T(shared[j])
        end
        partials[block] = acc
    end
end

"""
    area_weighted_sum(::Type{A}, xs, areas, x, backend = CPU(BLOCKSIZE); blocksize = BLOCKSIZE) where A

The fixed-order sum, accumulated in type `A`, of `areas` at the indices
where `xs` is at or above `x`, and zero elsewhere: the same blocked,
fixed-order pass `pairwise_block_sums` walks, with the indicator selected
and folded into the block accumulation instead of read from a
materialised array the size of `xs`. `Reductions.segmented_weighted_sum`'s
sibling for this rule: a reduction allocates no temporary the size of its
input. `ifelse` is a select, not a multiply feeding an add, so no fusion
barrier is needed to keep this the same two-step rounding (the select,
then the `T(...)` conversion the block sum's add reads) a materialised
`ifelse.(xs .>= x, areas, zero(eltype(areas)))` array followed by a plain
summation kernel produced before this fusion. `xs` and `areas` must
already live on `backend`; the block sums are combined on the host through
`combine_fixed_order`, the same door `pairwise_sum` uses. Refuses when
`blocksize` is not positive or when `xs` and `areas` differ in length.
"""
area_weighted_sum(::Type{A}, xs::AbstractVector, areas::AbstractVector, x::Real,
                   backend::Backend = CPU(BLOCKSIZE);
                   blocksize::Integer = BLOCKSIZE) where {A<:Number} =
    combine_fixed_order(on(area_weighted_block_sums(A, xs, areas, x, backend;
                                                     blocksize = blocksize), CPU(1)))

"""
    area_weighted_block_sums(::Type{A}, xs, areas, x, backend = CPU(BLOCKSIZE); blocksize = BLOCKSIZE) where A

`area_weighted_sum`'s block sums before they are combined: block `i` the
fixed-order sum, accumulated in type `A`, of `areas` over that block's
indices where `xs` is at or above `x` and zero elsewhere, left on
`backend`, launched by `launch_block_sums!` as `pairwise_block_sums` is: on
`GPU` each lane copies its selected area into the workgroup's shared
memory, so the select happens in the copy and the accumulation reads one
array. `pairwise_block_sums`' sibling, and the door `area_fraction_above`
reads when it moves two block-sum arrays to the host together. Refuses
when `blocksize` is not positive or when `xs` and `areas` differ in length.
"""
function area_weighted_block_sums(::Type{A}, xs::AbstractVector, areas::AbstractVector, x::Real,
                                   backend::Backend = CPU(BLOCKSIZE);
                                   blocksize::Integer = BLOCKSIZE) where {A<:Number}
    blocksize > 0 ||
        refuse("pairwise blocksize", "Reductions.area_weighted_block_sums",
               "blocksize $blocksize is not positive")
    n = length(xs)
    n == length(areas) ||
        refuse("area weighted extent", "Reductions.area_weighted_block_sums",
               "xs has length $n, areas has length $(length(areas))")
    nb = cld(n, blocksize)
    partials = similar(areas, A, nb)
    nb == 0 && return partials
    return launch_block_sums!(area_weighted_block_kernel!, area_weighted_block_shared_kernel!,
                              backend, partials, n, blocksize, xs, areas, x)
end

"""
    area_fraction_above(xs, areas, x, backend = CPU(BLOCKSIZE))

The area-weighted fraction of `xs` at or above `x`: the fixed-order sum
(`area_weighted_sum`) of `areas` where `xs .>= x`, divided by the
fixed-order sum of `areas` (`pairwise_sum`). Neither call materialises an
array the size of `xs` (`area_weighted_sum`'s own docstring states the
rule this follows). The exact inverse of `segmented_quantile` rather than
an interpolation of it: it reads back a fraction from a value with no rule
of its own about what lies between two data points, so calling it on the
value `segmented_quantile` selected counts that element itself as being at
or above the threshold, while calling it on any value absent from the data
(an interpolated value, among others) does not. `xs` and `areas` must have
the same length and must already live on `backend`. Refuses when they
differ in length, or when the total area is not positive.

The return is a host scalar, and the two block-sum arrays are joined on
`backend` and read back in one move, so on device-resident input this is one
`Events.moved` record per call and one completion, not one of each per sum.
Each half is combined on its own afterwards, over the same block sums and by
the same tree, whose shape `combine_tree` takes from the half's length
alone. The two forms and their cost are in
notes/findings/2026-09-11-area-fraction-in-one-read.md.
"""
function area_fraction_above(xs::AbstractVector, areas::AbstractVector, x::Real,
                              backend::Backend = CPU(BLOCKSIZE))
    length(xs) == length(areas) ||
        refuse("area fraction extent", "Reductions.area_fraction_above",
               "xs has length $(length(xs)), areas has length $(length(areas))")
    total_blocks = pairwise_block_sums(Float64, areas, backend)
    weighted_blocks = area_weighted_block_sums(Float64, xs, areas, x, backend)
    nb = length(total_blocks)
    both = on(vcat(total_blocks, weighted_blocks), CPU(1))
    total = combine_fixed_order(view(both, 1:nb))
    weighted = combine_fixed_order(view(both, nb+1:lastindex(both)))
    total > 0 ||
        refuse("area fraction total", "Reductions.area_fraction_above",
               "total area $total is not positive")
    return weighted / total
end

"""
    area_fraction_above_reference(xs, areas, x)

The naive serial reference for `area_fraction_above` (decision 0027):
`areas` and the `areas` of entries with `xs` at or above `x` each
accumulated in `Float64`, one term at a time in index order, then divided.
`xs` and `areas` must be host arrays. Refuses when they differ in length,
or when the total area is not positive.
"""
function area_fraction_above_reference(xs::AbstractVector, areas::AbstractVector, x::Real)
    length(xs) == length(areas) ||
        refuse("area fraction extent", "Reductions.area_fraction_above_reference",
               "xs has length $(length(xs)), areas has length $(length(areas))")
    total = zero(Float64)
    weighted = zero(Float64)
    for i in eachindex(xs, areas)
        a = Float64(areas[i])
        total += a
        xs[i] >= x && (weighted += a)
    end
    total > 0 ||
        refuse("area fraction total", "Reductions.area_fraction_above_reference",
               "total area $total is not positive")
    return weighted / total
end
