# The project's own transcendentals are bitwise across backends and under 0.85 ulps, and the fusion barrier is not what buys either

Measured on 2026-09-11 on yggdrasil, through `qrun -p gpu-share` (one share of the RTX
4090), Julia 1.12.7, `CUDA.jl` 6.3.1, `GPUCompiler.jl` 2.6.0, `KernelAbstractions.jl`
0.9.42, Fiddlybits at branch `fiddlybits-52v.7.8` cut from `4e58509`. Every reference is
the same quantity at 300 bits, `setprecision(BigFloat, 300)`, rounded once to `Float64`.

Decision 0029's bitwise mode requires the project's own polynomial transcendentals, and
two earlier findings put a number on not having them: the Kepler solve differs between
the processor and the device by 1.0 to 1.5 ulps of pi on a well-conditioned solve
(`notes/findings/2026-09-10-kepler-in-a-portable-kernel.md`,
`notes/findings/2026-09-10-sampling-the-kepler-hard-region.md`). This row built the six
functions `src/Backends/transcendentals.jl` now carries and measured three things: what
they cost in accuracy, whether they are bitwise across backends, and what the
`@noinline` fusion barrier of
`notes/findings/2026-09-11-gpucompiler-unconditional-fma-contraction.md` does to a
polynomial chain.

## The declared grids

The bitwise claim and the accuracy bound are both stated over these grids, which are
fixed formulas in `test/backends/transcendentals.jl` and not draws. `uniform(lo, hi, n)`
is `n` points evenly spaced inclusive of both ends, `geometric(lo, hi, n)` is `n` points
in geometric progression, `signed(v)` is `v` followed by `-v`.

| grid | points | definition |
|---|---|---|
| TRIG | 6144 | `signed(geometric(2^-40, 2^18, 2048))` and `uniform(-4pi, 4pi, 2048)` |
| EXP | 4096 | `uniform(-745, 709, 2048)` and `signed(geometric(2^-40, 1, 1024))` |
| LOG | 4096 | `geometric(2^-1070, 2^1020, 2048)` and `uniform(0.5, 2, 2048)` |
| CBRT | 4096 | `signed(geometric(2^-1070, 2^1020, 1024))` and `signed(uniform(1, 8, 1024))` |
| REDUCED_TRIG | 2001 | `uniform(-pi/4, pi/4, 2001)` |
| REDUCED_EXP | 2001 | `uniform(-ln(2)/2, ln(2)/2, 2001)` |
| REDUCED_LOG | 2001 | `uniform(sqrt(2)/2, sqrt(2), 2001)` |
| REDUCED_CBRT | 2001 | `uniform(1, 8, 2001)` |
| KEPLER_M | 4096 | `uniform(-pi, pi, 4096)` at eccentricity 0.5, 0.9, 0.99, 0.999, 1 - 1e-6, 1 - 1e-9, 1 - 1e-12 |

The reduced grids span exactly the interval each polynomial is evaluated over once the
argument reduction has run. The declared grids span the whole domain: TRIG spans the
whole reduced-argument range at every quadrant index the reduction admits, EXP the whole
finite range of the exponential, LOG and CBRT the whole binade range including the
subnormals. The probes of this finding used a 20001-point version of each reduced grid
and the full seven-eccentricity Kepler set; the suite runs the counts in the table.

The endpoints of `uniform(-4pi, 4pi, 2048)` are the two points in TRIG where the result
is near a zero of the sine, and they are the points at which the reduction's low part
decides the answer. They are why the grid is written with the ends included.

## Accuracy, and what the barrier costs

Maximum error against the 300-bit reference, in ulps of the returned value, with the
subnormal spacing as the floor so a subnormal result is measured in its own spacing.
Three routes for every multiply that feeds an add: `fma`, which is what the module
ships; `Backends.nofuse_mul` followed by the add, which is the barrier; and the plain
`a * b + c`, which is what the compiler is free to contract. The probe's `fma` route was
asserted bitwise identical to the shipped functions at every point of every grid before
any of these numbers were taken.

| function | route | max ulps, reduced range | max ulps, declared grid |
|---|---|---|---|
| sine | fma | 0.6598 | 0.7140 |
| sine | barrier | 0.6928 | 0.7140 |
| sine | plain | 0.6928 | 0.7140 |
| cosine | fma | 0.7282 | 0.6344 |
| cosine | barrier | 0.7282 | 0.6344 |
| cosine | plain | 0.7282 | 0.6344 |
| exponential | fma | 0.7923 | 0.8452 |
| exponential | barrier | 0.7463 | 0.8452 |
| exponential | plain | 0.7463 | 0.8452 |
| logarithm | fma | 0.6861 | 0.7142 |
| logarithm | barrier | 0.7666 | 0.6984 |
| logarithm | plain | 0.7666 | 0.6984 |
| cube_root | fma | 0.5000 | 0.4977 |
| cube_root | barrier | 0.9162 | 0.8514 |
| cube_root | plain | 0.9162 | 0.8514 |

