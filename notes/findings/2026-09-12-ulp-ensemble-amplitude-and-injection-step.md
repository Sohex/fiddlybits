# One ulp of the certified precision is the amplitude at which the envelope is the propagator's operator one norm, and the injection step is what a nonlinear case adds

Measured on 2026-09-12 on yggdrasil through `qrun -p light` (no GPU share; every number
below is a single-threaded CPU measurement), Julia 1.12.7, Fiddlybits on branch
`fiddlybits-4hl` cut from `4c3f8ea2d7823bc97939a351c2b318a744b238c4`. Every number is
exhaustive or deterministic except where a member count is named; nothing here is a
draw. The row is `fiddlybits-4hl`.

This supersedes the section "The certification, and the smallest defect it catches" of
`notes/findings/2026-09-11-ulp-ensemble-member-count.md`, which recorded the
certification's comparison level as

    bound(s) = E(s) * initial + sum_{j=1}^{s} E(s - j) * roundoff,   E(0) = 1,

with `E` measured by perturbing the initial state by one `Float64` ulp. That formula
carries two claims this record measures and finds false on the very case it was measured
on: that `E` is the operator one norm of the case's propagator, and that the gain an
error injected at step `j` meets is the gain measured from step zero at the same lag.
The two readings of decision 0029's phrase settled in that finding, the member count,
the miss rate and the amplification distribution it is sized against are not superseded;
what is superseded is the amplitude, the injection step and the word `bound`.

## What has a right answer here

A linear step has a propagator, and the propagator has an operator one norm. For a
linear map the largest one-norm response to a perturbation of a single cell, per unit of
perturbation, is exactly that norm, because the one-norm operator norm is the largest
column sum and a single-cell perturbation is a column. The norm also does not depend on
the step the perturbation is injected at, because the map is the same map at every step.

The stand-in case (`test/certify/fixtures.jl`, a fixed gather over a `4^k` layout
followed by a fixed rotation) is linear and stationary. So its envelope has a right
answer that can be read without an envelope, by perturbing at an amplitude far enough
above the rounding of the state that the response carries no quantisation of its own.
`CertifyFixtures.operator_one_norms` is that reading, at a relative `1e-6`.

## The stand-in case at the two amplitudes

The `4^5` stand-in, 1024 cells, two fields, 2048 sites, 20 steps. The exhaustive
envelope perturbing every site, against the norms above.

| step | operator one norm | envelope at one Float32 ulp | envelope at one Float64 ulp |
|---|---|---|---|
| 1 | 1.53707 | 1.53707 | 3.0 |
| 5 | 1.73350 | 1.73350 | 7.53125 |
| 10 | 1.76429 | 1.76429 | 11.0 |
| 15 | 1.85663 | 1.85663 | 13.75 |
| 20 | 1.95275 | 1.95275 | 14.375 |

At one `Float32` ulp the exhaustive envelope reproduces the norm at every one of the 20
steps. At one `Float64` ulp it overstates it by 1.95 at step 1 and by 7.36 at step 20,
with a worst of 8.69 at step 17.

The reason is visible in the sizes. One `Float64` ulp of the stand-in's field scale is a
relative `1.6e-16`. One step spreads that over the case, so each cell's share of the
response is a fraction of one ulp of the value it is added to, and each cell either
rounds away or is carried to a full ulp. What the member then measures is how many cells
the rounding carried, which is a property of the floating point grid and not of the
case. One `Float32` ulp of the same scale is a relative `8.5e-8`, nine orders larger,
and the response clears the granularity of the `Float64` state it is read against by six
orders.

The declared draw of 766 members over the same 20 steps, injected at step zero, is the
draw's own signature; a member set that moved would not reproduce it, and
`certify.sampled_draw_is_unchanged` asserts it bit for bit:

    1.5370733437594026, 1.49623842316214,   1.5326636934187263, 1.5908572526823264,
    1.6080869103316218, 1.6191722891526297, 1.6264993406366557, 1.6330749358749017,
    1.651457596803084,  1.6652258010581136, 1.6752443460281938, 1.6837054369971156,
    1.6935136308893561, 1.7129886508919299, 1.7329219253733754, 1.7526412960141897,
    1.7716029654257,    1.7909559129038826, 1.813414293807,     1.8346782953012735

Nine orders is also the distance between the amplitude the envelope was measured at and
the amplitude it was applied to. The `initial` and `roundoff` terms the envelope
multiplies are both `Float32`-scale, which is where the mismatch came from.

## The injection step

The same case, the same 20 steps, now perturbing the reference state at every step an
error could be injected at rather than at step zero alone, and comparing each gain with
the one measured from step zero at the same lag.

| case | worst ratio, gain at step j to gain from step 0 at the same lag |
|---|---|
| stand-in, one Float32 ulp | 1.0 at every one of the 20 steps |
| stand-in, one Float64 ulp | up to 2.67 |

For a linear stationary step the ratio must be one, and at the right amplitude it is one
exactly. At one `Float64` ulp it is not, so the superposition the earlier formula is
built on failed even on a linear stationary case, from quantisation alone and before any
question of nonlinearity.

On a nonlinear case the ratio is the whole content. `CertifyFixtures.growing_case` is
one cell stepping `x -> x * x + 1` from 1.5, whose local amplification runs 3, 6.5,
23.125, 269.4 over its four steps:

| gain | injected at step 0 | injected at step 3 |
|---|---|---|
| read at step 4 | 121475 | 269.4 |

