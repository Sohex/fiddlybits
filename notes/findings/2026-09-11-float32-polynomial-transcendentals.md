# The Float32 transcendentals are a different fit, not the Float64 set rounded, and they beat the device library on every function

Measured on 2026-09-11 on yggdrasil, through `qrun`, Julia 1.12.7, `CUDA.jl` 6.3.1,
`GPUCompiler.jl` 2.6.0, `KernelAbstractions.jl` 0.9.42, Fiddlybits at branch
`fiddlybits-52v.7.13` cut from `382e65b`. Every 300-bit reference is the same quantity
at `setprecision(BigFloat, 300)`, rounded once to `Float32`.

Decision 0011 runs production profiles at `Float32`, and `Backends.certify` compares a
candidate kernel at `Float32` against the same kernel at `Float64`, so a kernel with a
transcendental in it could not be certified at all while
`src/Backends/transcendentals.jl` carried only the `Float64` set: a `Float32` argument
was a `MethodError`. This row built the `Float32` set, and it is a second fit rather
than the first one converted. The three things a precision fixes are the truncation
degree, the coefficient bit patterns and the number of pieces the argument reduction
splits a constant into, and all three come out different.

## What carries and what does not

The `Float64` set's truncation degrees are chosen where the next term falls below a
fraction of the `Float64` ulp, which is 2^-53 and not 2^-24, so every one of them is
four to eight terms longer than `Float32` can use. Its reduction splits carry 33
significant bits in the parts whose products with the quadrant index must be exact,
which a 24-bit significand cannot hold at all; rounded to `Float32` the leading part
carries 24, and `n * PIO2_A` then needs up to `12 + 24 = 36` bits and is inexact
already at a quadrant index of 3, and at every index that is not a power of two after
it. And rounding the coefficients of a minimax fit to a narrower format gives a
polynomial that is no longer the minimax polynomial of that format, with the truncation
degree still chosen for the wrong one.

So the sets below are derived at `Float32`: each series is the Remez minimax polynomial
of its correction function at the degree `Float32` needs, computed at 300 bits, and the
reduction constants are split into as many pieces as `Float32` products can carry
exactly, which is more pieces of fewer bits than `Float64` uses.

## The reduction splits

`pi/2` is split into four parts against `TRIG_ARGUMENT_LIMIT_F32 = 4096`. The quadrant
index `n = round(x * 2/pi)` is then at most 2608, which is 12 significant bits, so each
part whose product with `n` must be exact carries at most `24 - 12 = 12` bits:

| part | value | significant bits | leading | lowest |
|---|---|---|---|---|
| `PIO2_A_F32` | 1.5708008 | 12 | 2^0 | 2^-11 |
| `PIO2_B_F32` | -4.4535846e-6 | 12 | 2^-18 | 2^-29 |
| `PIO2_C_F32` | -8.706138e-10 | 12 | 2^-31 | 2^-42 |
| `PIO2_D_F32` | 6.223372e-14 | 22 | 2^-44 | 2^-65 |

The residual `pi/2 - (A + B + C + D)` is 2.022266e-21. Three parts of this shape reach
only 2^-49 and the fourth is what makes the reduction stand up at the arguments that
decide it, measured below. The `Float64` set reaches 1.0086e-37 in three parts because
its parts are 33 and 33 and 53 bits; the `Float32` arithmetic cannot spell any of those.

`ln(2)` is split into two parts against an exponent index of at most 150, which is 8
significant bits: `LN2_A_F32 = 0.69314575` carries 15 significant bits with its lowest
at 2^-15, so `k * LN2_A_F32` is exact, and `LN2_B_F32 = 1.4286068e-6` carries 23. The
residual is 5.497923e-14, which at the largest index is 8.2e-12 of a reduced argument
whose own ulp is 3e-8, so two parts are enough here and a third would buy nothing.

### What the split makes exact, over every argument in range

Over all 104263718 `Float32` arguments in `[pi/4, 4096]`, at which the largest quadrant
index reached is 2608:

- `r0 = fma(-n, PIO2_A_F32, x)` is exact at every one of them. Zero exceptions.
- `n * PIO2_B_F32` and `n * PIO2_C_F32` are exactly representable at every one of them.

