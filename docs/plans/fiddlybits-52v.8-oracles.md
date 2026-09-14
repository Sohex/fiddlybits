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
| `test/oracles/` | `oracles.registry_wellformed` in `wellformed.jl` with its fixtures, the loader suite, the registration-rule fixtures, the mutation suite | fiddlybits-dvk, fiddlybits-w7p, 52v.8.2 to 52v.8.4 |
| `test/datasets/` | the link between each entry's `datasets` and each manifest's `oracles`, both directions, with its fixtures | fiddlybits-3vq |

`Oracles` sits in group G and may reference anything below it. It is the one module
that reads the registry, so a threshold has one reader as well as one declaration.

## Types and functions

### The loader

```
Entry     id, tier, subsystem, dataset_or_reference, statistic, verdict_kind,
          threshold, provisional, registered_at, holdout, anchors,
          instances (tier 1 system.*), protocol (tier 3; optional on tier 1),
          datasets (tier 2 and tier 3; optional on tier 1),
          depends_on (optional on every tier)
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

`depends_on` names the rows a row rests on (decision 0054). The same file decides its
shape: every id resolves to a row on the depending row's tier or a lower one, no row
depends on itself, no statistic or threshold names a row id, and no statistic or
threshold carries a clause of the threshold of a `fail_bar` row it depends on. The loader
carries `depends_on` on `Entry` and resolves each id to its `Entry`; the runner reports
each dependency's verdict beside the depending row's and changes neither.

`datasets` names the hashed manifests an entry reads, by manifest id. The loader
carries it on `Entry`; whether each id resolves, and whether the manifest names the
entry back, is `oracles.dataset_links` in `test/datasets/harness.jl`, and the loader
does not decide it a second time. The runner reads the manifest through that id when it
checks a payload's hashes and keys an artifact on it.

### The registration rule as a build check

Decision 0025 (amendment of 2026-09-13) states the rule and `docs/oracles/README.md`,
Registration, states its clauses; this is where it bites:

- **A bar is fixed before the value it judges has been seen.** That value is the
  entry's statistic evaluated on a model result: the output of code under `src/` on a
  declared `System`, from any run, store or test. A fixture a test constructs with its
  answer known, and a positive control's named break, are not model results.
- `registered(entry)` holds when `registered_at` names a commit at which the entry's
  `statistic`, `verdict_kind`, `threshold` and `holdout` equal the loaded ones, read
  with git. An entry with an empty `registered_at`, or one that differs from that
  commit, is unregistered.
- `Fixture` is a type in `src/Oracles/registry.jl` that only `test/` constructs; the
  check parses `src/` and refuses a construction there.
- `admits(entry, x, use)` is the admission predicate the runner's door calls. `use` is
  the statistic's value (with any distance, verdict or threshold comparison), whether
  the statistic evaluates, or the difference between two arms of one configuration. An
  unregistered entry admits its value only on a `Fixture`, and admits evaluability and
  the arm difference on a model result as well; a registered entry admits all three on
  either. This holds for a `report` entry as for a `fail_bar` one.
- The git check reads history from the commit carrying the amendment. It refuses a
  tier-2 or tier-3 entry registered again with its `anchors` and `datasets` unchanged,
  or in a commit touching `src/` or `notes/findings/`; an entry registered once as
  `report` and later as `fail_bar`; and a merge whose branch, diffed against its first
  parent, changes an entry's threshold together with `src/` or a file holding the
  testset named by that entry.
- A bar narrower than the observation's own uncertainty is refused at registration.
- Every entry names its source kind and its anchors in `docs/references/INDEX.md`,
  and an anchor that is not `read` there is refused for a `Sourced` bar.
- A provisional entry blocks no milestone gate.

Every entry in the tree is provisional and unregistered, so the rule says what such an
entry may execute (fixtures and positive controls; on a model result, evaluability and
the arm difference) rather than treating the skeleton as a violation of itself. A
tier-1 identity's door is the testset named by its id, which judges the implementation
on every commit whether or not the entry is registered.

The git check keeps no map from an entry to the paths that produce its result: a
tier-2 or tier-3 registration is refused beside any change under `src/` or
`notes/findings/`, and a tier-1 entry reaches its testset through its id.

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

`run` calls `admits(entry, artifact, use)` at its door, with the use it serves, before
it evaluates the statistic, and raises when `admits` refuses, so a refused call
returns, emits and reports nothing. An unregistered entry handed a model result is
refused its value, and the same entry handed a `Fixture` is admitted (The registration
rule as a build check).

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
| `oracles.registry_wellformed` | every entry parses, carries every required field including a closed `source_kind`, satisfies its conditional fields, has anchors if it is tier 2 or 3, and every anchor resolves in the references index; every entry carries one verdict semantics and names no verdict in prose, and every protocol is declared once and named (decision 0053); every `depends_on` id resolves to a row on the same tier or a lower one without a cycle, no row id is named in prose, and no row carries a clause of a dependency's threshold (decision 0054) | a row with a missing `threshold`, a tier-1 `system.*` row with no `instances`, and a tier-2 row with empty anchors, all of which must be refused rather than skipped; a row mixing an exact identity and a report under one bar, which must be refused; a row depending on an absent row and a row restating a dependency's threshold, both of which must be refused; one fixture for each remaining verdict-shape and dependency clause, and a clean fixture that must be accepted |
| `oracles.registration_rule` | a bar is fixed before the value it judges has been seen: `admits` refuses an unregistered entry's value on a model result; an entry counted registered is what its `registered_at` commit holds; no re-registration, `report` to `fail_bar` change, merge or `Fixture` construction the clauses of The registration rule as a build check refuse; no bar is narrower than its observation's uncertainty | `admits` handed an unregistered fixture entry and a model result, which must refuse the value, and the same entry and a `Fixture`, which must admit it; one fixture for each remaining clause, each with the accepted twin its clause names; a fixture bar set below a stated observational uncertainty, which must be refused |
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
| fiddlybits-w7p | frontier | `docs/oracles/registry.toml`, `docs/oracles/README.md`, `docs/decisions/`, this plan, `test/oracles/wellformed.jl`, `test/oracles/runtests.jl`, `test/oracles/fixtures/` | `sweep.obliquity` names `system.orbit_mean_insolation` in `depends_on` and states no threshold for it; every `depends_on` id resolves; no row restates the threshold of a row it depends on; the absent-dependency and restated-threshold fixtures are refused |
| 52v.8.2 | sonnet | `src/Oracles/registry.jl`, `test/oracles/registry.jl`, `test/oracles/wellformed.jl` | `oracles.registry_wellformed` and `oracles.registration_rule` run with every control firing; the loader refuses a malformed entry rather than skipping it; the tree's own wellformed verdict is recorded, FAIL until 52v.8.7 merges |
| 52v.8.7 | local | `docs/oracles/registry.toml`, `docs/oracles/README.md`, `docs/references/INDEX.md` | every entry carries `source_kind`; no tier-2 or tier-3 entry has empty anchors; every anchor resolves by verbatim title; `oracles.registry_wellformed` passes on the tree |
| 52v.8.3 | sonnet | `src/Oracles/run.jl`, `test/oracles/run.jl` | a verdict is one of the three and never a boolean; `run` calls `admits` at its door: an unregistered fixture entry handed a model result is refused its value and emits nothing, and the same entry handed a `Fixture` returns its verdict; every admitted result is emitted as an `oracle` journal event through the one emitter; a tier-2 entry with only a global mean is refused at load |
| 52v.8.4 | frontier | `src/Oracles/mutate.jl`, `test/oracles/mutate.jl` | `repro.mutation_run` runs the whole list; a mutation nothing catches files a row and the suite is not reported green |
| 52v.8.5 | sonnet | none; re-pointed | the M0 Earth derived-quantity question is `system.derived_fields_reproduce`, carried by `fiddlybits-52v.4.5` on all five instances; this row closes as superseded rather than writing a second oracle for it |
| fiddlybits-3vq | frontier | `docs/oracles/registry.toml`, `docs/oracles/README.md`, `docs/oracles/data/`, `docs/inputs/`, `docs/references/INDEX.md`, this plan, `test/datasets/` | every tier-2 and tier-3 entry carries `datasets`; every link resolves in both directions; `earth.sea_ice_extent_cycle` corrected; `oracles.dataset_links` passes on the tree with every control refused |
| 52v.8.6 | sonnet | none; reports only | all four oracles ran; verdicts by name |

52v.8.3 and 52v.8.4 depend on 52v.8.2; 52v.8.3 depends on `fiddlybits-52v.6.8`; the
verify row depends on 52v.8.7. The mutation row depends on every other area's
verify row, because a mutation run over a suite that does not yet exist measures
nothing.
