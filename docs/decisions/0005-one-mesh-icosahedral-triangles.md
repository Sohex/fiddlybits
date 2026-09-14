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

### The body-fixed frame and the icosahedron's orientation

The mesh's Cartesian coordinates are body-fixed, and `Mesh.BODY_FRAME` is the one
declaration of how they meet the planet's rotation. Its `spin_axis` is the positive pole
of rotation, the pole about which the body turns counterclockwise seen from outside (the
right-hand rule); its `prime_meridian` is the equatorial direction of longitude zero; and
`ninety_east` is their cross product, derived and never declared, so the frame is
right-handed by construction. Latitude is positive toward the spin axis and longitude
increases east, the direction the surface moves. Every east-north frame, latitude,
longitude, Coriolis parameter and hour angle reads these axes from the declaration by
name, and no other site in `src/` writes an axis by coordinate, which
`test/mesh/frame.jl` decides by scanning the tree.

The spin axis is the positive pole on every configuration, prograde or retrograde. The
sense of decision 0004 is relative to the orbit normal, and it enters only where the body
frame is placed in the orbit frame: a retrograde rotator's positive pole lies on the far
side of its orbit plane from the orbit normal. `Mesh.require_body_orientation` is the
rule every placement passes: the placed frame is right-handed, and the placed spin axis
has a positive component along the body's rotation vector. The rotation rate about the
spin axis is then positive, the Coriolis parameter `2 Omega sin(latitude)` is positive
toward the spin axis, and the surface moves east, on every configuration, and no kernel
reads the sense. How decision 0004's obliquity and sense, and a rotation phase at the
epoch, place the frame in the orbit frame is `fiddlybits-52v.5.7`.

`base_icosahedron` places each golden-ratio corner by its components along the prime
meridian, ninety east and the spin axis. That puts the spin axis through the midpoint of
one base edge and the prime meridian through the midpoint of the base edge at right
angles to it, each a two-fold symmetry axis of the icosahedron. What follows is checked
by `test/mesh/frame.jl` or follows from what it checks:

- Every level is mirror-symmetric about the equatorial plane, bitwise, because the plane
  normal to a two-fold axis is a mirror plane of the icosahedron and a renormalised
  bisection commutes with the reflection. A forcing symmetric about the equator but not
  zonally symmetric, of which the sub-stellar heating of a synchronous rotator with its
  sub-stellar point on the equator is the case that matters, meets the same grid in both
  hemispheres, so a hemispheric difference in the response is not grid imprint. On a grid
  that is not symmetric across the equator, an initial state symmetric across it evolves
  asymmetric (Heikes and Randall 1995, Part I, p. 1864), and a symmetric grid keeps the
  response symmetric (the same paper, p. 1874). Every level is also mirror-symmetric
  about the plane of the prime meridian and the spin axis. The mirror normal to a base
  vertex or to a base face centre is not a symmetry, which is the check's positive
  control.
- No pole is a valence-five vertex. From level one each pole is a valence-six vertex, and
  no cell centre lies on the spin axis at any level, so an east-north frame over cell
  centres exists at every cell.
- The cost falls on the equator. Four of the twelve valence-five vertices lie on it, so an
  equatorial wave crosses four of them in a circuit; the other eight lie four in the
  plane of the prime meridian and four in the plane of ninety east. The rotational
  symmetry about the spin axis is of order two, so a pattern the grid imprints on a
  zonally symmetric flow repeats under a half turn and holds only even zonal wavenumbers,
  where a vertex-at-pole orientation imprints wavenumber five near its valence-five
  vertices (Wan et al. 2013, p. 747).

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
- **The spin axis as the pole on the orbit normal's side**, the north pole of the IAU
  convention for planets and satellites (Archinal et al. 2018, p. 6, with the invariable
  plane where decision 0004 has the orbit normal), the sense carried as the sign of the
  rotation about it. It matches the catalogue coordinates of solar-system planets. Lost
  because the sign then reaches every rotating kernel: the Coriolis parameter and the
  direction the surface moves change sign with the sense, and a kernel that drops the
  sign runs a retrograde world as a prograde one without an error. The positive pole is
  the IAU convention for dwarf planets, minor planets, their satellites and comets (the
  same report, p. 22), which the report notes planetary systems could follow (p. 39).
- **A pole on a base vertex**, the orientation of the ICON grid (Wan et al. 2013,
  p. 738). It keeps the equator free of valence-five vertices and puts one at each pole,
  where the Coriolis parameter is extremal; its hemispheres are related by a fifth of a
  turn and not by a reflection, so the equatorial mirror is not a symmetry. Lost on that
  asymmetry.
