+++
id = "0027"
title = "Every optimised kernel keeps a naive reference path, and a mutation run proves the oracles can fail"
status = "accepted"
date = 2026-09-08
+++

## Decision

**Two implementations of every optimised operator, and the slow one is the
specification.** Every kernel that is optimised, fused, or ported to the GPU is first
written as a naive serial Julia function whose correctness is obvious by inspection
and which is tested against the analytic oracles of decision 0026. The production
kernel must agree with the reference path to a tolerance derived from floating point
(the same roundoff bound the ledgers use), on every backend and precision the kernel
is certified for. The reference path is never deleted, never optimised, and never
fused: it is the thing the fast path is compared against, and it replaces the
independent reference implementations the predecessor lost when it forked its
vendored models.

**A weekly mutation run proves the oracle suite can fail.** A named list of
deliberate breaks is maintained beside the suite: a physical constant perturbed by one
percent, a Coriolis term dropped, a flux counted twice, a sign reversed in one
ledger, a stencil shifted by one cell, a reduction made partition-dependent, a
sentinel introduced at a boundary. The suite is executed against each mutated build,
and every mutation must be caught by at least one oracle. A mutation nothing catches
is a hole in the suite and files an issue; the suite may not be reported green until
the hole is closed or the mutation is recorded as out of scope with the reason.

## Alternatives considered

- *Trust the fast path once it passes the analytic oracles.* Rejected: the analytic
  cases exercise smooth fields and simple geometry; an indexing error at a pentagon
  cell or in a fused kernel's boundary handling can pass every one of them. The
  reference path exercises the same inputs the production run sees.
- *Keep the reference path only until the fast path passes, then delete it.*
  Rejected: every later change to the fast path would again have nothing to compare
  against. The cost of keeping it is a slow test; the cost of deleting it is the
  predecessor's history.
- *Run the mutation set per commit.* Rejected on cost; weekly is enough for a set
  whose purpose is to find holes in the suite rather than defects in the code.

## Consequences

- Every kernel file has a sibling reference function and a comparison test; a kernel
  without one does not merge.
- CPU/GPU and FP32/FP64 certification (decision 0029) is a comparison against the
  reference path, not against a previous run.
- The mutation list is a tracked file; adding an oracle class means adding the
  mutation it is meant to catch.
- The test suite is slower than it would otherwise be; the reference path runs at the
  smallest mesh level that exercises every special case (the base vertices, a
  refinement boundary), not at production size.

## References

- Predecessor record of what the lost independent implementations had caught, and
  therefore what the reference path must now catch:
  `/home/cfutro/docs/world/docs/src/reference/vendored-upstreams.md`.
- Predecessor failure class "a check that cannot fail is not a check" and "a probe
  with no positive control": `/home/cfutro/docs/world/docs/src/practice/failure-modes.md`.
- On mutation testing as a measure of test-suite adequacy: DeMillo, R. A., R. J.
  Lipton, and F. G. Sayward. "Hints on Test Data Selection: Help for the Practicing
  Programmer." Computer 11 (1978). DOI: 10.1109/C-M.1978.218136.

## Amendments

- 2026-09-13: the archive this record cites now resolves at /home/cfutro/git/vesper; /home/cfutro/docs/world no longer exists on disk, from notes/findings/2026-09-13-predecessor-archive-relocated-to-vesper.md.
