+++
id = "0042"
title = "Every run writes an append-only event journal beside its plan, from a closed event vocabulary"
status = "accepted"
date = 2026-09-10
amends = [{ record = "0010", what = "the run record gains a third element beside the plan and the system struct: an append-only event journal" }]
+++

## Decision

A run's record holds the plan it produced and the system struct it used (decision 0010),
and now a third thing: an append-only journal of what happened, under the same run UUID,
in TOML (decision 0036).

**Every event has the same header and a typed payload.** The header is the sequence
number, the simulated instant in SI seconds, the tier that was advancing, the component
that emitted it, and the event kind. The payload is a table whose shape is fixed per kind.
A reader can therefore filter on the header without knowing any payload, and a query
written against one kind keeps working when another is added.

**The event kind comes from a closed vocabulary.** At the founding:

| kind | payload |
| --- | --- |
| `verdict` | the loop or predicate by name, its verdict from decision 0009's five, the statistic, the bracket it was judged against |
| `refusal` | the `Verdicts.Refusal` that was raised: what was refused, where it was refused, and why |
| `ledger_open` | the ledger, the imbalance, the derived tolerance, the exchange it closed over |
| `refresh` | the trigger that fired, the boundary field that changed and by how much, the restart length in seconds and in orbits |
| `topology_change` | the connectivity-graph edit, the level whose numbering the cells are in, the cells involved as `CellId` values at that level, the quantity that crossed |
| `level_change` | the level moved from and to, and the reconvergence window |
| `artifact` | the content key written, its kind, its support id |
| `checkpoint` | the key, the working precision it was written at |
| `oracle` | the registry id, its verdict, the statistic and the threshold |
| `budget` | the cap reached, and which |

Adding a kind is a deliberate act with a test, in the way decision 0006's semantics
vocabulary is. The vocabulary is closed so that a query over the journal is a query over
a schema and not over prose.

**The journal records decisions and exceptions, never the passage of time.** A ledger
that closes inside its tolerance is not an event; one that does not is. A step that
advances normally is not an event; a refresh, a level change, a topology change, a
verdict, an oracle result, a refusal is. Anything emitted once per step is a diagnostic
series, and a series belongs in the store as a field with its own support and semantics,
where it can be reduced, compared and plotted. This is the rule that keeps the journal
bounded: its length scales with the number of decisions a run took, not with its step
count, so it stays a thing a person can read and a query can scan.

**It is written through one emitter and never by hand.** One function appends one event;
no component writes the file. The schema is enforced at that one place, and the lint
suite refuses a direct write to the journal path from anywhere else.

**It is inert.** No component reads it, nothing in the model branches on it, and it is not
in any content key. A run with journaling switched off produces bitwise identical
artifacts, and that is a test. This is what keeps it from becoming a second source of
truth beside the content-addressed store: it is a report of what the run decided, written
where the deciding happened, and the artifacts remain the only thing the model consumes.

## Alternatives considered

- **Error logging for refusals, and nothing else.** The considered position, and most of
  the way there. It fails on two specific points. A refusal is a legitimate outcome of a
  correct run under decision 0009, so routing it to the error channel makes a working run
  emit errors and trains a reader to ignore the channel. And a refusal carries structure,
  the predicate, the reservoir, the drift, the bracket and the window, which a message
  string flattens; recovering it means parsing log text, which is the reconstruction by
  scanning that decision 0029 rules out. Structured logging keyed by run rather than by
  process answers both, and structured logging keyed by run is this journal.

- **A journal for refusals and refresh triggers only.** Rejected in favour of the full
  vocabulary. The narrow version buys a smaller file and forecloses every use nobody has
  thought of yet, and the mechanism costs the same either way. What makes an unanticipated
  use possible is the schema, not the volume, which is why the vocabulary is closed and
  typed rather than free text.

- **A git repository per run, journalled by commit.** The pattern `ClimateModels.jl`
  implements (`docs/imports/mesharrays-and-climatemodels.md`). Rejected: it puts a second
  identity beside the content address, invites diffing two runs that share no ancestor,
  and makes the journal's own history a thing to reason about.

- **Reconstructing the sequence from the artifacts.** Rejected by decision 0029, which
  forbids rebuilding run records by scanning, and impossible for a refused run, which
  produces no artifact to scan.

- **A per-step journal.** Rejected by the bound above. A fast tier at a short step over
  many orbits would write a series, and a series is a field.

## Consequences

- The store gains one path per run and one writer. `fiddlybits-52v.6.7` carries the
  emitter, the vocabulary and the two tests; the verify row of that epic depends on it,
  and the one-emitter lint is in the suite at `fiddlybits-52v.1.3`.
- Two registry entries follow: the journal's inertness, asserted by a bitwise comparison
  of a run's artifacts with and without it; and the event-vocabulary closure, an
  enumeration test in the shape decision 0006 already requires for semantics, asserting
  that every kind has a declared payload schema and every emitted event validates against
  the schema of its kind.
