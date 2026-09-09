+++
id = "REQ-HYD-003"
title = "A steady water table needs internal sinks and local baselevels, and the groundwater term enters every basin balance"
old_path = ["/home/cfutro/docs/world/hydrography/notes/groundwater-et-sink.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Fan (2019) writes the catchment budget as `dS/dt = P - ET - Qr - Qg` and names dropping
the net groundwater term `Qg` as the common assumption. The predecessor made it in
every surface balance, and Fan's own leaky-catchment conditions (small catchments,
steep regional gradients, deep permeable substrate, dry climate) are the closed-basin
arid setting where basin fate is decided. Four channels carry the term: regional flow
across surface divides, evaporation from a shallow table in discharge zones, lake
leakage, and baseflow timing. Two of them pull opposite ways at one basin, so the sign
of the term on lake area is not knowable before the solve, and the term must not be
tuned against a lake comparison. The scoping argument is in
`/home/cfutro/docs/world/hydrography/notes/groundwater-scoping.md`.

A steady water table whose only exits are the coast and surface seepage cannot hold
itself below the land surface across a dry continent: it pinned at the surface on 95.5%
of Australian land and on 63.0% of the predecessor's generated world. The estimate
needs no model: head above the outlet goes as `R L^2 / 2T`, so 8 mm/yr over 1,000 km
held 250 m down needs about 600 km of aquifer. Adding groundwater evapotranspiration,
exponential in depth after Shah, Nachabe and Ross (2007), whose finding is that the
exponential form beats the linear one used by MODFLOW's EVT package, with extinction
depths 0.18 to 1.86 m, removed the pinning entirely (95.5% to 0.0%) and left the depth
a near-deterministic function of recharge, `d = lambda ln(ET_max / R)`, Spearman -0.977
against recharge where the observed field gives -0.156, with the whole distribution
compressed to 2.9 to 5.6 m against 0.9 to 50.9 m observed. Local baselevels (river and
lake cells as fixed heads at their own surface) with a basin-scale thickness restored
the observed range (95th percentile 52 to 60 m against 42 m) without restoring the
pattern. The two terms are preconditions, not refinements; they are inert bit for bit
when off, and closure holds with three exit doors.

On basin fate the term acts as a zero-crossing: every verdict it flipped was a basin
with exactly zero surface runoff acquiring a finite supply, so the count (86, 83, 85
flips across a permeability bracket spanning a factor of five hundred in exchange; 84,
83, 83 across three members of 12% operator noise; Jaccard 0.78 to 0.90 between
members) is stable while the depth field is not. The sink raised the exchange rather
than lowering it, because a table pinned at the surface cannot develop a gradient. A
first attribution compared recharge against seepage and booked the evaporation as
exchange: global closure balanced at 9e-13 while a derived quantity moved 90% of every
basin's water, which is what gave it away.

Permeability transfers as `k`, a pore-geometry property, from Gleeson et al. (2011)
Table 1 class geometric means keyed on the Durr et al. (2005) lithologic classes, with
within-class sigma of 1.5 to 2.5 orders as the bracket; the geometric mean is
scale-independent over 5 to 100 km except carbonate (karst, one-signed); evaporite has
no assigned value and was carried as unassigned rather than nearest-class.
Conductivity `K = k rho g / mu` is the planet's. A sourced cover thickness contradicted
an assumed uniform 2 km on 99% of land, and the written prediction of its effect was
wrong in both halves because it reasoned against a baseline the run did not use.

## Why it carries

Every item is planet-independent physics or a general lesson about a coupled water
balance. B5 solves a steady unconfined water table; B4 gives each tile an aquifer
store; B8 and the minerals overlay key on the depth; REQ-HYD-001's dry-tail failure
names the groundwater term as a missing one. The zero-crossing finding generalises: a
supply term that means surface runoff only makes every fully arid basin undecidable,
and the fix is a supply that includes exchange. The gravity rule (permeability
transfers, conductivity does not) is free at the start and expensive to retrofit once
a calibration has absorbed it.

## What this system must do

- Carry `Qg` in every basin's supply and in the lake cascade: supply is generated
  runoff plus net groundwater exchange, and the lake solver and any basin criterion
  read the same supply. A basin that receives nothing, including one exporting its
  whole recharge underground, still never overflows.
- Give the water table a groundwater evapotranspiration sink exponential in depth,
  the form `Sourced` from Shah et al., with the extinction depth `lambda` `Derived` as
  the column's rooting depth from the vegetation subsystem (0021) plus a
  capillary-fringe height `Derived` from soil texture with `sigma / (rho_w g)`
  explicit (the condensable's surface tension from REQ-ATM-017, the water density
  from the water-property door of 0017 (pure-water limb), gravity from `System`); Shah et al.'s extinction depths are the
  reported Earth distance, never the value, because they fold one land cover and one
  gravity into a length. `ET_max` is the same evaporative demand the lake tile and
  the land column use: one evaporation rule for lakes, sinks and columns.
- Impose rivers and lakes from the drainage graph as fixed heads at their surface.
- Tabulate permeability, never conductivity, per hydrolithology from the lithology
  registry (REQ-PED-004) as Sourced with the within-class sigma as its Bracket, swept as
  named members; compute conductivity `K = k rho_w g / mu` at the system's gravity
  with `rho_w` and `mu` read from the water-property door of 0017 (pure-water
  limb) at the column's mean soil temperature; leave
  unassigned classes unassigned with a declared consumer policy. Take saturated thickness from the terrain
  snapshot's cover stratigraphy (B1), floored at the source's own depth of validity.
- Emit the regime per cell as fields of the artifact: sink fraction, pinned-at-surface,
  at-thickness-floor, and the permeability member; every consumer of a depth reads
  them.
- Attribute basin-fate changes by isolating exchange (`give + Qg` against `give`), and
  report flips as sets across members, never as a count alone.
- Write the baseline a prediction is against into the prediction.

## Enforced by

Reduction identity to the surface-only balance at zero permeability (bitwise);
inert-path identity for each optional term; the closure ledger with three exit doors;
schema test on the regime fields; REQ-HYD-002's oracle; A3 disposition refusal on any
conductivity literal.

## References

- Are catchments leaky? Fan (2019), WIREs Water 6, e1386. DOI: 10.1002/wat2.1386
- Global Patterns of Groundwater Table Depth. Fan, Li, Miguez-Macho (2013), Science 339,
  940-943. DOI: 10.1126/science.1229881
- Extinction Depth and Evapotranspiration from Ground Water under Selected Land Covers.
  Shah, Nachabe, Ross (2007), Ground Water 45, 329-338.
  DOI: 10.1111/j.1745-6584.2007.00302.x
- Mapping permeability over the surface of the Earth. Gleeson et al. (2011),
  Geophysical Research Letters 38, L02401. DOI: 10.1029/2010GL045565
- Lithologic composition of the Earth's continental surfaces derived from a new digital
  map emphasizing riverine material transfer. Durr, Meybeck, Durr (2005), Global
  Biogeochemical Cycles 19, GB4S10. DOI: 10.1029/2005GB002515

## Amendments

- 2026-09-08: extinction depth derived from rooting depth plus a capillary fringe with `sigma / (rho_w g)` explicit, Shah et al. demoted to the reported distance (row 17); conductivity's `rho_w` and `mu` taken from the water-property door of 0017 at the column temperature (row 16), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: surface tension pointed at REQ-ATM-017 and water density and viscosity at the water-property door of 0017 (pure-water limb), from notes/findings/2026-09-08-implicit-earth-audit.md
