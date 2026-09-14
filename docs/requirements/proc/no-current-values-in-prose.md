+++
id = "REQ-PROC-001"
title = "No current value is written into prose, no generated artifact is hand-edited, and a derived summary is checked against its primitives"
old_path = ["/home/cfutro/git/vesper/notes/audits/derived-structure-audit.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

A corpus-wide sweep on 2026-08-19 by six fresh-context reviewers found fifty-one
derived summaries in the predecessor's documentation (counts, partitions, pairings,
exception claims such as "those are the four that work") that failed against their own
primitives; every one was fixed or settled from surviving artifacts and history. The
conventions chapter had already recorded the mechanism: mean temperature, basin counts,
land composition and the active build were every one wrong in the documents within a
day of being written, so a number earns a place in a document only as a decision, a
threshold, an identity, or a magnitude an argument fails without; dated findings are
the exception and the opposite, keeping their numbers with a "measured on". The frozen
quantities sweep found about forty prose and comment instances of the same class,
among them stellar-cycle ranges that reproduced, to the digit, a sensitivity slope
retired twice since, and a module docstring whose endorheic share described no build in
the tree. A generated error-budget JSON had been hand-edited with a correction that the
next run of its generator discarded, invisibly in both directions. Two further rules
earned their place: rewrite superseded content rather than marking it, because a
grepping reader lands on the number and not the warning above it; and write a declared
numeric so the parser resolves it as a number, because three constants written as
`5.0e4` arrived as strings under YAML 1.1 and failed several steps from the declaration
that caused it, so quoting is the statement of intent.

## Why it carries

This project is worked by fresh sessions with no memory, and a stale number is an
ordinary number. The plan's content store (A6) and one-clock design remove many
producers of prose numbers, but requirement records, decision records, findings and
docstrings will still be written by hand, and the failure is a property of prose, not
of the old stack.

## What this system must do

- A number appears in a document only as a decision, a registered threshold, an
  identity, or a magnitude the argument fails without; any measured current value
  lives in a dated finding under `notes/findings/` with "measured on <artifact,
  support, commit>", or in a generated report.
- Requirement records restate old measurements only inside "What is true" with
  "measured on"; no record states a current value of this system.
- A generated artifact carries a header naming its generator and is never edited by
  hand; content belongs in the generator, and a CI check confirms regeneration is a
  no-op on the committed file.
- A derived summary in prose (a count of classes, "exactly N", a partition claim) is
  either generated or carries a lint-checked reference to the primitive it summarises.
- Superseded content is rewritten, not annotated.
- A declared numeric in any configuration file is written so the parser resolves it
  as a number; a quoted scalar is a deliberate string, and the check reports an
  unquoted scalar that reads as a number and resolves to a string.

## Enforced by

A doc lint over `docs/` and `notes/` for numerals outside the allowed forms and for
summaries without a primitive reference; the `notes/findings/README` dated-record rule;
a generated-file header and no-op regeneration check in CI; a configuration parse check.

## References

- /home/cfutro/git/vesper/notes/audits/derived-structure-audit.md
- /home/cfutro/git/vesper/docs/src/practice/conventions.md, "Documents and numbers"
- /home/cfutro/git/vesper/notes/audits/frozen-derived-quantities.md, tier 5
- /home/cfutro/git/vesper/notes/audits/missed-couplings.md, finding 3 (the hand-edited generator output)
- Plan: first execution pass, `notes/findings/` rule; verification that no effort estimate appears anywhere in the tree.
