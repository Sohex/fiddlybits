+++
id = "0031"
title = "Small features are carried by tiles and an explicit connectivity graph, with instrument-triggered local refinement"
status = "accepted"
date = 2026-09-08
+++

## Decision

Features narrower than a climate or ocean cell (islands, isthmuses, straits, inland
seas, mountain passes) are exactly what makes a world interesting and exactly what a
plain coarse level drops. They are a first-class requirement. The guiding case is a
seaway closing: its outsized effect on the global ocean is a *connectivity* event,
not a resolution-of-dynamics event, so the mechanism has three layers and the first
two carry the outsized cases without any refinement.

**Layer 1: existence and topology are exact and event-driven.** The connectivity
graph is derived from the terrain level every slow step. Its nodes are bodies: an
ocean body is a set of world-ocean terrain cells of one coarse cell joined through
edge neighbours inside that cell, and a land body is the same for the cell's
non-ocean terrain cells, so a coarse cell holds as many bodies of each kind as its
terrain does. For every pair of bodies of adjacent coarse cells joined across their
shared edge there is one gate: for ocean, the minimum sill depth and the width of that
connection, read at its control section; for land, contiguity. For basins, the
drainage terminal. A change in the graph's topology (a seaway closes, a land bridge
floods, a basin captures its neighbour, a body splits, two bodies of one coarse cell
join) is an *event* that forces a climate refresh, so a closure happens when it
happens rather than being averaged away by the slow tier. Bodies of two derivations
correspond through the terrain cells they share and never through their labels. A cell
with land fraction between zero and one holds an island or lake tile with its own land
column; an island is never rounded to ocean and a strait is never rounded to land. The
tile's area and hypsometry come from the fine level exactly.

**Layer 2: through-flow is parameterised by physics that carries the feature's
geometry.** Strait exchange by rotating hydraulic control: sill depth, width against
the deformation radius, and the density contrast across the sill, with the reduced
gravity from the equation of state and the declared gravity and the Coriolis
parameter from the system struct. A width small against the deformation radius, or
a Coriolis parameter that tends to zero (an equatorial strait, a slow or a
synchronous rotator), is the non-rotating critical-flow limit of the same control
forms (Whitehead 1998); that limit is the physics of the f-to-zero case and not a
floor or a fallback (REQ-OCN-002). The discharge coefficients are `Bracketed`
(dimensionless; mechanisms: frictional and mixed overflow at the low end, inviscid
control at the high end), and downstream overflow entrainment is a `Closure` in the
resolved density contrast or a declared absence with its interface. That is what
sets an inland sea's salinity and a gateway's exchange. Each gate's exchange is read
from its own sill depth and width and from the state of the two bodies it names: a
coarse ocean column holding more than one ocean body carries a water tile per body
with its own state, and two bodies of one column exchange only through gates. A land
bridge blocks ocean flow exactly and carries a land tile, including one that lies
inside a single coarse cell. Mountain passes carry their sub-grid slope statistics
into orographic drag and precipitation.

**Layer 3: refinement is invoked by an instrument, not by hand.** Every feature
record gets a sensitivity probe: the parameterised transport is run at both ends of
its declared bracket, and if a declared global or regional metric (overturning
strength, basin salinity contrast, regional sea-surface temperature, a downstream
drainage share) moves beyond its own bracket, a bracket declared with the
configuration and never the observed transport of one planet, the feature is
flagged *outsized* and
the ocean, and if needed the atmosphere, is refined around it to a declared depth of
levels. A configuration may also declare a region refined outright. Refinement is
local levels on the same hierarchy with 2:1 balance and flux-conserving hanging-edge
treatment.

**Fluid refinement boundaries are graded, not abrupt.** An abrupt 2:1 step reflects
gravity and acoustic waves and seeds grid-scale storms, so atmospheric and oceanic
refinement steps down one level at a time through transition rings of a declared
minimum width, with divergence damping inside the transition. Terrain and hydrology,
which are damped systems, may use abrupt boundaries.

