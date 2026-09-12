# A single run of the reduction bench carries up to four per cent, the mean of twenty agrees to one, and the host's load moves neither

Measured on 2026-09-12 on yggdrasil through `qrun` with this repository's defaults
(profile `gpu-share`, one share of an NVIDIA GeForce RTX 4090, 8 CPUs, 16G), Julia
1.12.7, CUDA.jl 6.3.1, KernelAbstractions.jl 0.9.42, Adapt.jl 4.7.0, on branch
`fiddlybits-hth` at `5e496a4fe89c1423a60d269e57c715de454a3faa` with
`bench/runbench.jl` at sha256 `93b5ce5b79c68a8b29847d9da40e1eba211beff1efcb543cb6a945f28416e52f`.
The row is `fiddlybits-hth`.

`bench/runbench.jl` registers twelve GPU-resident cases and no bar. Decision 0029
fixes a bar only once the A/A scatter of the bed is known, because a bar narrower
than its instrument's scatter is refused at registration. This is that scatter, the
values the optimisation rows report their before and after against, and the two
reasons the bar stays unset beyond it.

## The bed

Every case moves its inputs to the device once and then calls one reduction, 400
calls to a batch closed by one `Backends.complete!`, 200 batches sampled after two
discarded. The statistic is the minimum over batches of the mean seconds per call;
the median over batches is reported beside it. The segmented cases call the
`Segmentation` form, which reads no boundary array back to the host, and the
`Segmentation` is built outside the timing.

The segment shapes are real level crossings (decision 0005): the elements are the
cells of level 7, and a segment is one coarse cell's `4^k` descendants, at depth two
from level 5 and at depth three from level 4. No profile exists to read the levels
from; `fiddlybits-2pn` carries that.

A single call timed on its own does not reproduce, for the reason
`notes/findings/2026-09-11-area-fraction-in-one-read.md` measured, which is why the
unit here is a batch.

## The A/A pair

Two arms differing in nothing, interleaved sample by sample so that drift in the
host falls on both. One fresh process per sample, twenty samples each arm. Host load
average 1.08 to 14.59 over the campaign; startup 3.18 to 3.63 s per sample and 44.5
to 48.7 s measuring, so every sample cleared the bed's declared floor of four times
its own startup.

Microseconds per call, the minimum statistic:

| case | A mean | B mean | A less B | as pc of A | pooled sd | pooled sd over mean | full range |
| --- | --- | --- | --- | --- | --- | --- | --- |
| pairwise_sum, level 5 | 36.181 | 35.832 | +0.348 | +0.96 | 1.151 | 3.20 pc | 8.2 pc |
| pairwise_sum, level 7 | 50.169 | 49.805 | +0.364 | +0.73 | 1.694 | 3.39 pc | 9.3 pc |
| area_fraction_above, level 5 | 73.790 | 73.492 | +0.298 | +0.40 | 2.295 | 3.12 pc | 8.4 pc |
| area_fraction_above, level 7 | 124.199 | 124.566 | -0.367 | -0.30 | 4.695 | 3.77 pc | 12.0 pc |
| segmented_sum, depth 2 | 4.349 | 4.340 | +0.009 | +0.21 | 0.041 | 0.95 pc | 5.6 pc |
| segmented_sum, depth 3 | 7.823 | 7.831 | -0.008 | -0.10 | 0.053 | 0.68 pc | 2.7 pc |
| segmented_weighted_sum, depth 2 | 5.349 | 5.345 | +0.004 | +0.08 | 0.035 | 0.65 pc | 4.2 pc |
| segmented_weighted_sum, depth 3 | 16.421 | 16.365 | +0.056 | +0.34 | 0.474 | 2.89 pc | 15.2 pc |
| segmented_mean, depth 2 | 54.649 | 55.051 | -0.402 | -0.74 | 1.848 | 3.37 pc | 9.0 pc |
| segmented_mean, depth 3 | 64.121 | 64.498 | -0.377 | -0.59 | 1.767 | 2.75 pc | 8.4 pc |
| segmented_quantile, depth 2 | 28.204 | 28.296 | -0.092 | -0.33 | 0.526 | 1.86 pc | 5.9 pc |
| segmented_quantile, depth 3 | 28.892 | 29.034 | -0.142 | -0.49 | 0.530 | 1.83 pc | 5.2 pc |