The platform library on the same grids, for the distance:

| function | max ulps, reduced range | max ulps, declared grid |
|---|---|---|
| sine | 0.6445 | 0.7279 |
| cosine | 0.7060 | 0.6344 |
| exponential | 0.5194 | 0.5169 |
| logarithm | 0.5386 | 0.5141 |
| cube_root | 0.6650 | 0.6496 |

The premise this row was set up to resolve was that the barrier buys cross-backend
identity at one extra rounding per Horner term and that this is paid against the
accuracy bound. Through a Horner chain that is not what the numbers say. Over eight to
twelve terms the barrier moves the maximum by at most 0.081 ulps (logarithm, reduced
range, 0.7666 against 0.6861) and it moves it the other way twice (exponential, reduced
range, 0.7463 against 0.7923; logarithm, declared grid, 0.6984 against 0.7142). In a
Horner chain evaluated over a reduced range the terms after the first two are small
enough that the roundings introduced on them are attenuated before they reach the result,
and the two routes land within a tenth of an ulp of each other.

Where the barrier costs is not a Horner chain at all. `cube_root` finishes with one step
on a residual formed exactly: `p = t*t` with its error `fma(t, t, -p)`, then
`c = p*t` with its error `fma(p, t, -c)`, so that `t^3 - y` is available to more than
`Float64` can hold and the step lands within half an ulp. Through the barrier
`nofuse_mul(t, t) - p` is identically zero, the two error terms vanish, and the step
degrades to an ordinary Newton step: 0.9162 ulps against 0.5000. A compensated algorithm
cannot be written through the barrier, which is a different statement from one more
rounding per term.

So the module routes every multiply that feeds an add through an explicit `fma`, and uses
`Backends.nofuse_mul` at the one place where a separately rounded product is required:
`cube_root`'s `c = nofuse_mul(p, t)`, so that the `c - y` beside it cannot be re-fused
into `fma(p, t, -y)`, which would be a different residual. Nothing in
`src/Backends/kernels.jl` is changed and `nofuse_mul` itself is untouched.

## Why that bound is enough

The bar is one ulp: the returned value is one of the two `Float64` values adjacent to
the exact result. It was fixed before any evaluation, by the construction of the series
rather than from the measurements. Every truncation degree was chosen from a bound
computed at 300 bits before a single `Float64` was evaluated: the first omitted term of
the sine series is 8.35e-20 in absolute value at `r = pi/4`, of the cosine series
3.28e-21, of the exponential series 4.14e-18 at `abs(r) = ln(2)/2`, and the logarithm
series' omitted contribution `s * 2 * z^11 / 25` is 1.97e-19 at the end of its reduced
range. Each is below 0.01 ulps of the smallest result on its range, so the truncation is
not what decides the measured error; the roundings of the evaluation are, and the bar
states that they cost less than one step.

The bound is enough for the kernels that read it on three counts.

The consumer that exists is the Kepler solve. Decision 0008 requires Kepler's equation
solved to rounding for any eccentricity below one, and
`notes/findings/2026-09-10-sampling-the-kepler-hard-region.md` fixed the verdict bar of
`system.kepler_period` at 2 ulps of pi. The solve built on these polynomials reaches
0.642 to 0.787 ulps of pi over KEPLER_M at every eccentricity from 0.5 to 1 - 1e-12,
which is the same value to three figures as the same solve on the platform library. The
substitution costs nothing at the consumer and the solve keeps a factor of 2.5 to its
bar. That is the measurement, not an extrapolation from the per-function bound: the
per-function bound does not by itself say what a solve that calls it four times per
iteration will do, and the solve was measured.

Against the platform library, which is what every kernel would otherwise call, the
distance is small and it runs both ways. Per function on the declared grid, these are
0.014 ulps closer to the reference than the library for the sine, equal for the cosine,
0.152 closer for the cube root, 0.200 further for the logarithm and 0.328 further for
the exponential; the largest of these is 0.8452 and the largest library value on the
same grids is 0.7279. Both sides are inside one ulp on every function, so both return a
value adjacent to the correctly rounded one and nothing that was accurate enough with
the library becomes inaccurate with these.

