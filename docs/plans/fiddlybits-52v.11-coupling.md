+++
epic = "fiddlybits-52v.11"
title = "The coupling layer: one writer per quantity checked at assembly, ledgers at every crossing, and loops as values with verdicts"
decisions = ["0009", "0010", "0023", "0029", "0032", "0042"]
requirements = ["REQ-SYS-002", "REQ-SYS-007", "REQ-SYS-008", "REQ-SYS-009", "REQ-NUM-004", "REQ-NUM-005"]
oracles = ["coupling.assembly_refusals", "coupling.loop_finalizer", "loop.exit_criteria_on_a_known_surrogate", "loop.drift_against_its_own_scatter", "ledger.closure"]
status = "filed"
date = 2026-09-10
+++

## Scope

This plan builds the interfaces every component is written against: `WorldState` with
one declared writer per quantity, `assemble` that checks the ownership graph at
construction, `Exchange` that closes a ledger at every crossing, and the loops and
ladder that carry a verdict rather than a number.

It builds no component. Every check here is evidenced on fixture components, which is
the right way round: a duplicate writer is a property of the graph, and a fixture pair
declaring the same quantity is a sharper control than any real pair would be.

### The milestone question, settled

The M0 deliverable of decision 0034 does not name this layer, and the plan row that
filed this asked whether it belongs to M0 at all. It does, and the argument is
mechanical rather than a principle.

Decision 0010 states the store's central function as `plan(system, ladder, code)`, and
decision 0009 defines `Ladder` as the value holding the loops and their finalizer. An
M0 row's signature therefore already reads a coupling type: `fiddlybits-52v.6.4` cannot
be written without it. A layer an M0 row calls is an M0 deliverable whatever the
milestone table says, so decision 0034 is amended rather than the row being deferred.

The principle points the same way, and it is worth stating separately because it is
the reason the mechanical dependency exists at all. A subsystem may be a declared
absence; its interface may not, because a retrofitted interface reaches every
consumer. Decision 0032 relies on exactly that: the tides, the rotation-state
evolution and the obliquity stability are components whose bodies refuse with the
record's identifier, and a body that refuses is still a body that `assemble` must be
able to see, declare and wire.

What M0 cannot evidence is the layer under load. `ledger.closure` at a real crossing
and the exit predicates on a real trajectory need components that do not exist yet.
Both oracles run here on fixtures and surrogates, which decides the machinery, and
run again on the coupled case at M7, which decides the physics. The verify row records
which arm it ran.

## Module boundaries

| path | holds | row |
| --- | --- | --- |
| `src/Coupling/Coupling.jl` | the module and its includes | 52v.11.1 |
| `src/Coupling/state.jl` | `WorldState`, the component declaration, `assemble` | 52v.11.1 |
| `src/Coupling/exchange.jl` | `Exchange`, `exchange!`, the residual classifier | 52v.11.2 |
| `src/Coupling/loops.jl` | `FixedPointLoop`, `Ladder`, the exit verdicts, the finalizer | 52v.11.3 |
| `test/coupling/` | the fixture components, the surrogate trajectories, the suites | 52v.11.1 to 52v.11.3 |

`Coupling` enters `src/Fiddlybits.jl` in group F, **before `Provenance`**, which reads
`Ladder`. It references `Fields`, `Mesh`, `Systems`, `Time`, `Events` and `Verdicts`.

Two rows now add an include to `src/Fiddlybits.jl`: this one and `fiddlybits-52v.9.8`,
which adds `ShallowWater`. They add different lines to one file, so whichever merges
second rebases onto the first; neither widens into the other's module directory, and
`build.module_order_acyclic` decides the result either way.

It does not reference `Provenance`, and the reason is the cycle that would otherwise
close: the store reads `Ladder`, so the loops cannot read the store. Decision 0042
sends a `verdict`, a `refusal` and a `ledger_open` to the run journal, all three of
which are emitted from here through `Events.emit`, the one front door declared in
group A with a no-op sink that `Provenance` installs (`fiddlybits-52v.6.8`). This
plan first declared a hook of its own for that, as did the kernels plan and the mesh
plan; the plan review found the three and consolidated them, because three hooks for
one mechanism is three definitions of one quantity.