- **The twisted icosahedron** (Heikes and Randall 1995, Part I, p. 1864): the southern
  faces of the vertex-at-pole orientation rotated through a fifth of a turn, which
  restores equatorial symmetry. It is no longer a regular icosahedron and its equatorial
  faces are distorted, and the grid the authors run repositions the new points of each
  level to minimise an error measure (Part II, p. 1885), which breaks exact nesting as
  smoothing does. Lost.
- **A pole on a base face centre.** Order-three symmetry about the spin axis and no
  equatorial mirror, and the central child of the polar face keeps its circumcentre on
  the axis at every level, so a cell centre sits on each pole, where east has no
  direction. Lost.
- **An orientation with no symmetry axis through the pole.** No mesh site on a pole at
  the levels a profile uses, and no symmetry either; its angle would be chosen to avoid
  something rather than derived. Lost.
- **The prime meridian through the other two-fold axis in the equatorial plane.**
  Equivalent in every property above except which four valence-five vertices lie in the
  prime meridian's plane. Either is admissible, and the declaration names one.

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
- `Mesh.BODY_FRAME` is read by `Fields.local_east_north` and `Fields.east_north_frame`,
  and `Mesh.latitude`, `Mesh.longitude` and `Mesh.require_body_orientation` are the doors
  the Coriolis parameter (`fiddlybits-52v.9.2`), the hour angle (`fiddlybits-52v.5.3`)
  and the instellation (`fiddlybits-52v.5.4`) read. Checks implied: east cross north is
  the local up at every cell centre; the placement rule refuses a retrograde rotator
  placed with its pole on the orbit normal's side, and a left-handed placement; the two
  mirror symmetries of the hierarchy hold bitwise; no site in `src/` writes an axis by
  coordinate.
- Routing on triangles uses the twelve-neighbour stencil with slope-weighted
  multiple-flow-direction accumulation and random tie-breaking for the steepest
  receiver, to break the lattice bias of single-direction routing on a regular mesh.

## References

- Wan, H., et al. "The ICON-1.2 hydrostatic atmospheric dynamical core on triangular
  grids - Part 1: Formulation and performance of the baseline version." Geoscientific
  Model Development 6 (2013). DOI: 10.5194/gmd-6-735-2013. Pages 738 (the grid's orientation, a vertex at each pole) and 747 (wavenumber-five imprint near the valence-five vertices).
- Archinal, B. A., et al. "Report of the IAU Working Group on Cartographic Coordinates and Rotational Elements: 2015." Celestial Mechanics and Dynamical Astronomy 130 (2018), article 22. DOI: 10.1007/s10569-017-9805-5. Pages 6 (the north pole by the invariable plane, the sense from W), 22 (the positive pole by the right-hand rule), 39 (planetary systems following the right-hand rule).
- Heikes, R., Randall, D. A. "Numerical Integration of the Shallow-Water Equations on a Twisted Icosahedral Grid. Part I: Basic Design and Results of Tests." Monthly Weather Review 123 (1995). DOI: 10.1175/1520-0493(1995)123<1862:NIOTSW>2.0.CO;2. Pages 1864 (a grid not symmetric across the equator, the twisted icosahedron), 1874 (a symmetric response on a symmetric grid).
- Heikes, R., Randall, D. A. "Numerical Integration of the Shallow-Water Equations on a Twisted Icosahedral Grid. Part II: A Detailed Description of the Grid and an Analysis of Numerical Accuracy." Monthly Weather Review 123 (1995). DOI: 10.1175/1520-0493(1995)123<1881:NIOTSW>2.0.CO;2. Page 1885 (the new points of each level repositioned).
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
- 2026-09-13: the body-fixed frame is declared once in Mesh, its spin axis the positive pole of rotation for either sense, with the placement rule a retrograde rotator passes; the base icosahedron is placed in it with the spin axis and the prime meridian on two-fold axes; section The body-fixed frame and the icosahedron's orientation and its alternatives, carried by fiddlybits-52v.2.16, with the rotation phase at the epoch and the placement from obliquity and sense in fiddlybits-52v.5.7.
- 2026-09-13: the archive this record cites now resolves at /home/cfutro/git/vesper; /home/cfutro/docs/world no longer exists on disk, from notes/findings/2026-09-13-predecessor-archive-relocated-to-vesper.md.