That is the whole design condition, checked by enumeration rather than by argument. The
two subtractions that follow are not exact, which is why the assembly carries both
rounding errors through `two_sum` and folds them into the low word together with
`n * PIO2_D_F32`. An earlier version of this row's code took only the second
subtraction's error, on the reasoning that the first is exact because `r0` lies on a
2^-24 grid; that reasoning was wrong, because `PIO2_B_F32`'s lowest bit is at 2^-29 and
not 2^-24, and it cost 1.0193 ulps on the sine and 1.3167 on the cosine before the
first `two_sum` was put back. The measurement found it; reading the source did not.

### What the fourth part buys

Relative error of the reduced argument `r + rlo` against `x - n * pi/2` at 300 bits,
over the 5214 `Float32` arguments nearest the multiples of `pi/2` in range, which are
the hardest arguments a reduction meets:

| split | max relative error of the reduced argument |
|---|---|
| the four parts above | 2.4352e-11 |
| the same, with `PIO2_D_F32` dropped | 2.3938e-03 |
| `PIO2_A`, `PIO2_B`, `PIO2_C` rounded to `Float32` | 1.6837e+03 |

The third row is the "rounded copy" hypothesis run as an experiment: the `Float64`
split converted to `Float32` does not reduce the argument at all, it loses it, because
its leading part carries 24 significant bits at `Float32` and `n * PIO2_A` is then
inexact already at `n = 3`. Both lower rows are positive controls in
`test/backends/transcendentals.jl`.

## The series, and what the fit buys over the truncation

Each correction function is fitted by Remez exchange at 300 bits and then rounded to
`Float32` from the highest degree down, refitting the free coefficients after each
rounding so that a coefficient's rounding is absorbed by the ones below it. The error
column is the maximum of `|P - f|` over the reduced range for the rounded coefficients,
converted to ulps of the returned value by the prefactor the correction enters with:
0.6851 for the sine, 0.5381 for the cosine, 0.1699 for the exponential and 0.01472 for
the logarithm.

| set | coefficients | this fit | the Taylor truncation of the same length | one coefficient shorter, fitted | one shorter, Taylor |
|---|---|---|---|---|---|
| `SIN_SERIES_F32` | 4 | 0.0577 ulp | 0.0571 ulp | 0.2855 ulp | 7.4475 ulp |
| `COS_SERIES_F32` | 4 | 0.0112 ulp | 0.0112 ulp | 0.0474 ulp | 0.5922 ulp |
| `EXP_SERIES_F32` | 6 | 0.0103 ulp | 0.1225 ulp | 0.3350 ulp | 2.9493 ulp |
| `LOG_SERIES_F32` | 4 | 0.0060 ulp | 0.0296 ulp | 0.0491 ulp | 1.4294 ulp |

The `Float64` set uses 8, 8, 12 and 11 coefficients for the same four functions.

Two things in that table are worth stating plainly rather than leaving to be read off.
At the chosen lengths the fit beats the truncation by a factor of 12 on the exponential
and 5 on the logarithm and ties it on the two trigonometric sets, because there the
error has already fallen to the floor set by rounding the leading coefficient to
`Float32` (5.02e-9 for the sine, which is half an ulp of 1/6 times `(pi/4)^3`), and
below that floor a better polynomial buys nothing. Where the fit decides the question
is one coefficient shorter: at three coefficients the fitted sine is 0.2855 ulps and
the truncated one is 7.4475, a factor of 26, and the same at three for the logarithm is
0.0491 against 1.4294. The truncation is not usable at any length the fit is usable at
minus one. That is the operational meaning of deriving at the format rather than
converting: it is what decides how many terms the kernel evaluates.

The chosen lengths are the ones whose fit error is at or just above that rounding
floor, so the series contributes under 0.06 ulps everywhere and the measured error is
the evaluation's roundings rather than the polynomial's truncation.

The cube root's starting value is fitted the same way in the relative error, and the
degree is decided by what the iteration that follows needs rather than by the fit:

| degree | coefficients | relative error of the rounded fit |
|---|---|---|
| 2 | 3 | 6.3609e-4 |
| 3 | 4 | 1.5137e-4 |
| 4 | 5 | 1.6432e-5 |

