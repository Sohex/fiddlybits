# Segmented quantiles and their exact inverse: docs/plans/fiddlybits-52v.7-
# kernels.md, section "The reductions", decision 0005 (the 4^k segment) and
# decision 0027 (reference path).

using ..Backends: Backend, CPU, GPU, launch!, at_workgroup, array_type, on
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
# compile time. Each kernel sorts one segment of one column of the
# (elements, columns) array xs in workgroup shared memory (one workgroup per
# segment and column, workgroup g being column fld1(g, nseg) and segment
# mod1(g, nseg)) and writes back a single selected element to
# out[seg, column]; xs itself is left unchanged. base[seg] is the segment's
# own start minus one, computed at the host boundary, and the kernel adds
# its own local position to it; the bitonic comparisons come from
# bitonic_network, indexed by that local position.
for k in QUANTILE_K_MIN:QUANTILE_K_MAX
    local seglen = 4^k
    local nsteps = size(QUANTILE_BITONIC_NETWORK[k][1], 2)
    local kernel_name = Symbol(:segmented_bitonic_kernel_, seglen, :!)
    @eval @kernel function $kernel_name(out, @Const(xs), @Const(base), rank,
                                         @Const(partner), @Const(ascending), nseg)
        group = @index(Group, Linear)
        column = fld1(group, nseg)
        seg = mod1(group, nseg)
        li = @index(Local, Linear)
        shared = @localmem eltype(xs) ($seglen,)
        @inbounds shared[li] = xs[base[seg] + li, column]
        @synchronize
        for step in 1:$nsteps
            @inbounds begin
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
            end
            @synchronize
        end
        if li == 1
            selected_column = fld1(group, nseg)
            selected_seg = mod1(group, nseg)
            @inbounds out[selected_seg, selected_column] = shared[rank]
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
    segmented_quantile(xs, starts, q, backend = CPU())
    segmented_quantile(xs, segmentation, q, backend = CPU())

The `q`-quantile of each segment `starts` describes (`segment_extent`),
selected rather than interpolated: every segment is sorted by a bitonic
network run in one workgroup's shared memory, and the element at
`quantile_rank(segment length, q)` of the sorted segment is read back,
unchanged in type and value from whatever `xs` held at that rank. `xs` is
never reordered. Every segment must share one length, `4^k` for a `k` in
`QUANTILE_K_MIN:QUANTILE_K_MAX` (`segment_depth`); a segment is a coarse
cell's `4^k` descendants at depth `k` (decision 0005). `xs` and `starts`
must already live on `backend`; the launch is pinned to the segment length
(`Backends.at_workgroup`) whatever `backend` carries, because the sort's
barriers apply across exactly one workgroup.

The `Segmentation` form takes the boundaries already checked and refuses
when `xs` does not have the length they were checked against. A
`Segmentation` carries no depth: `segment_depth` runs on every call over
the host boundaries it holds, which is host work and no device-to-host
copy.
"""
function segmented_quantile(xs::AbstractVector, segmentation::Segmentation, q::Real,
                             backend::Backend = CPU())
    require_extent(segmentation, xs, "Reductions.segmented_quantile")
    out = similar(xs, segmentation.nseg)
    segmentation.nseg == 0 && return out
    queue_quantiles!(by_columns(out), by_columns(xs), segmentation, q, backend)
    return out
end

"""
    queue_quantiles!(out, xs, segmentation, q, backend)

The launch both forms of `segmented_quantile` make, once their shapes are
checked: `out` is `(nseg, ncol)` and `xs` is `(nelement, ncol)`, `nseg` at
least one. Reads the segment depth from `segmentation`'s host boundaries,
then queues `launch_quantiles!` once over every segment of every column.
"""
function queue_quantiles!(out::AbstractMatrix, xs::AbstractMatrix, segmentation::Segmentation,
                          q::Real, backend::Backend)
    nseg = segmentation.nseg
    k = segment_depth_host(segmentation.starts_host, nseg)
    rank = quantile_rank(4^k, q)
    base = segmentation.lo .- 1
    partner, ascending = device_bitonic_network(backend, k)
    launch_quantiles!(backend, k, nseg, out, xs, base, rank, partner, ascending)
    return nothing
end

"""
    launch_quantiles!(backend, k, nseg, out, xs, base, rank, partner, ascending)

Queues `quantile_kernel(Val(k))` on `backend` over `nseg` segments of `4^k`
elements in each of the `ncol = size(xs, 2)` columns of the
`(elements, columns)` array `xs`, one workgroup per segment and column
(`Backends.at_workgroup`), `nseg * ncol` of them: workgroup `g` is column
`c = fld1(g, nseg)` and segment `s = mod1(g, nseg)`, which sorts
`xs[base[s] + 1:base[s] + 4^k, c]` by the network `partner` and `ascending`
and writes the element at `rank` to `out[s, c]`.