The purpose of the bound is not accuracy for its own sake. Bitwise mode compares a run
against another run of the same code, so bitwise agreement on its own is satisfied by
two backends agreeing on a wrong answer, and the accuracy bound is what rules that out.
A sub-ulp forward error establishes that both backends agree on a value adjacent to the
correctly rounded one, which is the strongest statement a `Float64` implementation
without an extended accumulator can make.

`TRIG_ARGUMENT_LIMIT` is 2^18, and above it the trigonometric functions return `NaN`
rather than a reduced argument the three-part split cannot carry. The condition is that
`x` be a multiple of 2^-34 and `n * PIO2_A` exact: `PIO2_A` carries 33 significant bits
with its lowest at 2^-32, `abs(n) <= 2^18 * 2/pi < 2^17.35`, so the product needs at most
50 bits and `x - n * PIO2_A` is a multiple of 2^-34 below 0.8 in magnitude, which is 34
bits. The Kepler solve's arguments are in `[-pi, pi]` and its half-angles in
`[-pi/2, pi/2]`, four orders below the limit.

## The contraction sites the first run found

The first cross-backend run disagreed by one ulp on the sine, on `sine_cosine` and on
the logarithm, and agreed on the cosine, the cube root and the exponential. Four
expressions were then rewritten, each one a rounded product feeding an add:
`e - n * PIO2_C` in the reduction, `hfsq + rr` and `hfsq - (...)` in the logarithm's
assembly, `z*z*C(z) - r*rlo` in the cosine core, and `c - y` with `t - t*(...)` in the
cube root. The second run agreed at every point of every declared grid.

The sine's only altered expression is the one in the reduction, and the logarithm's only
altered expressions are the two in its assembly, so the attribution is by construction.
The sine's case shows where such a difference becomes visible: `rlo` is of order 4e-16 at
the top of the range and the two forms of that expression differ by about 3e-32, which is
2.7e-16 ulps of a result of order one and invisible everywhere except at
`x = -4pi` and `x = 4pi`, where the true sine is about -4.9e-16 and one ulp of the result
is 1.2e-31. The grid's endpoints are what caught it.

A product that is exactly representable may be contracted without changing anything, and
three of those are left alone: `1.0 - 0.5*z` in the cosine core, `n * PIO2_B` in the
reduction, and `2.0*t` in the cube root's Newton steps all have an exact product, so the
fused and unfused forms return the same bits.

The cosine and the cube root agreed across backends in the first run while still carrying
a contractible site, so passing a grid is not evidence that no contractible site remains.
The audit has to be by construction over the source, which is why every multiply that
feeds an add in the module is written as an `fma` or a `nofuse_mul` and none is left
plain.

## Bitwise across the backends

Same source, the two backends, through `Backends.launch!` at workgroup 64, over the
declared grids. Ulp distance is the absolute difference between the two values'
monotonic bit-pattern orderings.

| function | points | bitwise mode | largest difference | fast mode | largest difference |
|---|---|---|---|---|---|
| sine | 6144 | yes | 0 | no | 1 |
| cosine | 6144 | yes | 0 | no | 1 |
| sine_cosine | 6144 | yes | 0 | no | 1 |
| cube_root | 4096 | yes | 0 | no | 1 |
| exponential | 4096 | yes | 0 | no | 1 |
| logarithm | 4096 | yes | 0 | no | 1 |

The fast-mode column is the positive control and it fires on all six: fast mode keeps the
platform library on each side and the two libraries differ by an ulp.

The identity in bitwise mode rests on `fma` being the correctly rounded single-rounding
operation on both backends, which IEEE 754 requires of `fusedMultiplyAdd`. That is
checked rather than assumed: the suite compares `fma(a, b, c)` against the same
expression at 300 bits over 2000 triples and asserts equality, with a control asserting
that `fma(a, b, c)` differs from `a * b + c` somewhere on the same set, so the check
cannot pass vacuously on a host where the two are the same operation.

## The Kepler solve

The form of `src/Orbit/kepler.jl`, with every multiply that feeds an add routed through
the barrier and every transcendental through `Backends`, so that the arithmetic and the
transcendentals switch separately. The mean anomaly arrives in `[-pi, pi]`, so `rem2pi`
is not reached. 4096 mean anomalies, both backends.

