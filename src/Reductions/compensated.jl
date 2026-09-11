# Compensated summation: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The reductions", and notes/findings/2026-09-10-compensated-accumulation-
# in-a-kernel.md.

"""
    two_sum(a, b)

`(s, e)` with `s` the rounded `a + b` and `e` the exact rounding error of
that addition, so that `s + e == a + b` in infinite precision (Knuth's
error-free transform, four operations after the initial sum).
"""
@inline function two_sum(a::T, b::T) where {T<:AbstractFloat}
    s = a + b
    v = s - a
    e = (a - (s - v)) + (b - v)
    return s, e
end

"""
    compensated_sum(xs)

The compensated sum of `xs`, accumulated in `Float64` regardless of
`eltype(xs)` (decision 0029): a running sum and a running compensation
term, advanced one term at a time in index order by `two_sum`, with the
compensation added back in once at the end. Never atomic; a single fixed
order.
"""
function compensated_sum(xs::AbstractVector)
    hi = zero(Float64)
    lo = zero(Float64)
    for x in xs
        hi, e = two_sum(hi, Float64(x))
        lo += e
    end
    return hi + lo
end

"""
    compensated_sum_reference(xs)

The naive serial reference for `compensated_sum` (decision 0027): `xs`
accumulated in `Float64`, one term at a time in index order, with no
compensation.
"""
compensated_sum_reference(xs::AbstractVector) = pairwise_sum_reference(Float64, xs)
