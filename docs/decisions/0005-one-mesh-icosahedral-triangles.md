+++
id = "0005"
title = "One mesh: an icosahedral bisection hierarchy with triangle cells, sub-grid structure for small features, and graded local refinement"
status = "accepted"
date = 2026-09-08
+++

## Decision

Every component of the system lives on a level of one spherical discretisation: the
icosahedron, bisected. Level `L` has `20 * 4^L` triangular cells, `30 * 4^L` edges and
`10 * 4^L + 2` vertices. There is no second grid anywhere in the model. The atmosphere
does not run on a Gaussian grid, the ocean does not run on an equal-area grid, and
the terrain does not run on a Voronoi mesh; each runs at its level of the same
hierarchy, and a reduction from a fine level to a coarse one is a relation between a
parent and its children, never a remap.

### Properties the choice rests on

- **Exact nesting.** The four children of a triangle tile it exactly: their outer
  boundary is the parent's three great-circle arcs, and their areas sum to the
  parent's to rounding. So a coarse-level field that is the area-weighted sum of its
  children conserves area, water, energy and salt identically at every crossing, and
  the closure ledgers of decision 0009 can demand identity rather than tolerance.
- **Arithmetic hierarchy.** Cells are numbered so that the children of a cell are a
  contiguous index range and the parent is a shift (decision 0010 fixes the index
  base). A reduction of `4^k` fine cells into one coarse cell is a segmented
  reduction over a contiguous, power-of-four segment, which is the ideal GPU
  reduction: coalesced, no atomics, and a bitonic sort fits a segment of up to 1024
  for quantiles.
- **Fixed valence.** Every cell has exactly three edge neighbours and twelve vertex
  neighbours, except the cells touching the twelve base vertices, which have eleven
  and are padded with self at zero weight. Stencils are dense integer matrices with
  no special cells.
- **An operational existence proof.** A finite-volume dynamical core on exactly this
  triangle C-grid runs operationally (decision 0013).

### What the choice costs, and how it is carried

Pure bisection leaves a cell-area variation of order 1.3 to 1.4 between the largest
and smallest cells at fine levels. Operational icosahedral models smooth the vertex
positions to reduce it; this design does not, because smoothing one level destroys
its exact nesting with every other level. Cell areas are carried as an explicit
measure, every reduction is area-weighted, and the ratio is recorded as a mesh
property. Nothing in the design assumes equal area.

### Small interesting places are a requirement, not a resolution casualty

Islands, isthmuses, straits, inland seas and passes are what make a world
interesting and are exactly what a coarse level drops. Three mechanisms, all present
from the founding:

1. **Mosaic tiles carry sub-grid land and water.** A cell whose land fraction is
   strictly between zero and one holds an island tile, or a lake tile, with its own
   land column. An island is never rounded to ocean and a strait is never rounded to
   land. Tile area and hypsometry come from the fine level exactly.
2. **Connectivity is an explicit derived graph.** Every slow step, the terrain level
   yields: for each pair of adjacent coarse ocean cells the minimum sill depth and
   the width of their connection; for land, contiguity; for basins, the drainage
   terminal. The ocean solver reads strait transports through this graph by rotating
   hydraulic control (sill depth, width against the deformation radius, density
   contrast); the deformation radius is `Derived` from the local Coriolis parameter
   and the density contrast, and where the Coriolis parameter is small the control
   reduces to the non-rotating hydraulic limit, which is the physics of that case and
   never a floor (REQ-OCN-002). A land bridge blocks ocean flow exactly and carries a
   land tile. Passes carry
   their sub-grid slope statistics into orographic drag and precipitation. A change
   in the graph's topology (a seaway closes, a land bridge floods) is an event that
   forces a climate refresh, so a gateway closure happens when it happens rather than
   being averaged away by the slow tier. The tectonic seed exposes arcs, land bridges
   and archipelagos as things a configuration can request, so such places need not
   be accidents.
