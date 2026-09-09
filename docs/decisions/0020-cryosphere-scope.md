+++
id = "0020"
title = "Cryosphere: shallow-ice flow on the terrain level, mass balance from the land column"
status = "accepted"
date = 2026-09-08
+++

## Decision

**Mass balance** comes from the land column's glacier tile (0018): a surface energy
balance on ice and firn under the declared spectrum with the shared snow model, not a
temperature-index scheme. Surface mass balance per elevation band is downscaled to
terrain cells by elevation.

**Flow.** Shallow-ice approximation on the terrain level for glaciers and ice sheets
alike: Glen's law with `(rho_i g)^n` explicit, a Weertman-type sliding law with
effective pressure `rho_i g H`, explicit time stepping with adaptive substeps, active
only on the sparse glaciated set. Face fluxes are antisymmetric so volume is
conserved exactly; the full surface gradient is reconstructed on the twelve-neighbour
stencil, because a two-point normal slope made the predecessor's prototype
non-contractive. The Halfar similarity solution is the test with a right answer. The
interface admits an implicit multigrid solver and a higher-order stress balance if a
configuration's substepping ever binds; both are declared absences.

**Sub-grid glaciers.** Valley glaciers narrower than the terrain spacing live in the
glacier tile as ice stores driven by surface mass balance with the volume-area
scaling of Bahr et al. (1997), and are reported as sub-grid ice, never folded into
the resolved field. Bahr's exponent follows from Glen's `n` and the column's
mass-balance exponent, and the coefficient from the solver's `Gamma` (so from
`(rho_i g)^n` and `A(T)`) and the column's own mass-balance gradient by the same
dimensional argument; both are `Derived` here, so gravity enters the tile stores as
it enters the resolved flow, and the published Earth coefficient is the reported
distance, never the value.

**Feedbacks.** Ice mask, sliding velocity and effective pressure `N = rho_i g H` to
the terrain's two-limb glacial erosion law `E_g = K_g N^r |u_b|^l` (0015,
REQ-TER-013);
ice load to flexural isostasy; ice and firn optics through the shared snow model;
meltwater to hydrology (0019).

**Permafrost** emerges from the soil heat column (0018); there is no separate module.
The column's bottom boundary is the basal heat flux per province and age that the
terrain derives from the lithosphere block of System (0004) through its cooling
geotherm (0015); the soil column reads it from the terrain, one definition, never a
constant flux.

**Excluded, with reasons.** Ice shelves, grounding lines and calving (declared
absence with the interface named; a configuration with a marine ice sheet buys them).
Subglacial hydrology (effective pressure is overburden; declared).

**Constants.** Glen's `A(T)` and `n` `Sourced` (material), `A` carrying `Pa^-n s^-1`
(REQ-CRY-002); sliding coefficient `Bracketed` with its dimension `m s^-1 Pa^-(p-q)`
stated, its ends the hard-bed and soft-bed field fits re-read under this record's
overburden convention for `N`, since those fits were made where basal water pressure
lowers `N`; firn densification `Sourced` with `g` explicit in the overburden and its
accumulation-rate terms converted from the source's year by dimension (REQ-TER-018);
volume-area scaling exponent and coefficient `Derived` (above).

**Exchanges (cryosphere owns ice thickness, velocity, mask, glacial erosion rate,
sub-grid ice stores).** Reads: surface mass balance (land column), bed and load
response (terrain). Writes: terrain (erosion, load), land column (tile areas),
hydrology (meltwater).

## Alternatives considered

- *No ice flow; vertical growth only* (the predecessor's climate model). Rejected:
  extent is then underestimated wherever ice would spread, and glacial erosion has no
  velocity to act with.
- *Temperature-index mass balance.* Rejected: it is an Earth calibration of ablation
  against air temperature; the column already computes melt from radiation under the
  declared spectrum.
- *Higher-order or full-Stokes flow.* Deferred as a declared absence; nothing at the
  operating spacing needs it, and the interface admits it.

## Consequences

- Where ice forms is an outcome of relief, mass balance and flow; no latitude enters.
- Glacial erosion has a physical velocity and pressure, and the erosion law carries
  both limbs (0015), so the gravity dependence the predecessor bracketed across
  several powers is computed within the declared brackets of `r` and `l`; a
  velocity-only law could not carry it.

## References

- Bueler, E. and Brown, J., "Shallow shelf approximation as a "sliding law" in a thermomechanically coupled ice sheet model", Journal of Geophysical Research: Earth Surface 114 (2009). DOI: 10.1029/2008JF001179
- Halfar, P., "On the dynamics of the ice sheets 2", Journal of Geophysical Research: Oceans 88 (1983). DOI: 10.1029/JC088iC10p06043
- Bahr, D. B., Meier, M. F. and Peckham, S. D., "The physical basis of glacier volume-area scaling", Journal of Geophysical Research: Solid Earth 102 (1997). DOI: 10.1029/97JB01696
- Cuffey, K. M. and Paterson, W. S. B., "The Physics of Glaciers", 4th edition, Academic Press (2010). ISBN 978-0-12-369461-4 (Glen's law, sliding, firn densification)
- Herman, F. et al., "Erosion by an Alpine glacier", Science 350 (2015). DOI: 10.1126/science.aab2386

## Amendments

- 2026-09-08: volume-area scaling exponent and coefficient made Derived by Bahr's dimensional argument from `Gamma` and the column's mass-balance gradient (row 19), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: feedback to terrain names the effective pressure and the two-limb erosion law, and the consequence says the velocity limb alone cannot carry the gravity dependence (row 3), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: permafrost column's basal heat flux read from the terrain's geotherm, one definition (row 22); sliding-coefficient ends re-read under the overburden convention and firn accumulation terms converted by dimension (rows 31 and 34), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: the glacial-erosion pressure exponent renamed `r` so `p` stays the sliding exponent, from notes/findings/2026-09-08-implicit-earth-audit.md