| eccentricity | arithmetic | transcendentals | bitwise | largest difference, ulps of pi |
|---|---|---|---|---|
| 0.5 | barrier | own polynomials | yes | 0.00 |
| 0.5 | plain | library | no | 1.00 |
| 0.5 | barrier | library | no | 1.00 |
| 0.9 | barrier | own polynomials | yes | 0.00 |
| 0.9 | plain | library | no | 1.00 |
| 0.9 | barrier | library | no | 1.00 |
| 0.99 | barrier | own polynomials | yes | 0.00 |
| 0.99 | plain | library | no | 1.25 |
| 0.99 | barrier | library | no | 1.25 |
| 0.999 | barrier | own polynomials | yes | 0.00 |
| 0.999 | plain | library | no | 1.00 |
| 0.999 | barrier | library | no | 1.00 |
| 1 - 1e-6 | barrier | own polynomials | yes | 0.00 |
| 1 - 1e-6 | plain | library | no | 1.00 |
| 1 - 1e-6 | barrier | library | no | 1.00 |
| 1 - 1e-9 | barrier | own polynomials | yes | 0.00 |
| 1 - 1e-9 | plain | library | no | 1.00 |
| 1 - 1e-9 | barrier | library | no | 1.00 |
| 1 - 1e-12 | barrier | own polynomials | yes | 0.00 |
| 1 - 1e-12 | plain | library | no | 1.50 |
| 1 - 1e-12 | barrier | library | no | 1.50 |

The fast-mode row is the positive control the row's acceptance names, and it reproduces
the 1.0 to 1.5 ulps of pi the two earlier findings measured. The third row is the
attribution: with the arithmetic already in bitwise mode and only the transcendentals
left on the library, the disagreement is the same value at every eccentricity to the
three figures reported. The transcendentals were the whole of it.

The solve's accuracy does not move. Against the 300-bit reference over 256 of the same
mean anomalies, on the processor backend:

| eccentricity | max ulps of pi, bitwise mode | max ulps of pi, fast mode |
|---|---|---|
| 0.5 | 0.642 | 0.642 |
| 0.9 | 0.779 | 0.779 |
| 0.99 | 0.643 | 0.643 |
| 0.999 | 0.658 | 0.658 |
| 1 - 1e-6 | 0.740 | 0.740 |
| 1 - 1e-9 | 0.787 | 0.787 |
| 1 - 1e-12 | 0.782 | 0.782 |

The reference is 250 bisection steps on `[-pi - 1, pi + 1]` followed by five Newton steps
on the stable residual, at 300 bits. Its control is its own residual: the largest
`abs(E - e sin E - M)` over the set is 3.93e-90, so the reference is the root.

## Every constant, with its disposition

No coefficient in this module is transcribed from a published minimax table, so none is
Sourced. Every one is Derived, computed at 300 bits and rounded once, and the derivation
and range of each is below.

| constant | disposition | derivation |
|---|---|---|
| `PIO2_A`, `PIO2_B`, `PIO2_C` | Derived | `pi/2` at 300 bits, split by taking each part in turn with its low 20 mantissa bits cleared, so the first two carry 33 significant bits; the third is the remainder rounded once. The residual left by the three parts is 1.0086e-37. |
| `TWO_OVER_PI` | Derived | `2/pi` at 300 bits, rounded once. |
| `TRIG_ARGUMENT_LIMIT` | Derived | 2^18, from the exactness condition set out above. |
| `SIN_SERIES` | Derived | `(-1)^(k+1)/(2k+3)!` for `k` in `0:7`, at 300 bits, rounded once; the series of the sine at zero, truncated where the next term is 8.35e-20 at `r = pi/4`. |
| `COS_SERIES` | Derived | `(-1)^k/(2k+4)!` for `k` in `0:7`, at 300 bits, rounded once; the series of the cosine at zero, truncated where the next term is 3.28e-21 at `r = pi/4`. |
| `LN2_A`, `LN2_B` | Derived | `ln(2)` at 300 bits, the first part with its low 20 mantissa bits cleared so it carries 33 significant bits, the second the remainder rounded once. Residual 1.3125e-27. |
| `LOG2_E` | Derived | `1/ln(2)` at 300 bits, rounded once. |
| `EXPONENTIAL_MAX` | Derived | 709.782712893384, the largest `Float64` whose exponential is finite. |
| `EXPONENTIAL_MIN` | Derived | -746.0, below `-1075 * ln(2) = -745.1332191019411`, at which the exponential is 2^-1075 and rounds to zero. |
| `EXP_SERIES` | Derived | `1/(k+2)!` for `k` in `0:11`, at 300 bits, rounded once; the series of the exponential at zero, truncated where the next term is 4.14e-18 at `abs(r) = ln(2)/2`. |
| `LOG_SERIES` | Derived | `2/(2j+3)` for `j` in `0:10`, at 300 bits, rounded once; the series of `(2 atanh(s) - 2s)/s` in `z = s^2`, truncated where the omitted contribution `s * 2 * z^11 / 25` is 1.97e-19 at `abs(s) = (sqrt(2) - 1)/(sqrt(2) + 1) = 0.17157287525380996`. |
| `SQRT_TWO` | Derived | `sqrt(2)` at 300 bits, rounded once; the crossover that puts the reduced significand in `[sqrt(2)/2, sqrt(2))`. |
| `CBRT_START` | Derived | the degree-five Chebyshev interpolant of `m^(1/3)` on `[1, 2]` at its six Chebyshev nodes, computed at 300 bits, converted to the monomial basis in `u = 2*(m - 1.5)` and rounded once. Its maximum relative error over `[1, 2]` is 1.7833744296869014e-6, which two Newton steps carry below the rounding floor. |
| `CBRT_TWO`, `CBRT_FOUR` | Derived | `2^(1/3)` and `2^(2/3)` at 300 bits, rounded once. |
| the 2^54 in `split_exponent` | Derived | the power of two that lifts a subnormal into the normals before its exponent field is read. |

