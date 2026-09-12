# The gate falls from 507 seconds to 89: two thirds of the longest suite was heap pressure from the suites before it, and the rest is one parallel loop

Measured on 2026-09-12 on yggdrasil through `qrun` with this repository's defaults
(profile `gpu-share`, one share of an NVIDIA GeForce RTX 4090, 8 CPUs, 16G), Julia
1.12.7, on branch `fiddlybits-52v.1.12` cut from `d480373`. The row is
`fiddlybits-52v.1.12`, raised by
`notes/findings/2026-09-12-a-pre-push-gate-longer-than-the-idle-timeout.md`, which
measured the target: a pre-push gate is viable only inside the six minutes GitHub
leaves an idle session open.

## Where the time was

Every suite, in one process, in order, which is what `Pkg.test()` does:

| suite | seconds | share |
|---|---|---|
| certify | 360.6 | 71.1 % |
| backends | 65.5 | 12.9 % |
| reductions | 32.6 | 6.4 % |
| gate | 18.0 | 3.5 % |
| fields | 7.9 | 1.6 % |
| mesh | 7.4 | 1.4 % |
| events | 4.7 | 0.9 % |
| orbit | 3.0 | 0.6 % |
| time | 2.1 | 0.4 % |
| lint | 1.9 | 0.4 % |
| imports | 1.7 | 0.3 % |
| dimensions | 1.3 | 0.3 % |
| verdicts | 0.5 | 0.1 % |
| build | 0.3 | 0.1 % |
| total | 507.4 | |

The whole run reported 8m27.4s for 4866 assertions; the difference from the total
above is package load and precompilation.

One suite is 71 per cent of the run, so distributing suites over cores cannot beat 360
seconds however many cores it is given. That is the first thing this table settled, and
it is the reason the answer is not only "run them at once".

## Two thirds of that suite was not work

The same suites, each in its own process, eight at a time:

| suite | in one process | own process | own process, 8 threads |
|---|---|---|---|
| certify | 360.6 | 151.0 | 89.1 |
| backends | 65.5 | 61.9 | 74.7 |
| reductions | 32.6 | 49.3 | 60.6 |
| gate | 18.0 | 30.1 | 33.6 |
| verdicts | 0.5 | 6.4 | 6.6 |
| build | 0.3 | 0.8 | 0.8 |
| sum of suites | 507.4 | 393.8 | 365.9 |
| **wall** | **507.4** | **151.1** | **89.2** |

`certify` alone falls from 360.6 to 151.0 by being moved into a process of its own,
before any parallelism is applied to it. Nothing about the suite changed. What changed
is the live set the collector walks: in the serial run thirteen suites have already
built their fixtures and hold them at module scope, including an icosahedral hierarchy
at level 5, and `certify` allocates a copy of a 10242-cell two-field state per member
per injection step against that heap. In its own process it starts from an empty one.

The small suites get slower, from 0.5 to 6.4 seconds in the worst case, because each now
pays its own process start and package load, measured at 4.7 seconds. The sum of suites
still falls, because what the isolation buys on `certify` is larger than what it costs
across the other thirteen.

## The rest is one parallel loop

`Backends.measure_envelope` runs one member per site per injection step, and the
injection steps are independent: task `j` writes row `j + 1` of the gain matrix and no
other, so there is no accumulator shared between tasks and no order in which they could
combine. With that loop threaded, `certify` falls from 151.0 to 89.1 and the wall with
it.

The result is the same result. On the stand-in case the SHA-256 of the whole gain matrix
is `15ee064401eca1be9b8c3eb7e13c458a907a3a4c33716b600f2791e14a579fae` at one thread and
at eight, and the envelope is measured at 1.78 s and 0.66 s respectively.
`certify.envelope_does_not_depend_on_its_partition` asserts the equality at every commit
by rebuilding the matrix one injection step at a time in the calling task, with a
positive control that moves one entry by an ulp.

Threading costs the neighbours something, and the table shows it: `backends` goes from
61.9 to 74.7 and `reductions` from 49.3 to 60.6, because `certify` is now using cores
they were using. The trade is worth taking at a wall of 89.2 against 151.1, and it is
bounded: the driver gives every worker the whole thread budget, and `certify` is the only
suite that spends it.

## What the gate costs now

| | wall | against the six-minute window |
|---|---|---|
| before | 507.4 s | 1.41 times over |
| after | 89.2 s | 4.0 times under |
| after, end to end through `tools/gate/gate.sh` | 92.1 s | 3.9 times under |

The end-to-end figure is what a `pre-push` hook actually pays: the scheduler's queueing
and `srun` startup on top of the driver's own 88.9 s on that run.

The profile has also flattened, which is what makes the number durable rather than
lucky: the longest suite was 71 per cent of the run and is now 24 per cent of the sum,
with `backends` and `reductions` within a factor of 1.5 of it. A gate whose cost is one
suite degrades the moment that suite grows; a gate whose cost is three roughly equal
suites degrades slowly.

## The serial door keeps the serial cost

`Pkg.test()` starts its test process with one thread and takes no argument that would
change that, so the door a person reaches for gets the process isolation of neither and
the threaded envelope of neither. Run after this change it reports 4903 assertions in
9m01.9s, with `certify` at 399.2 s: the same shape as before, because nothing it does is
different. That is the right outcome rather than a gap. The door exists to read one
failure in one place, and a run whose suites interleave over eight cores is a worse place
to read one. What it costs is that the serial door is the slow one on purpose, and
`tools/gate/gate.sh` is what the executor loop and the `pre-push` hook call.

## What is not claimed

The six-minute window was measured on one day against one remote and is not a contract.
The margin, not the threshold, is what makes this safe, and the margin is 4.0.

The seven suites that reach the card all ran concurrently, eight processes at a time,
with no video memory refusal at the profile's default cap. No classification of which
suites take the card was needed, and none was built: a hand-maintained map of that would
go stale silently, and the measurement says it buys nothing.
