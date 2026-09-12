# CLAUDE.md (AGENTS.md is a symlink to this file)

Fiddlybits is a generic exoplanet-building simulation system written from scratch in
Julia: one process, one icosahedral mesh hierarchy, GPU-first with a CPU fallback. No
specific planet or star is its subject. The predecessor project at
`/home/cfutro/docs/world` is an archive of findings consulted by absolute path, never
copied. The package is `Fiddlybits`: one top-level module over the submodules
`docs/plans/fiddlybits-52v.1-skeleton.md` names, each filled by its own area row.

**This file is a map: identity, pointers, and the rules that bite. Nothing else.**
Arguments live in `docs/practice.md` and `docs/decisions/`; findings in
`notes/findings/`; tasks in `bd`.

| Read this | For |
| --- | --- |
| `README.md` | what this is and the founding principles |
| `docs/decisions/` | every design decision, with alternatives and consequences |
| `docs/requirements/` | what the system must do, carried on merit, with what enforces it |
| `docs/references/INDEX.md` | primary sources and whether each has been READ |
| `docs/practice.md` | how a session conducts itself |
| `docs/failure-modes.md` | how this kind of project goes wrong, and the prevention here |
| `docs/oracles/` | the three oracle tiers and the threshold registry |
| `docs/inputs/` | manifests of the datasets the model reads, kept apart from the oracle datasets |
| `docs/workflow.md` | HOW WORK MOVES: the three layers, the tiers, the executor loop with commands, the planner's and reviewer's checklists. Read before touching `bd` |
| `docs/plans/` | plan documents, one per plan row; the brief every implementation row is worked from |
| `docs/imports/` | what each dependency carries and how a leak is caught |
| `~/.claude/CLAUDE.md` | resource scheduling: heavy work goes through `qrun` |

## The rules that bite

- No specific planet or star is the subject; a configuration declares the system.
- Every constant carries one of five dispositions: Sourced, Derived, Bracketed,
  Irreducible, Closure. Tuned does not exist.
- Earth is a comparison to report the distance from, never a target to solve onto.
- Conventions travel by name, never by coordinate; there are no translation layers.
- No silent default across a component boundary; check at the point of reading.
- One definition per quantity, with as many doors as needed; never two definitions.
- A test needs a right answer: an identity, a conservation law, or a known quantity.
- Physics is not a knob: a process is in the model because it exists.
- A check that cannot fail is not a check; every oracle has a positive control.
- No current values in prose; no effort estimates anywhere; ASCII punctuation.
- A comment says what the code does, never why it is right (decision 0039). Arguments go
  to `docs/decisions/`, measurements and dates to `notes/findings/`; a comment may name
  one by path and never summarise it.
- TOML for every configuration, manifest, registry and record header; never YAML or JSON for anything a person edits.
- Findings, decisions and tasks are kept apart: `notes/findings/`, `docs/decisions/`, `bd`.
- A filing is not an end state: a finding, a row or a proposal is on the way to the change
  it calls for; when the context to make the change is in hand, make it.
- A row is worked to completion (decision 0048): work a row's own work turns up is that
  row's work and is finished inside it. A new row only for what crosses the file
  boundary, is a different question, must merge first, or would put a second substantial
  piece of work under one review; name which. Filing is not progress.
- Work is invisible until it is a bead: anything not finished in the session that named it
  is filed as a row, labelled from the closed vocabulary, given its boundary and
  acceptance, and linked to what it depends on and what it blocks. A decision, a finding
  or a note that calls for work names the row that carries it, and the row names it back.
- Every law, scheme and constant is anchored to a READ primary source with a
  locator; open-access papers and datasets are fetched directly, and only paywalled
  ones are requested from the user by verbatim title and identifier.
- Do not use the AskUserQuestion tool with this user; raise decisions in prose with
  description, options, pros and cons, and expect a conversation.
- Heavy work goes through `qrun`, never directly; see `~/.claude/CLAUDE.md`.
- Anything crossing two resources is concurrent from its first version (decision 0038):
  stages sized to their own resource, a pool between them rather than a barrier, the
  queue bounded in bytes. A file, a level or a batch is never the unit of waiting.
  Arrival order never reaches a result; reductions stay partition-independent (0029).
- Work is tiered (decision 0037): plan rows are frontier work; implementation rows carry
  `tier:local|sonnet|frontier`, a file boundary and named acceptance oracles, and run in
  their own worktree; every merge is reviewed against the plan.

## Vocabulary

- **system**: the declared stars, planet, moons and inventories; the only free inputs.
- **profile**: a named set of levels, ladders, cadences, precision and brackets a run uses.
- **level**: one refinement depth of the icosahedral hierarchy; a component runs at one.
- **tile**: a sub-grid unit of a column carrying its own state (elevation band, lake, island).
- **connectivity graph**: the derived record of which cells actually connect, and how.
- **ledger**: a conserved-quantity balance closed at every exchange, with what it lost.
- **disposition**: the recorded origin of a constant; one of the five.
- **oracle tier**: identity and analytic, then Earth as distance, then published spreads.
- **verdict**: Converged, Bracketed, Refused or NotEvaluable for loops; FAIL, REPORT, PASS for oracles.
- **closure**: a coefficient standing for truncated sub-grid variance; scales with spacing.
- **reference path**: the naive serial version of every optimised kernel; never deleted.
- **finding**: a dated measurement with its evidence, in `notes/findings/`.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:6cd5cc61 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->

Codex sessions: the same `bd` workflow applies; the beads skill is at `.agents/skills/beads/SKILL.md` (or `~/.agents/skills/beads/SKILL.md`), and Codex 0.129.0+ loads Beads context through its native hooks.
