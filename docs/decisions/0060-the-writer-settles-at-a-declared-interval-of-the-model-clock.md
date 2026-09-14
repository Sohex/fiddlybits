+++
id = "0060"
title = "The store's writer settles during a run at the end of the first step reaching each multiple of a declared interval of simulated seconds, and always at the drain; a late refusal is journalled under that step's header"
status = "accepted"
date = 2026-09-13
+++

## Decision

The store's writer (`docs/plans/fiddlybits-52v.6-provenance.md`, section The writer)
lands a run's writes through stages, so a refusal found in the data, at the handoff, at
the rename or on the filesystem is found after `submit!` has returned, and `settle!` is
where the run meets it. This record says where a run calls `settle!`.

**The writer settles at a declared cadence.** The profile declares `settle_interval`, a
duration in SI seconds of the model's one clock (decision 0008), beside `write_ceiling`
and `store_writers`: a `Disposition{FT,TIME}` above zero with a disposition from
`Systems.DECLARED`, required, with no default and no `Absent`. The settle instants are
its multiples counted from the run epoch, the instant `k * settle_interval` seconds
after it for each integer `k`.

**The settle point is a step boundary.** At the end of every step the run's driver hands
the run door that step's `Time.Interval` and its journal header. The door settles when
the step's end is at or after the next settle instant, and then takes as the next one
the first instant after that end, so a step spanning several instants settles once. The
door's decision reads the interval and the cadence and nothing of the writer's state.
Several steps ending at one instant are ended in the driver's evaluation order, and the
first of them to reach the instant settles.

**The drain always settles.** `drain!` settles before it stops the stages, whether the
run ended normally or was unwound by a refusal, as the run door's close already
provides (`fiddlybits-52v.6.27`). A refusal a settle has already raised is raised once:
the drain after it removes the discarded staging directories and raises nothing further
for that write.

**A late refusal is journalled under the header of the step that settles.** `settle!`
runs inside the run's `journalled` wrapper with that step's sequence number, instant and
tier, so the `refusal` event names the earliest-submitted refused write, its key and
quantity and the count of later submissions discarded (decision 0042's `Refusal`
payload), at the step boundary where the run stopped. The refusal is then rethrown, the
run unwinds, and the close drains.

**Between a refused write and the next settle the run computes, and nothing it submits
is stored.** The steps after the refused write run as they would have: their
components step, their inline admission refusals are raised where they occur, and their
events are journalled. Every submission after the refused one is discarded, so the
store holds exactly the submissions before the earliest refused write, which is the set
the writer's commit order fixes under every cadence. `submit!` does not refuse on
account of a late refusal. The host copy and its charge are taken for every submission
as for any other, so the device-move tally the run record carries (decision 0046) is
the same whenever the stages found the failure; the encode and disk stages may drop an
item they already know to be discarded, since neither records anything a run keeps.

**Arrival order does not choose where a run stops.** The step at which a run meets a
late refusal is a function of the step schedule and the declared cadence, both part of
the run identity (decisions 0014 and 0029), and never of the moment a stage found the
failure. `settle!` waits on every submission made so far and names the earliest
submitted refused write among them, so which failure it reports is fixed by submission
order too. Two runs of one identity whose stages finish in different orders stop at the
same step, journal the same refusal event and hold the same store.

**The cadence reaches no artifact.** The stored set, the keys and the manifests are
fixed by submission order and admission. `settle_interval` decides how much a run
computes after a refused write and the header under which the refusal is journalled; no
component declares it, and it is in no content key.

## Alternatives considered

**Settle at the end of every step.** A late refusal is raised at the first step
boundary after its write was submitted, so the run computes the least after it. Lost on
decision 0038: the driver's task then waits at every step for the stages to land that
step's writes, which makes the step the unit of waiting, the per-step barrier that
decision rejects. The stages still run concurrently with the kernels, but every step
boundary becomes the point at which the run cannot go on until the filesystem has
caught up.

**Settle only at the drain.** No barrier inside the run at all. Lost because a refused
write early in a long run is reported only at the run's end: the run computes
everything after the refusal, discards all of it, and the journal places the refusal at
the close rather than near the step that submitted the write.

**Raise at the first point after the refusal is discovered.** Neither a barrier nor a
late report. Excluded: the moment a stage finds a failure depends on how the stages
were scheduled, so the step at which the run stops, what it computed before stopping
and the header of the refusal event would all depend on arrival order, which decision
0029 keeps out of every result and record.

