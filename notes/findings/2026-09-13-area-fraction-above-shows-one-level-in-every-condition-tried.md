# area_fraction_above at level 7 shows one level in every condition tried, exclusive or shared, and the historical two-level split does not reproduce

Measured on 2026-09-13 on yggdrasil through `qrun`, Julia 1.12.7, CUDA.jl 6.3.1,
KernelAbstractions.jl 0.9.42, driver 610.57.04, one NVIDIA GeForce RTX 4090. Branch
`fiddlybits-6nh` at `280e183` (main merged in), which carries no change to
`bench/runbench.jl` (sha256 `fccd602f9693e7146fe9b6c9e4b297297d80cde119aec16ca2fca5b2b57c5ddc`,
unchanged since `notes/findings/2026-09-13-block-sums-in-shared-memory.md`) or to
`src/Reductions/quantiles.jl`. The row is `fiddlybits-6nh`.

## What is checkably the same, and what is checkably different, from the two campaigns that found the split

`notes/findings/2026-09-13-block-sums-in-shared-memory.md` (the branch-arm campaign,
84 or 107 us) and its own predecessor (the base-arm campaign against
`1c7b601ec401e5b4667b74c59d45443ff8f35ca7`, committed 2026-09-12 11:11:46, 116 or 141
us) both name Julia 1.12.7, CUDA.jl 6.3.1, KernelAbstractions.jl 0.9.42, Adapt.jl
4.7.0, driver 610.57.04: identical to every version this investigation ran under,
checked directly (`pkgversion` on each package) rather than assumed. `bench/
runbench.jl`'s sha256 is unchanged across all three. The branch-arm campaign's own
commit, `3a4d33ad9b46fb3c7d7521dd4c70ceb15b6c8005`, is committed 2026-09-13 04:36:42
and is an ancestor of every commit this investigation ran from, including `280e183`
(2026-09-13 08:14:40) and this finding's own head. What is different and checkable:
this investigation's measurements ran on 2026-09-13 from about 06:56 to 09:32, three
to five hours after the branch-arm campaign's commit, the same calendar day but not
the same session. What else was running on the shared host at either time is not
recorded by either campaign and is not recoverable now. No other difference in code,
package version or driver is found.

## The question

`reduction.area_fraction_above.7` settles per process into one of two discrete levels
about a fifth apart (116 or 141 us pre-`fiddlybits-2tg`, 84 or 107 us after) and holds
whichever it takes for all two hundred batches. No other of the bed's twelve cases
splits this way. What sets the level: device memory pool state, the stream or
context, case order, the host transfer path, or something else.

## Twenty runs under exclusive access (qrun -p gpu): one level

`bench/runbench.jl` itself, unmodified, run in twenty fresh processes through
`qrun -p gpu` (`shards = 4/4`, no share left for any other job). Minimum
microseconds per call for `reduction.area_fraction_above.7`:

| run | min us | run | min us | run | min us | run | min us |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 84.549 | 6 | 84.418 | 11 | 85.043 | 16 | 84.438 |
| 2 | 84.609 | 7 | 84.131 | 12 | 87.703 | 17 | 84.591 |
| 3 | 82.591 | 8 | 88.513 | 13 | 84.652 | 18 | 84.698 |
| 4 | 89.329 | 9 | 84.926 | 14 | 88.103 | 19 | 86.311 |
| 5 | 83.879 | 10 | 84.616 | 15 | 87.760 | 20 | 84.638 |

Mean 85.475 us, sd 1.811, full range 82.591 to 89.329 (7.88 per cent of the mean):
one level, not two, and every run read `shards_in_use = 4/4` at both of the bed's own
occupancy readings. This is on the real bed rather than a stand-in probe, from `main`
merged in. Read on its own this looks like the row's "split removed" branch; the
section below shows every other condition tried gives the same single level, so
exclusive access is not what is distinguishing it here.

## Nine neighbour profiles tried against the real bed or a matching probe; none reproduce the named levels

Under the repository's default `gpu-share` profile (`shards = 1/4`, `vram = 3G`, the
same profile the two campaigns that found the split used), the real bed (or, where
noted, a probe reproducing only this one case, `BATCHES = 60`) was run alongside each
of the following, each its own `qrun -p gpu-share` job:

