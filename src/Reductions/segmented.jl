# Segmented sums and means: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The reductions".

using ..Backends: Backend, CPU, launch!, on, nofuse_mul
using ..Verdicts: refuse
using KernelAbstractions: @kernel, @index, @Const

"""
    starts_on_host(starts)

`starts` moved to the host through `Backends.on`: a no-op returning
`starts` unchanged when it already lives there, otherwise one copy.
`segment_extent` and `segment_depth` both accept the already-host array
through their `_host`-suffixed forms below, so a caller that needs both
checks reads the boundary array to the host once rather than once per
check. `Segmentation` calls this once and keeps what it read, so a caller
holding one reads the boundary array to the host no further times at all.
"""
starts_on_host(starts::AbstractVector{<:Integer}) = on(starts, CPU(1))

"""
    segment_extent_host(xs, starts_host)

`segment_extent`'s check, given `starts` already on the host.
"""
function segment_extent_host(xs::AbstractVector, starts_host::AbstractVector{<:Integer})
    isempty(starts_host) &&
        refuse("segment boundaries", "Reductions.segment_extent", "starts is empty")
    issorted(starts_host) ||
        refuse("segment boundaries", "Reductions.segment_extent", "starts is not non-decreasing")
    first(starts_host) == 1 ||
        refuse("segment boundaries", "Reductions.segment_extent",
               "starts begins at $(first(starts_host)), not 1")
    last(starts_host) == length(xs) + 1 ||
        refuse("segment boundaries", "Reductions.segment_extent",
               "starts ends at $(last(starts_host)), xs has length $(length(xs))")
    return length(starts_host) - 1
end

"""
    segment_extent(xs, starts)

Refuses unless `starts` is a non-decreasing boundary array beginning at
`1` and ending at `length(xs) + 1`, and otherwise returns
`length(starts) - 1`, the segment count. Segment `s` is
`xs[starts[s]:starts[s+1]-1]`. `starts` is read element by element for
this check, so it is copied to the host first when it is not already
there (a boundary array, not the reduced data, so the copy is cheap).
"""
function segment_extent(xs::AbstractVector, starts::AbstractVector{<:Integer})
    return segment_extent_host(xs, starts_on_host(starts))
end

"""
    segment_bounds(starts)

`(lo, hi)`, each of length `length(starts) - 1`: segment `s` runs
`lo[s]:hi[s]`. Computed once at the host boundary (decision F7: a kernel
never offsets the index it was bound with) so `segmented_sum_kernel!`
reads a start and an end for its own segment with no arithmetic on the
index at all. Both come back on the device `starts` lives on, and both
are new arrays rather than views of it.
"""
function segment_bounds(starts::AbstractVector{<:Integer})
    nseg = length(starts) - 1
    lo = starts[1:nseg]
    hi = starts[2:nseg+1] .- 1
    return lo, hi
end

"""
    Segmentation(xs, starts)

A boundary array checked once against the extent it describes, holding
everything a segmented reduction reads from it: the element count it was
checked against, the segment count, the boundaries on the host, and the
per-segment `lo` and `hi` on the device `starts` came from. Refuses at
construction, exactly as `segment_extent` does, for an empty `starts`,
for one that is not non-decreasing, for one that does not begin at `1`,
and for one that does not end at `length(xs) + 1`.

Every segmented reduction takes either a boundary array or a
`Segmentation`. Given a boundary array it builds one, so a boundary array
is copied to the host and checked on every call. Given a `Segmentation`
it copies nothing to the host and checks the boundaries no further times,
whatever device they live on (decision 0011).

A `Segmentation` holds its own copies of the boundaries and of `lo` and
`hi`, and is only ever constructed from a boundary array, never looked up
from one: mutating a boundary array in place after building a
`Segmentation` from it leaves the `Segmentation` describing what was
checked, and `xs` is checked against `nelement` on every use.
"""
struct Segmentation{D<:AbstractVector{<:Integer},H<:AbstractVector{<:Integer}}
    nelement::Int
    nseg::Int
    starts_host::H
    lo::D
    hi::D
end

