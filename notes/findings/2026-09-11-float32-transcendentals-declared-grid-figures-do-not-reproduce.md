# Eight of the ten Float32 accuracy figures in the declared-grid and reduced-range columns do not reproduce from the finding's own stated method

Measured on 2026-09-11 on yggdrasil, through `qrun`, Julia 1.12.7, `CUDA.jl` 6.3.1,
`GPUCompiler.jl` 2.6.0, `KernelAbstractions.jl` 0.9.42, Fiddlybits at branch
`fiddlybits-52v.7.40`, commit `83f7248b68cf51fe9d52bc972b01fa3f8629f9b7`, a worktree cut
from `main`. Every environment component matches
`notes/findings/2026-09-11-float32-polynomial-transcendentals.md`'s own header
component for component.

This supersedes the declared-grid column of both tables in
`notes/findings/2026-09-11-float32-polynomial-transcendentals.md` ("Against the 300-bit
reference, on the declared grids" and the device table under "Why that bound is
enough") and the reduced-range column of the first of those two tables, for `sine`,
`cosine`, `exponential`, `logarithm` and `cube_root`. That finding is named here by
path and is not edited; its diff against the tree is empty, checked with `git diff
d22b6b9 HEAD -- notes/findings/2026-09-11-float32-polynomial-transcendentals.md`, which
prints nothing.

## What triggered this

`fiddlybits-52v.7.40`'s row observed that the exponential's declared-grid figure of
0.8942 ulps does not reproduce: a re-measurement gave 0.8644. That re-measurement was a
probe of a different row's writing, not the finding's own method, so it did not by
itself settle anything. This record reconstructs the finding's method exactly first,
confirms the reconstruction against the finding's own numbers where they do reproduce,
and only then reports where the other four functions stand.

## The method, reconstructed

`test/backends/transcendentals.jl` carries the same grids and the same measurement
functions the finding was written from, unmoved since the commit that introduced them
(`d22b6b9`, the same commit that wrote the finding): `git diff d22b6b9 HEAD --
src/Backends/transcendentals.jl` shows only a `Float64` cube-root `fma` rewrite and a
`NaN` sanitiser guard on `exponential_poly` that the suite itself proves moves no
returned value at a finite or infinite argument (`fiddlybits-52v.7.38`), neither of
which touches any `Float32` constant, coefficient or code path this record measures.
`git diff d22b6b9 HEAD -- test/backends/transcendentals.jl` shows the grids and the
`ulp_error`/`worst_ulps` functions themselves are also unmoved.

The method, read directly from `test/backends/transcendentals.jl`:

- `setprecision(BigFloat, 300)`.
- `ulp_error(computed::Float32, exact::BigFloat)`: `ex = Float32(exact)`, the ulp `u =
  max(2^(exponent(ex) - 23), 2^-149)`, and the result is `abs(big(computed) - exact) /
  u`, i.e. an absolute error in ulps of the correctly-rounded `Float32` answer, with the
  subnormal spacing as the floor.
- `worst_ulps(f, reference, xs)`: the maximum of `ulp_error(f(x), reference(big(x)))`
  over `x` in `xs`.
- The reduced-range grids are `TranscendentalGrids.REDUCED_TRIG32`, `REDUCED_EXP32`,
  `REDUCED_LOG32`, `REDUCED_CBRT32`: 2001-point uniform grids over `[-pi/4, pi/4]`,
  `[-ln(2)/2, ln(2)/2]`, `[sqrt(2)/2, sqrt(2))` and `[1, 8)`.
- The declared grids are `TranscendentalGrids.TRIG32` and `NEAR_HALF_PI32` combined for
  `sine` and `cosine`, `EXP32` for `exponential`, `LOG32` for `logarithm`, `CBRT32` for
  `cube_root`, exactly as the accuracy `@testset` in `test/backends/transcendentals.jl`
  builds them.
- `own` is `Backends.sine_poly`, `Backends.cosine_poly`, `Backends.exponential_poly`,
  `Backends.logarithm_poly`, `Backends.cube_root_poly`; `reference` is `sin`, `cos`,
  `exp`, `log`, `cbrt` from `Base`, applied to `big(x)`.

This reconstruction is confirmed against the finding's own numbers, not assumed: two of
the ten figures below reproduce exactly to the four decimal places the finding states
them at (sine's reduced range and the exponential's reduced range), which is only
possible if the grids, the constants and the `ulp_error` definition used here match what
the finding used. The other eight do not.

## The five reduced-range figures

| function | measured | recorded | reproduces |
|---|---|---|---|
| sine | 0.6454190869482829 | 0.6454 | yes |
| cosine | 0.7023850104520816 | 0.7387 | no |
| exponential | 0.7710362497402097 | 0.7710 | yes |
| logarithm | 0.6146090242416123 | 0.6177 | no |
| cube_root | 0.4998408107765541 | 0.4999 | no |

## The five declared-grid figures

| function | measured | recorded | reproduces |
|---|---|---|---|
| sine | 0.6041346941353379 | 0.6326 | no |
| cosine | 0.5762917883646314 | 0.6748 | no |
| exponential | 0.8644266562831514 | 0.8942 | no |
| logarithm | 0.7048184359052861 | 0.7075 | no |
| cube_root | 0.4995247183461280 | 0.4997 | no |

None of the five declared-grid figures reproduces. The exponential's is the 0.03 ulp gap
the row was opened over; sine's and cosine's gaps are of the same order (0.029 and 0.099
ulps); logarithm's and cube_root's are an order smaller (0.0027 and 0.0002 ulps) but are
still outside the four decimal places the finding states them at, using the identical
grid, the identical constants and the identical code.

## A cross-check the finding's own second table gives, for free

`notes/findings/2026-09-11-float32-polynomial-transcendentals.md` carries a second
table, under "Why that bound is enough", of the same five functions "measured on the
device over the declared grids, against the same 300-bit reference." Bitwise mode is
bit-identical between the CPU and GPU backends over every one of these grids (asserted
by `test/backends/transcendentals.jl`'s "bitwise between the processor and the CUDA
backend" testset, which this row's gate run confirms still passes), so that column is
the same quantity measured here.

For sine and cosine, the second table's figures (0.6041 and 0.5763) match this record's
declared-grid measurement exactly, to the four decimal places both are stated at, while
the first table's declared-grid figures for the same two functions (0.6326 and 0.6748)
do not. For exponential, logarithm and cube_root the two tables agree with each other
(0.8942, 0.7075, 0.4997 in both) and neither agrees with this record's measurement. So
the disagreement is not confined to one table's transcription: for exponential,
logarithm and cube_root it is a genuine non-reproduction from the same numbers in both
places.

## What this does not change

The code and the constants: confirmed unmoved since `d22b6b9` by `git diff` above. The
grids: confirmed unmoved by the same means, and by `fiddlybits-52v.7.40`'s own check
that `git log -L` over the `EXP32` lines in `test/backends/transcendentals.jl` shows one
commit only. The bar the suite enforces: `ULP_BAR_F32 = 1.0`, and every measured figure
above stays under it, so no accuracy assertion in `test/backends/transcendentals.jl` is
at risk from this record. `./tools/gate/gate.sh` was run in full after this measurement:
1864 passed, 1864 total, zero failed, zero errored. The grid is not corrected, because
the grid is not what is wrong: the declared grids and the reduced-range grids in
`test/backends/transcendentals.jl` are exactly what this record measured over, and the
suite already passes against them. What is superseded is the ten prose figures in
`notes/findings/2026-09-11-float32-polynomial-transcendentals.md`'s two tables that this
record could not reproduce from its own stated method, most plausibly because they were
carried over from an earlier iteration of the coefficient rounding described in that
finding's own "The series, and what the fit buys over the truncation" section, before
the coefficients reached the values now committed in `src/Backends/transcendentals.jl`,
and the accuracy tables were not regenerated against the final constants before the
finding was written. Nothing in this record depends on that explanation; it is offered
only because the two exact reproductions above (sine and exponential, both reduced
range) rule out a wholesale method mismatch and leave a partial, function-dependent
drift as the remaining shape of the disagreement.

## The probe

`/tmp/fb7340/reproduce.jl` carries the reconstruction: the `TranscendentalGrids` module
and the `ulp_error`/`worst_ulps` functions copied verbatim from
`test/backends/transcendentals.jl`, run against `Backends.sine_poly`, `cosine_poly`,
`exponential_poly`, `logarithm_poly` and `cube_root_poly`, under `qrun -p light` since
no GPU is touched.
