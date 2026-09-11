# Kepler to rounding is a property of the residual, not of the solver, and the packaged solvers do not compile for the device

Measured on 2026-09-10 on yggdrasil, through `qrun -p gpu-share` (one share of the RTX
4090), Julia 1.12.7, `CUDA.jl` 6.3.1, `KernelAbstractions.jl` 0.9.42,
`BracketingNonlinearSolve` 1.12.6 and `NonlinearSolveBase` 2.49.4 from
`/home/cfutro/git/SciML/NonlinearSolve.jl` at `0dccd34d125638394c2f3e5e53be3b5e272896a0`,
Markley's closed form transcribed from `AstroLib.jl` at
`288bcfd14e71fba9e34db62cc6341a04751153a7`.

Decision 0008 requires Kepler's equation solved to rounding for any eccentricity below
one. Two rows asked whether a packaged bracketing solver can do it inside a portable
kernel, and whether the closed form holds at the eccentricities the synthetic instances
declare. Every solver below runs as the body of the same `KernelAbstractions` kernel, on
the processor backend and on the CUDA backend, over 201 mean anomalies spanning a full
turn at each of seven eccentricities.

The reference is the same equation solved at 300 bits, by 250 bisection steps followed by
five Newton steps. Its control is its own residual: the largest `|E - e sin E - M|` over
the reference set is 2.0e-90, so the reference is the root and not an opinion about it.
Errors are reported in ulps of pi, 4.44e-16 radians, because the answer is an angle in
`[-pi, pi]` and that is the resolution the answer has.

## The residual decides the accuracy, not the method

| eccentricity | bisection, naive residual | bisection, stable residual | Markley closed form | Markley then two Newton steps on the stable residual |
|---|---|---|---|---|
| 0.5 | 1.39 | 1.45 | 0.78 | 0.72 |
| 0.9 | 1.30 | 1.39 | 0.70 | 0.70 |
| 0.99 | 1.26 | 1.62 | 0.79 | 0.70 |
| 0.999 | 1.27 | 1.56 | 0.74 | 0.63 |
| 1 - 1e-6 | 1.32 | 1.44 | 0.79 | 0.81 |
| 1 - 1e-9 | 4.90 | 1.44 | 24.1 | 0.70 |
| 1 - 1e-12 | 2930 | 1.42 | 13500 | 0.70 |

The naive residual is `E - e*sin(E) - M`. As the eccentricity approaches one and the
eccentric anomaly is small, its two leading terms cancel: the true value is of order
`(1-e)E + E^3/6` while the terms subtracted are of order `E`, so at `e = 1 - 1e-12` the
computed residual has no correct digits left and the sign test that drives a bisection is
deciding on noise. Eighty bisection steps then land 2930 ulps away, and Markley's closed
form, which finishes with three correction terms built from the same residual, lands
13500 away. Neither is a defect of the method. Both are the same subtraction.

The stable residual is `(1 - e)*E + e*(E - sin E) - M`, with `E - sin E` evaluated by its
series below `|E| = 0.5` and by the direct subtraction above it. Nothing cancels: the two
terms are positive and of comparable size, and the small-angle series carries the
cancellation that remains. With it, every solver is under two ulps of pi at every
eccentricity tried, including `1 - 1e-12`.

The series needs seven terms, not five. At the crossover a five-term series is short by a
relative 7.8e-13, which by itself put the moderate-eccentricity error at 95 ulps until the
terms through `E^15` were added; the reference for that check is the same 300-bit
evaluation, and the corrected series matches it to 2.3e-17 relative on both sides of the
crossover.

## The paper says so, and the implementation does not do it

Markley's paper was fetched and read after the measurement, which is the right order for
once: the numbers were in hand before the text that predicts them. Its Numerical
Considerations section states that a naive double-precision implementation of the method
"yields unacceptably large errors exceeding 5e-14", that all errors above 5e-16 lie in
the region `e > 0.75` and `E < 45` degrees, and that the fix is to replace two of its own
equations. Equation 30 replaces the derivative `1 - e cos E` by `1 - e + 2 e sin^2(E/2)`.
Equations 31 to 34 replace the residual by `M*(e,E) - M`, where `M*` is `E - e sin E`
outside the region and, inside it, `(1 - e)E` plus `e E^3` times a Pade approximant whose
coefficients the paper prints. With both fixes the paper reports relative errors under
4e-16 over the whole elliptic range.

