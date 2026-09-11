# Segmented quantiles and their exact inverse: docs/plans/fiddlybits-52v.7-
# kernels.md, section "The reductions", decision 0005 (the 4^k segment) and
# decision 0027 (reference path).

using ..Backends: Backend, CPU, GPU, launch!, bitwise, array_type
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
    starts_host = starts isa Array ? starts : Array(starts)
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
    QUANTILE_BITONIC_NETWORK

`k => bitonic_network(4^k)` for every `k` in `QUANTILE_K_MIN:
QUANTILE_K_MAX`, computed once at module load.
"""
const QUANTILE_BITONIC_NETWORK = Dict(k => bitonic_network(4^k) for k in QUANTILE_K_MIN:QUANTILE_K_MAX)

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
    segmented_quantile(xs, starts, q, backend = CPU(BLOCKSIZE))

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
"""
function segmented_quantile(xs::AbstractVector, starts::AbstractVector{<:Integer}, q::Real,
                             backend::Backend = CPU(BLOCKSIZE))
    nseg = segment_extent(xs, starts)
    out = similar(xs, nseg)
    nseg == 0 && return out
    k = segment_depth(starts, nseg)
    seglen = 4^k
    rank = quantile_rank(seglen, q)
    lo, _ = segment_bounds(starts)
    base = lo .- 1
    partner, ascending = QUANTILE_BITONIC_NETWORK[k]
    AT = array_type(backend)
    kernel = quantile_kernel(Val(k))
    launch!(kernel, at_workgroup(backend, seglen), nseg * seglen,
            out, xs, base, rank, AT(partner), AT(ascending))
    return out
end

"""
    segmented_quantile_reference(xs, starts, q)

The naive serial reference for `segmented_quantile` (decision 0027): each
segment's slice sorted by `Base.sort` and the element at `quantile_rank`
read out, one segment after another. `xs` and `starts` must be host
arrays.
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

"""
    area_fraction_above(xs, areas, x, backend = CPU(BLOCKSIZE))

The area-weighted fraction of `xs` at or above `x`: the fixed-order sum
(`pairwise_sum`) of `areas` where `xs .>= x`, divided by the fixed-order
sum of `areas`. The exact inverse of `segmented_quantile` rather than an
interpolation of it: it reads back a fraction from a value with no rule of
its own about what lies between two data points, so calling it on the
value `segmented_quantile` selected counts that element itself as being at
or above the threshold, while calling it on any value absent from the data
(an interpolated value, among others) does not. `xs` and `areas` must have
the same length and must already live on `backend`. Refuses when they
differ in length, or when the total area is not positive.
"""
function area_fraction_above(xs::AbstractVector, areas::AbstractVector, x::Real,
                              backend::Backend = CPU(BLOCKSIZE))
    length(xs) == length(areas) ||
        refuse("area fraction extent", "Reductions.area_fraction_above",
               "xs has length $(length(xs)), areas has length $(length(areas))")
    above = ifelse.(xs .>= x, areas, zero(eltype(areas)))
    total = pairwise_sum(Float64, areas, backend)
    weighted = pairwise_sum(Float64, above, backend)
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
