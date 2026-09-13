# With every reduction kernel reading under @inbounds, the area-weighted and area-fraction device forms still beat the portable text on the card at both bench levels, the pairwise device form beats it up to 245760 elements and loses above, and the bench moves by two to five per cent with every result bitwise unchanged

Measured on 2026-09-13 on yggdrasil, NVIDIA GeForce RTX 4090, driver 610.57.04, Julia
1.12.7, CUDA.jl 6.3.1, KernelAbstractions.jl 0.9.42, GPUCompiler 2.6.0. Every timing ran
through `qrun -p gpu` (all four shares, 8 CPUs, 24G, 18G of vram); every bench sample read
`held_all_shards = true`. The base arm is `main` at
`48420c5de6353315d698dee0893cf76c6f068e1f`, unpacked by `git archive` so it could not
move. The branch arm is `fiddlybits-2c9` with `src/Reductions/pairwise.jl` at sha256
`429ae56f6903a38342478dd1b64aff903681808775fab23e1a972aaa268344da`, `quantiles.jl` at
`a6abfbca7dc928277b0ba504e7d3fed9d1cb1cf9d211d5724a95ac76c287ff43` and `segmented.jl` at
`3a9141755886e811252b1c6075b5cc861c4a3108638c02b79ab429d4d9df2faf`; `bench/runbench.jl`
is at `014090906589030b6af54947217f9c7e84cf652b89809f61cf3848f2d2e1e22c` on both arms.
The row is `fiddlybits-2c9`; decision 0055 is what it applies, and decision 0051 is what
the device forms are re-weighed under. The probe scripts lived outside the tree.

## What changed

Every KernelAbstractions kernel in `src/Reductions/` reads and writes under `@inbounds`,
on its serial loop and its write, and on the lane's copy into shared memory where it has
one: `pairwise_block_kernel!`, `pairwise_block_shared_kernel!`,
`segmented_sum_kernel!`, `segmented_weighted_sum_kernel!`, `segmented_mean_kernel!`,
the five generated `segmented_bitonic_kernel_{4,16,64,256,1024}!`,
`area_weighted_block_kernel!`, `area_weighted_block_shared_kernel!`,
`area_fraction_block_kernel!` and `area_fraction_block_shared_kernel!`. No kernel is
given `inbounds=true`, and no host code carries `@inbounds`.

Each launch sits behind one door that checks on the host every length the kernel's
indices are derived from and refuses through `Verdicts.refuse`, naming the array and both
lengths:

- `Reductions.launch_block_sums!`: `partials` is `cld(n, blocksize)` rows by the kernel's
  column count, every array input holds `n`, `blocksize` is positive.
- `Reductions.launch_segments!`: every output holds `nseg`, every input `nelement`, `lo`
  and `hi` each `nseg`. `Reductions.Segmentation` is built only by its checked
  constructor, so the values of `lo` and `hi` lie in `1:nelement`.
- `Reductions.launch_quantiles!`: `out` and `base` hold `nseg`, `xs` holds `nseg * 4^k`,
  `partner` and `ascending` are `4^k` by the network's step count, `rank` is in `1:4^k`,
  `k` is in the declared range.

`test/reductions/edge_shapes.jl` runs every one of these on `Backends.CPU(8)` and on
`Backends.GPU(8)` against the reference path, and each door with each argument one element
short.

## The arithmetic did not move

Every reduction on the bench's registered cases (`pairwise_sum` and `area_fraction_above`
at levels 5 and 7 with their block sums, `area_weighted_block_sums` and
`area_weighted_sum` at both, and `segmented_sum`, `segmented_weighted_sum`,
`segmented_mean` and `segmented_quantile` over level 7 at levels 5 and 4), and a set of
type mixes over level 5 at level 3 (`Float32` and `Float64` elements, weights and
accumulator for the sums, means and area sums, `Float32` and `Float64` quantiles, and
`Bool` into `Int` for `pairwise_sum`), was written as raw bytes on `Backends.CPU(256)` and
on `Backends.GPU(256)`. The 138 sha256 values from the base arm and from the branch as
committed are identical, line for line.

The reductions suite, with the edge shapes and the door controls, passed under the default
and under `--check-bounds=yes`, and `kernels.reduction_partition_independent` and the
fixed-order and thread-count tests passed in both.

## The CPU run under the flag is what catches an index below a block start