**Features can be asked for.** The tectonic seed exposes arcs, land bridges and
archipelagos as things a configuration can request, so the interesting places are
not accidents of the seed.

## Alternatives considered

- *Local refinement as the primary mechanism.* Rejected: regions must be declared or
  detected; every solver handles hanging edges from day one; cost is uneven; and
  features outside declared regions are still lost. Refinement is the escalation.
- *Tiles and connectivity only, no refinement.* Rejected: it leaves no route to
  resolving a feature's own dynamics when the parameterisation is insufficient, and
  the instrument would have nothing to escalate to.
- *Smoothly varying mesh spacing instead of nested levels.* Rejected: it breaks the
  exact nesting the ledgers rely on.
- *A minimum feature size below which features are dropped.* Rejected: it is the
  predecessor's coastline-threshold problem restated, and it drops exactly the
  features this record exists to keep.
- *One ocean body and one land body per coarse cell, with a gate per pair of adjacent
  coarse cells.* Rejected: an isthmus cell with a sea on each side keeps one sea, and
  the other sea's connection to its own neighbour has no gate, so the coarse ocean
  blocks an exchange that exists; a second connection across the same coarse edge is
  lost the same way.
- *One node per coarse cell with every body in it counted as joined.* Rejected: a
  column mixing two seas carries water across the land bridge between them, and the
  upstream height above sill depth that sets a passage's transport (Whitehead 1998,
  p. 427, eqs. 12-13) belongs to the basin behind that passage, which two seas do not
  share.
- *One gate per coarse edge carrying the deepest of several connections, or their
  summed width.* Rejected: two passages with their own sills are two controls, and one
  sill depth with one upstream height gives neither transport.
- *A gate between any two bodies of adjacent coarse cells joined anywhere inside the
  two cells.* Rejected: a chain of passages through other bodies of the pair is then
  counted again as a passage of its own, and its exchange twice.
- *Folding a body below a size into a neighbouring body.* Rejected as the minimum
  feature size above.

## Consequences

- The connectivity graph is a first-class artifact with its own identity and its
  own tests (a synthetic strait's sill depth and width recovered exactly from the fine
  level; a synthetic isthmus cell's two connections recovered each with its own; a
  topology change firing the refresh event).
- One gate is kept per pair of bodies, as one outlet is kept per pair of depressions
  that meet in the depression hierarchy of Barnes, Callaghan and Wickert 2020 (section
  3.3, p. 438), where the lowest outlet between the pair is the one recorded. A
  passage between the same two bodies shallower than the gate's crest is not a second
  gate; the connected components at every model-level horizon that REQ-OCN-009 asks of
  the graph are what carry it.
- The control forms treat one passage at a time, and boundaries with many gaps, where
  flow leaves through one and returns through another, are outside the review they
  come from (Whitehead 1998, p. 424). The graph gives each passage its gate; how the
  flows through several gates of one body pair up, and how a resolved coarse column
  and its body tiles share the column's state, are the ocean plan's
  (`fiddlybits-ncw.1`).
- The ocean solver's strait transport parameterisation is a named scheme with a
  bracketed coefficient and the sensitivity probe as its instrument, and it has a
  tier-1 identity: the control forms reproduce the closed-form transport of a
  synthetic sill at the test's reduced gravity and Coriolis parameter, including
  the non-rotating limit.
- The mesh module supports graded local refinement from the start (decision 0005),
  and the dynamical-core gate includes a refinement region with no reflected-wave
  growth (decision 0026).
- Feature records are part of a configuration's declared inputs and of a run's
  provenance.

## References

- Whitehead, J. A. "Topographic control of oceanic flows in deep passages and
  straits." Reviews of Geophysics 36 (1998). DOI: 10.1029/98RG01014.
- Pratt, L. J., and J. A. Whitehead. Rotating Hydraulics: Nonlinear Topographic
  Effects in the Ocean and Atmosphere. Springer, 2008. DOI: 10.1007/978-0-387-49572-9.
  Not held; the Whitehead 1998 review above carries the control forms the design uses.
