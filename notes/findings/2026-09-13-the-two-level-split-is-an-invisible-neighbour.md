# area_fraction_above at level 7 splits because a neighbour shares the card, invisible to the bed's own before-and-after occupancy reading

Measured on 2026-09-13 on yggdrasil through `qrun`, Julia 1.12.7, CUDA.jl 6.3.1,
KernelAbstractions.jl 0.9.42, Adapt.jl 4.7.0, driver 610.57.04, one NVIDIA GeForce
RTX 4090. Branch `fiddlybits-6nh` at `e8cdc1a96388e8552ab86b7b5181a4d9770b231c`, which
carries no change to `bench/runbench.jl` (sha256
`fccd602f9693e7146fe9b6c9e4b297297d80cde119aec16ca2fca5b2b57c5ddc`, the same file
`notes/findings/2026-09-13-block-sums-in-shared-memory.md` measured) or to
`src/Reductions/quantiles.jl`. The row is `fiddlybits-6nh`, raised by
`notes/findings/2026-09-13-block-sums-in-shared-memory.md`, filed by `fiddlybits-2tg`.

## The question

`reduction.area_fraction_above.7` settles per process into one of two levels a fifth
apart and holds it for all two hundred batches of that case, on both the pre- and
post-`fiddlybits-2tg` code. No other of the bed's twelve cases splits this way. The
question was what sets the level at process start: device memory pool state from the
`vcat` of the two block-sum arrays, the stream or context, the order of earlier cases,
the host transfer path, or something else.

## The probe

A standalone script (kept outside the tree, per this row's file boundary) reproduces
the bed's own `area_fraction_above.7` case exactly: the same fixtures
(`test/reductions/fixtures.jl`), the same `WORKGROUP`, `THRESHOLD` and `CALLS` as
`bench/runbench.jl`, `WARMUP_BATCHES = 5` and `BATCHES = 60` (more than the bed's two
warm-up batches and fewer than its two hundred, chosen so a fresh process settles
before it is judged and the run still finishes in seconds). Two instruments ride
alongside the timing:

- **Shard occupancy**, read from `qrun free` before the run and after every batch, not
  only at the two ends `bench/runbench.jl` reads today (the gap `fiddlybits-azi` is
  closing in that file; this probe does not touch that code, per this row's
  concurrency note).
- **A counter on CUDA.jl's own completion path.** `CUDACore.synchronize(::CuStream)`
  (`CUDA/EwwXC/CUDACore/lib/cudadrv/synchronization.jl`) either returns as soon as a
  bounded busy/yield spin (`spinning_synchronization`, up to 256 tries) sees the
  stream done, or falls through to `CUDACore.nonblocking_synchronize`, a round trip
  through one of four sticky per-task worker threads. The probe redefines that one
  function, verbatim plus two counters, so every call `Backends.on` makes through
  `Backends.complete!` is counted, and the fraction that fell to the worker-thread
  path is read back per batch.

## Twenty fresh processes with the whole card held show one level, not two

Each of twenty fresh processes was launched through `qrun -p gpu` (`shards = 4/4`,
decision to use this profile per user direction 2026-09-13: any run whose timings are
counted takes every share, so no neighbour can hold any part of the card while it
runs). Every one of the twenty read `shards_before = 4/4` and `shards_after = 4/4`.
Minimum microseconds per call over the sixty measured batches:

| sample | min us | sample | min us | sample | min us | sample | min us |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 85.941 | 6 | 86.399 | 11 | 85.669 | 16 | 85.586 |
| 2 | 84.496 | 7 | 86.389 | 12 | 85.078 | 17 | 87.698 |
| 3 | 85.414 | 8 | 86.182 | 13 | 84.760 | 18 | 85.808 |
| 4 | 85.130 | 9 | 86.182 | 14 | 85.151 | 19 | 85.897 |
| 5 | 85.368 | 10 | 85.859 | 15 | 85.151 | 20 | 86.320 |

Mean of the twenty minimums 85.777 us, sd 0.712 us, full range 84.496 to 87.698, 3.73
per cent of the mean: inside the bed's own A/A scatter
(`notes/findings/2026-09-12-reduction-bench-scatter.md`, `notes/findings/2026-09-12-
reduction-bench-occupancy.md`), not the 20.9 to 27 per cent gap the two named levels
show under the repository's default `gpu-share` profile. Every synchronization
counter agreed: the fraction of completions that fell to the worker-thread path
stayed under half a per cent in every one of the twenty runs (0.0009 to 0.0048), with
no batch-to-batch pattern tracking the small scatter that remains. Three earlier
processes measured with only twenty batches (not sixty) landed at 88.8, 95.5 and 96.7
us, all closer to this same floor than to either named level once enough batches ran
to reach it; they are not counted among the twenty above; they are why sixty batches
were used for the rest.

This is the row's "split removed" branch: twenty fresh processes, the whole card
held, one level.

## What the level actually was: an undetected neighbour, not a per-process state

The named levels come from measuring under `qrun`'s repository default, `gpu-share`
(one of four shares). `bench/runbench.jl` reads shard occupancy once before its first
case and once after its last; a job that takes a share after the first reading and
releases it before the last leaves both endpoints reading one share, exactly the gap
`fiddlybits-azi`'s row names. A neighbour whose own activity happens to span the
whole of `area_fraction_above.7`'s few-second window inflates every one of that
case's batches for as long as it runs; the case's statistic is the minimum over its
batches, so a neighbour covering only part of the window still usually leaves at
least one clean batch and the minimum still reads the floor. Only a neighbour that
covers the entire window moves the reported number itself, which is why the split
holds for whichever case it lands on and not for a few batches inside one.

### The positive control: a synthetic neighbour reproduces it and releases it

One process ran the same probe under the repository's own `gpu-share` profile (one
share) while a second process, launched moments earlier under the same profile
(`neighbour_load.jl`, back-to-back single-precision 4096-by-4096 matrix products
through `CUDA.CUBLAS.gemm!`, the same synthetic load
`notes/findings/2026-09-12-reduction-bench-occupancy.md`'s own neighbour control
used) held the other share for a fixed seventy seconds. Both `shards_before` and
`shards_after` for the probe read `2/4`: the occupancy reading correctly told
contended from clean at both its own endpoints here, because the neighbour outlived
the whole probe's warm-up and the first thirty-nine of its sixty batches.