**The cadence as a count of steps of a named tier.** Bounds in steps the work computed
after a refused write, and needs no crossing rule because it counts existing
boundaries. Lost on three points. A tier's step is a `Derived` duration that moves with
the profile's levels and with the configuration (decision 0023), so one declared count
is a different span of simulated time in every profile and every system, a setting
whose meaning moves when something else is changed. A named tier may be absent from a
profile, or coincide with another by name as the orbital tier does with the daily tier
on a configuration with no seasonal cycle, so the setting would need a tier vocabulary
checked at the profile and a rule for the absent tier. And decision 0023 declares every
step and window as a duration in seconds, never as a count alone; a count of steps
would be the one cadence in the profile in another unit.

**The cadence in seconds of wall-clock time.** Bounds the wall time a refused run
spends. Lost because wall time depends on the machine and its load: two runs of one
identity would settle at different steps and journal the refusal under different
headers, which lets something outside the run identity choose where a run stops.

**The cadence as a count of bytes or of submissions.** Deterministic, since submission
order is the run's evaluation order. Lost because the settle point then moves with the
levels and with which fields a step writes rather than with the model's clock, a reader
of the journal cannot place it on the clock, and the writer's memory is already bounded
by `write_ceiling`, so a byte cadence would declare a second bound for a question that
is not about memory.

**An existing physics cadence, such as the climate refresh interval or the radiation
interval, with no new setting.** Lost: those are declared for the physics and some are
`Bracketed` and swept (decision 0023), so sweeping one would move where the writer
settles; and a profile with the slow tier or the radiation scheme `Absent` would have no
cadence at all.

**Settle instants counted from the run's first instant.** Equivalent for a run started
at the epoch. Lost because a run continued from a later instant would then settle at
different instants from the run it continues; counted from the epoch, the settle
instants are a property of the clock alone.

## Consequences

- `Systems.Profile` gains `settle_interval`, required on `Profile`, `fast_profile` and
  `full_profile`, carried by `strip`, with an amendment line on decision 0014:
  `fiddlybits-52v.6.30`, after `fiddlybits-52v.6.25`.
- The run door gains `end_step!`, which the driver calls at the end of every step and
  which settles at the cadence under the step's header; `settle!` is called in `src`
  only by `end_step!` and `drain!`: `fiddlybits-52v.6.31`, after `fiddlybits-52v.6.26`,
  `fiddlybits-52v.6.27`, `fiddlybits-52v.6.11` and `fiddlybits-52v.6.30`.
- `settle!` raises a refused write once, and a later settle or the drain raises nothing
  further for it (`fiddlybits-52v.6.26` builds `settle!`, `fiddlybits-52v.6.27` the
  drain in the close).
- A settle is a wait of the driver's task at the cadence for the stages to land what is
  in flight, which `write_ceiling` bounds in bytes. Between settles nothing waits on the
  stages but a submitter the pool holds back.
- A record that names a run's write as stored is written only after the settle or drain
  that commits it, since a submission is not stored until then. A key a step submitted
  is in flight, not stored, until that point.
- No driver that steps a run's components exists in the tree. The one that is built
  calls `end_step!` at the end of every step and submits the fields a step wrote; the
  milestone plan that builds it carries the call and a test that a run with a refused
  write stops at the declared settle step. The obligation is noted on
  `fiddlybits-37w.1`, the first milestone plan after M0 whose run steps a component, and
  on `fiddlybits-caz.1`, whose plan drives the tiers of decision 0023.
- A refused run computes at most up to the first step boundary at or after the next
  multiple of `settle_interval` past the refused write's submission; the profile that
  declares the interval declares that bound.

## References

- Decision 0038, concurrency from the outset: stages sized to their resource, a pool
  bounded in bytes, a stage never the unit of waiting.
- Decision 0029, reproducibility across threads: arrival order reaches no result, and
  the run identity includes the profile.
- Decision 0042, the run event journal: the header, the `refusal` payload, and the
  journal recording decisions and exceptions.
- Decision 0046, the device-move tally carried by the run record.
- Decision 0014, the profile, whose cadences are declared in seconds.
- Decision 0008, one clock in SI seconds since the run epoch.
- Decision 0023, the timestep tiers, every step and window a duration in seconds.
- `docs/plans/fiddlybits-52v.6-provenance.md`, section The writer: `submit!`, `settle!`,
  `drain!`, the commit in submission order and the late refusals.
- `fiddlybits-52v.6.20`, the plan row that raised the question; user decision,
  2026-09-13: settle at a declared cadence.
