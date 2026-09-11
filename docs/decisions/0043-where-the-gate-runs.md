+++
id = "0043"
title = "The gate runs on the machine that holds the data and the card; a hosted job runs only the clean-room subset"
status = "accepted"
date = 2026-09-10
+++

## Decision

The per-commit gate runs on this machine, through the scheduler, and never on a hosted
runner. A hosted job runs on push and answers one question a local gate structurally
cannot: whether the tracked tree builds and passes from a clean checkout with nothing
of this machine around it.

### Why the gate cannot leave this machine

Two reasons, and the second is the larger one.

- **The device.** The backend oracles of decision 0011 and the ulp-ensemble
  certification of decision 0029 need the card. A hosted runner has none.
- **The data.** The oracle datasets and the input datasets are tens of gigabytes and
  are deliberately untracked; `docs/oracles/data/` and `docs/inputs/data/` hold their
  manifests and hashes, not their bytes. Every tier-2 and tier-3 oracle reads them. No
  hosted runner is going to fetch that per run, so the Earth distance report and the
  published-spread sweeps are off a hosted machine permanently rather than until
  someone attaches a card.

Benchmarks settle it in the same direction from a third angle: decision 0029 keys them
by hardware and requires the A/A scatter of the bed measured before any bar applies. A
number from a runner of unknown provenance cannot join that series.

### What runs where

| where | when | what |
| --- | --- | --- |
| the executor's own shell | before each commit, per the loop in `docs/workflow.md` | the whole suite; this is the per-commit gate of decision 0029 |
| `commit-msg` and `pre-commit` hooks | every commit touching code | the reference hash against its record, the `answers:` rule, the lint suite |
| `pre-push` hook | every push | the whole suite including the device arm, through the scheduler |
| a hosted job | every push | a clean checkout: the package resolves, loads, and passes the device-free suite |
| this machine, nightly | nightly | thread-count bitwise, the backend envelope, whatever is too slow per commit |
| this machine, weekly | weekly | the mutation run of decision 0027 |

Device oracles run per commit while they are cheap and move to the nightly row when
they are not. The trigger is the measured cost of the bed, not a guess made now: the
suite's warm cost and the load measurement are recorded beside every run, and
`build.load_latency` already carries the host and the load with its number.

### The hooks are a backstop, not the gate

A hook can be skipped, and saying otherwise would be the kind of claim this project
does not make. The gate is the executor running the suite before the commit, which the
reviewer's checklist verifies by reading the row's notes. The hooks catch the case
where that did not happen, and the hosted job catches, on the push it was skipped for,
the part a clean machine can see. Three overlapping checks, none of them claimed to be
airtight.

Hooks attach as marked blocks in `.beads/hooks/`, which is where `core.hooksPath`
points and where the records block of decision 0040 already lives. A block is gated on
a staged-path pattern so a documents-only commit pays nothing.

### The reference hash and the `answers:` rule

Decision 0029 requires a short coupled case per commit whose final state hash is a
tracked reference, and refuses a commit that moves the hash without a
`answers: <mechanism>` line and a reference updated in the same commit.

That case does not exist until M3, so the mechanism is built now against the most
answer-bearing deterministic artifact the tree has, and the case behind it is named in
`bench/reference.toml` rather than assumed. When the coupled case exists it replaces
the case in that file and nothing else changes. Building the mechanism against a
stand-in is the point: a rule that arrives with the artifact it governs has never been
shown to fire.

The check refuses two different things and names which: a reference that disagrees with
what the code produces, which is a stale record, and a moved reference with no
mechanism line, which is the fitting signature decision 0025 exists to catch.

## Alternatives considered

- **A hosted runner carrying the whole gate.** Lost to the data and the device, above.
- **A self-hosted runner on this machine, listening for jobs.** It could run everything
  the local gate runs, and it would add a long-lived daemon to a machine whose
  resources are centrally arbitrated, for no gain over running the same command from
  the shell that made the commit. Rejected on the ratio, not on principle; if the work
  ever spreads to a second machine or a second person, this is the first thing to
  revisit.
- **No hosted job at all.** Cheapest, and it gives up the only question a hosted
  machine answers better: whether the tree stands up without this machine's home
  directory around it. That question is exactly what the import harness and the
  manifest check were built to decide, so giving it up would waste them.
- **The gate as a pre-commit hook running the whole suite.** Rejected as the primary
  mechanism because it makes every commit pay the device arm, and because it reads as
  airtight while remaining skippable. Kept for the cheap half.

## Consequences

- A push that fails the hosted job is a red mark on a commit already on this machine's
  main branch, not a blocked merge. That is the cost of batching pushes and it is
  accepted.
- The hosted job's value decays as more of the suite needs the data; it is scoped to
  the tracked tree on purpose, and a check that starts needing a dataset moves to the
  local gate rather than the dataset moving to the runner.
- `oracles.registration_rule` reads git history and therefore runs where the history
  is, which is both places.

## References

- Decision 0029 (the per-commit case, the `answers:` rule, benchmarks keyed by
  hardware), decision 0025 (tier 1 per commit where cheap, nightly otherwise),
  decision 0011 (the device), decision 0027 (the mutation run), decision 0040 (the
  records block these hooks sit beside).
- The scheduler this machine arbitrates through: `~/.claude/CLAUDE.md`.