Two runs of the same bed agree in the mean of twenty to within one per cent on every
case, and the sign of the difference is not the same on all of them. A single sample
carries between 0.65 and 3.8 per cent, and the full range over forty samples reaches
15.2 per cent on the loosest case.

The same pair on the median statistic is looser everywhere: pooled sd over mean
between 1.6 and 5.0 per cent against 0.65 to 3.8 for the minimum, and the arms agree
to 1.2 per cent rather than 1.0. The minimum over 200 batches is the tighter arm and
is what a bar would judge.

## What the host's load does to it

The load instrument of `notes/findings/2026-09-11-load-latency-instrument.md` moved
by 58 per cent when six neighbours took the memory bandwidth around it. This bed does
not. Splitting the forty samples at the median load of 1.83:

| case | quiet half | busy half | busy less quiet | correlation with load |
| --- | --- | --- | --- | --- |
| pairwise_sum, level 5 | 35.865 | 36.148 | +0.79 pc | -0.12 |
| pairwise_sum, level 7 | 49.752 | 50.223 | +0.95 pc | -0.08 |
| area_fraction_above, level 5 | 73.504 | 73.777 | +0.37 pc | -0.12 |
| area_fraction_above, level 7 | 124.566 | 124.200 | -0.29 pc | -0.21 |
| segmented_sum, depth 2 | 4.338 | 4.351 | +0.28 pc | +0.25 |
| segmented_sum, depth 3 | 7.830 | 7.824 | -0.07 pc | +0.01 |
| segmented_weighted_sum, depth 2 | 5.342 | 5.352 | +0.19 pc | +0.52 |
| segmented_weighted_sum, depth 3 | 16.329 | 16.456 | +0.77 pc | -0.09 |
| segmented_mean, depth 2 | 54.988 | 54.712 | -0.50 pc | -0.13 |
| segmented_mean, depth 3 | 64.404 | 64.215 | -0.29 pc | -0.11 |
| segmented_quantile, depth 2 | 28.296 | 28.204 | -0.33 pc | -0.15 |
| segmented_quantile, depth 3 | 29.002 | 28.923 | -0.27 pc | -0.14 |

The halves differ by under one per cent on every case, in both directions, and the
correlation with load is near zero. A thirteen-fold range in host load moved nothing
here, where it moved the package load by three fifths. The work is on the card and
the host is dispatching it.

This is a statement about the host's CPUs and not about the card. Nothing in the
campaign recorded what else held a share of the GPU while a sample ran, so the
neighbour that would matter to this bed is the one it did not watch.
`fiddlybits-pgf` carries that.

## The values the optimisation rows compare against

Mean over all forty samples, microseconds per call:

| case | minimum | its sd | median | its sd |
| --- | --- | --- | --- | --- |
| pairwise_sum, level 5 | 36.007 | 1.151 | 38.043 | 1.884 |
| pairwise_sum, level 7 | 49.987 | 1.694 | 54.002 | 1.940 |
| area_fraction_above, level 5 | 73.641 | 2.295 | 77.986 | 2.920 |
| area_fraction_above, level 7 | 124.383 | 4.695 | 129.587 | 5.243 |
| segmented_sum, depth 2 | 4.345 | 0.041 | 4.509 | 0.073 |
| segmented_sum, depth 3 | 7.827 | 0.053 | 8.267 | 0.378 |
| segmented_weighted_sum, depth 2 | 5.347 | 0.035 | 5.637 | 0.264 |
| segmented_weighted_sum, depth 3 | 16.393 | 0.474 | 16.981 | 0.759 |
| segmented_mean, depth 2 | 54.850 | 1.848 | 59.258 | 2.575 |
| segmented_mean, depth 3 | 64.309 | 1.767 | 68.621 | 2.468 |
| segmented_quantile, depth 2 | 28.250 | 0.526 | 29.626 | 1.327 |
| segmented_quantile, depth 3 | 28.963 | 0.530 | 30.352 | 1.336 |