The component declaration is this module's and no other's. The system plan first
named a `declares(component)` beside its tracking wrapper, which would have been a
second declaration site; it now takes the declared graph as plain data, and this
module is what builds that data from `declare`.

## Types and functions

### The state and its assembly

```
WorldState                    a typed store, one declared writer per quantity
declare(component)            reads, writes, system-struct fields, device
assemble(components...)       -> the wired system, or a refusal naming the cycle
```

A component declares what it reads, each read naming the level and the operator by
which it coarsens or refines, since the operator is part of the declaration and not a
choice the caller makes later; what it writes; which system-struct fields it depends
on; and the device it runs on. Its `step!` takes the store, an interval and the
stripped constants, and nothing else.

`assemble` is where ownership stops being a convention. Its refusals:

| refusal | why | control |
| --- | --- | --- |
| a quantity with two declared writers | the predecessor's record has the surface field that two components each wrote | a fixture pair declaring the same quantity |
| a read with no writer and no initial condition | a read of a quantity nobody produces is a silent default waiting to happen | a fixture reading an undeclared quantity |
| a written quantity nothing reads | a quantity computed and written that no loop re-reads is a frozen derived quantity (REQ-SYS-002) | a fixture writing into the void |
| an intra-step cycle once the lagged reads are removed, with the cycle printed | a cycle without a lagged edge has no evaluation order | a fixture triad with no lagged edge, and the same triad with one, which must assemble |

The last control is the one that matters most, because it has to fire in one direction
and not in the other. A cycle checker that refuses every triad is not a checker.

`assemble` also refuses a component whose declared device disagrees with the device of
a quantity it reads without a declared move, so a silent host-to-device copy cannot
appear at a component boundary.

### Exchanges

```
Exchange(from, to, quantities, conserved)
exchange!(state, ex, interval)   -> (state, ledgers), refusing on any open ledger
```

`exchange!` coarsens or refines by the **destination's** declared operators, computes
each ledger over the interval, and refuses if any is open. The conserved quantities an
exchange names are mass, energy, water, salt, carbon, nitrogen, phosphorus, and
angular momentum for the atmosphere.

Three rules the implementation carries, each from a recorded failure:

- **One owner per flux, and a flux handed over is never recomputed by the receiver**
  (REQ-SYS-009). A receiver that recomputes has a second definition of the quantity.
- **Ledgers are computed on in-memory state, never on written output.** A check that
  reads a file measures the file's quantum first, and the predecessor's nitrogen
  closure was judged against a tolerance larger than the quantum of the column it
  differenced.
- **The tolerance is derived, never chosen**, and it is read from `Reductions` where
  the fields plan already puts it, so a ledger tolerance has one definition.

The residual's time signature is classified rather than reported: linear growth is a
leak, a constant offset is a stock omitted from the inventory, and a random walk of
rounding size is rounding. The three have different fixes and the report names the
class.

**A conservation check must not fail open.** ClimaCoupler's credits a component that
reports no stock with zero and keeps it in the total, and substitutes the integral of
net precipitation minus evaporation for a water stock it could not read, and its
assertion passes either way (`docs/imports/climacoupler-jl.md`). Here a component that
cannot report a stock is a refusal at assembly, not a zero at runtime, which is why
the stock declaration sits in `declare` rather than being asked for at the crossing.

**A crossing's measure is declared once, on the read's operator.** The operator a read
names declares the measure its crossing integrates under, a name from
`Fields.MEASURE_NAMES` or `NoMeasure()`, and the `Crossing` of an `Exchange` carries
that measure's values, refused when their name differs from the declaration. `Coarsen`
and `Refine` name it for their reduction; `AtLevel` names it for the receipt of a move,
because a move runs no reduction and its receipt ledger is the one integral it has.
Every `AtLevel` names its measure, `NoMeasure()` included. `assemble` reads each
`AtLevel` against the `Write` of the quantity it reads, and a `Write` declares the
semantics and the location (a `Mesh.Location`) every field placed for its quantity
carries, each refused at placement otherwise: a move of a quantity carrying a conserved
quantity names a measure when the quantity is `FluxDensity`, `Fraction` or `Intensive`,
names `NoMeasure()` when it is `Extensive`, and is refused for any other semantics; every
other `AtLevel` read names `NoMeasure()`. `assemble` refuses a `Coarsen` or `Refine` read
of a quantity whose write declares a location other than `Cells`, which the fields
plan's refusal table would otherwise first raise at an exchange. The key hashes the
write whole, so the location reaches it with no part of its own (the provenance plan,
section The key). A location learned from the field at placement was weighed and lost
for the reason the semantics was: `assemble` could not refuse a coarsening read of an
edge quantity before the first exchange.

