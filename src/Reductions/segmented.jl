# Segmented sums and means: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The reductions".

using ..Backends: Backend, CPU, launch!
using ..Verdicts: refuse
using KernelAbstractions: @kernel, @index, @Const

"""
    segment_extent(xs, starts)

Refuses unless `starts` is a non-decreasing boundary array beginning at
`1` and ending at `length(xs) + 1`, and otherwise returns
`length(starts) - 1`, the segment count. Segment `s` is
`xs[starts[s]:starts[s+1]-1]`.
"""
function segment_extent(xs::AbstractVector, starts::AbstractVector{<:Integer})
    isempty(starts) &&
        refuse("segment boundaries", "Reductions.segment_extent", "starts is empty")
    issorted(starts) ||
        refuse("segment boundaries", "Reductions.segment_extent", "starts is not non-decreasing")
    first(starts) == 1 ||
        refuse("segment boundaries", "Reductions.segment_extent",
               "starts begins at $(first(starts)), not 1")
    last(starts) == length(xs) + 1 ||
        refuse("segment boundaries", "Reductions.segment_extent",
               "starts ends at $(last(starts)), xs has length $(length(xs))")
    return length(starts) - 1
end

"""
    segment_bounds(starts)

`(lo, hi)`, each of length `length(starts) - 1`: segment `s` runs
`lo[s]:hi[s]`. Computed once at the host boundary (decision F7: a kernel
never offsets the index it was bound with) so `segmented_sum_kernel!`
reads a start and an end for its own segment with no arithmetic on the
index at all.
"""
function segment_bounds(starts::AbstractVector{<:Integer})
    nseg = length(starts) - 1
    lo = starts[1:nseg]
    hi = starts[2:nseg+1] .- 1
    return lo, hi
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

The per-segment fixed-order sum of `xs`, accumulated in type `A`. `xs` is
grouped contiguously by segment and `starts` gives its boundaries
(`segment_extent`): `length(starts) == nseg + 1`, 1-based and
non-decreasing, `starts[1] == 1` and `starts[end] == length(xs) + 1`. One
fixed-order tree per segment, each computed independently of every other
segment. `xs` and `starts` must already live on `backend`.
"""
function segmented_sum(::Type{A}, xs::AbstractVector, starts::AbstractVector{<:Integer},
                        backend::Backend = CPU(BLOCKSIZE)) where {A<:Number}
    nseg = segment_extent(xs, starts)
    out = similar(xs, A, nseg)
    nseg == 0 && return out
    lo, hi = segment_bounds(starts)
    launch!(segmented_sum_kernel!, backend, nseg, out, xs, lo, hi)
    return out
end

"""
    segmented_sum_reference(::Type{A}, xs, starts) where A

The naive serial reference for `segmented_sum` (decision 0027): each
segment's terms accumulated one at a time in index order, one segment
after another.
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

"""
    segmented_mean(::Type{A}, xs, starts, weights, backend = CPU(BLOCKSIZE)) where A

The per-segment weighted mean of `xs` by `weights`, accumulated in type
`A`: the segmented sum of `xs .* weights` divided elementwise by the
segmented sum of `weights`, both by `segmented_sum` on `backend`. Refuses
when `xs` and `weights` differ in length, or when a segment's total weight
is zero.
"""
function segmented_mean(::Type{A}, xs::AbstractVector, starts::AbstractVector{<:Integer},
                         weights::AbstractVector, backend::Backend = CPU(BLOCKSIZE)) where {A<:Number}
    length(xs) == length(weights) ||
        refuse("segmented mean extent", "Reductions.segmented_mean",
               "xs has length $(length(xs)), weights has length $(length(weights))")
    numerator = segmented_sum(A, xs .* weights, starts, backend)
    denominator = segmented_sum(A, weights, starts, backend)
    any(iszero, denominator) &&
        refuse("segmented mean weight", "Reductions.segmented_mean",
               "a segment's total weight is zero")
    return numerator ./ denominator
end

"""
    segmented_mean_reference(::Type{A}, xs, starts, weights) where A

The naive serial reference for `segmented_mean` (decision 0027): each
segment's weighted numerator and total weight accumulated one term at a
time in index order, one segment after another. Refuses when `xs` and
`weights` differ in length, or when a segment's total weight is zero.
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