A copy of the branch with `pairwise_block_kernel!`'s block start moved one down
(`lo = blocksize * i - blocksize`), `pairwise_block_sums` over 1061 elements against the
per-block reference:

| backend | `--check-bounds=auto` | `--check-bounds=yes` |
| --- | --- | --- |
| CPU | differs from the reference | `BoundsError: attempt to access 1061-element Vector{Float64} at index [0]` |
| GPU | agrees with the reference | agrees with the reference |

The card ran the device form, which derives no block start, and so saw nothing; the CPU
backend's run of the portable text raised under the flag and read silently without it.

## The device forms against the single @inbounds text

Both forms under `@inbounds` on the card at the bench's workgroup of 256, the bench's
statistic (the minimum over 60 batches of 400 calls closed by one `Backends.complete!`,
of the mean per call, after 5 discarded), in microseconds per call. "device" is the public
function, which launched the device form at both levels when this ran; "portable" allocates
the same result and launches the portable kernel through `Backends.launch!` on the same
backend, with the host combine where the row is a whole reduction. Six rounds, the arm
order reversed on every second round; the median and the span (largest less smallest) over
the six. One job, host load 2.04 to 2.38; the job was the only one holding a share before
and after. Both forms were bitwise identical at every row's input.

| level | case | device | span | portable | span | portable less device | pc of portable |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 5 | pairwise_block_sums | 6.161 | 0.465 | 14.485 | 0.060 | +8.324 | +57.5 |
| 5 | pairwise_sum | 19.231 | 0.388 | 27.458 | 0.593 | +8.227 | +30.0 |
| 5 | area_weighted_block_sums | 6.210 | 0.012 | 20.646 | 0.102 | +14.436 | +69.9 |
| 5 | area_fraction_block_sums | 7.194 | 0.011 | 23.680 | 0.385 | +16.486 | +69.6 |
| 5 | area_fraction_above | 21.748 | 0.278 | 37.956 | 0.200 | +16.207 | +42.7 |
| 7 | pairwise_block_sums | 25.677 | 0.091 | 24.805 | 0.068 | -0.872 | -3.5 |
| 7 | pairwise_sum | 49.210 | 2.010 | 48.046 | 0.819 | -1.164 | -2.4 |
| 7 | area_weighted_block_sums | 21.757 | 0.074 | 48.072 | 0.044 | +26.316 | +54.7 |
| 7 | area_fraction_block_sums | 40.665 | 0.089 | 48.340 | 0.057 | +7.675 | +15.9 |
| 7 | area_fraction_above | 78.890 | 1.001 | 86.428 | 4.156 | +7.538 | +8.7 |

Controls, level 5, `pairwise_block_kernel!` launched as the portable arm: 14.527 as is,
19.474 with a 15 us host busy-wait before each call (host 4.265 and 19.431), and 3107.261
over one block of `2^16` elements (host 4.399). The busy-wait moves host and batch
together, the long loop moves batch alone; the instrument separates time on the host from
time on the card.

What a difference has to clear: the bench's own twenty-process arms below are the A/A
range of the bed as it runs now, on four shares. The full range of the ten lowest samples
of the base arm is 1.342 on `pairwise_sum` at level 5, 3.204 at level 7, 0.976 on
`area_fraction_above` at level 5 and 3.631 at level 7.

- **The area-weighted and area-fraction device forms stay at both levels.** They beat the
  portable text by 14.4 and 26.3 us, and by 16.5 and 7.7 us, at levels 5 and 7, over every
  range above and over the probe's own spans.
- **The pairwise device form stays at level 5 and goes at level 7.** At level 5 it beats
  the portable text by 8.3 us; at level 7 it is slower by 0.87 us on the block sums and 1.16
  on the whole reduction.

### Where the pairwise answer changes

The same two kernels over element counts between the two levels, four rounds each, same
statistic, one job, host load 2.50 to 2.56, no other job holding a share. Bitwise identical
at every count.

