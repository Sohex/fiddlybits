+++
id = "0053"
title = "A registry row carries one verdict semantics: a constituent judged differently is a row of its own, a protocol is declared once in its own table and named by id, and no verdict is named in prose"
status = "accepted"
date = 2026-09-13
amends = [{ record = "0025", what = "what a registry entry is and where its protocol lives: one metric under one verdict_kind whose statistic and threshold name no verdict, and a tier-3 entry names a protocol declared once in the registry's protocol table rather than carrying its protocol system itself" }]
+++

## Decision

**A row is one metric under one verdict semantics.** Decision 0025 fixes a verdict per
metric before the run, and the registry fixes one `verdict_kind` per row, so a row is a
metric. A row's statistic carries every constituent its `verdict_kind` judges and no
other. A constituent judged by a different verdict is a row of its own, with its own
statistic, threshold, `verdict_kind`, `datasets` and anchors. Several constituents
judged under one bar of one kind from one source may share a row.

**The verdict kinds are `fail_bar` and `report`.** Under `fail_bar` the threshold states
a bar; inside it the verdict is PASS and outside it FAIL. Under `report` there is no bar,
the verdict is REPORT, and the threshold says why. A band between two edges with a
verdict of its own is not a kind: decision 0025's verdicts are three, and a metric has
one bar.

**No verdict is named in prose.** `verdict_kind` names the verdict. A statistic or
threshold does not name FAIL, PASS or REPORT. The statistic and threshold of a
`fail_bar` row do not call a constituent a report, give it no bar or mark it n/a; those
of a `report` row do not give a constituent a failing or passing edge. This is the prose
half of the shape, and it is decided lexically on that vocabulary.

**Where a bar applies is a rule of the schema, stated once.** A tier-2 bar applies to a
run of `Earth()`. The bar of a row naming a protocol applies to a run of that protocol's
system with the protocol's normalisation held and no field changed but the one the row's
statistic names as swept. A threshold may narrow that by a condition it states. The same
statistic from any other run is REPORT by this rule, and no threshold restates it.

**A protocol is declared once, in a protocol table, and named by id.** `registry.toml`
carries `[[protocol]]` entries, each with an `id`, the protocol's `system` as `Sourced`
constructor calls, and the `normalisation` the protocol held fixed. A row names one in
`protocol`. Every tier-3 row names one; a tier-1 row of a published standard case may;
a tier-2 row does not, because tier 2 runs on `Earth()`. Every declared protocol is
named by at least one row. The row-level `protocol_system` field is withdrawn.

**A constituent that is already another row's question is not copied.** Where a split
constituent is an identity another row already decides, the split makes no new row for
it, because two oracles for one question is the failure one definition per quantity
forbids; the row that rests on it names the other row in its statistic, and
`fiddlybits-w7p` gives that name a field. Where no row decides it, the split makes one,
at the tier its source kind belongs to: an identity found inside a tier-3 row becomes a
tier-1 row.

**The check.** `oracles.registry_wellformed` decides the shape in
`test/oracles/wellformed.jl`: a row id is used once; every row carries a statistic, a
threshold and a `verdict_kind` from the two; the prose rule above; no row carries
`protocol_system`; every tier-3 row names a protocol and no tier-2 row does; every named
protocol is declared, and every declared protocol has an id used once, a system and a
normalisation, and is named. Its positive control is a fixture row mixing an exact
identity and a report under one bar, which must be refused; every other clause has a
fixture of its own, and a clean fixture must be accepted.

## Alternatives considered

- *Submetrics under a row that declares the protocol once*, each with its own source
  kind, statistic, `verdict_kind` and threshold. This was the recommendation the row
  carried. Lost on three counts. Every field that makes a metric a metric is per metric:
  the threshold a result's hash is checked against, `registered_at`, `provisional`,
  `holdout`, and the id and verdict an `oracle` journal event carries. Under submetrics
  each either repeats on every submetric, which makes the row a container of rows under
  another name, or is declared on the row and inherited by its submetrics, which is a
  default crossing a boundary unchecked; a threshold registered at one milestone beside a
  sibling registered at another needs the first. Every reader of the registry would read
  two shapes, a row with submetrics and a row without. And it keeps a protocol single
  only inside one row, while the restatement a protocol invites crosses rows and tiers:
  `HeldSuarez()` serves a tier-1 row and a tier-3 row, and the baroclinic instability
  case serves two tier-1 rows. A protocol declared on a row cannot be named by another; a
  protocol table keeps the declaration single for every row run on it and leaves every
  row one shape.
