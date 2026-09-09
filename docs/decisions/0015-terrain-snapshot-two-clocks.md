+++
id = "0015"
title = "Terrain and lithology are a snapshot carrying two declared clocks"
status = "accepted"
date = 2026-09-08
+++

## Decision

The terrain subsystem produces a point-in-time snapshot of the solid surface whose
state carries its own ages and rates, so that every downstream derivative (regolith,
weathering, soil age, cover lithology, mineral overlay) has a real clock to reference.
It does not produce a geological history.

**Two clocks, both declared, both in SI seconds on the system clock (0008).**

- *Deep clock.* The tectonic seed assigns an age to every province: craton
  stabilisation, orogen initiation, rift opening, arc initiation, hotspot track
  progression, passive-margin breakup. These are declared draws from declared
  distributions (disposition `Bracketed`, with the reference distribution reported as
  a distance, never as a target). Plate and uplift rates are `Bracketed` the same
  way, declared beside the lithosphere block of System (0004) whose mantle thermal
  state they physically share a cause with. Basement lithology, thermal subsidence,
  flexure, the basal heat flux and the mineral overlay read this clock.
- *Surface clock.* A landscape-evolution integration of declared duration `T_int`
  (`Bracketed`). During it every cell accumulates real uplift, erosion, deposition,
  denudation and exposure. Plates do not advect during `T_int`; the seed builds the
  *decayed* initial state of its age model (an orogen of age `t_o` starts at the relief
  a landscape with the declared erodibility would hold after `t_o` of decay; a passive
  margin starts at its thermal-subsidence depth for its age). What comes out is a
  landscape that is knowingly not at equilibrium, which is the honest state of any
  real snapshot.

**Processes included.**