| elements | device | span | portable | span | portable less device |
| --- | --- | --- | --- | --- | --- |
| 20480 | 6.151 | 0.495 | 14.424 | 0.042 | +8.273 |
| 30720 | 6.159 | 0.006 | 14.521 | 0.002 | +8.362 |
| 40960 | 6.169 | 0.004 | 16.139 | 0.074 | +9.970 |
| 61440 | 6.197 | 0.004 | 23.251 | 0.011 | +17.054 |
| 81920 | 7.043 | 0.007 | 24.726 | 0.012 | +17.683 |
| 122880 | 8.671 | 0.007 | 24.739 | 0.046 | +16.068 |
| 163840 | 10.931 | 0.010 | 24.877 | 0.013 | +13.947 |
| 245760 | 20.571 | 0.080 | 24.757 | 0.046 | +4.186 |
| 327680 | 25.537 | 0.032 | 24.752 | 0.012 | -0.785 |

The device form is at the launch floor to 61440 and then grows with its lane count; the
portable text reaches a plateau from 81920, where the bench's workgroup puts every block
in one CUDA block of 256 threads. The last count measured faster is 245760, by 4.2 us.

So `Reductions.launch_block_sums!` on `GPU` launches a device form when the element count
is at most `Reductions.device_form_limit` of that form, and the portable kernel at the
backend's own workgroup above it: `Reductions.PAIRWISE_DEVICE_FORM_MAX`, 245760, for
`pairwise_block_shared_kernel!`, and no limit for the two area forms. Counts between 245760
and 327680 were not measured, and the dispatch gives them the portable text.
`test/reductions/shared_block_kernels.jl` holds the dispatch to the limit from both sides
by the kernel `Backends.queued` records, and the portable text on the card above it
bitwise to the reference and to the CPU backend.

## The area-weighted kernels, which no bench case calls

`area_weighted_block_sums` and `area_weighted_sum` through the public functions (the device
form on the card at both levels), six fresh processes per arm alternating base and branch in
one job, the same statistic, host load 3.20 to 3.91, no other job holding a share. Median
and span over the six, microseconds per call:

| level | case | base | span | branch | span | branch less base |
| --- | --- | --- | --- | --- | --- | --- |
| 5 | area_weighted_block_sums | 6.740 | 0.498 | 6.238 | 0.548 | -0.502 |
| 5 | area_weighted_sum | 19.569 | 0.257 | 19.928 | 2.356 | +0.359 |
| 7 | area_weighted_block_sums | 21.541 | 0.141 | 21.677 | 0.981 | +0.136 |
| 7 | area_weighted_sum | 45.692 | 3.784 | 45.463 | 3.416 | -0.229 |

Five of the six base samples of the block sums at level 5 read 6.738 to 6.744 and five of
the six branch samples 6.184 to 6.566, so the device form's elision takes 0.5 us off at
level 5. On the whole reduction at level 5, and on both rows at level 7, the difference is
inside the spans.

## The portable block-sum texts, checked against @inbounds

The three portable kernels launched directly through `Backends.launch!`, allocating their
result as the portable arm above does: on `Backends.GPU(256)` at levels 5 and 7 with the
same statistic, and on `Backends.CPU(256)` at level 7 in a process started with `-t 8`,
with 20 batches of 50 calls. Four fresh processes per arm alternating base and branch in
one job, host load 2.99 to 3.01, no other job holding a share. Median and span over the
four, microseconds per call:

| backend | level | kernel | checked (base) | span | `@inbounds` (branch) | span | branch less base |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GPU | 5 | pairwise_block_kernel! | 23.520 | 2.920 | 14.607 | 0.750 | -8.912 |
| GPU | 5 | area_weighted_block_kernel! | 32.895 | 3.386 | 21.764 | 1.489 | -11.130 |
| GPU | 5 | area_fraction_block_kernel! | 34.930 | 3.568 | 23.739 | 1.417 | -11.190 |
| GPU | 7 | pairwise_block_kernel! | 25.773 | 1.992 | 24.856 | 1.006 | -0.917 |
| GPU | 7 | area_weighted_block_kernel! | 55.783 | 6.399 | 48.448 | 3.715 | -7.335 |
| GPU | 7 | area_fraction_block_kernel! | 57.247 | 7.787 | 48.465 | 3.956 | -8.782 |
| CPU | 7 | pairwise_block_kernel! | 55.087 | 16.680 | 46.410 | 2.235 | -8.678 |
| CPU | 7 | area_weighted_block_kernel! | 78.980 | 8.904 | 61.300 | 5.130 | -17.680 |
| CPU | 7 | area_fraction_block_kernel! | 85.382 | 6.726 | 64.118 | 3.459 | -21.264 |

