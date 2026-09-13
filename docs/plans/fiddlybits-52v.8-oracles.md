+++
epic = "fiddlybits-52v.8"
title = "The registry loader, the registration rule as a build check, the identity oracles, and the mutation run"
decisions = ["0025", "0026", "0027", "0034", "0036", "0042"]
requirements = ["REQ-TER-004", "REQ-NUM-008", "REQ-SYS-103"]
oracles = ["oracles.registration_rule", "oracles.registry_wellformed", "oracles.dataset_links", "repro.mutation_run"]
status = "filed"
date = 2026-09-10
+++

## Scope

This plan builds the machinery every other oracle runs through: the loader that reads
`docs/oracles/registry.toml`, the build check that enforces the registration rule, the
runner that turns an identity into a verdict, and the mutation run that proves the
suite can fail.

It does not write the identity oracles of the other areas. Each area's plan names its
own and its rows implement them, which is deliberate: an oracle written by someone
other than the person who built the thing it judges tends to check what is easy rather
than what is load bearing. What this plan owns is the frame they hang in, and the two
checks on the frame itself.

The Earth derived-quantity oracle that this area's row 52v.8.5 carried is already the
system plan's `system.derived_fields_reproduce`, which runs on all five M0 instances
rather than on Earth alone. That row is re-pointed rather than duplicated: two
oracles for one question is the thing REQ-SYS-103 forbids.

## Module boundaries

| path | holds | row |
| --- | --- | --- |
| `src/Oracles/registry.jl` | the loader, the entry type, the registration rule | 52v.8.2 |
| `src/Oracles/run.jl` | the runner, the verdict report, the `oracle` event through `Events.emit` | 52v.8.3 |
| `src/Oracles/mutate.jl` | the named mutation list and the harness that applies it | 52v.8.4 |
| `test/oracles/` | `oracles.registry_wellformed` in `wellformed.jl` with its fixtures, the loader suite, the registration-rule fixtures, the mutation suite | fiddlybits-dvk, 52v.8.2 to 52v.8.4 |
| `test/datasets/` | the link between each entry's `datasets` and each manifest's `oracles`, both directions, with its fixtures | fiddlybits-3vq |

`Oracles` sits in group G and may reference anything below it. It is the one module
that reads the registry, so a threshold has one reader as well as one declaration.

## Types and functions

### The loader

```
Entry     id, tier, subsystem, dataset_or_reference, statistic, verdict_kind,
          threshold, provisional, registered_at, holdout, anchors,
          instances (tier 1 system.*), protocol (tier 3; optional on tier 1),
          datasets (tier 2 and tier 3; optional on tier 1)
Protocol  id, system, normalisation
load(path)              every entry and protocol, refusing a malformed one rather than skipping it
entry(id)               one, refusing an unknown id
```

The loader refuses rather than skips. An entry that does not parse is not a
mis-typed row to be ignored; it is a threshold nobody is checking, and skipping it
would be a check that cannot fail.

`instances` and `protocol` are optional in the schema and conditional in the rule:
every tier-1 `system.*` entry must name its instances, every tier-3 entry must name
its protocol, and no tier-2 entry may name one.

The verdict shape of decision 0053 is decided in `test/oracles/wellformed.jl`, which is
`oracles.registry_wellformed`'s one implementation: one `verdict_kind` from `fail_bar`
and `report` per entry, no verdict named in a statistic or threshold, the protocol
conditions above, and every protocol declared once and named by an entry. The loader
carries `verdict_kind` and `protocol` on `Entry`, resolves a protocol id to its
`Protocol`, and does not decide the shape a second time. The remaining clauses of the
oracle (required fields, `source_kind`, `instances`, anchors) join the same file beside
their fixtures, so the oracle is not implemented twice.

`datasets` names the hashed manifests an entry reads, by manifest id. The loader
carries it on `Entry`; whether each id resolves, and whether the manifest names the
entry back, is `oracles.dataset_links` in `test/datasets/harness.jl`, and the loader
does not decide it a second time. The runner reads the manifest through that id when it
checks a payload's hashes and keys an artifact on it.

### The registration rule as a build check

Decision 0025 states the rule and this is where it bites:

- A threshold is fixed and committed before the first artifact it judges exists, and
  `registered_at` records that commit.
- **A registry edit may not share a commit with a result it judges.** The check reads
  git: if a commit touches `docs/oracles/registry.toml` and also touches a path that
  produces a result the edited entries judge, it fails.
- A bar narrower than the observation's own uncertainty is refused at registration.
- Every entry names its source kind and its anchors in `docs/references/INDEX.md`,
  and an anchor that is not `read` there is refused for a `Sourced` bar.
- An entry that is `provisional = true` with an empty `registered_at` may run and
  report, and may not FAIL a milestone gate.

That last clause matters right now: every entry in the tree is provisional, so the
rule has to say what a provisional entry can and cannot do rather than treating the
skeleton as a violation of itself.

Two of these are stated precisely enough to be checked only after the plan review,
and the precision is the point. **The co-commit rule reads the `threshold` and
`registered_at` fields of registered entries**: a commit that changes either on an
entry whose `registered_at` is set, and also touches `src/` or `notes/findings/`,
fails. A provisional entry is exempt, because the rule bites at registration and
not before; the commit that merged the Kepler solve changed a provisional entry's
sampling clause beside the code it judges, and that is allowed. Without that
precision the rule would need a map from entry to result path that nothing keeps.

**The anchors rule reads the registry as it is, not as the README describes it.**
The README says every entry names a closed source kind and its anchors; the registry
has `dataset_or_reference` as free text conflating the kind with a description, and
47 tier-2 and tier-3 entries, every one a published bar, carry `anchors = []`. So
`oracles.registry_wellformed` requires anchors on every tier-2 and tier-3 entry and
a `source_kind` from the closed set on every entry, and it fails on the tree today.
That is filed as `fiddlybits-52v.8.7` rather than papered over by a rule loose
enough to pass: a published bar with no anchored source is exactly what registration
exists to refuse.

### The runner

```
run(entry, artifact)    -> OracleVerdict from Verdicts, never a boolean
report(results)         the distance report: value, reference, its uncertainty,
                        the distance in units of that uncertainty, the verdict
```

A verdict is `FAIL`, `REPORT` or `PASS` and never a boolean, so a metric with no bar
that is not a preference records its distance and says `REPORT` rather than silently
passing. Every result is emitted to the run journal as an `oracle` event carrying the
registry id, the verdict, the statistic and the threshold, through `Events.emit`,
which is the one front door (`fiddlybits-52v.6.8`).

Every Earth metric is scored on pattern as well as on a global mean, because a model
whose global mean is right by compensation does not carry to another rotation,
gravity or star. The runner therefore takes a pattern statistic beside the scalar one
and a tier-2 entry with only a global mean is refused at load.

### The mutation run

A named list of deliberate breaks beside the suite: a physical constant perturbed by
one percent, a Coriolis term dropped, a flux counted twice, a sign reversed in one
ledger, a stencil shifted by one cell, a reduction made partition-dependent, a
sentinel introduced at a boundary. The suite runs against each mutated build and every
mutation must be caught by at least one oracle.

A mutation nothing catches is a hole in the suite. It files a row, and **the suite may
not be reported green until the hole is closed or the mutation is recorded as out of
scope with its reason.** That last clause is what stops the mutation run from becoming
a report nobody acts on.

The mutation list is TOML beside the suite, one entry per mutation naming the break,
the file it is applied to and the oracle expected to catch it. An expectation that
turns out wrong is information: a mutation caught by a different oracle than the one
named is recorded, not silently accepted.

## Oracles

Three entries are added for the frame itself, plus `repro.mutation_run` which exists.

