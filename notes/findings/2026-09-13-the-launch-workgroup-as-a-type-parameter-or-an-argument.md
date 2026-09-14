# A launch workgroup held in the kernel's type costs a runtime dispatch per launch, and one passed as an argument costs the CPU backend's launches. A branch per power of two to 1024 keeps the type without the dispatch, and no arm moves a bit

Measured on 2026-09-13 on yggdrasil, NVIDIA GeForce RTX 4090, driver 610.57.04, Julia 1.12.7,
CUDA.jl and CUDACore 6.3.1, GPUCompiler 2.6.0, KernelAbstractions.jl 0.9.42. The row is
`fiddlybits-52v.3.19`. The static pass of `test/fields/static_pass.jl` reports the runtime
dispatch in `Backends.launch!` that this measures the ways out of.

## The arms

Five trees unpacked by `git archive` from `main` at `e6bb1ba`. They are identical except for
how `Backends.launch!` in `src/Backends/launch.jl` calls the kernel. The first eight hex
digits of that file's sha256 are given for each:

| arm | the call | launch.jl |
| --- | --- | --- |
| A, as on `main` | `kernel(dev, size)(args...; ndrange = n)` | `1e2b4897` |
| B | `kernel(dev)(args...; ndrange = n, workgroupsize = size)` | `0f4b05c3` |
| C | `kernel(dev, 1)(args...; ndrange = n)` when `size == 1`, B otherwise | `138f866d` |
| D | `kernel(dev, w)(args...; ndrange = n)` in one branch per `w` in 1, 2, 4, ..., 1024, B otherwise, written out in `launch!` | `e3ec7adb` |
| E, as committed | `queue_kernel!`: one branch per `w` in `STATIC_WORKGROUPS`, calling `kernel(dev, KernelAbstractions.StaticSize{(w,)}(), KernelAbstractions.DynamicSize())`, B otherwise | `448b767b` |

## What each arm compiles, in the installed source

- KernelAbstractions `src/macros.jl`, lines 67-70. `name(dev)` builds a kernel whose
  workgroup and range are `DynamicSize()`. `name(dev, size)` builds one whose workgroup is
  `StaticSize(size)`. `name(dev, size::_Size, range::_Size)` takes both as given.
- `src/nditeration.jl`, lines 13-21. `StaticSize(s::Int...)` is `StaticSize{s}()`, so
  `StaticSize(256)` and `StaticSize{(256,)}()` are one type.
- `src/KernelAbstractions.jl`, line 706: `Kernel{Backend, WorkgroupSize, NDRange, Fun}`. In A
  the kernel's type depends on `size`, a runtime value.
- CUDACore `src/CUDAKernels.jl`, lines 111-127. The `Kernel{CUDABackend}` call passes
  `maxthreads` to `kernel_compile` only for a `StaticSize` workgroup (lines 119-126).
- KernelAbstractions `src/nditeration.jl`, lines 62-63. `workitems` of a range with a dynamic
  workgroup reads the `CartesianIndices` the range holds. With a static workgroup it builds
  them from the type.
- KernelAbstractions `src/cpu.jl`, lines 129-150 and 156. The CPU backend runs every work item
  of every block at line 147, and `@index(Local)` reads `workitems`.
- CUDACore `src/device/intrinsics/indexing.jl`, lines 40-41:
  `max_block_size = (x=1024, y=1024, z=64)`. This is the largest thread count a CUDA block
  holds along its first dimension, and the top of D's and E's branches.

## The dispatch

The optimised IR of each arm's launch was scanned for any `:call` whose callee is not a
builtin.

- **A.** One `Core.kwcall` at a CPU signature and one at a GPU signature. This is the control:
  the scan sees the dispatch the static pass reports.
- **B, C and D.** None, in `launch!`.
- **The first committed form.** It had the branches of D in a separate `@eval` method called
  with `kernel(dev, w)`, and held an unresolved `Core.kwcall` in all eleven branches. The
  kernel's workgroup type inferred as `S where S<:StaticSize`: the literal was not
  propagated into the constructor there, as it was in D's `launch!`. The static pass reported
  it as a new runtime dispatch in `Backends.queue_kernel!`.
- **E.** Spells each type in its source. It holds none, in `launch!` or in `queue_kernel!`, at
  these signatures:
  - the fill kernel on `KernelAbstractions.CPU` and on `CUDABackend`;
  - `pairwise_block_kernel!` on `KernelAbstractions.CPU`;
  - `pairwise_block_shared_kernel!` on `CUDABackend` with a `Val{256}`.

  F, which is E with `@inline` on `queue_kernel!`, holds none at the same signatures. The static
  pass on the tree with E reads 14 findings, 0 new and 0 stale.

## The instrument

A sample is one fresh `julia -t 8` process that loads the arm's tree from a depot of its own.
It times every case on `Backends.GPU()`, then on `Backends.CPU()`. The cases go through the
public reductions, and through `Backends.launch!` of a fill kernel of one line.

For each case the process records:

- the first call with its completion, compile included;
- two batches, discarded;
- **batch**: the minimum over batches of the mean per call, each batch closed by
  `Backends.complete!`;
- **host**: the minimum over the same batches, timed up to the completion.

A batch is 200 calls, 30 batches, on the card, and 20 calls, 15 batches, on the CPU backend.
Times are microseconds per call. Every result is hashed as raw bytes.

A round holds each arm twice, in a palindromic order rotated round by round: ABCCBA, BCAACB,
CABBAC, and so on; ABBA and BAAB for two arms.

- **A/A med** and **A/A max** are the median and the maximum of the absolute difference
  between one arm's two processes in one round, over every arm and every round.
- **X-A** is the median over rounds of the mean of X's two processes less the mean of A's in
  the same round.
- **X faster** is the number of rounds in which that difference was negative.

Control: the fill of one element with a 15 us host busy-wait added after each launch. Its
host time reads 15.0 us more than the fill without it, on both backends and in every arm. On
the CPU backend its batch time also reads 15.0 more. On the card its batch time reads 9.8 to
10.7 more, because the wait overlaps time the card spends on the launches already queued. So
host time moves with what the host does, and batch time on the card also carries what the
card does.

The host rows of the card, where no case waits on the device, are the A/A floor. Every arm's
two processes in a round agree there to a median of 0.04 to 0.06 us.

## What the runs show

Every number below is read from the tables that follow. Each is compared against the A/A
scatter of the same run and the same row.

- **The dispatch.** A holds the one runtime dispatch. B, C, D, E and F hold none at the
  signatures scanned.
- **Bits.** Every case hashed to one value over every process of every run, on both backends:
  36, 36, 36 and 48 processes. No arm, and no workgroup form, moved a result bit.
