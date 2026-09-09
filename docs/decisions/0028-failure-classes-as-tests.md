+++
id = "0028"
title = "The predecessor's failure classes become tests or process rules, each on its merits"
status = "accepted"
date = 2026-09-08
+++

## Decision

The predecessor project catalogued forty-one classes of how a simulation project
goes wrong, almost all found late by comparing two things that were supposed to
agree. Each class is examined here on its own merits, and given exactly one of four
dispositions:

- **T (type or build system):** the instance is made unrepresentable. A quantity
  with one definition and N accessors; a field whose support is part of its type;
  an immutable parameter struct; a content-addressed store with no overwrite;
  `Union{T, Missing}` instead of sentinels.
- **L (lint or smoke check):** a static check over the tree that refuses the
  pattern. No keyword defaults on physical arguments; a sourced constant without a
  locator; a per-band array holding one value without a stated reason; a number in
  prose that matches a generated state value.
- **R (runtime refusal):** the system refuses rather than proceeds. A read whose
  support digest mismatches; a ledger that does not close; an A/B harness whose A/A
  arm is not bitwise; a measurement below its instrument's scatter returned as
  `Unresolved` rather than as a number.
- **O (oracle test):** a test with a right answer that fires on the instance.
- **E (epistemic):** not testable in code; becomes one positive-form line in the
  practice book, citing the predecessor's argument by path.

The row-by-row table is `docs/failure-modes.md`. A class is carried only if the
mechanism behind it exists in this architecture; classes that were artifacts of the
predecessor's stack (one binary per configuration, a namelist beside a config, a
Fortran restart layout) are recorded there as not carried, with the reason, or
carried as the general lesson behind them.

New instances found in this project are appended to the table only when a class
recurs here; the table is a living record, not a monument.

## Alternatives considered

- *Carry all forty-one classes verbatim as rules.* Rejected: many were shaped by the
  old stack, and a rule with no mechanism behind it is a poison seed (the
  predecessor's own class for that).
- *Carry none and rediscover.* Rejected: the classes cost the predecessor real work
  to find, and the majority describe mechanisms this architecture shares (one
  quantity with several consumers; artifacts paired silently; a check that cannot
  fail).
- *Treat every class as a test.* Rejected: a minority are about records and
  reasoning, and a test that pretends to check a judgment is a check that cannot
  fail.

## Consequences

- `docs/failure-modes.md` is the index of what the type system, the lints, the
  refusals and the oracles exist to prevent; a new lint or refusal cites the class it
  serves.
- The practice book carries the epistemic classes as one-liners; their arguments
  stay in the predecessor by path rather than being re-argued here.
- A recurrence here of a class marked T or L is a defect in the mechanism, not a
  process failure, and is filed against the mechanism.

## References

- `/home/cfutro/docs/world/docs/src/practice/failure-modes.md` (the catalogue and
  its arguments).
- `/home/cfutro/docs/world/docs/src/practice/working-agreements.md` (the agreements
  whose incidents motivate the epistemic rows).
- `docs/failure-modes.md` in this repository (the dispositions).