The two identities the assembly rests on are derived rather than transcribed.

For the logarithm, with `f = m - 1` and `s = f/(2 + f)`, so that `2s = f(1 - s)` and
`f s = f^2/(2 + f) = (f^2/2)(1 - s)`: the series `log(1 + f) = 2 atanh(s) = 2s + sR`
with `R = 2(z/3 + z^2/5 + ...)` and `z = s^2` gives
`log(1 + f) = f - f s + s R = f - (f^2/2 - s(f^2/2 + R))`, which is the form the code
evaluates. Nothing in it cancels: `f` is exact, and the correction is of order `f^2`.

For the trigonometric functions, with the reduced argument carried as `r + rlo`:
`sin(r + rlo) = sin r + rlo cos r + O(rlo^2)` and `cos(r + rlo) = cos r - r_lo sin r +
O(rlo^2)`, with `sin r` and `cos r` from the series and the first-order terms taken as
`rlo` and `-r rlo`. `rlo` is below the ulp of `r`, so the omitted second-order term is
below 1e-32.

## What this changes

`src/Backends/transcendentals.jl` carries `sine`, `cosine`, `sine_cosine`, `cube_root`,
`exponential` and `logarithm`, each taking a `Backend` and reading `Backends.bitwise` to
choose between its polynomial and the platform library. `Float64` only: the coefficient
sets and the reduction splits are bit patterns of the precision they belong to, and a
`Float32` set is `fiddlybits-52v.7.13`.

`test/backends/bitwise_mode.jl`'s search for a transcendental call in the module's source
now skips `transcendentals.jl` and asserts the same thing of every other file, which is
the claim that is true once this row lands. `test/lint/lists/literals.toml` exempts
`Backends/transcendentals.jl` from `lint_literals` for the same reason the file is
`Float64` only.

`src/Orbit/kepler.jl` still calls the library and still writes its multiply-adds plain,
so the model's Kepler path is not yet bitwise across backends. The switched solve exists
only as the control in `test/backends/transcendentals.jl`. Wiring the model's own solve
is `fiddlybits-52v.7.14`.

`fiddlybits-52v.7.10` asks whether bitwise mode should route through `muladd` instead of
the `@noinline` barrier in general. This finding does not answer it and changes nothing
it would touch, and it bears on it in both directions. The barrier's cost through a
Horner chain is 0.081 ulps or less and twice negative, which is a weaker case for
replacing it than the earlier finding's axpy measurement suggested. A compensated step
cannot be expressed through the barrier at all, which is a stronger one. The two
statements are about different kernel shapes, and that is the question 52v.7.10 has to
decide.

## The probes

`/tmp/fb78/gen_coeffs.jl` prints the reduction splits and the series coefficients;
`/tmp/fb78/gen_cbrt3.jl` prints the Chebyshev fit and its maximum relative error at each
degree from four to nine. `/tmp/fb78/probe_cpu.jl` carries a second copy of all six
functions with the multiply-add route as a `Val` parameter, asserts that its `fma` route
reproduces the shipped functions bit for bit over every declared grid, and then measures
the three routes. `/tmp/fb78/probe_gpu.jl` runs the cross-backend comparison and the
Kepler table. All four were invoked as
`qrun -p gpu-share -- julia --startup-file=no --project=. <probe>` from the worktree root.
The suite at `test/backends/transcendentals.jl` carries the same grids, the same bar and
the same controls at the counts in the table above.