- **The host's cost of a launch.** Every dispatch-free arm launches faster than A on the host.
  - On the card, the host rows of the fill kernel read 0.68 to 0.86 us less per launch than A,
    faster in 6 of 6 rounds in every run. The A/A maximum on those rows is at most 0.30.
  - On the CPU backend, the fill of one element reads 0.51 to 0.54 less, 6 of 6. The A/A
    maximum there is at most 0.065.
- **The first call, compile included.** It does not order the arms the same way on every
  case (the first-call tables).
  - On the card, the fill of 20480 and the pairwise and segmented cases read the same or
    shorter in the dispatch-free arms than in A.
  - The fill of one element on the card reads 4.5 to 4.7 s in B, C and D, 5.4 to 5.7 in A,
    and 5.9 in E and F.
  - The pinned `segmented_quantile` on the CPU backend reads 0.28 to 0.38 s in D, E and F
    against 0.12 to 0.19 in A and C.
  - Each is one sample per process, taken once, and is not separated from the process's
    own warm-up here.
- **B on the CPU backend.** A dynamic workgroup costs the CPU backend's launches (run 1):
  - the fill of 20480: +10.0 us, B faster in 0 of 6 rounds, A/A maximum 8.5;
  - the fill of 655360: +343.3, 0 of 6, A/A maximum 49.8;
  - `segmented_sum` over segments of 64: +5.2, 0 of 6, A/A maximum 2.6;
  - over segments of 16: +16.2, 0 of 6, inside its A/A maximum of 17.2;
  - the pinned `segmented_quantile` over segments of 16: +86.1, 0 of 6, inside its A/A
    maximum of 207.5.
- **C, a static workgroup of 1 only.** C recovers the fills and the segmented sums on the CPU
  backend, but not the pinned quantile launch:
  - run 1: +85.3, 0 of 6, inside its A/A maximum of 207.5;
  - run 2: +72.2, 0 of 6, beyond its A/A maximum of 33.9.

  That launch is pinned to its segment length (`Backends.at_workgroup`), which C sends through
  the dynamic workgroup.
- **D, E and F.** A static branch for every power of two to 1024 brings the pinned quantile
  launch on the CPU back to A:
  - run 2, D: +1.1;
  - run 3, D: +4.7 and E: -1.1;
  - run 4, D: +1.2, E: +5.3 and F: +1.8.

  Every one of these is inside its row's A/A median of 10.2 to 11.4.
- **E against F.** Run 4 is the only run holding both. It separates neither: on no row of 36,
  batch and host on both backends, does the median over rounds of F-E exceed that row's A/A
  maximum. The tree takes E, whose source is F's without `@inline`. The measurement did not
  separate them.

### F-E per row, run 4

| backend, case | statistic | F-E median | F-E range | F faster | A/A median | A/A maximum | against the maximum |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GPU launch.fill.1 | batch | -1.087 | -3.896 to +0.030 | 4/6 | 0.059 | 5.101 | inside |
| GPU launch.fill.1.busywait15us | batch | -0.014 | -0.048 to +0.028 | 5/6 | 0.024 | 0.066 | inside |
| GPU launch.fill.20480 | batch | -1.644 | -4.170 to +0.929 | 5/6 | 2.386 | 6.981 | inside |
| GPU launch.fill.655360 | batch | -0.006 | -10.721 to +6.210 | 3/6 | 0.062 | 21.420 | inside |
| GPU pairwise_sum.5 | batch | +0.126 | -0.546 to +0.511 | 2/6 | 0.279 | 0.872 | inside |
| GPU pairwise_sum.7 | batch | +0.549 | -1.077 to +5.755 | 2/6 | 0.607 | 20.062 | inside |
| GPU area_fraction_above.5 | batch | +0.282 | -7.849 to +9.424 | 3/6 | 1.561 | 9.325 | inside |
| GPU segmented_sum.7over5 | batch | -0.697 | -2.386 to +3.128 | 5/6 | 0.835 | 5.726 | inside |
| GPU segmented_sum.7over4 | batch | -2.088 | -3.952 to -0.671 | 6/6 | 1.864 | 9.187 | inside |
| GPU segmented_mean.7over4 | batch | +3.038 | -9.582 to +10.519 | 2/6 | 4.819 | 19.565 | inside |
| GPU segmented_quantile.7over5 | batch | -1.918 | -7.535 to +1.228 | 4/6 | 0.229 | 14.665 | inside |
| GPU segmented_quantile.7over4 | batch | -0.002 | -0.182 to +0.054 | 3/6 | 0.047 | 0.182 | inside |
| CPU launch.fill.1 | batch | +0.013 | +0.009 to +0.015 | 0/6 | 0.001 | 0.065 | inside |
| CPU launch.fill.1.busywait15us | batch | +0.016 | +0.013 to +0.020 | 0/6 | 0.003 | 0.024 | inside |
| CPU launch.fill.20480 | batch | +0.271 | -1.088 to +0.858 | 1/6 | 0.500 | 1.290 | inside |
| CPU launch.fill.655360 | batch | -5.574 | -13.250 to +18.664 | 4/6 | 9.556 | 24.171 | inside |
| CPU pairwise_sum.5 | batch | +0.102 | -0.370 to +0.306 | 2/6 | 0.213 | 1.294 | inside |
| CPU pairwise_sum.7 | batch | +0.187 | -1.564 to +2.022 | 3/6 | 1.011 | 9.335 | inside |
| CPU area_fraction_above.5 | batch | -0.198 | -1.704 to +0.577 | 4/6 | 0.541 | 2.052 | inside |
| CPU segmented_sum.7over5 | batch | -2.735 | -7.893 to +6.309 | 4/6 | 2.989 | 18.040 | inside |
| CPU segmented_sum.7over4 | batch | -2.161 | -2.686 to +1.577 | 5/6 | 0.745 | 5.035 | inside |
| CPU segmented_mean.7over4 | batch | -2.486 | -5.461 to +20.516 | 4/6 | 4.740 | 18.625 | inside |
| CPU segmented_quantile.7over5 | batch | -3.678 | -15.909 to +94.811 | 4/6 | 10.204 | 206.446 | inside |
| CPU segmented_quantile.7over4 | batch | -1.727 | -36.126 to +11.999 | 4/6 | 9.803 | 37.879 | inside |
| GPU launch.fill.1 | host | -0.008 | -0.053 to +0.008 | 4/6 | 0.031 | 0.076 | inside |
| GPU launch.fill.1.busywait15us | host | -0.018 | -0.066 to +0.028 | 4/6 | 0.020 | 0.092 | inside |
| GPU launch.fill.20480 | host | -0.011 | -0.035 to +0.014 | 5/6 | 0.018 | 0.080 | inside |
| GPU launch.fill.655360 | host | +0.010 | -0.049 to +0.033 | 2/6 | 0.030 | 0.098 | inside |
| GPU pairwise_sum.5 | host | +0.126 | -0.546 to +0.511 | 2/6 | 0.279 | 0.872 | inside |
| GPU pairwise_sum.7 | host | +0.549 | -1.077 to +5.755 | 2/6 | 0.607 | 20.062 | inside |
| GPU area_fraction_above.5 | host | +0.282 | -7.849 to +9.424 | 3/6 | 1.561 | 9.325 | inside |
| GPU segmented_sum.7over5 | host | +0.036 | -0.126 to +0.136 | 2/6 | 0.102 | 0.226 | inside |
| GPU segmented_sum.7over4 | host | +0.023 | -0.131 to +0.078 | 2/6 | 0.043 | 0.158 | inside |
| GPU segmented_mean.7over4 | host | +3.038 | -9.582 to +10.519 | 2/6 | 4.820 | 19.565 | inside |
| GPU segmented_quantile.7over5 | host | -0.418 | -0.666 to -0.235 | 6/6 | 0.242 | 1.047 | inside |
| GPU segmented_quantile.7over4 | host | -0.160 | -0.639 to +0.127 | 5/6 | 0.141 | 0.725 | inside |