The receipt of a move compares what the reader holds against the hand-over's result,
which for a move is the source field taken to the reader's device through `Backends.on`,
as for every other crossing: the total of each under `NoMeasure()`, and under a measure
the integral of each weighted by the measure's values at the read's level, the
magnitude taken over the result so weighted, in `Float64` over the cell count, on the
reader's device. A field of cells by trailing axes closes one ledger per column, and
its residual series are classified column by column.

Alternatives to where the measure is declared:

- On the `Crossing` alone. `assemble` never sees an `Exchange`, so a missing measure
  would surface at the first `exchange!`, and the name would sit on the operator for
  two operators and on the crossing for the third. Lost.
- As a keyword of `Read`. A coarsening read would carry two measure slots, one on
  `Read` and one on `Coarsen`, which is two declarations of one quantity. Lost.
- A `Move` operator beside `AtLevel`. A move is a property of any read, a coarsening
  one included, and a second encoding of it would have to agree with the `move` flag.
  Lost.
- On the `Write`. The measure of a reduction is the destination's, and a writer-side
  name would stand beside the one `Coarsen` and `Refine` declare. Lost.
- The semantics learned at `exchange!` rather than declared on the `Write`. `assemble`
  could not tell an `Extensive` move, which takes no measure, from a flux density,
  which does, so the refusal would wait for the first exchange. Lost.

Alternative to what the receipt of a move compares: the writer's field on its own device
against the reader's on its own. The receipt would then have a different reference for
a move than for every other crossing, whose receipt is taken against the operator's
result on the reader's device, and the ledger would hold a device copy, which changes no
value, to a rounding tolerance. Lost.

### Loops as values

```
FixedPointLoop(body, exit, monotonicity, cap, floor)
Ladder(loops, finalizer)
```

An exit predicate returns one of `Converged`, `Bracketed`, `Refused`, `NotEvaluable`
or `BudgetExhausted` from `Verdicts`, never a boolean and never a number. The rules:

- **A loop declared `Antitone` cannot return `Converged`.** Its exit is a bracket by
  construction, and its `Bracketed` verdict reports the width and the overshoot
  separately, because a bracket whose overshoot is hidden inside its width is a
  convergence claim in disguise.
- **A cap on iterations is a refusal boundary, never a second success condition.**
  Hitting it returns `BudgetExhausted`, which is not a pass.
- **A run floor is decided before the loop starts**, so a loop cannot exit on its first
  evaluation because the first evaluation happened to look settled.
- **Every tolerance is dimensionless** (decision 0023). An absolute tolerance is
  refused at construction, which is the same rule the oracle registry applies to a
  threshold, applied here at the loop instead.

The `Ladder`'s finalizer re-evaluates every loop's exit at the final state and reports
pass, fail naming the loop, or not evaluable. **The finalizer verifies; it does not
iterate**, and it never substitutes a coarser artifact for the one a predicate needs.
A predicate that cannot be evaluated on what the run actually produced returns
`NotEvaluable` by name, and a `NotEvaluable` is not a pass.

A loop left open on purpose is a declared absence whose cost is measured and reported,
never an assumption read as a result (REQ-SYS-007).

## Oracles

Two entries exist and belong here: `loop.exit_criteria_on_a_known_surrogate` and
`loop.drift_against_its_own_scatter`. `ledger.closure` is shared with the fields plan,
which runs its reduction arm; this plan runs its exchange arm. Two are added.

