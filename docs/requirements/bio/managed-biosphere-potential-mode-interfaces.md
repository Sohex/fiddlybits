+++
id = "REQ-BIO-020"
title = "The managed biosphere is a first-class subsystem whose potential mode reads the strategy space, the land column, the hydrology and the marine ecosystem through declared interfaces fixed before it is built, and whose driven mode extends the same interfaces"
old_path = ["/home/cfutro/git/vesper/vendor/lpjml", "/home/cfutro/git/vesper/notes/external-model-survey.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor vendored a managed-land model for fork-shaped work on
agriculture and never read it beyond its fire module, and never scoped the
marine half at all (measured on the old world's tree at the archived commit:
`vendor/lpjml` is present; the only reading of it recorded is the SPITFIRE
comparison in the external model survey, section 51). Its own vegetation
model's managed-land paths were dormant and made to fail closed because they
carried Earth ordinal sowing and harvest dates (180, 364, 365-day ordinals) and
selected tropical versus temperate crop types at absolute latitude 30 degrees;
the harvested-product turnover rates were per Earth year and never converted,
inert only because no configuration reached them. The plan records both gaps
and puts both halves in scope (B10), potential mode first (F4), with every
interface declared from the start (F2).

Two properties of the predecessor's findings decide the shape of the
interface. First, every reason an Earth crop calendar or crop type does not
transfer is one already recorded for natural vegetation: sowing and harvest
are seasonal landmarks (REQ-BIO-005), crop traits are points in a trait space
with Earth's covariance not imposed (REQ-BIO-006), yields are photon and water
and nutrient outcomes on the planet's own day (REQ-BIO-007, REQ-BIO-003), and
per-year rates are classified (REQ-BIO-001). Second, the water and nutrient
withdrawals of managed land are the double-debit hazard of REQ-BIO-019 in
another form: an irrigation withdrawal that is not a declared sink on the
routing graph spends the same water the column and the river already own.

## Why it carries

B10 is the one subsystem the old project scoped and never built, so there is
no finding to carry and no coupling to invert; what carries is the interface
discipline the rest of the biosphere paid for, applied before a line of the
subsystem exists so that it is an extension of B7, B4, B5 and B3 rather than a
second copy of any of them. The M11 gate (crop and fishery potential against
Earth statistics as REPORT; irrigation ledger closes) is evaluable only if
these interfaces are declared now.

## What this system must do

1. Potential mode is built first as a first-class subsystem with a declared
   interface; driven mode is a declared absence whose interface (an imposed
   land-use and water-use map per tile, a management calendar on the system
   clock, and returned yields, demands and cover changes) is complete from the
   start.
2. Potential mode READS: from B7, the strategy space, in which crop analogues,
   pasture and timber strategies are points in the same trait space (annual
   and perennial life forms, a harvest-index trait, phenology cues derived per
   REQ-BIO-005, the storage-organ trait of REQ-BIO-006) filtered by the tile's
   resolved climate without competition where a managed stand suppresses it;
   from B4 per tile, the same column state as REQ-BIO-019 (soil water and
   temperature by layer, photon flux per band, pressure, humidity, wind,
   precipitation with phase, rootable and other fractions) and the soil
   nutrient state of REQ-BIO-010 and REQ-BIO-012; from B5, river discharge,
   lake level and volume, aquifer store and their seasonal cycle on the routing
   graph, and freshwater lake primary productivity from B5's one-dimensional
   lakes; from B3, primary productivity and community structure of the
   trait-based marine ecosystem per ocean cell and the coastal connectivity
   graph (strait geometry, sill depth, exposure), sea surface temperature,
   salinity, nutrient and light state.
3. Potential mode WRITES, per tile and strategy: potential rain-fed and
   irrigated yield with the irrigation demand that produced it; pasture
   productivity; timber increment from the same wood allocation as B7; and per
   ocean and lake cell, potential fishable production derived from primary
   production through a trophic transfer with `Bracketed` efficiency and
   trophic level, and aquaculture suitability from temperature against the
   thermal traits of the marine (B3) and lake trait communities, never a table
   of another planet's species' thermal ranges, from nutrient supply, from
   shelter (from the connectivity graph and resolved wave and wind exposure)
   and from freshwater supply. Every yield is on the planet's own orbit and
   converted only at reporting (REQ-BIO-001).
4. Irrigation withdrawal is a declared sink on B5's routing graph with one
   owner, drawn from river, lake or aquifer by declared priority, debited once
   by the owning store, and never applied to the column as extra
   precipitation; fertiliser and manure are terms of the nutrient ledger
   (REQ-BIO-012) with a boundary node, never an increment to a pool.
5. Driven mode's feedbacks (albedo per band, roughness, litter, root cohesion,
   erosion, carbon) reach the atmosphere and B1 through exactly the channels of
   REQ-BIO-019; a managed tile is a tile of the same mosaic.