Before the launch, on the host, refuses through `Verdicts.refuse`, naming
the array and both shapes, unless `k` is in
`QUANTILE_K_MIN:QUANTILE_K_MAX`, `base` holds `nseg` elements, `xs` has
size `(nseg * 4^k, ncol)`, `out` has size `(nseg, ncol)`, `partner` and
`ascending` are each `4^k` by the step count of
`QUANTILE_BITONIC_NETWORK[k]`, and `rank` is in `1:4^k`: the extents every
index the kernel reads or writes is derived from. The values of `base` are
`lo .- 1` of a `Segmentation` whose segments all have length `4^k`.
"""
function launch_quantiles!(backend::Backend, k::Integer, nseg::Integer, out::AbstractArray,
                            xs::AbstractArray, base::AbstractVector{<:Integer}, rank::Integer,
                            partner::AbstractMatrix, ascending::AbstractMatrix)
    site = "Reductions.launch_quantiles!"
    QUANTILE_K_MIN <= k <= QUANTILE_K_MAX ||
        refuse("quantile segment depth", site,
               "k=$k is outside the declared range $QUANTILE_K_MIN:$QUANTILE_K_MAX")
    seglen = 4^k
    shape = (seglen, size(QUANTILE_BITONIC_NETWORK[k][1], 2))
    length(base) == nseg ||
        refuse("quantile kernel extent", site,
               "base has length $(length(base)), $nseg segments of $seglen need $nseg")
    ndims(xs) == 2 ||
        refuse("quantile kernel extent", site, "xs has size $(size(xs)), not (elements, columns)")
    ncol = size(xs, 2)
    for (name, array, expected) in (("xs", xs, (nseg * seglen, ncol)), ("out", out, (nseg, ncol)))
        size(array) == expected ||
            refuse("quantile kernel extent", site,
                   "$name has size $(size(array)), $nseg segments of $seglen in $ncol " *
                   "column(s) need $expected")
    end
    for (name, array) in (("partner", partner), ("ascending", ascending))
        size(array) == shape ||
            refuse("quantile kernel extent", site,
                   "$name has size $(size(array)), the network at k=$k has size $shape")
    end
    1 <= rank <= seglen ||
        refuse("quantile rank", site, "rank $rank is outside 1:$seglen")
    ncol == 0 && return nothing
    launch!(quantile_kernel(Val(Int(k))), at_workgroup(backend, seglen), nseg * ncol * seglen,
            out, xs, base, Int(rank), partner, ascending, Int(nseg))
    return nothing
end

function segmented_quantile(xs::AbstractVector, starts::AbstractVector{<:Integer}, q::Real,
                             backend::Backend = CPU())
    return segmented_quantile(xs, Segmentation(xs, starts), q, backend)
end

"""
    segmented_quantile(xs::AbstractArray, starts, q, backend = CPU())
    segmented_quantile(xs::AbstractArray, segmentation, q, backend = CPU())

The column form of `segmented_quantile`: `xs` is an array of cells by
trailing axes (`Backends.LAYOUT`), and the result, on `backend`, has size
`(nseg, trailing...)` and `xs`'s element type, its column `c` the vector
form's quantile of `xs`'s column `c`, the same element selected by the same
network. One launch over every segment of every column, one workgroup per
segment and column (`launch_quantiles!`); nothing is read back from the
device. The segmentation is checked against `size(xs, 1)`. Refuses when `xs`
has fewer than two dimensions, and as the vector form does.
"""
function segmented_quantile(xs::AbstractArray, segmentation::Segmentation, q::Real,
                             backend::Backend = CPU())
    site = "Reductions.segmented_quantile"
    require_columns(xs, site)
    require_extent(segmentation, xs, site)
    out = similar(xs, segmentation.nseg, trailing_shape(xs)...)
    (segmentation.nseg == 0 || column_extent(xs) == 0) && return out
    queue_quantiles!(by_columns(out), by_columns(xs), segmentation, q, backend)
    return out
end

function segmented_quantile(xs::AbstractArray, starts::AbstractVector{<:Integer}, q::Real,
                             backend::Backend = CPU())
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

"""
    segmented_quantile_reference(xs::AbstractArray, starts, q)
    segmented_quantile_reference(xs::AbstractArray, segmentation, q)