- A refused run now leaves a record. This is the case that has no alternative: no artifact
  exists, so nothing else in the store can say why.
- The refresh-trigger sequence becomes data, which the acceleration factor's bracket
  (decision 0023) is swept against.
- The journal is written even when the run is abandoned mid-step, because it is appended
  as events occur rather than assembled at the end.

## References

- `docs/imports/mesharrays-and-climatemodels.md`, the reading that raised the question
  and the pattern this record declines.
- Decision 0009 (verdicts as values; ledgers at every exchange), decision 0010 (the run
  record this amends), decision 0023 (the refresh trigger and the swept acceleration
  factor), decision 0029 (run records append-only, never rebuilt by scanning), decision
  0036 (TOML for every record).
- User direction, 2026-09-10: the full vocabulary rather than the two kinds that have a
  named use today.

## Amendments

- 2026-09-13: the `refusal` payload is the `Verdicts.Refusal` that was raised, its
  quantity, site and reason, and `Events.RefusalPayload` names that type rather than
  declaring a second one; carried by `fiddlybits-52v.6.10`. The founding row read "the
  quantity and the bound it violated" as two numbers, while every refusal the tree
  raises is `Verdicts.refuse(quantity, site, reason)`, so no raised refusal could reach
  an event without a field invented for it. Three other readings were weighed.
  *`Refusal` gains the violated value and bound as numbers*: lost on what the refusals
  are. Most have no numeric bound at all (two supports whose digests differ, operands of
  different semantics, a backend given by something that is not a name, a device the
  driver does not report), so each would carry a number nobody measured; and the
  numeric ones do not fit one bound, since a closed or half-open range has two, a
  finiteness or power-of-four test has none, and an extent mismatch compares two lengths
  neither of which is the bound. *The strings plus optional typed numbers*: lost on the
  boundary rule. A three-argument `refuse` leaves the numbers absent at every site that
  has one and did not pass it, TOML writes an absent number as no key, and a reader of
  the journal cannot tell a refusal with no bound from one whose bound was dropped; the
  number would also stand twice in one record, in its field and in the reason sentence.
  *A closed vocabulary of violation shapes carried on `Refusal`*: lossless in
  principle, and lost because it is a second predicate language written beside the
  checks it describes, and because a statistic judged against a threshold already has a
  typed kind: `verdict` carries the statistic and the bracket, a loop's `Refused`
  included; `ledger_open` the imbalance and the tolerance; `oracle` the statistic and
  the threshold; `budget` the cap. The structure the first alternative above says a
  message string flattens is a loop's, and it is journalled through `verdict`. What is
  left to `refusal` is a read that could not be answered, whose structure is what, where
  and why, and those stay three fields a query filters on rather than one message. The
  founding `component` field is dropped because the header carries the emitting
  component and the refusal's site names where it was refused. A query that needs a
  refusal's numbers as numbers is met by a kind that carries them, added the way this
  record adds a kind, and not by widening `Refusal`.
- 2026-09-13: the `topology_change` payload names the level whose numbering its cells
  are in, as a `level` field, and carries the cells as `Mesh.CellId` values, the 0-based
  disk base of decision 0010, so the index base is named by type; carried by
  `fiddlybits-52v.6.13`. The founding payload held a list of integers, which the emitter
  filled with 1-based memory indices of the graph's coarse level; a reader of the TOML
  journal could place them only by knowing the emitter, which makes a cell index a
  coordinate. `Events` is included before `Mesh`, so `TopologyChangePayload` is
  parametric in the element type of its cells, and it refuses a number and a type that
  is not concrete; the connectivity emitter fills it through `Mesh.disk_id`, and the
  journal writer (`fiddlybits-52v.6.7`) writes a `CellId` as its disk integer at the disk
  boundary and refuses any other element type. In the journal a `topology_change` table
  therefore holds `level` and `cells`, and `cells` is 0-based at `level`. Four other
  readings were weighed. *Memory integers, with the base stated in the docstring and
  the writer converting*: lost because the base travels by a default only a reader of
  the source knows, and the writer would have to know which integer fields of which
  payload are cells, a translation layer keyed on field names. *0-based integers filled
  by the emitter*: lost on REQ-TER-010, since a bare integer of the disk base in memory
  is the mixed-base defect `CellId` makes a type error, and the translation would happen
  before the disk boundary rather than at it. *The field typed `Vector{Mesh.CellId}`*:
  not expressible, as `Events` cannot reach `Mesh` without breaking
  `build.module_order_acyclic`; and giving `Mesh.CellId` a supertype declared in
  `Events` would make the mesh's index type depend on the journal's vocabulary.
  *The support identity in place of the level*: lost because the digest covers the
  radius, the measures, the element type and the fractions, none of which numbers a
  cell, while the numbering of a uniform level of a run's one hierarchy is fixed by its
  level alone; the graph reports at a uniform level, which `Connectivity` refuses
  otherwise. A kind whose cells lie on a refined support names that support's refinement
  beside its level when it is added.