3. **Local refinement in the hierarchy, invoked by an instrument.** Because nesting
   is exact, a component may run at a finer level inside a region and the coarse
   level elsewhere. Each feature record carries a sensitivity probe: the
   parameterised transport is run at the two ends of its declared bracket, and if a
   declared metric (overturning strength, a basin's salinity contrast, a regional
   sea-surface temperature, a downstream drainage share) moves beyond its own
   bracket, the feature is flagged outsized and the ocean, and if needed the
   atmosphere, is refined around it to a declared depth of levels. A configuration
   may also declare a region refined outright.

**Refinement boundaries are graded for the fluids and may be abrupt for the damped
systems.** An abrupt 2:1 step in a primitive-equation core reflects gravity and
acoustic waves and seeds grid-scale storms at the boundary. Atmospheric and oceanic
refinement therefore steps down one level at a time through transition rings of a
declared minimum width in cells, with divergence damping inside the transition, and
2:1 balance with flux-conserving hanging edges at every step. Terrain, hydrology and
the land column, which are damped, use abrupt 2:1 boundaries.

### Vertical resolution is a per-component declared ladder derived from the planet

Atmosphere levels are placed by the scale height and by the boundary-layer depth
scale, with a declared number of levels inside a declared fraction of the scale
height, where the scale height is computed from the declared composition
(REQ-ATM-017) and a Bracketed first-guess temperature from the declared instellation
(mechanisms: radiative equilibrium with no greenhouse forcing at the low end,
radiative equilibrium at a Bracketed greenhouse forcing at the high end) and a
Bracketed Bond albedo (mechanisms: a bare-rock surface at the low end, full cloud
cover at the high end), and the boundary-layer depth scale is the smaller of a
Bracketed multiple of u*/|f| (mechanisms: the laboratory neutral Ekman depth at the
low end, observed convective deepening at the high end) and a declared fraction of
the scale height, with the slow-rotator limit named, so that inversions and low-level jets have an interior on
every configuration and not only on one whose scale height happens to be several
kilometres; the model top is set by the pressure at which the sponge lives, as a
fraction of the surface pressure, not by a fixed pressure in hectopascals. Ocean
levels are placed against the mixed-layer and thermocline depth scales, with
partial bottom cells. Soil, snow, lake and ice columns use adaptive or
geometric layering with their own ladders. Every vertical ladder is swept the way
horizontal levels are, and convergence with the ladder is an oracle.

### Levels are profile settings

No level number is fixed in this record. A profile (decision 0014) chooses each
component's level to hit a target spacing in kilometres derived from the planet's
radius, so the same profile means the same physical spacing on a small planet and a
large one. The same spacing is a different dynamical resolution under another
rotation, gravity or composition, so the profile record also reports the ratio of
that spacing to the configuration's first-baroclinic deformation radius at a declared
reference latitude (the equatorial deformation radius where the Coriolis parameter is
small), `Derived` from the system and the first-guess column of the vertical ladder;
a reader comparing two configurations at one profile reads the ratio, not the
kilometres.

## Alternatives considered

