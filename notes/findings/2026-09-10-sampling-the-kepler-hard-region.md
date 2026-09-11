# A Kepler sample uniform in mean anomaly cannot see the defect it is meant to catch

Measured on 2026-09-10 on yggdrasil, Julia 1.12.7, `CUDA.jl` 6.3.1 and
`KernelAbstractions.jl` 0.9.42, with the solve at `src/Orbit/kepler.jl` and the suite at
`test/orbit/runtests.jl`. The subject is how `system.kepler_period` must be sampled, and
it follows `notes/findings/2026-09-10-kepler-in-a-portable-kernel.md`, which established
that the accuracy of a Kepler solve is a property of its residual.

## The region is a vanishing fraction of the mean-anomaly axis

Markley's paper names the region where a double-precision implementation of his method
loses accuracy: eccentricity above 0.75 and eccentric anomaly below 45 degrees. At high
eccentricity that region is almost invisible from the other side of the equation. For
`e = 1 - 1e-12`, the whole of `E` below 45 degrees maps into `M` below 0.081, which is
1.3 per cent of a half turn, and the error grows as `E` falls toward zero.

Two hundred and one mean anomalies spanning a full turn, which is what the earlier
finding used, put three points in that window and none of them near its worst part.
Maximum error in ulps of pi, over that sample:

| eccentricity | this solve | Markley closed form | two Newton steps, naive residual |
|---|---|---|---|
| 0.5 | 0.72 | 0.8 | 0.7 |
| 0.9 | 0.70 | 0.7 | 0.7 |
| 0.99 | 0.70 | 0.7 | 0.7 |
| 0.999 | 0.61 | 0.7 | 1.1 |
| 1 - 1e-6 | 0.81 | 0.8 | 0.7 |
| 1 - 1e-9 | 0.65 | 0.9 | 1.1 |
| 1 - 1e-12 | 0.70 | 0.7 | 0.7 |

Every route passes. The two routes that are wrong are indistinguishable from the one that
is right, and a positive control drawn this way never fires.

## Sampled in the eccentric anomaly, the same routes separate by five orders

Choosing `E` and deriving `M = E - e sin E` at 300 bits puts the sample where the defect
lives, and makes the chosen `E` the reference with no solve required. Four hundred values
of `E` spaced logarithmically from 1e-8 to 45 degrees:

| eccentricity | this solve | Markley closed form | two Newton steps, naive residual |
|---|---|---|---|
| 0.9 | 0.52 | 0.5 | 0.7 |
| 0.99 | 0.48 | 2.7 | 2.2 |
| 0.999 | 0.71 | 5.6 | 7.5 |
| 1 - 1e-6 | 0.77 | 205.0 | 247.9 |
| 1 - 1e-9 | 0.54 | 7159.7 | 7058.8 |
| 1 - 1e-12 | 0.52 | 207949.1 | 237458.3 |

Markley's closed form as implemented by `AstroLib.jl`, and two Newton steps on the naive
residual, both reach two hundred thousand ulps. The solve this project owns, which is that
closed form followed by two Newton steps on the stable residual `(1 - e)E + e(E - sin E) - M`
with the derivative `1 - e + 2 e sin^2(E/2)`, stays under 1.01 ulps at every eccentricity
and every point of both samples.

The seven-term series for `E - sin E` below half a radian is confirmed necessary from the
other direction: truncated at five terms it reaches 25.8 ulps at `e = 0.5` and 94.9 ulps
at `e = 0.9` on the uniform sample, where every other route reads 0.7.

## The instruments

The reference for the uniform sample is bisection at 300 bits on `[-pi - 1, pi + 1]`,
followed by three Newton steps on the stable residual. The bracket is widened by one
radian on each side because at `M = -pi` exactly the root sits on the endpoint of the
natural bracket and the bisection collapses onto it; the widened bracket has the root
strictly interior at every sampled point. Its control is its own residual: the largest
`|E - e sin E - M|` over the whole set is 3.9e-90, so the reference is the root and not
one method's opinion of it.

The derived reference carries one error of its own. `M` is rounded to double precision
before the solve sees it, and the root moves by that rounding divided by `dM/dE`, which is
smallest in exactly the region of interest. Measured over the sample, that shift is at
most 0.052 ulps of pi, at `e = 0.9` and `E = 45` degrees, against a verdict bar of 2 ulps.
The instrument is nearly forty times finer than the effect it measures, and the suite
asserts that ratio rather than assuming it.

## The two backends are still not bitwise

The same kernel source over 4096 mean anomalies, processor against device:

| eccentricity | bitwise | largest difference |
|---|---|---|
| 0.5 | no | 1.00 ulps of pi |
| 0.99 | no | 1.25 ulps of pi |
| 0.999 | no | 1.50 ulps of pi |
| 1 - 1e-12 | no | 1.50 ulps of pi |

This reproduces the earlier finding on a well-conditioned solve and confirms its
attribution: the difference is the transcendental libraries, and it is the cost of not yet
having the project's own polynomial transcendentals that decision 0029's bitwise mode
calls for.

## What this changes

`system.kepler_period` in `docs/oracles/registry.toml` states its sampling: the eccentric
anomaly is chosen and the mean anomaly derived from it, spaced logarithmically toward
zero across the region above `e = 0.75` and below 45 degrees. Without that clause the
entry's declared positive control, that the naive residual must fail, is a control that
cannot fire.