## Anomalies not explained here

- **The card's batch time for `segmented_sum` reads higher in E and F than in A, at both
  depths, in both runs on the whole card.** A was faster in every round. The same arms'
  host rows for those cases read faster than A in 6 of 6 rounds. D, which compiles the same
  static kernels from branches written out in `launch!`, does not show it.

  | run, arm | depth two | depth three |
  | --- | --- | --- |
  | run 3, E | +1.64 (A/A median 0.56, maximum 3.72) | +3.03 (A/A median 1.12, maximum 6.01) |
  | run 4, E | +1.85 (A/A median 0.84, maximum 5.73) | +3.97 (A/A median 1.86, maximum 9.19) |
  | run 4, F | +1.09 | +1.86 |

  Each is beyond its row's A/A median and inside its A/A maximum.
- **`area_fraction_above` at level 5 on the card reads higher in D, E and F than in A in runs
  3 and 4.** The differences are +2.1 to +4.8 us, the arm faster in 1 or 2 rounds of 6, inside
  the A/A maxima of 7.0 and 9.3.
- **The first call in F on the CPU backend** reads 1.2 s for the fill of one element and 0.2
  to 0.4 s for the reductions in run 4, against 0.1 s and under in A, D and E.
- **The first job of the exclusive runs, 2622, is not counted.** It ran A against D and was
  cancelled after two and a half rounds, once D's form was replaced by E's.
- **On one share (runs 1 and 2), D read 42 to 54 us on `pairwise_sum` at level 7 in 9 of its
  12 processes,** against 34 to 36 for C in every process and for A in 10 of its 12. Other jobs held
  one or two further shares at the readings.
  On the whole card, runs 3 and 4, D reads within 0.1 of A there.

## Run 1: A, B and C, one share

