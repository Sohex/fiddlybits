+++
id = "0017"
title = "Ocean, sea ice and marine ecosystem on the shared mesh, coupled synchronously"
status = "accepted"
date = 2026-09-08
+++

## Decision

**Ocean core.** Hydrostatic Boussinesq primitive equations on the same mesh family as
the atmosphere (0005, 0013), sharing its horizontal operators, so one set of
discretised operators serves both fluids. The Boussinesq reference density is
`Derived` as the volume-mean in-situ density of the initial state from the equation
of state; the largest density excursion over it is a reported diagnostic with a
refusal threshold for the Boussinesq form, so a very deep or a hypersaline ocean
refuses rather than degrades. Vertical: z* levels with partial bottom cells, placed
against the mixed-layer and thermocline depth scales per the profile's ladder (0014);
both scales are `Derived` from the declared system and the profile's forcing bracket
(the Ekman depth from the wind-stress bracket and the Coriolis parameter; the
thermocline scale from the interior diapycnal diffusivity and the overturning
estimate) or `Bracketed` per profile with those two mechanisms named, and a profile
carries no depth literal. Implicit free surface solved by multigrid on the hierarchy;
there is no barotropic streamfunction and therefore no island constraint on an
unstructured mesh. Equation of state TEOS-10 (`Sourced` for the seawater it was
fitted to; the composition axis is stated below). Eddy parameterisation
Gent-McWilliams with Redi rotation: `kappa` is a `Closure` whose scaling law is
named (the square of the Rossby radius over an eddy time scale such as the Eady
growth time, Visbeck et al. 1997, with the dimensionless coefficient `Bracketed`;
mechanisms: suppression by the mean flow at the low end, the full baroclinic growth
rate at the high end), because the spacing and the Rossby radius alone do not fix a
dimensional diffusivity; the isopycnal-slope tapering threshold is a numerical
`Closure` in the grid aspect ratio with a diagnostic of the cells where it binds.
Mixed layer by a nonlocal K-profile or the same TKE closure the atmosphere uses;
the dimensionless numbers of either (critical Richardson numbers, surface-layer
fraction, shape function) are `Sourced` and carry no planet, and every dimensional
interior diffusivity of the scheme (the shear-instability maximum, the
double-diffusion scale) is a `Closure` in the resolved shear and stratification with
its coefficient `Bracketed`; the double-diffusion branch reads the molecular
diffusivities of heat and solute from the seawater-properties door below.
Convective adjustment. Quadratic bottom drag (`Bracketed`; mechanisms: a smooth
abyssal floor at the low end, rough ridge and shelf topography at the high end);
any residual tidal velocity in the drag law is `Derived` from the tidal component
or is zero under the declared absence, never a literal.

**Interior mixing.** The interior diapycnal diffusivity is a field of this record,
not of the mixed-layer scheme: a `Closure` in the resolved stratification with its
coefficient `Bracketed` and both ends named. The low end is the molecular
diffusivity plus the near-inertial energy the atmosphere's stress supplies, which
exists on any world with wind. The high end is the tidal dissipation the 0032
component delivers when it is written, which exists only for the declared moons and
stars. The sweep of this bracket is mandatory for any configuration whose moons
differ from the test instance, because the interior diffusivity sets the abyssal
stratification and the overturning strength (Munk and Wunsch 1998); under the
declared absence of tides the high end is absent and the run report names the
absence.