Every span is one sample in four; on the card at level 7 the other three samples of
`pairwise_block_kernel!` read 25.634 to 25.793 checked and 24.806 to 24.897 under
`@inbounds`. At level 7 the checked portable text, 25.77, and the checked device form
measured in
`notes/findings/2026-09-13-the-per-lane-block-kernel-pays-for-one-thread-s-checked-serial-reads.md`
(25.689, beside 25.416 for the checked portable text there) cost the same, so the level 7
change in `pairwise_sum` is the elision and not the change of form.

## Before and after on the registered bench (fiddlybits-hth)

Twenty pairs, each one `qrun -p gpu` job running the base arm and the branch arm as two
fresh processes, base first in odd pairs and branch first in even ones. Host load 2.37 to
12.8; startup 3.22 to 3.75 s; measuring 28.6 to 41.3 s, every sample over the bed's floor.

Microseconds per call, the minimum statistic. "paired" is the median over the twenty pairs
of branch less base within the same job, and "faster" counts the pairs where the branch
was:

| case | base mean | base sd | branch mean | branch sd | base median | branch median | paired | pc of base median | faster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pairwise_sum, level 5 | 20.967 | 2.195 | 20.019 | 2.116 | 20.029 | 18.823 | -0.474 | -2.37 | 16/20 |
| pairwise_sum, level 7 | 53.399 | 7.679 | 50.983 | 6.499 | 50.778 | 47.723 | -1.482 | -2.92 | 18/20 |
| area_fraction_above, level 5 | 23.643 | 2.323 | 22.269 | 1.968 | 22.562 | 21.516 | -1.060 | -4.70 | 18/20 |
| area_fraction_above, level 7 | 87.711 | 14.569 | 83.075 | 11.563 | 80.661 | 78.478 | -0.282 | -0.35 | 12/20 |
| segmented_sum, depth 2 | 4.300 | 0.090 | 4.321 | 0.081 | 4.320 | 4.313 | +0.012 | +0.29 | 8/20 |
| segmented_sum, depth 3 | 7.914 | 0.365 | 7.588 | 0.344 | 7.777 | 7.495 | -0.302 | -3.89 | 18/20 |
| segmented_weighted_sum, depth 2 | 5.340 | 0.016 | 5.217 | 0.011 | 5.336 | 5.219 | -0.123 | -2.30 | 20/20 |
| segmented_weighted_sum, depth 3 | 16.740 | 1.607 | 15.757 | 0.575 | 16.138 | 15.612 | -0.404 | -2.50 | 18/20 |
| segmented_mean, depth 2 | 24.634 | 2.677 | 24.100 | 2.015 | 23.407 | 23.076 | -0.260 | -1.11 | 12/20 |
| segmented_mean, depth 3 | 36.371 | 4.255 | 34.899 | 3.763 | 34.136 | 33.262 | -0.834 | -2.44 | 16/20 |
| segmented_quantile, depth 2 | 29.139 | 2.347 | 27.878 | 2.737 | 27.866 | 26.453 | -1.389 | -4.99 | 18/20 |
| segmented_quantile, depth 3 | 29.896 | 2.461 | 28.703 | 2.421 | 28.515 | 27.602 | -0.941 | -3.30 | 18/20 |

- **Ten cases move by 2.3 to 5.0 per cent**, the branch faster in 16 to 20 of the twenty
  pairs: twice the one per cent on the mean of twenty that
  `notes/findings/2026-09-12-reduction-bench-scatter.md` puts as the bed's A/A agreement,
  and more. `pairwise_sum` at level 7 carries both changes at once, the `@inbounds` read
  and the portable text in place of the device form.
- **Two do not**: `segmented_sum` at depth two, at the launch floor already
  (`notes/findings/2026-09-13-the-segmented-kernels-shared-memory-form-is-slower-on-every-bench-case.md`
  put its kernel within 0.03 of it under `@inbounds`), and `area_fraction_above` at level 7,
  -0.35 per cent with the branch faster in 12 of 20. `segmented_mean` at depth two, -1.11
  per cent in 12 of 20, is inside twice the A/A agreement too.
- **Ten of the forty processes ran slow on every case that reads back to the host**, 15
  to 40 per cent above the rest of their arm (`pairwise_sum`, `area_fraction_above`,
  `segmented_mean`, `segmented_quantile`; not `segmented_sum` nor `segmented_weighted_sum`).
  They fall on both arms, in pairs 13 to 19 (base in 14, 15, 16, 17, 18, 19; branch in 13,
  14, 15, 18), and do not follow the load, which was 2.9 to 4.0 across pairs 13 to 18. A
  slow process is slow on all four such cases at once, so the means and standard deviations
  above carry it, and the paired medians and the medians are what the verdicts read.