- *One row per statistic, each tier-3 row carrying its own `protocol_system`.* Lost: rows
  sharing a protocol would each declare it, and the declarations would drift apart, which
  is two definitions of one quantity.
- *Keep the rows and state each constituent's verdict in the threshold*, as the rows did.
  Lost: a runner reads `verdict_kind`, sees one bar, and either fails the constituent that
  has none or passes an identity it never checked.
- *A field per row saying that other configurations are REPORT.* Lost: the rule holds for
  every bar on a protocol and every tier-2 bar, so the field could take one value and
  would decide nothing; a check on it could not fail.
- *Keep `pass_bar` in the vocabulary.* Lost: no row carries it and no record says what it
  means, so a row choosing it would carry a verdict semantics nobody defined. A kind with
  a use is added by the record that defines it.
- *A marginal verdict, or a band between two edges, for `earth.hydrolakes_terminal_lakes`.*
  REQ-HYD-001 carries the predecessor's registration: a passing edge at 0.30, a marginal
  band to 0.60, and a failing edge above it or on an error correlated with a driver. Lost:
  a fourth verdict is what decision 0025 declined when it declined two, and a band is a
  second bar on one metric. The row carries the failing edge and the correlation clause,
  both under `fail_bar`; the 0.30 edge divides two outcomes that are both PASS under three
  verdicts, and it is not carried.
- *Leave the prose half to review.* Lost: the defect stood across rows written and
  reviewed separately. The lexical clause decides what a vocabulary can decide. A second
  semantics phrased without a verdict word, such as a constituent the threshold simply
  omits, passes it and stays review's to catch.

## Consequences

- `docs/oracles/registry.toml` carries the protocol table and no `protocol_system`, and
  every row naming a verdict in prose is rewritten without it. The splits:
  `system.dependency_unread_edges` reports what `system.dependency_subset` had called
  REPORT; `terrain.hypsometry_profile` reports the fractions and depth modes
  `terrain.hypsometry_scale_matched` gave no bar, and the `etopo2022` manifest names both;
  `terrain.endorheic_share_nonzero` is the tier-1 routing identity `terrain.endorheic_share`
  carried; `sweep.rotation_rate_jets_and_contrast` and `core.hadley_small_rossby_limit`
  take the jet count and contrast and the analytic limit out of `sweep.rotation_rate`;
  `physics.gravity_column_identities` takes the column identities out of `sweep.gravity`,
  which reports the circulation response; `sweep.stellar_type_day_night_contrast` and
  `sweep.stellar_type_ice_albedo` take the constituents the THAI bar did not judge out of
  `sweep.stellar_type_aquaplanet`.
- `sweep.obliquity` names `system.orbit_mean_insolation` for the insolation pattern and
  `core.held_suarez` names `ledger.closure` for angular momentum, rather than restating
  their thresholds; `sweep.gravity` and `sweep.rotation_rate` name the tier-1 rows split
  from them. Those names are the edges `fiddlybits-w7p` turns into a field.
- The Jablonowski-Williamson, Held-Suarez and DCMIP small-planet rows name their
  protocols, so the spread-arm rule each carried is the schema's.
- `docs/oracles/README.md` states the kinds, the prose rule, where a bar applies, the
  protocol table, and that a provisional entry blocks no milestone gate, which
  `oracles.registration_rule`'s threshold had carried.
- `docs/plans/fiddlybits-52v.8-oracles.md`: the loader's `Entry` carries `protocol` beside
  a `Protocol` type, and `oracles.registry_wellformed` has one implementation,
  `test/oracles/wellformed.jl`, which `fiddlybits-52v.8.2` extends with its own clauses.
- REQ-HYD-001 records the predecessor's marginal band as what the predecessor registered;
  it describes that registration and is not a threshold here.

## References

- Decision 0025, the verdict table, the tier-3 protocol system and the registration rule
  this record amends.
- `notes/findings/2026-09-08-implicit-earth-audit.md`: the rows on the
  Jablonowski-Williamson and Held-Suarez spread arms, on the tier-3 protocol systems, on
  the tier-2 terrain bars evaluated only under the Earth constructor, and on the
  endorheic share, which put the per-configuration rule into each row's prose.
- `docs/requirements/hyd/lake-equilibrium-earth-oracle.md` (REQ-HYD-001): the terminal-lake
  registration and its correlation refusal.
- `docs/plans/fiddlybits-52v.8-oracles.md`, sections The loader and Oracles, and
  `test/datasets/` (`oracles.dataset_links`): the precedent of a registry check that the
  loader does not decide a second time.
- Decisions 0039 (the argument lives here, not in the harness) and 0040 (the amends edge).