**Seawater properties and the composition axis.** Every property of the water is
read through one door, a seawater-properties component that the ocean, the sea
ice, the carbonate chemistry and the atmosphere's surface humidity all consume,
and that door reads the ionic composition declared in the ocean solute inventory
(0004). The door has two limbs. The pure-water limb is the IAPWS-95 formulation,
`Sourced`: density, viscosity, thermal conductivity, heat capacity and the other
thermal properties of liquid water as functions of temperature and pressure, read
at zero salinity; every terrain, hydrology, land-column and pedology kernel that
needs a property of fresh water reads this limb, and no record carries a water
constant of its own. The saline limb is TEOS-10, which carries the saline part
(density, thermal expansion, haline contraction, heat capacity, sound speed,
freezing point, vapour pressure) only for the Reference Composition it was fitted
to (Millero et al. 2008); Absolute Salinity is itself defined against that
composition; and the function cannot be re-derived for another solute. So the
saline equation of state, the carbonate equilibria, the freezing point, the
salinity reduction of the vapour pressure, the viscosity and the molecular
diffusivities are `Irreducible` inside the Reference-Composition anomaly tolerance
and refused beyond it (0004); the general form, an ion-specific Gibbs or Pitzer
model, is a declared absence with its interface in place. The condensable's latent
heats, its saturation vapour pressure over pure water and its surface tension are
owned by REQ-ATM-017; the door applies the salinity reduction to that pure curve,
so each quantity has one owner. A lake inside the tolerance reads this door at its
own salinity; a closed-basin brine beyond the tolerance reads its density and
freezing point from the brine activity model of 0022 (0018, REQ-ATM-012,
REQ-HYD-010). The validity domain of every fit in (S, T, p) is declared and
refused outside (REQ-OCN-003), and the pressure ceiling of TEOS-10 is the refusal
boundary for a deep ocean.

**Carbonate chemistry and gas exchange.** The equilibrium constants of the
carbonate system (gas solubility, the two carbonic-acid dissociations, borate,
water, sulfate, fluoride, calcite and aragonite solubility) are `Sourced` with a
declared validity domain in (S, T, p) and refused outside it, the rule REQ-OCN-003
gives the equation of state; the total boron, sulfate and fluoride that set the
borate share of alkalinity and the pH scale are `Derived` from the declared
composition, never ratios to salinity. Gas solubility and the fugacity conversion
take the local surface pressure and the declared mole fraction of the gas from the
atmosphere, not a fixed reference pressure. The air-sea transfer velocity is a
function of the water-side friction velocity, obtained from the stress the
atmosphere writes so that air density enters through REQ-ATM-017, and of the
Schmidt number, with the dimensionless coefficient `Bracketed` (mechanisms:
surface renewal at the low end, bubble injection at the high end); the Schmidt
number is `Derived` from the modelled viscosity and the `Sourced` molecular
diffusivity of the gas. The classical law in wind speed at a reference height
(Wanninkhof 2014) was fitted at Earth air density and calibrated against an Earth
radiocarbon inventory, and is kept only as the comparison in `EarthRatios`.

**Initial state.** The initial temperature and salinity fields of a spin-up are
`Derived` by a named rule from the declared system (isothermal at a temperature
taken from the configuration's radiative estimate; salinity uniform at the
inventory mean), and the rule is recorded in the run's provenance. An observed
profile is never an initial condition, because a drift criterion under tracer
acceleration cannot distinguish a deep ocean that has equilibrated from one that
started near a foreign equilibrium; the Earth test instance is the one exception
and is labelled as such.

**Coupling.** Synchronous, inside the one process (0009). The ocean steps at its own
timestep, sub-cycled by the coupler. The predecessor's offline transport loop does
not exist here: the atmosphere never learns to carry the whole poleward heat load
because the ocean transports from the first orbit. Deep spin-up alternates coupled
segments with ocean-only segments forced by the coupled segment's surface-flux
climatology under tracer timestep acceleration; the criterion for leaving
acceleration is a deep-temperature drift bracket declared before the run.

**Straits and connectivity.** The connectivity graph (0005, 0031) supplies, for every
pair of ocean bodies of adjacent coarse cells joined across a coarse edge, the sill
depth and width of their gate. Where a strait is narrower than the ocean spacing its
exchange is parameterised by rotating hydraulic control (sill depth, width against the
Rossby radius, density contrast across it) rather than left to the coarse cell
geometry; a topology change in the graph is an event that forces a climate refresh
(0023). Refinement around a strait follows the graded-transition rule of 0005 when the
sensitivity probe flags it.