The naive serial reference for the column form of `segmented_quantile`
(decision 0027): the vector reference over each column of `xs` in turn, in
column-major order of the trailing axes, into an array of size
`(nseg, trailing...)` and `xs`'s element type. `xs` must be a host array.
"""
function segmented_quantile_reference(xs::AbstractArray, starts::AbstractVector{<:Integer}, q::Real)
    require_columns(xs, "Reductions.segmented_quantile_reference")
    out = Array{eltype(xs)}(undef, segment_extent(xs, starts), trailing_shape(xs)...)
    for column in CartesianIndices(trailing_shape(xs))
        out[:, column] = segmented_quantile_reference(view(xs, :, column), starts, q)
    end
    return out
end

function segmented_quantile_reference(xs::AbstractArray, segmentation::Segmentation, q::Real)
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
    @inbounds for j in lo:hi
        acc += T(ifelse(xs[j] >= x, areas[j], zero(eltype(areas))))
    end
    @inbounds partials[i] = acc
end

@kernel function area_weighted_block_shared_kernel!(partials, @Const(xs), @Const(areas), x,
                                                     width, nb, lastcount)
    block = @index(Group, Linear)
    lane = @index(Local, Linear)
    element = @index(Global, Linear)
    shared = @localmem eltype(areas) (block_width(width),)
    @inbounds shared[lane] = ifelse(xs[element] >= x, areas[element], zero(eltype(areas)))
    @synchronize
    if lane == 1
        T = eltype(partials)
        acc = zero(T)
        @inbounds for j in 1:(block == nb ? lastcount : block_width(width))
            acc += T(shared[j])
        end
        @inbounds partials[block] = acc
    end
end

"""
    AREA_WEIGHTED_DEVICE_FORM_MAX

The largest element count `launch_block_sums!` launches
`area_weighted_block_shared_kernel!` over on `GPU`; above it the portable
`area_weighted_block_kernel!` runs there instead. The largest count at which
notes/findings/2026-09-13-the-launch-workgroup-is-set-by-blocks-at-once-and-the-warp.md
measured the device form faster than the portable text on the card, at
`BLOCKSIZE` and the portable text at `Backends.launch_workgroup`.
"""
const AREA_WEIGHTED_DEVICE_FORM_MAX = 184320

device_form_limit(::typeof(area_weighted_block_shared_kernel!)) = AREA_WEIGHTED_DEVICE_FORM_MAX

"""
    area_weighted_sum(::Type{A}, xs, areas, x, backend = CPU(); blocksize = BLOCKSIZE) where A

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
                   backend::Backend = CPU();
                   blocksize::Integer = BLOCKSIZE) where {A<:Number} =
    combine_fixed_order(on(area_weighted_block_sums(A, xs, areas, x, backend;
                                                     blocksize = blocksize), CPU(1)))

"""
    area_weighted_block_sums(::Type{A}, xs, areas, x, backend = CPU(); blocksize = BLOCKSIZE) where A

`area_weighted_sum`'s block sums before they are combined: block `i` the
fixed-order sum, accumulated in type `A`, of `areas` over that block's
indices where `xs` is at or above `x` and zero elsewhere, left on
`backend`, launched by `launch_block_sums!` as `pairwise_block_sums` is: on
`GPU` each lane copies its selected area into the workgroup's shared
memory, so the select happens in the copy and the accumulation reads one
array. `pairwise_block_sums`' sibling; `area_fraction_above` uses its own
fused door, `area_fraction_block_sums`, rather than this one, so it reads
`areas` once instead of once per column. Refuses when `blocksize` is not
positive or when `xs` and `areas` differ in length.
"""
function area_weighted_block_sums(::Type{A}, xs::AbstractVector, areas::AbstractVector, x::Real,
                                   backend::Backend = CPU();
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
                              backend, partials, n, blocksize, 1, (xs = xs, areas = areas, x = x))
end

@kernel function area_fraction_block_kernel!(partials, @Const(xs), @Const(areas), x, blocksize, n)
    i = @index(Global)
    base = blocksize * i
    lo = base - blocksize + 1
    hi = min(i * blocksize, n)
    T = eltype(partials)
    total = zero(T)
    above = zero(T)
    @inbounds for j in lo:hi
        total += T(areas[j])
        above += T(ifelse(xs[j] >= x, areas[j], zero(eltype(areas))))
    end
    @inbounds partials[i, 1] = total
    @inbounds partials[i, 2] = above
end

@kernel function area_fraction_block_shared_kernel!(partials, @Const(xs), @Const(areas), x,
                                                     width, nb, lastcount)
    block = @index(Group, Linear)
    lane = @index(Local, Linear)
    element = @index(Global, Linear)
    shared_total = @localmem eltype(areas) (block_width(width),)
    shared_above = @localmem eltype(areas) (block_width(width),)
    @inbounds shared_total[lane] = areas[element]
    @inbounds shared_above[lane] = ifelse(xs[element] >= x, areas[element], zero(eltype(areas)))
    @synchronize
    if lane == 1
        T = eltype(partials)
        total = zero(T)
        above = zero(T)
        @inbounds for j in 1:(block == nb ? lastcount : block_width(width))
            total += T(shared_total[j])
            above += T(shared_above[j])
        end
        @inbounds partials[block, 1] = total
        @inbounds partials[block, 2] = above
    end