| id | right answer | the mutation that must make it fail |
| --- | --- | --- |
| `oracles.registry_wellformed` | every entry parses, carries every required field including a closed `source_kind`, satisfies its conditional fields, has anchors if it is tier 2 or 3, and every anchor resolves in the references index; every entry carries one verdict semantics and names no verdict in prose, and every protocol is declared once and named (decision 0053) | a row with a missing `threshold`, a tier-1 `system.*` row with no `instances`, and a tier-2 row with empty anchors, all of which must be refused rather than skipped; a row mixing an exact identity and a report under one bar, which must be refused, with one fixture for each remaining verdict-shape clause and a clean fixture that must be accepted |
| `oracles.registration_rule` | no commit changes a registered entry's `threshold` or `registered_at` and also touches `src/` or `notes/findings/`; no bar is narrower than its observation's uncertainty | a fixture commit doing both on a registered entry, which must fail, and the same commit on a provisional entry, which must pass; a fixture bar set below a stated observational uncertainty, which must be refused |
| `oracles.dataset_links` | every manifest id in an entry's `datasets` resolves to a manifest that names the entry back in `oracles`; every entry a manifest names exists and names the manifest back; every tier-2 and tier-3 entry carries `datasets`; every oracle manifest names an entry; no manifest anchor carries an oracle id | a fixture row naming an absent manifest and a fixture manifest naming an absent oracle, both refused, with one fixture for each remaining clause and a clean fixture that must pass |
| `repro.mutation_run` | every mutation in the list is caught by at least one oracle | the list itself is the control; a mutation nothing catches files a row and the suite is not green |

`oracles.registry_wellformed` runs today against the registry as it stands and fails
on it, by design, until `fiddlybits-52v.8.7` anchors the published bars. That is
worth stating: the skeleton has grown from its founding rows to the entries these M0
plans added, nothing has checked them beyond a person running a parser, and the
first real check finding 47 published bars with no source is the check working.

## Rows filed

| row | tier | boundary | acceptance |
| --- | --- | --- | --- |
| fiddlybits-dvk | frontier | `docs/decisions/`, `docs/oracles/registry.toml`, `docs/oracles/README.md`, `docs/oracles/data/`, this plan, `test/oracles/wellformed.jl`, `test/oracles/runtests.jl`, `test/oracles/fixtures/` | decision 0053 settles the shape; no row carries constituents with different verdicts under one `verdict_kind`; `oracles.registry_wellformed`'s verdict-shape clauses pass on the tree with the mixed-bar fixture and every other control refused |
| 52v.8.2 | sonnet | `src/Oracles/registry.jl`, `test/oracles/registry.jl`, `test/oracles/wellformed.jl` | `oracles.registry_wellformed` and `oracles.registration_rule` run with every control firing; the loader refuses a malformed entry rather than skipping it; the tree's own wellformed verdict is recorded, FAIL until 52v.8.7 merges |
| 52v.8.7 | local | `docs/oracles/registry.toml`, `docs/oracles/README.md`, `docs/references/INDEX.md` | every entry carries `source_kind`; no tier-2 or tier-3 entry has empty anchors; every anchor resolves by verbatim title; `oracles.registry_wellformed` passes on the tree |
| 52v.8.3 | sonnet | `src/Oracles/run.jl`, `test/oracles/run.jl` | a verdict is one of the three and never a boolean; every result is emitted as an `oracle` journal event through the one emitter; a tier-2 entry with only a global mean is refused at load |
| 52v.8.4 | frontier | `src/Oracles/mutate.jl`, `test/oracles/mutate.jl` | `repro.mutation_run` runs the whole list; a mutation nothing catches files a row and the suite is not reported green |
| 52v.8.5 | sonnet | none; re-pointed | the M0 Earth derived-quantity question is `system.derived_fields_reproduce`, carried by `fiddlybits-52v.4.5` on all five instances; this row closes as superseded rather than writing a second oracle for it |
| fiddlybits-3vq | frontier | `docs/oracles/registry.toml`, `docs/oracles/README.md`, `docs/oracles/data/`, `docs/inputs/`, `docs/references/INDEX.md`, this plan, `test/datasets/` | every tier-2 and tier-3 entry carries `datasets`; every link resolves in both directions; `earth.sea_ice_extent_cycle` corrected; `oracles.dataset_links` passes on the tree with every control refused |
| 52v.8.6 | sonnet | none; reports only | all four oracles ran; verdicts by name |

52v.8.3 and 52v.8.4 depend on 52v.8.2; 52v.8.3 depends on `fiddlybits-52v.6.8`; the
verify row depends on 52v.8.7. The mutation row depends on every other area's
verify row, because a mutation run over a suite that does not yet exist measures
nothing.
