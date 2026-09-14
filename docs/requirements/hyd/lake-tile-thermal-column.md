+++
id = "REQ-HYD-010"
title = "A sub-grid lake is a tile with its own thermal column, ice and salinity bracket, not a land column with a wetter bucket"
old_path = ["/home/cfutro/git/vesper/notes/audits/surface-hydrology-fire-carbon-followup.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The audit (read 2026-08-21, no model run) examined five proposed omissions. Its
fourth finding is this area's: the predecessor's sub-grid lakes were land cells with a
modified albedo and a deeper bucket, so they inherited a soil thermal column and had
the wrong thermal material, depth, mixing, phase and surface-flux state rather than
zero heat capacity. Bernus and Ottle (2022) found seasonal temperature differences of
several kelvin for large or deep lakes and materially different evaporation when a
lake energy balance replaced bare soil; their lake model is freshwater, and they name
salinity as a cause of lake-temperature error through albedo, evaporation and seasonal
thermal behaviour, which matters for closed basins that can be saline or briny. The
audit's prescription: a reduced seasonal bound per basin from area and hypsometric
depth, crossing depth and ice physics with a freshwater-to-brine property bracket, and
a test on basins near their overflow margin rather than an assertion from lake area.

The same physics appeared from the other side in
`/home/cfutro/git/vesper/hydrography/notes/carve-verdict-interval.md`: an open-water
evaporation scheme with no heat storage, evaluated on annual-mean air, is the limit for
a lake deep enough to hold its temperature through the year; evaluated per interval
and averaged, it is the limit for a lake with no heat capacity; the spread between
them (1.57x over land on the predecessor's climatology) is the water body's own heat
storage, and the ocean, where the model carries real storage, put the per-interval
overestimate at 14%, an upper bound because an ocean stores more heat than any lake
while a shallow playa stores almost none.

The audit's third finding, that both dust emission paths read a scalar soil-water
bucket and none saw groundwater-fed wetness, an explicit top layer, the liquid-ice
partition or a wet-dry sub-grid mosaic, resolves to ownership: dust reads the top
emitting layer's liquid-water state from the one land column, including bulk density,
texture, frozen water, capillary supply and emitting-area fraction. Findings 1, 2 and
5 belong to other areas and are routed, not dispositioned, here: forest snow masking
is a structural operator (the gap-fraction form of Essery 2013) driven by canopy
structure, not a scalar mask; fire needs a persistent surface-disturbance state
(severity, char, bare and standing-dead cover, time since fire) whose albedo sign is
not universal, since canopy loss raises spring albedo for decades; the outgassing
capacity question is REQ-PED-011.

## Why it carries

B4 gives every column 1-D lakes with ice among its tiles and bulk aerodynamic
evaporation everywhere; B3 carries salinity as a real budget with evaporite sinks; B5
supplies lake level, area and volume; B9 resolves the stellar cycle. A water body's
heat capacity is a state of the system, and an evaporation scheme without it is
bracketed by two limits whose spread is exactly that state. The requirement is
planet-independent and is what makes REQ-HYD-007's interval bracket collapse.

## What this system must do

- Each column's lake tile is a 1-D thermal column with depth from the basin's
  hypsometry (level, area, volume from the terrain level), a mixed layer, ice with its
  own optics, and evaporation from the column's own surface temperature with water's
  roughness at the column step (REQ-HYD-007); its area is the lake solution's
  (REQ-HYD-011). The mixed layer's buoyancy terms (reduced gravity, the Richardson
  and Wedderburn numbers) carry `g` from `System` and water density from the water-property door of 0017
  at the lake's own salinity inside the Reference-Composition tolerance, and from
  the brine activity model of 0022 beyond it; any fitted
  diffusivity coefficient the mixing scheme carries is `Bracketed` between its
  wind-stirred and convective ends with its full dimension stated, and the Earth
  lake it was fitted on is the reported distance.
- Lake salinity comes from the basin's solute budget (river solute in, evaporite sink
  out, B3 and REQ-PED-008) and sets the freezing point and the evaporation reduction:
  inside the Reference-Composition tolerance the lake reads the water-property door
  of 0017 at that salinity, and a closed-basin brine beyond the tolerance reads its
  density and freezing point from the brine activity model of 0022 (0018,
  REQ-ATM-012); where the brine chemistry is unresolved the property is Bracketed between fresh and
  brine ends and both ends are carried.
- With storage on, the annual and per-step evaporation limits are an identity check
  bounding the column's evaporation, and the residual between them is reported as the
  storage term, never as a scheme error.
- Dust emission on bare and playa tiles reads the top layer's liquid state from the one
  column; no second soil-water state exists.
- Routed to other areas: canopy snow masking as a structural operator (B4); fire
  disturbance state with a non-universal albedo sign (B7).

## Enforced by

C3 single-column oracles (Stefan ice growth analytic; the storage identity); M5
site-level lake benchmarks; A5 tile ownership at assemble; the ledger (REQ-HYD-012)
booking lake evaporation on the open-water area.

## References

- Modeling subgrid lake energy balance in ORCHIDEE terrestrial scheme using the FLake
  lake model. Bernus, Ottle (2022), Geoscientific Model Development 15, 4275-4295.
  DOI: 10.5194/gmd-15-4275-2022
- Parameterization of lakes in numerical weather prediction. Description of a lake
  model. Mironov (2008), COSMO Technical Report 11, Deutscher Wetterdienst. DOI:
  10.5676/DWD_pub/nwv/cosmo-tr_11
- Simulation of lake evaporation with application to modeling lake level variations of
  Harney-Malheur Lake, Oregon. Hostetler, Bartlein (1990), Water Resources Research 26,
  2603-2612. DOI: 10.1029/WR026i010p02603
- An improved lake model for climate simulations: Model structure, evaluation, and
  sensitivity analyses in CESM1. Subin, Riley, Mironov (2012), Journal of Advances in
  Modeling Earth Systems 4, M02001. DOI: 10.1029/2011MS000072
- Large-scale simulations of snow albedo masking by forests. Essery (2013), Geophysical
  Research Letters 40, 5521-5525. DOI: 10.1002/grl.51008

## Amendments

- 2026-09-08: mixed-layer buoyancy terms stated to carry `g` and the water EOS, fitted mixing coefficients Bracketed with dimension (row 21), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: water properties read from the 0017 door at the lake's salinity inside the Reference-Composition tolerance and from 0022's brine activity model beyond it, from notes/findings/2026-09-08-implicit-earth-audit.md
