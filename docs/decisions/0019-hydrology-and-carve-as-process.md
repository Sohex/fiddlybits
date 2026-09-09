+++
id = "0019"
title = "Hydrology on the terrain mesh, with drainage change as a process rather than a verdict"
status = "accepted"
date = 2026-09-08
+++

## Decision

Hydrology runs on the terrain level at the terrain timestep, with a fast routing
surrogate at the column step. It owns the drainage graph, lake levels, areas, volumes
and overflow, river discharge, the water table, the topographic index, the wetness
classes, and the delivery of water and solute to lakes and the ocean.

**Drainage and lakes: depression hierarchy plus fill-spill-merge.** The depression
hierarchy is built from the terrain state (a sequential algorithm on the CPU backend,
0011); it is cached until the terrain changes. Fill-spill-merge then routes any
runoff field through it and yields every lake's level, area, volume and overflow at
once, conserving water by construction. Lake evaporation enters from the column's
open-water evaporation on the lake tile (0018), with the open-water roughness of 0016 and the
air properties of REQ-ATM-017 (REQ-HYD-007); the equilibrium condition for a closed
lake, area times net evaporation equals inflow, is a property of the cascade, not a
separate solver, and a lake that reaches its spill passes the excess down the
cascade.

**Discharge.** Tile runoff (0018) maps to terrain cells by elevation-band membership,
an exact partition, so the water ledger closes; accumulation follows the graph;
overflow is routed from sills. Coastal delivery uses embayment-first spreading into
the ocean's coastal cells (0017).

**Drainage change as a process.** There is no carve verdict. The terrain subsystem
(0015) reads, per sill, the overflow discharge and the time fraction the basin spent
overflowing across the climate statistics the slow tier accumulates, and incises with
its own law. A basin that never overflows is never cut; a basin that overflows only
in the wet phase of the stellar cycle is cut in proportion to that phase. The
predecessor's antitone bracketing (a larger set of cut basins produced a smaller next
verdict, so verdicts oscillated) is replaced by integrating a slow threshold process
against a fast variable forcing, which is what the physical situation is. The
ratchet toward the wet extreme is an outcome of the threshold, not a rule.

**Groundwater.** Steady unconfined water table on the terrain mesh as a
box-constrained linear complementarity problem (head cannot exceed the surface; where
it would, the excess is discharge). Transmissivity from permeability by
hydrolithology (`Sourced` compilation, its decade-scale spread `Bracketed`) with
conductivity `K = k rho_w g / mu`, where `g` is the system's and `rho_w` and `mu` are
read from the water-property door of 0017 (pure-water limb) at the column's mean
soil temperature, so a warm or cold configuration's
aquifers are not another planet's by default; the source's depth of validity floors
the saturated thickness (REQ-HYD-003). Solved by multigrid-preconditioned
iteration on the hierarchy; rivers and lakes are fixed heads. Returns the shallow-table
fraction per tile and groundwater discharge to lakes and coast. Depth-dependent
transmissivity forms that do not average across a cell are refused, because the
predecessor measured that their cell mean is meaningless at this spacing.

**Topographic index and wetness.** Computed per terrain cell and reduced to tiles as
*areas* (the share of a tile above a threshold), never as a mean depth, because a
mean of a nonlinear function is not the function of the mean.

**Fast routing.** At the column step a linear-reservoir cascade per catchment carries
discharge to the outlet with a delay, so the ocean receives river water on the fast
tier. The delay is `Derived` from the reach length along the graph and a
Darcy-Weisbach velocity `sqrt(8 g R_h S / f)`, with `g` from `System`, the hydraulic
radius `R_h` from the threshold-channel relation of 0015 and the friction factor `f`
`Bracketed` between the smooth-bed and the coarse-bed ends; a Manning coefficient,
whose dimension hides a power of gravity, is refused by the dimension type.
Irrigation withdrawals from the managed biosphere (0024) are a declared sink on
the same graph.

**Solute routing.** Pedology's solute fluxes (0022) follow the same graph to lakes
(brine chemistry) and to the ocean (salinity, alkalinity, phosphorus).

**Exchanges (hydrology owns the drainage graph, lake state, discharge, overflow,
water table, topographic index, wetness classes, solute delivery).** Reads: terrain,
tile runoff, recharge and open-water evaporation (land column), solute production
(pedology), withdrawals (managed biosphere). Writes: overflow statistics (terrain),
lake area and level and shallow-table fraction (land column), river water and solute
(ocean), wetness (vegetation), brine inputs (pedology).

## Alternatives considered

- *Priority-flood drainage with a separate closed-form lake solver and an external
  carve verdict* (the predecessor). Rejected: three artifacts for one water balance,
  and a verdict whose antitone map could only bracket.
- *A routing scheme that fills every depression to its spill* (the common
  land-surface default). Rejected: it deletes closed basins, which are a large share
  of the land on many configurations and are the subject of the drainage question.
- *Direct factorisation for the water table.* Rejected: the fill at the terrain
  cell count is prohibitive; the multigrid iteration is the fit for the hierarchy.
- *Depth-decaying transmissivity averaged per cell.* Rejected on the predecessor's
  measurement that the cell mean diverges.

## Consequences

- Loop A of the predecessor no longer exists as a loop; drainage change is part of
  the slow tier's integration (0023).
- Every lake is a water body with a level and a balance, on every tier.
- The water ledger closes across land column, hydrology and ocean by construction of
  the partitions.
- The depression hierarchy is the one sequential bottleneck of the slow tier and is
  cached accordingly.

## References

- Barnes, R., Callaghan, K. L. and Wickert, A. D., "Computing water flow through complex landscapes - Part 1: The depression hierarchy", Earth Surface Dynamics 8 (2020). DOI: 10.5194/esurf-8-431-2020
- Barnes, R., Callaghan, K. L. and Wickert, A. D., "Computing water flow through complex landscapes - Part 3: Fill-Spill-Merge: flow routing in depression hierarchies", Earth Surface Dynamics 9 (2021). DOI: 10.5194/esurf-9-105-2021
- Gleeson, T., Smith, L., Moosdorf, N., Hartmann, J., Duerr, H. H., Manning, A. H., van Beek, L. P. H. and Jellinek, A. M., "Mapping permeability over the surface of the Earth", Geophysical Research Letters 38 (2011). DOI: 10.1029/2010GL045565
- Fan, Y., Li, H. and Miguez-Macho, G., "Global Patterns of Groundwater Table Depth", Science 339 (2013). DOI: 10.1126/science.1229881
- Beven, K. J. and Kirkby, M. J., "A physically based, variable contributing area model of basin hydrology", Hydrological Sciences Bulletin 24 (1979). DOI: 10.1080/02626667909491834
- Tarboton, D. G., "A new method for the determination of flow directions and upslope areas in grid digital elevation models", Water Resources Research 33 (1997). DOI: 10.1029/96WR03137
- Henderson, F. M., "Open Channel Flow", Macmillan (1966). ISBN: to confirm (the Darcy-Weisbach form with gravity explicit)

## Amendments

- 2026-09-08: conductivity written as `K = k rho_w g / mu` with `rho_w` and `mu` from the water-property door of 0017 at the column's soil temperature (row 16), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: fast-routing delay derived from a Darcy-Weisbach velocity with `g` explicit, Manning refused by dimension (row 18); lake evaporation pointed to REQ-HYD-007 for roughness and air properties (row 20), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: `rho_w` and `mu` read from the water-property door of 0017 (pure-water limb); lake evaporation's roughness pointed at 0016's one definition, from notes/findings/2026-09-08-implicit-earth-audit.md
