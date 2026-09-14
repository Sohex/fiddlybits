+++
id = "0018"
title = "One land column, shared by climate and vegetation, on a tile mosaic"
status = "accepted"
date = 2026-09-08
+++

## Decision

There is exactly one land column type, instantiated once per **tile**, and it is the
single owner of soil water, soil heat, snow, canopy water, lake state, glacier surface
mass balance, evaporation and transpiration, runoff and dust emission. The atmosphere
reads its surface fluxes and albedo; the vegetation subsystem reads its soil state and
its assimilation; neither computes any of these itself.

**Why one column.** The predecessor ran two land columns (one inside the climate
model, one inside the vegetation model) and recorded the cost: two snowpacks
insulating differently from the same snowfall, two hydrologies, a land-water ledger
that never closed, and, above all, a climate model whose evaporation had no stomatal,
leaf-area, root or interception term, so a vegetated and a bare cell with the same
soil water evaporated identically. That missing transpiration was worth about one
land runoff on the measured configuration, and runoff was the denominator of the
irreversible drainage decision. One column closes the hole and deletes the
consistency work.

**Tiles.** Each atmosphere column is partitioned by the mesh hierarchy (0005) into
tiles, each an exact area partition of the terrain level's cells: elevation bands by
land-area quantile; a lake tile; a glacier tile; a bare tile (playa, evaporite,
rock); a wetland tile where the topographic-index distribution says so; and an
**island tile** for land inside a cell whose land fraction is below one, so an island
is never rounded to ocean. Atmospheric forcing is downscaled to tiles by the column's
own lapse rate (`Derived` from its profile, never a fixed constant) and by
linear-theory orographic precipitation evaluated on a finer terrain level with the
column's wind and moist stability; the theory's conversion and fallout time scales
are `Derived` from the column microphysics' fall speeds (which carry `g` and the air
density of REQ-ATM-017) or, where a profile runs the theory without that
microphysics, `Bracketed` (dimension s) between the condensation-limited and the
fallout-limited ends.

**Processes and state.**

