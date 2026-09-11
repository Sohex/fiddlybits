# An explicit fma is bitwise across backends in every kernel shape the module has, including the running sum, and it is the only one of the three routes that stays bitwise on a target with no fused multiply-add instruction

Measured on 2026-09-11 on yggdrasil, through `qrun -p gpu-share` (one share of the RTX
4090), Julia 1.12.7, `CUDA.jl` 6.3.1, `GPUCompiler.jl` 2.6.0, `KernelAbstractions.jl`
0.9.42, Fiddlybits at branch `fiddlybits-52v.7.10` cut from
`43ef9777e537434f54f14977d378915ac1378c19`. Every reference is the same quantity at 256
bits, `setprecision(BigFloat, 256)`, rounded once, except the triple set of the last
table, which is at 300 bits.

`notes/findings/2026-09-11-gpucompiler-unconditional-fma-contraction.md` measured that
`Backends.nofuse_mul`'s barrier makes the two backends agree by moving the device to the
processor's twice-rounded answer, and that `muladd` agrees and is correctly rounded on
both. It left three things open, and they are what this row measured: whether a kernel
that accumulates into a running sum can be written in the fused form at all, what
happens on a target with no hardware fused multiply-add, and what a fused kernel does to
the naive serial reference of decision 0027.

## The fixtures

`N = 1024` cells and `NK = 4` neighbours, from the formulas in
`test/backends/fixtures.jl`: `x[i] = mod(31i + 7, 97)/20 - 2`, `y0[i] = 2 x[i]`,
`a = 1.3`, `neighbour[k, i] = mod1(i + 37k - 11, N)`,
`weight[k, i] = (mod(7i + 13k, 101) - 50)/50`. Four routes for the multiply that feeds
the add: `plain` is `a * b + c` as written, `barrier` is `Backends.nofuse_mul(a, b) + c`,
`muladd` is `muladd(a, b, c)` and `fma` is `fma(a, b, c)`. Ulp distance is the absolute
difference between two values' monotonic bit-pattern orderings.

## Shape: the running sum is the fused shape

`Backends.stencil_gather_bitwise_kernel!` writes `acc += in[n] * weight[k]`, which is
`acc = in[n] * weight[k] + acc`: the multiply feeds the add and the add's other operand
is the accumulator, so the fused form of that statement is
`acc = fma(in[n], weight[k], acc)`, the fused multiply-accumulate. The running sum is
not a shape the fused form fails to reach; it is the shape the instruction is named
for. Measured rather than argued, on both kernels and both element types:

axpy, `y[i] = a x[i] + y[i]`, against the single-rounding reference:

| type | route | max ulps, CPU vs GPU | cells differing, of 1024 | max ulps, CPU vs reference | max ulps, GPU vs reference |
|---|---|---|---|---|---|
| Float64 | plain | 1 | 203 | 1 | 0 |
| Float64 | barrier | 0 | 0 | 1 | 1 |
| Float64 | muladd | 0 | 0 | 0 | 0 |
| Float64 | fma | 0 | 0 | 0 | 0 |
| Float32 | plain | 1 | 106 | 1 | 0 |
| Float32 | barrier | 0 | 0 | 1 | 1 |
| Float32 | muladd | 0 | 0 | 0 | 0 |
| Float32 | fma | 0 | 0 | 0 | 0 |

stencil gather, `acc` over four terms. The exact sum passes within 5.773e-17 of zero at
one of the 1024 cells at `Float64` and within 3.099e-8 at `Float32`, while the terms
there are of order one, so an ulp count against the exact sum measures the conditioning
of that one cell and not the arithmetic. The columns that decide the question are
cross-backend identity and which of the two rounding chains the route reproduces:

| type | route | max ulps, CPU vs GPU | cells differing | equals the one-rounding chain | equals the two-rounding chain |
|---|---|---|---|---|---|
| Float64 | plain | - | 332 | no | on the CPU only |
| Float64 | barrier | 0 | 0 | no | yes |
| Float64 | muladd | 0 | 0 | yes | no |
| Float64 | fma | 0 | 0 | yes | no |
| Float32 | plain | - | 342 | no | on the CPU only |
| Float32 | barrier | 0 | 0 | no | yes |
| Float32 | muladd | 0 | 0 | yes | no |
| Float32 | fma | 0 | 0 | yes | no |

The one-rounding chain is `acc = T(big(in) * big(w) + big(acc))` per term at 256 bits;
the two-rounding chain is `acc = acc + T(big(in) * big(w))`. The `fma` route reproduces
the first exactly at every cell on both backends and the barrier reproduces the second
exactly at every cell on both backends, so the two routes are not approximations of each
other: each is exactly one of the two chains, and the choice between them is a choice of
which chain bitwise mode is.

Accuracy, as the maximum over the 1024 cells of `abs(err) / (eps(T) * sum(abs(terms)))`,
the same scaling `Reductions.error_bound` uses. The axpy row skips the 11 cells where
that scale is zero:

| quantity | type | two roundings | one rounding |
|---|---|---|---|
| stencil gather | Float64 | 1.1246 | 0.8589 |
| stencil gather | Float32 | 0.9314 | 0.8695 |
| axpy | Float64 | 0.5368 | 0.4132 |
| axpy | Float32 | 0.4675 | 0.4138 |

The naive serial reference and the barrier kernel are the same number in every row,
because they are the same chain.

