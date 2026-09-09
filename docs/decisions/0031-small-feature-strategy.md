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
graph is derived from the terrain level every slow step: for every pair of adjacent
coarse ocean cells the minimum sill depth and the width of the connection; for land,
contiguity; for basins, the drainage terminal. A change in the graph's topology (a
seaway closes, a land bridge floods, a basin captures its neighbour) is an *event*
that forces a climate refresh, so a closure happens when it happens rather than being
averaged away by the slow tier. A cell with land fraction between zero and one holds
an island or lake tile with its own land column; an island is never rounded to ocean
and a strait is never rounded to land. The tile's area and hypsometry come from the
fine level exactly.

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
sets an inland sea's salinity and a gateway's exchange. A land bridge blocks ocean
flow exactly and carries a land tile. Mountain passes carry their sub-grid slope
statistics into orographic drag and precipitation.

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

## Consequences

- The connectivity graph is a first-class artifact with its own identity and its
  own tests (a synthetic strait's sill depth and width recovered exactly from the fine
  level; a topology change firing the refresh event).
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
