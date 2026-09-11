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

The bound requires `n` small enough that `(n-1)*u` is itself small: `gamma_{n-1} =
(n-1)*u / (1 - (n-1)*u)` is only finite and positive while `(n-1)*u < 1`, and beyond
that `k * n * eps(T)` (linear in `n`) no longer dominates it (`gamma_{n-1}` diverges).
This domain is not an asymptotic nicety; the first pass of this finding stated it only
for `Float64` and, checking the number rather than assuming it, was wrong about the
domain it was declared safe over.

## The validity limit, and where it is reachable

**The reading.** Higham does not restate `(n-1)*u < 1` at (2.6) itself; he writes the
same condition, in `n` rather than `n - 1`, in the discussion directly after eq.
(3.11): "As long as `nu <= 1`, the constant in this bound is independent of `n`." That
is stated for the compensated-summation bound, not (2.6), but it is the same
condition (`gamma_k`'s denominator staying positive) applied to the same quantity
(`n` in place of `n - 1`, the same widening already used above), so it is the reading
taken here: `error_bound` treats `n * u > 1`, i.e. `n > 1/u = 2/eps(T)`, as outside
Higham's stated domain, and refuses at or beyond it rather than return a number
`gamma_{n-1}` no longer bounds.

**The two types this project runs.** `1/u = 2/eps(T)`:

    T        eps(T)          u = eps(T)/2     1/u = 2/eps(T)
    Float64  2^-52           2^-53            2^53  = 9007199254740992  (~9.007e15)
    Float32  2^-23           2^-24            2^24  = 16777216          (~1.678e7)

checked in Julia: `2/eps(Float64) == 2.0^53` and `2/eps(Float32) == 2.0^24`, both
exact.

**The mesh reaches the `Float32` limit.** `ncells(L) = 20 * 4^L`
(`src/Mesh/hierarchy.jl`, `ncells`; decision 0005):

    L    ncells(L)     ncells(L) / 2^24
    9    5242880       0.3125       under
    10   20971520      1.25         over
    11   83886080      5.0          over, by a factor of five

so a `Float32` global reduction over all cells is inside Higham's domain through level
9 and outside it from level 10 on; decision 0011 runs production profiles at `Float32`,
and this is a level the mesh hierarchy actually builds, not an edge case at the top of
the range. `Float64`'s limit, `2^53`, is `2^29`, about `5.37e8` times the `Float32`
one, and no mesh level here reaches it.

**The refusal.** `error_bound(T, n, magnitude)` now refuses when `n >= 2/eps(T)`,
naming `T`, `n` and the limit, rather than returning `k*n*eps(T)*magnitude`, a finite
number that is no longer Higham's bound on anything past that point. `validity_limit`
carries the `2/eps(T)` computation as its own definition; `test/reductions/
error_bound.jl` checks the pair the finding above is stated for: a term count one over
`validity_limit(Float32)` refuses, and the identical count at `Float64` does not.

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

`Reductions.validity_limit(T) = 2/eps(T)` is Derived: computed from `eps(T)` (a
property of `T`, not chosen) by the reading of Higham's `nu <= 1` given above; the
rule, not a bare number, is what is carried.
