+++
id = "REQ-SYS-008"
title = "The dependency graph is complete and measured, and closure and status are computed from it"
old_path = ["/home/cfutro/git/vesper/notes/audits/pipeline-bookkeeping.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The audit of 2026-08-18 found the predecessor's climate inputs correct and its
bookkeeping wrong in four places. The pipeline graph declared four loops and no step
carried the vegetation-climate loop at all: the biosphere run was a leaf, the albedo
step declared no dependencies although its modelled mode raised without the biosphere's
output, and the soil step's feedback edge was missing, so the soil-biosphere loop was a
chain. Both feedback flags existed in the scripts; it was built capability the graph did
not know about. Because "an artifact no step generates does not exist", the planner
could not route to the modelled-albedo field and the status tool could not report it
missing; both were silent rather than wrong, which the project's own rule names as the
worse failure. The planner's hours warning was structurally zero because every
hours-class step was skipped before the count; a gate sentence saying a final baseline
is stricter than a converged one could never print; the graph had one climatology step
where the loop ran two, so the closure was right and the order wrong. Two literals in
the error budget were contradicted by the artifact they described (one understated by
64 per cent); four records had gone false against their artifacts, and the tracker cell
that fed a gate was the costly one. Computing that gate from tracker markers was later
removed as a category error: a marker records where work is filed, not what closing it
would change. One check, a bin-weighting concern, was measured and found not to move the
verdict, and the negative was recorded.

## Why it carries

A coupled system's loop closure is a property of its graph, and a declared edge that is
missing makes a cycle into a chain silently. The plan already makes dependencies a
measured property: each component declares its dependency set and a tracking wrapper
records the actual reads (A3), and the state store has exactly one declared writer per
quantity checked at `assemble` (A5). The predecessor's evidence is what those
mechanisms are for, and it adds the rule that status is computed from the store at
query time, never read from a cell someone wrote.

## What this system must do

- Every component declares the quantities it reads and writes; a tracking wrapper
  records the actual reads and writes; `recorded` is a subset of `declared` is a test, and a declared
  edge with no recorded read in the coupled test case is reported.
- `assemble` refuses a quantity with two writers, a written quantity nothing reads, and
  a read with no writer.
- Loop membership, tier membership and the closure of a target are derived from the
  measured graph, never from prose or from labels.
- Cost bands and gates are attached to steps as data and are computed from run records
  (measured wall time per profile), so a planner's warning is a measurement.
- Status ("what is missing", "what is now worthless") is computed from the content
  store's keys at query time; no document or tracker cell is a source of status.
- A negative result from a measured check is recorded with its artifact so it is not
  repeated.

## Enforced by

Decision A3's tracking wrapper and test; A5 `assemble`; A6 content-addressed keys; the
C6 per-commit short coupled case whose state hash exercises the measured graph.

## References

- /home/cfutro/git/vesper/notes/audits/pipeline-bookkeeping.md
- /home/cfutro/git/vesper/docs/src/practice/conventions.md, "The issue tracker" (a marker names a location, not an effect)
- Plan decisions A3, A5, A6.
