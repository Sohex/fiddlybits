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
          depends_on (optional on every tier),
          form (tier 2), pattern_entry (tier-2 scalar entries)
Protocol  id, system, normalisation
load(path)              every entry and protocol, refusing a malformed one rather than skipping it
entry(id)               one, refusing an unknown id
pattern_partner(registry, e)   the tier-2 pattern entry a scalar entry names; nothing for any other
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
  `statistic`, `verdict_kind`, `threshold`, `holdout`, `form` and `pattern_entry` equal
  the loaded ones, read with git (`form` and `pattern_entry` from decision 0025's
  amendment of 2026-09-14, `fiddlybits-52v.8.23`). An entry with an empty `registered_at`, or one that differs from that
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
  parent, changes an entry's threshold, `form` or `pattern_entry` together with `src/`
  or a file holding the testset named by that entry.
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
run(entry, artifact)        -> OracleVerdict from Verdicts, never a boolean
report(results, registry)   the distance report: value, reference, its uncertainty,
                            the distance in units of that uncertainty, the verdict,
                            and under each tier-2 scalar entry its pattern partner
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
gravity or star (decision 0025). The registry carries the pattern, not the payload:
each tier-2 entry declares its `form`, and a scalar entry names the entry that judges
its pattern (The form of a tier-2 entry). `run` judges one statistic per entry against
that entry's own bar, and `Payload` carries no pattern statistic.

`report(results, registry)` places under each scalar entry's line the line of the entry
`pattern_partner` resolves, labelled as its pattern partner; a partner two scalars name
appears under each. A partner with no result among those reported shows its id as not
evaluated and is never omitted, since an unregistered partner is refused its value on a
model result and a hold-out partner is scored at milestone gates only. The two verdicts
stay independent: neither is folded into the other, and a partner's FAIL leaves its
scalar's verdict as it is.

### The form of a tier-2 entry

User decision 2026-09-14 (option B), raised on `fiddlybits-52v.8.3` and planned by
`fiddlybits-zar`; decision 0025, amendment of 2026-09-14.

- `form` is required on every tier-2 entry and is one of `pattern` and `scalar`. An
  entry is `pattern` when its statistic is itself spatial, seasonal or class structure
  (a zonal or seasonal profile, a land/ocean or class contrast, a per-basin, per-site or
  per-class distribution) or locates a feature of that structure (a jet latitude, a
  cell edge, a transport peak). It is `scalar` when its statistic is one number over the
  whole domain: a global mean, total, share or fitted exponent.
- `pattern_entry` is required on a tier-2 scalar entry and names a tier-2 entry of form
  `pattern`, the partner its report is read beside. A pattern entry carries no
  `pattern_entry`, and no tier-1 or tier-3 entry carries either key: the rule is tier
  2's, and a key that means nothing on a tier is refused there, as `protocol` is on
  tier 2.
- Each entry keeps one statistic, one `verdict_kind`, one bar and one set of anchors.
  The partner is judged by its own threshold and registered on its own; the scalar
  states no bar of it.
- Rule 1: a `fail_bar` scalar names a `fail_bar` partner; a report scalar names a
  partner of either kind. A report partner's threshold states from its source why no
  bar exists, as every report entry's does.
- Rule 2: `form` and `pattern_entry` are fixed at registration. They join the fields a
  registered entry's `registered_at` commit must hold (decision 0025, amendment of
  2026-09-13, clause (2)), and no merge on the mainline changes an entry's `form` or
  `pattern_entry` together with `src/` or its testset, the clause (4) rule for a
  threshold. A partner re-pointed after its scalar's value is seen chooses the
  comparison with the value known.
- Rule 3: a scalar and its partner share `holdout`, so no nightly shows a scalar with
  its partner held out.
- The loader refuses a tier-2 entry with no `form` or a `form` outside the closed set; a
  tier-2 scalar entry with no `pattern_entry`; a `pattern_entry` naming an id that is not
  an entry, an entry that is not tier 2, or an entry whose form is not `pattern`; a
  `fail_bar` scalar naming a report partner; a pair whose `holdout` values differ; a
  pattern entry carrying `pattern_entry`; and a tier-1 or tier-3 entry carrying either
  key. These are loader clauses, so `oracles.registry_wellformed` reads them through
  `Oracles.problems` and does not decide them a second time. Rule 2 is the registration
  rule's, decided by `registered` and the history check.
