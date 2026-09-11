# The reduction error bound: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The reductions", and docs/requirements/num/closure-tolerance-from-
# floating-point.md (REQ-NUM-004).

using ..Verdicts: refuse

"""
    ERROR_BOUND_K

The declared margin `k` of `error_bound`'s `k * n * eps(T) * magnitude`
(Higham, "The accuracy of floating point summation", 1993): a fixed
positive integer, the same for every reduction in this module, never
widened to fit a result.
"""
const ERROR_BOUND_K = 2

"""
    error_bound(::Type{T}, n, magnitude) where {T<:AbstractFloat}

`ERROR_BOUND_K * n * eps(T) * magnitude`: the roundoff bound for a
fixed-order sum of `n` terms of type `T` whose magnitude is `magnitude`
(REQ-NUM-004). The one definition of this quantity in the tree; a caller
reads it from here rather than declaring its own. Refuses when `n` or
`magnitude` is negative.
"""
function error_bound(::Type{T}, n::Integer, magnitude::Real) where {T<:AbstractFloat}
    n >= 0 ||
        refuse("reduction error bound", "Reductions.error_bound", "term count $n is negative")
    magnitude >= 0 ||
        refuse("reduction error bound", "Reductions.error_bound",
               "magnitude $magnitude is negative")
    return ERROR_BOUND_K * n * eps(T) * T(magnitude)
end