function Segmentation(xs::AbstractVector, starts::AbstractVector{<:Integer})
    starts_host = starts_on_host(starts)
    nseg = segment_extent_host(xs, starts_host)
    lo, hi = segment_bounds(starts)
    return Segmentation(length(xs), nseg, copy(starts_host), lo, hi)
end

"""
    require_extent(segmentation, xs, site)

Returns `nothing` when `xs` has the length `segmentation` was checked
against, and otherwise refuses at `site`, naming both lengths.
"""
function require_extent(segmentation::Segmentation, xs::AbstractVector, site::AbstractString)
    length(xs) == segmentation.nelement && return nothing
    refuse("segmentation extent", site,
           "the segmentation was checked against $(segmentation.nelement) elements, " *
           "xs has length $(length(xs))")
end

@kernel function segmented_sum_kernel!(out, @Const(xs), @Const(lo), @Const(hi))
    seg = @index(Global)
    T = eltype(out)
    acc = zero(T)
    for j in lo[seg]:hi[seg]
        acc += T(xs[j])
    end
    out[seg] = acc
end

"""
    segmented_sum(::Type{A}, xs, starts, backend = CPU(BLOCKSIZE)) where A
    segmented_sum(::Type{A}, xs, segmentation, backend = CPU(BLOCKSIZE)) where A

The per-segment fixed-order sum of `xs`, accumulated in type `A`. `xs` is
grouped contiguously by segment and `starts` gives its boundaries
(`segment_extent`): `length(starts) == nseg + 1`, 1-based and
non-decreasing, `starts[1] == 1` and `starts[end] == length(xs) + 1`. One
fixed-order tree per segment, each computed independently of every other
segment. `xs` and `starts` must already live on `backend`.

The `Segmentation` form takes the same boundaries already checked, and
refuses when `xs` does not have the length they were checked against.
"""
function segmented_sum(::Type{A}, xs::AbstractVector, segmentation::Segmentation,
                        backend::Backend = CPU(BLOCKSIZE)) where {A<:Number}
    require_extent(segmentation, xs, "Reductions.segmented_sum")
    out = similar(xs, A, segmentation.nseg)
    segmentation.nseg == 0 && return out
    launch!(segmented_sum_kernel!, backend, segmentation.nseg,
            out, xs, segmentation.lo, segmentation.hi)
    return out
end

function segmented_sum(::Type{A}, xs::AbstractVector, starts::AbstractVector{<:Integer},
                        backend::Backend = CPU(BLOCKSIZE)) where {A<:Number}
    return segmented_sum(A, xs, Segmentation(xs, starts), backend)
end

"""
    segmented_sum_reference(::Type{A}, xs, starts) where A
    segmented_sum_reference(::Type{A}, xs, segmentation) where A

The naive serial reference for `segmented_sum` (decision 0027): each
segment's terms accumulated one at a time in index order, one segment
after another. The `Segmentation` form reads the boundaries it holds and
checks them again here, so the reference path checks its own boundaries
whatever it is handed.
"""
function segmented_sum_reference(::Type{A}, xs::AbstractVector,
                                  starts::AbstractVector{<:Integer}) where {A<:Number}
    nseg = segment_extent(xs, starts)
    out = Vector{A}(undef, nseg)
    for s in 1:nseg
        acc = zero(A)
        for j in starts[s]:starts[s+1]-1
            acc += A(xs[j])
        end
        out[s] = acc
    end
    return out
end

function segmented_sum_reference(::Type{A}, xs::AbstractVector,
                                  segmentation::Segmentation) where {A<:Number}
    require_extent(segmentation, xs, "Reductions.segmented_sum_reference")
    return segmented_sum_reference(A, xs, segmentation.starts_host)
end

@kernel function segmented_weighted_sum_kernel!(out, @Const(xs), @Const(weights), @Const(lo), @Const(hi))
    seg = @index(Global)
    T = eltype(out)
    acc = zero(T)
    for j in lo[seg]:hi[seg]
        acc += nofuse_mul(T(xs[j]), T(weights[j]))
    end
    out[seg] = acc
end