- A scalar whose metric has no published pattern spread either gets a partner with its
  own sourced bar, or leaves tier 2. A tier move is a change to an existing entry, so it
  merges registry-only, apart from code.
- `pattern_entry` is not `depends_on` (decision 0054). A dependency is a constituent a
  row's verdict rests on; a scalar's verdict does not rest on its partner's, which is
  shown beside it.

Two alternatives were weighed.

- *One entry carrying both a scalar and a pattern statistic, each with its own bar*
  (option A). Lost because every tier-2 entry would carry two bars, and registration,
  anchors and verdicts are per bar: `registered_at` fixes one threshold, a re-registration
  rests on a change to one set of anchors and datasets, an entry carries one verdict
  semantics (decision 0053), and `bar_half_width` with `observation_uncertainty` is one
  pair. Two bars under one entry would break or double each of those, and a pattern bar
  sourced from another paper than the scalar's would share the scalar's anchors.
- *A run-time check that the payload carries a pattern statistic* (the first form of
  `fiddlybits-52v.8.3`). Lost because it enforces nothing at load, so an entry with no
  pattern is found only when it is run, and the pattern it demanded had no declared bar:
  the runner compared it against the scalar's `bar_half_width`, a bar sourced for another
  statistic.

The rows land in the order the registration rule sets, registry data before the code
that decides it, with one row ahead of both. The loader refuses a key that is not a
registry field, so `form` and `pattern_entry` are admitted as typed keys with no
condition (`fiddlybits-52v.8.13`) before the registry-only merge writes them
(`fiddlybits-52v.8.14`). Rule 2 needs only those keys on `Entry` and follows
`fiddlybits-52v.8.13` directly (`fiddlybits-52v.8.23`). The partner entries and the
tier moves follow the registry merge (`fiddlybits-52v.8.15` to `fiddlybits-52v.8.20`),
each registry-only; the loader's conditions land once the tree satisfies them
(`fiddlybits-52v.8.21`), and the report reads them last (`fiddlybits-52v.8.22`).

#### Classification

The form each tier-2 entry declares, read from its statistic, and for each scalar the
partner it names (an existing entry, or one to be created by the row given) or the
tier it moves to. An entry that moves carries `form = "scalar"` from
`fiddlybits-52v.8.14` until its move removes it.

| id | form | pattern partner |
| --- | --- | --- |
| `earth.ceres_clear_sky_olr_zonal` | pattern | |
| `earth.ceres_toa_balance` | scalar | none; moves to tier 1 as an energy-conservation criterion (52v.8.15) |
| `earth.ceres_global_means` | scalar | `earth.ceres_toa_zonal`, to create (52v.8.15) |
| `earth.ceres_cre_zonal` | pattern | |
| `earth.era5_zonal_temperature` | pattern | |
| `earth.era5_jet_latitude` | pattern | |
| `earth.era5_hadley_edge` | pattern | |
| `earth.era5_structure_report` | pattern | |
| `earth.gpcp_global_mean` | scalar | `earth.gpcp_zonal_rms`, exists |
| `earth.gpcp_zonal_rms` | pattern | |
| `earth.gpcp_land_ocean_split` | pattern | |
| `earth.land_pme_vs_runoff` | scalar | `earth.grdc_basin_discharge`, exists |
| `earth.hydrolakes_terminal_lakes` | pattern | |
| `earth.fan_water_table` | pattern | |
| `earth.grdc_basin_discharge` | pattern | |
| `earth.basalt_granite_clay_divergence` | pattern | |
| `earth.soilgrids_ph_by_zone` | pattern | |
| `earth.hartmann_phosphorus_yield` | pattern | |
| `earth.modis_albedo_by_class` | pattern | |
| `earth.modis_lai_seasonal` | pattern | |
| `earth.biome_kappa` | pattern | |
| `earth.plumber2_sites` | pattern | |
| `earth.fluxnet_gpp` | pattern | |
| `earth.snow_cover_extent` | pattern | |
| `earth.sea_ice_extent` | pattern | |
| `earth.rgi_glacier_area` | scalar | none; leaves tier 2, for tier 3 or removal as its sources decide (52v.8.18) |
| `earth.woa_sst_zonal` | pattern | |
| `earth.woa_salinity_sections` | pattern | |
| `earth.mld_by_basin` | pattern | |
| `earth.meridional_heat_transport` | pattern | |
| `earth.amoc_strength` | scalar | `earth.amoc_overturning_profile`, to create (52v.8.16) |
| `earth.marine_npp` | scalar | `earth.marine_npp_zonal`, to create (52v.8.16) |
| `earth.dust_aod` | scalar | `earth.dust_aod_by_region`, to create (52v.8.17) |
| `earth.dust_emission` | scalar | `earth.dust_emission_by_region`, to create (52v.8.17) |
| `earth.global_surface_temperature` | scalar | `earth.era5_zonal_temperature`, exists |
| `earth.ecs_report` | scalar | none; moves to tier 3 as a published spread (52v.8.19) |
| `terrain.hypsometry_scale_matched` | pattern | |
| `terrain.hypsometry_profile` | pattern | |
| `terrain.channel_concavity` | scalar | `terrain.channel_concavity_by_basin`, to create (52v.8.20) |
| `terrain.drainage_density` | scalar | `terrain.drainage_density_by_basin`, to create (52v.8.20) |
| `terrain.endorheic_share` | scalar | `terrain.endorheic_share_by_latitude`, to create (52v.8.20) |
| `terrain.denudation_vs_relief` | pattern | |
| `terrain.hypsometric_integral_distribution` | pattern | |
| `terrain.hack_exponent` | scalar | `terrain.hack_exponent_by_basin`, to create (52v.8.20) |

