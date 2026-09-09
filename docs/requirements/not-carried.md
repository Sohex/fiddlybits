# Not carried

Every old audit or note judged not to carry as a requirement, with the reason, grouped by the area that reviewed it. A finding listed here may still have had a lesson absorbed into a record; the line says which.

## Reviewed by area: atm


One line per old audit judged not to carry on its merits for a generic exoplanet
builder. Where a lesson from the audit survives, the line names the record that
holds it.

No whole audit in this batch was judged not to carry: each of the twenty carries
a generalised lesson into one record under `atm/` or `sys/`, and its path appears
in exactly one record's `old_path`. What does not carry is listed below by audit
and section, so the boundary between the lesson and the defect is on the record.
These lines name sections of carried audits, not audits; the audit paths are
deliberately not repeated here.

## Findings inside carried audits that do not carry

- `model-earth-centrism` sections 0, 3, 4, 10, 15, 16, 18, 19, 26, 28 and the
  dormant list: continuation drivers dropping namelist keys, a compiled Earth
  radius in one Fortran module, a 5 m snow cap, four compiled salinity
  constants, an archived albedo code, a postprocessor lapse rate, a calendar
  module never updated, a persistence flag not in the restart, an Arctic
  thickness clamp with global heat redistribution, a run log printing Earth, and
  which vendored modules were dead. Each is a defect in a model that will not
  exist. The mechanisms behind them are REQ-SYS-101 (constants and constructed
  defaults), REQ-SYS-102 (day and calendar), REQ-SYS-103 (one declaration) and
  REQ-SYS-104 (grid-unit constants); nothing else from those sections is a
  requirement.
- `inherited-earth-constants` sections 4, 5 and 7 in their specifics: the
  longitude of perihelion of the old orbit, the design-flux derivation against a
  habitability comfort band, and which four papers a photosynthetic window rested
  on. The perihelion is an A0 free parameter with an epoch rule (decision 0032);
  the comfort-band criterion is a worldbuilding preference of the old world, not
  a builder requirement, and only its threshold-before-derivation lesson carries
  (REQ-ATM-014); the read-versus-held discipline is decision 0030.
- `opaque-constants` sections 4, 14, 15, 17 and the build-flag rows of its
  smaller-findings table: a transform-equivalence gate at a stale filter power,
  `OMP_STACKSIZE` absent from the run path, an unbuildable truncation and four
  private copies of the rung table, a controller's state absent from the restart,
  and hand-written compiler flag lines. Old-stack tooling; the one-declaration
  and derived-gate lessons are REQ-SYS-103 and the restart-completeness lesson
  belongs to the provenance area.
- `aerosol-particle-radius` sections "Why it matters now", "The two fixes are
  coupled" and the erratum question about a published grid: an upstream
  pull-request sequencing problem and a question for another project's authors.
  The physics (one particle description, sinks as rates, a longwave term) is
  REQ-ATM-006.
- `dormant-exoplasim-modules` sections 1, 4, 5 and 6: the inventory of which
  vendored modules were compiled, a diagnostic's accumulators as restart records,
  an offline ice-sheet accelerator nothing invoked, and what CMake compiled. The
  grid-unit thresholds and the dormant-switch lesson are REQ-SYS-104; the
  declared-absence discipline is REQ-ATM-013.
- `absent-and-inherited-physics` section 1's first verdict (that ocean heat
  transport was one namelist key away) is superseded by its own second verdict
  and by decision 0017, which carries a dynamical ocean; only the pricing
  discipline carries (REQ-ATM-013).
- `unpriced-terms` section "Knocked down": the pit-filling routing of the old
  land scheme was not a defect. Recorded inside REQ-ATM-012 as the reason the
  lake, not the routing, was the absent physics; nothing about that routing is a
  requirement.
- `design-flux-two-point-response` sections "The soil built on this climate" and
  "The cap stands": a soil-depth comparison across two terrains with two
  pedogenesis values and the old world's flux decision. Configuration-specific;
  the regime and threshold lessons are REQ-ATM-014.
- `flux-slope-bracket` section "Cost, with the machine state": a wall-clock
  price of one pair on one host. Not a requirement; benchmarking discipline is
  decision 0029.
