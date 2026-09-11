+++
id = "0039"
title = "A comment says what the code does; the argument for it lives in the durable record"
status = "accepted"
date = 2026-09-10
+++

## Decision

A comment or docstring describes behaviour: what this function does, what it takes,
what it returns, what it refuses, what a caller must hold true. That is its whole
job.

It does not argue for the code, justify the code, or give the code a background. In
particular, a comment never carries:

- **The case for a design.** Why this scheme and not the alternative is a decision
  record.
- **A measurement or a date.** "493 of 1071 pages were wrong", "38 percent of lines
  carry two columns", "measured 2026-09-09" belong in `notes/findings/`, dated, with
  the evidence beside them.
- **An incident.** The thing that went wrong once, the source that was mis-read, the
  run that had to be discarded. That is a finding, and if it changed a rule, the rule
  is in a decision record.
- **A persuasion aimed at the next reader.** A comment arguing that its approach is
  correct is a comment that expects to be doubted, and the answer to that is a record
  it can point to, not a longer comment.

**Where the argument goes.** `docs/decisions/` for a choice, `notes/findings/` for a
measurement, `docs/requirements/` for an obligation, `docs/practice.md` for a working
rule. A comment may name one of those by path when the behaviour it describes is
unobvious without it. A path is a pointer and costs one line; a summary of the record
is a second copy that will go stale.

**What a comment may still carry.** A non-obvious invariant, a unit, an index base, a
refusal and its condition, a locator for a formula, a warning about a call-order
constraint, the shape of an argument. All of these are behaviour.

## Alternatives considered

- *Keep the rationale next to the code, where the person changing it will see it.*
  This is the real argument for the other side and it is not a bad one: a reader
  editing a line is holding that file, not the decision index. Lost for three
  reasons. A rationale in a comment is not reachable by anything that searches the
  records, so the same question gets re-answered elsewhere and the two answers
  drift. A comment is copied with the code it sits beside and outlives the reasoning
  it describes, so it becomes a confident statement of something no longer true. And
  a measurement in a comment has no date and no evidence, which makes it an assertion
  where the project requires a finding. A pointer to the record gets the reader there
  and cannot go stale in the same way, because a moved path resolves through git and
  a wrong claim is superseded by a new record.
- *A rationale block at the top of a module, kept short.* Lost: this is the same
  thing at a coarser grain, and it is where the practice actually took hold here. The
  offending docstrings were module-level.
- *Allow it in tools and forbid it in model code.* Lost: the tools are how the
  archive and the oracles are built, and a wrong claim in a tool's docstring misleads
  exactly the reader who is deciding whether to trust its output.

## Consequences

- Four tool docstrings in `tools/references/` carried measurements, dates and an
  incident narrative and are cut back to what the tool does; the material they
  carried already existed in `notes/findings/`, which is where it stays.
- A reviewer's checklist item: a comment that argues is a change request, and the
  argument moves to a record.
- `CLAUDE.md` carries the one-line form of this rule, because it is a rule that bites
  during ordinary work and not only at review.
- This record is the reason a comment may look thinner than the thinking behind it.
  That is the intent: the thinking is written down, and it is written down somewhere
  a search will find it.

## References

- The occasion: `notes/findings/2026-09-09-janaf-table-identities.md` and
  `notes/findings/2026-09-09-tables-invented-from-figures.md` had been summarised
  into three tool docstrings, so the same measurement stood in four places with one
  date between them.
- Decision 0036 (TOML for every record a person edits) and the frozen-against-live
  distinction in `docs/practice.md`, "Documents and records": the same separation of
  what is edited in place from what is written once and superseded.
