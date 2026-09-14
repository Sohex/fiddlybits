# The predecessor archive's on-disk location moved to /home/cfutro/git/vesper

Measured on 2026-09-13. `/home/cfutro/docs/world`, the path every decision record
before this date cites for the predecessor project, no longer exists on this
machine; only `/home/cfutro/docs/world.7z` does. User decision, 2026-09-13: the
predecessor's on-disk reference location is now `/home/cfutro/git/vesper`, a git
clone.

Checked directly rather than assumed:

- `git -C /home/cfutro/git/vesper log --oneline -1` reports HEAD `34f75fc5`.
- `git -C /home/cfutro/git/vesper merge-base --is-ancestor 6aa93489 HEAD` succeeds:
  commit `6aa93489d233d4e9d531d6479d338c643e34bc5e`, the commit every carried
  requirement record and every decision record pins as the archive commit, is an
  ancestor of the clone's HEAD.
- `docs/src/practice/conventions.md`, the file decision 0025 cites at that commit,
  exists at that path in the clone.

Every tracked file naming `/home/cfutro/docs/world` outside `docs/decisions/` had
the path text replaced with `/home/cfutro/git/vesper`, pinned commits left as
written. Each accepted decision record keeps its body as written, per
`docs/decisions/README.md`'s self-amendment convention, and instead carries one
dated `## Amendments` line naming this finding.