- `albedo-attenuation` sections "What actually blocks it" and "The run, priced":
  worktree symlink refusals, stale binaries and restart availability on the old
  tree. Tooling; the measurement discipline is REQ-ATM-016.
- `lake-energy-omission-bound` last bullet on the old terrain export carrying
  zero inland-water regions: a property of that generator. Decision 0019 derives
  lakes from the water balance by construction.
- `cryosphere-material-properties` section "The run that would measure it":
  the specific paired arms named for the old model. The pricing rule (constant
  against prognostic density, not two gravities) carries in REQ-ATM-010; the
  arms do not.
- `stellar-spectrum-oracle` section "How this becomes a standing check" in its
  specifics: the old project's check script and provenance file. The design of
  the check (stored source-resolution integral, tolerance from the rebin
  residual) is REQ-ATM-001.

## Reviewed by area: num


One line per old audit judged not to carry on its merits for a generic exoplanet
builder. Where a lesson from the audit survives, the line names the record that
holds it.

- /home/cfutro/docs/world/notes/audits/aocl-and-model-build-flags.md: a survey of whether a vendor maths library could attach to a Fortran binary (it could not, and the two components that could were slower) and a round of compiler-flag verdicts on a build profile that was replaced twice before the audit closed. The library and flag findings are properties of that toolchain. The benchmarking method (interleaved paired arms, a self-scatter floor declared before any bar, a moved answer excluded from timing) is REQ-NUM-006, and the finding that the same source at two checkout paths gave two binaries is answered by REQ-PROV-002, where the code version is a tree hash computed at load and there is no compiled artifact to differ.
- /home/cfutro/docs/world/notes/audits/epilog-adenergy-use-after-free.md: an array freed and then written to the checkpoint, so every production run's checkpoint was truncated. Manual deallocation does not exist in a garbage-collected language and the defect class is unrepresentable. The coverage lesson (the stability probe switched off the diagnostic and so never exercised the path that faulted) is REQ-PROV-001's per-commit round trip, which runs with the production profile's diagnostics on.
- /home/cfutro/docs/world/notes/audits/nlowio-collective-deadlock.md: a configuration scalar read by one MPI rank and never broadcast, which deadlocked a patched collective and, without the patch, assembled fields that were part sample and part interval mean over 60 of 64 latitude rows while every collective count matched. There is no collective in a single process, and one immutable `System` seen by value on every worker leaves no per-worker copy that could diverge (A3, REQ-NUM-002). The corruption shape it describes, a decomposition-dependent answer with no error, is exactly what REQ-NUM-002's thread-count invariance test with repeats catches. The diagnostic lesson (two changes landed in one day and the one easier to name got the blame; the test that separated them ran the old binary under the new conditions) is a practice-book line, not a requirement.

## Reviewed by area: ter


One line per old audit judged not to carry as a requirement record, with the
reason. Every other terrain audit in this pass has a record under `ter/`.

- /home/cfutro/docs/world/notes/audits/orogen-first-pass-gate.md: A one-off reading of the predecessor's issue tracker against a gate the old pipeline refused to compute ("does anything outstanding change the first export"); its two generalisable points, that an artifact is a function of an enumerable set of inputs and that a loop input absent on the first pass is a declared absence resolved by iteration, are made unrepresentable by decision A6 (artifact identity as a hash over code version, declared parameter subset, input keys, support id and operator version) and decision A5 (exit predicates with a `NotEvaluable` verdict), so there is no rule left to carry. Its two audit findings without tracker rows (a plutonic excess and a near-silent craton archetype) are distance-from-Earth reports about one configuration's plate count and cover thickness, which decision C1 handles as `REPORT` verdicts, not requirements.

## Reviewed by area: hyd


One line per old audit or note in this area judged not to carry, or carried only in
part, with the reason. Every audit assigned to this area produced a record; the lines
under "Audits, in part" name the findings inside a carried audit that do not carry so
that nothing in those files is silently dropped. Notes are listed for completeness.

## Audits, in part

