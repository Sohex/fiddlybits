+++
id = "0024"
title = "Managed biosphere: agriculture, grazing, forestry, irrigation, fisheries and aquaculture, potential mode first"
status = "accepted"
date = 2026-09-08
+++

## Decision

A first-class subsystem covering what a population could grow, graze, cut, catch and
farm, on land and in water. The predecessor vendored a managed-land model for this
purpose and never built it, and never scoped the marine half.

**Two modes, one interface, declared from the start.**

- *Potential mode* (built first). A pure function of the run: crop-analogue
  strategies drawn from the vegetation trait space (0021) under each tile's
  climate, soil and water (0018, 0022); pasture productivity; timber increment;
  marine productivity from the ocean's trait community (0017) and freshwater
  productivity from the lakes (0018, 0019); aquaculture suitability from
  temperature against the thermal traits of the marine and lake trait communities
  (0017, 0018), never a table of another planet's species' thermal ranges, from
  nutrients, from shelter (from the connectivity graph and coastal geometry) and
  from freshwater supply. Yields are radiation-use and water-use limited through
  the same photosynthesis the column computes; fishery potential is bounded by
  primary production and a declared trophic transfer efficiency (`Bracketed`).
- *Driven mode* (later). A declared land-use and water-use map is imposed; the
  subsystem returns yields, irrigation demand against hydrology's supply (a declared
  sink on the routing graph, 0019), nutrient exports to rivers and coast, and the
  land-cover changes that feed back to albedo, roughness, erosion (0015) and carbon
  (0022). The input map is a design object with its own record when the mode is
  built; its interface (a per-tile use fraction and a per-catchment withdrawal) is
  declared now so nothing is retrofitted.

**Constants.** The biology assumption of 0021 (`Irreducible`); harvest indices and
trophic efficiencies `Bracketed`; everything else derived from the run.

**Exchanges (managed biosphere owns potential and, in driven mode, realised yields,
withdrawals, nutrient exports and use-driven cover change).** Reads: strategy space
and productivity (vegetation), soil and water (land column, pedology, hydrology),
marine and lake productivity (ocean, land column), coastal geometry (mesh). Writes
(driven mode only): withdrawals (hydrology), cover change (land column, vegetation,
terrain), nutrient exports (hydrology).

## Alternatives considered

- *Defer the whole subsystem with only interfaces declared.* Rejected: the marine
  community and the trait space need their consumers named early; potential mode is
  a small step once they exist and it is the first thing a worldbuilder asks.
- *Driven mode first.* Rejected: it needs an input map that does not exist until a
  world does, and its feedbacks reach several subsystems that should be validated
  unmanaged first.
- *A separate crop model with its own physiology.* Rejected as a second definition of
  photosynthesis; crops are strategies in the same space.

## Consequences

- The vegetation, ocean and hydrology interfaces carry a declared consumer from the
  start.
- Yield and catch are reported as potentials with their brackets; the Earth distance
  report (0025) scores them as REPORT, never PASS or FAIL, because they depend on
  practices the model does not declare.

## References

- Schaphoff, S. et al., "LPJmL4 - a dynamic global vegetation model with managed land - Part 1: Model description", Geoscientific Model Development 11 (2018). DOI: 10.5194/gmd-11-1343-2018
- Bondeau, A. et al., "Modelling the role of agriculture for the 20th century global terrestrial carbon balance", Global Change Biology 13 (2007). DOI: 10.1111/j.1365-2486.2006.01305.x
- Monteith, J. L., "Climate and the efficiency of crop production in Britain", Philosophical Transactions of the Royal Society B 281 (1977). DOI: 10.1098/rstb.1977.0140
- Pauly, D. and Christensen, V., "Primary production required to sustain global fisheries", Nature 374 (1995). DOI: 10.1038/374255a0
- Ryther, J. H., "Photosynthesis and Fish Production in the Sea", Science 166 (1969). DOI: 10.1126/science.166.3901.72
- Gentry, R. R. et al., "Mapping the global potential for marine aquaculture", Nature Ecology and Evolution 1 (2017). DOI: 10.1038/s41559-017-0257-9
- Fischer, G. et al., "Global Agro-Ecological Zones (GAEZ v4) - Model Documentation", FAO and IIASA (2021). Locator: FAO/IIASA GAEZ v4 documentation

## Amendments

- 2026-09-08: aquaculture thermal suitability derived from the trait communities'
  thermal traits, with Earth species ranges confined to the Earth REPORT metric
  (audit row 18), from notes/findings/2026-09-08-implicit-earth-audit.md