| neighbour | what it does | this case's min us | effect on the mean while active |
| --- | --- | --- | --- |
| none (genuinely solo, checked via `qrun free`) | nothing | 84.68, 84.72 | none |
| idle client | opens a CUDA context, one tiny kernel, then sleeps | 81.81 | none |
| brief, early only | `pairwise_sum` at level 6 in a tight loop, 8 s, finished before this case starts | 87.42 | none (gone before the window) |
| light, sustained | `pairwise_sum` at level 6 in a tight loop, 90 s, spans the whole run | 88.18 | mean about 99 us, 1.2x |
| sized matmul, N=1024 | back-to-back single-precision matmuls, 60 s | 81.95 | mean about 114 us on the batches it touches, min unaffected |
| sized matmul, N=2048 | back-to-back single-precision matmuls, 40 s | 89.74 (one batch of sixty) | mean about 900 to 950 us on every other batch, 10x |
| saturating matmul, N=4096 | back-to-back single-precision matmuls, 70 s, active for 39 of 60 batches | 86.11 | mean 2578 us while active, 30x; drops to the floor within one batch of the neighbour stopping |
| a second full bed run, started moments after | the genuine bed, all twelve cases | 85.21 and 89.45 (one pair), 83.23 and 82.50 (another pair) | median lifts from about 90 to about 111 us; minimum unaffected |
| a second single-case probe, started moments after | the same case only, tight overlap | 85.34 and 81.72 | median lifts from about 90 to about 95 us; minimum unaffected |

Thirteen real-bed runs under `gpu-share` across these trials (the solo, idle, brief,
light-sustained, N=1024, saturating-neighbour, and both bed-pair runs) all read a
minimum between 81.95 and 89.83 us, mean 85.87, full range 9.18 per cent: the same
single level the twenty exclusive runs above show, not the named 84-or-107 split.
Two patterns hold across every neighbour tried:

- **A neighbour either does not move this case's minimum, or moves its mean by an
  order of magnitude while active.** Nothing tried sits at a stable, modest, roughly
  twenty per cent floor for a whole run. Below some threshold of the neighbour's own
  kernel size (level-6 `pairwise_sum`, a 1024-square matmul) the effect is not
  measurable at all; at or above another threshold (a 2048-square matmul, a
  saturating 4096-square one) the effect is 10x to 30x while the neighbour runs. There
  is no size found in between that gives a small, steady multiplier.
- **The minimum recovers as soon as one batch is clean.** Even with a 30x neighbour
  active for two thirds of a run, or two genuine bed copies contending for their
  whole overlap, at least one of the batches this case's statistic is a minimum over
  came out clean, and the reported number reads the floor. Reproducing the named
  historical levels as a *minimum over two hundred batches* would need a neighbour
  that inflates every one of them by about a fifth with no exception, which none of
  the profiles above did.

A merely idle second client (a live context, no kernel work, sitting the whole time)
moved nothing, which rules out a flat per-launch cost from MPS simply serving a
second client. Genuinely solo `gpu-share` (checked clean by `qrun free`, not by the
bed's own before-and-after reading alone) matches the exclusive floor, which rules
out the tighter `vram = 3G` cap on its own, without any neighbour, as the difference
`qrun -p gpu` makes. `/var/log/nvidia-mps/server.log` on this host, readable and
covering every client back to 2026-09-07, logs every client's priority as `0
(NORMAL)` with no line ever naming an active-thread-percentage or other per-client
resource limit: this MPS server is not configured to partition SM resources between
clients, ruling out a sticky per-client allocation decided at connection time as the
mechanism.

## What this leaves

The split did not reproduce in any condition tried: not exclusive (twenty for
twenty, one level), not genuinely solo on one share, not with any of nine neighbour
profiles on one share. Four shares is not shown here to be the remedy; the table
above and the thirteen-run summary before it are the same single level regardless of
how many shares this investigation's own runs held or who else was on the card.
Every bench or probe run whose timings are counted still takes every share
(`qrun -p gpu`), because that is the bed's own rule on its own grounds
(`fiddlybits-azi`, user direction 2026-09-13), not because this finding demonstrates
it fixes anything.

The mechanism the two historical campaigns' discrete, whole-run-persistent split
came from is not established by this investigation, and neither is why it did not
reproduce here. Nine neighbour profiles, spanning negligible to thirty-fold effects,
real single-case probes and real full bed copies alike, do not reproduce it as this
case's own minimum-over-many-batches statistic; nor does the tighter `vram` cap
alone, without contention; nor does exclusive access differ from any of the shared
conditions tried. What contention plainly does do here (10x to 30x while an
SM-saturating neighbour runs, recovering to the floor the moment it and its lingering
batch pass) is a different, larger and non-discrete effect from the named levels, not
a demonstration of them. What is checkably the same and different between now and the
two campaigns is in the section above; nothing beyond it is offered as an
explanation.

## References

- `notes/findings/2026-09-13-block-sums-in-shared-memory.md`, section "area_fraction_
  above at level 7 settles into one of two levels per process", which raised this row.
- `notes/findings/2026-09-12-reduction-bench-occupancy.md`, the occupancy licence and
  its own neighbour control.
- `notes/findings/2026-09-12-reduction-bench-scatter.md`, the bed's A/A scatter the
  ranges above are checked against.
- `fiddlybits-azi`, sampling occupancy per case rather than twice per run.
- `fiddlybits-ool`, comparing `area_fraction_above` before and after fusing its two
  kernels: run that comparison under `qrun -p gpu`, where this row found one level.