Three things in this table are the claims the optimisation rows on the board were
raised against, recorded here as numbers rather than as readings of the source.

- `segmented_mean` costs twelve times `segmented_sum` at depth two and eight times it
  at depth three, on the same elements and the same segmentation, where it is a
  segmented weighted sum, a segmented sum, a check on the weights and a division.
  That is the five launches and the host sync `fiddlybits-3jt` names.
- `segmented_sum` at depth three costs 1.80 times the same call at depth two over the
  same 327680 elements, and `segmented_weighted_sum` 3.07 times. The element count is
  identical and only the segment length changed, which is the lane stride
  `fiddlybits-2tg` and `fiddlybits-zgh` name.
- `area_fraction_above` costs 2.05 times `pairwise_sum` at level 5 and 2.49 times it
  at level 7, where it is two block-sum passes over the same areas.
  `fiddlybits-ool` names the second read.

`segmented_quantile` is the one case whose cost barely moves between the two
crossings, 28.963 against 28.250, although the second sorts segments four times
longer in a workgroup four times wider. What it does on every call regardless is
build a bitonic network and allocate a device array, which is what `fiddlybits-9j7`
names.

## The positive control

The bed carries two controls on one registered case's own measured value: a bar of
1 ns per call, below it, which must read FAIL, and a bar of 1 s per call, above it,
which must read PASS. The bed refuses when either verdict is not the declared one.
The second is what stops the first from being a mechanism that fails whatever it is
handed. Both decided correctly on all forty samples of this campaign; no sample
refused.

The bed also refuses when it measures for less than a declared multiple of its own
startup, which decision 0029 requires it to declare. That check fired on the first
run of the bed, which measured for 3.06 s against a startup of 7.79 s and a multiple
of eight. Both sides of it then moved: the batch count went from twelve to two
hundred, and the multiple from eight to four.

The multiple came down because startup is not stable and the floor has to be
clearable at its worst. That first run's 7.79 s was a cold depot; every one of the
forty samples here started in 3.18 to 3.63 s. A multiple of eight sets a floor of
26 s against a warm startup and 62 s against a cold one, and the bed measures for
about 45 s, so it would clear the floor warm and refuse cold on the same work. At
four the floor is 13 s warm and 31 s cold and the bed clears both. The multiple is
the bed's own declaration and nothing outside it reads the number; what it buys is
that startup is under a fifth of the job the bed asks the scheduler for.

## Why no bar is registered

- **The scatter is wide enough to swallow a small win.** A bar on a single bed run is
  refused below the full range of its case, which is 2.7 per cent at best and 15.2
  per cent at worst. A bar on the mean of twenty runs is refused below about one per
  cent. Every optimisation row on the board claims more than that, so each can be
  judged; a bar that would catch a small regression cannot be set from one run.
- **The bed does not watch the card's occupancy.** The host's load turned out not to
  matter, which is the opposite of what the load instrument found and is the reason
  this section is shorter than that one's. What replaces it is the neighbour on the
  card, which nothing here recorded. Until a sample carries how many shares were held
  while it ran, a bar narrow enough to catch a kernel regression may be firing on
  another job's share instead.

## References

- Decision 0029, reproducibility: benchmarks are failing tests, the A/A scatter comes
  before the bar, and the bed refuses below a declared multiple of its startup.
- Decision 0005, the mesh: a segment is a coarse cell's `4^k` descendants.
- Decision 0025, the oracle verdicts FAIL, REPORT and PASS.
- `notes/findings/2026-09-11-load-latency-instrument.md`, the A/A protocol followed
  here and the load sensitivity this bed does not share.
- `notes/findings/2026-09-11-area-fraction-in-one-read.md`, why the unit is a batch.