job 2595, 21:44 to 21:57, `qrun -p gpu-share` (8 CPUs, one of the card's four shares, 3G of vram). Other jobs held zero to two further shares at the readings. Six rounds. Sample counts, host load and shares at each process's start and end readings: processes 36, rounds 6, arms A B C; load 5.24 to 22.25; shares in use at readings 1, 2, 3; package load 2.29 to 3.05 s; threads 8. Every case hashed to one value over every process, on both backends.

**`Backends.GPU()`, batch**

| case | A | B | C | A/A med | A/A max | B-A | B faster | C-A | C faster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch.fill.1 | 6.971 | 7.093 | 6.953 | 0.028 | 5.151 | +0.099 | 2/6 | -0.003 | 4/6 |
| launch.fill.1.busywait15us | 17.672 | 16.886 | 16.933 | 0.050 | 0.160 | -0.781 | 6/6 | -0.753 | 6/6 |
| launch.fill.20480 | 7.301 | 7.062 | 7.957 | 1.492 | 6.113 | -0.837 | 3/6 | +0.461 | 2/6 |
| launch.fill.655360 | 11.382 | 11.431 | 11.406 | 0.031 | 33.121 | +0.077 | 2/6 | +0.025 | 2/6 |
| pairwise_sum.5 | 19.868 | 18.932 | 18.954 | 0.223 | 0.767 | -0.835 | 6/6 | -0.785 | 6/6 |
| pairwise_sum.7 | 36.434 | 35.699 | 35.909 | 0.524 | 1.288 | -0.912 | 5/6 | -0.450 | 6/6 |
| area_fraction_above.5 | 26.162 | 25.372 | 26.357 | 1.362 | 5.357 | -0.491 | 3/6 | +0.179 | 1/6 |
| segmented_sum.7over5 | 6.090 | 5.781 | 6.184 | 0.542 | 1.977 | -0.152 | 3/6 | +0.299 | 2/6 |
| segmented_sum.7over4 | 10.611 | 10.816 | 11.576 | 1.555 | 7.386 | +0.488 | 2/6 | +0.961 | 2/6 |
| segmented_mean.7over4 | 38.051 | 28.682 | 38.126 | 8.040 | 17.601 | -3.544 | 5/6 | +2.916 | 1/6 |
| segmented_quantile.7over5 | 27.317 | 27.456 | 27.363 | 0.162 | 4.803 | +0.668 | 1/6 | +1.039 | 1/6 |

**`Backends.GPU()`, host**

| case | A | B | C | A/A med | A/A max | B-A | B faster | C-A | C faster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch.fill.1 | 2.604 | 1.793 | 1.849 | 0.060 | 0.239 | -0.781 | 6/6 | -0.758 | 6/6 |
| launch.fill.1.busywait15us | 17.640 | 16.877 | 16.929 | 0.041 | 0.161 | -0.784 | 6/6 | -0.755 | 6/6 |
| launch.fill.20480 | 2.651 | 1.803 | 1.786 | 0.046 | 0.126 | -0.820 | 6/6 | -0.837 | 6/6 |
| launch.fill.655360 | 2.620 | 1.792 | 1.789 | 0.045 | 0.183 | -0.811 | 6/6 | -0.836 | 6/6 |
| pairwise_sum.5 | 19.866 | 18.929 | 18.952 | 0.223 | 0.767 | -0.835 | 6/6 | -0.785 | 6/6 |
| pairwise_sum.7 | 36.431 | 35.697 | 35.907 | 0.524 | 1.288 | -0.912 | 5/6 | -0.450 | 6/6 |
| area_fraction_above.5 | 26.160 | 25.370 | 26.355 | 1.362 | 5.357 | -0.492 | 3/6 | +0.179 | 1/6 |
| segmented_sum.7over5 | 4.699 | 3.798 | 3.970 | 0.090 | 0.383 | -0.871 | 6/6 | -0.783 | 6/6 |
| segmented_sum.7over4 | 4.474 | 3.687 | 3.822 | 0.091 | 0.495 | -0.766 | 6/6 | -0.665 | 6/6 |
| segmented_mean.7over4 | 38.048 | 28.680 | 38.124 | 8.040 | 17.601 | -3.544 | 5/6 | +2.916 | 1/6 |
| segmented_quantile.7over5 | 18.513 | 17.717 | 17.689 | 0.346 | 1.030 | -0.726 | 6/6 | -0.841 | 6/6 |

**`Backends.CPU()`, where batch and host agree to 0.001, batch**

| case | A | B | C | A/A med | A/A max | B-A | B faster | C-A | C faster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch.fill.1 | 0.544 | 0.015 | 0.009 | 0.001 | 0.063 | -0.529 | 6/6 | -0.535 | 6/6 |
| launch.fill.1.busywait15us | 15.589 | 15.047 | 15.042 | 0.003 | 0.035 | -0.541 | 6/6 | -0.546 | 6/6 |
| launch.fill.20480 | 8.626 | 18.100 | 7.435 | 0.531 | 8.525 | +10.007 | 0/6 | -1.106 | 5/6 |
| launch.fill.655360 | 85.103 | 434.070 | 84.195 | 13.078 | 49.792 | +343.257 | 0/6 | -4.260 | 3/6 |
| pairwise_sum.5 | 9.341 | 8.390 | 8.404 | 0.160 | 0.679 | -1.052 | 6/6 | -0.925 | 6/6 |
| pairwise_sum.7 | 68.407 | 69.743 | 67.172 | 0.777 | 7.110 | +1.183 | 0/6 | -1.579 | 5/6 |
| area_fraction_above.5 | 12.704 | 11.908 | 11.872 | 0.719 | 1.605 | -0.778 | 6/6 | -0.667 | 4/6 |
| segmented_sum.7over5 | 23.383 | 38.893 | 22.158 | 2.346 | 17.164 | +16.231 | 0/6 | -1.963 | 6/6 |
| segmented_sum.7over4 | 29.862 | 34.575 | 28.369 | 0.339 | 2.641 | +5.172 | 0/6 | -1.603 | 6/6 |
| segmented_mean.7over4 | 357.979 | 357.858 | 353.826 | 9.507 | 47.816 | +0.396 | 3/6 | -0.535 | 4/6 |
| segmented_quantile.7over5 | 465.359 | 550.716 | 551.197 | 12.399 | 207.457 | +86.083 | 0/6 | +85.285 | 0/6 |

**first call with its completion, seconds, median over processes**

| backend, case | A | B | C |
| --- | --- | --- | --- |
| GPU launch.fill.1 | 5.728 | 4.685 | 4.626 |
| GPU launch.fill.1.busywait15us | 0.000 | 0.000 | 0.000 |
| GPU launch.fill.20480 | 0.279 | 0.000 | 0.200 |
| GPU launch.fill.655360 | 0.001 | 0.000 | 0.001 |
| GPU pairwise_sum.5 | 0.648 | 0.548 | 0.556 |
| GPU pairwise_sum.7 | 0.320 | 0.163 | 0.161 |
| GPU area_fraction_above.5 | 0.267 | 0.240 | 0.237 |
| GPU segmented_sum.7over5 | 0.220 | 0.180 | 0.184 |
| GPU segmented_sum.7over4 | 0.000 | 0.000 | 0.000 |
| GPU segmented_mean.7over4 | 0.414 | 0.367 | 0.369 |
| GPU segmented_quantile.7over5 | 0.578 | 0.523 | 0.558 |
| CPU launch.fill.1 | 0.105 | 0.000 | 0.000 |
| CPU launch.fill.1.busywait15us | 0.000 | 0.000 | 0.000 |
| CPU launch.fill.20480 | 0.007 | 0.003 | 0.006 |
| CPU launch.fill.655360 | 0.000 | 0.000 | 0.000 |
| CPU pairwise_sum.5 | 0.080 | 0.075 | 0.062 |
| CPU pairwise_sum.7 | 0.000 | 0.000 | 0.000 |
| CPU area_fraction_above.5 | 0.085 | 0.082 | 0.065 |
| CPU segmented_sum.7over5 | 0.088 | 0.076 | 0.070 |
| CPU segmented_sum.7over4 | 0.000 | 0.000 | 0.000 |
| CPU segmented_mean.7over4 | 0.168 | 0.152 | 0.133 |
| CPU segmented_quantile.7over5 | 0.189 | 0.174 | 0.204 |

## Run 2: A, C and D, one share

job 2610, 21:59 to 22:14, `qrun -p gpu-share`, with the pinned `segmented_quantile` over segments of 64 added to the cases. Other jobs held one or two further shares at the readings. Six rounds. Sample counts, host load and shares at each process's start and end readings: processes 36, rounds 6, arms A C D; load 7.71 to 21.72; shares in use at readings 2, 3; package load 2.33 to 2.86 s; threads 8. Every case hashed to one value over every process, on both backends.

**`Backends.GPU()`, batch**

| case | A | C | D | A/A med | A/A max | C-A | C faster | D-A | D faster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch.fill.1 | 6.973 | 6.974 | 6.947 | 0.055 | 4.981 | +1.049 | 3/6 | -0.033 | 4/6 |
| launch.fill.1.busywait15us | 17.736 | 16.953 | 16.948 | 0.048 | 0.213 | -0.752 | 6/6 | -0.769 | 6/6 |
| launch.fill.20480 | 6.745 | 8.170 | 6.983 | 1.847 | 7.498 | +1.807 | 1/6 | +0.082 | 3/6 |
| launch.fill.655360 | 11.386 | 11.417 | 11.417 | 0.086 | 30.741 | +0.001 | 3/6 | -0.023 | 3/6 |
| pairwise_sum.5 | 19.906 | 18.973 | 19.380 | 0.257 | 10.485 | -0.942 | 6/6 | -0.466 | 5/6 |
| pairwise_sum.7 | 35.723 | 35.219 | 44.347 | 1.045 | 14.496 | -0.698 | 5/6 | +7.261 | 1/6 |
| area_fraction_above.5 | 25.192 | 26.097 | 27.394 | 2.093 | 9.290 | +0.495 | 1/6 | +2.170 | 1/6 |
| segmented_sum.7over5 | 5.660 | 6.114 | 8.760 | 1.025 | 5.349 | +0.166 | 2/6 | +1.980 | 0/6 |
| segmented_sum.7over4 | 10.144 | 11.334 | 12.558 | 2.683 | 10.379 | +2.254 | 0/6 | +3.873 | 1/6 |
| segmented_mean.7over4 | 38.312 | 43.227 | 37.617 | 6.853 | 16.526 | +3.168 | 1/6 | -1.074 | 4/6 |
| segmented_quantile.7over5 | 27.418 | 27.556 | 27.380 | 0.141 | 11.095 | +0.057 | 1/6 | -0.072 | 3/6 |
| segmented_quantile.7over4 | 28.151 | 28.148 | 28.063 | 0.095 | 1.695 | +0.045 | 2/6 | -0.098 | 4/6 |

**`Backends.GPU()`, host**

| case | A | C | D | A/A med | A/A max | C-A | C faster | D-A | D faster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch.fill.1 | 2.693 | 1.854 | 1.903 | 0.057 | 0.288 | -0.800 | 6/6 | -0.764 | 6/6 |
| launch.fill.1.busywait15us | 17.732 | 16.945 | 16.945 | 0.052 | 0.212 | -0.752 | 6/6 | -0.768 | 6/6 |
| launch.fill.20480 | 2.702 | 1.834 | 1.897 | 0.041 | 0.197 | -0.855 | 6/6 | -0.788 | 6/6 |
| launch.fill.655360 | 2.701 | 1.815 | 1.886 | 0.039 | 0.299 | -0.832 | 6/6 | -0.764 | 6/6 |
| pairwise_sum.5 | 19.903 | 18.971 | 19.378 | 0.257 | 10.485 | -0.942 | 6/6 | -0.466 | 5/6 |
| pairwise_sum.7 | 35.721 | 35.217 | 44.345 | 1.045 | 14.496 | -0.699 | 5/6 | +7.261 | 1/6 |
| area_fraction_above.5 | 25.190 | 26.094 | 27.391 | 2.093 | 9.290 | +0.495 | 1/6 | +2.170 | 1/6 |
| segmented_sum.7over5 | 4.695 | 4.039 | 4.177 | 0.141 | 0.342 | -0.622 | 6/6 | -0.530 | 6/6 |
| segmented_sum.7over4 | 4.504 | 3.879 | 4.019 | 0.105 | 0.306 | -0.643 | 6/6 | -0.492 | 6/6 |
| segmented_mean.7over4 | 38.309 | 43.225 | 37.615 | 6.853 | 16.527 | +3.167 | 1/6 | -1.074 | 4/6 |
| segmented_quantile.7over5 | 18.755 | 17.739 | 18.022 | 0.400 | 1.535 | -0.653 | 6/6 | -0.681 | 6/6 |
| segmented_quantile.7over4 | 12.331 | 11.591 | 11.685 | 0.321 | 0.752 | -0.764 | 6/6 | -0.662 | 5/6 |

**`Backends.CPU()`, where batch and host agree to 0.001, batch**

| case | A | C | D | A/A med | A/A max | C-A | C faster | D-A | D faster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch.fill.1 | 0.543 | 0.009 | 0.009 | 0.001 | 0.035 | -0.532 | 6/6 | -0.531 | 6/6 |
| launch.fill.1.busywait15us | 15.590 | 15.041 | 15.042 | 0.003 | 0.054 | -0.542 | 6/6 | -0.542 | 6/6 |
| launch.fill.20480 | 7.641 | 6.401 | 6.596 | 0.549 | 1.797 | -1.298 | 6/6 | -1.250 | 6/6 |
| launch.fill.655360 | 75.984 | 81.307 | 73.301 | 13.293 | 42.627 | -4.463 | 4/6 | -9.519 | 6/6 |
| pairwise_sum.5 | 9.293 | 8.141 | 8.277 | 0.284 | 4.327 | -1.187 | 6/6 | -0.972 | 5/6 |
| pairwise_sum.7 | 68.236 | 67.042 | 67.302 | 2.454 | 6.220 | -1.724 | 6/6 | -1.805 | 5/6 |
| area_fraction_above.5 | 12.127 | 11.122 | 11.325 | 0.694 | 2.190 | -1.348 | 5/6 | -0.751 | 5/6 |
| segmented_sum.7over5 | 24.461 | 23.236 | 23.933 | 0.955 | 16.604 | -1.358 | 6/6 | -0.682 | 3/6 |
| segmented_sum.7over4 | 29.862 | 28.522 | 28.670 | 0.756 | 4.680 | -1.433 | 6/6 | -1.506 | 5/6 |
| segmented_mean.7over4 | 359.949 | 357.473 | 359.151 | 7.751 | 29.896 | -3.409 | 5/6 | -1.524 | 4/6 |
| segmented_quantile.7over5 | 451.673 | 526.677 | 451.843 | 11.414 | 33.941 | +72.196 | 0/6 | +1.141 | 3/6 |
| segmented_quantile.7over4 | 840.764 | 847.185 | 822.559 | 13.881 | 46.492 | +5.428 | 1/6 | -13.685 | 4/6 |

**first call with its completion, seconds, median over processes**

| backend, case | A | C | D |
| --- | --- | --- | --- |
| GPU launch.fill.1 | 5.677 | 4.699 | 4.709 |
| GPU launch.fill.1.busywait15us | 0.000 | 0.000 | 0.000 |
| GPU launch.fill.20480 | 0.267 | 0.212 | 0.154 |
| GPU launch.fill.655360 | 0.000 | 0.001 | 0.000 |
| GPU pairwise_sum.5 | 0.662 | 0.558 | 0.639 |
| GPU pairwise_sum.7 | 0.326 | 0.168 | 0.292 |
| GPU area_fraction_above.5 | 0.279 | 0.245 | 0.252 |
| GPU segmented_sum.7over5 | 0.223 | 0.187 | 0.200 |
| GPU segmented_sum.7over4 | 0.000 | 0.000 | 0.000 |
| GPU segmented_mean.7over4 | 0.428 | 0.382 | 0.390 |
| GPU segmented_quantile.7over5 | 0.588 | 0.577 | 0.627 |
| GPU segmented_quantile.7over4 | 0.369 | 0.241 | 0.400 |
| CPU launch.fill.1 | 0.107 | 0.000 | 0.000 |
| CPU launch.fill.1.busywait15us | 0.000 | 0.000 | 0.000 |
| CPU launch.fill.20480 | 0.007 | 0.007 | 0.007 |
| CPU launch.fill.655360 | 0.000 | 0.000 | 0.000 |
| CPU pairwise_sum.5 | 0.080 | 0.063 | 0.073 |
| CPU pairwise_sum.7 | 0.000 | 0.000 | 0.000 |
| CPU area_fraction_above.5 | 0.084 | 0.067 | 0.077 |
| CPU segmented_sum.7over5 | 0.089 | 0.073 | 0.081 |
| CPU segmented_sum.7over4 | 0.000 | 0.000 | 0.000 |
| CPU segmented_mean.7over4 | 0.171 | 0.138 | 0.162 |
| CPU segmented_quantile.7over5 | 0.194 | 0.209 | 0.381 |
| CPU segmented_quantile.7over4 | 0.131 | 0.145 | 0.298 |

## Run 3: A, D and E, the whole card

job 2633, 22:28 to 22:43, `qrun -p gpu` (8 CPUs, all four shares, 18G of vram). No other job could reach the card. Six rounds. Sample counts, host load and shares at each process's start and end readings: processes 36, rounds 6, arms A D E; load 1.13 to 5.45; shares in use at readings 4; package load 2.26 to 2.34 s; threads 8. Every case hashed to one value over every process, on both backends.

**`Backends.GPU()`, batch**

| case | A | D | E | A/A med | A/A max | D-A | D faster | E-A | E faster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch.fill.1 | 6.991 | 6.981 | 6.984 | 0.004 | 0.060 | -0.010 | 6/6 | -0.011 | 6/6 |
| launch.fill.1.busywait15us | 17.598 | 16.893 | 16.920 | 0.031 | 0.106 | -0.704 | 6/6 | -0.677 | 6/6 |
| launch.fill.20480 | 7.155 | 7.293 | 7.794 | 1.170 | 3.156 | +0.342 | 2/6 | +0.684 | 1/6 |
| launch.fill.655360 | 11.387 | 11.390 | 11.380 | 0.094 | 29.507 | -0.017 | 4/6 | -0.012 | 4/6 |
| pairwise_sum.5 | 19.505 | 19.054 | 19.068 | 0.245 | 0.649 | -0.339 | 6/6 | -0.355 | 6/6 |
| pairwise_sum.7 | 36.742 | 36.602 | 36.428 | 0.266 | 4.508 | -0.061 | 4/6 | -0.228 | 4/6 |
| area_fraction_above.5 | 26.042 | 28.906 | 28.180 | 1.093 | 6.982 | +2.108 | 2/6 | +2.290 | 1/6 |
| segmented_sum.7over5 | 6.282 | 5.362 | 8.322 | 0.559 | 3.724 | -0.282 | 3/6 | +1.644 | 0/6 |
| segmented_sum.7over4 | 10.798 | 9.154 | 13.767 | 1.116 | 6.011 | +0.338 | 3/6 | +3.033 | 0/6 |
| segmented_mean.7over4 | 38.859 | 37.207 | 39.493 | 2.535 | 11.041 | +2.335 | 2/6 | +0.003 | 3/6 |
| segmented_quantile.7over5 | 30.005 | 30.423 | 33.794 | 3.410 | 11.072 | +2.285 | 2/6 | +0.350 | 2/6 |
| segmented_quantile.7over4 | 28.047 | 28.045 | 28.042 | 0.020 | 0.149 | -0.003 | 3/6 | -0.005 | 3/6 |

**`Backends.GPU()`, host**

| case | A | D | E | A/A med | A/A max | D-A | D faster | E-A | E faster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch.fill.1 | 2.536 | 1.817 | 1.851 | 0.024 | 0.060 | -0.728 | 6/6 | -0.685 | 6/6 |
| launch.fill.1.busywait15us | 17.594 | 16.889 | 16.917 | 0.030 | 0.106 | -0.703 | 6/6 | -0.676 | 6/6 |
| launch.fill.20480 | 2.556 | 1.826 | 1.863 | 0.014 | 0.047 | -0.737 | 6/6 | -0.688 | 6/6 |
| launch.fill.655360 | 2.520 | 1.801 | 1.840 | 0.029 | 0.233 | -0.745 | 6/6 | -0.714 | 6/6 |
| pairwise_sum.5 | 19.503 | 19.052 | 19.066 | 0.245 | 0.649 | -0.339 | 6/6 | -0.355 | 6/6 |
| pairwise_sum.7 | 36.739 | 36.599 | 36.426 | 0.266 | 4.508 | -0.061 | 4/6 | -0.228 | 4/6 |
| area_fraction_above.5 | 26.040 | 28.904 | 28.178 | 1.093 | 6.982 | +2.108 | 2/6 | +2.290 | 1/6 |
| segmented_sum.7over5 | 4.488 | 3.952 | 4.070 | 0.078 | 0.358 | -0.555 | 6/6 | -0.419 | 6/6 |
| segmented_sum.7over4 | 4.361 | 3.797 | 3.861 | 0.061 | 0.113 | -0.566 | 6/6 | -0.475 | 6/6 |
| segmented_mean.7over4 | 38.857 | 37.205 | 39.490 | 2.535 | 11.041 | +2.335 | 2/6 | +0.003 | 3/6 |
| segmented_quantile.7over5 | 18.146 | 17.510 | 18.701 | 0.224 | 0.804 | -0.642 | 6/6 | +0.523 | 1/6 |
| segmented_quantile.7over4 | 11.693 | 11.207 | 12.043 | 0.077 | 0.759 | -0.451 | 6/6 | +0.406 | 1/6 |

**`Backends.CPU()`, where batch and host agree to 0.001, batch**

| case | A | D | E | A/A med | A/A max | D-A | D faster | E-A | E faster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch.fill.1 | 0.532 | 0.010 | 0.011 | 0.001 | 0.026 | -0.525 | 6/6 | -0.525 | 6/6 |
| launch.fill.1.busywait15us | 15.574 | 15.040 | 15.040 | 0.002 | 0.022 | -0.534 | 6/6 | -0.534 | 6/6 |
| launch.fill.20480 | 8.768 | 7.909 | 7.616 | 0.484 | 7.912 | -0.933 | 5/6 | -1.212 | 6/6 |
| launch.fill.655360 | 96.357 | 90.008 | 93.447 | 7.833 | 24.722 | -4.984 | 4/6 | -2.435 | 4/6 |
| pairwise_sum.5 | 9.231 | 8.338 | 8.539 | 0.312 | 0.785 | -0.967 | 6/6 | -0.713 | 6/6 |
| pairwise_sum.7 | 68.753 | 67.244 | 67.236 | 0.691 | 2.988 | -1.649 | 5/6 | -1.597 | 6/6 |
| area_fraction_above.5 | 13.369 | 12.419 | 12.433 | 0.458 | 1.536 | -1.041 | 6/6 | -0.923 | 6/6 |
| segmented_sum.7over5 | 27.025 | 25.273 | 23.394 | 3.867 | 14.404 | -2.287 | 4/6 | -4.294 | 5/6 |
| segmented_sum.7over4 | 29.632 | 28.337 | 28.968 | 0.744 | 2.929 | -1.616 | 5/6 | -1.148 | 5/6 |
| segmented_mean.7over4 | 349.864 | 344.288 | 347.273 | 4.782 | 13.116 | -6.121 | 5/6 | -5.499 | 5/6 |
| segmented_quantile.7over5 | 462.648 | 460.907 | 465.456 | 10.307 | 37.651 | +4.655 | 2/6 | -1.051 | 3/6 |
| segmented_quantile.7over4 | 865.516 | 858.993 | 862.368 | 11.126 | 34.673 | -13.073 | 5/6 | +1.408 | 2/6 |

**first call with its completion, seconds, median over processes**

| backend, case | A | D | E |
| --- | --- | --- | --- |
| GPU launch.fill.1 | 5.380 | 4.449 | 5.889 |
| GPU launch.fill.1.busywait15us | 0.000 | 0.000 | 0.000 |
| GPU launch.fill.20480 | 0.285 | 0.147 | 0.148 |
| GPU launch.fill.655360 | 0.001 | 0.000 | 0.001 |
| GPU pairwise_sum.5 | 0.614 | 0.582 | 0.599 |
| GPU pairwise_sum.7 | 0.308 | 0.289 | 0.271 |
| GPU area_fraction_above.5 | 0.258 | 0.232 | 0.238 |
| GPU segmented_sum.7over5 | 0.204 | 0.183 | 0.185 |
| GPU segmented_sum.7over4 | 0.000 | 0.000 | 0.000 |
| GPU segmented_mean.7over4 | 0.392 | 0.354 | 0.371 |
| GPU segmented_quantile.7over5 | 0.536 | 0.573 | 0.570 |
| GPU segmented_quantile.7over4 | 0.352 | 0.374 | 0.369 |
| CPU launch.fill.1 | 0.099 | 0.000 | 0.000 |
| CPU launch.fill.1.busywait15us | 0.000 | 0.000 | 0.000 |
| CPU launch.fill.20480 | 0.006 | 0.006 | 0.006 |
| CPU launch.fill.655360 | 0.000 | 0.000 | 0.000 |
| CPU pairwise_sum.5 | 0.074 | 0.068 | 0.070 |
| CPU pairwise_sum.7 | 0.000 | 0.000 | 0.000 |
| CPU area_fraction_above.5 | 0.078 | 0.071 | 0.074 |
| CPU segmented_sum.7over5 | 0.082 | 0.075 | 0.078 |
| CPU segmented_sum.7over4 | 0.000 | 0.000 | 0.000 |
| CPU segmented_mean.7over4 | 0.157 | 0.146 | 0.151 |
| CPU segmented_quantile.7over5 | 0.179 | 0.360 | 0.358 |
| CPU segmented_quantile.7over4 | 0.120 | 0.283 | 0.279 |

## Run 4: A, D, E and F, the whole card

job 2640, 22:48 to 23:10, `qrun -p gpu`. F is E with `@inline` on `queue_kernel!` (launch.jl `8ff8c97e`). No other job could reach the card. Six rounds. Sample counts, host load and shares at each process's start and end readings: processes 48, rounds 6, arms A D E F; load 1.18 to 13.48; shares in use at readings 4; package load 2.27 to 2.35 s; threads 8. Every case hashed to one value over every process, on both backends.

**`Backends.GPU()`, batch**

| case | A | D | E | F | A/A med | A/A max | D-A | D faster | E-A | E faster | F-A | F faster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch.fill.1 | 6.994 | 6.969 | 6.975 | 6.961 | 0.059 | 5.101 | +0.063 | 2/6 | +0.063 | 3/6 | -0.022 | 4/6 |
| launch.fill.1.busywait15us | 17.616 | 16.891 | 16.939 | 16.924 | 0.024 | 0.066 | -0.730 | 6/6 | -0.690 | 6/6 | -0.703 | 6/6 |
| launch.fill.20480 | 6.814 | 6.446 | 7.411 | 6.336 | 2.386 | 6.981 | +0.210 | 3/6 | +0.886 | 3/6 | -0.622 | 4/6 |
| launch.fill.655360 | 11.528 | 11.460 | 11.461 | 11.460 | 0.062 | 21.420 | -0.043 | 6/6 | -0.037 | 4/6 | -0.054 | 5/6 |
| pairwise_sum.5 | 19.630 | 19.057 | 19.187 | 19.173 | 0.279 | 0.872 | -0.581 | 5/6 | -0.418 | 6/6 | -0.450 | 6/6 |
| pairwise_sum.7 | 36.991 | 36.933 | 36.802 | 37.151 | 0.607 | 20.062 | +0.051 | 3/6 | -0.383 | 5/6 | +0.246 | 3/6 |
| area_fraction_above.5 | 25.816 | 30.679 | 27.915 | 27.990 | 1.561 | 9.325 | +4.797 | 1/6 | +3.755 | 1/6 | +2.714 | 1/6 |
| segmented_sum.7over5 | 6.228 | 4.998 | 8.222 | 6.620 | 0.835 | 5.726 | -0.686 | 5/6 | +1.848 | 0/6 | +1.093 | 0/6 |
| segmented_sum.7over4 | 10.522 | 8.375 | 14.516 | 11.747 | 1.864 | 9.187 | -1.084 | 4/6 | +3.967 | 0/6 | +1.860 | 0/6 |
| segmented_mean.7over4 | 39.570 | 32.342 | 32.476 | 37.680 | 4.819 | 19.565 | -6.189 | 4/6 | -7.283 | 4/6 | -1.627 | 3/6 |
| segmented_quantile.7over5 | 27.257 | 27.162 | 27.273 | 27.145 | 0.229 | 14.665 | -1.219 | 4/6 | +1.363 | 2/6 | -0.223 | 4/6 |
| segmented_quantile.7over4 | 27.894 | 27.920 | 27.916 | 27.892 | 0.047 | 0.182 | +0.042 | 0/6 | +0.016 | 2/6 | +0.001 | 3/6 |

**`Backends.GPU()`, host**

| case | A | D | E | F | A/A med | A/A max | D-A | D faster | E-A | E faster | F-A | F faster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch.fill.1 | 2.541 | 1.832 | 1.868 | 1.853 | 0.031 | 0.076 | -0.714 | 6/6 | -0.681 | 6/6 | -0.689 | 6/6 |
| launch.fill.1.busywait15us | 17.610 | 16.884 | 16.935 | 16.921 | 0.020 | 0.092 | -0.730 | 6/6 | -0.687 | 6/6 | -0.701 | 6/6 |
| launch.fill.20480 | 2.561 | 1.832 | 1.865 | 1.852 | 0.018 | 0.080 | -0.732 | 6/6 | -0.697 | 6/6 | -0.710 | 6/6 |
| launch.fill.655360 | 2.535 | 1.813 | 1.840 | 1.842 | 0.030 | 0.098 | -0.728 | 6/6 | -0.707 | 6/6 | -0.699 | 6/6 |
| pairwise_sum.5 | 19.628 | 19.055 | 19.185 | 19.171 | 0.279 | 0.872 | -0.581 | 5/6 | -0.418 | 6/6 | -0.450 | 6/6 |
| pairwise_sum.7 | 36.989 | 36.930 | 36.799 | 37.148 | 0.607 | 20.062 | +0.051 | 3/6 | -0.384 | 5/6 | +0.246 | 3/6 |
| area_fraction_above.5 | 25.814 | 30.676 | 27.913 | 27.987 | 1.561 | 9.325 | +4.797 | 1/6 | +3.755 | 1/6 | +2.714 | 1/6 |
| segmented_sum.7over5 | 4.453 | 3.927 | 4.009 | 4.007 | 0.102 | 0.226 | -0.517 | 6/6 | -0.420 | 6/6 | -0.463 | 6/6 |
| segmented_sum.7over4 | 4.299 | 3.776 | 3.886 | 3.910 | 0.043 | 0.158 | -0.514 | 6/6 | -0.402 | 6/6 | -0.392 | 6/6 |
| segmented_mean.7over4 | 39.567 | 32.340 | 32.474 | 37.678 | 4.820 | 19.565 | -6.189 | 4/6 | -7.283 | 4/6 | -1.627 | 3/6 |
| segmented_quantile.7over5 | 18.148 | 17.424 | 18.696 | 18.336 | 0.242 | 1.047 | -0.688 | 6/6 | +0.583 | 1/6 | +0.197 | 1/6 |
| segmented_quantile.7over4 | 11.674 | 11.117 | 12.001 | 11.989 | 0.141 | 0.725 | -0.616 | 6/6 | +0.317 | 1/6 | +0.232 | 1/6 |

**`Backends.CPU()`, where batch and host agree to 0.001, batch**

| case | A | D | E | F | A/A med | A/A max | D-A | D faster | E-A | E faster | F-A | F faster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch.fill.1 | 0.534 | 0.011 | 0.011 | 0.024 | 0.001 | 0.065 | -0.526 | 6/6 | -0.528 | 6/6 | -0.514 | 6/6 |
| launch.fill.1.busywait15us | 15.571 | 15.040 | 15.041 | 15.057 | 0.003 | 0.024 | -0.531 | 6/6 | -0.531 | 6/6 | -0.515 | 6/6 |
| launch.fill.20480 | 8.768 | 7.741 | 7.873 | 8.146 | 0.500 | 1.290 | -1.346 | 6/6 | -0.987 | 6/6 | -0.804 | 6/6 |
| launch.fill.655360 | 97.087 | 94.584 | 94.453 | 92.258 | 9.556 | 24.171 | -3.167 | 5/6 | -3.524 | 4/6 | -6.132 | 4/6 |
| pairwise_sum.5 | 9.369 | 8.419 | 8.527 | 8.547 | 0.213 | 1.294 | -0.970 | 6/6 | -0.814 | 6/6 | -0.935 | 6/6 |
| pairwise_sum.7 | 68.956 | 67.456 | 67.390 | 67.427 | 1.011 | 9.335 | -1.726 | 6/6 | -1.423 | 5/6 | -1.091 | 5/6 |
| area_fraction_above.5 | 13.711 | 12.632 | 12.735 | 12.198 | 0.541 | 2.052 | -0.934 | 6/6 | -0.741 | 5/6 | -1.191 | 5/6 |
| segmented_sum.7over5 | 24.953 | 22.743 | 24.822 | 23.318 | 2.989 | 18.040 | -4.618 | 6/6 | -0.178 | 3/6 | -4.213 | 4/6 |
| segmented_sum.7over4 | 29.357 | 28.081 | 29.397 | 28.308 | 0.745 | 5.035 | -0.532 | 4/6 | +1.192 | 1/6 | -0.899 | 4/6 |
| segmented_mean.7over4 | 349.094 | 345.934 | 348.489 | 346.652 | 4.740 | 18.625 | -1.478 | 3/6 | -1.169 | 3/6 | -1.389 | 3/6 |
| segmented_quantile.7over5 | 462.272 | 461.159 | 467.704 | 464.482 | 10.204 | 206.446 | +1.222 | 3/6 | +5.319 | 1/6 | +1.801 | 3/6 |
| segmented_quantile.7over4 | 859.515 | 854.741 | 863.408 | 856.068 | 9.803 | 37.879 | -1.628 | 4/6 | +1.150 | 3/6 | +0.444 | 3/6 |

**first call with its completion, seconds, median over processes**

| backend, case | A | D | E | F |
| --- | --- | --- | --- | --- |
| GPU launch.fill.1 | 5.385 | 4.465 | 5.899 | 5.894 |
| GPU launch.fill.1.busywait15us | 0.000 | 0.000 | 0.000 | 0.000 |
| GPU launch.fill.20480 | 0.286 | 0.185 | 0.146 | 0.148 |
| GPU launch.fill.655360 | 0.001 | 0.000 | 0.001 | 0.001 |
| GPU pairwise_sum.5 | 0.615 | 0.583 | 0.599 | 0.607 |
| GPU pairwise_sum.7 | 0.306 | 0.291 | 0.281 | 0.274 |
| GPU area_fraction_above.5 | 0.257 | 0.233 | 0.239 | 0.242 |
| GPU segmented_sum.7over5 | 0.204 | 0.183 | 0.184 | 0.188 |
| GPU segmented_sum.7over4 | 0.000 | 0.000 | 0.000 | 0.000 |
| GPU segmented_mean.7over4 | 0.392 | 0.358 | 0.373 | 0.376 |
| GPU segmented_quantile.7over5 | 0.548 | 0.576 | 0.573 | 0.589 |
| GPU segmented_quantile.7over4 | 0.359 | 0.385 | 0.369 | 0.370 |
| CPU launch.fill.1 | 0.100 | 0.000 | 0.000 | 1.205 |
| CPU launch.fill.1.busywait15us | 0.000 | 0.000 | 0.000 | 0.000 |
| CPU launch.fill.20480 | 0.006 | 0.006 | 0.006 | 0.006 |
| CPU launch.fill.655360 | 0.000 | 0.000 | 0.000 | 0.000 |
| CPU pairwise_sum.5 | 0.074 | 0.068 | 0.070 | 0.195 |
| CPU pairwise_sum.7 | 0.000 | 0.000 | 0.000 | 0.000 |
| CPU area_fraction_above.5 | 0.079 | 0.071 | 0.074 | 0.217 |
| CPU segmented_sum.7over5 | 0.082 | 0.076 | 0.078 | 0.199 |
| CPU segmented_sum.7over4 | 0.000 | 0.000 | 0.000 | 0.000 |
| CPU segmented_mean.7over4 | 0.157 | 0.146 | 0.152 | 0.400 |
| CPU segmented_quantile.7over5 | 0.180 | 0.361 | 0.361 | 0.347 |
| CPU segmented_quantile.7over4 | 0.120 | 0.281 | 0.281 | 0.281 |