One Newton step squares the relative error, so the degree-two start reaches 4e-7 after
one step, and the final step on a residual formed exactly by `fma` squares that again,
which is 1.6e-13 and far under the 6e-8 rounding floor. The `Float32` cube root
therefore runs a three-coefficient start, one Newton step and one compensated step,
where the `Float64` one runs a six-coefficient start and two Newton steps. Its measured
error says the shorter chain is the right one: 0.50000402 ulps over every `Float32` in
`[1, 8)`, which is the correctly rounded result everywhere but for four parts in a
million of an ulp.

## Accuracy

### Against the 300-bit reference, on the declared grids

The bar is one ulp of `Float32`: the returned value is one of the two `Float32` values
adjacent to the exact result. It is the same bar the `Float64` set was held to and it
was fixed before any evaluation.

| function | reduced range | declared grid | nearest the multiples of pi/2 | host library, declared grid |
|---|---|---|---|---|
| sine | 0.6454 | 0.6326 | 0.5000 | 0.5002 |
| cosine | 0.7387 | 0.6748 | 0.4998 | 0.4999 |
| exponential | 0.7710 | 0.8942 | | 0.7709 |
| logarithm | 0.6177 | 0.7075 | | 0.5090 |
| cube_root | 0.4999 | 0.4997 | | 0.4997 |

### Against the platform library, over every Float32 in the domain

`Float32` is a format whose domain can be enumerated, so the bound does not have to be
stated over a sample. The reference for the sweeps is the `Float64` platform library,
which is admissible here because rounding it to `Float32` gives the correctly rounded
`Float32` result at every point of every declared grid, by at most 0.499952 ulps and
never 0.5, and its own error is under 2^-29 ulps of `Float32`.

| function | arguments swept | range | max ulps | at |
|---|---|---|---|---|
| sine | 268435457 | `[2^-20, 4096]` | 0.8140 | 264.702 |
| sine, negative | 268435457 | `[-4096, -2^-20]` | 0.8140 | -264.702 |
| cosine | 268435457 | `[2^-20, 4096]` | 0.8027 | 52.6272 |
| cosine, negative | 268435457 | `[-4096, -2^-20]` | 0.8027 | -52.6272 |
| exponential | 263287320 | `[2^-25, 88.72283]` | 0.9781 | 5.22742 |
| exponential, negative | 265289729 | `[-104, -2^-25]` | 0.9785 | -5.83756 |
| exponential | 2228225 | `[-104, -87]`, subnormal results | 0.7505 | -87.9446 |
| logarithm | 16777216 | `[0.5, 2)` | 0.7555 | 0.633045 |
| logarithm | 8388608 | `[2^-149, 2^-126)`, subnormal arguments | 0.5026 | 2.59083e-40 |
| logarithm | 8388608 | `[2^127, 3.40282e38]` | 0.5026 | 2.39179e38 |
| logarithm | 18153472 | every binade, 65536 significands each | 0.7363 | 0.388302 |
| cube_root | 25165824 | `[1, 8)` | 0.50000402 | 7.00691 |

Three of these sweeps are exhaustive over the whole domain rather than over the stated
interval, because the remaining arguments reduce to them exactly:

- The cube root computes `scale_two(t, q)` on a reduced argument in `[1, 8)`, and
  `scale_two` is an exact scaling by a power of two whose result never reaches the
  subnormals, so the sweep over `[1, 8)` decides every finite argument. The largest
  `Float32` subnormal argument returns 1.1190347e-15 and the binade sweep over
  2^-149 to 2^127 also maxes at 0.5000.
- Below 2^-20 the sine returns its argument unchanged at all 532480 `Float32` values
  sampled there, and `|sin(x) - x| <= |x|^3/6 < |x| * 2^-42` on that interval, which is
  under half an ulp, so returning the argument is the correctly rounded answer. The
  cosine over the same interval is within 3.1e-5 ulps of 1.
- Below 2^-25 the exponential is within 0.5000 ulps at 1024000 values sampled across
  every binade down to 2^-149.

The two intervals that are sampled rather than enumerated are the logarithm's 254
binades, where the significand is enumerated in the binade the reduction makes hardest
(`[0.5, 2)`, where `k` is zero and the result is smallest) and sampled at 65536
significands elsewhere, and the exponential below 2^-25.