Three readings in that table are judgements the rows carry as stated. A statistic
locating a feature of a profile (`earth.era5_jet_latitude`, `earth.era5_hadley_edge`,
`earth.meridional_heat_transport`) is pattern, because it is not an integral a
compensation can hold fixed. An entry carrying a domain total beside structure
(`earth.snow_cover_extent`, `earth.sea_ice_extent`, `earth.fluxnet_gpp`) is pattern,
because its structure is already judged with the total. A partner is the scalar's own
quantity with its structure kept, so `earth.global_surface_temperature` names the zonal
temperature section rather than a sea-surface or land entry.

The partners to create, each with the pattern statistic it judges, the source its bar
is read from, and the verdict kind rule 1 allows it. No bar is proposed here; each is
taken from its source by the row. Every partner's `holdout` is its scalar's.

| partner | for | pattern statistic | source | kind | row |
| --- | --- | --- | --- | --- | --- |
| `earth.ceres_toa_zonal` | `earth.ceres_global_means` (report) | zonal-mean all-sky OLR, reflected SW, absorbed SW and net TOA flux against CERES EBAF | the CERES EBAF zonal-mean uncertainty, from the EBAF data-product paper (held; read by the row) | `fail_bar` | 52v.8.15 |
| `earth.amoc_overturning_profile` | `earth.amoc_strength` (report) | the vertical profile of overturning transport at 26 N, its depth of maximum and deep return transport, against the RAPID array | the RAPID overturning profile, Moat et al. 2020 (held; read by the row) | either, as the source states a spread or not | 52v.8.16 |
| `earth.marine_npp_zonal` | `earth.marine_npp` (report) | zonal-mean marine net primary productivity by season against the satellite compilations | a published intercomparison of satellite NPP algorithms, whose spread is the bar (open access; fetched by the row) | `fail_bar` | 52v.8.16 |
| `earth.dust_aod_by_region` | `earth.dust_aod` (`fail_bar`) | dust aerosol optical depth by source and outflow region | the regional inter-model spread of AeroCom phase I, Huneeus et al. 2011 (held; read by the row) | `fail_bar` | 52v.8.17 |
| `earth.dust_emission_by_region` | `earth.dust_emission` (`fail_bar`) | dust emission per source region | the same paper's regional spread of emission | `fail_bar` | 52v.8.17 |
| `terrain.channel_concavity_by_basin` | `terrain.channel_concavity` (`fail_bar`) | the distribution of concavity fitted per basin | a published per-basin distribution of concavity (found by the row) | `fail_bar` | 52v.8.20 |
| `terrain.drainage_density_by_basin` | `terrain.drainage_density` (`fail_bar`) | the distribution of drainage density across basins at matched scale, one channel-definition operator on both terrains | a published per-basin distribution of drainage density (found by the row) | `fail_bar` | 52v.8.20 |
| `terrain.endorheic_share_by_latitude` | `terrain.endorheic_share` (report) | the internally drained share of land per latitude band | a published per-latitude-band distribution of the endorheic share (found by the row) | either | 52v.8.20 |
| `terrain.hack_exponent_by_basin` | `terrain.hack_exponent` (report) | the distribution of the Hack exponent fitted per major basin | a published per-basin distribution of the Hack exponent (found by the row) | either | 52v.8.20 |

