# Fusing area_fraction_above's two block-sum kernels into one halves the small case and moves the large one by a fourteenth, and the shared-memory form beats the portable text on the card at both sizes

Measured on 2026-09-13 on yggdrasil through `qrun`, Julia 1.12.7, CUDA.jl 6.3.1,
KernelAbstractions.jl 0.9.42, Adapt.jl 4.7.0, driver 610.57.04, one NVIDIA GeForce RTX
4090. The base arm is `main` between `c25426c2efd4a10abf65ba80c5c20fd10a12dc45` and
`555bad1f12774b0a3f5d69399d43f554a788b8e8` (the commits in between touch neither
`src/`, `bench/` nor `test/reductions/`, confirmed by `git diff --stat`, so every
sample measured the same code regardless of which of those commits was checked out
at the instant it ran). The branch arm is `fiddlybits-ool` at
`6b65573c49bf6acbd88565ffdae8ad418180ace6`. `bench/runbench.jl` is at sha256
`014090906589030b6af54947217f9c7e84cf652b89809f61cf3848f2d2e1e22c` on both. The row
is `fiddlybits-ool`.

## What changed

`area_fraction_above` called `pairwise_block_sums` over `areas` and
`area_weighted_block_sums` over `xs` and `areas`, two launches that each walk every
block's indices, `areas` read once by each. `Reductions.area_fraction_block_kernel!`
(portable) and `Reductions.area_fraction_block_shared_kernel!` (device form, decision
0051) carry both accumulators in one kernel: `total += T(areas[j])` and
`above += T(ifelse(xs[j] >= x, areas[j], zero(eltype(areas))))`, in the same
expressions and order `pairwise_block_kernel!` and `area_weighted_block_kernel!` used,
writing an `nb`-by-2 block array (column 1 the total, column 2 the weighted sum)
instead of two separate arrays. `area_fraction_above` reads this one door and combines
each column through `combine_fixed_order` exactly as it combined the two separate
arrays before. `Reductions.launch_block_sums!` (`src/Reductions/pairwise.jl`) reads
its block count from `size(partials, 1)` rather than `length(partials)`, so the one
dispatcher serves both the one-column callers (`pairwise_block_sums`,
`area_weighted_block_sums`, unaffected: `size(v, 1) == length(v)` for a vector) and
the fused kernel's two-column array.

## Correctness

`area_fraction_above` on a fixed CPU input (4133 elements, the fixture formula) is
bitwise identical, as `UInt64` bits, before and after this change:
`0.34737785933231863` either way, checked directly against the pre-change call chain
(`pairwise_block_sums` and `area_weighted_block_sums` combined separately) rather than
only against the reference. It agrees with `area_fraction_above_reference` to
`2.22e-16`, inside the declared error bound. `test/reductions/quantiles.jl`'s own
"area_fraction_above's one read is bitwise the two reads it replaced" test continues
to hold, unchanged, and is now also a regression check for this fusion: it compares
`area_fraction_above` against the same two-kernel call chain the fused kernel
replaces, on `CPU` and on `GPU`. The not-positive-total refusal is untouched (the
check runs before either kernel is dispatched) and its test
(`area_fraction_above refuses a length mismatch or a non-positive total area`) is
unchanged. `test/reductions/shared_block_kernels.jl` adds the fused kernel's own
decision-0051 bitwise test: the shared-memory form against the portable form launched
directly on the card, against `CPU`, over every block full, a partial last block, one
block shorter than a block, one element, the declared blocksize and a second one that
divides none of them, and three thresholds (below all, mid-range, above all); a
positive control mutates an area at an index the threshold excludes (moves only the
total column) and one it includes (moves both columns), telling the two accumulators
apart.

## Device form against the portable text on the card (decision 0051, condition 3)

The portable kernel launched directly on the `GPU` backend (one work item per block,
reading global memory, bypassing `launch_block_sums!`'s own dispatch to the
shared-memory form) against `Reductions.area_fraction_above`, which dispatches to the
shared-memory form automatically for any `GPU` backend. Two runs, `qrun -p gpu`
(`shards = 4/4`), 60 batches of 400 calls each after 5 discarded, minimum
microseconds per call, run order swapped between the two to rule out a warm-up bias:

| level | run | device (shared) | portable (per-lane, on GPU) | portable less device | as pc of portable |
| --- | --- | --- | --- | --- | --- |
| 5 | 1 (device first) | 22.017 | 48.662 | 26.645 | 54.76 |
| 5 | 2 (portable first) | 22.013 | 49.017 | 27.004 | 55.09 |
| 7 | 1 (device first) | 78.044 | 96.733 | 18.689 | 19.32 |
| 7 | 2 (portable first) | 79.115 | 96.243 | 17.128 | 17.80 |

Both levels and both orderings show the device form faster by well over the bed's A/A
range (`notes/findings/2026-09-12-reduction-bench-scatter.md`: 2.7 to 15.2 per cent on
a single run, about 1 per cent on the mean of twenty), so the device form is kept, and
`Reductions.launch_block_sums!` dispatches to it for any `GPU` backend as it already
does for `pairwise_block_sums` and `area_weighted_block_sums`. The probe script is
kept outside the tree, per this row's file boundary.

