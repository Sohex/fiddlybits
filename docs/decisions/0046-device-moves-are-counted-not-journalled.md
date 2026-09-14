+++
id = "0046"
title = "A device move is counted, never journalled: the tally is a run-record field and the move sink is installed apart from the event sink"
status = "accepted"
date = 2026-09-11
amends = [
  { record = "0010", what = "the run record gains a fourth element beside the plan, the system struct and the journal: the device-move tally" },
  { record = "0011", what = "what recording a device move means: the run record carries a count per direction, and the per-move record reaches only a sink installed for moves" },
]
+++

## Decision

`Events.moved` and `Events.emit` handed their records to one installed callback, and a
`Moved` is not an `Event`: no kind in decision 0042's closed vocabulary names a device
move. The journal writer is not built yet, so nothing in the tree was receiving a record
it had no schema for; this record answers the question before the writer exists.

**A `Moved` never reaches the journal, and no kind is added for it.** The journal records
decisions and exceptions (decision 0042). A device-to-host copy is neither: it is the
cost of the contract the caller invoked, on the path that invoked it. A global sum on
device-resident input reads its block sums back once per call, so the count of moves
scales with the reduction count, which is the per-step series decision 0042 forbids the
journal and sends to the store instead. The bound is the whole point of the closed
vocabulary: a journal whose length scales with the work a run did is not a thing a person
reads or a query scans.

**It reaches the run record as a tally: one count per ordered pair of backend names,
reported once.** `Events` holds the tally, `moved` adds one to it under `(from, to)`,
`move_counts` reads it, `reset_move_counts!` empties it at a run boundary. The tally is
bounded by the number of ordered pairs of backend names, which is why `moved` refuses a
`from` or a `to` that is not a `Symbol`: a name is what makes the key set small, and an
array or a backend object as a key would make the tally grow with the moves it counts.
The run record writes it beside the plan and the system struct (decision 0010), where a
run's inputs already live.

Per direction rather than as one number, because the two directions mean different
things. A host-to-device count is staging, paid once per field at the start of a run; a
device-to-host count is synchronisation, paid per call on the hot path. A single total
cannot tell a run that uploaded its inputs from a run that read a scalar back inside a
loop, and telling those apart is exactly what `fiddlybits-52v.7.47` acts on.

**`moved` and `emit` no longer share an installed sink.** `sink!` installs the event
sink, which only `emit` reaches; `move_sink!` installs the move sink, which only `moved`
reaches. Both default to `noop_sink`. A journal writer installs the event sink and can
therefore never be handed a record the journal has no kind for, without writing a single
defensive line. The per-move record is not deleted: a diagnostic run, and every move test
in the suite, installs a move sink and sees each move with its array and its direction.
What changes is that the journal is not one of the things that can be installed there by
accident.

## Alternatives considered

- *An eleventh kind, `move`, with a line per move.* The faithful answer, and the one that
  keeps when and where. Lost on the bound. Its journal length scales with the reduction
  count rather than with the decisions the run took, which is the case decision 0042
  named when it rejected a per-step journal. It also loses under decision 0038: with
  stages running concurrently, the interleaving of moves from different stages is not
  determined, so two runs that produce bitwise identical artifacts would produce
  different journals, and a sequence number would be carrying arrival order into a
  record. A tally is a commutative reduction and is partition-independent in the sense
  decision 0029 requires.
- *One sink, and a journal writer that filters by type.* Simple, and it needs no new
  installation point. Lost: the filter has to be written again in every sink anyone
  installs, and a sink that must discard what it is handed is a schema enforced in prose
  rather than in types, which is the failure decision 0042's closed vocabulary exists to
  prevent. The type system carries the distinction for free once there are two doors.
- *A move as a field in the store, the way decision 0042 sends a diagnostic series there.*
  Lost on what a field is. A field carries a support, semantics, a dimension and an
  interval (decision 0006), and a device move has none of them: it is not attached to a
  cell, a level or an instant of the model clock. The count of a thing that is not a
  field belongs in the run record, which is where the run's other non-field facts are.
- *Not recording the move at all, and deleting `Moved`.* Lost: decision 0011 says the
  move between devices is explicit and recorded, the per-move record is what the
  reduction tests count to assert that a repeated reduction does not read back more than
  once, and `fiddlybits-52v.7.47` needs the number.
- *One total count rather than a count per direction.* Lost on the paragraph above: it
  cannot separate staging from synchronisation, and it is not cheaper in any way that
  matters.
