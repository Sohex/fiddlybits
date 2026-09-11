# The reduction error bound: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The reductions", and docs/requirements/num/closure-tolerance-from-
# floating-point.md (REQ-NUM-004).

using ..Verdicts: refuse

"""
    ERROR_BOUND_K

`k` of `error_bound`'s `k * n * eps(T) * magnitude`. Sourced: 1, from
Higham (1993, "The accuracy of floating point summation," eq. 2.6,
`gamma_{n-1} * sum|x_i|`) by two substitutions and no other adjustment,
`eps(T) = 2u` for Higham's unit roundoff `u` and the declared term count
`n` for Higham's `n - 1`; derivation in
notes/findings/2026-09-11-reduction-error-bound-derivation.md.
"""
const ERROR_BOUND_K = 1

"""
    ERROR_BOUND_ULP_MARGIN

The count of `Float64` ulps `error_bound`'s `Float64`-formed product is
advanced by, via `nextfloat`, before it is rounded up into `T`. Chaining
three `Float64` multiplications rounds the exact product down by up to
`0.36` ulp of `Float64` (measured for `T = Float64`, where `T`'s own
rounding step is a no-op); `4` covers that with headroom.
"""
const ERROR_BOUND_ULP_MARGIN = 4

"""
    validity_limit(::Type{T}) where {T<:AbstractFloat}

`2 / eps(T)`, i.e. `1 / u` for `T`'s unit roundoff `u = eps(T) / 2`: the
term count above which Higham's `n * u <= 1` (1993, discussion following
eq. 3.11) fails and `gamma_{n-1}` (eq. 2.6) is no longer a finite, positive
bound. `error_bound` refuses at and above this count rather than return a
number that is not a bound (derivation and the mesh levels that reach it
at `Float32` in
notes/findings/2026-09-11-reduction-error-bound-derivation.md).
"""
validity_limit(::Type{T}) where {T<:AbstractFloat} = 2 / Float64(eps(T))

"""
    error_bound(::Type{T}, n, magnitude) where {T<:AbstractFloat}

`ERROR_BOUND_K * n * eps(T) * magnitude`: the roundoff bound for a
fixed-order sum of `n` terms of type `T`, from Higham (1993) eq. 2.6
(REQ-NUM-004). `magnitude` must be an upper bound on the sum of the
terms' absolute values, `sum|x_i|`, for the bound to hold; a smaller
number is a different, caller-declared expectation, not this guarantee.
The one definition of this quantity in the tree; a caller reads it from
here rather than declaring its own.

The product is formed in `Float64` regardless of `T`, advanced by
`ERROR_BOUND_ULP_MARGIN` ulps of `Float64`, then rounded toward
positive infinity into `T`, so the returned value is never below the
exact value of the declared expression. Refuses when `n` or
`magnitude` is negative, when `n` is at or beyond `validity_limit(T)`,
or when the rounded-up product is not finite in `T`, naming `T`, `n`
and `magnitude` in that last case.
"""
function error_bound(::Type{T}, n::Integer, magnitude::Real) where {T<:AbstractFloat}
    n >= 0 ||
        refuse("reduction error bound", "Reductions.error_bound", "term count $n is negative")
    magnitude >= 0 ||
        refuse("reduction error bound", "Reductions.error_bound",
               "magnitude $magnitude is negative")
    limit = validity_limit(T)
    Float64(n) < limit ||
        refuse("reduction error bound", "Reductions.error_bound",
               "term count $n at type $T is at or beyond the validity limit $(limit) " *
               "(Higham 1993 eq. 2.6 requires n * u <= 1, u = eps($T) / 2)")
    product = ERROR_BOUND_K * Float64(n) * Float64(eps(T)) * Float64(magnitude)
    advanced = product == 0 ? product : nextfloat(product, ERROR_BOUND_ULP_MARGIN)
    bound = T(advanced, RoundUp)
    isfinite(bound) ||
        refuse("reduction error bound", "Reductions.error_bound",
               "bound for type $T, term count $n and magnitude $magnitude is not finite " *
               "in $T (the product $product exceeds floatmax($T))")
    return bound
end