## Before and after on the registered bench (fiddlybits-hth)

Twenty fresh processes per arm, each its own `qrun -p gpu` job (`shards = 4/4`,
`held_all_shards = true` on every one of the forty). `fiddlybits-6nh` investigated the
historical two-level split at this case
(`notes/findings/2026-09-13-area-fraction-above-shows-one-level-in-every-condition-
tried.md`) and closed without establishing its mechanism, but found it did not
reproduce under `qrun -p gpu`, under genuinely solo `gpu-share`, or under any of nine
neighbour profiles tried; this row's own forty runs show the same single level on
both arms, consistent with that finding. Base arm: host load 2.18 to 10.91, startup
3.27 to 7.53 s, measuring 30.3 to 32.5 s. Branch arm: host load 2.45 to 29.48 (one
sample shared the node with unrelated CPU work; the card itself was held exclusively
throughout, `held_all_shards = true`), startup 3.24 to 3.76 s, measuring 29.0 to
31.4 s. Every sample cleared the bed's declared floor of four times its own startup.

Microseconds per call, the minimum statistic, mean and sd over twenty samples:

| case | base mean | base sd | branch mean | branch sd | branch less base | as pc of base |
| --- | --- | --- | --- | --- | --- | --- |
| area_fraction_above, level 5 | 28.944 | 0.171 | 21.882 | 0.242 | -7.062 | -24.40 |
| area_fraction_above, level 7 | 84.635 | 0.415 | 78.256 | 0.336 | -6.379 | -7.54 |
| pairwise_sum, level 5 | 19.134 | 0.268 | 19.498 | 0.547 | +0.363 | +1.90 |
| pairwise_sum, level 7 | 48.689 | 0.347 | 48.934 | 0.367 | +0.245 | +0.50 |
| segmented_sum, depth 2 | 4.365 | 0.065 | 4.325 | 0.066 | -0.041 | -0.93 |
| segmented_sum, depth 3 | 7.797 | 0.063 | 7.803 | 0.053 | +0.006 | +0.08 |
| segmented_weighted_sum, depth 2 | 5.329 | 0.011 | 5.341 | 0.016 | +0.012 | +0.22 |
| segmented_weighted_sum, depth 3 | 16.182 | 0.280 | 16.075 | 0.198 | -0.108 | -0.66 |
| segmented_mean, depth 2 | 23.033 | 0.173 | 23.096 | 0.359 | +0.064 | +0.28 |
| segmented_mean, depth 3 | 33.405 | 0.419 | 33.543 | 0.333 | +0.138 | +0.41 |
| segmented_quantile, depth 2 | 27.700 | 0.070 | 27.824 | 0.242 | +0.125 | +0.45 |
| segmented_quantile, depth 3 | 28.466 | 0.035 | 28.537 | 0.217 | +0.071 | +0.25 |

Both cases this row touches clear the bed's A/A range (about 1 per cent on the mean of
twenty) by a wide margin. The ten cases that call neither changed kernel move by under
2 per cent, consistent with the bed's own scatter and not with a mechanism.

## area_fraction_above.7: one level on both arms, no split

Per sample, in the order run, minimum microseconds per call:

- base (main): 84.508 84.323 84.612 85.067 85.101 84.816 84.487 84.711 84.098 85.162
  84.952 83.639 84.070 84.747 84.697 84.979 85.106 84.093 84.888 84.646
- branch (fiddlybits-ool): 78.211 77.982 77.992 77.953 78.145 79.283 77.940 78.417
  78.270 78.434 78.231 78.580 77.808 78.228 78.438 78.549 77.780 78.194 78.408 78.271

Base arm: min 83.639, max 85.162, full range 1.523 (1.80 per cent of the mean).
Branch arm: min 77.780, max 79.283, full range 1.503 (1.92 per cent of the mean). One
cluster on each arm, not two: every sample of both arms falls inside a band under 2
per cent wide, well short of the 20 to 28 per cent gap the historically named levels
showed under the repository's default `gpu-share` profile. This row's own
before-and-after therefore compares one level to one level, as `fiddlybits-6nh`'s note
to this row asked for.

## References

- `notes/findings/2026-09-13-block-sums-in-shared-memory.md`, the individual
  `pairwise_block_sums` and `area_weighted_block_sums` device forms this row fuses,
  and decision 0051's four conditions.
- `notes/findings/2026-09-13-area-fraction-above-shows-one-level-in-every-condition-
  tried.md`, the finding that closed `fiddlybits-6nh`: the historical two-level split
  does not reproduce under `qrun -p gpu`, under genuinely solo `gpu-share`, or under
  any of nine neighbour profiles tried, and its mechanism is not established.
- `notes/findings/2026-09-12-reduction-bench-scatter.md`, the bed's A/A range a gain is
  measured against.
- Decision 0051, the device-form conditions; decision 0055, why no kernel here carries
  `@inbounds`; decision 0027, the reference path both forms are checked against.
- `fiddlybits-hth`, the registered bench cases this row's before and after report
  against.