- *A `budget` event when the move count crosses a declared ceiling.* Not rejected, and
  not taken here. A ceiling crossed is a decision, `budget` is already in the vocabulary,
  and one event per run per cap is bounded, so the flood has a door into the journal that
  needs no new kind. What it needs first is a ceiling, which is a constant with a
  disposition and a profile field, and neither exists. It is filed rather than invented.

## Consequences

- `src/Events/Events.jl` gains `MOVE_SINK`, `move_sink!`, the tally behind `move_counts`,
  `move_total` and `reset_move_counts!`, and a refusal in `moved` for a backend that is
  not named by a `Symbol`. `sink!` and `emit` are unchanged in behaviour and narrower in
  contract.
- The tally is mutated under a lock, because a move can be recorded from any stage
  decision 0038 has running at the time.
- Every test that counts moves installs `move_sink!` instead of `sink!`:
  `test/backends/move_events.jl` and `test/reductions/segment_moves.jl`. What they count
  is unchanged, since the records they receive are the same records.
- `fiddlybits-52v.6.7`, which writes the journal, installs the event sink only. Nothing
  it writes has to know what a `Moved` is.
- The run record's move-tally field is `fiddlybits-52v.6.11`, filed against the store,
  since the run record writer is outside this record's reach.
- The move ceiling that would raise one `budget` event is `fiddlybits-52v.6.12`, filed
  and blocked on a profile that declares one.
- A stated residual: the tally says how many moves and which way, never where. A run that
  needs the call site installs a move sink, which is the mechanism the suite already
  uses. Putting the site in the tally means giving `moved` a component argument, which
  every caller would then have to pass.
- The flood stays visible. A run whose device-to-host count grows with its reduction
  count reports a large number in one field of its run record, which is the signal
  `fiddlybits-52v.7.47` is about and the reason the tally is not a single total.

## Amendments

- 2026-09-14: the sinks `sink!` and `move_sink!` install are a closed set of concrete
  types, never any callable (user decision 2026-09-14, option C). `sink!` installs an
  `Events.EventSink`, one of `NoopSink`, `Journal` and `Collector{Event}`; `move_sink!`
  installs an `Events.MoveSink`, one of `NoopSink`, `MoveTally` and `Collector{Moved}`.
  Each is called through a method on its concrete type, and `SINK` and `MOVE_SINK` are
  `Ref`s to those unions, so `emit` and `moved` call their sink by union splitting
  rather than by a runtime dispatch on a value of type `Any`. A value outside the set is
  refused by name at the installer, with the installed sink left in place. The `Journal`
  struct is declared in `Events` behind the checked door, since a union names its
  members where it is declared: its one constructor takes the `Checked` token first,
  which `install_journal!` passes after its refusals, and the token's one definition
  moves from `Systems` to `Verdicts`, which `Events` and `Systems` both load after, with
  `Systems` importing it. Its method appending an event stays in
  `src/Provenance/journal.jl`. The run's
  tally is the `MoveTally` `MOVE_TALLY`, which `moved` hands every record to before the
  installed sink; a `MoveTally` installed as the move sink counts a scope, which is how
  the move tests count, and `Collector{R}` is the collecting sink every other test
  installs. A `Moved` names its backends as `Symbol` fields. The installers
  (`src/Provenance/journal.jl` and every test under `test/` that installed a closure)
  are written against the set, and the accepted `report_opt` entry for `Events.moved`
  leaves `test/fields/static_pass.toml`. From
  `notes/findings/2026-09-14-a-caught-exception-and-an-installed-sink-dispatch-on-a-value-of-type-any.md`,
  carried by `fiddlybits-52v.3.25`.

## References

- Decision 0042 (the closed vocabulary, the bound that keeps the journal from becoming a
  series, and the journal's inertness), decision 0010 (the run record this adds a field
  to), decision 0011 (the explicit, recorded device move), decision 0006 (what a field
  carries, which a move does not), decision 0029 (partition independence), decision 0038
  (concurrent stages, which is why the interleaving of moves is not determined).
- `docs/plans/fiddlybits-52v.6-provenance.md`, section "The journal", which declares the
  one emitter and the sink `fiddlybits-52v.6.7` installs.
- `docs/plans/fiddlybits-52v.7-kernels.md`, section "The reductions", for which reads a
  reduction makes on device-resident input.
- `fiddlybits-52v.7.44`, which routed the last unrecorded host reads in `Reductions`
  through the recorded move and raised this question.
