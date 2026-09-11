# muladd fuses or not according to what surrounds it, even on a host that has the instruction; in the fast arm that costs nothing and returns the Kepler solve's accuracy, and the cross-backend control the change silenced was a sample too small to see a one-in-a-hundred difference

Measured on 2026-09-11 on yggdrasil, through `qrun -p gpu-share` (one share of the RTX
4090), Julia 1.12.7, `CUDA.jl` 6.3.1, `GPUCompiler.jl` 2.6.0, `KernelAbstractions.jl`
0.9.42, Fiddlybits at branch `fiddlybits-52v.7.28` cut from
`8d5a455`. Every reference root is the 300-bit bisection-and-Newton root of
`test/orbit/runtests.jl`, and every error is the worst over the sample of
`abs(E - Eref)` in ulps of `Float64(pi)`, which is `eps(Float64(pi))`.

`notes/findings/2026-09-11-fma-against-the-fusion-barrier-in-bitwise-mode.md` measured
that `muladd` unfuses on a code-generation target with no fused multiply-add
instruction, which is the measurement decision 0044 refuses `muladd` on. Decision
0044's opening paragraph scopes its rule to source compiled for bitwise mode and then
ends with an unscoped sentence, `muladd` is used nowhere. `fiddlybits-52v.7.21` read
that sentence literally and moved `src/Orbit/kepler.jl`'s polynomials off Base's
`@evalpoly`, which compiles to `muladd`, onto plain unfused arithmetic in fast mode as
well as onto `fma` in bitwise mode. This row measured what the fast arm of that switch
costs and what the three spellings actually are.

## The three spellings on a host that has the instruction

1000000 triples `a = 1 + 3i/n`, `b = 1 + mod(7i, n)/n`, `c = -(a b)(1 + i/2n)` with
`n = 1000000`, on the host alone, no Fiddlybits and no device. Each cell counts the
triples at which the spelling differs from `fma(a, b, c)`, which is the once-rounded
value by IEEE 754 clause 5.4.1:

| the three spellings are | `a * b + c` differs from `fma` | `muladd` differs from `fma` |
|---|---|---|
| each behind its own `@noinline` call | 740912 / 1000000 | 0 / 1000000 |
| `muladd` and `fma` inlined, no plain form present | - | 0 / 1000000 |
| all three inlined in one loop body | 740912 / 1000000 | 740912 / 1000000 |

`muladd` is the once-rounded value in the first two rows and the twice-rounded value in
the third, on one host, at one optimisation level, with the same three arguments. The
third row differs from the first two only in that the same product is also written
plainly a line away, which lets the compiler share one `fmul` between the two
expressions and then decline to contract it. So `muladd`'s value is not a function of
its own source text even where the instruction exists: it is a function of what
surrounds it. This is the same defect decision 0044 refuses `muladd` for, one step
worse than the form 0044 measured, which needed a different target to show it.

`a * b + c` is likewise not a function of its source: it is twice rounded on the
processor, where nothing contracts by default, and once rounded on the device, where
`-nvptx-fma-level=1` contracts unconditionally
(`notes/findings/2026-09-11-gpucompiler-unconditional-fma-contraction.md`). Of the
three spellings only `fma` has one value fixed by the standard. Both of the others
return either the once-rounded or the twice-rounded value, and never anything else, so
neither can be worse than the plain chain and neither can be better than `fma`.

## The Kepler solve, worst error over `hard_region(e, 256)`

`hard_region(e, n)` is `test/orbit/runtests.jl`'s sample: eccentric anomalies spaced
logarithmically from `1e-8` to `pi/4` with the mean anomaly derived from each at 300
bits. Three states of `src/Orbit/kepler.jl`: `pre` is `1c65c53^`, the solve before
`fiddlybits-52v.7.21`, where bitwise mode was the fusion barrier and fast mode was a
plain multiply and a plain add with `@evalpoly`'s `muladd` inside the polynomials;
`plain` is `1c65c53`, where `Orbit.fma_add`'s bitwise arm is `fma` and its fast arm is
`a * b + c`; `muladd` is this row, where the fast arm is `muladd(a, b, c)` and the
bitwise arm is unchanged.

Fast mode, on `Backends.CPU(1)`, in ulps of pi:

| e | pre | plain | muladd |
|---|---|---|---|
| 0.9 | 0.58623 | 0.58623 | 0.33623 |
| 0.99 | 0.58623 | 0.58623 | 0.58623 |
| 0.999 | 0.48143 | 0.48143 | 0.48143 |
| 1 - 1e-6 | 0.51857 | 0.51857 | 0.51857 |
| 1 - 1e-9 | 0.37205 | 0.62205 | 0.37205 |
| 1 - 1e-12 | 0.40455 | 0.40455 | 0.41972 |
| worst of the six | 0.58623 | 0.62205 | 0.58623 |

Bitwise mode, on `Backends.CPU(1; bitwise = true)`, in ulps of pi:

| e | pre | plain | muladd |
|---|---|---|---|
| 0.9 | 0.41377 | 0.41377 | 0.41377 |
| 0.99 | 0.66377 | 0.66377 | 0.66377 |
| 0.999 | 0.48143 | 0.48143 | 0.48143 |
| 1 - 1e-6 | 0.66377 | 0.66377 | 0.66377 |
| 1 - 1e-9 | 0.37205 | 0.37205 | 0.37205 |
| 1 - 1e-12 | 0.40455 | 0.41972 | 0.41972 |

