+++
id = "0030"
title = "Every law, scheme and constant is anchored to a read primary source with a locator"
status = "accepted"
date = 2026-09-08
+++

## Decision

This is the fourth founding principle. Nothing drifts from accepted science by
accident because nothing is taken from a secondhand citation.

**Anchoring.** A `Sourced` disposition requires the primary source's identifier and
the table, equation or figure the value comes from, and the equation in this system
that the value multiplies. A scheme's decision record names the paper the scheme is
modelled on. An oracle bar names the paper whose residual statistics set it. A
number quoted from a review, a textbook table or another model's source code is not
a sourced value; it is `held` exposure until the primary work has been opened.

**The index.** `docs/references/INDEX.md` is tracked. Papers live in
`references/pdf/` at the repository root, untracked pure payload named
`<firstauthor><year><suffix>-<slug>.pdf`, so the directory can be linked whole into
any worktree and a fetched paper does not die with a worktree. Each row carries the
filename, the verbatim published title, the identifier, the status, and the
*anchors*: the decision records, requirement records, parameters and oracles that
cite it. A row with no anchor is flagged by the document lint. A `Sourced` parameter
or an oracle bar whose reference is not `read` is refused.

**Status is honest.**

- `read`: someone here opened the paper and took a number or a scheme from it, and
  the anchor names where. An optimistic `read` is the failure this file exists to catch.
- `held`: on disk, cited, not yet read for a number. An open exposure, not a resource.
- `requested`: listed in `docs/references/REQUESTS.md` for the user to fetch.

**Identifiers.** A DOI where one exists, confirmed against Crossref before a fetch is
requested, because a guessed DOI resolves to a real but wrong paper and nothing about
the result says so. A work old enough to have no clean DOI carries a stable locator
instead: an ISBN, a handle, an ADS bibcode, a publisher record, or a full
bibliographic entry, confirmed to resolve to the intended work. A vague title-only
query is the other failure; the published title is quoted verbatim.

**The request protocol.** A needed paper is requested from the user with the verbatim
title and the confirmed identifier, grouped by subsystem in `REQUESTS.md` with what
it anchors, after checking the index so nothing is fetched twice. On arrival the
paper is filed, its row moves to `held`, and it moves to `read` only when a number or
scheme has been taken from it by someone who opened it.

**External source trees** consulted as comparison material are recorded the same way
(pinned commit or release, tarball hash, licence, what was consulted and for which
record), extracted from pinned tarballs rather than cloned, and never vendored.

## Alternatives considered

- *Cite by whatever is convenient and fix later.* Rejected: the predecessor recorded
  two cases where a number taken from a citation rather than the paper was wrong, and
  one where the correction was itself half wrong.
- *Require a DOI without exception.* Rejected: several foundational works predate
  DOIs or carry none cleanly, and refusing them would exclude the primary source in
  favour of a secondary one with a DOI, which inverts the purpose.
- *Track the PDFs.* Rejected on size and licence; the record is tracked and the
  payload is regenerable from it.

## Consequences

- `docs/references/INDEX.md` and `REQUESTS.md` exist before the first parameter
  block, and the references pass is part of the first execution pass.
- A document lint runs over the tree: every identifier in a decision or requirement
  record has an index row; every `requested` row has a confirmed identifier; no
  `read` row lacks an anchor.
- The user is the fetch mechanism, by design: the request is a title and an
  identifier, and the confirmation step happens before the request.

## References

- Predecessor index whose read/held distinction and DOI-confirmation lesson this
  record carries: `/home/cfutro/docs/world/references/INDEX.md`.
- Predecessor failure class "a number taken from a citation rather than from the
  paper": `/home/cfutro/docs/world/docs/src/practice/failure-modes.md`.