## Why that bound is enough

The bound is 0.9785 ulps, and it is the exponential that holds it. For the other four
functions it is 0.8140 or better and for the cube root it is the correctly rounded
result. Four arguments, in order of how much they decide.

**On the backend production runs on, this is more accurate than the alternative.**
Decision 0011 is GPU-first and decision 0029's fast mode leaves each backend on its own
library, so the thing a `Float32` kernel would otherwise call is the CUDA device
library. Measured on the device over the declared grids, against the same 300-bit
reference:

| function | this set, on the device | the device library | the host library |
|---|---|---|---|
| sine | 0.6041 | 1.1649 | 0.5000 |
| cosine | 0.5763 | 1.1142 | 0.4998 |
| cube_root | 0.4997 | 0.8708 | 0.4997 |
| exponential | 0.8942 | 1.6300 | 0.7709 |
| logarithm | 0.7075 | 0.7793 | 0.5090 |

The device library is outside one ulp on the sine, the cosine and the exponential, and
this set is inside it on all five and closer to the reference than the device library
on all five. So substituting these polynomials into an FP32 kernel does not cost
accuracy against what it replaces, it buys accuracy, and it buys cross-backend identity
at the same time. This is a different situation from `Float64`, where the earlier row
measured its own set as at best equal to the library and at worst 0.328 ulps further
out, and had to argue that the cost was worth the identity. At `Float32` there is no
cost to argue about on the backend that matters.

**The consumer that exists is the single-precision certification.** `Backends.certify`
runs a candidate kernel at `Float32` and at `Float64` and asks whether the divergence
between them stays inside an envelope built from a per-step roundoff the caller
declares, which for a `Float32` candidate is of the order of one `Float32` rounding
unit per step. A transcendental accurate to under one ulp injects at most one rounding
unit per call, which is the same order as the arithmetic around it, so the declared
roundoff stays an honest model of the step. The device library at 1.63 ulps would
inject 63 percent more than the declared unit, and a certification run against it would
be measuring the library rather than the kernel. Before this row the question did not
arise, because a step function calling a transcendental could not be run at `Float32`
at all: `Backends.sine(x::Float32, b)` was a `MethodError`, which is decision 0011's
"no silent widening" working as intended and also a hard stop on the certification the
plan asks for.

**The bound is a maximum and not a sample.** Bitwise mode's value is fixed by IEEE 754
rather than by the host, since every operation in these functions is a correctly
rounded `+`, `-`, `*`, `/` or `fma`, so the number in the sweep table is the largest
error the function can return on any backend at any argument in the swept set, and the
swept set is every `Float32` in the domain for the sine, the cosine, the cube root and
the exponential above 2^-25. There is no distribution here whose tail might be worse.

**The truncation is not what decides it.** Every series contributes under 0.06 ulps and
the reduction contributes 2.4e-11 relative at the arguments that stress it most, so the
measured error is the roundings of the evaluation. That matters because it is the part
that cannot be bought down by a longer polynomial: the exponential's 0.9785 is a half
ulp from rounding `1 + y` into the result, which is the final rounding and is not an
error at all, plus about a quarter of an ulp from carrying the reduced argument in one
`Float32` rather than two. Carrying it in two, as the trigonometric path does, is what
would buy the rest, at the cost of an extra `two_sum` in the hottest of the six
functions. The measurement says the bar is met without it; the option is recorded here
rather than taken.

## Bitwise across the backends

Same source, the two backends, through `Backends.launch!` at workgroup 64, over the
declared `Float32` grids.

| function | points | bitwise mode | largest difference | fast mode | largest difference |
|---|---|---|---|---|---|
| sine | 8288 | yes | 0 | no | 1 |
| cosine | 8288 | yes | 0 | no | 1 |
| sine_cosine | 8288 | yes | 0 | no | 1 |
| cube_root | 4096 | yes | 0 | no | 1 |
| exponential | 4096 | yes | 0 | no | 2 |
| logarithm | 4096 | yes | 0 | no | 1 |

The fast-mode column is the positive control and it fires on all six. Its largest
difference at `Float32` reaches 2 ulps on the exponential, where the `Float64` row
measured 1 ulp for every function: the two libraries are further apart at `Float32`
than at `Float64`, which is the same fact as the device library's 1.63 ulps above.