- **Fibonacci-sphere Voronoi mesh** (what the predecessor's terrain generator used).
  Quasi-uniform, but with no hierarchy at all: a coarser Fibonacci set is a different
  point set, so every reduction is a general polygon-intersection remap with variable
  valence and a compressed-row adjacency. That structure is what made the
  predecessor's mesh-to-grid reduction library and its inventory of what a crossing
  lost necessary. Lost on the absence of nesting.
- **Cubed sphere.** Regular quadrilaterals with exact 4:1 refinement and arithmetic
  parent indices, and strong ecosystem support. Lost on its panel seams: every
  stencil kernel special-cases them, vectors change basis across them, and the eight
  panel corners are valence-3 vertices. The seam is the "convention that travels by
  coordinate" the predecessor banned. Second choice, and the last fallback of
  decision 0013.
- **Icosahedral hexagonal (vertex-dual) cells.** Twelve pentagons break fixed
  valence, and a hexagon at one level is never a union of hexagons or triangles at
  the next, so nesting is not exact and ledgers could not close identically. Lost;
  see decision 0013 for the consequence on the dynamical core.
- **Smoothing the bisected mesh** for area uniformity. Lost because it breaks exact
  nesting across levels.
- **Local refinement as the primary mechanism for small features.** Lost because
  refinement regions must be declared or detected, every solver handles hanging
  edges from day one, cost is uneven, and features outside declared regions are
  still lost. It is the escalation, triggered by a measurement.
- **Mosaic and connectivity only, with no refinement in scope.** Lost because it
  leaves no path to resolving a feature's dynamics when the parameterisation is
  insufficient.

## Consequences

- The mesh module exposes the hierarchy, the geometry per level on the unit sphere
  (physical geometry is unit geometry times the radius, read from the system struct
  at call time; there is no radius in the mesh object), the stencils, the identity
  digest, the connectivity-graph construction, and refinement with graded
  transitions. The radius read is the volumetric mean radius of the planet's figure
  (decision 0004), and the geopotential of a cell comes from the `Derived`
  `g(r, phi)` of that decision, never from a sphere of uniform gravity.
- Reductions are segmented operations dispatched on field semantics (decision 0006).
- Oracles implied: sum of cell areas equals `4 pi R^2` at every level to rounding;
  `children(parent(i))` contains `i`; valence counts; a constant field coarsens to a
  constant; an extensive field's integral is preserved to rounding across levels; a
  graded refinement region shows no reflected-wave growth for a propagating wave
  test; drainage-density isotropy by azimuth and a Hack's-law exponent for the
  routing stencil.
- Routing on triangles uses the twelve-neighbour stencil with slope-weighted
  multiple-flow-direction accumulation and random tie-breaking for the steepest
  receiver, to break the lattice bias of single-direction routing on a regular mesh.

## References

- Wan, H., et al. "The ICON-1.2 hydrostatic atmospheric dynamical core on triangular
  grids - Part 1: Formulation and performance of the baseline version." Geoscientific
  Model Development 6 (2013). DOI: 10.5194/gmd-6-735-2013
- Zaengl, G., Reinert, D., Ripodas, P., Baldauf, M. "The ICON (ICOsahedral
  Non-hydrostatic) modelling framework of DWD and MPI-M: Description of the
  non-hydrostatic dynamical core." Quarterly Journal of the Royal Meteorological
  Society 141 (2015). DOI: 10.1002/qj.2378
- Whitehead, J. A. "Topographic control of oceanic flows in deep passages and
  straits." Reviews of Geophysics 36 (1998). DOI: 10.1029/98RG01014
- The predecessor's audits on grid-crossing loss and the two cell-area answers:
  `/home/cfutro/docs/world/notes/audits/nonlinear-spatial-reductions.md`,
  `/home/cfutro/docs/world/notes/audits/ocean-grid-crossing.md`,
  `/home/cfutro/docs/world/notes/audits/grid-convention-and-runoff.md`.
- The predecessor's measurement of the terrain information floor and catalogue
  convergence with region count:
  `/home/cfutro/docs/world/notes/audits/orogen-resolution.md`.

## Amendments

- 2026-09-08: the vertical ladder places levels inside a declared fraction of the scale height computed from composition and a Bracketed first-guess temperature, with the boundary-layer depth scale bounded by a Bracketed multiple of u*/|f| and the slow-rotator limit named, replacing "the lowest kilometre", from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: the profile record reports the spacing as a ratio to the deformation radius; the mesh radius is named as the volumetric mean radius and the geopotential comes from g(r, phi); the strait control names its non-rotating limit, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: cross-area review: both ends named for the ladder's first-guess temperature, Bond albedo and u*/|f| multiple, matching decision 0016, from notes/findings/2026-09-08-implicit-earth-audit.md
