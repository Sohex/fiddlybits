# The bench bed's numbers are comparable only while it is the card's sole share-holder, and the scheduler's count is the only reading that says so

Measured on 2026-09-12 on yggdrasil through `qrun` with this repository's defaults
(profile `gpu-share`, one share of an NVIDIA GeForce RTX 4090, 8 CPUs, 16G), Julia
1.12.7, CUDA.jl 6.3.1, KernelAbstractions.jl 0.9.42, on branch `fiddlybits-pgf` at
`e398c738739ce971374b71523866189e16c2a074`, with `bench/runbench.jl` at sha256
`b23d62aed0d75fc730e237d60059cb8c07fad68d30508cf8a847f59216ab9e10`. The committed
file differs from that one in the wording of a single docstring and in nothing that
runs. The row is `fiddlybits-pgf`, raised by
`notes/findings/2026-09-12-reduction-bench-scatter.md`.

That finding recorded the host's load beside every number and showed the load does
not move this bed. It said the neighbour that would matter is another job holding a
share of the same card, and that nothing recorded whether one did. This is that
reading, what it is worth, and what it licenses.

## What is recorded, and from where

Two sources, before the first case and after the last.

- **The scheduler.** `qrun free` reports how many of the node's four shares are
  allocated. Read from inside the bed's own allocation it counts that allocation, so
  a run that is the only holder reads one.
- **The card.** `nvidia-smi` reports utilisation, memory in use, and the compute
  processes it carries, from which the bed derives how many are not this process.

The record carries both readings and one derived field, `sole_holder_throughout`,
true when the scheduler counted exactly one share at both ends of the run.

Only the share count is a condition. The other readings are facts about the host
rather than about the run:

- **Compute processes are not zero on a quiet card.** With no job holding any share,
  the card carried three compute processes using 2907 MiB. Across all forty samples
  below, the count of processes other than the bed's own was three every time. A rule
  written on that count would refuse every run on this host.
- **Utilisation is an instant, not an average.** The after-reading ranged from 6 to
  100 per cent over forty samples of the same work on an otherwise idle card, because
  it is sampled once at the end of the run. It cannot carry a condition.

## The A/A pair at a declared occupancy

The pair of the earlier finding, repeated with the occupancy recorded: two arms
differing in nothing, interleaved sample by sample, one fresh process per sample,
twenty samples each arm. Every one of the forty reported `sole_holder_throughout`,
and both arms saw a share count of exactly one at both ends. The occupancy was
therefore declared and held, rather than assumed.

Microseconds per call, the minimum statistic:

| case | A mean | B mean | A less B | as pc of A | pooled sd over mean | full range |
| --- | --- | --- | --- | --- | --- | --- |
| pairwise_sum, level 5 | 35.739 | 36.088 | -0.350 | -0.98 | 2.83 pc | 7.1 pc |
| pairwise_sum, level 7 | 49.388 | 49.898 | -0.510 | -1.03 | 2.99 pc | 8.1 pc |
| area_fraction_above, level 5 | 73.107 | 73.594 | -0.487 | -0.67 | 2.86 pc | 7.0 pc |
| area_fraction_above, level 7 | 123.246 | 122.672 | +0.575 | +0.47 | 4.07 pc | 20.9 pc |
| segmented_sum, depth 2 | 4.340 | 4.325 | +0.015 | +0.34 | 0.66 pc | 2.6 pc |
| segmented_sum, depth 3 | 7.825 | 7.842 | -0.017 | -0.21 | 0.75 pc | 3.3 pc |
| segmented_weighted_sum, depth 2 | 5.339 | 5.340 | -0.000 | -0.00 | 0.28 pc | 1.1 pc |
| segmented_weighted_sum, depth 3 | 16.335 | 16.423 | -0.088 | -0.54 | 2.47 pc | 12.6 pc |
| segmented_mean, depth 2 | 54.727 | 54.631 | +0.096 | +0.18 | 3.20 pc | 11.1 pc |
| segmented_mean, depth 3 | 63.996 | 64.297 | -0.301 | -0.47 | 2.85 pc | 9.0 pc |
| segmented_quantile, depth 2 | 28.166 | 28.192 | -0.027 | -0.10 | 1.69 pc | 4.3 pc |
| segmented_quantile, depth 3 | 28.910 | 28.920 | -0.011 | -0.04 | 1.67 pc | 4.2 pc |

The scatter reproduces the earlier campaign's. The arms agree in the mean of twenty
to about one per cent on every case, a single sample carries between 0.28 and 4.1 per
cent, and the widest full range is 20.9 per cent on `area_fraction_above` at level 7.

Host load ran from 1.15 to 34.97 across this campaign, a thirty-fold range and wider
than the thirteen-fold range of the earlier one, and the arms still agree to one per
cent. The earlier conclusion about the host's load survives a harder test than it was
drawn from.

## The neighbour

The positive control: one sample taken while a second job held a share of the card
and kept its SMs busy with back-to-back single-precision matrix products. Its
recorded occupancy differs from every quiet sample's. Two shares in use at the first
reading against one, and `sole_holder_throughout` false. The reading separates the
two conditions, which is what the control had to show.

That sample also ran far slower: 870 s measuring against 44 to 53 s quiet. Two cases
came out near twenty times their quiet value, `segmented_weighted_sum` at depth two
at 105 against 5.3 microseconds and `segmented_sum` at depth three at 150 against
7.8, while others barely moved.

No per-case multiplier is quoted from it, for two reasons.

- **The sample straddles.** The neighbour's walltime ended partway through the bed's
  case list. The statistic is a minimum over two hundred batches, so a case with even
  a few batches after the neighbour stopped reports a near-quiet minimum, and the
  uneven pattern across cases is evidence about when the neighbour ended rather than
  about the kernels.
- **The multiplier would not be a property of the kernels anyway.** Two contexts
  sharing the card are timesliced by MPS, so the ratio measures how the GPU scheduler
  divides the card between them. Quoting it per case would invite reading it as
  something `segmented_sum` does.

What the control establishes is the direction and the order: a neighbour holding a
share moves this bed by more than tenfold on some cases, against a quiet scatter of
a few per cent. Nothing finer is needed, and a finer number would be misleading.

## What the reading licenses

A number from this bed is comparable with another number from this bed when both
recorded `sole_holder_throughout`. That is the whole of it, and it is enough, because
the two conditions are separated by more than two orders of magnitude: a few per cent
of scatter against a shift of more than tenfold. There is no intermediate regime here
to calibrate for, and no correction to apply to a contended sample. A contended sample
is discarded.

This answers for the bed the question `fiddlybits-52v.1.8` carries for the load
instrument: the recorded occupancy becomes a condition on the measurement rather than
a note under it. The bed does not yet refuse a contended sample, because refusing is
a property of judging and nothing here judges: every case carries no bar. The
condition belongs in the same change that registers the first bar, which is
`fiddlybits-e81`.

## References

- Decision 0029, reproducibility: benchmarks are failing tests, keyed by hardware.
- Decision 0043, where the gate runs: the scheduler and the card this bed reads.
- `notes/findings/2026-09-12-reduction-bench-scatter.md`, the campaign this repeats
  and the host-load result it extends.
- `notes/findings/2026-09-11-load-latency-instrument.md`, which raised the question of
  what a recorded condition licenses.