**Tides.** The interface for tidal forcing (equilibrium tide potential from the
declared moons and star, 0007 and 0008) and for tidal mixing (a dissipation field on
the bathymetry) is complete from the start; the physics is a declared absence until
the moon-scope decision (0032) buys it. When the component exists the dissipation
field is `Derived`: from the barotropic tidal solution on this mesh under the
declared potential and from the bathymetric roughness of the terrain level through
internal-tide conversion (St Laurent, Simmons and Jayne 2002; the inference from
altimetry in Egbert and Ray 2000 is the Earth comparison), with the local
dissipation efficiency and the vertical decay scale `Bracketed` (mechanisms:
radiation of low modes away from the site at the low end, local breaking of high
modes at the high end). The field is never read from a dataset; under the declared
absence it is zero and the run report names the absence.

**Salinity.** A real budget: freshwater and solute delivery from rivers at coastal
cells with embayment-first spreading (0019), evaporation minus precipitation over the
ocean, brine rejection and meltwater from sea ice, evaporite precipitation in closed
marginal seas as a sink (`Bracketed`). The global salt inventory is a declared
`Bracketed` initial condition, because the system has no mechanism to derive it from
the solid planet yet; its distribution is predicted and its secular drift is reported. The evaporite sink
reads the same activity model and chemical-divide logic as the pedology's brine
chemistry (0022), one definition with two doors, under the composition fence above;
its `Bracketed` coefficient is the precipitation kinetics (mechanisms:
mixing-limited nucleation at the low end, instantaneous equilibrium at the high
end), never the saturation threshold, which is a property of the declared
composition.

**Bathymetry.** From the terrain level exactly: ocean fraction per ocean cell is the
fraction of its children below sea level; cell depth is the volume-conserving
area-weighted mean with the deep-percentile depth kept as a diagnostic. Straits
narrower than the spacing are carried by the graph, never quietly accepted or
rejected.

**Sea ice.** Winton three-layer thermodynamics with prognostic snow. The freezing
point and the liquidus slope inside Winton's brine-pocket heat capacity and
conductivity are read from the one freezing-point function of REQ-OCN-003, so the
composition enters once; the brine-conductivity coefficient is `Bracketed`
(mechanisms: thin first-year ice at the low end, thick multiyear ice at the high
end) about the fit with its Arctic-ice provenance and its composition limit stated;
ice salinity is `Bracketed` between the first-year and the multiyear values until
it is prognostic (REQ-OCN-011). Albedo per band from the same grain and
impurity snow model the land column uses (0018); the shortwave that penetrates bare
ice and is absorbed within it is per band, `Derived` from the radiation's band
structure with a per-band ice absorption coefficient `Sourced`, and there is no
broadband penetrating-fraction literal, because that fraction is the visible share
of one star's spectrum. Lead fraction: the lead-closing thickness of the Hibler
(1979) law is `Bracketed` (mechanisms: rapid thin-ice growth that closes leads at
the low end, rafting and ridging of thin ice at the high end); the floe size of the
lateral-melt law is `Bracketed` (mechanisms: wave fracture at the low end,
thermodynamic consolidation at the high end); the lateral-melt coefficients are
`Bracketed` (mechanisms: thin first-year ice at the low end, thick multiyear ice at
the high end) about the Maykut and Perovich (1987) fit with its Arctic provenance.
Those
formulations carry the thickness dependence of the closing rate and the
temperature dependence of the melt rate; neither derives its length scale, which
is why the scales are `Bracketed` and no record claims a derivation. Dynamics: free
drift under the stress the atmosphere writes, ocean drag against the ice-ocean
relative velocity and Coriolis, with a thickness-dependent internal-stress cap
(REQ-OCN-011: cap and drag coefficients `Bracketed` and dimensionless, turning
angle emergent or `Derived`, basal heat and salt exchange with no friction-velocity
floor), advected by flux-corrected transport. Sea ice is owned here; the atmosphere
reads its state.