| process | law | disposition of constants |
|---|---|---|
| tectonic seed | Voronoi plates on the sphere with random Euler poles; boundary class from relative velocity; continental and oceanic crust per plate with craton cores; arcs on the overriding plate; hotspot traces as a Poisson process along absolute motion; uplift field per boundary class with age-dependent decay | rates and ages `Bracketed` distributions |
| stream-power incision | `dz/dt = U - K Q^m S^n`, defined once, here (sill incision in REQ-HYD-008 points to this row); `Q` is the runoff accumulated along the drainage graph, read from hydrology (0019), never the drainage area under an assumed runoff; `K = rho_w g k_e`, with `rho_w` read from the water-property door of 0017 (pure-water limb) at the column's mean soil temperature, and `k_e` carrying the dimension `Pa^-1 m^(1-3m) s^(m-1)`, so gravity enters the law exactly once and never as a post-hoc relief scaling; implicit solve along receivers | `k_e` `Bracketed`: one absolute anchor converted from a field coefficient by the rule below, its ends the weakest and strongest expressed lithologies of the class table (REQ-TER-015); `theta = m/n` `Bracketed` between the shear-stress and the unit-stream-power derivations of Whipple and Tucker (1999) under the declared channel-width exponent; `m` `Derived = theta n`; `n` `Bracketed` between the detachment-linear-in-stress end and the stress-squared end, swept |
| sediment continuity | deposition term `G q_s / A` in the Yuan et al. (2019) form, where `G` stands for a settling velocity over a runoff rate (Davy and Lague 2009) and is dimensionless only because those two are hidden inside it; here `G` is `Derived` from a `Sourced` settling law (Ferguson and Church 2004) evaluated with `g` from `System` and `rho_w`, `mu` from the water-property door of 0017 (pure-water limb) at the column temperature, a `Bracketed` grain size, and the cell's runoff rate from hydrology (0019); deposition where capacity is exceeded; lake trapping `Derived` from the same settling velocity and the lake's residence time (volume over inflow, from hydrology), never a trapping-efficiency curve | settling law `Sourced`; grain size `Bracketed` between the finest and the coarsest fluvially carried class of the lithology table; the published dimensionless `G` is the reported Earth distance, never the value |
| closed basins as physics | a pit is a lake node receiving water (level from hydrology, 0019) and sediment (floor rises); the sill of a basin whose lake reaches spill is incised at the stream-power rate driven by the overflow discharge and the time fraction spent overflowing; a basin that never spills is never incised | none beyond the incision law |
| hillslope transport | nonlinear diffusion with critical slope `S_c`; at the terrain level every resolved slope is a channel or a basin floor, so this term is declared as the sub-grid closure it is, and the transport it stands for is the sub-grid application of the incision law above: `D` (dimension `m^2 s^-1`) is `Derived` from `k_e`, the sub-grid runoff and the sub-grid relief distribution at the spacing, so gravity and runoff enter it through the same `K` and never a second time; an Earth soil-creep diffusivity (Roering et al. 1999) is the reported distance, never the value | `D` `Closure`: its scaling law in the spacing stated dimensionally, its dimensionless coefficient `Bracketed` between the arm where the sub-grid network is at grade and the arm where it is transient, swept across two levels; `S_c` `Sourced` (a friction angle, gravity-free) |
| sub-grid relief | per-cell relief distribution from channel steepness and `S_c`, limited by the strength process `H_max = sigma_c / (rho g)` applied as landsliding (REQ-TER-014), never as a clamp; exported as the hypsometry each climate tile reads | `sigma_c`, densities `Sourced` |
| glacial erosion | `E_g = K_g N^r \|u_b\|^l`, where the cryosphere (0020) supplies the ice mask, the basal sliding velocity `u_b` and the effective pressure `N = rho_i g H`. The velocity limb alone (Herman et al. 2015) carries gravity only through `u_b`; the pressure limb is what lets the law move between the flux-conserved and thickness-conserved ends that REQ-TER-013 records, so the width of that bracket is now the declared spread of `r` and `l`, not a hidden choice. `K_g` carries the dimension `Pa^-r m^(1-l) s^(l-1)`; an Earth fit quoted per year is converted with its exponents (REQ-TER-018) | `r` `Bracketed` between the abrasion end (erosion proportional to the normal contact force times sliding, Hallet 1979) and the quarrying end (Iverson 2012); `l` `Bracketed` between the linear-in-sliding and the squared-in-sliding ends; `K_g` `Bracketed` between the Earth fits at the ends of `r` and `l`, each converted by dimension |
| flexural isostasy | `D nabla^4 w + delta_rho g w = load`, multigrid on the hierarchy; rigidity `D = E T_e^3 / (12 (1 - nu^2))` with `E` and `nu` `Sourced` rock properties; `T_e` `Derived` as the depth of a `Sourced` yield isotherm on the province geotherm, computed from the lithosphere block of System (0004) and the deep clock (the same geotherm as the thermal subsidence row); `delta_rho` from the mantle density of that block and the infill density `Derived` from the cover stratigraphy this record owns (the density of the cover class that fills the load); the crustal thickness the Airy limit needs is the province class's value from the same block, thickened by the orogen's integrated uplift under Airy, so it is `Derived` from `Bracketed` inputs and not computed from a crust-production law, which this system does not hold and names as a declared absence; Airy as the `D -> 0` check | `E`, `nu`, yield isotherm `Sourced`; mantle and crust parameters from the lithosphere block (0004), `Bracketed` with Earth as the reported distance |
| thermal subsidence | half-space cooling (the cooling forms of Turcotte and Schubert 2014) on oceanic and stretched continental lithosphere from the seed's ages, evaluated in the mantle potential temperature, thermal diffusivity, expansivity, radiogenic heat production and densities of the lithosphere block of System (0004); the ridge depth is `Derived` by isostasy against the declared water inventory and the ocean's area, never a quoted depth; the plate-cooling depth-age fit of Stein and Stein (1992) is an Earth tier-2 REPORT, never the formula. The same geotherm yields the basal heat flux per province and age; the soil column (0018) reads that flux from the terrain as its bottom boundary, one definition, owned here | forms `Sourced`; parameters `Bracketed` in the lithosphere block with Earth as the reported distance |
| vegetation effects on erosion | root cohesion raises the incision threshold, which is a critical shear stress in pascals converted to the law through `rho_w g` and a flow depth from a threshold-channel relation (Parker 1978) carrying `g` explicitly, never through a hydraulic-geometry fit in metres; canopy and litter cover reduce hillslope erodibility; biotic weathering rates enter regolith production; all read from the vegetation subsystem (0021) | threshold stress `Sourced` per root class; the threshold-channel width coefficient `Bracketed` between the cohesionless-bank and root-reinforced-bank ends; other coefficients `Bracketed` |
| stratigraphy per cell | basement class and age; cover layers (fluvial, lacustrine, evaporite, glacial, aeolian, marine) each with thickness, class and deposition age; exposure age; cumulative denudation; current uplift and erosion rates | state, not constants |

