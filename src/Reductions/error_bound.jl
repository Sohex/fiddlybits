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
    error_bound(::Type{T}, n, magnitude) where {T<:AbstractFloat}

`ERROR_BOUND_K * n * eps(T) * magnitude`: the roundoff bound for a
fixed-order sum of `n` terms of type `T`, from Higham (1993) eq. 2.6
(REQ-NUM-004). `magnitude` must be an upper bound on the sum of the
terms' absolute values, `sum|x_i|`, for the bound to hold; a smaller
number is a different, caller-declared expectation, not this guarantee.
The one definition of this quantity in the tree; a caller reads it from
here rather than declaring its own. Refuses when `n` or `magnitude` is
negative.
"""
function error_bound(::Type{T}, n::Integer, magnitude::Real) where {T<:AbstractFloat}
    n >= 0 ||
        refuse("reduction error bound", "Reductions.error_bound", "term count $n is negative")
    magnitude >= 0 ||
        refuse("reduction error bound", "Reductions.error_bound",
               "magnitude $magnitude is negative")
    return ERROR_BOUND_K * n * eps(T) * T(magnitude)
end