Microseconds per call, mean over the batches named:

| segment | batches | mean us per call | vs the clean floor |
| --- | --- | --- | --- |
| neighbour active | 1-39 | 2578.2 | 30.1x |
| neighbour just ended (partial batch) | 40 | 1716.9 | 20.0x |
| neighbour gone | 41-60 | 110.4 (86.1 to 413.8) | 1.0x to 4.8x |

The fraction of completions falling to the worker-thread synchronization path moved
with it: 0.305 to 0.331 while the neighbour ran, under 0.02 in every batch after it
stopped. `min_us` over the whole sixty-batch run was 86.111, matching the clean
floor above almost exactly, because batch 44 happened to be clean; had the neighbour
instead covered all sixty batches, as one covering the whole of a shorter case's
window would, the reported minimum would have read in the thousands, not near the
floor.

The forced-path arm confirms the counter itself: `CUDA.synchronize(stream; spin =
false)` on the same kernels read `slow = 200/200` every time it was tried, in every
one of the twenty-three exclusive runs and the contended run, and `spin = true`
immediately after those same kernels read `slow` at 0 to 12 out of 200, with
`spin = true`'s own median
completion (about 40 to 41 us) close to `spin = false`'s (about 42 to 45 us) because
by the time either measured, the kernels were long finished either way; the gap the
counter is built to catch is not in that forced pair, it is in what fraction of the
bed's own, un-forced completions take the slow branch, which is the number the table
above reports.

The GPU's own SM clock settled at 2850 MHz in every one of the twenty exclusive runs,
after one to ten batches of ramp from idle (sometimes through an intermediate 2625
MHz step) and stayed there for the rest of each run regardless of whether that run's
minimum came out near 84.5 or 87.7 us; it moved only to 2400 to 2520 MHz during the
contended run's first thirty-nine batches (a fourteen per cent drop, not the
thirty-fold slowdown MPS time-slicing accounts for): the clock tracks having a rival
context on the card as a minor secondary effect, not the mechanism, and does not
track the small scatter among the twenty exclusive runs at all.
CPU frequency (sampled from every visible core's `scaling_cur_freq`) stayed at 5.0 to
5.2 GHz throughout every run, exclusive or contended alike, and is not implicated.

## What this answers

The cause is a neighbour on another share, active for the whole of this case's own
window, invisible to `bench/runbench.jl`'s two-reading occupancy check exactly as
`fiddlybits-azi`'s row describes; nothing about `area_fraction_above`'s own code,
the `vcat`, the memory pool, or the order of earlier cases sets the level, and
`src/Reductions/quantiles.jl` carries no change here. `area_fraction_above.7` is the
case this shows on because it is one of the longer-running unsegmented cases (two
block-sum kernels and the join, not one), so a neighbour of the kind agents on this
machine routinely launch (a few tens of seconds of `gpu-share` work) is more likely
to span its whole few-second window than a shorter case's; the two named levels'
modest twenty to twenty-seven per cent gap is consistent with a neighbour lighter
than this control's saturating matrix product, not with a different mechanism.

The split is removed, not recorded: a timing run that takes every share, as user
direction 2026-09-13 now requires for any bench or probe whose numbers are counted,
has no neighbour to be invisible, and the twenty-sample table above is that run
showing one level. `bench/runbench.jl` and `src/Reductions/quantiles.jl` are
unchanged; `fiddlybits-azi`'s per-case occupancy reading remains useful defense in
depth for a run made under the shared default profile, but does not need to carry
this row's fix.

## References

- `notes/findings/2026-09-13-block-sums-in-shared-memory.md`, section "area_fraction_
  above at level 7 settles into one of two levels per process", which raised this row.
- `notes/findings/2026-09-12-reduction-bench-occupancy.md`, the occupancy licence and
  its own neighbour control, reused here.
- `notes/findings/2026-09-12-reduction-bench-scatter.md`, the bed's A/A scatter this
  finding's twenty-sample range is checked against.
- `fiddlybits-azi`, sampling occupancy per case rather than twice per run.
- `fiddlybits-ool`, comparing `area_fraction_above` before and after fusing its two
  kernels: run that comparison under `qrun -p gpu` and there is one level to compare,
  not two.
- Decision 0043, where the gate runs: the scheduler and the card this bed reads.