**The incision coefficient's anchor.** A field-calibrated stream-power coefficient
is quoted for a drainage-area form under one landscape's runoff, gravity and water,
in per-year units, so it carries that landscape's runoff-to-area conversion, its
`rho_w g` and its year folded into one number. The conversion to `k_e` is done once,
by the dimension type: divide by the source landscape's `rho_w g`, by its mean runoff
raised to `m` (the discharge-to-area conversion the source folded in), and by the
source's year raised to the power the coefficient carries (REQ-TER-018). The source,
its runoff and its year travel with the `Sourced` datum; a coefficient quoted
without them is refused at load. The expressed lithology contrast (REQ-TER-015)
scales that one anchor, and the model's own runoff enters only through `Q`. Every
coefficient in the table that uses water density or viscosity reads them from the
water-property door of 0017 (pure-water limb) at the column's mean soil
temperature; none carries a water constant of its own.

**Requestable features.** The seed exposes arcs, land bridges, archipelagos, inland
seas and rift lakes as things a configuration can ask for, so the interesting places
of a world are not accidents of the random draw. Requested features are recorded in
the configuration and carried through the connectivity graph (0005).

**Excluded, with reasons.** Plate advection and remeshing during `T_int` (the
integration cannot be long enough to be a kinematic history without an advection
scheme this system does not need). Mantle-flow dynamic topography (declared as a
long-wavelength component of the seed). Procedural detail noise (replaced by the
physical sub-grid relief closure; any texture a map wants is a rendering choice and
never enters a physical field).

**Placement and stepping.** The terrain level of the mesh hierarchy (0005), chosen by
the profile (0014) to hit a target spacing. Terrain steps in the slow tier (0023);
implicit incision has no CFL constraint; diffusion is implicit. The depression
hierarchy (0019) is rebuilt when the terrain changes.

**Routing on triangles.** Steepest-receiver routing on a regular mesh locks channels
to lattice axes. Accumulation and sediment use slope-weighted multiple flow direction
on the twelve-vertex-neighbour stencil; the implicit incision uses the steepest
receiver with random tie-breaking keyed on cell identity (0010). Drainage-density
isotropy by azimuth is the test with a right answer (an identity on a symmetric
synthetic uplift). Hack's law exponent is an Earth empirical value, not an
identity: it is a REPORT metric, and where the steady-profile oracle needs a
length-area relation it takes the exponent as a declared parameter of the synthetic
profile, never as an assertion.

**Exchanges (terrain owns topography, bathymetry, stratigraphy, ages, rates,
erodibility, sub-grid hypsometry).** Reads: runoff and overflow statistics
(hydrology), ice mask, sliding velocity and load (cryosphere), evaporite and carbonate
precipitation mass per basin (pedology), root cohesion and cover (vegetation), water
loads (hydrology). Writes: to every other subsystem.

## Alternatives considered

