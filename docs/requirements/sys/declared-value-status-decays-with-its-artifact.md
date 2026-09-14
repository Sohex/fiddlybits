+++
id = "REQ-SYS-003"
title = "A declared value's label says what stands behind it, and the label is demoted when the artifact behind it goes"
old_path = ["/home/cfutro/git/vesper/config/planet.yaml"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's canonical parameter file gave every block a status about what stood
behind the value, not about how old it was, with four atomic statuses and an argument
for each:

- DETERMINED: measured, derived by an artifact that exists, or decided in a way that is
  now load-bearing; downstream work may rely on it.
- DECLARED: the project cannot compute it, or has not reproducibly; a stated position
  written down so it is not read back as a result. The argument given for ocean
  salinity is the shape of the class: a real value is the steady state of riverine
  delivery against hydrothermal uptake, evaporite burial and reverse weathering over an
  ocean age and an outgassing history that nothing in the tree supplied, so the value
  is a position and the record says so.
- PROVISIONAL: a placeholder that will move; relying on it is relying on something
  already scheduled to change.
- DERIVED: computed by the named script from other values in the file; regenerate it
  rather than editing it.

Compound labels (MIXED, PARTLY DETERMINED, TRANSITIVE for facts about the run rather
than the world, DECLARED ABSENT for a deliberate null) built on those. The file's own
rule was that the label decays in one direction only: a stellar-cycle amplitude and
centre were carried before a baseline flux existed to centre on and were later read
back as though chosen; a composition block claimed DETERMINED for two values while its
next sentence withdrew one. When an artifact is deleted or superseded, the label above
every value that rested on it is part of what is now worthless and is demoted in the
same pass. The file's values are not carried.

## Why it carries

Decision A0 says everything that is not a foundational free parameter is a derived
state of the run or a declared-with-bracket initial condition when the system has no
mechanism yet to derive it, "and the record says which". The predecessor's vocabulary
is the observation that a label is about provenance rather than age, that a stated
position must be distinguishable from a result, and that the label must be demoted
automatically when the artifact behind it goes. A content-addressed store can make the
demotion a property of the identity rather than a discipline.

## What this system must do

- Every value in `System`, in every component's parameter struct and in every profile
  carries its disposition (REQ-SYS-001). A value the system cannot yet derive is
  `Bracketed` and its record states why it cannot be computed and what mechanism would
  compute it; that statement is what keeps it from being read back as a result.
- "Provisional" is not a disposition. A value that is scheduled to move is `Bracketed`
  with its sweep pending, and a threshold not yet registered carries
  `provisional = true` and an empty `registered_at` in the oracle registry until the
  commit that registers it.
- A `Derived` value's producer key (code version, inputs, support) is part of the
  artifact identity, so a deleted or superseded producer invalidates every dependent
  label without a hand pass.
- "Determined" means an artifact with a key exists in the store; no label claims a
  measurement that no artifact carries, and prose never determines a value.
- A declared absence (a process, a moon, a tide) is a declared value with a complete
  interface and a record of what its absence is worth where that can be bounded.
- Operational values that are facts about a run rather than the world (levels,
  cadences, precision) live in the `Profile`, never beside planetary quantities.

## Enforced by

Decision A3's `System` construction (keyword-only, no defaults, dispositions as types);
A6 identity; the oracle registry's `provisional` and `registered_at` fields; the doc
lint of REQ-PROC-001; the failure-modes review.

## References

- /home/cfutro/git/vesper/config/planet.yaml (header, lines 1-31, and the status
  arguments beside `star`, `ocean.salinity`, `stellar_cycle`)
- Plan decisions A0, A3, A6, A10.
