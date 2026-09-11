+++
id = "0040"
title = "A decision record names the records it amends or supersedes, in its front matter, as data"
status = "accepted"
date = 2026-09-10
+++

## Decision

A decision record that changes a prior record says so in its front matter, in a form
a program can read. Two optional keys, both arrays of inline tables, both at the top
level of the TOML header:

```
+++
id = "0041"
title = "<one line>"
status = "accepted"
date = 2026-09-10
amends = [{ record = "0017", what = "the fallback form beyond the composition tolerance" }]
supersedes = [{ record = "0019", what = "the whole record; its carve rule is withdrawn" }]
+++
```

`record` is another record's `id`, zero-padded, as a string. `what` says what this
record does to it, in a phrase, and is required: an edge with no statement of what
changed is bookkeeping rather than a record. Either key may be absent, and absence
means the record changes nothing before it.

**The edge is stored once, on the record that acts.** A superseded record carries
`status = "superseded"` and nothing else: it does not name what replaced it. The
back-edge is derived by reading the forward ones, because storing it in both places
is two definitions of one fact and they will disagree. A reader who opens a
superseded record learns from its status that it is dead, and one grep tells them
what killed it.

**Inline tables, not `[[amends]]` sections.** An array-of-tables header would be
valid TOML and would put every key after it inside that table, so a `date` line added
later in the obvious place would silently stop being the record's date. Inline tables
stay at the top level and cannot be broken that way.

### Which mechanism to use

This is not the only way a record changes, and the two must not be confused.

- **In-place amendment, the existing `## Amendments` section.** The record's decision
  stands and a detail inside it is filled in or sharpened, usually from a finding.
  The body is edited and a dated line is appended to that section naming what moved
  and the finding it came from. Every amendment in the corpus at the time of writing
  is of this kind. Nothing is related to anything: one document changed, and the line
  is its own log of the change. The finding it cites is a citation like any other in
  the record's references, not a relation between records, and needs no schema.
- **A front-matter edge.** A *later* record changes what an *earlier* one decided.
  `amends` where part of the earlier record no longer holds and the rest stands;
  `supersedes` where the earlier record is replaced whole. The earlier record's body
  is not rewritten and its status changes only for supersession, because the point of
  a frozen record is that it says what was believed when it was written.

The dividing question is whose decision is changing. A record filling in its own
detail amends itself. A record overturning another's claim takes an edge.

## Alternatives considered

- *A bare list of ids, `amends = ["0017"]`.* Simplest to parse and the usual form
  elsewhere. Lost because it records that something changed and not what, which is
  the half a reader needs and the half that cannot be recovered later. The graph
  without the reasons is a diagram, and this project's records exist for the reasons.
- *Store the back-edge too, `superseded_by = "0041"` on the old record.* Lost on the
  one-definition rule: the same edge written in two files drifts the first time a
  record is renumbered or a supersession is withdrawn, and neither copy is
  authoritative. The status field is enough to stop a reader trusting a dead record,
  and the check below reconciles the two.
- *Put the relation in the body, under a "Supersedes" heading.* Lost: it is the same
  information one parse-step further away, and the front matter is already the place
  this project puts what a program reads (decision 0036).

## Consequences

- `docs/decisions/README.md` carries the schema; it is the format spec and is edited
  in place.
- `tools/records/decisions.py` checks the headers and regenerates `INDEX.md` from
  them, and the pre-commit hook runs it whenever a record is staged, refusing the
  commit on a failed check. `--self-test` runs every check against a fixture that must
  fail it, and a clean fixture that must pass. The checks: the header parses and
  carries id, title, status and date; the id matches the filename and is unique; the
  status is in the vocabulary; the date is a bare TOML date; every edge entry carries
  `record` and `what`; every `record` resolves; no record amends or supersedes itself;
  no edge points at a later record; every record named by a `supersedes` edge has
  `status = "superseded"` and is superseded by exactly one record; every record with
  `status = "superseded"` is named by one.
- `INDEX.md` is where the derived back-edge appears, and the only place it is written
  down. It is generated, never edited.
- No record in the corpus carries an edge yet, because none has needed one. The first
  will be whatever settles the water door's fallback form, which is filed.
- A record that supersedes another does not delete it. The superseded file stays
  where it is, with its status changed, because it is the evidence of what was
  believed then.

## References

- Decision 0036 (TOML for every record header), decision 0002 (an addition to the
  model's scope gets a record that supersedes the line it contradicts), decision 0039
  (the argument lives in the record, not beside the code).
- `docs/practice.md`, "Documents and records": rewrite superseded content in a live
  document and do not mark it; a frozen record is the opposite case and is why the
  edge is needed.