Every value is inside the bar of 2 ulps of pi that `system.kepler_period` carries, and
every relative error is below 5.1e-16 against the registered 1e-15, in all three
states.

The bitwise column does not move between `plain` and `muladd`, because the bitwise arm
is `fma` in both. So the bitwise regression at `1 - 1e-12`, 0.40455 to 0.41972, is the
barrier-to-`fma` move of decision 0044 and not the `muladd` sentence: it is the price
of the once-rounded chain being the same chain on every target, paid once, in the
debugging oracle.

The fast column's regression at `1 - 1e-9`, 0.37205 to 0.62205, is the `muladd`
sentence and comes back in full. At 0.9 the fast path ends better than it has ever
been, 0.58623 to 0.33623, because the sites that were a bare product and a bare add
before `fiddlybits-52v.7.21` are now fused as well. At `1 - 1e-12` the fast path ends
0.015 ulps worse than `pre` and equal to bitwise mode, which is where a fused fast arm
has to land on a host whose `muladd` is `fma`.

## The cross-backend control, and why 256 points was not enough

`test/orbit/runtests.jl` asserts that the solve is bitwise between the processor and
the CUDA backend in bitwise mode, with a positive control that fast mode is not. With
the fast arm on `muladd` the control fell silent at two of the six eccentricities on a
256-point sample. Elements of the sample at which the two backends' fast-mode results
differ:

| e | n = 256 | n = 1024 | n = 4096 | 256 points at four whole-turn shifts |
|---|---|---|---|---|
| 0.9 | 3 | 6 | 37 | 14 / 1024 |
| 0.99 | 3 | 10 | 48 | 16 / 1024 |
| 0.999 | 0 | 7 | 20 | 6 / 1024 |
| 1 - 1e-6 | 2 | 1 | 28 | 12 / 1024 |
| 1 - 1e-9 | 0 | 5 | 33 | 12 / 1024 |
| 1 - 1e-12 | 2 | 11 | 33 | 6 / 1024 |

The fast-mode backends differ at about one point in a hundred, so a 256-point sample
draws two or three differing points at best and none at worst. The same fast-mode
`sine` on the same arguments, `Backends.sine(x, Backends.CPU(64))` against
`Backends.sine(x, Backends.GPU(64))`, differs at 12 of 4096 eccentric anomalies and 11
of 4096 half-anomalies at every one of the six eccentricities: the platform library and
the device intrinsic are not the same function, and that difference alone keeps fast
mode off bitwise identity whatever the arithmetic does. Bitwise mode is bitwise between
the backends at all 4096 points at every one of the six eccentricities.

The sample in the suite is raised from 256 to 4096, where the control fires with 20
differing points at its thinnest.

## Decision 0027's reference path already differs by backend

`Backends.axpy!` on a non-bitwise backend against `Backends.axpy_reference!`, the naive
serial reference, at `BackendFixtures`'s 1024-cell fixture, with
`Reductions.error_bound(T, 2, max|a x| + |y0|)` as the tolerance decision 0027 asks
for. No `muladd` anywhere in either:

| type | processor against the reference | device against the reference | tolerance |
|---|---|---|---|
| Float64 | 0.0 (0.000 of tolerance) | 1.7764e-15 (0.433 of tolerance) | 4.1034e-15 |
| Float32 | 0.0 (0.000 of tolerance) | 4.7684e-7 (0.216 of tolerance) | 2.2030e-6 |

The fast kernel already agrees with its reference exactly on one backend and to under
half the tolerance on the other, with plain arithmetic and no `muladd` in the tree.
Whether the fast path fuses is therefore not a new source of machine dependence in the
0027 comparison; the comparison is at a tolerance because that dependence is already
there.

## What this changes

`src/Orbit/kepler.jl`: `Orbit.fma_add`'s fast arm is `muladd(a, b, c)`. The bitwise arm
is unchanged. Decision 0044 is amended to scope its refusal of `muladd` to source
compiled for bitwise mode and to state what the fast arm is; the argument is there.

`test/orbit/runtests.jl`: the cross-backend sample is 4096 points, and a new testset
asserts the two arms of `Orbit.fma_add` by spelling with a control that the triple
sample reaches values the two chains disagree on.

`bench/reference.toml`: the `kepler_sweep` hash moves from
`5806877ec3c59821cfe1caba07a983fd789cc21060869877c8f4d586cb80f7a8` to
`e9648e53da233a7b860eeed9c6a72ec7b5c29ea44c5a1e916f8da51b9360545b`, because the case
runs on `Backends.CPU(1)` in fast mode and every `fma_add` site in it now fuses.

`fiddlybits-52v.7.22`'s lint takes two prohibitions rather than one: no bare multiply
feeding a bare add in source bitwise mode compiles, and no `muladd` in source bitwise
mode compiles.

## The probes

`/tmp/fb728/probe.jl` runs the accuracy table, the cross-backend table at 256 points,
the 0027 reference comparison and the host's `muladd` against `fma`;
`/tmp/fb728/probe2.jl` runs the sample-size sweep and the fast-mode `sine` comparison;
`/tmp/fb728/probe3.jl` runs the 4096-point bitwise identity and control;
`/tmp/fb728/probe4.jl` runs the three-spellings table and takes no Fiddlybits and no
device; `/tmp/fb728/acc.jl` runs the accuracy table alone, and was run against
`1c65c53^` for the `pre` column. All but `probe4.jl` were invoked as
`qrun -p gpu-share -- julia --startup-file=no --project=. <probe>` from the worktree
root.
