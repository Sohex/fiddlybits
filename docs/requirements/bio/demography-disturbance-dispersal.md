+++
id = "REQ-BIO-009"
title = "Demographic stochastic streams key on physical identity, disturbance is a process with a driver and element destinations, dispersal runs on the land connectivity graph, and patches are samples within a tile rather than places"
old_path = ["/home/cfutro/git/vesper/biosphere/notes/demography-disturbance-dispersal-audit.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the old world's port of a cohort demography model at the archived
commit, and on FATES in /home/cfutro/git/vesper/notes/external-model-survey.md
section 54:

- Every stand initialised its random seed to the same literal; there was no
  root seed in the manifest and no independent streams per cell, stand and
  process, so rank or traversal changes could redefine the scientific
  realisation. The repair keyed separate restart-serialised streams for
  establishment, fire occurrence, fire mortality, background mortality and
  disturbance on the root seed, cell coordinates, stand, replicate and a
  process id, with neither rank nor order in the key.
- Nutrient activation was a hidden stand-replacement event: at a fixed year
  every patch was killed to reach "the right composition faster", a
  synchronous planet-wide disturbance with a live-biomass-to-litter nutrient
  pulse inside the physical trajectory.
- Generic disturbance was a memoryless Bernoulli draw per patch per orbit
  that killed all vegetation, left soil intact and carried no driver, size,
  severity or spatial correlation; the examples it stood for (windthrow,
  landslide) have different material destinations (litter versus export of
  vegetation, litter and soil).
- The within-stand "spatial mass effect" moved no seed between cells; a
  climatically eligible type could appear with no local parent, so the result
  was a potential natural vegetation conditional on an available propagule
  pool, not a prediction of colonisation, isolation or range migration.
- In one model a patch is an area-tracked place (FATES: patches carry area
  summing to a site, an age and fusion rules, so canopy death creates gap
  area while understory death is density loss); in the other a patch is a
  Monte Carlo replicate with no area, aggregated by an unweighted mean.
  Patch count and nominal patch area were part of the model form (Poisson
  establishment scales with area; deaths are drawn on an integer count), and
  changing the patch count reduced noise without testing the same thing.
- Stochastic patches could not stand in for spatial response units: no
  patch count creates a wet valley, an exposed ridge or a groundwater-fed
  fraction. Extensive outputs were scored against full binary land-cell area
  rather than the rootable area.
- Establishment carried a `3 / nwoodypfts` multiplier making three eligible
  woody types the unstated reference richness; mortality was a structural
  model-form choice (Bugmann et al. 2019 show submodels with comparable
  historical behaviour diverging over long runs).

## Why it carries

A6 keys the counter-based RNG on (root seed, support id, cell, process, time
index); A1 makes connectivity an explicit derived graph and mosaic tiles the
spatial response units; A5 gives every store one writer. The findings above
are the biosphere-specific consequences: which processes need separate
streams, what a disturbance must declare to be a process rather than a hazard,
where dispersal reads its graph, and what a patch is allowed to mean. The
demography and range-migration claims a builder can make depend entirely on
these.

## What this system must do

1. Establishment, mortality by cause, fire occurrence, fire mortality and each
   disturbance process draw from separate named stochastic streams keyed by
   (root seed, support id, tile, process, time index) per A6; the key never
   contains a rank, a thread or a traversal position.
2. Disturbance is a set of named processes, each with a driver read from the
   component that owns it (wind as the aerodynamic load, the air density of
   REQ-ATM-017 times the square of the atmosphere's resolved surface wind and
   gustiness, against a critical load that is a strategy trait; mass wasting
   from B1's slope and erosion state, fire from REQ-BIO-015 and REQ-BIO-016,
   flooding from B5), a severity, a size distribution on the tile, and
   explicit carbon, nitrogen, phosphorus and water destinations (litter,
   export to B1's sediment, atmosphere). No memoryless generic complete-kill
   hazard exists; a process the configuration lacks is a declared absence with
   its interface (F2).
3. Dispersal reads the land connectivity graph of A1 with a per-strategy
   dispersal kernel trait, so isolation, refugia, islands and migration speed
   are outcomes. A potential-natural mode with ubiquitous propagules is a
   labelled model-form control, never the default.
4. Patches are Monte Carlo samples of demography within one tile environment;
   tiles from the hierarchy (A1 mosaic) are the spatial response units and
   carry area exactly; every extensive quantity is on tile area. Patch count
   and nominal patch area are declared model-form parameters swept in a
   convergence design that varies root seed, count and area separately before
   a result is accepted.
5. Initialisation accelerators (an analytic soil equilibrium, a
   stand-replacement to reach composition) are excluded from the physical
   trajectory and from every ledger, and the accepted record begins after a
   declared restart-equivalence with the unaccelerated path (REQ-BIO-010).
6. Recruitment, mortality by cause, age and size structure, patch age
   distribution and disturbance fluxes are retained outputs; the mortality
   submodel is a registered model-form bracket (age hazard, growth-efficiency
   and hydraulic failure, REQ-BIO-008), not a retuned coefficient.

## Enforced by

- Fixtures: RNG determinism, key separation and rank and order invariance
  without a model run (C6 thread-count invariance); a dispersal test in which
  an island with no source strategy stays empty unless the graph connects it.
- Type: a `Disturbance` process is constructed only with a driver `Field`, a
  severity and a destination ledger; the `Exchange` closes it (A5).
- Ledgers: element and water closure across every disturbance (C3).
- The C4 mutation run: a seeded stream re-keyed on rank must be caught.

## References

- Smith, B., Prentice, I. C. and Sykes, M. T. (2001). Representation of
  vegetation dynamics in the modelling of terrestrial ecosystems: comparing two
  contrasting approaches within European climate space. Global Ecology and
  Biogeography 10, 621-637. DOI: to confirm. The cohort and patch conception
  as replicate samples.
- Moorcroft, P. R., Hurtt, G. C. and Pacala, S. W. (2001). A method for
  scaling vegetation dynamics: the ecosystem demography model (ED). Ecological
  Monographs 71, 557-586. DOI: 10.1890/0012-9615(2001)071[0557:AMFSVD]2.0.CO;2.
  Area-tracked patches as places.
- Fisher, R. A. et al. (2018). Vegetation demographics in Earth System
  Models: A review of progress and priorities. Global Change Biology 24,
  35-54. DOI: 10.1111/gcb.13910. Absent inter-cell dispersal as a general
  limitation; patch meaning depends on the disturbance scale represented.
- Bugmann, H. et al. (2019). Tree mortality submodels drive simulated
  long-term forest dynamics: assessing 15 models from the stand to global
  scale. Ecosphere 10, e02616. DOI: 10.1002/ecs2.2616.
- Pacala, S. W., Canham, C. D. and Silander Jr, J. A. (1993). Forest models
  defined by field measurements: I. The design of a northeastern forest
  simulator. Canadian Journal of Forest Research 23, 1980-1988.
  DOI: to confirm. Disturbance size and severity change long-term
  composition.
- Hickler, T. et al. (2012). Projecting the future distribution of European
  potential natural vegetation zones with a generalized, tree species-based
  dynamic vegetation model. Global Ecology and Biogeography 21, 50-63.
  DOI: to confirm. Propagules assumed available wherever climate is suitable.
- Koven, C. D. et al. (2020). Benchmarking and parameter sensitivity of
  physiological and vegetation dynamics using the Functionally Assembled
  Terrestrial Ecosystem Simulator (FATES) at Barro Colorado Island, Panama.
  Biogeosciences 17, 3017-3044. DOI: 10.5194/bg-17-3017-2020.
- /home/cfutro/git/vesper/biosphere/notes/spatial-support-ecological-aggregation-audit.md
  finding 5 (one ecological column is not a spatial mosaic).

## Amendments

- 2026-09-08: windthrow driver stated as aerodynamic load with air density
  from REQ-ATM-017 and a critical load trait (audit row 37), from
  notes/findings/2026-09-08-implicit-earth-audit.md