- /home/cfutro/docs/world/notes/audits/carve-criterion-terms.md (finding 8): two more
  longitude-convention defects (a coupling matrix and a basemap reading a climatology
  by the wrong first column). A grid-convention class made unrepresentable by "conventions
  travel by name" (A1, A6); enforced by the `ter` area's records, not here.
- /home/cfutro/docs/world/notes/audits/carve-overshoot.md (the instrument): the
  cross-build provenance flag (`--for-build`), the staged albedo file keyed by rung,
  and the carve-list sidecar's per-basin bracket membership are machinery of the
  verdict loop and of a multi-process pipeline; A5 and A6 make a cross-build read a
  content-addressed input rather than a declared exception. The lesson carried is in
  REQ-HYD-008.
- /home/cfutro/docs/world/notes/audits/basin-catalogue-floor.md (the generator's
  contract): `selectBasins`, `buildBasinProtection`, the `noLower` band, the
  natural-relief basis conversion and the manifest fields are the old generator's
  interface; there is no catalogue to select from and no instruction to convert in a
  depression-hierarchy design. The lessons are in REQ-HYD-006.
- /home/cfutro/docs/world/notes/audits/surface-hydrology-fire-carbon-followup.md
  (findings 1, 2, 5): forest snow masking, fire disturbance state and outgassing
  capacity are routed to the atmosphere/land-column, biosphere and carbon areas; the
  outgassing lesson is REQ-PED-011. Nothing in them is dropped; they are not this
  area's to write.

## Notes

- /home/cfutro/docs/world/hydrography/notes/mesh-geometry.md: the Voronoi dual of a
  jittered Fibonacci mesh, the two disagreeing cell areas, and the non-converging
  truncation error of a first-order operator on it are properties of the old mesh; the
  icosahedral hierarchy (A1) has one exact area per cell. The general lesson, that a
  finite-volume divergence must divide by the area its own faces bound and that the
  solved field's error is a different quantity from the operator's truncation error,
  belongs to the `ter` and `num` areas.
- /home/cfutro/docs/world/hydrography/notes/orogen-carving-request.md: a feature
  request to a vendored terrain fork for per-basin carving control. There is no
  cross-process request in one-process coupling, and basin incision is a process
  (REQ-HYD-008), not an instruction.
- /home/cfutro/docs/world/hydrography/notes/retain-fraction.md: the retain fraction,
  the Earth-calibrated incision coefficient and the size-floor sweep are superseded by
  the incision process of B1 and B5; the surviving oracle and the erodibility, slope
  exponent and size-class lessons are carried inside REQ-HYD-008.
- /home/cfutro/docs/world/hydrography/notes/carve-verdict-interval.md: carried inside
  REQ-HYD-007 (interval bracket, sign check) and REQ-HYD-010 (the storage the bracket
  measures); the concavity bound on `Q^m` is unnecessary once overflow is a resolved
  series and is recorded in REQ-HYD-008.
- /home/cfutro/docs/world/hydrography/notes/groundwater-scoping.md: carried inside
  REQ-HYD-003 (the four channels, the permeability table, the gravity rule) and
  REQ-HYD-004 (the tests declared before the code).
