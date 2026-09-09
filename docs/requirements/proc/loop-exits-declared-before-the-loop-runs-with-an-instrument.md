+++
id = "REQ-PROC-006"
title = "Every loop exit is declared before the loop runs, has an instrument that can evaluate it, and reports NotEvaluable as a verdict"
old_path = ["/home/cfutro/docs/world/notes/audits/loop-exit-predicates.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Read on 2026-08-27 while building the predecessor's finalizer, against the four loop
exits its pipeline file stated. Six findings, each about the predicate rather than the
finalizer:

- The soil-biosphere loop's three exit criteria were declared in the right place, in
  the right order, "fixed before any iteration has been run", and nothing in the tree
  read any of them; the loop had a written exit and no instrument, so whether it had
  exited was a judgement for as long as it existed.
- Both tolerances were differences between iterations, and every iteration overwrote
  the only copy of the previous soil, so at the moment the criteria could be applied
  the quantity they were about had been destroyed; the iteration counter was an
  optional argument defaulting to none, so the maximum-iterations criterion had nothing
  to count against.
- Two numbers decided one criterion and only one had a key; the other lived in a
  comment, so the instrument carried it as a module constant citing the comment.
- Both carve scripts wrote the configured rung and albedo source into the verdict's
  sidecar rather than the climatology's own, and the guard that would have kept them
  honest was bypassed by exactly the explicit-path form every re-take used; the
  instrument therefore read the rung off the artifact's own latitude dimension and
  never off a sidecar.
- The vegetation-climate loop's exit ("re-take the verdict on modelled vegetation")
  was unreachable at the configured albedo source: the graph edge was correct for the
  mode the loop was meant to end in and inert at the value the configuration carried,
  so the pipeline bought a biosphere run whose output the albedo step did not read.
- Two artifacts the predicates needed had no generator in the graph, and by the
  project's own rule an artifact no step generates does not exist; the finalizer
  reported those loops as NOT EVALUABLE and named the command in each case.
- Re-taking one loop's exit at the operating support was not the minutes the chapter
  first claimed but two hours-scale runs, so the loop whose non-closure was most
  expensive to repair was also the most expensive to detect.

The orchestration survey added two observations: a workflow engine that cycles over
calendar points does not fit a system whose every loop exits on a predicate over
results, and a gate a person answers is stronger when the answer lands inside the
provenance graph rather than in a commit message.

## Why it carries

The plan's risk register names "a loop never converging" with the mitigation "every
exit declared before the loop runs with an instrument that can evaluate it" and the
tripwire "a `NotEvaluable` exit at M8"; A5 makes loops values with exit predicates
returning `Converged | Bracketed | Refused | NotEvaluable`. The predecessor's evidence is
the list of ways a declared exit fails to be evaluable: no consumer, destroyed inputs,
an unkeyed number, provenance read from a restatement, an exit unreachable under the
configuration, an object no step produces.

## What this system must do

- A loop's exit predicate is a value (`FixedPointLoop`, `Ladder`) declared at
  registration with its thresholds, window, instrument and the state it needs; the
  previous iterate it compares against is retained as an artifact by construction.
- Every number the predicate reads has a key in the registry; a threshold in a comment
  or a docstring does not exist.
- A predicate reads support identity, interval and instrument from the artifact's own
  attributes (A6), never from a configuration restatement.
- A predicate whose object no component produces returns `NotEvaluable` by name, with
  the producer that would make it evaluable, and a `NotEvaluable` verdict blocks the
  gate it belongs to.
- A loop exit unreachable under the current `Profile` (an edge inert at the configured
  setting) is refused at `assemble`, not discovered after the run.
- The cost of evaluating each exit at the operating level is declared beside the exit;
  an exit whose evaluation needs a run is scheduled as one.
- A gate answered by a person records the answer in the run's provenance.
- Loops iterate on results, never on calendar points.

## Enforced by

Decision A5 loop types; A6 artifact attributes; `docs/oracles/registry.toml`; the M8
gate "every loop exit evaluable"; the risk-register tripwire.

## References

- /home/cfutro/docs/world/notes/audits/loop-exit-predicates.md
- /home/cfutro/docs/world/notes/orchestration-frameworks.md (Cylc and the AiiDA gate pattern)
- Plan decisions A5, A6; Part E risk register.
