+++
id = "0009"
title = "Coupling in one process, with declared ownership, ledgers at every exchange, and loops as values"
status = "accepted"
date = 2026-09-08
+++

## Decision

The whole coupled system runs in one process. Components exchange state through a
typed store, `WorldState`, in which every named quantity has exactly one declared
writer. `assemble(components...)` checks at construction that every quantity has one
writer, that every read has a writer or is an initial condition, and that the
intra-step read-write graph is acyclic once the reads declared as lagged are removed;
a cycle without a lagged edge is refused with the cycle printed.

A component declares what it reads (each read naming the level and the operator by
which it coarsens or refines; the operator is part of the declaration), what it
writes, which system-struct fields it depends on (decision 0007), and the device it
runs on. Its `step!` takes the store, an interval and the stripped constants.

### Exchanges close ledgers

An `Exchange` names the two components, the quantities crossing, and the conserved
quantities (mass, energy, water, salt, carbon, nitrogen, phosphorus, and angular
momentum for the atmosphere) that must balance across the crossing. `exchange!`
coarsens or refines by the destination's declared operators, computes each ledger
over the interval, and refuses if any is open. A ledger's tolerance is derived from
floating point (a small integer multiple of the number of terms, the machine epsilon
and the magnitude), never chosen. Ledgers are computed on in-memory state, never on
written output. A residual's time signature is classified: linear growth is a leak (a
flux counted once), a constant offset is a stock omitted from the inventory, a random
walk of rounding size is rounding. The three have different fixes and the report
names the class.

### The one land column

The land column (soil water, soil heat, snow, canopy water, lakes, glacier surface
mass balance, dust emission on bare tiles) is one component with one writer for each
of its states. The atmosphere reads its surface fluxes and albedo; the vegetation
reads its soil water and temperature and writes leaf area, root profile and
conductance parameters back. Two columns cannot disagree because there is one. This
is the design's answer to the predecessor's largest missing coupling.

### Loops are values with verdicts

The outer loops (terrain with climate, soil with biosphere, vegetation with climate,
the level ladder) are `FixedPointLoop` values: a body, an exit predicate over the
history, a declared monotonicity, an iteration cap, and a run floor decided before
the loop starts. An exit predicate returns one of `Converged`, `Bracketed`, `Refused`,
`NotEvaluable` or `BudgetExhausted`. A loop declared `Antitone` cannot return
`Converged`; its exit is a bracket by construction. A `Ladder` holds the loops and a
finalizer that re-evaluates every loop's exit at the final state and reports pass,
fail naming the loop, or not evaluable, and never substitutes a coarser artifact for
the one the predicate needs. The finalizer verifies; it does not iterate.

In this design most of the predecessor's loops dissolve into ordinary time stepping
(decisions 0015 to 0019): the ocean transport loop becomes
synchronous coupling, the carve verdict becomes an incision process, and the dust
loop closes in the tracer transport. What remains is the asynchronous coupling of the
slow tier to the fast one, and that is the loop this machinery serves.

## Alternatives considered

- **Separate processes exchanging files** (the predecessor). Every one of its five
  loops, its frozen-derived-quantity class, its "best available input" rule and its
  namespacing-by-build rule existed because artifacts were frozen at process
  boundaries. Lost.
- **A workflow engine orchestrating separate model executables.** The predecessor
  surveyed four and found each shaped for clusters or for an Earth calendar. Lost;
  there is one executable and one clock.
- **Ownership by convention** (a comment saying who writes what). The predecessor's
  record has the surface field that two components each wrote. Lost; ownership is
  checked at assembly.
- **Ledger tolerances chosen per ledger.** The predecessor's nitrogen closure was
  judged against a tolerance larger than the written-precision quantum of the column
  it differenced. Lost; tolerances are derived, and a check that reads a file
  measures the file's quantum first.

## Consequences

- The coupler's inner loop is sequential over components in the topological order
  from assembly, on one machine; distributed memory is not a goal.
- Every subsystem decision record names its reads, writes and the ledgers on its
  exchanges.
- Oracles implied: a duplicate writer is refused at assembly; an open ledger is
  refused at the store; the short coupled case closes every ledger over its run; a
  mutation that counts a flux twice is caught by the ledger classifier as a leak;
  the finalizer reports `NotEvaluable` rather than passing on what it could not test.

## References

- The predecessor's missed-coupling audit and its transpiration finding:
  `/home/cfutro/docs/world/notes/audits/missed-couplings.md`.
- The predecessor's argument for loops as brackets and the finalizer as verification:
  `/home/cfutro/docs/world/docs/src/pipeline/loops.md`.
- The predecessor's audits on closure stocks and closure tolerance:
  `/home/cfutro/docs/world/notes/audits/closure-stocks-are-incomplete.md`,
  `/home/cfutro/docs/world/notes/audits/closure-tolerance-under-written-precision.md`.
- The predecessor's audit of loop exit predicates without instruments:
  `/home/cfutro/docs/world/notes/audits/loop-exit-predicates.md`.

## Amendments

- 2026-09-10: the interfaces this record declares are carried by `fiddlybits-52v.11`,
  which settles first whether they belong to the M0 deliverable of decision 0034,
  since that record does not name them. Found while writing
  `docs/plans/fiddlybits-52v.1-skeleton.md`.
- 2026-09-13: the archive this record cites now resolves at /home/cfutro/git/vesper; /home/cfutro/docs/world no longer exists on disk, from notes/findings/2026-09-13-predecessor-archive-relocated-to-vesper.md.