Per sample, in pair order, for every case (base, then branch):

- pairwise_sum, level 5: 20.029 18.687 19.066 19.130 20.030 19.542 19.987 20.263 20.268 19.417 19.183 20.237 19.059 23.896 24.493 24.368 24.389 23.704 24.105 19.479; 18.723 18.583 18.653 18.651 18.742 18.778 19.656 19.887 18.569 18.825 19.952 19.835 24.022 23.964 24.023 18.709 19.062 24.190 18.822 18.737
- pairwise_sum, level 7: 46.917 46.483 46.712 49.216 49.687 48.900 52.086 51.868 52.239 47.881 48.933 57.183 52.340 65.106 69.637 51.978 69.457 65.375 47.524 48.454; 45.346 45.759 45.319 50.518 47.701 47.536 49.842 50.976 47.423 47.016 48.330 50.901 64.113 63.139 62.135 47.744 47.530 63.579 47.081 47.674
- area_fraction_above, level 5: 21.701 21.486 21.578 22.121 22.433 22.098 23.469 23.101 22.662 22.462 22.267 23.648 23.502 27.263 28.052 27.324 26.941 27.418 21.746 21.579; 20.637 20.748 20.841 22.267 21.066 21.188 22.408 22.879 21.158 21.048 21.546 22.299 26.716 22.299 26.454 21.485 21.724 26.595 20.687 21.334
- area_fraction_above, level 7: 75.317 75.321 74.950 78.358 78.581 78.401 83.884 83.739 82.741 78.310 78.405 95.036 83.174 110.936 112.314 112.953 109.779 109.377 75.021 77.634; 74.577 74.808 75.193 78.603 78.152 78.605 82.206 84.003 78.467 78.415 78.269 83.115 110.084 107.262 79.434 78.178 78.489 110.361 74.992 78.280
- segmented_sum, depth 2: 4.225 4.052 4.154 4.312 4.256 4.334 4.404 4.321 4.319 4.366 4.303 4.323 4.332 4.331 4.307 4.374 4.465 4.342 4.199 4.280; 4.298 4.140 4.279 4.238 4.267 4.396 4.349 4.318 4.266 4.292 4.282 4.345 4.331 4.473 4.321 4.259 4.493 4.349 4.421 4.308
- segmented_sum, depth 3: 7.748 7.732 7.742 7.924 7.945 7.755 7.816 7.761 7.776 7.751 7.761 7.778 7.752 7.917 7.772 9.351 8.340 7.905 7.875 7.886; 7.511 7.496 7.498 7.519 7.501 7.511 7.483 7.499 7.508 7.491 7.443 7.448 8.953 7.494 7.485 7.463 7.470 8.030 7.482 7.472
- segmented_weighted_sum, depth 2: 5.350 5.322 5.321 5.340 5.326 5.336 5.333 5.323 5.331 5.334 5.337 5.336 5.335 5.377 5.356 5.343 5.340 5.378 5.340 5.335; 5.226 5.198 5.203 5.226 5.218 5.214 5.214 5.224 5.207 5.207 5.206 5.209 5.223 5.224 5.231 5.202 5.221 5.238 5.219 5.223
- segmented_weighted_sum, depth 3: 15.809 15.527 15.986 16.159 16.118 16.026 16.069 16.713 16.197 15.885 16.468 16.171 16.505 16.690 18.808 21.026 20.996 15.856 15.825 15.961; 15.558 15.359 15.114 15.603 15.750 16.015 15.732 15.424 15.824 15.443 15.655 15.759 15.667 17.219 15.538 15.368 15.622 17.452 15.468 15.566
- segmented_mean, depth 2: 22.062 22.604 23.046 23.253 23.443 23.028 24.283 24.447 23.008 23.372 23.323 24.833 23.487 24.615 28.869 30.336 29.668 29.695 22.310 22.987; 22.869 22.731 22.798 22.980 22.964 22.755 24.285 24.451 23.041 22.942 22.691 24.243 29.193 27.259 24.325 23.111 23.179 28.961 24.369 22.844
- segmented_mean, depth 3: 33.186 33.759 33.256 33.825 33.728 34.277 34.990 34.714 33.995 34.718 33.967 36.750 33.864 39.126 43.547 44.427 44.273 44.602 33.100 33.308; 32.814 32.188 32.599 32.919 33.030 32.903 34.656 35.362 33.234 33.112 32.803 35.254 43.445 43.334 33.291 33.737 33.385 43.485 33.371 33.066
- segmented_quantile, depth 2: 27.818 27.685 27.716 27.754 27.807 27.743 28.726 28.792 27.779 27.730 27.893 29.311 33.886 27.842 33.223 33.418 27.889 33.986 27.789 27.998; 26.438 26.417 26.430 26.416 26.409 26.436 27.299 27.285 26.372 26.398 26.350 27.242 32.863 31.856 26.403 35.303 26.467 32.136 26.486 26.544
- segmented_quantile, depth 3: 28.444 28.452 28.421 28.473 28.480 28.499 29.322 29.754 28.512 28.482 28.485 29.977 34.475 28.519 34.321 34.757 28.490 34.891 28.578 28.580; 27.507 27.480 27.489 27.563 27.562 27.543 28.431 28.518 27.551 27.536 27.548 28.451 34.927 34.100 27.584 27.633 27.650 33.721 27.647 27.620

