+++
id = "0037"
title = "Tiered agentic execution: plans by frontier models, implementation rows sized to an executor class, one worktree per row"
status = "accepted"
date = 2026-09-08
+++

## Decision

Work is organised in three layers, each a row in `bd`, and the layers are separated
because the difficult work is in the planning.

1. **Epic** (a milestone or a subsystem): states the gate it must pass, from decision
   0034, and nothing else. Never worked directly.
2. **Plan row** (`kind:plan`, always `tier:frontier`): a frontier model (Fable or Opus)
   reads the decision records and requirement records the epic cites and writes a plan
   document under `docs/plans/<epic-id>-<slug>.md`: the module boundaries, the types and
   functions by name, the oracles each piece must pass, and the decomposition into
   implementation rows, which the planner files itself with their tier, acceptance
   criteria, file boundary and dependencies. A plan row closes when its rows exist and
   its document is on disk. The planner does not implement.
3. **Implementation row** (`kind:impl`): one bounded piece of work with a declared
   executor class, a file boundary it may not cross, and acceptance criteria that name
   the oracle or identity that must pass. Executed in its own git worktree
   (`bd worktree create <row-id>`), on its own branch, by an agent of the row's tier.
   A `kind:verify` row per plan runs the plan's whole oracle set on the merged result
   and is `tier:frontier` or `tier:sonnet` depending on what judgement it needs.

**Executor classes** are labels, chosen by the planner from the shape of the row, never
from its importance:

- `tier:local`: mechanical work with a fully specified target and a test that decides
  it (transcribing a declared table into a struct, adding a lint that greps for a
  pattern, filling a manifest, running a recipe, renaming to a convention). The local
  Qwen model behind `tools/references/serve_llm.sh` or an equivalent local agent.
- `tier:sonnet`: bounded implementation against a written interface where the design
  is settled but the code is not (a kernel from a specified formula, a reduction with
  its ledger, a parser for a documented format, a test file for a listed set of
  identities). Sonnet-class agents.
- `tier:frontier`: anything that needs a design judgement or a numerical argument
  (the dynamical-core discretisation, the closure scaling laws, an oracle whose bar
  must be derived, any row whose acceptance criterion cannot be written before the
  work). Fable or Opus. Also every plan row and every review.

**Row discipline.** A row carries: `design` (the plan section it implements, by
heading), `acceptance` (the named oracles, identities or lints that must pass, fixed
before work starts), `labels` (`kind:*`, `tier:*`, `area:*`), a file boundary in the
description (paths the executor may create or edit; touching another path is a
refusal, not a judgement call), and `deps` on the rows it needs merged first. An
executor works its row to *completed* or *blocked*, files follow-on rows for what it
finds rather than widening its own, and reports which oracles it ran and their
verdicts. A blocked row names what would unblock it.

**Merge gate.** A row's branch merges only when its acceptance oracles pass in the
worktree, the per-commit gate passes, the commit carries an `answers:` line if the
reference hash moved (decision 0029), and a frontier review has read the diff against
the plan. Reviews are cheap next to plans; they are never skipped for `tier:local` rows,
whose failure mode is confident wrongness.

**Worktrees.** One per implementation row, created and removed through `bd worktree`
so every worktree shares the one tracker. Payload directories (`references/`,
`oracles/data`, `inputs/data`, `store/`) are never duplicated: a worktree reads them
from the main checkout by absolute path, and the write-door rule from the predecessor
applies (a worktree does not regenerate a linked artifact).

## Alternatives considered

- *One agent, one milestone at a time.* Rejected: serialises work that is independent
  by construction, and puts mechanical rows on the most expensive executor.
- *Tier by importance rather than by shape.* Rejected: importance is what the plan and
  the review carry; a row's executor is decided by whether its acceptance can be written
  in advance and whether a judgement is needed inside it.
- *Plans as tracker fields only, no document.* Rejected: a plan is read by several
  executors and by the reviewer, must cite decision and requirement records by path,
  and outlives its rows; it belongs in `docs/plans/` under version control.

## Consequences

- `docs/plans/` is added; every plan document opens with TOML front matter naming its
  epic, the decisions and requirements it implements, and the oracle set.
- Labels are a closed vocabulary: `kind:plan|impl|verify|review`,
  `tier:local|sonnet|frontier`, `area:<module>`. `bd label list-all` is the check.
- M0's nine areas are decomposed now (decisions 0005 to 0014 are detailed enough);
  M1 to M11 open with a plan row each and are decomposed by their planners.
- `docs/practice.md` gains a "Working the board" section; the executor loop is written
  there once, for every tier.

## References

- Decisions 0029 (`answers:` discipline), 0034 (gates), 0027 (reference paths and
  mutation run); predecessor working agreement "a delegated agent works the rows it
  files", `/home/cfutro/docs/world/docs/src/practice/working-agreements.md`.

## Amendments

- 2026-09-10: the closed label vocabulary gains a fourth namespace,
  `milestone:m-1|m0|...|m4b|...|m11`, naming the milestone of decision 0034 a row is
  wanted by. It is carried by survey and reading rows, which are timed to a milestone
  without belonging to its epic; rows that sit under a milestone epic take their
  milestone from the parent and do not repeat it.