The `Float64` set was run on the same GPU probe and is still bitwise across the
backends, so nothing this row added disturbed it.

No expression in the `Float32` code had to be rewritten to reach identity, unlike the
first `Float64` run which found four contraction sites: every multiply that feeds an
add was written as an `fma` from the start, which is decision 0044's rule, and
`Backends.nofuse_mul` is used at exactly one place for the reason its narrowed role
describes. `cube_root_poly`'s `c = nofuse_mul(p, t)` needs a separately rounded product
because the `c - y` beside it is the residual of a compensated step: fusing the two
would compute `fma(p, t, -y)`, a different residual, and the error terms `ep` and `ec`
that the step is built on would no longer describe it.

## Every constant, with its disposition

No coefficient here is transcribed from a published table, so none is Sourced. Every
one is Derived, computed at 300 bits.

| constant | disposition | derivation |
|---|---|---|
| `PIO2_A_F32`, `PIO2_B_F32`, `PIO2_C_F32` | Derived | `pi/2` at 300 bits, taken in turn at 12 significant bits each, which is `24 - 12` for a quadrant index of at most 12 bits. |
| `PIO2_D_F32` | Derived | the remainder after the first three, rounded once to `Float32`; 22 significant bits. Residual 2.022266e-21. |
| `TWO_OVER_PI_F32` | Derived | `2/pi` at 300 bits, rounded once. |
| `TRIG_ARGUMENT_LIMIT_F32` | Derived | 2^12, the largest power of two at which the quadrant index still fits in 12 bits and each of the three exact-product parts still carries 12. The split's contribution at the `Float32` arguments nearest the multiples of `pi/2` is then 0.0023 ulps of the returned value, against 0.0947 ulps at 2^13, where the index takes 13 bits and each part loses one. |
| `SIN_SERIES_F32` | Derived | the degree-three Remez minimax polynomial in `z = r^2` of `(sin(r) - r)/r^3` over `abs(r) <= pi/4`, at 300 bits, rounded to `Float32` from the top down with the free coefficients refitted after each rounding. Maximum 5.0206e-9, which is 0.0577 ulps of the result. |
| `COS_SERIES_F32` | Derived | the same construction for `(cos(r) - 1 + r^2/2)/r^4`. Maximum 1.2437e-9, 0.0112 ulps. |
| `LN2_A_F32` | Derived | `ln(2)` at 300 bits at 16 significant bits, of which 15 are set, so its product with an exponent index of at most 8 bits is exact. |
| `LN2_B_F32` | Derived | the remainder, rounded once to `Float32`. Residual 5.497923e-14. |
| `LOG2_E_F32` | Derived | `1/ln(2)` at 300 bits, rounded once. |
| `EXPONENTIAL_MAX_F32` | Derived | 88.72283, the largest `Float32` whose exponential is finite in `Float32`; `ln` of the largest `Float32` is 88.7228390521. The function returns 3.4027985e38 there and `Inf32` at the next `Float32` up. |
| `EXPONENTIAL_MIN_F32` | Derived | -104.0, below `-150 * ln(2) = -103.9720770840`, at which the exponential is 2^-150 and rounds to zero. |
| `EXP_SERIES_F32` | Derived | the degree-five Remez minimax polynomial in `r` of `(exp(r) - 1 - r)/r^2` over `abs(r) <= ln(2)/2`, rounded the same way. Maximum 3.6022e-9, 0.0103 ulps. |
| `LOG_SERIES_F32` | Derived | the degree-three Remez minimax polynomial in `z = s^2` of `(2*atanh(s) - 2s)/(s*z)` over `abs(s) <= (sqrt(2) - 1)/(sqrt(2) + 1)`, rounded the same way. Maximum 2.4427e-8, 0.0060 ulps. |
| `SQRT_TWO_F32` | Derived | `sqrt(2)` at 300 bits, rounded once. |
| `CBRT_START_F32` | Derived | the degree-two Remez minimax polynomial of `m^(1/3)` in the relative error over `[1, 2]`, in `u = 2*(m - 1.5)`, rounded the same way. Maximum relative error 6.3609e-4. |
| `CBRT_TWO_F32`, `CBRT_FOUR_F32` | Derived | `2^(1/3)` and `2^(2/3)` at 300 bits, rounded once. |
| the 2^24 in `split_exponent` | Derived | the power of two that lifts a `Float32` subnormal into the normals before its exponent field is read. |