**Marine ecosystem.** A trait-based plankton community in the same family as the land
vegetation model (0021): size- and strategy-structured phytoplankton and zooplankton
with declared trait ranges, growth limited by nitrogen, phosphorus, light under the
declared spectrum and, where its speciation makes it scarce, iron, grazing, export
and remineralisation with depth. Iron speciation and scavenging are a named scheme
that is a function of the modelled oxygen and pH state, with the ligand
concentration `Bracketed` (mechanisms: photolysis and scavenging loss at the low
end, biological ligand production at the high end), so that iron limitation is an
outcome of the ocean's redox state and never a declared limiter: it exists on an
oxic ocean because the oxidised metal is insoluble, and a low-oxygen ocean keeps
the reduced metal in solution. It
carries dissolved inorganic carbon and alkalinity for the carbon loop (0022) and net
primary productivity for the managed biosphere (0024). The biology assumption of 0021
applies (an Earth-like biochemistry in a planet-filtered strategy space) and is
declared as `Irreducible` in the same record.

**Excluded, with reasons.** Frictional-geostrophic dynamics (see alternatives). Ice
shelves and calving (0020). Sediment diagenesis beyond a lysocline burial
parameterisation (0022). Full sea-ice rheology (see alternatives).

**Exchanges (ocean owns sea-surface temperature and salinity, currents, mixed-layer
depth, ice thickness, concentration and velocity, ocean DIC and alkalinity, marine
NPP).** Reads: surface stress and friction velocity, heat and freshwater fluxes,
surface pressure and gas mole fractions, and deposition (atmosphere; air properties
per REQ-ATM-017), river water and solute discharge (hydrology), bathymetry and
connectivity (terrain, mesh), tidal potential and the ionic composition of the
solute inventory (system, 0004). Writes: surface state, including the seawater
vapour pressure at the surface salinity, to the atmosphere's flux routine; pCO2
exchange to carbon; productivity to the managed biosphere. The mixed-layer depth it
writes is the mixing scheme's own boundary-layer depth, one definition; a
density-threshold diagnostic exists only for the Earth report, at the dataset's own
threshold.

## Alternatives considered