| id | right answer | the mutation that must make it fail |
| --- | --- | --- |
| `coupling.assembly_refusals` | each of the four assembly refusals fires on its fixture, and the graph that should assemble does | the triad with a lagged edge, which must assemble rather than being refused with the rest |
| `coupling.loop_finalizer` | an `Antitone` loop never returns `Converged`; a cap returns `BudgetExhausted`; the finalizer returns `NotEvaluable` rather than passing on what it could not test | a finalizer given a coarser artifact than the predicate needs, which must refuse to substitute it |
| `loop.exit_criteria_on_a_known_surrogate` | `Converged` on the settled trajectory, `Converged` or `Bracketed` on the oscillating one, and not `Converged` on the crawling one | the crawling trajectory, which a drift-window test alone passes |
| `loop.drift_against_its_own_scatter` | the phase-randomised surrogate fraction reported beside the declared bracket, with no bar | none; the entry is REPORT by construction, because a significance level is not a tolerance |
| `ledger.closure` | every exchange's residual within one derived bound unit, with its signature classified | a flux counted twice at the crossing, whose residual must grow linearly and be classified a leak |

`loop.exit_criteria_on_a_known_surrogate` is the entry that makes this layer testable
at M0 at all. Its three surrogate trajectories have a status known in advance and need
no physics, and its declared positive control is the trajectory that a naive
drift-window test passes and should not.

The surrogate phases for `loop.drift_against_its_own_scatter` come from the
counter-based generator of `fiddlybits-52v.6.5`, so the report is reproducible; that
is a dependency between two M0 areas rather than a convenience.

## Rows filed

| row | tier | boundary | acceptance |
| --- | --- | --- | --- |
| 52v.11.1 | frontier | `src/Coupling/Coupling.jl`, `src/Coupling/state.jl`, `test/coupling/state.jl`, the `Coupling` include in `src/Fiddlybits.jl` | `coupling.assembly_refusals` passes with all four refusals firing and the lagged triad assembling; a device disagreement at a boundary refuses; the declared graph handed to `Systems.affected` is built here and nowhere else |
| 52v.11.2 | sonnet | `src/Coupling/exchange.jl`, `test/coupling/exchange.jl` | `ledger.closure` passes on the exchange arm with the double-count control classified a leak; a component that cannot report a stock refuses at assembly rather than being credited zero |
| 52v.11.3 | frontier | `src/Coupling/loops.jl`, `test/coupling/loops.jl` | `coupling.loop_finalizer`, `loop.exit_criteria_on_a_known_surrogate` and `loop.drift_against_its_own_scatter` all run; an absolute tolerance is refused at construction |
| 52v.11.4 | sonnet | none; reports only | all five oracles ran; verdicts by name; the arm each ran on recorded, since the fixture arm decides the machinery and the coupled arm at M7 decides the physics |
| 52v.11.7 | sonnet | `src/Coupling/state.jl`, `src/Coupling/exchange.jl`, `test/coupling/state.jl`, `test/coupling/exchange.jl`, the `Write` constructions in `test/provenance/fixtures.jl`, `test/provenance/journal.jl` and `test/io/store_fixtures.jl`, `test/provenance/key_stability.jl` | `coupling.assembly_refusals` passes with a `Coarsen` and a `Refine` read of an edge quantity refused naming the location and the same reads of a cell quantity assembling; a field placed at another location than its write's refuses naming both, the matching field placing; a `Write` without `location` refuses; `provenance.key_stability` gives two keys for writes differing only in location, the arm failing with the location left out of the canonical bytes |

52v.11.2 and 52v.11.3 depend on 52v.11.1; 52v.11.3 depends on the counter-based
generator; 52v.11.1 depends on `fiddlybits-52v.6.8` for `Events.emit`. 52v.11.7 depends
on `fiddlybits-52v.2.20` for `Mesh.Location`, on `fiddlybits-52v.3.26` for
`Fields.location`, and on `fiddlybits-52v.6.26`, which edits `test/io/store_fixtures.jl`;
it blocks `fiddlybits-52v.6.35`, whose store checks a field's location against its write. The area depends on the fields plan for the ledger and on the system plan
for `Profile`, which holds the exit brackets.