- /home/cfutro/docs/world/hydrography/notes/subgrid-water-table.md: carried inside
  REQ-HYD-005 (the cell-mean rule) and REQ-HYD-004 (the unconfined form's refusal).
- /home/cfutro/docs/world/pedology/notes/mineral-reactivity-supply.md: the four
  proxies of a vendored vegetation model's mineral-aware arm are that model's contract.
  What generalises is carried: a transfer indexed on an axis the system does not carry
  cannot be derived (REQ-PED-001, where the clock now exists); allophane content keyed
  on leaching rather than development and the exchange-complex derivation are in
  REQ-PED-006.

## Reviewed by area: ocn


One line per old audit or note judged not to carry as a requirement of its own.
Where a source contains one generalisable lesson beside its old-stack content,
the line says which record or area holds it.

- /home/cfutro/docs/world/notes/audits/cgenie-build-cost-and-grid-ceiling.md: a build, timing and stability sweep of a vendored Fortran ocean host that will not exist here; its costs, make overrides, code-model flags, the MATLAB/Octave connector and the r^4 timestep scaling are properties of that stack. The one lesson that generalises (a grid that runs is not a grid that is stable; a solver's Courant number must be computed from its own diagnosed flow and acted upon, never left as a namelist integer or a diagnostic behind a debug flag) is a numerics requirement for the `num` area, not an ocean one.
- /home/cfutro/docs/world/notes/audits/cgenie-embm-free-path-and-threading.md: the addition of a driven surface-flux path, a heap-traffic fix, a storage-class flag change and OpenMP threading to a vendored host; the correctness class it demonstrates (implicit static state under threads; a private copy that needed an inherited value) is made unrepresentable by A7 and C6 (pure kernels, no mutable globals, thread-count invariance as a design property) and belongs to `num`, not to the ocean.
- /home/cfutro/docs/world/notes/audits/cgenie-parallelism-and-coupling-support.md: a profile of a vendored serial ocean host and an Amdahl bound on threading it; not carried. Its section 5 (the regridding contract: normalisation by field, coverage fraction travelling with the result, unmapped destination an error, closure registered in advance, source edges from the model's own quadrature) is carried through REQ-OCN-010, and its section 4b resolution rule (the coarsest support that resolves the connections the terrain carries) through REQ-OCN-009; both records cite it.
- /home/cfutro/docs/world/notes/audits/cgenie-unreachable-code-dispositions.md: a keep-or-delete verdict on unreachable routines in a maintained fork of a vendored model; nothing is vendored here (A8 borrows ideas and adopts infrastructure only), so the fork-maintenance test has no object.
- /home/cfutro/docs/world/ocean/README.md: the description of an offline full-flux ocean architecture around a vendored host, superseded by B3's synchronous coupling on one mesh. Its rule that wiring a component means declaring its calibration state first (which switches are off, which factors at identity, which reference files absent) is the A8 import-review record in another form and belongs to `prov`, not to an ocean requirement.
- /home/cfutro/docs/world/ocean/notes/mesh-placement.md: the placement of a Voronoi mesh onto a separately constructed ocean grid through cell boundaries in one coordinate frame; superseded by A1, where the ocean's cells are a level of the same hierarchy as the terrain's and placement is exact nesting (a bit shift), so no coordinate comparison exists to get wrong. The lesson that a placement must live in one frame is idea 7 (conventions travel by name, not by coordinate) and is held by the `ter` area.

## Reviewed by area: bio


One line per old audit or component note judged not to carry as a
requirement. Where a lesson inside it survives, the record that absorbed the
lesson is named so nothing is lost by the line.

## Judged not to carry

- /home/cfutro/docs/world/biosphere/notes/cnp-fork-scoping.md: a scoping of how to integrate one vendored fork's phosphorus routes into one pipeline; nothing is ported (plan, Context). The one scientific statement in it, that phosphorus is rock-derived and its supply is the weathering the terrain and pedology already model, is REQ-BIO-012 item 4.
- /home/cfutro/docs/world/biosphere/notes/lpj-guess-porting-audit.md: the mechanics of porting a vendored Earth model (constants in one header, a patch, a smoke test, a per-cell cost) are old-stack work. Its two surviving lessons, the 24-hour-step calendar decision with its verification and the PAR-fraction derivation from the real spectrum, are REQ-BIO-001 and REQ-BIO-003.
- /home/cfutro/docs/world/biosphere/notes/modelling-gap-audit.md: nine of its ten findings are seams of a pipeline that exchanged frozen artifacts between processes (a binary land mask, a dominant soil code, an unretained runoff table, a roughness builder with no back-edge, a climatology hash the soil step could not prove), which A1 mosaic tiles, A5 one-writer ownership and A6 content addressing make unrepresentable. The two lessons that generalise, that the last output year is not an equilibrium statistic and that every extensive quantity and feedback is on the rootable tile area, are REQ-BIO-014 and REQ-BIO-019; the two-band albedo anchoring rule is REQ-BIO-003 item 4.
- /home/cfutro/docs/world/biosphere/notes/restart-state-outside-soil.md: a restart that lost annual accumulators reset on day zero and an integer parser that rounded a -1 sentinel to 0 are defects of an ordinal calendar and a vendored instruction parser; under A4 an annual sum is an interval integral in the state store and there is no ordinal. The general lesson, that restart equivalence is tested as a run against an uninterrupted run with a right answer and that a check agreeing with a copy of the rule cannot fail, belongs to the num and prov areas (C6 reproducibility), not to biology.
- /home/cfutro/docs/world/biosphere/notes/soil-restart-state.md: the member-by-member classification of a vendored soil class's serializer (rebuilt-before-first-read, diagnostic, lost) is old-stack; the design's state store declares every prognostic quantity (A5, A6), so an unserialised member is unrepresentable. The behavioural half (restart continuity as a test) is the num and prov areas' as above.
- /home/cfutro/docs/world/biosphere/notes/spatial-support-ecological-aggregation-audit.md: its ten findings are the grid-crossing class (partial land to binary cell, means through nonlinear operators, extensive outputs on different coastlines, shape mistaken for support), made unrepresentable by A1 one mesh with exact nesting and A2 field semantics; the ter area owns the surviving reduction and support-identity lessons. The one biosphere-specific lesson, that stochastic patches are samples of demography and not spatial response units, is REQ-BIO-009 item 4.
- /home/cfutro/docs/world/biosphere/notes/forcing-replay-preregistration.md: replaying an archived climate block through a vegetation spin-up existed because vegetation ran offline; under A5 and B9 the daily tier runs synchronously in one process. The seam test, block ladder, alternative-block spread and orbit-preserving reordering, and the three generator prohibitions, survive as REQ-BIO-002 items 5 and 6 for any tier that does replay a block.
- /home/cfutro/docs/world/biosphere/notes/bvoc-cloud-sensitivity-preregistration.md: its three arms were built around a climate model with no aerosol-to-droplet pathway and a prescribed optical-depth carrier; B2 resolves activation from droplet number, so the structural question it registered is answered by the design and the arms do not transfer. The discipline (a model-form decision rule fixed before any arm runs, an optical-depth proxy refused) is REQ-BIO-018 items 4 and 6 and C2.
- /home/cfutro/docs/world/biosphere/notes/productivity-prediction.md: ten pre-registered predictions for one configuration, scored on its runs; configuration-specific numbers are not requirements (brief rule 2). The photosystem-window and photon-currency lessons are REQ-BIO-003; the obliquity cold-trough mechanism behind its structural misses is REQ-BIO-005; the rule that a declared bracket is quoted as its span and a line hits only when the whole span lands is C2's and the proc area's.

## Absorbed into records (listed so the index is complete)

- /home/cfutro/docs/world/notes/audits/closure-stocks-are-incomplete.md: REQ-BIO-013 (old_path).
- /home/cfutro/docs/world/notes/audits/lpj-pft-set-implicit-earth.md: REQ-BIO-004 (old_path); the anticorrelated table in REQ-BIO-006.
- /home/cfutro/docs/world/notes/audits/lpj-soil-cn-ratios.md: REQ-BIO-010 (old_path).
- /home/cfutro/docs/world/biosphere/notes/time-base-unit-contract.md: REQ-BIO-001 (old_path).
- /home/cfutro/docs/world/biosphere/notes/ecological-forcing-field-contract.md: REQ-BIO-002 (old_path).
- /home/cfutro/docs/world/biosphere/notes/ecological-climate-forcing-audit.md: REQ-BIO-002.
- /home/cfutro/docs/world/biosphere/notes/implicit-earth-assumptions.md: REQ-BIO-005 (old_path); findings 3, 5, 6 in REQ-BIO-007 and REQ-BIO-003; finding 7 in REQ-BIO-020.
- /home/cfutro/docs/world/biosphere/notes/vesperian-polar-type.md: REQ-BIO-006 (old_path).
- /home/cfutro/docs/world/biosphere/notes/polar-cover-cold-filter-and-capture.md: REQ-BIO-006.
- /home/cfutro/docs/world/biosphere/notes/underoccupied-niches.md: REQ-BIO-004 and REQ-BIO-006.
- /home/cfutro/docs/world/biosphere/notes/plant-physiology-carbon-allocation-audit.md: REQ-BIO-007 (old_path).
- /home/cfutro/docs/world/biosphere/notes/plant-hydraulics-groundwater-audit.md: REQ-BIO-008 (old_path); findings 5 and 6 in REQ-BIO-019.
- /home/cfutro/docs/world/biosphere/notes/demography-disturbance-dispersal-audit.md: REQ-BIO-009 (old_path).
- /home/cfutro/docs/world/biosphere/notes/phosphorus-cycle-parameterisation.md: REQ-BIO-010.
- /home/cfutro/docs/world/biosphere/notes/soil-decomposition-biogeochemistry-audit.md: REQ-BIO-010; finding 8 in REQ-BIO-011.
- /home/cfutro/docs/world/biosphere/notes/mineral-reactivity-contract.md: REQ-BIO-010.
- /home/cfutro/docs/world/biosphere/notes/soil-phosphorus-input-parameterisation.md: REQ-BIO-012 and REQ-BIO-010.
- /home/cfutro/docs/world/biosphere/notes/soil-nitrogen-transformation-parameterisation.md: REQ-BIO-011 (old_path).
- /home/cfutro/docs/world/biosphere/notes/abiotic-nutrient-ledger.md: REQ-BIO-012 (old_path).
- /home/cfutro/docs/world/biosphere/notes/abiotic-nutrient-delivery-audit.md: REQ-BIO-012.
- /home/cfutro/docs/world/biosphere/notes/equilibrium-trend-null.md: REQ-BIO-014 (old_path).
- /home/cfutro/docs/world/biosphere/notes/fire-model-audit.md: REQ-BIO-015 (old_path); findings 6, 10, 11, 14, 15 in REQ-BIO-016.
- /home/cfutro/docs/world/biosphere/notes/fire-nitrogen-range.md: REQ-BIO-016 (old_path); the input-side bounds in REQ-BIO-013.
- /home/cfutro/docs/world/biosphere/config/fire.yaml: REQ-BIO-015 and REQ-BIO-016.
- /home/cfutro/docs/world/biosphere/notes/wetland-activation-contract.md: REQ-BIO-017 (old_path).
- /home/cfutro/docs/world/biosphere/notes/wetlands-peat-methane-audit.md: REQ-BIO-017.
- /home/cfutro/docs/world/biosphere/notes/reduced-wetland-form.md: REQ-BIO-017.
- /home/cfutro/docs/world/biosphere/notes/bvoc-activation-contract.md: REQ-BIO-018 (old_path).
- /home/cfutro/docs/world/biosphere/notes/bvoc-soa-atmospheric-coupling-audit.md: REQ-BIO-018 (old_path).
- /home/cfutro/docs/world/biosphere/notes/soil-land-surface-hydraulic-consistency-audit.md: REQ-BIO-019 (old_path).
- /home/cfutro/docs/world/biosphere/README.md: sections on the port and calendar in REQ-BIO-001; forcing transport in REQ-BIO-002; PFTs and the photon conversion in REQ-BIO-003 and REQ-BIO-006; the diurnal-range blindness in REQ-BIO-004; seasonal landmarks in REQ-BIO-005; equilibrium acceptance, consumer reads and run lengths in REQ-BIO-014; the fire registers in REQ-BIO-015 and REQ-BIO-016.
- /home/cfutro/docs/world/lib/lpj_output.py: REQ-BIO-014.
- /home/cfutro/docs/world/notes/external-model-survey.md sections 23, 38, 41, 51, 54: REQ-BIO-019, REQ-BIO-003, REQ-BIO-008, REQ-BIO-015 and REQ-BIO-001 with REQ-BIO-009 respectively; section 51 also in REQ-BIO-020.
- /home/cfutro/docs/world/vendor/lpjml: REQ-BIO-020 (old_path; vendored and never read beyond its fire module).

## Reviewed by area: proc


One line per old audit or document judged not to carry on its merits for a generic
exoplanet builder. Every whole document assigned to this pass carried at least one
requirement (the table in the handoff names each record), so the lines below are the
parts of those documents judged not to carry, keyed by path and section, each with the
record that holds whatever lesson survived. A configuration-specific number, an
old-stack tooling defect, or a verdict on a tool the new project does not use is not a
requirement.

- /home/cfutro/docs/world/notes/audits/missed-couplings.md, finding 5 (the clamped aerodynamic term firing on 29.3 per cent of land): knocked down by the audit itself; the clamp was a cold-cell phenomenon that did not reach the verdict. Recorded there so it is not found again; no lesson beyond REQ-PROC-003's rule that a limiter's binding regime is reported.
- /home/cfutro/docs/world/notes/audits/missed-couplings.md, finding 3 as a tooling defect (a generated JSON edited by hand and the edit discarded): the specific file is the old stack's; the rule that a generated artifact is never hand-edited is REQ-PROC-001.
- /home/cfutro/docs/world/notes/audits/physics-review.md, the knocked-down items (the lapse rate Earth-like because latent heat sets it; the Hadley width moving 4 per cent because g H = R T cancels gravity; the Rayleigh column mass carrying an explicit gravity factor): correct negatives about one configuration, not requirements. The habit of recording a negative with its evidence is REQ-SYS-008.
- /home/cfutro/docs/world/notes/audits/physics-review.md, finding 2's mechanism (a namelist rebuilt by a continuation driver dropping the spectrum file): an old-stack defect. The lesson, that the spectrum a run used is in its identity and verified before the first step, is REQ-SYS-005.
- /home/cfutro/docs/world/notes/audits/pipeline-bookkeeping.md, findings 2, 3 and 5 (the planner's hours count structurally zero; one climatology step where the loop ran two; the output bin weighting measured at under two basins): defects of a step-typed YAML graph and a twelve-bin climatology that do not exist in one process on one clock. The lesson that a planner's warning is a measurement and status is computed from the store is REQ-SYS-008.
- /home/cfutro/docs/world/notes/audits/docs-restructure-audit.md, the four specific acceptances (which magnitudes stayed in which chapter; the illustrative pair in a builds reference; the pointer-table overlap; the chapter numbering): properties of the old book. The rule that an acceptance is recorded as a decision where a reader would re-litigate it is REQ-PROC-002.
- /home/cfutro/docs/world/notes/audits/tuned-values.md, the per-row values and their dispositions (the design flux, the canopy scalar, the regolith coefficients, the eddy wind, the cloud coefficients, the roughness field, the mixing length, the soil nitrogen constants, the cloud onset thresholds, the sigma quartic slope, the biosphere constants, the vendored ocean tier): configuration-specific and old-stack values, not carried as numbers. The disposition space, the merit tests and the worked shapes (a constant that derived into a form; a target set by an undeclared size floor; a coefficient with the wrong dependence that therefore could not be sourced) are REQ-SYS-001 and REQ-SYS-004.
- /home/cfutro/docs/world/notes/audits/frozen-derived-quantities.md, the sixty-four instances and their tiers: the instances are the old tree's. The class, its boundary, the two dispositions and the currency rule are REQ-SYS-002.
- /home/cfutro/docs/world/notes/audits/loop-exit-predicates.md, the specific commands and sidecars (which scripts wrote which rung; which flag bypassed which guard): old-stack. The failure shapes are REQ-PROC-006.
- /home/cfutro/docs/world/docs/src/reference/design-intent.md, the two configuration decisions (the cloud droplet effective radius carried implicitly in Stephens (1978)'s fits and declared rather than absent; the broadband radiation scheme kept and a correlated-k replacement refused on a measured 8.6x price): decisions about that stack's radiation scheme, superseded by B2's line-by-line pipeline. The rule that a refusal on price fixes its criterion first and keeps its holes open is REQ-PROC-005; the rule that a scheme's implicit inputs are declared rather than absent is REQ-SYS-005.
- /home/cfutro/docs/world/docs/src/pipeline/loops.md, the specific loop inventory (the terrain-climate carve, the offline ocean cross-pass partition with its transport-loop axes, the cut dust loop, the open carbon loop with fixed CO2): the loops of a pipeline of separate processes, unrepresentable under A5 and B9. The invariant, the antitone bracket and the finalizer are REQ-SYS-007 and REQ-PROC-007; the carbon loop's "land area, not weathering intensity" and "check which class is on top" are B8's concern and are left to the pedology and carbon records.
- /home/cfutro/docs/world/docs/src/practice/conventions.md, the YAML 1.1 exponent rule as stated (PyYAML `safe_load`, `5.0e+4`): a property of one parser. The general rule, a declared numeric resolves as a number and quoting is the statement of intent, is REQ-PROC-001. The `batch:<n>` blast-radius labels and the `needs-decision` versus `needs-permission` labels: the old tracker's labels; the distinction between annotation and verdict is REQ-PROC-002 and the two end states are REQ-PROC-009.
- /home/cfutro/docs/world/docs/src/practice/working-agreements.md, the incident specifics (the CLIM-11/CLIM-31 pair, the three handoffs, the pH parent-supply and melange rows): kept in the record as the one-line cost history only; REQ-PROC-009.
- /home/cfutro/docs/world/docs/src/reference/vocabulary.md, the pipeline nouns (build, base, interim, generation, bootstrap run, baseline run, commissioning, re-commissioning, iteration, segment, canonical climatology lineage, carve verdict, carve list): the vocabulary of a pipeline of separate processes on frozen artifacts. Not carried as words. The rule that each concept has one word and the four defect classes are REQ-PROC-010 and REQ-SYS-001.
- /home/cfutro/docs/world/docs/src/reference/no-time-axis.md, the fact (the terrain generator has no time axis) and the three specific applications (flood basalts and andic soils; komatiite nickel; the incision coefficient): superseded by B1's two clocks and B5's carve as a process. The lessons are REQ-PROC-011.
- /home/cfutro/docs/world/notes/external-tree-checklist.md, the models column and section citations per item, and the single-model observations table: evidence for the class counts, not requirements; kept by reference in REQ-PROC-008, whose rule is that a single-tree observation is promoted at its second instance.
- /home/cfutro/docs/world/notes/external-model-survey.md, section 1 (no existing family covers a non-Earth planet with a land surface, drainage and biosphere): the finding that motivates building rather than adopting; it is the plan's context and a decision record's concern, not a requirement. Section 2's cost figures: measurements of other people's models and the old stack; the like-for-like rule is REQ-PROC-005. Section 5's verdict on a CMIP-class Julia stack: A8's ecosystem verdicts own it; the borrowable enumeration of planetary parameters is REQ-PROC-008. Section 55's regridding details (ESMF's weight-file format, N-gon triangulation): a tool the one-mesh design does not need; the field-normalisation and coverage-fraction rules are REQ-SYS-009 and the refusal default is REQ-PROC-003. Section 59's architecture choice among three offline and online couplings: superseded by A5's synchronous coupling in one process; the hand-over rule and the tier-cost rule are REQ-SYS-009, and the elimination on tuning is REQ-PROC-004.
- /home/cfutro/docs/world/notes/orchestration-frameworks.md, the verdicts (ESM-Tools no, ESMValTool no, Cylc not assessed, AiiDA the candidate for a spike) and the spike's five questions: evaluations of tools against a pipeline of separate scripts and frozen NetCDF artifacts; A6's content-addressed store and A5's single process make the comparison moot. The lessons (check a claimed limitation against the candidate before recording it; a rejection names the mismatch in kind; loops exit on results, not calendar points; a human gate's answer lands in provenance) are REQ-PROC-008 and REQ-PROC-006.
- /home/cfutro/docs/world/config/planet.yaml, every value: the old configuration. Not carried by rule 2 of the brief. The status vocabulary and its decay rule are REQ-SYS-003.
- /home/cfutro/docs/world/lib/sensitivity.py, /home/cfutro/docs/world/lib/lapse.py, /home/cfutro/docs/world/lib/stellar.py, /home/cfutro/docs/world/lib/orbit.py, the code: not ported. The four docstrings' shared lesson (measure at call time from the artifact the configuration names; one implementation instead of three copies; two checks that can fail with a right answer) is REQ-SYS-002 and REQ-PROC-003; the reference-level and identity lessons are REQ-SYS-005.