- *Frictional-geostrophic ocean* (the predecessor's adopted model). Rejected: it is
  not cheaper on this mesh once the barotropic solve is unstructured, its drag
  coefficient is the sensitivity the predecessor's audit flagged, and its
  non-dimensionalisation carried another planet's radius and gravity in two places
  with two values. A primitive-equation ocean at coarse resolution costs little.
- *Slab mixed layer with prescribed or offline transport.* Rejected: an atmosphere
  equilibrated over a slab learns to carry the poleward heat load itself, and the
  predecessor needed a cross-pass partition loop to undo that. Synchronous coupling
  removes the loop.
- *Elastic-viscous-plastic sea-ice rheology.* Deferred: its rheology constants are
  Earth-polar tunings; free drift with a stress cap carries drift, which exists, without
  them. The interface admits a rheology if a configuration with thick perennial ice
  needs one.
- *Prescribed salinity.* Rejected: on a world where much of the land drains
  internally the delivery of solute to the ocean is the quantity least likely to match
  a declared number; the budget is the honest form.

## Consequences

- The horizontal operators are written once and tested once (shallow water gate,
  0013) for both fluids.
- Deep spin-up is an explicit protocol with a declared exit, not an offline loop.
- Strait exchange is state, and the Panama-class topology event is an event.
- The marine ecosystem gives the carbon loop and the managed biosphere their marine
  half from the same trait framework as the land.
- Every seawater property has one door, and the door reads the declared
  composition; a configuration outside the Reference-Composition tolerance refuses
  by name rather than answering for another ocean.
- No surface law in this record takes a wind speed at a reference height; the
  argument is the stress or friction velocity the atmosphere writes, and gravity.

## References

- Ringler, T., Petersen, M., Higdon, R. L., Jacobsen, D., Jones, P. W. and Maltrud, M., "A multi-resolution approach to global ocean modeling", Ocean Modelling 69 (2013). DOI: 10.1016/j.ocemod.2013.04.010
- Adcroft, A. and Campin, J.-M., "Rescaled height coordinates for accurate representation of free-surface flows in ocean circulation models", Ocean Modelling 7 (2004). DOI: 10.1016/j.ocemod.2003.09.003
- Adcroft, A., Hill, C. and Marshall, J., "Representation of Topography by Shaved Cells in a Height Coordinate Ocean Model", Monthly Weather Review 125 (1997). DOI: 10.1175/1520-0493(1997)125<2293:ROTBSC>2.0.CO;2
- IOC, SCOR and IAPSO, "The international thermodynamic equation of seawater - 2010: Calculation and use of thermodynamic properties", Intergovernmental Oceanographic Commission, Manuals and Guides No. 56 (2010). Locator: UNESCO IOC Manuals and Guides 56
- Gent, P. R. and McWilliams, J. C., "Isopycnal Mixing in Ocean Circulation Models", Journal of Physical Oceanography 20 (1990). DOI: 10.1175/1520-0485(1990)020<0150:IMIOCM>2.0.CO;2
- Redi, M. H., "Oceanic Isopycnal Mixing by Coordinate Rotation", Journal of Physical Oceanography 12 (1982). DOI: 10.1175/1520-0485(1982)012<1154:OIMBCR>2.0.CO;2
- Large, W. G., McWilliams, J. C. and Doney, S. C., "Oceanic vertical mixing: A review and a model with a nonlocal boundary layer parameterization", Reviews of Geophysics 32 (1994). DOI: 10.1029/94RG01872
- Bryan, K., "Accelerating the Convergence to Equilibrium of Ocean-Climate Models", Journal of Physical Oceanography 14 (1984). DOI: 10.1175/1520-0485(1984)014<0666:ATCTEO>2.0.CO;2
- Whitehead, J. A., "Topographic control of oceanic flows in deep passages and straits", Reviews of Geophysics 36 (1998). DOI: 10.1029/98RG01014
- Winton, M., "A Reformulated Three-Layer Sea Ice Model", Journal of Atmospheric and Oceanic Technology 17 (2000). DOI: 10.1175/1520-0426(2000)017<0525:ARTLSI>2.0.CO;2
- Flato, G. M. and Hibler, W. D., "Modeling Pack Ice as a Cavitating Fluid", Journal of Physical Oceanography 22 (1992). DOI: 10.1175/1520-0485(1992)022<0626:MPIAAC>2.0.CO;2
- Hunke, E. C. and Dukowicz, J. K., "An Elastic-Viscous-Plastic Model for Sea Ice Dynamics", Journal of Physical Oceanography 27 (1997). DOI: to confirm (named as the deferred alternative)
- Follows, M. J., Dutkiewicz, S., Grant, S. and Chisholm, S. W., "Emergent Biogeography of Microbial Communities in a Model Ocean", Science 315 (2007). DOI: 10.1126/science.1138544
- Ward, B. A., Dutkiewicz, S., Jahn, O. and Follows, M. J., "A size-structured food-web model for the global ocean", Limnology and Oceanography 57 (2012). DOI: 10.4319/lo.2012.57.6.1877
- Edwards, N. R. and Marsh, R., "Uncertainties due to transport-parameter sensitivity in an efficient 3-D ocean-climate model", Climate Dynamics 24 (2005). DOI: 10.1007/s00382-004-0508-8 (the frictional-geostrophic alternative)
- Millero, F. J., Feistel, R., Wright, D. G. and McDougall, T. J., "The composition of Standard Seawater and the definition of the Reference-Composition Salinity Scale", Deep-Sea Research I 55 (2008). DOI: 10.1016/j.dsr.2007.10.001 (the composition TEOS-10 is fitted to)
- Visbeck, M., Marshall, J., Haine, T. and Spall, M., "Specification of Eddy Transfer Coefficients in Coarse-Resolution Ocean Circulation Models", Journal of Physical Oceanography 27 (1997). DOI: 10.1175/1520-0485(1997)027<0381:SOETCI>2.0.CO;2 (the scaling law of the GM coefficient)
- Munk, W. and Wunsch, C., "Abyssal recipes II: energetics of tidal and wind mixing", Deep-Sea Research I 45 (1998). DOI: 10.1016/S0967-0637(98)00070-3 (the interior diffusivity's two mechanisms and its leverage on the overturning)
- St Laurent, L. C., Simmons, H. L. and Jayne, S. R., "Estimating tidally driven mixing in the deep ocean", Geophysical Research Letters 29 (2002). DOI: 10.1029/2002GL015633 (internal-tide conversion as the derived dissipation field)
- Egbert, G. D. and Ray, R. D., "Significant dissipation of tidal energy in the deep ocean inferred from satellite altimeter data", Nature 405 (2000). DOI: 10.1038/35015531 (the Earth comparison for the dissipation field)
- Wanninkhof, R., "Relationship between wind speed and gas exchange over the ocean revisited", Limnology and Oceanography: Methods 12 (2014). DOI: 10.4319/lom.2014.12.351 (the wind-speed law kept as the Earth comparison)
- Hibler, W. D., "A Dynamic Thermodynamic Sea Ice Model", Journal of Physical Oceanography 9 (1979). DOI: 10.1175/1520-0485(1979)009<0815:ADTSIM>2.0.CO;2 (the lead-closing law and the free-drift limit)
- Maykut, G. A. and Perovich, D. K., "The role of shortwave radiation in the summer decay of a sea ice cover", Journal of Geophysical Research 92 (1987). DOI: 10.1029/JC092iC07p07032 (the lateral-melt law)
- McPhee, M. G., "Turbulent heat flux in the upper ocean under sea ice", Journal of Geophysical Research 97 (1992). DOI: 10.1029/92JC00239 (the basal exchange law)

## Amendments

- 2026-09-08: Boussinesq reference density `Derived` from the equation of state with a refusal diagnostic; level-placement depth scales `Derived` or `Bracketed` with mechanisms, no depth literal (rows 6, 19), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: GM closure's scaling law named and slope tapering declared; KPP dimensionless numbers separated from its dimensional diffusivities, which are `Closure`; bottom-drag bracket mechanisms named and the tidal residual velocity `Derived` (rows 14, 20, 21), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: new Interior mixing paragraph: the interior diapycnal diffusivity as a `Closure`/`Bracketed` field of this record with both mechanisms named and a mandatory sweep when moons differ from the test instance (row 4), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: new Seawater properties paragraph: one door reading the ionic composition declared in the ocean solute inventory (0004); what TEOS-10 carries and cannot; `Irreducible` inside the Reference-Composition tolerance, refused beyond (rows 1, 12, 26), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: new Carbonate chemistry and gas exchange paragraph: `Sourced` equilibria with declared domains, total boron, sulfate and fluoride from composition, solubility at local surface pressure, transfer velocity in friction velocity and Schmidt number with the wind-speed law named as an Earth fit (rows 2, 3), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: new Initial state paragraph: spin-up initial fields `Derived` by a named rule, never an observed profile (row 5), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: Tides: the dissipation field `Derived` from the tidal solution and terrain roughness, never read from a dataset (row 13), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: Salinity: the evaporite sink reads the pedology's brine chemistry under the composition fence; its bracket is the kinetics (row 18), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: Sea ice: liquidus slope through the one freezing-point function, brine conductivity `Sourced` with provenance, per-band penetrating shortwave, lead-closing thickness and floe size `Bracketed` with the claim of derivation withdrawn and the gap's disposition stated, dynamics stated in stress with the turning angle and basal exchange pointed at REQ-OCN-011 (rows 7, 8, 9, 16, 17), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: Marine ecosystem: iron speciation as a function of the modelled oxygen and pH state so that iron limitation is an outcome (row 10), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: Exchanges: reads stress, friction velocity, surface pressure, gas mole fractions and the solute composition; writes seawater vapour pressure; the exchanged mixed-layer depth has one definition (rows 11, 27), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: Consequences and references extended accordingly, from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: the seawater-properties door stated with a pure-water limb (IAPWS-95, `Sourced`, read at zero salinity by every fresh-water consumer) and a saline limb `Irreducible` inside the Reference-Composition tolerance, the salinity reduction applied on REQ-ATM-017's pure saturation curve, the brine rule for lakes beyond the tolerance; brine-conductivity and lateral-melt coefficients `Bracketed` between first-year and multiyear ice; Visbeck, Maykut and Perovich, and McPhee identifiers filled, from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-13: Straits and connectivity: restated over the ocean bodies of
  adjacent coarse cells and one gate per body pair joined across a coarse
  edge, rather than one gate per pair of adjacent ocean cells, per decision
  0031's amendment of 2026-09-13 (row fiddlybits-52v.2.19)
