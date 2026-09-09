+++
id = "REQ-BIO-019"
title = "Vegetation reads the one land column's state per tile and returns boundary controls and demand; the column computes every water and energy flux and returns fulfilled uptake by source, so no store is debited twice and no second land column exists"
old_path = ["/home/cfutro/docs/world/biosphere/notes/soil-land-surface-hydraulic-consistency-audit.md", "/home/cfutro/docs/world/biosphere/notes/modelling-gap-audit.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor did not have one terrestrial water column; it had two fast
water balances and a third subsurface one (measured on the old world's
ExoPlaSim, LPJ-GUESS-CNP and groundwater pipeline at the archived commit):

- The climate model carried one liquid land bucket, a separate snowpack and
  five soil temperature layers with fixed thermal properties; the vegetation
  model reconstructed rain, snow, melt, interception, fifteen layers of soil
  liquid and ice, evapotranspiration and runoff from the driver, debiting
  nothing the climate had already evaporated; the groundwater solver treated
  positive annual P - E as recharge while the same surplus was also the
  climate's overflow runoff and the catchment's runoff. The same millimetre
  could be evaporated twice and exported three times, so a closed annual P - E
  budget proved nothing about conservation or timing.
- One pedology artifact became two incompatible soils: the climate read one
  clipped capacity, the vegetation derived its own retention from texture
  regressions and ignored the pedology's capacity, bulk density and andic
  effect; the two capacities differed by a median factor of 1.61 with a
  10th-to-90th percentile range of 0.90 to 2.55.
- Vegetation changed the climate's albedo but LAI, roots, interception and
  stomatal state did not control the climate's evaporation; latent heat and
  precipitation partitioning are fast processes that must use the same state
  when the flux is evaluated, so passing soil water after the fact could not
  close the loop.
- Snow, frozen soil and thermal state were reconstructed twice, and the two
  columns disagreed about whether water that reached the ground was liquid.
- The vegetation was not told which ground was barren, lake, salt crust or
  playa, and grew on it; the correction was one provenance-stamped rootable
  fraction per cell derived from the same surface classification and lake
  solution the climate used, governing every extensive quantity and every
  feedback (albedo, forest fraction, roughness, soil carbon, denominators).
  Modelled cover was composited over solved lakes; roughness never received
  modelled vegetation at all.
- The acceptance boundary the audit wrote: identical declared properties at
  each consumer boundary including gravity convention and layer geometry;
  exact closure of precipitation to storage change, evapotranspiration
  components, runoff and drainage; one and only one debit for canopy
  evaporation, soil evaporation, transpiration and groundwater uptake;
  rain-snow and liquid-ice partition closure with energy conserved across
  freeze and thaw; restart equivalence through active intervals; analytic
  reductions in which the multilayer column reproduces the single-bucket case
  and zero groundwater exchange gives the no-groundwater case. Annual P - E
  closure, a plausible LAI map or two agreeing cell-mean capacities are not
  sufficient, since each coexists with compensating errors.

## Why it carries

A5 and B4 make the land column one component read by both climate and
vegetation with one declared writer per quantity, which is the architecture the
audit recommended; that removes the possibility of a second column but does
not by itself say what crosses the seam or in which direction. This record is
that interface, fixed now under the founding principle that every interface is
nailed out of the gate (F2), so that vegetation work (M5, M9) and managed land
(M11) extend the same seam rather than reopen it.

## What this system must do

1. Vegetation holds no water, snow, soil heat or surface energy state. Per
   tile of the mosaic (A1) at the column step, it READS from B4: soil liquid
   and ice by layer with the layer's water potential, soil temperature by
   layer, snow depth and water equivalent, canopy and surface temperature,
   incident direct and diffuse photon flux per band (REQ-BIO-003), pressure,
   specific humidity, wind at a declared height, the gas-mixture properties of
   REQ-ATM-017 at that pressure and temperature, precipitation with phase, the
   tile's aquifer store and water-table depth, and the tile's rootable, lake,
   glacier, wetland and bare fractions with their areas from the hierarchy.
2. Vegetation RETURNS to B4 per tile: leaf area and canopy structure (height,
   cover, clumping, leaf angle) for two-stream radiation and roughness;
   per-band leaf optics (REQ-BIO-003); stomatal conductance by the Medlyn
   relation and transpiration demand per soil layer on the root profile
   (REQ-BIO-008); interception capacity; litter mass and chemistry by depth;
   and root cohesion and cover to B1's erosion terms (B1 reads them). B4
   evaluates every flux (interception, canopy and soil evaporation,
   transpiration, uptake from layers and aquifer, infiltration, drainage,
   runoff, snowmelt, soil freeze and thaw) once, and returns to vegetation the
   fulfilled uptake by source. Each store is debited exactly once; the
   vegetation never withdraws.
3. Soil hydraulic and thermal properties come from one pedology artifact (B8)
   read by the column alone, with the organic term updated from the
   biosphere's soil carbon through that artifact; no consumer derives its own
   retention curve, and the retention closure is a named property with its
   family stated.
4. Every extensive vegetation quantity is on the tile's rootable area from
   the hierarchy; feedback fields (albedo per band, roughness, forest
   fraction, litter, cohesion) are composited on the same partition, leaving
   water tiles at water values with zero forest.
5. The coupling is synchronous at the column step (the daily tier of 0023
   reading the fast tier's state within one process); no vegetation control
   computed from a later climate segment is applied to that segment.
6. Acceptance at the seam: identical declared properties at both consumers,
   exact closure of the water and energy ledgers over an orbit, one debit per
   evaporative term, phase closure with energy across freeze and thaw, restart
   equivalence through active intervals, and the analytic reductions
   (multilayer to single bucket; zero exchange to no groundwater).

## Enforced by

- Type: `WorldState` declares B4 as the sole writer of every water, snow and
  soil heat quantity and vegetation as the sole writer of canopy structure,
  demand and litter; `assemble` refuses a second writer (A5).
- Ledgers: the `Exchange` at the seam closes water and energy every column
  step; the M5 gate item "ledgers closed at the seam".
- Oracles: the bucket and no-groundwater reductions (C3); Richards and
  Stefan analytics on the column; site-level benchmarks on the Earth
  instance (M5).

## References

- Clark, M. P. et al. (2015). A unified approach for process-based hydrologic
  modeling: 1. Modeling concept. Water Resources Research 51, 2498-2514.
  DOI: 10.1002/2015WR017198. Separating the conservation core and state
  ownership from flux parameterisation and spatial representation.
- Best, M. J. et al. (2011). The Joint UK Land Environment Simulator (JULES),
  model description - Part 1: Energy and water fluxes. Geoscientific Model
  Development 4, 677-699. DOI: 10.5194/gmd-4-677-2011. One coupled surface
  balance including interception, infiltration, root extraction, Richards
  flow and phase-aware heat.
- Lawrence, D. M. et al. (2019). The Community Land Model Version 5:
  Description of New Features, Benchmarking, and Impact of Forcing
  Uncertainty. Journal of Advances in Modeling Earth Systems 11, 4245-4287.
  DOI: 10.1029/2018MS001583. The column structure B4 models on.
- Essery, R. L. H., Best, M. J., Betts, R. A., Cox, P. M. and Taylor, C. M.
  (2003). Explicit Representation of Subgrid Heterogeneity in a GCM Land
  Surface Scheme. Journal of Hydrometeorology 4, 530-543.
  DOI: to confirm. Tiled against aggregate surfaces under coupled feedback.
- Medlyn, B. E. et al. (2011). Reconciling the optimal and empirical
  approaches to modelling stomatal conductance. Global Change Biology 17,
  2134-2144. DOI: 10.1111/j.1365-2486.2010.02375.x.
- /home/cfutro/docs/world/notes/external-model-survey.md section 23 (the
  retention closure as a named property; standalone column components against
  a shared interface).
- /home/cfutro/docs/world/biosphere/notes/plant-hydraulics-groundwater-audit.md
  findings 5 and 6 (one conserved withdrawal; the two-way coupling precedent).

## Amendments

- 2026-09-08: gas-mixture properties of REQ-ATM-017 added to what vegetation
  reads; cadence wording replaced by the daily tier of 0023 (audit row 9),
  from notes/findings/2026-09-08-implicit-earth-audit.md