`AstroLib.jl` implements equations 20 through 29 and not 30 through 35. Its residual is
`E1 - e*sin(E1) - M` and its derivative is `1 - e*cos(E1)`, which are exactly the two
expressions the paper's last two pages exist to replace.

Measured in Markley's own metric, relative error in the eccentric anomaly:

| eccentricity | as implemented | with the residual fixed |
|---|---|---|
| 0.5 | 1.45e-16 | 1.22e-16 |
| 0.9 | 7.22e-16 | 3.76e-16 |
| 0.99 | 6.48e-16 | 2.66e-16 |
| 0.999 | 5.00e-16 | 4.03e-16 |
| 1 - 1e-6 | 5.75e-11 | 6.26e-16 |
| 1 - 1e-9 | 4.36e-08 | 1.96e-16 |
| 1 - 1e-12 | 5.35e-07 | 3.97e-16 |

Over the region the paper names, `e > 0.75` and `E` below 45 degrees, the implemented
form reaches 5.35e-07 and the fixed form 6.26e-16. The prediction is thirty years old and
it is exactly right. The reformulation this finding arrived at independently,
`(1 - e)E + e(E - sin E)` with a series below half a radian, is the same idea as the
paper's equation 33 with a series in place of its Pade approximant, and reaches the same
place.

The recommendation the table supports is Markley's closed form as the starting value,
which is not iterative and costs four transcendental evaluations, followed by two Newton
steps on the stable residual. That is uniformly under one ulp of pi, is branch-free apart
from the small-angle crossover, and has a fixed cost per lane, which is what decision 0029
wants from a kernel.

## The packaged bracketing solvers do not compile for the device

`SciMLBase.solve` on an `IntervalNonlinearProblem` with `ITP()` or `Bisection()` was run
as the body of a `KernelAbstractions` kernel, with the problem built inside the kernel and
with a problem built on the host and passed in, on both backends:

| solver | problem built | processor backend | CUDA backend |
|---|---|---|---|
| ITP | in the kernel | runs | fails to compile |
| ITP | on the host | runs | fails to compile |
| Bisection | in the kernel | runs | fails to compile |
| Bisection | on the host | runs | fails to compile |

The failure is invalid intermediate representation, and the cause is not the solve loop.
The stack trace names `SciMLLogging`'s `emit_message`, reached from the
`@SciMLMessage` call that sits on the not-an-enclosing-interval branch of each solver
(`bisection.jl:45`, `itp.jl:82`, and the same line in `brent.jl`, `falsi.jl`, `ridder.jl`
and `modAB.jl`). Logging is a dynamic call, `jl_f_invokelatest`, with a lock and a symbol
construction behind it, and the device compiler has to compile the branch whether or not
the branch is taken. Around it are the ordinary exception paths, `ijl_rethrow` and the
garbage-collector safepoint.

So the survey's reading, that nothing in the loops is device-specific and the gap to a
portable kernel is a demonstration gap rather than an obstruction, is half right and the
wrong half is load bearing. The loops are clean. The refusal branch beside them is not,
and it is compiled with them.

## The two backends are not bitwise, by one ulp

Same kernel source, same inputs, the two backends:

| solver | bitwise equal | largest difference |
|---|---|---|
| bisection, naive residual | no | 35.5 ulps of pi |
| bisection, stable residual | no | 2 ulps |
| Markley closed form | no | 1.5 ulps |
| Markley then two stable Newton steps | no | 1 ulp |

The difference is the transcendental library: the processor's `sin`, `cos` and `cbrt` and
the device's differ by an ulp or so, and the solver carries that through. This is exactly
what decision 0029's bitwise mode says it needs the project's own polynomial
transcendentals for, and it puts a number on the cost of not having them: one ulp on a
well-conditioned solve, and thirty-five on the ill-conditioned residual, which is another
reason the residual is the thing to fix first.

## What this changes

The clock module writes its own Kepler solve: Markley's start and two Newton steps on the
stable residual, with the small-angle series to seven terms. `BracketingNonlinearSolve` is
an algorithmic reference for ITP and not a dependency, because its device path does not
exist. The oracle `system.kepler_period` carries the residual form in its statistic, since
a threshold of roundoff is reachable only with it, and gets a positive control at
`e = 1 - 1e-12`, where the naive form misses by three thousand ulps and would otherwise
pass unnoticed at the eccentricities an Earth-like instance declares.