"""
    segmented_weighted_sum(::Type{A}, xs, weights, segmentation, backend = CPU(BLOCKSIZE)) where A

The per-segment fixed-order sum of `xs[j] * weights[j]`, accumulated in
type `A`, one workgroup pass per segment: the product and the
accumulation happen in the same loop `segmented_sum_kernel!` walks, so no
array the size of `xs` is ever materialised. `Reductions.BLOCKSIZE`'s
sibling rule for a segmented reduction: a reduction allocates no
temporary the size of its input, so a later reduction fuses its own
elementwise step into its accumulation loop the same way rather than
asking `Backends.budget` to account for a transient. Each term is
`nofuse_mul(A(xs[j]), A(weights[j]))`: both operands converted to `A`,
then multiplied through `Backends.nofuse_mul`, so the product is rounded
once on its own in `A` before the add that follows, on both CPU and GPU
(decisions 0055 and 0044). The sum this function returns is bitwise
`segmented_weighted_sum_reference`, and bitwise the `segmented_sum` in
`A` of the materialised array `A.(xs) .* A.(weights)`. Refuses when
`xs` and `weights` differ in length, or when `xs` does not have the
length `segmentation` was checked against.
"""
function segmented_weighted_sum(::Type{A}, xs::AbstractVector, weights::AbstractVector,
                                 segmentation::Segmentation, backend::Backend = CPU(BLOCKSIZE)) where {A<:Number}
    require_extent(segmentation, xs, "Reductions.segmented_weighted_sum")
    length(xs) == length(weights) ||
        refuse("segmented weighted sum extent", "Reductions.segmented_weighted_sum",
               "xs has length $(length(xs)), weights has length $(length(weights))")
    out = similar(xs, A, segmentation.nseg)
    segmentation.nseg == 0 && return out
    launch!(segmented_weighted_sum_kernel!, backend, segmentation.nseg,
            out, xs, weights, segmentation.lo, segmentation.hi)
    return out
end

"""
    segmented_weighted_sum_reference(::Type{A}, xs, weights, starts) where A
    segmented_weighted_sum_reference(::Type{A}, xs, weights, segmentation) where A

The naive serial reference for `segmented_weighted_sum` (decision 0027):
the products `A(xs[j]) * A(weights[j])` written one index at a time into an
array of type `A`, each operand converted to `A` before it is multiplied
(decision 0055), and that array then reduced by `segmented_sum_reference`
in `A`. Refuses when `xs` and `weights` differ in length. The
`Segmentation` form reads the boundaries it holds and checks them again
here.
"""
function segmented_weighted_sum_reference(::Type{A}, xs::AbstractVector, weights::AbstractVector,
                                           starts::AbstractVector{<:Integer}) where {A<:Number}
    length(xs) == length(weights) ||
        refuse("segmented weighted sum extent", "Reductions.segmented_weighted_sum_reference",
               "xs has length $(length(xs)), weights has length $(length(weights))")
    terms = Vector{A}(undef, length(xs))
    for j in eachindex(terms, xs, weights)
        terms[j] = A(xs[j]) * A(weights[j])
    end
    return segmented_sum_reference(A, terms, starts)
end

function segmented_weighted_sum_reference(::Type{A}, xs::AbstractVector, weights::AbstractVector,
                                           segmentation::Segmentation) where {A<:Number}
    require_extent(segmentation, xs, "Reductions.segmented_weighted_sum_reference")
    return segmented_weighted_sum_reference(A, xs, weights, segmentation.starts_host)
end

@kernel function segmented_mean_kernel!(out, zeroflag, @Const(xs), @Const(weights), @Const(lo), @Const(hi))
    seg = @index(Global)
    T = eltype(out)
    num = zero(T)
    den = zero(T)
    for j in lo[seg]:hi[seg]
        num += nofuse_mul(T(xs[j]), T(weights[j]))
        den += T(weights[j])
    end
    out[seg] = num / den
    zeroflag[seg] = iszero(den)
end