end

"""
    AREA_FRACTION_DEVICE_FORM_MAX

The largest element count `launch_block_sums!` launches
`area_fraction_block_shared_kernel!` over on `GPU`; above it the portable
`area_fraction_block_kernel!` runs there instead. The largest count at which
notes/findings/2026-09-13-the-launch-workgroup-is-set-by-blocks-at-once-and-the-warp.md
measured the device form faster than the portable text on the card, at
`BLOCKSIZE` and the portable text at `Backends.launch_workgroup`.
"""
const AREA_FRACTION_DEVICE_FORM_MAX = 81920

device_form_limit(::typeof(area_fraction_block_shared_kernel!)) = AREA_FRACTION_DEVICE_FORM_MAX

"""
    area_fraction_block_sums(::Type{A}, xs, areas, x, backend = CPU(); blocksize = BLOCKSIZE) where A

`area_fraction_above`'s block sums before they are combined: block `i`'s
row holds, in column 1, the fixed-order sum accumulated in type `A` of
`areas` over that block's indices (`pairwise_block_kernel!`'s own
accumulator expression and order, read here from `areas`), and in column 2
the fixed-order sum, same type, of `areas` where `xs` is at or above `x`
and zero elsewhere (`area_weighted_block_kernel!`'s own accumulator
expression and order). One kernel walks each block's indices once, so
`areas` is read from the device once per element rather than once per
column. Left on `backend`, launched by `launch_block_sums!` as
`pairwise_block_sums` is: on `GPU` each lane copies its own element of
`areas` into one workgroup-shared array and its selected element into a
second, so the select happens in the copy and each column's accumulation
reads its own shared array. Refuses when `blocksize` is not positive or
when `xs` and `areas` differ in length.
"""
function area_fraction_block_sums(::Type{A}, xs::AbstractVector, areas::AbstractVector, x::Real,
                                   backend::Backend = CPU();
                                   blocksize::Integer = BLOCKSIZE) where {A<:Number}
    blocksize > 0 ||
        refuse("pairwise blocksize", "Reductions.area_fraction_block_sums",
               "blocksize $blocksize is not positive")
    n = length(xs)
    n == length(areas) ||
        refuse("area fraction extent", "Reductions.area_fraction_block_sums",
               "xs has length $n, areas has length $(length(areas))")
    nb = cld(n, blocksize)
    partials = similar(areas, A, nb, 2)
    nb == 0 && return partials
    return launch_block_sums!(area_fraction_block_kernel!, area_fraction_block_shared_kernel!,
                              backend, partials, n, blocksize, 2, (xs = xs, areas = areas, x = x))
end

"""
    area_fraction_above(xs, areas, x, backend = CPU())

The area-weighted fraction of `xs` at or above `x`: the fixed-order sum of
`areas` where `xs .>= x`, divided by the fixed-order sum of `areas`, from
one pass over each block's indices (`area_fraction_block_sums`) that reads
`areas` once and launches one kernel rather than two. Neither column
materialises an array the size of `xs`. The exact inverse of
`segmented_quantile` rather than an interpolation of it: it reads back a
fraction from a value with no rule of its own about what lies between two
data points, so calling it on the value `segmented_quantile` selected
counts that element itself as being at or above the threshold, while
calling it on any value absent from the data (an interpolated value, among
others) does not. `xs` and `areas` must have the same length and must
already live on `backend`. Refuses when they differ in length, or when the
total area is not positive.

The return is a host scalar, and the block-sum matrix is read back in one
move, so on device-resident input this is one `Events.moved` record per
call and one completion. Each column is combined on its own afterwards, by
the same tree `combine_tree` builds from the column's length alone. The two
forms and their cost are in notes/findings/2026-09-11-area-fraction-in-one-
read.md; the fused kernel and its cost are in
notes/findings/2026-09-13-area-fraction-above-fused-block-sums.md.
"""
function area_fraction_above(xs::AbstractVector, areas::AbstractVector, x::Real,
                              backend::Backend = CPU())
    length(xs) == length(areas) ||
        refuse("area fraction extent", "Reductions.area_fraction_above",
               "xs has length $(length(xs)), areas has length $(length(areas))")
    blocks = on(area_fraction_block_sums(Float64, xs, areas, x, backend), CPU(1))
    total = combine_fixed_order(view(blocks, :, 1))
    weighted = combine_fixed_order(view(blocks, :, 2))
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