A partner row whose named source states no spread for a partner that needs a bar stops
blocked and names that scalar for the user.

#### Decisions of 2026-09-14

The user answered the questions this plan raised, and decided each scalar that had no
known pattern source.

1. A `fail_bar` scalar names a `fail_bar` partner; a report scalar names a partner of
   either kind (rule 1).
2. `form` and `pattern_entry` are fixed at registration, and no mainline merge changes a
   registered entry's `form` or `pattern_entry` together with `src/` or its testset,
   the same rule as for a threshold (rule 2, `fiddlybits-52v.8.23`).
3. A scalar and its partner share hold-out status, and the loader refuses a pair whose
   `holdout` values differ (rule 3).
4. `earth.ceres_toa_balance` moves to tier 1 as an energy-conservation criterion, with
   `source_kind` conservation and its statistic unchanged, and takes no partner
   (`fiddlybits-52v.8.15`). Decision 0023 names it as a tier-2 bar and is amended by
   that row. A tier-1 threshold is an exact identity or a tolerance whose derivation it
   states, fixed by the plan row before the implementation row; the derivation of this
   entry's tolerance is carried by `fiddlybits-caz.1`, the coupled-Earth plan row.
5. `earth.ceres_global_means` takes `earth.ceres_toa_zonal`, whose bar is the CERES EBAF
   zonal-mean uncertainty (`fiddlybits-52v.8.15`).
6. `earth.ecs_report` moves to tier 3 as a published spread, anchored to the
   climate-sensitivity assessment, and no warming-pattern partner is created
   (`fiddlybits-52v.8.19`). A tier-3 entry names a protocol, so that row declares one
   from the assessment.
7. `earth.rgi_glacier_area` leaves tier 2; its row decides from its sources between tier
   3 and removal and reports the choice (`fiddlybits-52v.8.18`). Its manifest names it
   alone, so a removal settles the manifest in the same row.
8. `earth.amoc_strength` and `earth.marine_npp` take the RAPID profile and a satellite
   NPP algorithm intercomparison (`fiddlybits-52v.8.16`); the dust scalars take the
   regional spread of AeroCom phase I (`fiddlybits-52v.8.17`); the four terrain scalars
   take published per-basin or per-latitude-band distributions (`fiddlybits-52v.8.20`).

