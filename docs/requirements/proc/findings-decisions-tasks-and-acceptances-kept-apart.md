+++
id = "REQ-PROC-002"
title = "Findings, decisions, requirements, tasks and acceptances are separate records, each citing the one it rests on, and an id is never reused"
old_path = ["/home/cfutro/git/vesper/notes/audits/docs-restructure-audit.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

After six fresh-context reviews of the restructured predecessor book, what remained
binding was not the fixes but the acceptances: deliberate states a later reader might
otherwise re-litigate, each recorded with its reason (a magnitude-bearing measurement
kept in prose where the argument fails without it; an illustrative pair of numbers
kept so a grepping reader lands on its own warning; a deliberate overlap between a map
row and a canonical home). The conventions chapter carried the companion rules from the
issue tracker: a document under the findings directory says what is true and carries
its evidence, the issue says what to do about it, so a finding can be read without
being re-litigated and an issue closed without editing the argument that produced it;
an issue with no source is not yet a finding; an issue that turns out to be wrong is
closed with its reason and never deleted, because several closures reversed an earlier
conclusion; ids are never reused, and hand allocation issued two duplicates; a marker
on an issue is annotation, never a verdict; regenerating a derived artifact is a step,
not an issue; an issue is code, physics, a decision or a measurement that settles a
mechanism, and one whose closure would only produce a number the next iteration
regenerates is not an issue; blocking and related edges are different, and recording a
consumer as a blocker hides work.

## Why it carries

The plan separates decision records, requirement records, findings and the oracle
registry, and tracks tasks in `bd`. The predecessor's evidence is what happens when the
kinds blur: arguments re-litigated, refutations lost, ids ambiguous forever. With one
developer and many agents, a record that can be read without its author is the only
kind that survives a session boundary.

## What this system must do

- Five record kinds, each with its own home and format: finding (`notes/findings/`,
  dated, evidence and "measured on"), decision (`docs/decisions/`, ADR with
  alternatives and consequences), requirement (`docs/requirements/`), task (`bd`),
  and oracle threshold (`docs/oracles/registry.toml`).
- Every task cites the finding or decision that justifies it; a task without a source
  is a finding not yet written.
- A refuted task is closed with its reason and kept; a reversed conclusion is a new
  finding that cites the one it reverses.
- Ids are issued by the tool that owns the kind (`bd` for tasks, the sequence for
  decisions and requirements) and never reused; an area is a label, not an id space.
- An acceptance (a deliberate state a reader might re-litigate) is a decision record
  with the alternative it refuses, so the argument is findable where the state is.
- A label on a task annotates location or timing and never decides a gate; a gate is
  computed from the oracle registry and the store (REQ-SYS-008).
- Regenerating a derived artifact is a step of the build, never a task.
- Blocking dependencies drive readiness; related edges do not.

## Enforced by

`bd` conventions in `CLAUDE.md`; the decisions and requirements README formats; a doc
lint that a task's description names a finding or decision path; the review of this
pass ("every old audit has exactly one disposition").

## References

- /home/cfutro/git/vesper/notes/audits/docs-restructure-audit.md
- /home/cfutro/git/vesper/docs/src/practice/conventions.md, "The issue tracker"
- Plan: Part D M-1 deliverables; first execution pass file list.
