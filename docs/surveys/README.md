# Reference-tree surveys

A survey is a triage of external source trees, not an import review. It answers three
questions for each repository: what it is, whether it bears on anything this project has
decided, and when it would be worth a closer look. Nothing here adopts anything, and
nothing here is vendored: decision 0012 records an external tree by pinned commit,
licence and what was consulted, and that is what a closer look produces.

The trees live outside this repository, under `/home/cfutro/git/`, cloned for reading.
A survey record names the tree by path and the commit it was read at.

## Verdicts

- `import review` -- a plausible dependency; the next step is a record in `docs/imports/`
  against the checklist there, and a decision if it is to be adopted.
- `algorithmic reference` -- not a dependency, but its treatment of a problem this project
  solves is worth reading before the row that solves it is planned. The record names the
  decision or requirement it bears on.
- `oracle arm` -- an independent implementation whose answers could serve as a
  verification bar, per the third oracle tier of decision 0025.
- `not pertinent` -- read and dismissed, with the reason in one clause. A tree dismissed
  silently is a tree nobody can tell was examined.

## When

Timing is stated against the build order of decision 0034, so a reference is read when
the work it bears on is planned rather than at the moment it was found. `now` means it
bears on a decision that is open or on M0.
