# Oracles

The predecessor found almost every defect late, by comparing two things that were
supposed to agree. A rewrite has no upstream implementation to compare against, so
this system earns trust from three oracle tiers, trusted in this order, and from a
reference path beside every optimised kernel.

## The three tiers

1. **Identity and analytic.** Exact answers: conservation ledgers, mesh identities,
   manufactured solutions with a designed convergence order, the standard
   dynamical-core test cases, closed-form column and process solutions, blackbody
   and photon-currency identities, line-by-line radiation references. Failure means
   the implementation is wrong. These run per commit where cheap, nightly otherwise.
2. **Earth as a distance.** An Earth instance is one constructor call on the same
   parameter set every other configuration uses. The suite produces a *distance
   report*, never an objective function. Every metric is scored on pattern (zonal
   structure, seasonal amplitude, land/ocean contrast), not only its global mean.
3. **Published spreads in the non-Earth direction.** Aquaplanet, rotation,
   obliquity, gravity and stellar-type sweeps that have published multi-model
   results; the inter-model spread is the bar. Landing inside a spread is evidence
   of being indistinguishable from published models, which is the most this tier
   can say, and every report says so in its header.

## Verdicts

Fixed per metric, in advance. A registry entry is one metric: it carries one
`verdict_kind`, and its statistic carries every constituent that verdict judges and no
other. A constituent judged differently is an entry of its own (decision 0053).

- `fail_bar`: the threshold states a bar; inside it the verdict is PASS, outside it FAIL.
- `report`: there is no bar; the verdict is REPORT, and the threshold says why.

The verdict is named by `verdict_kind` alone. A statistic or threshold names no verdict
in capitals; those of a `fail_bar` entry do not call a constituent a report, give it no
bar or mark it n/a; those of a `report` entry do not give a constituent a failing or
passing edge. `oracles.registry_wellformed` refuses each (`test/oracles/`).

A bar applies where its entry says and nowhere else: a tier-2 bar to a run of `Earth()`;
the bar of an entry naming a protocol to a run of that protocol's system with its
normalisation held and no field changed but the one the entry's statistic names as
swept; and within that, only under any condition its threshold states. The same
statistic from any other run is REPORT by this rule, and no threshold restates it.

| verdict | meaning | consequence |
| --- | --- | --- |
| FAIL | outside a bar set from a published model's own residual, or a physical constraint | a defect; blocks the milestone |
| REPORT | no bar exists that is not a preference; the distance is recorded | none; the number is a property of the model |
| PASS | inside the bar | recorded; evidence of indistinguishability, not correctness |

A bar narrower than the observation's own uncertainty is refused by the registry
check. Where no published model of comparable class has a residual to quote, the
metric is REPORT.

## Registration

- A threshold is fixed and committed before the first artifact it judges exists;
  `registered_at` records that commit. A registry edit may not share a commit with
  a result it judges.
- Every entry names its source kind (identity, conservation, analytic, known
  quantity, published spread) and its anchors in `docs/references/INDEX.md`.
- Every entry in `registry.toml` is `provisional = true` with an empty
  `registered_at` until the milestone that registers it. Nothing in this skeleton
  has been registered. A provisional entry runs and records its verdict, and no
  verdict of it blocks a milestone gate.
- Statistics and thresholds are stated in SI seconds and in dimensionless or
  system-derived units. A published case's "day" is written as its seconds on the
  arm where the published bar applies, and the entry states the rule by which the
  spread arms scale; a coupled-loop exit is a dimensionless bracket (decision 0023)
  and an absolute tolerance is refused at registration. Vertical diagnostics are
  stated in sigma (pressure over surface pressure), never in a fixed pressure.
- An entry run on a published protocol names it in `protocol`: every tier-3 entry
  does, a tier-1 entry of a published standard case may, and a tier-2 entry does not,
  since tier 2 runs on `Earth()`. The protocol is declared once, in a `[[protocol]]`
  entry of `registry.toml` carrying its system as `Sourced` constructor calls in
  `system` and what the protocol held fixed in `normalisation`, and every entry run on
  it names that one declaration. Every declared protocol is named by an entry.
- An entry that reads a hashed dataset names its manifest ids in `datasets`, and the
  manifest, under `docs/oracles/data/` or `docs/inputs/data/`, names the entry back in
  its `oracles` key. Every tier-2 and tier-3 entry carries `datasets`, empty where it
  reads no held dataset; every manifest under `docs/oracles/data/` names at least one
  entry; an oracle id is never written in a manifest's `anchors`, which carry the
  requirements, decisions and milestones in prose. `oracles.dataset_links` checks both
  directions (`test/datasets/`).
- An entry that rests on a constituent another entry decides names that entry's id in
  `depends_on`, on its own tier or a lower one, and states no bar for it: the named
  entry is judged by its own threshold, and a report of the depending entry names each
  dependency's verdict beside its own. No statistic or threshold names an entry's id,
  and none carries a clause of the threshold of a `fail_bar` entry it depends on,
  directly or through other entries. `oracles.registry_wellformed` refuses each
  (decision 0054).
- Every tier-1 identity of the system layer (the `system.*` section) runs on
  `Earth()` and on a synthetic non-Earth instance with closed forms, so a `Derived`
  field is never validated on one configuration alone.

## Hold-out

A pre-registered subset of Earth metrics is scored only at milestone gates, never
in the nightly run, so iteration cannot converge on the visible metrics. Hold-out
entries carry `holdout = true`.

## Anti-tuning

- One parameter set, by hash, shared by every configuration; there is no
  Earth-only override of any physics parameter.
- No `Tuned` disposition exists; a constant that moves must change its source or
  derivation in the same commit.
- A moved Earth metric requires an `answers: <mechanism>` line in the commit
  message, in either direction; an improvement without a mechanism is the
  signature of fitting.
- Physics is not a knob: a process is added or removed on the argument that it
  exists, with a decision record.

## The mutation run

A test that has never failed has not been shown able to. Weekly, the oracle suite
is run against a build carrying named deliberate breaks (a constant scaled by one
per cent, a dropped Coriolis term, a flux counted twice, a reversed ledger sign, a
stencil shifted by one). Every mutation must be caught by at least one oracle; one
nothing catches is a hole in the suite and files an issue.

## Reference paths

Every kernel that is optimised or ported to the GPU is written twice: a naive
serial function that is the specification, and the production version. The test
is agreement to a tolerance derived from floating point. The reference path is
never deleted.

## Amendments

- 2026-09-08: statistics in seconds with the spread-arm rule, dimensionless exits, sigma diagnostics, the protocol_system field for tier 3, and the two-instance rule for system.* identities, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-13: one verdict semantics per entry, the two verdict kinds, no verdict named in prose, where a bar applies, the protocol table in place of the protocol_system field, and a provisional entry blocking no gate, from docs/decisions/0053-one-verdict-semantics-per-registry-row.md.
- 2026-09-13: the depends_on field, no entry id named in prose, and no clause of a dependency's threshold restated, from docs/decisions/0054-a-row-names-the-rows-it-rests-on.md.
