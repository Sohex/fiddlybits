+++
id = "0048"
title = "A row is worked to completion: what a row's own work turns up is finished inside it, and only a boundary or a scope crossing becomes a new row"
status = "accepted"
date = 2026-09-12
amends = [{ record = "0037", what = "what an executor does with what it finds: the default is to finish it inside the row, and filing a follow-on row is the exception the tests below name rather than the rule" }]
+++

## Decision

A row is finished when the thing it names is actually true, not when the smallest
change that touches its acceptance criteria has been made and the rest has been
written down somewhere.

Work that a row's own work turns up is that row's work. The default is to do it. A
new row is the exception, and it needs one of the reasons below to be named:

- **It crosses the file boundary.** The change belongs to paths this row may not
  create or edit. The boundary is the one thing an executor may not decide for
  itself (decision 0037).
- **It crosses the scope.** The change is a different question that happens to be
  adjacent: another component, another decision to take, a second mechanism that
  the row's own mechanism merely sits next to.
- **It has to merge first.** The change is a dependency of this row rather than part
  of it, and the ordering is what a dependency edge is for.
- **It is too large to carry.** Finishing it would put a second substantial piece of
  work inside one review, so the reviewer cannot judge either against its own plan
  section.

Nothing else is a reason. In particular, these are not reasons: that the work was not
foreseen when the row was written; that the row's acceptance criteria do not mention
it; that a finding or a decision record could be written about it instead; that
another row could be filed for it and the board would then show it.

**Filing is not progress.** A board that grows a row every time work is looked at
closely records the looking, not the work. Three rows filed and none of them closed
leaves the tree exactly where it was, with more bookkeeping to read. The measure of a
session is what is true in the tree at the end of it.

**Where this sits between the two rules it looks like.** *Work is invisible until it
is a bead* says that anything **not finished** is filed before the session ends, with
its boundary, acceptance and edges. *A filing is not an end state* says that a
finding, a row or a proposal is on the way to a change and the change is the point.
This record says which of the two applies when work appears mid-row: finish it, and
file only what one of the four tests above puts outside this row.

**What the executor reports.** A row closed as *completed* says what its acceptance
oracles were and that they passed. Where the row's own work turned up more, it says
what was finished beyond what the acceptance named, so a reviewer reads a diff that is
larger than the acceptance line and knows why. A row filed instead names which of the
four tests it met.

**What the reviewer checks.** The diff staying inside the file boundary is unchanged
and is still the hard rule. A diff that is wider than the row's acceptance criteria is
not by itself a finding against it; a diff that leaves the row's subject half-true is,
whatever was filed alongside.

## Alternatives considered

- *Every unforeseen piece of work becomes a new row.* This was the rule, in decision
  0037 and in `docs/workflow.md`. It is right about the boundary and wrong about
  everything else: it treats an executor's judgement as the risk, when the larger risk
  is a tree full of rows that each did the minimum. It also mis-prices the two sides.
  Widening a row costs one review of a larger diff. Filing instead costs a row that
  must be read, scheduled, given a worktree, reviewed and merged, by someone who no
  longer has the context that made the work obvious.
- *Let the row's acceptance criteria be rewritten as work proceeds.* Rejected: the
  acceptance is fixed before the work starts (decision 0037) precisely so a row cannot
  be declared complete by lowering its own bar. This record widens what the executor
  may **do**, not what the row may **claim**.
- *A size limit in lines or files.* Rejected as an effort estimate under another name,
  and it measures the wrong thing: a large mechanical change is easier to review than a
  small one that crosses a boundary.

## Consequences

- `docs/workflow.md`'s executor loop says the default is to finish, and lists the four
  tests; the sentence "anything found outside the boundary is a NEW row, never a
  widening of your own" is replaced by the boundary test alone.
- `CLAUDE.md` carries the rule beside the two it sits between.
- A row's close reason may name work beyond its acceptance criteria, and a review that
  sees a wider diff reads that reason rather than rejecting the diff for width.
- The file boundary stays the one line an executor may not cross on its own judgement,
  so the widening this record allows is bounded by the same paths as before.