| process | scheme | constants |
|---|---|---|
| soil water | Richards equation in mixed form, multiple layers to a declared depth plus a weathered-bedrock layer | retention and conductivity from pedology's mineralogy and texture by pedotransfer (`Sourced` regressions with their spread `Bracketed`); matric-potential quantities carry `g` explicitly |
| runoff generation | infiltration excess at the top boundary; saturation excess from a TOPMODEL saturated fraction using the tile's exact topographic-index distribution | decay parameter `Bracketed` |
| groundwater store | per-tile unconfined aquifer with recharge from the Richards bottom flux and baseflow; the spatial water table is solved on the terrain mesh (0019) and returns the shallow-table fraction per tile | none |
| soil heat | multilayer diffusion with phase change; soil ice occupies pore space; the bottom boundary is the basal heat flux the terrain derives per province and age from the lithosphere block of `System` (0004, 0015), read from the terrain and never a constant; permafrost emerges relative to that flux | `Sourced` thermal properties by mineralogy |
| snow | multilayer pack; fresh-snow density from the tile's resolved temperature; compaction with the overburden weight carrying `g` explicitly; prognostic grain size by dry and wet metamorphism; impurity mass from deposition; effective thermal conductivity with its pore-gas conduction and vapour-diffusion parts named; albedo per band by two-stream over grain size and impurities against the declared spectrum; zenith dependence inside the two-stream | fresh-snow density `Bracketed` between the source fit in air temperature (Anderson 1976), with its site and temperature range, and a wet-bulb form (REQ-ATM-010); compactive viscosity `Bracketed` between the dry-cold-snow and the wet-warm-snow ends with the temperature and density range of its fit stated at the entry; the dry-metamorphism rate tables carry the pressure and pore gas they were generated at and are rescaled by the vapour diffusivity of REQ-ATM-017 at the column's pressure, or regenerated from the microphysical model at the run's pressure as a build step; the pore-gas part of thermal conductivity `Derived` from REQ-ATM-017; ice and impurity optical constants `Sourced` |
| canopy | sunlit and shaded big leaves with a leaf boundary-layer conductance on the viscosity and diffusivities of REQ-ATM-017; interception store with a capacity per unit leaf area that is a strategy trait (`Bracketed`, dimension kg m-2 per unit leaf area index, between the film-limited and droplet-limited ends) and a drip rate carrying `g`; two-stream canopy radiative transfer per band; roughness and displacement from canopy height | roughness relations `Sourced` (dimensionless) |
| stomata | optimality conductance coupled to Farquhar assimilation, computed here at the column step so the system's own day and its diurnal range are resolved; the slope is `Derived` from the marginal water-cost trait at the column's CO2 compensation point and CO2 partial pressure, and the water-to-CO2 diffusivity ratio in the conductance relation is read from REQ-ATM-017 for the declared gas mixture | the marginal water cost of carbon is a plant trait (0021); the Earth-air diffusivity ratio is an `EarthRatios` control |
| roots | profile from a rooting-depth trait; uptake weighted by conductance per layer; hydraulic redistribution optional | trait |
| lakes | one-dimensional lake: multilayer temperature with wind-driven eddy diffusivity written on the Coriolis parameter 2 Omega sin(latitude) from `System` (the published form's square root of the sine of latitude is that parameter at one rotation rate and is refused as a latitude selector, REQ-BIO-005), with the surface friction velocity from the air density of REQ-ATM-017 and the water density; ice with snow; freezing point from lake salinity through the water-property door of 0017 inside the Reference-Composition tolerance, and from the brine activity model of 0022 for a closed-basin brine beyond it; depth from hydrology's solved level | eddy diffusivity coefficient `Bracketed` (dimension m2 s-1 per unit of its wind and Coriolis argument) between the published fit and the Ekman-depth derivation |
| evaporation | bulk aerodynamic with Monin-Obukhov stability for every surface, the Obukhov length reading `System.g`; air density, specific heat, molar mass, the water-to-air molar mass ratio in the mixing-ratio conversion, and the condensable's latent heat and saturation curve all read from REQ-ATM-017 at the column's pressure and temperature, never held as constants here; wet fraction from interception | similarity functions `Sourced` (dimensionless) |
| glacier tile | surface energy balance on ice and firn with the same snow model, yielding surface mass balance | `Sourced` |
| dust emission | on bare tiles: saltation with the threshold friction velocity of Shao and Lu (2000) carrying `g`, particle density and the air density of REQ-ATM-017 explicitly, the Earth fit of Iversen and White (1982) the reported distance; the saltation flux and the vertical-to-horizontal flux ratio written with their air-density-over-`g` scaling explicit; the published scheme's reference air density and reference standardised threshold are `EarthRatios` denominators, not constants of the kernel; soil-moisture threshold; drag partition with roughness from the surface class and vegetation cover | `Sourced`; the emission coefficient `Bracketed` (dimensionless) between the two published fitting populations, with the erodibility exponent's fitted range of standardised threshold recorded so a configuration outside it is reported |

Timestep: the atmosphere physics step (0023, fast tier).

**Gas properties have one owner.** Every kernel in the column that needs air
(evaporation and sensible heat, the leaf boundary layer, snow pore vapour, soil gas,
the lake surface exchange, saltation) reads air density, specific heat, molar mass,
the water-to-air molar mass ratio, viscosity, binary diffusivities, mean free path,
and the condensable's latent heat and saturation curve from the gas-mixture property
group of REQ-ATM-017, evaluated at the column's own pressure and temperature; the
column defines none of them and holds no Earth value of any of them.

**Excluded, with reasons.** Penman or Priestley-Taylor evaporation (the column
computes evaporation from its own state and the surface layer; a combination equation
would be a second definition). A separate lake model outside the column (a lake tile
is a column with a water body). Crop and grazing management (0024 reads this column;
it does not modify it in potential mode).

**Exchanges (land column owns soil water, ice and temperature, snow state, canopy
water, runoff, recharge, evaporation and transpiration, sensible heat, tile albedo
and roughness, lake temperature and ice, glacier surface mass balance, dust
emission).** Reads: forcing (atmosphere), leaf area, height, traits and root profile
(vegetation), hydraulic and thermal properties (pedology), tile hypsometry and
topographic index (terrain, hydrology), lake area and level and shallow-table fraction
(hydrology), deposition (atmosphere). Writes: surface fluxes and albedo (atmosphere),
runoff and recharge (hydrology), assimilation and soil state (vegetation), surface
mass balance (cryosphere), emission (atmosphere).

## Alternatives considered

- *Two columns, one per consumer* (the predecessor's arrangement, inherited from
  vendoring two models). Rejected on the evidence above.
- *A bucket column.* Rejected: saturation excess would be the only runoff mechanism,
  there would be no infiltration capacity and no matric potential, and the
  transpiration channel would have nowhere to act.
- *Per-terrain-cell columns instead of tiles.* Rejected for the operating profiles:
  the tile mosaic carries the sub-grid distribution exactly through the hierarchy,
  and a column per terrain cell multiplies memory without changing what the
  atmosphere can see. The interface does not forbid it for a profile that wants it.
- *A combination-equation evaporation alongside the column.* Rejected as a second
  definition of one quantity.

## Consequences

- Transpiration is a first-class channel from the biosphere to the water balance.
- Dust-on-snow has a slot (impurity mass in a layer with a grain size).
- Every evaporation, snow and lake quantity has one owner; the land-water ledger can
  close.
- The island tile is what keeps an archipelago in the climate.

## References

- Lawrence, D. M. et al., "The Community Land Model Version 5: Description of New Features, Benchmarking, and Impact of Forcing Uncertainty", Journal of Advances in Modeling Earth Systems 11 (2019). DOI: 10.1029/2018MS001583
- Celia, M. A., Bouloutas, E. T. and Zarba, R. L., "A general mass-conservative numerical solution for the unsaturated flow equation", Water Resources Research 26 (1990). DOI: 10.1029/WR026i007p01483
- Niu, G.-Y., Yang, Z.-L., Dickinson, R. E. and Gulden, L. E., "A simple TOPMODEL-based runoff parameterization (SIMTOP) for use in global climate models", Journal of Geophysical Research 110 (2005). DOI: 10.1029/2005JD006111
- Beven, K. J. and Kirkby, M. J., "A physically based, variable contributing area model of basin hydrology", Hydrological Sciences Bulletin 24 (1979). DOI: 10.1080/02626667909491834
- Flanner, M. G. and Zender, C. S., "Linking snowpack microphysics and albedo evolution", Journal of Geophysical Research 111 (2006). DOI: 10.1029/2005JD006834
- Flanner, M. G., Zender, C. S., Randerson, J. T. and Rasch, P. J., "Present-day climate forcing and response from black carbon in snow", Journal of Geophysical Research 112 (2007). DOI: 10.1029/2006JD008003
- Anderson, E. A., "A point energy and mass balance model of a snow cover", NOAA Technical Report NWS 19 (1976). Locator: NOAA Tech. Rep. NWS 19
- Medlyn, B. E. et al., "Reconciling the optimal and empirical approaches to modelling stomatal conductance", Global Change Biology 17 (2011). DOI: 10.1111/j.1365-2486.2010.02375.x
- Farquhar, G. D., von Caemmerer, S. and Berry, J. A., "A biochemical model of photosynthetic CO2 assimilation in leaves of C3 species", Planta 149 (1980). DOI: 10.1007/BF00386231
- Raupach, M. R., "Simplified expressions for vegetation roughness length and zero-plane displacement as functions of canopy height and area index", Boundary-Layer Meteorology 71 (1994). DOI: 10.1007/BF00709229
- Hostetler, S. W. and Bartlein, P. J., "Simulation of lake evaporation with application to modeling lake level variations of Harney-Malheur Lake, Oregon", Water Resources Research 26 (1990). DOI: 10.1029/WR026i010p02603
- Smith, R. B. and Barstad, I., "A Linear Theory of Orographic Precipitation", Journal of the Atmospheric Sciences 61 (2004). DOI: 10.1175/1520-0469(2004)061<1377:ALTOOP>2.0.CO;2
- Kok, J. F. et al., "An improved dust emission model - Part 1: Model description and comparison against measurements", Atmospheric Chemistry and Physics 14 (2014). DOI: 10.5194/acp-14-13023-2014
- Shao, Y. and Lu, H., "A simple expression for wind erosion threshold friction velocity", Journal of Geophysical Research 105 (2000). DOI: 10.1029/2000JD900304 (the threshold law)
- Iversen, J. D. and White, B. R., "Saltation threshold on Earth, Mars and Venus", Sedimentology 29 (1982). DOI: 10.1111/j.1365-3091.1982.tb01713.x (the Earth fit reported against)
- Fecan, F., Marticorena, B. and Bergametti, G., "Parametrization of the increase of the aeolian erosion threshold wind friction velocity due to soil moisture for arid and semi-arid areas", Annales Geophysicae 17 (1999). DOI: 10.1007/s00585-999-0149-7
- Marticorena, B. and Bergametti, G., "Modeling the atmospheric dust cycle: 1. Design of a soil-derived dust emission scheme", Journal of Geophysical Research 100 (1995). DOI: 10.1029/95JD00690
- Businger, J. A., Wyngaard, J. C., Izumi, Y. and Bradley, E. F., "Flux-Profile Relationships in the Atmospheric Surface Layer", Journal of the Atmospheric Sciences 28 (1971). DOI: 10.1175/1520-0469(1971)028<0181:FPRITA>2.0.CO;2

## Amendments

- 2026-09-08: soil heat row: the bottom boundary is the terrain's basal heat flux
  from the lithosphere block of System, never a constant (audit row 10), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: snow row: fresh-snow density, compactive viscosity, dry-metamorphism
  rate tables and pore-gas conductivity named with their pressure and gas dependence
  through REQ-ATM-017 (audit rows 11, 27), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: canopy row: interception capacity as a Bracketed trait with drip
  carrying g, and leaf boundary layer on REQ-ATM-017 (audit row 28), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: stomata row: slope Derived from the marginal water-cost trait at the
  column's compensation point, diffusivity ratio from REQ-ATM-017 (audit row 12),
  from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: lakes row: eddy diffusivity written on the Coriolis parameter from
  System rather than a latitude fit (audit row 7), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: evaporation row: Obukhov length reads System.g and every gas property
  comes from REQ-ATM-017 (audit row 9), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: dust emission row: saltation flux scaling and the published scheme's
  Earth reference density and threshold named as EarthRatios denominators (audit row
  8), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: orographic time scales Derived or Bracketed (audit row 29);
  gas-properties ownership paragraph added, from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: lake freezing point through the 0017 door inside the Reference-Composition tolerance and 0022's brine activity model beyond it; fresh-snow density and compactive viscosity `Bracketed` with both ends as in REQ-ATM-010; the dust row names Shao and Lu (2000) as the threshold law, from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-14: snow row: fresh-snow density is `Sourced` from Anderson (1976) eq. 4.22,
  a fit in wet-bulb temperature to LaChapelle's (1969) Alta, Utah plot, with its site
  and temperature range recorded, applied to a wet-bulb temperature computed from the
  column's air temperature, humidity and pressure through REQ-ATM-017; the bracket
  between a fit in air temperature and a wet-bulb form is withdrawn, since the source
  fit is the wet-bulb form. Dust emission row: the emission coefficient is `Sourced`
  from the one least-squares fit of Kok et al. (2014), p. 13033, with the fit's stated
  uncertainty recorded beside it; the bracket between two published fitting
  populations is withdrawn, since the paper reports one. User decision of 2026-09-14,
  raised by notes/findings/2026-09-14-an-audit-of-source-fitness.md; REQ-ATM-010's
  bracket is carried by fiddlybits-b7w.