## Hardware: muladd unfuses on a target without the instruction, and fma does not

Same three routes, on the host alone, over 4000 triples `a = 1 + i/4000`,
`b = 1 + mod(7i, 4000)/4000`, `c = -(a b)`, at two code-generation targets: the default
native target of this host, which has the instruction, and `--cpu-target=x86-64`, the
baseline target, which does not. No Fiddlybits in the process, so the package is not
recompiled at a non-native target.

| target | fma equals the single-rounding reference | muladd equals it | muladd equals fma | muladd equals plain |
|---|---|---|---|---|
| native | yes | yes | yes | no |
| x86-64 baseline | yes | no | no | yes |

The emitted code says the same thing: at the native target both `fma` and `muladd`
compile to `vfmadd`; at the baseline target `muladd` compiles to a multiply and an add
with `mulsd` in the body and `fma` compiles to a call.

Cost per call, the best of five runs of 200 passes over the 4000 triples, in
nanoseconds:

| target | fma | muladd | plain |
|---|---|---|---|
| native | 0.632 | 0.632 | 0.597 |
| x86-64 baseline | 4.457 | 0.624 | 0.600 |

So `muladd` on a target without the instruction silently becomes the twice-rounded
answer while the device, which contracts unconditionally, keeps the once-rounded one:
the two backends stop agreeing, with nothing in the source changed and no error raised.
`fma` keeps the same value at both targets, and pays 7.1 times the cost of the fused
instruction where it has to be emulated.

## The reference path

Decision 0027 asks the production kernel to agree with its naive serial reference to a
tolerance derived from floating point, which is `Reductions.error_bound`. The naive
reference is a plain multiply and a plain add, two roundings, and it is left that way.
The fused kernel against it:

| quantity | type | max absolute difference | tolerance | inside | cells differing, of 1024 |
|---|---|---|---|---|---|
| axpy | Float64 | 1.7763568394002505e-15 | 4.103384299014578e-15 | yes | 203 |
| axpy | Float32 | 4.7683716e-7 | 2.2029878e-6 | yes | 106 |
| stencil gather | Float64 | 8.881784197001252e-16 | 4.9622528308645994e-15 | yes | 332 |
| stencil gather | Float32 | 4.7683716e-7 | 2.6640894e-6 | yes | 342 |

The barrier kernel matched the reference at every cell of every one of those four rows,
which is where the exact assertion in `test/backends/reference_agreement.jl` came from:
the barrier kernel and the naive reference were the same chain, so the exact match was
recording that and nothing else. The fused kernel is a different chain from the
reference and agrees with it to a fifth of the bound at `Float64` and to a quarter at
`Float32`, and it agrees exactly with the 256-bit one-rounding chain, which is the
stronger statement and the one `test/backends/bitwise_mode.jl` now asserts.

## fma is correctly rounded on both backends, and the device control cannot be the plain form

2000 triples `a = 1 + i/2000`, `b = 1 + mod(7i, 2000)/2000`, `c = -(a b)`, through
`Backends.launch!` on each backend, against the 300-bit single rounding:

| backend | fma equals the reference | max ulps | plain differs from fma somewhere | max ulps, plain vs reference |
|---|---|---|---|---|
| CPU | yes | 0 | yes | 4372982015608245656 |
| GPU | yes | 0 | no | 0 |

The processor's plain form is the twice-rounded answer, which on this set is identically
zero where the fused answer is the residual of `a b`, hence the ulp count in the last
column; the device's plain form is contracted into the same instruction `fma` names, so
it is not a positive control on the device at all. A device-side check that `fma` is the
single-rounding operation has to take `Backends.nofuse_mul(a, b) + c` as its control,
which differs from `fma` on both backends.

## What this changes

`src/Backends/kernels.jl`: `axpy_bitwise_kernel!` is `fma(a, x[i], y[i])` and
`stencil_gather_bitwise_kernel!` is `acc = fma(in[neighbour[k, i]], weight[k, i], acc)`.
`nofuse_mul` stays, for the role `src/Backends/transcendentals.jl`'s `cube_root` already
uses it in. Decision 0044 carries the argument.

`test/backends/bitwise_mode.jl` asserts that `fma` is the single-rounding operation on
both backends with the barrier as its control, that both bitwise kernels equal the
256-bit one-rounding chain at both element types on both backends, and that they sit
inside `Reductions.error_bound` of the naive serial reference, with the two-rounding
reference as the control that the chain assertion is not vacuous.

`src/Orbit/kepler.jl` still routes its multiplies through `Backends.nofuse_mul` when the
backend is in bitwise mode, so the model's Kepler solve is on the two-rounding chain
where these two kernels are now on the one-rounding chain. Moving it is
`fiddlybits-52v.7.21`. Making the rule a lint over the source rather than a reading is
`fiddlybits-52v.7.22`.

## The probes

`/tmp/fb710/probe_gpu.jl` runs the four routes on both kernels and both backends and the
device-side `fma` check; `/tmp/fb710/probe_tol.jl` runs the roundoff-unit, reference
tolerance and one-rounding-chain measurements; `/tmp/fb710/probe_target.jl` runs the two
code-generation targets, and takes no Fiddlybits and no device. The first two were
invoked as `qrun -p gpu-share -- julia --startup-file=no --project=. <probe>` from the
worktree root.