"""
    segmented_mean(::Type{A}, xs, starts, weights, backend = CPU(BLOCKSIZE)) where A
    segmented_mean(::Type{A}, xs, segmentation, weights, backend = CPU(BLOCKSIZE)) where A

The per-segment weighted mean of `xs` by `weights`, accumulated in type
`A`: the weighted numerator and the total weight accumulated in the same
loop `segmented_weighted_sum_kernel!` and `segmented_sum_kernel!` each walk
on their own, one workgroup pass per segment, the division and the
zero-weight test written out at the end of that same pass. No array the
size of `xs`, nor a numerator or a denominator array, is ever materialised.
Each numerator term is `nofuse_mul(A(xs[j]), A(weights[j]))` and each
denominator term `A(weights[j])`, exactly as `segmented_weighted_sum`
states (decisions 0055 and 0044), so the result is bitwise
`segmented_mean_reference`. Refuses
when `xs` and `weights` differ in length, or when `xs` does not have the
length `segmentation` was checked against, or when any segment's total
weight is zero, naming how many. The boundaries reach the kernel once, so
the `Segmentation` form checks them no times and the boundary-array form
once rather than twice.

The result is a device array on `backend`, so nothing here reads the
result back; the zero-weight refusal is raised on the host and pays a
device-to-host read of its own. That read is the one `pairwise_sum` makes
over the per-segment zero-weight flag the kernel writes: one
`Events.moved` record per call on device-resident input, of the block
sums of that flag, and none on host-resident input. It is the device-move
record of decision 0010, not an event of decision 0042's journal
vocabulary. It is not a read of the boundary array, which the
`Segmentation` form still reads no times.
"""
function segmented_mean(::Type{A}, xs::AbstractVector, segmentation::Segmentation,
                         weights::AbstractVector, backend::Backend = CPU(BLOCKSIZE)) where {A<:Number}
    length(xs) == length(weights) ||
        refuse("segmented mean extent", "Reductions.segmented_mean",
               "xs has length $(length(xs)), weights has length $(length(weights))")
    require_extent(segmentation, xs, "Reductions.segmented_mean")
    out = similar(xs, A, segmentation.nseg)
    segmentation.nseg == 0 && return out
    zeroflag = similar(xs, Bool, segmentation.nseg)
    launch!(segmented_mean_kernel!, backend, segmentation.nseg,
            out, zeroflag, xs, weights, segmentation.lo, segmentation.hi)
    nzero = pairwise_sum(Int, zeroflag, backend)
    nzero == 0 ||
        refuse("segmented mean weight", "Reductions.segmented_mean",
               "$nzero of $(segmentation.nseg) segments have zero total weight")
    return out
end

function segmented_mean(::Type{A}, xs::AbstractVector, starts::AbstractVector{<:Integer},
                         weights::AbstractVector, backend::Backend = CPU(BLOCKSIZE)) where {A<:Number}
    return segmented_mean(A, xs, Segmentation(xs, starts), weights, backend)
end

"""
    segmented_mean_reference(::Type{A}, xs, starts, weights) where A
    segmented_mean_reference(::Type{A}, xs, segmentation, weights) where A

The naive serial reference for `segmented_mean` (decision 0027): each
segment's weighted numerator and total weight accumulated one term at a
time in index order, one segment after another, each numerator term
`A(xs[j]) * A(weights[j])` with both operands converted to `A` before they
are multiplied (decision 0055). Refuses when `xs` and
`weights` differ in length, or when a segment's total weight is zero. The
`Segmentation` form reads the boundaries it holds and checks them again
here.
"""
function segmented_mean_reference(::Type{A}, xs::AbstractVector, starts::AbstractVector{<:Integer},
                                   weights::AbstractVector) where {A<:Number}
    length(xs) == length(weights) ||
        refuse("segmented mean extent", "Reductions.segmented_mean_reference",
               "xs has length $(length(xs)), weights has length $(length(weights))")
    nseg = segment_extent(xs, starts)
    out = Vector{A}(undef, nseg)
    for s in 1:nseg
        num = zero(A)
        den = zero(A)
        for j in starts[s]:starts[s+1]-1
            num += A(xs[j]) * A(weights[j])
            den += A(weights[j])
        end
        den == 0 &&
            refuse("segmented mean weight", "Reductions.segmented_mean_reference",
                   "segment $s has zero total weight")
        out[s] = num / den
    end
    return out
end

function segmented_mean_reference(::Type{A}, xs::AbstractVector, segmentation::Segmentation,
                                   weights::AbstractVector) where {A<:Number}
    require_extent(segmentation, xs, "Reductions.segmented_mean_reference")
    return segmented_mean_reference(A, xs, segmentation.starts_host, weights)
end
