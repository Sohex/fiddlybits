# Reductions.error_bound's k is 1, from Higham (1993) equation (2.6), not a chosen margin

Read 2026-09-11 at `references/pdf/higham1993-accuracy-floating-point-summation.pdf`
(Higham, N. J., "The accuracy of floating point summation," SIAM J. Sci. Comput. 14
(1993), pp. 783-799, DOI: 10.1137/0914050), section 2, "Orderings of recursive
summation," pp. 784-785.

## The source result

For `S_n = sum_{i=1}^n x_i` computed by the standard recursive (left-to-right)
summation `s = 0; for i = 1:n; s = s + x_i; end` in floating point arithmetic obeying
Higham's model (1.2), `fl(x op y) = (x op y)(1 + delta)`, `|delta| <= u`, with `u` the
unit roundoff, Higham derives (eq. 2.4-2.5) and then weakens to the ordering-independent
form:

    |E_n| = |S_hat_n - S_n| <= gamma_{n-1} * sum_{i=1}^n |x_i|      (2.6)

where `gamma_k = k*u / (1 - k*u)`, defined on p. 784 directly under (2.2). Equation
(2.6) is exact (not an asymptotic O(u^2) statement); Higham also gives the weaker
`(n-1)*u*sum|x_i| + O(u^2)` reading of the same bound.

Every summation this row (`fiddlybits-52v.7.3`) built reduces, worst case, to one or
more applications of exactly this recursive-summation pattern: `pairwise_sum_reference`,
`compensated_sum_reference`, and the per-segment loop in `segmented_sum_reference` and
`segmented_mean_reference` are literally Higham's `s = s + x_i` loop; `pairwise_sum`'s
per-block loop is the same pattern applied within each block; `compensated_sum` and
`pairwise_sum`'s cross-block combine both have strictly smaller error constants (eq.
3.6 and 3.11 of the same paper), so (2.6) is the single worst case among every
reduction this module carries, which is what makes it the one bound to declare.

## Matching (2.6) to `error_bound(T, n, magnitude) = k * n * eps(T) * magnitude`

Two substitutions turn (2.6) into the declared form, and both are read off directly
rather than picked to make a number come out:

**`eps(T)` for `u`.** Higham's `u` is the unit roundoff of model (1.2): for round-to-
nearest binary arithmetic with a `p`-bit significand, `u = 2^-p`. Julia's `eps(T)` is
the distance from `1` to the next representable value, `2^(1-p)`, so:

    eps(T) == 2 * u                                    exactly, for T = Float32 or Float64

confirmed for both: `eps(Float64) == 2 * 2.0^-53` and `eps(Float32) == 2 * 2.0f0^-24`
both hold bit for bit in Julia 1.12. This is a unit conversion between two names for
the same rounding unit, not a margin.

**`n` for `n - 1`.** `error_bound` takes the term count `n` as its caller declares it
(the length of the array being summed); Higham's bound is stated in terms of `n - 1`,
the number of additions a length-`n` recursive sum performs. `n > n - 1` for every
`n >= 1`, so using the declared term count is a safe, minimal substitution of the
quantity the caller already has for the quantity the theorem is stated in, not an
added factor.

## What k = 1 gives, and its domain

Substituting `u = eps(T)/2` into `gamma_{n-1} = (n-1)*u / (1 - (n-1)*u)` and comparing
against `k * n * eps(T)` term by term:

    k * n * eps(T) >= gamma_{n-1}
    k * n * 2u     >= (n-1)*u / (1 - (n-1)*u)
    2kn(1-(n-1)u)  >= n-1

At `k = 1`: `2n(1-(n-1)u) >= n-1` reduces, for any `n` with `(n-1)*u` small (Higham's
own standing assumption throughout the paper, stated explicitly at eq. 3.11, "as long
as nu <= 1"), to `2n >= n-1`, true for every `n >= 1` with a factor of about two to
spare. Checked in Julia at `Float64`'s `u = 2^-53` for `n` from 2 to 1e9,
`gamma_{n-1}` against `n * eps(Float64)`: the latter exceeds the former at every `n`
tried, by a ratio converging to 2 as `n` grows (2 : 1 at `n = 1e9`, `gamma_{15} =
1.11e-16` against `16*eps(Float64) = 3.55e-15` at the small end). `k = 2` was declared
in the row's first pass without this derivation; it added a further factor of two on
top of a bound that already dominates by construction, which is exactly the "chosen"
margin REQ-NUM-004 and CLAUDE.md's five-disposition rule forbid. `k = 1` is what (2.6)
gives once `eps(T)` and `n` are substituted for `u` and `n - 1`; nothing is added to it.

The bound requires `n` small enough that `(n-1)*u` is itself small (Higham's `nu <= 1`
reading), which holds for every term count this project's reductions handle (mesh
cell counts and segment sizes are many orders below `1/u ~ 4.5e15` for `Float64`).

## The magnitude argument

(2.6) bounds `sum_{i=1}^n |x_i|`, the sum of the terms' absolute values, not the
largest term or the result's own scale. `error_bound`'s `magnitude` argument must be
an upper bound on that sum for the guarantee to hold; a caller that passes a smaller
number (a per-term or result-scale magnitude) is not exercising the sourced guarantee,
only a narrower, caller-specific expectation, and `test/reductions/` distinguishes the
two.

## Disposition

`Reductions.ERROR_BOUND_K = 1` is Sourced: transcribed from Higham (1993) equation
(2.6), by the two substitutions above and no other adjustment.
