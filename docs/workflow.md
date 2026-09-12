# How work moves through this repository

Self-contained. A new session (any agent, any model) reads this and works the board
without further instruction. The argument for each rule is in decision 0037; the
session rules that bite are in `CLAUDE.md`; the practice book has the epistemic rules.

## The three layers

| layer | `kind` | who | what it produces |
| --- | --- | --- | --- |
| epic | `kind:epic` | nobody works it | a gate (from decision 0034) and children |
| plan row | `kind:plan`, always `tier:frontier` | Fable or Opus | `docs/plans/<epic-id>-<slug>.md` and the implementation and verify rows, filed with tier, boundary and acceptance |
| implementation row | `kind:impl`, `tier:local`, `tier:sonnet` or `tier:frontier` | an agent of that tier | one bounded change in one worktree, merged after review |
| verify row | `kind:verify` | Sonnet or frontier | the plan's oracle set run on the merged result, verdicts by name |

Tiers are chosen by the SHAPE of the row, never by its importance:

- `tier:local` (the local model behind `tools/references/serve_llm.sh`, or any small
  local agent): the target is fully specified and a test decides it. Transcribing a
  declared table, adding a lint, filling a manifest, running a recipe.
- `tier:sonnet`: the interface is written and settled, the code is not. A kernel from
  a stated formula, a reduction with its ledger, a parser for a documented format, a
  test file for a listed set of identities.
- `tier:frontier`: a design judgement or a numerical argument is inside the row, or
  its acceptance cannot be written before the work. All plan rows. All reviews.

## Anatomy of a row

Every implementation row has, in the tracker (`bd show <id>`):

- **description**: what to build and the **file boundary**, the paths the executor
  may create or edit. Touching a path outside it is a refusal, not a judgement call.
- **design**: the plan document and section it implements.
- **acceptance**: the oracles, identities or lints that decide it, by name, fixed
  before work starts. A row with an empty acceptance field is not ready; ask the
  planner (file a row against the plan), do not invent a criterion.
- **labels**: `kind:*`, `tier:*`, `area:*`, and `milestone:*` on a row that is timed
  to a milestone of decision 0034 without sitting under its epic (a survey or reading
  row). A row under a milestone epic inherits the milestone and does not repeat it.
  Closed vocabulary; `bd label list-all`.
- **deps**: the rows that must be merged first.

## The executor loop

```
bd ready -l kind:impl -l tier:sonnet          # rows of your tier with no open blockers
bd show <id>                                  # read description, design, acceptance
bd update <id> --claim
bd worktree create .beads/worktrees/<id> --branch <id>   # shares the tracker
cd .beads/worktrees/<id>
#   work only inside the file boundary
#   payload dirs (references/, oracles/data, inputs/data, store/) are read from the
#   main checkout by absolute path and never regenerated from a worktree
#   heavy work through qrun (see ~/.claude/CLAUDE.md), never directly
julia --project -e 'using Pkg; Pkg.test()'    # the per-commit gate, once it exists
#   run the row's acceptance oracles by name; record verdicts
bd update <id> --notes "oracles run: <names and verdicts>; blocked on: <nothing|what>"
bd close <id> --reason "completed: <oracles passed>"   # or leave open with the blocker named
git commit -m "<what> ... answers: <mechanism>"   # the answers: line only if the
                                                  # reference hash moved
```

A worktree lives under `.beads/worktrees/` rather than at the repository root, which
keeps it under the root and so under `.taskrunner.toml`: every `qrun` from inside it
inherits this repository's resource defaults. `.gitignore` covers the directory as a
class, so no worktree needs an entry of its own.

**Every tracker write comes before the commit that carries it.** Nothing in git records
the board: the tracker lives in Dolt and syncs through `refs/dolt/data`, and the JSONL
export is ignored. What the rule buys is that a reader of one commit sees the row's
notes and its close beside the code they describe, rather than having to date them
against a separate history. The same holds for a row filed for something found outside
the boundary: file it before the commit, not after.

A second commit is cheap and a second push is not. The `pre-push` hook runs the whole
suite through the scheduler (decision 0043), so a unit of work pushes once, at the end,
and every commit it carries is already made. `bd worktree create` still writes a
`.gitignore` entry of its own and `bd worktree remove` takes it back out; against the
class rule it is redundant, and the two still cancel, so leave it out of every commit.

Two end states only: **completed** (acceptance oracles ran and passed, named) or
**blocked** (what would unblock it, named). Anything found outside the boundary is a
NEW row (`bd create --parent <area> ...`), never a widening of your own. Do not
remove the worktree until the reviewer has merged; then
`bd worktree remove .beads/worktrees/<id>`.

## The planner's checklist (plan rows)

1. Read the decision records and requirement records the epic cites, by path.
2. Write `docs/plans/<epic-id>-<slug>.md` from `docs/plans/TEMPLATE.md`: module
   boundaries, types and functions by name, the oracle set with its registry ids.
3. File the rows: one per bounded change, each with tier, boundary, acceptance,
   design pointer and deps. Split any row whose acceptance you cannot write.
4. File one verify row depending on all of them.
5. Close the plan row. Do not implement.

## The reviewer's checklist (every merge, every tier)

1. The branch's acceptance oracles passed in the worktree, by name, in the notes.
2. The diff stays inside the file boundary.
3. The per-commit gate passes; a moved reference hash carries an `answers:` line.
4. The change matches the plan section it cites; a deviation is a new plan row.
5. Merge and remove the worktree. The row is already closed, in the branch's own
   commit; a review that rejects reopens it with what it found, and that reopen rides
   the next commit rather than standing alone.
6. Push once, after the merge. The `pre-push` hook runs the whole suite, so a push per
   commit runs the gate for no reason.

## Where things are

| path | holds |
| --- | --- |
| `docs/decisions/` | why: every design decision |
| `docs/requirements/` | what: carried findings with what enforces them |
| `docs/plans/` | how: one plan per plan row |
| `docs/oracles/registry.toml` | every threshold, provisional until registered |
| `docs/references/`, `references/pdf`, `references/text` | sources; the search instruments in `tools/references/` |
| `oracles/data/`, `inputs/data/` | datasets, in-tree, hashed in `docs/oracles/data/` and `docs/inputs/data/` |
| `notes/findings/` | dated measurements with their numbers |
| `bd` | tasks; `bd prime` after any context reset |