- Barnes, R., K. L. Callaghan, and A. D. Wickert. "Computing water flow through complex
  landscapes - Part 2: Finding hierarchies in depressions and morphological
  segmentations." Earth Surface Dynamics 8 (2020). DOI: 10.5194/esurf-8-431-2020.
- Predecessor records of what a coarse coastline costs and of straits lost to
  resolution: `/home/cfutro/docs/world/notes/audits/coastline-threshold-cost.md`,
  `/home/cfutro/docs/world/notes/audits/ocean-support-nonlinear-reductions.md`.
- On wave reflection at nested-grid boundaries and graded transitions: Harris, L. M.,
  and D. R. Durran. "An Idealized Comparison of One-Way and Two-Way Grid Nesting."
  Monthly Weather Review 138 (2010). DOI: 10.1175/2010MWR3080.1.

## Amendments

- 2026-09-08: Layer 2: reduced gravity, gravity and the Coriolis parameter named as the declared inputs of the control; the non-rotating critical-flow limit named as the physics of the f-to-zero case rather than a floor; discharge coefficients `Bracketed` with mechanisms; overflow entrainment a `Closure` or declared absence (row 22 and the rotation auditor's request), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: Layer 3: the probe's metric brackets are declared with the configuration, never an observed transport (row 22), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: Consequences: the strait-control identity named as a tier-1 oracle, from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-13: Layer 1: the graph's nodes are the ocean and land bodies of each coarse cell and its gates one per pair of bodies joined across a coarse edge, rather than one per pair of adjacent coarse ocean cells; a body splitting and two bodies of one coarse cell joining are topology changes, read through shared cells; Layer 2: a column holding several ocean bodies carries a tile per body, exchanging only through gates; four alternatives and two consequences added, with Barnes, Callaghan and Wickert 2020 section 3.3 p. 438 and Whitehead 1998 pp. 424 and 427 as anchors (row fiddlybits-52v.2.17; REQ-OCN-009, decision 0017 and the mesh plan restated in fiddlybits-52v.2.19), from the review of fiddlybits-52v.2.7
- 2026-09-13: the archive this record cites now resolves at /home/cfutro/git/vesper; /home/cfutro/docs/world no longer exists on disk, from notes/findings/2026-09-13-predecessor-archive-relocated-to-vesper.md.
- 2026-09-14: the rotating hydraulic control forms of Layer 2 and the Alternatives are cited to their primary, Whitehead, Leetmaa and Knox (1974), "Rotating Hydraulics of Strait and Sill Flows", Geophysical Fluid Dynamics 6, 101-125, DOI 10.1080/03091927409365790, in place of the Whitehead (1998) review: the wide-channel transport Q = g' h_u^2/(2f), eq. 3.8, p. 107, where the deformation radius (2 g' h_u/f^2)^(1/2) of eq. 3.12, p. 108, is below the channel width; the narrow-channel transport, eq. 3.15, p. 108, where it is not; and the non-rotating weir limit at f = 0, eqs. 3.19, p. 109, which is eq. 3.15 at f = 0, so the f-to-zero case is the same form and not a branch. The forms assume a two-layer inviscid hydrostatic flow with the upper layer at rest and zero potential vorticity upstream (p. 106), a rectangular channel (Fig. 1), and the maximum-transport control rule, which the paper assumes (p. 107). The Alternatives' "Whitehead 1998, p. 427, eqs. 12-13" reads as these equations, and the References' Pratt and Whitehead note reads the 1974 paper as the carrier of the forms. The one-passage scope and the exclusion of boundaries with many gaps stay cited to Whitehead (1998), p. 424, which the 1974 paper does not discuss. User decision of 2026-09-14 (the paper supplied by the user), raised by notes/findings/2026-09-14-an-audit-of-source-fitness.md; the index row is carried by fiddlybits-wvu and the registry anchor of ocean.strait_control_identity by fiddlybits-n13.