## The gain each elision is taken on

- `pairwise_block_shared_kernel!`: `pairwise_sum` at level 5, -2.37 per cent, 16 of 20.
- `pairwise_block_kernel!`: `pairwise_sum` at level 7, -2.92 per cent, 18 of 20; directly,
  -0.92 us on the card at level 7 and -8.68 us on the CPU backend.
- `area_fraction_block_shared_kernel!`: `area_fraction_above` at level 5, -4.70 per cent,
  18 of 20. At level 7 the bench does not resolve a change.
- `area_weighted_block_shared_kernel!`: -0.50 us on its block sums at level 5; nothing
  resolved at level 7.
- `area_weighted_block_kernel!` and `area_fraction_block_kernel!`, which the CPU backend
  runs: -17.68 and -21.26 us there at level 7, and -7.3 to -11.2 us launched on the card.
- `segmented_sum_kernel!`: depth three, -3.89 per cent, 18 of 20.
- `segmented_weighted_sum_kernel!`: both depths, -2.30 and -2.50 per cent.
- `segmented_mean_kernel!`: depth three, -2.44 per cent, 16 of 20.
- `segmented_bitonic_kernel_16!` and `_64!`: -4.99 and -3.30 per cent, 18 of 20 each. The
  kernels for 4, 256 and 1024 are the same generated text at another segment length and are
  not on the bench.

## The gate's door on this branch

`tools/gate/gate.sh` from the worktree, before the commit, printed at its start and again
at its end:

```
gate: bounds door against main at 48420c5de635: 6 changed .jl file(s) elide a bounds check; every suite also runs under --check-bounds=yes
gate:   src/Reductions/pairwise.jl at line(s) 23, 26, 42, 47, 50
gate:   src/Reductions/quantiles.jl at line(s) 165, 168, 183, 365, 368, 377, 382, 385, 461, 465, 466, 476, 477, 483, 487, 488
gate:   src/Reductions/segmented.jl at line(s) 168, 171, 238, 241, 317, 321, 322
gate:   test/nightly/fixtures/inbounds_inside_kernel.jl at line(s) 8, 14
gate:   test/nightly/fixtures/inbounds_outside_kernel.jl at line(s) 12
gate:   test/nightly/fixtures/kernel_inbounds_true.jl at line(s) 6
gate: the door's 7 controls came out as stated
gate: under --check-bounds=yes kernels under @inbounds read checked on cpu and checked on gpu
```

All 17 suites passed in both passes: wall 274.5 s, sum of suites 1354.0 s, `certify+bounds`
274.4 s, `certify` 171.4 s, `backends+bounds` 133.5 s, `backends` 124.7 s,
`reductions+bounds` 118.6 s, `reductions` 109.3 s.

## Anomalies not explained here

- The slow processes of pairs 13 to 19, on both arms and only on the cases that read back
  to the host, with no load to match. `fiddlybits-6nh` found no such split on
  `area_fraction_above` at level 7 under `qrun -p gpu`; here it reaches four cases at once.
- The portable text's plateau from 81920 elements to 327680 at about 24.8 us, while its
  work grows fourfold.
