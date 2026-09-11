# Decision records

One decision per file, numbered. Status is `accepted`, `proposed` or `superseded`.
A record states the decision, the alternatives and why they lost, the consequences,
and the references it rests on. It does not carry current values or measurements;
those live in `notes/findings/`.

```
+++
id = "0007"
title = "<one line>"
status = "accepted"   # accepted | proposed | superseded
date = 2026-09-08
+++

## Decision
## Alternatives considered
## Consequences
## References
```

`INDEX.md` in this directory is generated from these headers by
`tools/records/decisions.py` and rewritten by the pre-commit hook whenever a record is
staged. It is not edited by hand. The same tool checks the headers, and the commit is
refused if a check fails; `--self-test` runs every check against a fixture that must
fail it.

## When a record changes another (decision 0040)

A record that changes a prior record says so in its front matter, as data. Both keys
are optional arrays of inline tables, at the top level of the header:

```
amends = [{ record = "0017", what = "the fallback form beyond the composition tolerance" }]
supersedes = [{ record = "0019", what = "the whole record; its carve rule is withdrawn" }]
```

`record` is another record's `id` as a zero-padded string. `what` is required and
says what this record does to that one. Use `amends` where part of the earlier record
no longer holds and the rest stands, `supersedes` where it is replaced whole.

The edge is written once, on the record that acts. A superseded record carries
`status = "superseded"` and does not name its replacement; the back-edge is derived
from the forward ones. A superseded file is never deleted, and its body is never
rewritten: it is the evidence of what was believed when it was written.

Use inline tables as shown, not `[[amends]]` section headers. An array-of-tables
header captures every key that follows it, so a `date` added afterwards in the obvious
place would stop being the record's date.

## When a record changes itself

A record whose decision stands but whose detail is filled in or sharpened, usually
from a finding, is edited in place and gains a dated line under `## Amendments`
naming what moved and the finding it came from. No front-matter edge is involved:
the record is amending itself, not acting on another.

The dividing question is whose decision is changing. A record filling in its own
detail amends itself; a record overturning another's claim takes an edge.