The identities the assembly rests on are the `Float64` set's, unchanged: the logarithm's
`log(1+f) = f - (f^2/2 - s(f^2/2 + R))` and the trigonometric first-order corrections in
`rlo` are derived in
`notes/findings/2026-09-11-polynomial-transcendentals-for-bitwise-mode.md` and hold at
any precision. What this row re-derived is the coefficients, the degrees and the splits.

## The Float64 set is unchanged, and now says so itself

The diff of `src/Backends/transcendentals.jl` removes three lines, all of them the
sentence in the closing docstring that said the module was `Float64` only. Every
`Float64` constant, every `Float64` method and every literal in them is byte for byte
what it was.

Better than a diff, the suite now states what the `Float64` set is rather than only
that it did not move: `test/backends/transcendentals.jl` re-derives `PIO2_A`, `PIO2_B`,
`PIO2_C`, `LN2_A`, `LN2_B`, `TWO_OVER_PI`, `LOG2_E`, `SQRT_TWO`, `CBRT_TWO`,
`CBRT_START` and all four `Float64` series from the rules their dispositions record,
at 300 bits, and asserts identity with `===`. Eleven of the twelve reproduce exactly.

The twelfth does not. `CBRT_FOUR` is 1.5874010519681994 and `Float64(4^(1/3))` at 300
bits is 1.5874010519681996, one ulp higher; `cbrt(4.0)` and `CBRT_TWO^2` both give the
higher value. The constant scales a starting value whose own relative error is 1.78e-6
and which two Newton steps and a compensated step carry below the rounding floor, so no
returned value is expected to move, and this row does not move it because its acceptance
is that the `Float64` set stays bit for bit as it is. The suite asserts the present
value as `prevfloat` of the derived one, so the discrepancy is recorded in the place it
lives rather than papered over, and `fiddlybits-52v.7.26` carries the correction and the
re-measurement.

## What this changes

`src/Backends/transcendentals.jl` carries both precisions, selected by method signature.
`Backends.sine`, `cosine`, `sine_cosine`, `cube_root`, `exponential` and `logarithm`
each take `Float64` or `Float32`; anything else is still a `MethodError` at the call
site and no call widens. An FP32 kernel with a transcendental in it can now be written,
run on both backends bitwise, and certified.

`test/lint/lists/literals.toml` names the nineteen new constants in the
`precision_pinned` entry decision 0045 defines. That is the mechanism working as that
record describes: the entry was not widened by a pattern or by a second file exemption,
each new table was declared, and a literal written anywhere else in the file is still
refused. The control was run by hand as well as by the suite's fixtures: a `Float32` bit
pattern inserted in `two_sum`'s body is flagged at its line, and removing it clears the
lint.

Nothing outside those three files and this finding is touched. `src/Orbit/kepler.jl` is
still `Float64` and still on the fusion barrier, which `fiddlybits-52v.7.21` moves.

## The probes

`/tmp/fb713/split_study.jl` sweeps the argument limit against the piece count and the
worst `Float32` argument near a multiple of `pi/2`, which is what fixed the limit at
2^12 and the count at four. `/tmp/fb713/remez.jl` is the Remez exchange in `BigFloat`
with the top-down rounding; `/tmp/fb713/degrees.jl` prints the degree study and the
Taylor comparison; `/tmp/fb713/gen_final.jl` prints every constant in source form with
its bit count and its fit error. `/tmp/fb713/probe_cpu32.jl` carries the 300-bit
measurement, the library comparison and the exactness enumeration;
`/tmp/fb713/sweep32.jl`, `/tmp/fb713/sweep32b.jl` and `/tmp/fb713/shoulder.jl` carry the
exhaustive sweeps; `/tmp/fb713/redacc.jl` carries the reduced-argument comparison of the
three splits; `/tmp/fb713/probe_gpu32.jl` carries the cross-backend run and the device
library measurement. The coefficient generators ran under `qrun -p light`, the
cross-backend probe under `qrun -p gpu-share`.