6. Constants are the same biology assumption as B7 (irreducibly Earth:
   Rubisco kinetics, stoichiometry ranges, harvest indices as `Bracketed`
   traits); no yield, catch or suitability metric is ever a target. Earth crop
   yields, catch statistics and aquaculture suitability maps are REPORT metrics
   of the Earth instance (C1 tier 2) and hold-outs (C2).
7. No Earth calendar, latitude-selected crop type, per-Earth-year turnover or
   population field enters the subsystem; the same lints and refusals as the
   rest of the biosphere apply.

## Enforced by

- Type: the managed subsystem is constructed only from the B7 strategy space,
  a B4 tile state, a B5 routing graph and a B3 ecosystem state; a prescribed
  land-use map is accepted only by the driven-mode constructor, which is a
  declared absence until built (F2).
- Ledgers: the irrigation ledger closes on the routing graph (M11 gate);
  nutrient ledger boundary terms for inputs.
- Oracles: the M11 REPORT metrics against Earth yield and catch statistics;
  hold-out scoring at the gate (C2).
- Decision records for B10 and F4.

## References

- Schaphoff, S. et al. (2018). LPJmL4 - a dynamic global vegetation model
  with managed land - Part 1: Model description. Geoscientific Model
  Development 11, 1343-1375. DOI: 10.5194/gmd-11-1343-2018. The managed-land
  reference B10 names.
- Bondeau, A. et al. (2007). Modelling the role of agriculture for the 20th
  century global terrestrial carbon balance. Global Change Biology 13,
  679-706. DOI: 10.1111/j.1365-2486.2006.01305.x. Crop functional types as
  strategies with sowing derived from climate.
- Follows, M. J., Dutkiewicz, S., Grant, S. and Chisholm, S. W. (2007).
  Emergent Biogeography of Microbial Communities in a Model Ocean. Science
  315, 1843-1846. DOI: 10.1126/science.1138544. The trait-based marine
  community B3 supplies.
- Pauly, D. and Christensen, V. (1995). Primary production required to
  sustain global fisheries. Nature 374, 255-257. DOI: 10.1038/374255a0.
  Trophic transfer from primary production to fishable production.
- Ryther, J. H. (1969). Photosynthesis and Fish Production in the Sea.
  Science 166, 72-76. DOI: 10.1126/science.166.3901.72.
- Cheung, W. W. L. et al. (2010). Large-scale redistribution of maximum
  fisheries catch potential in the global ocean under climate change. Global
  Change Biology 16, 24-35. DOI: 10.1111/j.1365-2486.2009.01995.x. Catch
  potential as a function of ecosystem state, an Earth REPORT metric.
- Gentry, R. R. et al. (2017). Mapping the global potential for marine
  aquaculture. Nature Ecology and Evolution 1, 1317-1324.
  DOI: 10.1038/s41559-017-0257-9. Suitability from temperature, depth and
  exposure.
- Kapetsky, J. M. and Aguilar-Manjarrez, J. (2007). Geographic information
  systems, remote sensing and mapping for the development and management of
  marine aquaculture. FAO Fisheries Technical Paper 458, Rome. Locator: FAO
  FTP 458. The suitability framework B10 names.
- Fischer, G. et al. (2021). Global Agro-Ecological Zones v4 - Model
  documentation. FAO, Rome. DOI: to confirm. Crop potential from climate,
  soil and water as an Earth REPORT metric.
- /home/cfutro/git/vesper/biosphere/notes/implicit-earth-assumptions.md
  findings 7 and 8 (the dormant crop calendar and latitude-selected crop
  types).
- /home/cfutro/git/vesper/notes/external-model-survey.md section 51 (the only
  recorded reading of the vendored managed-land model).

## Amendments

- 2026-09-08: aquaculture thermal suitability derived from the trait
  communities' thermal traits (audit row 18), from
  notes/findings/2026-09-08-implicit-earth-audit.md
