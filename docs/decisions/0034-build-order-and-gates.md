+++
id = "0034"
title = "Build order is by dependency, each milestone has a gate with a right answer, and no schedule is attached"
status = "accepted"
date = 2026-09-08
+++

## Decision

Milestones are ordered by what each needs to exist first. Each has a deliverable and
a gate whose criteria are registered at the milestone's *start* (decision 0025). No
schedule, effort figure or "first usable version" framing is attached to any of
them: the system is built so that each brick is sound before the next is laid.

| milestone | deliverable | gate |
|---|---|---|
| M-1 | decision records, requirements archive, practice book, failure-modes review, oracle registry skeleton, references triage (documents only) | every predecessor audit and class has a recorded disposition; the user has reviewed the framing |
| M0 | mesh hierarchy with graded local refinement and the connectivity graph; the typed field; the system struct with dispositions; the content-addressed store; an Earth test instance `Earth()` and four synthetic test instances with closed-form derived quantities, none a real body and every field a declared value chosen so closed forms exist: `SyntheticNonEarth()` (a CO2-dominated bulk atmosphere, higher gravity, prograde, high eccentricity, non-zero obliquity, one star, one moon), `SyntheticSynchronous()` (synchronous rotation, zero obliquity, an M-dwarf spectrum, no moon), `SyntheticRetrograde()` (retrograde spin, two stars, the epoch on the periapsis event) and `SyntheticComposition2()` (an H2-He bulk with a different condensable declared absent); CPU and GPU backends; profiles | area and nesting identities; refinement-balance identity; every `Derived` field of `System` reproduced from its own inputs on `Earth()` and on the synthetic instances (the registry's `system.*` section); dispositions refuse a bad block; elementwise CPU/GPU bitwise |
| M1 | terrain snapshot with ages and rates | scale-matched hypsometry, channel concavity, drainage density, denudation against relief, and the age-times-rate identity; no FAIL in the terrain registry |
| M2 | hydrology: drainage, lake cascade with spill, groundwater, wetness | the terminal-lake equilibrium test with no error correlation against runoff, area or aridity; water-table bars with a skill requirement; closed-form cascades |
| M3 | dynamical core on the GPU, with the independent reference arm | the shallow-water suite, the baroclinic cases, the idealised-forcing climatology, the small-planet cases across a parameter spread; the checkerboard mode suppressed and the Hollingsworth check passed; a graded refinement region with no reflected-wave growth; thread bitwise; ulp envelope; convergence orders as designed |
| M4 | radiation pipeline for arbitrary spectra, column physics | line-by-line bars for several spectra; grey analytics; aquaplanet inside the intercomparison spread; a prescribed-sea-surface Earth against the radiation, precipitation and reanalysis products |
| M4b | parameter sweeps (rotation, obliquity, gravity, stellar type, flux) | inside the published spreads of the third oracle tier |
| M5 | the one land column, snow, vegetation-lite | site-level flux benchmarks; basin discharge; land precipitation minus evaporation against runoff; ledgers closed at the seam |
| M6 | ocean, sea ice, marine ecosystem | the classical gyre solutions; the Stefan problem; climatological sections; meridional heat transport; the ice-extent cycle; marine productivity in the observational range |
| M7 | first coupled Earth | the full suite including hold-outs; ledgers over one statistics window; top-of-atmosphere drift inside the dimensionless exit of decision 0023; climate sensitivity reported |
| M8 | first coupled non-Earth configuration with terrain, hydrology, land column and ocean, every loop exit evaluable; the fast profile end to end | the sweeps bracket the configuration; every `Bracketed` and `Closure` constant swept; every loop exit evaluable |
| M9 | vegetation and biogeochemistry in full | land-model benchmark scores; site-level productivity; element ledgers |
| M10 | carbon loop, in-line dust, minerals, ice flow | dust burden and emission inside the compilation range; the weathering thermostat's analytic timescale; the ice-dome solution; exits evaluable |
| M11 | managed biosphere; the full profile end to end | crop and fishery potential against yield and catch statistics as REPORT; the irrigation ledger closes |

Within the code milestones: infrastructure first; terrain and hydrology, which are
standalone and identity-testable, in parallel with the dynamical core; radiation and
the column as a single-column model; then the first coupled run; then the rest.

**Known immaturities to be earned, not tuned away.** The core's stability, which a
decades-old spectral core has and a new one does not; climatology realism without
Earth tunings, under a rule that forbids fixing it by tuning; a radiation pipeline
with no long record inside a general circulation model; a trait-based vegetation
model with no validation history; terrain that looks coarser than a procedural
generator's until the sub-grid relief closure is proven. Each is a gate item with an
oracle, never an excuse.

## Alternatives considered

- *Value-first ordering (the atmosphere first so a climate exists early).* Rejected:
  the atmosphere is the long pole and depends on the mesh, the field type and the
  parameter struct being right; putting it first would build it on shifting
  foundations.
- *A minimum viable coupled system as an early milestone.* Rejected by the user's
  framing: no MVP, brick by brick.
- *Gates by comparison with the predecessor's outputs.* Rejected: the predecessor's
  numbers carry the defects its audits recorded, and this system has no continuity
  with them. A comparison run of a similar configuration is a possible oracle, judged
  on its merits like any other.

## Consequences

- Every milestone's registry entries exist before its first artifact.
- M3's gate is also the go/no-go on the triangle C-grid core; its fallbacks are in
  decision 0013.
- The independent reference arm for the dynamical core is a milestone deliverable,
  not an afterthought.
- No document in this repository states how long a milestone will take.

## References

- The oracle products and bars per milestone are enumerated in
  `docs/oracles/README.md` and its registry, each anchored in `docs/references/INDEX.md`.
- Decision 0025 (verdicts and registration), decision 0026 (the analytic gates),
  decision 0013 (the core and its fallbacks).

## Amendments

- 2026-09-08: the M0 gate validates every Derived field of System on a synthetic non-Earth instance as well as Earth(), and the M7 gate reads the statistics window and the dimensionless exit of decision 0023 rather than "a year", from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: cross-area review: the M0 deliverable names the four synthetic constructors and what each declares, from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-10: the M0 deliverable includes the coupling layer of decision 0009 (`WorldState`, `assemble`, `Exchange`, `FixedPointLoop`, `Ladder`) and the `Profile` of decision 0014, and the M0 gate includes the assembly refusals and the exit predicates on known surrogates. Neither was named in the table above and neither had a row. The argument for the coupling layer is mechanical rather than a principle: decision 0010 states the store's central function as `plan(system, ladder, code)`, so an M0 row's signature already reads a coupling type and cannot be written without it. What M0 cannot evidence is the layer under load, so its ledger and exit oracles run here on fixtures and surrogates, which decides the machinery, and again on the coupled case at M7, which decides the physics. Carried by `fiddlybits-52v.11` and `fiddlybits-52v.4.8`.
