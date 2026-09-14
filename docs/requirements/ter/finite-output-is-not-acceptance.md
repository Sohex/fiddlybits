+++
id = "REQ-TER-006"
title = "A finite output is not acceptance"
old_path = ["/home/cfutro/docs/world/config/spatial_conversion.yaml"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's conversion rule reads: "A finite output is not acceptance.
Every applicable closure and test passes; every inapplicable one names why;
and every fallback, ownership/connectivity change, discarded mode and unmapped
store remains visible in the artifact." The archive is a catalogue of what
that rule would have caught. Measured on the predecessor's builds: a
longitude remap produced plausible verdicts on the right grid for an entire
loop iteration while 1,172 of 3,621 basins were wrong (REQ-TER-010); a
nonlinear function evaluated on an annual mean "does not announce itself. Both
arms produce a plausible number on the right grid with the right units, the
code reads as an ordinary annual-mean read, and nothing downstream can tell"
(REQ-TER-008); a 1.0e20 sentinel sat in tile state on exactly the 1,053
partial cells the tiles existed for, inert until the next slice would have
read it into a flux kernel (REQ-TER-012); a climatology's glacier field read
identically zero and was a finding about the grid, not the planet
(REQ-TER-017). The audits also record the discipline that makes a verdict a
verdict: "a bar placed after the result it judges is not a criterion", an
undecidable arm is reported as NO VERDICT rather than as either pass or fail,
and a materiality test is taken against the instrument the consuming step
already declares rather than against a single percentage chosen for the
occasion.

## Why it carries

The class of silent, plausible failures survives any language and any mesh.
The only defence is a gate that asks positively for closures, tests and
inventories, refuses an artifact that does not carry them, and evaluates every
verdict against a bar fixed before the measurement. This is the contract's
top-level rule and the other seven contract records are its clauses.

## What this system must do

- An artifact enters the store only with: every closure ledger inside its
  derived tolerance or named not_applicable with a reason; every required test
  pass or not_applicable with a reason; every inventory present; and a verdict
  from an exit predicate declared before the run.
- Verdicts are one of `Converged | Bracketed | Refused | NotEvaluable`
  (decision A5). There is no warning status. An antitone loop cannot say
  converged. A `NotEvaluable` at a gate blocks the gate (Part E).
- Materiality is judged against the instrument the consuming component
  declares (its own bracket, its own storage tolerance), registered before the
  measurement (decision C2), never against a percentage chosen afterward.
- A measurement whose bracket crosses its bar is reported as undecided with
  the axis that decides it, not rounded to a verdict.

## Enforced by

- A5 store and `assemble`; A6 content-addressed store refusal.
- C2: a threshold is fixed before the value it judges has been seen and
  registered with the commit that holds it; `provisional = true` until then.
- Part D gates: every gate names its right answer; a `NotEvaluable` blocks.
- The finalizer (A5) re-evaluates every exit at the final state.

## References

- Oberkampf, W. L., Roy, C. J. (2010). "Verification and Validation in
  Scientific Computing". Cambridge University Press.
  DOI: 10.1017/CBO9780511760396.
- Nosek, B. A., Ebersole, C. R., DeHaven, A. C., Mellor, D. T. (2018). "The
  preregistration revolution". Proceedings of the National Academy of Sciences
  115(11), 2600-2606. DOI: 10.1073/pnas.1708274114. The argument for fixing
  the criterion before the result.
