+++
id = "REQ-PROC-007"
title = "Individually converged is not jointly converged; a finalizer re-evaluates every loop's exit at the final state and never substitutes a coarser artifact"
old_path = ["/home/cfutro/git/vesper/docs/src/pipeline/loops.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's loops were nested, and the outermost declared that it advanced only
after replaying the inner three on the new support, which is what would have made the
final state a joint fixed point. In practice that replay was not bought: the cost
argument put the bulk of the work at the coarsest rung, so the final state had terrain
carved at one rung, soil and vegetation converged at that rung, and a climate merely
settled at a finer one. Each loop exited; none exited against the others' final state.
The chapter called that a defensible trade and the leaving of it unmeasured a defect,
because the failure is silent: every artifact is a real artifact of a real world, and a
verdict taken on a coarser climate looks exactly like one taken on the finer. So the
finalizer was a verification, not another iteration: another turn of every loop pays
for the couplings that had already closed and does not say which one had not, where
verification localises the failure to a named loop. It reported NOT EVALUABLE as a
third verdict distinct from pass and fail, exited non-zero when nothing failed and
something could not be tested, never substituted a coarser artifact for the operating
support's ("a finalizer that passes on what it could not test is the failure it exists
to prevent"), ran once after the ladder, and left the decision to re-enter a loop to
the author because re-entry was a commissioning-scale purchase.

## Why it carries

The plan runs two profiles at different levels (A10), a resolution ladder, an
asynchronous slow tier with declared refresh criteria (B9), and local refinement (A1),
so a final state assembled from components converged at different levels and cadences
is the normal case. A5 specifies that a finalizer re-evaluates every exit at the final
state. This record carries the argument for why it is a verification rather than a
loop, and the rule that it may not pass on what it could not test.

## What this system must do

- After a run is declared finished, a finalizer evaluates every loop's own exit
  predicate against the final `WorldState` at the operating level of the profile and
  records `Converged`, `Bracketed`, `Refused` or `NotEvaluable` per loop, with the
  instrument and the artifact it read.
- The finalizer never substitutes an earlier iterate, a coarser level or a single arm
  where the exit is defined on a pair; it reports `NotEvaluable` with the producer
  that would make the exit evaluable.
- The finalizer is not a loop: it does not re-enter anything, and a failure names the
  loop and the cost of re-entering it at the operating level.
- A run's identity records the finalizer's verdict per loop and the level each exit was
  evaluated at; a result from the fast profile is labelled as such wherever it
  appears.
- A `NotEvaluable` or `Refused` verdict at the final state blocks a milestone gate.

## Enforced by

Decision A5 (finalizer); A10 profile identity; the M8 and M10 gates "every loop exit
evaluable"; the oracle registry.

## References

- /home/cfutro/git/vesper/docs/src/pipeline/loops.md, "The finalizer: individually converged is not jointly converged"
- /home/cfutro/git/vesper/notes/audits/loop-exit-predicates.md
- Plan decisions A1, A5, A10, B9.