Every tier move is a change to an existing registry entry, so it merges registry-only,
apart from code, before the loader's conditions.

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
| `oracles.registry_wellformed` | every entry parses, carries every required field including a closed `source_kind`, satisfies its conditional fields, has anchors if it is tier 2 or 3, and every anchor resolves in the references index; every entry carries one verdict semantics and names no verdict in prose, and every protocol is declared once and named (decision 0053); every `depends_on` id resolves to a row on the same tier or a lower one without a cycle, no row id is named in prose, and no row carries a clause of a dependency's threshold (decision 0054); every tier-2 entry declares a `form` from the closed set and every tier-2 scalar entry names in `pattern_entry` a tier-2 entry of form pattern (The form of a tier-2 entry) | a row with a missing `threshold`, a tier-1 `system.*` row with no `instances`, and a tier-2 row with empty anchors, all of which must be refused rather than skipped; a row mixing an exact identity and a report under one bar, which must be refused; a row depending on an absent row and a row restating a dependency's threshold, both of which must be refused; a tier-2 row with no `form`, and a tier-2 scalar row naming no partner or a partner that is absent, not tier 2 or not a pattern, each refused; one fixture for each remaining verdict-shape, dependency and form clause, and a clean fixture that must be accepted |
| `oracles.registration_rule` | a bar is fixed before the value it judges has been seen: `admits` refuses an unregistered entry's value on a model result; an entry counted registered is what its `registered_at` commit holds, `form` and `pattern_entry` included; no re-registration, `report` to `fail_bar` change, merge or `Fixture` construction the clauses of The registration rule as a build check refuse; no bar is narrower than its observation's uncertainty | `admits` handed an unregistered fixture entry and a model result, which must refuse the value, and the same entry and a `Fixture`, which must admit it; one fixture for each remaining clause, each with the accepted twin its clause names; a fixture bar set below a stated observational uncertainty, which must be refused |
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
| 52v.8.3 | sonnet | `src/Oracles/run.jl`, `test/oracles/run.jl` | a verdict is one of the three and never a boolean; `run` calls `admits` at its door: an unregistered fixture entry handed a model result is refused its value and emits nothing, and the same entry handed a `Fixture` returns its verdict; every admitted result is emitted as an `oracle` journal event through the one emitter; each entry is judged against its own bar and the payload carries no pattern statistic (the load rule is 52v.8.21's, the partner report 52v.8.22's) |
| 52v.8.4 | frontier | `src/Oracles/mutate.jl`, `test/oracles/mutate.jl` | `repro.mutation_run` runs the whole list; a mutation nothing catches files a row and the suite is not reported green |
| 52v.8.5 | sonnet | none; re-pointed | the M0 Earth derived-quantity question is `system.derived_fields_reproduce`, carried by `fiddlybits-52v.4.5` on all five instances; this row closes as superseded rather than writing a second oracle for it |
| fiddlybits-3vq | frontier | `docs/oracles/registry.toml`, `docs/oracles/README.md`, `docs/oracles/data/`, `docs/inputs/`, `docs/references/INDEX.md`, this plan, `test/datasets/` | every tier-2 and tier-3 entry carries `datasets`; every link resolves in both directions; `earth.sea_ice_extent_cycle` corrected; `oracles.dataset_links` passes on the tree with every control refused |
| 52v.8.13 | sonnet | `src/Oracles/registry.jl`, `test/oracles/registry.jl` | `form` and `pattern_entry` are registry fields carried on `Entry` with no conditional clause: a tier-2 fixture entry carrying both loads and one carrying neither loads; controls refused with their phrases: `form` not a string, `pattern_entry` not a string, a key spelt `forms`; `Oracles.problems` on the tree unchanged |
| 52v.8.14 | local | `docs/oracles/registry.toml` | every tier-2 entry carries the `form` of the classification table and no other tier carries either key; the three scalars with an existing partner name it, each pair sharing `holdout` and `fail_bar` on both sides, with a scratch listing and its control (one holdout flipped is named); no existing threshold or holdout changes, shown by a field-by-field comparison of the loaded entries against main with its control (one threshold edited in a scratch copy is reported); registry-only, touching nothing under `src/` or `test/`; `oracles.registry_wellformed`, `oracles.dataset_links` and `oracles.registration_rule`'s tree verdicts pass |
| 52v.8.15 | frontier | `docs/oracles/registry.toml`, `docs/references/INDEX.md`, `docs/references/REQUESTS.md`, decision 0023's Amendments | `earth.ceres_toa_balance` is tier 1 with `source_kind` conservation, no `form`, and its statistic, verdict kind, threshold, holdout, anchors and datasets unchanged, decision 0023 amended; `earth.ceres_toa_zonal` created `fail_bar` with its bar the CERES EBAF zonal-mean uncertainty from the read paper, `holdout` its scalar's, and named by `earth.ceres_global_means`; no other change, with the comparison control; registry-only, touching nothing under `src/` or `test/`; the three tree oracles pass; the scratch listings of unpartnered scalars and of mismatched pairs name none of this row's, with their controls |
| 52v.8.16 | frontier | `docs/oracles/registry.toml`, `docs/references/INDEX.md`, `docs/references/REQUESTS.md` | as 52v.8.15's partner, for `earth.amoc_overturning_profile` on the read RAPID paper (either kind) and `earth.marine_npp_zonal` `fail_bar` on the fetched NPP algorithm intercomparison's spread |
| 52v.8.17 | frontier | `docs/oracles/registry.toml`, `docs/references/INDEX.md`, `docs/references/REQUESTS.md` | as 52v.8.15's partner, for `earth.dust_aod_by_region` and `earth.dust_emission_by_region`, both `fail_bar` on the read AeroCom phase I regional spread |
| 52v.8.18 | frontier | `docs/oracles/registry.toml`, `docs/references/INDEX.md`, `docs/references/REQUESTS.md`, `docs/oracles/data/rgi-v7.toml` | `earth.rgi_glacier_area` is not tier 2: tier 3 with `source_kind` published spread, a declared protocol it names and read anchors, statistic unchanged; or removed, its manifest settled and `oracles.dataset_links` passing; the choice and its reason in the notes; no other change, with the comparison control; registry-only; the three tree oracles pass |
| 52v.8.19 | frontier | `docs/oracles/registry.toml`, `docs/references/INDEX.md`, `docs/references/REQUESTS.md` | `earth.ecs_report` is tier 3 with `source_kind` published spread, anchored to the read climate-sensitivity assessment, naming a protocol declared once from that assessment, no `form`, statistic, verdict kind, threshold and holdout unchanged; no other change, with the comparison control; registry-only; the three tree oracles pass |
| 52v.8.20 | frontier | `docs/oracles/registry.toml`, `docs/references/INDEX.md`, `docs/references/REQUESTS.md`, `docs/oracles/data/etopo2022.toml` (its `oracles` key, where a partner reads it) | as 52v.8.15's partner, for the four terrain partners on read per-basin and per-latitude-band distributions, the partners of the two `fail_bar` scalars `fail_bar` |
| 52v.8.21 | sonnet | `src/Oracles/registry.jl`, `test/oracles/registry.jl`, `test/oracles/fixtures/` (a tier-2 fixture row's `form` only) | the clean fixture with a `fail_bar` scalar and its `fail_bar` pattern partner of equal holdout loads and `pattern_partner` resolves it; controls refused with their phrases, each shown to fail with its clause removed: a tier-2 entry with no `form`, a `form` outside the closed set, a scalar with no `pattern_entry`, a partner that is not an entry, a partner on tier 1, a partner of form scalar, a pattern entry carrying `pattern_entry`, a tier-1 entry carrying `form`, a tier-3 entry carrying `pattern_entry`, a `fail_bar` scalar naming a report partner (twins: a report scalar naming either kind loads), a pair whose `holdout` differs in either direction (twin: both hold-out loads); a malformed partner refuses the whole registry; `Oracles.problems` on the tree is empty |
| 52v.8.23 | sonnet | `src/Oracles/registry.jl`, `test/oracles/registry.jl` | `REGISTERED_FIELDS` carries `form` and `pattern_entry`: an entry whose `form` or `pattern_entry` differs from its `registered_at` commit is unregistered; the history check refuses a mainline merge, and a branch judged as its own merge, changing `form` together with `src/` and `pattern_entry` together with the entry's testset, each beside a registry-only twin that is accepted; a listed exception accepts such a merge and an unmatched one is stale; each control shown to fail with the two fields left out; the tree's verdicts record no problem |
| 52v.8.22 | sonnet | `src/Oracles/run.jl`, `test/oracles/run.jl` | the report shows a fixture scalar's line followed by its partner's, labelled; controls: a report omitting the partner line fails, a partner with no result shows as not evaluated and a report dropping it fails, a scalar PASS beside a partner FAIL reports both unchanged and a report folding them fails; one oracle event per admitted run and none for a partner line; a `Payload` given a pattern keyword is refused |
| 52v.8.6 | sonnet | none; reports only | all four oracles ran; verdicts by name |

52v.8.3 and 52v.8.4 depend on 52v.8.2; 52v.8.3 depends on `fiddlybits-52v.6.8`; the
verify row depends on 52v.8.7. The mutation row depends on every other area's
verify row, because a mutation run over a suite that does not yet exist measures
nothing.

The pattern rows (`fiddlybits-zar`): 52v.8.14 and 52v.8.23 depend on 52v.8.13;
52v.8.15 to 52v.8.20 depend on 52v.8.14; 52v.8.21 depends on 52v.8.13 to 52v.8.20;
52v.8.22 depends on 52v.8.21 and 52v.8.3; the verify row depends on 52v.8.21, 52v.8.22
and 52v.8.23. 52v.8.23 is a row of its own under decision 0048, clause 4: the history
check and its git fixture repositories are a second substantial piece of work beside
52v.8.21's per-entry clauses, and it waits on none of the partner rows.