An error injected at step 3 meets an amplification of 269.4 on its way to step 4. The
gain measured from step zero over the same one-step lag is 3.0, which is the number the
earlier formula would have carried, short by a factor of 90.

## What the certification does with it

The same case, with a candidate whose `Float32` path adds `1e-3` to the cell after every
step and whose `Float64` path does not, and a declared roundoff of `2.4261e-3` measured
as the largest divergence one step of that candidate injects. The initial state is exact
at `Float32`, so `initial` is zero and the verdict rests on the propagation of the
declaration alone.

| construction | admitted at step 4 | observed at step 4 | worst observed over admitted | verdict |
|---|---|---|---|---|
| gains at the step the error is injected | 114.0 | 47.04 | 0.413 | PASS |
| gains from the initial state at the same lag | 1.151 | 47.04 | 40.87 | FAIL |

The candidate injects no more than it declares, and the construction the earlier finding
recorded refuses it by a factor of 41. This is the positive control in
`test/certify/certification.jl`, and the ratio is what a nonlinear case costs a
certification that reads its gains from the initial state.

## The sampling shortfall at the right amplitude

The declared draw is 766 members of the stand-in's 2048 sites. The exhaustive envelope
divided by the drawn one, worst over the 20 steps:

| amplitude | worst shortfall |
|---|---|
| one Float32 ulp | 1.087 |
| one Float64 ulp | 1.482 |

The earlier finding recorded 1.32 for this draw, at one `Float64` ulp and at step 20
alone. The amplitude that recovers the norm also flattens the gain landscape the draw
samples, so the same 766 members are short by 8.7 per cent rather than by a third. The
member count and the bracket it sits in are unchanged by this: they are fixed by a
requirement stated over sub-populations of a case that does not exist yet, not by the
shortfall on this one.

## The cost

Perturbing at every injection step runs one member from each step to the last, so the
work is the step count's triangular number rather than the step count: `(steps + 1) / 2`
times as much, 10.5 at 20 steps. Measured on the stand-in's 766 members over 20 steps,
single-threaded:

| measurement | time |
|---|---|
| injected at step 0 alone | 0.264 s |
| injected at every step | 1.916 s |

7.25 rather than 10.5, because the reference trajectory and the allocation are paid
once.

What that buys at the gate is one testset. `certify.case_certification_runs_every_arm`
runs both arms of the real-mesh case at level 5, 10242 vertices, two fields, 20 steps,
twice, and takes 1m21.6s of the certify suite's 1m35s. The whole suite is 4866
assertions, in 8m51.5s and 9m15.1s on two runs through `qrun` with this repository's
defaults; the second shared the host with a 16-CPU job and the first did not, so the
suite figure is a price to an order and not a bench number. The mesh case's
step count and level are what the cost is in, not the member count, and neither was
changed here: a shorter mesh case would buy the minute back and check a shorter
trajectory, which is a coverage question this record does not settle.

What the number raised is `fiddlybits-52v.1.12`: the gate runs every suite for every
commit, so this minute is paid by a commit that touches no kernel. Whether the gate can
be narrowed to what a branch changed, and what would make such a narrowing safe to
trust, is that row's to decide.

## What the words can say

With the amplitude and the injection step fixed, the level `Backends.admitted` builds is
an upper bound on the divergence when three things hold together: the step is linear and
stationary, so the response to a sum of errors is the sum of the responses and the
superposition is the triangle inequality; the ensemble is exhaustive over the case's
sites, so each gain is the largest over the case rather than over a draw; and the
perturbation is at the certified precision, so each gain is the operator one norm rather
than a reading of the rounding. The first table establishes the third, the ratio table
establishes that the first is what the second column of it tests, and the shortfall table
says what the second costs at the declared draw.

There is a fourth thing the first condition carries that the other two do not name. The
gains are measured on the reference trajectory, and the candidate's own state at step `j`
has drifted by whatever it injected before then. For a linear stationary step both states
carry the same gain and the distinction is empty, which is why it rides with the first
condition rather than standing beside it. For any other step it is a second reason that
same condition is the one that fails, and it cannot be measured away without running the
candidate, which is the thing the certification is there to judge.

Drop any one and the level is a comparison the case measured for itself. That is what
decision 0025's `PASS` already means, inside a bar and never evidence of correctness, so
the verdict vocabulary does not change; the word `bound` does, and
`src/Backends/certify.jl` no longer uses it for this quantity.

## What was run

Three of the four claims are assertions in the suite rather than numbers in this
record, so they are checked at every commit rather than read here:
`certify.linear_case_envelope_is_the_operator_one_norm` and
`certify.nonlinear_case_gains_grow_along_the_trajectory` in
`test/certify/envelope.jl`, and
`certify.later_injection_exceeds_the_initial_state_envelope` in
`test/certify/certification.jl`. Each carries its own positive control: the first the
same case at one `Float64` ulp, which fails both halves of the identity, and the third
the same candidate against gains read from the initial state, which refuses it.

The two tables the suite does not carry are read from `Backends` directly. The
amplitude table is `Backends.measure_envelope` over
`Backends.usable_sites(case, precision)` in full, at `Float32` and at `Float64`,
against `CertifyFixtures.operator_one_norms(case, steps, 1e-6)`. The shortfall is the
same pair of exhaustive readings divided by `Backends.envelope`'s drawn one on the same
case. The cost pair is `Backends.envelope` against one injection step of the same
members, both after a warm call, single-threaded and with nothing else on the host.
