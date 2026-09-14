+++
id = "REQ-OCN-009"
title = "Bathymetry carries a per-cell depth distribution and an explicit connectivity graph; cell-mean bathymetry passes every ledger and loses straits, sills and basins at every resolution"
old_path = ["/home/cfutro/git/vesper/notes/audits/ocean-support-nonlinear-reductions.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on a ten-million-region terrain of the predecessor's configured
planet, reduced onto a T21 to T170 spectral ladder and a 36 x 36 equal-area
ocean grid: the cell-mean depth reproduces the ocean volume to 1.7e-16
relative (an affine identity, the control); the ocean area on either side of a
depth horizon differs from the terrain's by 12 to 49 times a bar of 0.001 of
planetary area at every support including the finest, with a sign that flips
inside the sweep at the land-mean ocean depth, shrinking by a factor of 3.8
across the ladder and never removed; the deep-water connectivity (the area not
attached to the largest connected body at a horizon) disagrees with the
terrain's by up to 83 million km2, does not shrink with refinement and does
not keep its sign, because the deep water percolates apart between two
horizons and a support that moves one passage by one cell moves the area by
the size of a basin. The finest rung was not the closest. The binary 0.5 wet
mask contributed a second error of 3.3 to 12.3 times the bar on its own. A
pipeline gate requiring that bathymetry "preserve extensive quantities" passed
the cell-mean support that failed every threshold consumer. The audit fixed a
decision procedure before any ocean ran: a passage carrying transport H is
material when its fractional capacity error exceeds the loop's controlling
tolerance times the ocean area divided by H.

`cgenie-parallelism-and-coupling-support.md` section 4b stated the resolution
rule the finding implies: take the coarsest candidate that resolves the
connections the terrain carries. `notes/external-model-survey.md` section 47f
recorded a peer that hands its ocean a 90th-percentile bed elevation rather
than a mean, and a land-fraction threshold structured to vary where straits
carry through-flow.

## Why it carries

Volume is affine in depth; the area above a horizon is a threshold on a
distribution; connectivity is a property of the graph the cells form. A single
depth per cell cannot carry the last two at any resolution, and a conservation
gate cannot see the loss. Straits, sills and enclosed basins set an ocean's
overturning, its basin salinity contrasts and its ventilation on any planet,
and they are exactly what an interesting world has and what coarse levels
drop. This finding is the measured evidence for A1's explicit connectivity
graph and for the F1 mechanism: existence and topology exact, through-flow by
physics that carries the feature's geometry, refinement invoked by an
instrument.

## What this system must do

- The ocean's bathymetry at level L is derived from the terrain level
  exactly: per cell, the area-weighted depth distribution (a quantile table),
  the wet-area fraction, the volume by model level, and partial bottom cells
  (A1). The cell-mean depth is one diagnostic of that distribution, never the
  support.
- The connectivity graph is derived from the terrain level at every slow
  step: its nodes are the ocean and land bodies of each coarse cell, joined
  through edge neighbours inside it (decision 0031); for every pair of bodies
  joined across a coarse edge there is one gate, for ocean the minimum sill
  depth and the width of the connection and for land contiguity; the
  connected components at every model level horizon; for basins, the drainage
  terminal. The graph is state, versioned with the support, and a topology
  change is an event that forces a climate refresh (F1).
- The ocean solver reads strait and sill transports from the graph through
  rotating hydraulic control (sill depth, width against the Rossby radius, the
  density contrast across the sill), with the reduced gravity from the equation
  of state and the declared gravity, the Coriolis parameter from `System`, and
  the control's discharge coefficients `Bracketed` (dimensionless; mechanisms:
  frictional and mixed overflow at the low end, inviscid control at the high
  end). A width small against the Rossby radius, or a Coriolis parameter
  tending to zero, is the non-rotating critical-flow limit of the same forms
  (Whitehead 1998), the physics of that case and not a floor (REQ-OCN-002);
  downstream overflow entrainment is a `Closure` or a declared absence with its
  interface. A land bridge blocks flow exactly and carries a land tile.
- Wet and dry are never decided by a scalar threshold on a coarse fraction: a
  cell with land fraction strictly between 0 and 1 is a mosaic tile with
  sub-grid land and water; an island is never rounded to ocean and a strait is
  never rounded to land.
- Acceptance for any ocean support states, beyond the volume identity: the
  area above every model-level horizon against the terrain to a declared bar;
  the connected-component decomposition at every horizon matching the
  terrain's (the same bodies separating at the same horizons); every feature
  the tectonic seed declared (straits, sills, islands, enclosed seas) present
  in the graph.
- The F1 sensitivity probe runs each feature's parameterised transport at the
  ends of its bracket against declared global and regional metrics
  (overturning strength, basin salinity contrast, regional SST), whose brackets
  are declared with the configuration and never an observed transport of one
  planet, and flags an outsized feature for local refinement to a declared
  depth of levels.

## Enforced by

- A1 and F1 decision records; M0 gate (connectivity graph identities on the
  hierarchy; refinement balance identity).
- C3 mesh oracles extended with the horizon-area identity and the
  connected-component identity against the terrain level.
- The Part E tripwire: a declared feature (strait, island, isthmus) absent
  from a coarse-level artifact blocks the gate.
- C4 mutation run: a cell-mean bathymetry substituted for the distribution
  must fail the horizon identity.
- C3 oracle: the control forms reproduce the closed-form transport of a
  synthetic sill at the test's reduced gravity and Coriolis parameter,
  including the non-rotating limit (registry ocean.strait_control_identity).

## References

- Whitehead, J. A. (1998). "Topographic control of oceanic flows in deep
  passages and straits". Reviews of Geophysics 36, 423-440.
  DOI: 10.1029/98RG01014. (Rotating hydraulic control of strait transport.)
- Whitehead, J. A. (1998), held, is the treatment of rotating hydraulic control
  this requirement rests on; the Pratt and Whitehead (2008) monograph "Rotating
  Hydraulics" (Springer, DOI 10.1007/978-0-387-49572-9) is the comprehensive
  reference and is not held.
- Adcroft, A. (2013). "Representation of topography by porous barriers and
  objective interpolation of topographic data". Ocean Modelling 67, 13-27.
  DOI: 10.1016/j.ocemod.2013.03.002. (Sub-grid straits and sills as explicit
  barrier geometry rather than cell-mean depth.)
- Adcroft, A., Hill, C. and Marshall, J. (1997). "Representation of Topography
  by Shaved Cells in a Height Coordinate Ocean Model". Monthly Weather Review
  125, 2293-2315. DOI: to confirm. (Partial bottom cells.)
- Ringler, T., Petersen, M., Higdon, R. L., Jacobsen, D., Jones, P. W. and
  Maltrud, M. (2013). "A multi-resolution approach to global ocean modeling".
  Ocean Modelling 69, 211-232. DOI: 10.1016/j.ocemod.2013.04.010. (Local
  refinement of an unstructured ocean mesh around features.)

## Amendments

- 2026-09-08: strait control: reduced gravity, gravity and the Coriolis parameter named as declared inputs; the non-rotating limit as the f-to-zero physics; discharge coefficients `Bracketed` with mechanisms; entrainment a `Closure` or absence; probe brackets declared with the configuration; strait-control identity as a tier-1 oracle (row 22), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-13: connectivity graph bullet restated over the ocean and land bodies
  of a coarse cell and one gate per pair of bodies joined across a coarse
  edge, rather than one gate per pair of adjacent coarse ocean cells, per
  decision 0031's amendment of 2026-09-13 (row fiddlybits-52v.2.19)