- *A procedural generator with no clock* (the predecessor's approach). Rejected: a
  duration was undefined rather than unmeasured, so soil age, basin infill, relaxation
  windows and lake residence all had to be argued from an expected value over a
  stationary population. That reasoning class disappears when ages are state.
- *A full plate-kinematic history with advection.* Rejected: far larger scope, and
  not what the requirement asks for. The requirement is a snapshot whose derivatives
  carry time markers.
- *Gravity as a relief scaling at export.* Rejected: it hid gravity's separate
  entries through the erosion coefficient, isostasy and rock strength behind one
  factor, and the predecessor found the rule written out at three call sites.

## Consequences

- The carve decision of the predecessor's loop A becomes a physical competition
  between sill incision and sediment infill, integrated in the slow tier (0019, 0023).
- Every downstream weathering, regolith and mineral law can integrate over a real
  exposure age instead of a normalised intensity.
- Sub-grid relief is a claim to be earned: the hypsometry the climate tiles read must
  pass the scale-matched terrain oracles (0025) on the Earth test instance. On any
  other configuration those Earth-landscape statistics (hypsometry in absolute
  height, concavity, drainage density, endorheic share, denudation against relief)
  are REPORT distances, because this record rejects rescaling relief by gravity and
  no other transport of an Earth landscape bar exists; the convergence-with-level
  and noise-floor controls (REQ-TER-016) apply on every configuration.
- Exposure ages saturate at `T_int` on never-exhumed cells and fall back to the seed's
  basement age; the record says so.

## References

- Braun, J. and Willett, S. D., "A very efficient O(n), implicit and parallel method to solve the stream power equation governing fluvial incision and landscape evolution", Geomorphology 180-181 (2013). DOI: 10.1016/j.geomorph.2012.10.008
- Yuan, X. P., Braun, J., Guerit, L., Rouby, D. and Cordonnier, G., "A New Efficient Method to Solve the Stream Power Law Model Taking Into Account Sediment Deposition", Journal of Geophysical Research: Earth Surface 124 (2019). DOI: 10.1029/2018JF004867
- Whipple, K. X. and Tucker, G. E., "Dynamics of the stream-power river incision model: Implications for height limits of mountain ranges, landscape response timescales, and research needs", Journal of Geophysical Research: Solid Earth 104 (1999). DOI: 10.1029/1999JB900120
- Roering, J. J., Kirchner, J. W. and Dietrich, W. E., "Evidence for nonlinear, diffusive sediment transport on hillslopes and implications for landscape morphology", Water Resources Research 35 (1999). DOI: 10.1029/1998WR900090
- Herman, F. et al., "Erosion by an Alpine glacier", Science 350 (2015). DOI: 10.1126/science.aab2386
- Stein, C. A. and Stein, S., "A model for the global variation in oceanic depth and heat flow with lithospheric age", Nature 359 (1992). DOI: 10.1038/359123a0
- Montgomery, D. R. and Brandon, M. T., "Topographic controls on erosion rates in tectonically active mountain ranges", Earth and Planetary Science Letters 201 (2002). DOI: 10.1016/S0012-821X(02)00725-2
- Istanbulluoglu, E. and Bras, R. L., "Vegetation-modulated landscape evolution: Effects of vegetation on landscape processes, drainage density, and topography", Journal of Geophysical Research: Earth Surface 110 (2005). DOI: 10.1029/2004JF000249
- Perron, J. T. and Royden, L., "An integral approach to bedrock river profile analysis", Earth Surface Processes and Landforms 38 (2013). DOI: 10.1002/esp.3302
- Tarboton, D. G., "A new method for the determination of flow directions and upslope areas in grid digital elevation models", Water Resources Research 33 (1997). DOI: 10.1029/96WR03137
- Turcotte, D. L. and Schubert, G., "Geodynamics", 3rd edition, Cambridge University Press (2014). ISBN 978-0-521-18623-0 (flexure, isostasy, thermal subsidence)
- Hack, J. T., "Studies of longitudinal stream profiles in Virginia and Maryland", U.S. Geological Survey Professional Paper 294-B (1957). Locator: USGS PP 294-B
- Davy, P. and Lague, D., "Fluvial erosion/transport equation of landscape evolution models revisited", Journal of Geophysical Research: Earth Surface 114 (2009). DOI: 10.1029/2008JF001146 (the settling-velocity over runoff-rate content of the deposition coefficient)
- Ferguson, R. I. and Church, M., "A Simple Universal Equation for Grain Settling Velocity", Journal of Sedimentary Research 74 (2004). DOI: 10.1306/051204740933
- Hallet, B., "A theoretical model of glacial abrasion", Journal of Glaciology 23 (1979). DOI: 10.3189/S0022143000029725
- Iverson, N. R., "A theory of glacial quarrying for landscape evolution models", Geology 40 (2012). DOI: 10.1130/G33079.1
- Parker, G., "Self-formed straight rivers with equilibrium banks and mobile bed. Part 2. The gravel river", Journal of Fluid Mechanics 89 (1978). DOI: 10.1017/S0022112078002505 (the threshold-channel relation that carries gravity explicitly)

## Amendments

- 2026-09-08: incision law written once in discharge form with `K = rho_w g k_e`, `k_e`'s dimension, `theta` Bracketed and `m` Derived, and the Earth-field anchor conversion rule (rows 1, 9 and 27 of the audit), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: thermal subsidence, ridge depth, elastic thickness, crustal thickness and basal heat flux derived from the lithosphere block of System (0004), GDH1 demoted to an Earth REPORT, one geotherm owned here for the soil column to read (rows 2, 6, 7 and 22), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: glacial erosion given its effective-pressure limb `E_g = K_g N^r |u_b|^l` with `r`, `l` Bracketed and `K_g`'s dimension stated (row 3), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: deposition coefficient `G` and lake trapping derived from a sourced settling law with `g`, `rho_w`, `mu` from System and the water-property door of 0017, over the runoff rate (rows 5 and 23), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: hillslope closure `D` derived from the incision coefficient at the sub-grid scale so gravity and runoff enter once; strength limit reworded as a process (rows 8 and 29), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: incision threshold stated as a stress in pascals converted through `rho_w g` and a threshold-channel depth (row 24); Hack's exponent moved from identity to REPORT (row 25); plate rates declared beside the lithosphere block (row 28); Earth-landscape terrain oracles scoped to the Earth test instance, REPORT elsewhere (row 11), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: water density and viscosity read from the water-property door of 0017 (pure-water limb); the infill density of the flexure row `Derived` from the cover stratigraphy; the glacial-erosion pressure exponent renamed `r` so `p` stays the sliding exponent; Hallet 1979 identifier filled, from notes/findings/2026-09-08-implicit-earth-audit.md
