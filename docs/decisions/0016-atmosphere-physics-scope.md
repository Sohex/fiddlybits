+++
id = "0016"
title = "Atmosphere physics scope, with radiation generated per composition and spectrum"
status = "accepted"
date = 2026-09-08
+++

## Decision

The atmosphere is a finite-volume primitive-equation core on the mesh (0013) with
column physics attached column-wise. Its scope is chosen so that every scheme depends
on the declared system (gravity, rotation, composition, atmospheric mass and
spectrum) through its own physics, and no scheme carries a rate calibrated on
another planet's clock or grid.

**Dynamical core.** Per 0013: finite-volume, triangle C-grid, hydrostatic limit
implemented first on the general non-hydrostatic deep-atmosphere formulation (F5 in
the plan). Vertical ladder per 0005: levels placed by scale height and by the
boundary-layer depth, with a declared number of levels inside a declared fraction
of the scale height, where the scale height is computed from the declared
composition (REQ-ATM-017) and a Bracketed first-guess temperature from the declared
instellation (mechanisms: radiative equilibrium with no greenhouse forcing at the
low end, radiative equilibrium at a Bracketed greenhouse forcing at the high end)
and a Bracketed Bond albedo (mechanisms: a bare-rock surface at the low end, full
cloud cover at the high end), and the boundary-layer depth scale is the smaller of
a Bracketed multiple of u*/|f| (mechanisms: the laboratory neutral Ekman depth at
the low end, observed convective deepening at the high end) and a declared fraction
of the scale height, with the slow-rotator limit named, so inversions and low-level jets have an
interior; the model top is where the sponge lives, set in pressure fraction of the
surface pressure, never a fixed value. Sponge timescale `Derived` from the resolved
gravity-wave spectrum. Numerical dissipation is the scheme's own plus a fourth-order
filter whose coefficient is a `Closure` in the spacing and the eddy velocity.
Tracers (dust bins, sea salt bins, the condensable's species, ozone) by
flux-corrected transport. The core's thermodynamic variables are defined once
through the gas-mixture group (0013, REQ-ATM-017).

**Thermodynamics and the gas mixture.** The condensable species is a declared field
of the system: water by declaration, with its latent heats, saturation vapour
pressure and surface tension `Sourced` as functions of temperature, and any other
condensable a priced declared absence (REQ-ATM-013). The molar mass, specific gas
constant, heat capacities, `kappa`, `gamma`, `epsilon`, viscosity, thermal
conductivity, binary diffusivities and mean free path of the declared mixture are
one `Derived` group owned by the atmosphere (REQ-ATM-017). Every scheme below reads
them there; no scheme carries its own value of any of them, and the dimensionless
ones (`kappa`, `gamma`, `epsilon`) are lint-banned as literals because a lint on
dimensional literals cannot see them.

**Radiation: a k-distribution generated once per declared composition and per
spectrum.**

1. Offline build step on the GPU: line-by-line absorption for every declared absorber
   from HITRAN line parameters (`Sourced`, molecular) on a pressure-temperature grid
   `Derived` from the profile's state brackets, Voigt profiles, plus the water-vapour
   continuum (`Sourced`, laboratory). The line list is chosen per absorber against
   the profile's temperature bracket, HITRAN where the bracket lies inside its
   completeness and HITEMP or ExoMol where it does not (Rothman et al. 2010; Tennyson
   et al. 2016), and carries its validity range. The broadening partner is the
   declared bulk gas. HITRAN's default half-widths and temperature exponents are
   air-broadened and can carry only a nitrogen-oxygen bulk; per-perturber widths are
   `Sourced` where the database carries them (Wilzewski et al. 2016; Tan et al.
   2022), and where it does not the air-broadened width is `Bracketed` with the
   published perturber ratio as the bracket and the affected bands listed in the
   table's provenance; self-broadening is computed from the absorber's partial
   pressure. The continuum is `Sourced` per (absorber, perturber) pair with its
   fitted temperature and pressure range recorded: MT_CKD carries the water
   self-continuum and the water-air foreign continuum over the range of the
   atmosphere it was built for and nothing else; the water-CO2 continuum is a
   separate `Sourced` item (Tran et al. 2018); a declared pair with no measured
   continuum is a declared absence priced per REQ-ATM-013. The far-wing
   sub-Lorentzian line shape of a CO2-dominated bulk is a separate `Sourced` item
   (Perrin and Hartmann 1989). Collision-induced absorption per declared pair of bulk
   gases, `Sourced` from the HITRAN collision-induced section (Karman et al. 2019); a
   declared pair with no measurement is a declared absence.
2. Band edges from the flux quantiles of *whatever spectrum is declared* intersected
   with the absorber band structure; longwave bands on the Planck-weighted absorption
   structure at the system's temperature range. Multiple stellar sources are handled by
   building the shortwave tables against each source's spectrum; the instellation
   function (0008) supplies each source's geometry.
3. Within-band k-distribution with a declared number of g-points, weighted by the
   source spectrum in the shortwave and by Planck in the longwave; gas overlap by
   equivalent extinction. The number of g-points per band is a profile setting (0014).
4. Rayleigh cross-sections `Derived` per gas from refractive-index dispersion, with
   the validity range of each dispersion formula checked rather than extrapolated.
5. Two-stream solvers (delta-Eddington shortwave, hemispheric-mean longwave) per
   g-point, called at a profile-declared interval.
6. **Clouds take an effective radius as input.** Liquid optics regenerated per band
   from Mie theory on the condensable's optical constants (`Sourced`, with their
   measurement temperature); ice optics from ice optical constants over an
   effective-size axis with the habit mixture `Bracketed`, its provenance and fitted
   range in the registry (REQ-ATM-004); `r_e` from droplet number and condensate
   with a dispersion parameter (`Bracketed`). This retires any Earth-stratiform fit
   in which the effective radius is implicit.
7. Aerosol activation from the dust and sea-salt tracers by Koehler theory
   (`Sourced`), using the updraught the TKE closure supplies, with the growth
   coefficient's vapour diffusivity and thermal conductivity read from the
   gas-mixture group (REQ-ATM-017).
8. Ozone: a Chapman column, present only when molecular oxygen is in the declared
   composition, with photolysis cross-sections `Sourced` and integrated against the
   declared ultraviolet spectrum per band (REQ-ATM-002), diagnostic on the radiation
   step. The catalytic loss is a `Bracketed` coefficient (mechanisms: no catalyst at
   the low end, the trace-gas inventory of the atmosphere it was fitted on at the
   high end), or a rate per declared catalyst species where the composition
   carries them. Declared as the minimum
   photochemistry.
9. Surface albedo per band: every surface class carries a reflectance spectrum
   integrated against the declared spectrum per band at build time, or at run time
   where the state changes (snow grain size and impurities, 0018).

**Convection.** Mass-flux plume with entrainment and detrainment and a CAPE-relaxation
closure; buoyancy written as `g theta_v' / theta_v`, with `theta_v` the core's own
definition through the `epsilon` of REQ-ATM-017; closure timescale in seconds.
Entrainment rate and closure time are the two `Bracketed` Earth-fitted numbers of the
subsystem, and the record says so. Convective cloud fraction is the detrained
condensate, never a function of a precipitation rate.

**Large-scale cloud and microphysics.** Prognostic cloud liquid and ice; a statistical
scheme whose sub-grid total-water distribution width is a `Closure` supplied by the
TKE closure, replacing any grid-box-tuned critical humidity. Single-moment
microphysics with droplet number from activation; autoconversion `Bracketed` (it is a
large-eddy fit whose coefficient is dimensional and absorbs the air and condensate
densities, so the rate is evaluated in per-volume condensate and droplet number with
those densities explicit); fall speeds `Derived` from a drag law in `g`, air density
and the mixture's viscosity and mean free path (REQ-ATM-017).

**Boundary layer.** 1.5-order TKE closure with closure constants `Sourced` from
turbulence measurements; Monin-Obukhov surface layer with `Sourced` similarity
functions, the Obukhov length carrying `g`. Roughness over open water is defined
here, once: Charnock's form `z0 = alpha u*^2 / g` with `g` explicit and `alpha`
`Bracketed` (mechanisms: smooth-flow roughness at the low end, wave-age and spray
roughness at the high end; Charnock 1955), joined to the smooth-flow term in the
mixture's viscosity; every consumer (the ocean surface fluxes of REQ-OCN-004, the
lake tile of REQ-ATM-012 and REQ-HYD-007) reads this definition and restates no
form and no bracket end. Roughness over sea ice is `Sourced` per ice class; the
scalar roughness for heat and vapour follows a named relation in the roughness
Reynolds number and the mixture's Prandtl and Schmidt numbers (Brutsaert 1975),
every gas property read from REQ-ATM-017. The whitecap fraction of the open-water
surface is defined here, once, as a function of the friction velocity and gravity,
`Bracketed` between the published ten-metre-wind power law re-expressed in
friction velocity at Earth air density (the low-information end) and a
breaking-threshold form in a Froude number (the physics end); the sea-salt source
(REQ-ATM-006, 0022) and the open-water albedo (REQ-OCN-012) read it here.
Prognostic TKE is what activation, the cloud PDF and the nocturnal jet need.

**Orographic drag.** From the sub-grid orography variance the hierarchy provides
exactly; efficiency `Bracketed`.

**Excluded, with reasons.** Aerosol-cloud microphysics beyond activation (0002 scope
fence). Chemistry beyond Chapman ozone (declared absence; the interface is the tracer
set and a reaction table). Storm-scale diagnostics that need a resolution the
profiles do not reach (an absence is reported as such, never as zero storms).

**Exchanges (atmosphere owns temperature, humidity, winds, clouds, precipitation,
radiative fluxes, tracer burdens and deposition fluxes, surface fluxes over ocean and
sea ice).** Reads: surface state per tile (land column 0018), sea-surface state and
ice (ocean 0017), spectra and geometry of every source and the stellar cycle (0008),
pCO2 (carbon 0022), dust emission (land column). Writes: precipitation, radiative and
turbulent forcing to tiles; wind stress, heat and freshwater fluxes to the ocean;
deposition to land, snow and ocean.

## Alternatives considered

- *Spectral dynamical core.* Rejected in 0013: it needs latitude rings and so
  reinstates the grid crossing the whole design exists to delete.
- *Broadband few-band radiation with per-star correction weights* (the predecessor's
  scheme). Rejected: its per-band attribution, its missing continuum and its
  out-of-band absorption were recorded holes that re-weighting cannot close, and every
  new spectrum needed a new set of corrections. Generating the tables per spectrum
  removes the correction layer entirely.
- *Correlated-k evaluated per timestep from line data.* Rejected on structure, not
  price: the expensive part (line-by-line) depends only on composition and spectrum,
  so it belongs in a build step, and the per-timestep cost is then the same as any
  k-distribution scheme.
- *A fixed critical relative humidity for cloud fraction.* Rejected: it is a grid-box
  tuning by construction; the TKE-derived distribution width is the physical form.

## Consequences

- The three recorded holes of the predecessor's radiation scheme (per-band
  attribution, out-of-band absorption, no continuum) close by construction.
- A new composition or a new spectrum is a build step, not a source edit.
- The `Bracketed` and `Irreducible` constants of the atmosphere are listed in the
  oracle registry and reviewed at every milestone (decision 0007); the convective
  pair is on that list, beside the autoconversion, dispersion, habit, catalytic-loss,
  orographic-efficiency, roughness and source-function brackets named above, and
  this record does not claim to be that list. Convection-permitting refinement under
  the non-hydrostatic solver is the declared route to removing the convective pair
  (0013).
- Radiation validation is against generated line-by-line references for every
  declared spectrum (0025), because no long record of these tables in a circulation
  model exists.

## References

- Wan, H. et al., "The ICON-1.2 hydrostatic atmospheric dynamical core on triangular grids - Part 1: Formulation and performance of the baseline version", Geoscientific Model Development 6 (2013). DOI: 10.5194/gmd-6-735-2013
- Zaengl, G., Reinert, D., Ripodas, P. and Baldauf, M., "The ICON (ICOsahedral Non-hydrostatic) modelling framework of DWD and MPI-M: Description of the non-hydrostatic dynamical core", Quarterly Journal of the Royal Meteorological Society 141 (2015). DOI: 10.1002/qj.2378
- Edwards, J. M. and Slingo, A., "Studies with a flexible new radiation code. I: Choosing a configuration for a large-scale model", Quarterly Journal of the Royal Meteorological Society 122 (1996). DOI: 10.1002/qj.49712253107
- Lacis, A. A. and Oinas, V., "A description of the correlated k distribution method for modeling nongray gaseous absorption, thermal emission, and multiple scattering in vertically inhomogeneous atmospheres", Journal of Geophysical Research 96 (1991). DOI: 10.1029/90JD01945
- Toon, O. B., McKay, C. P., Ackerman, T. P. and Santhanam, K., "Rapid calculation of radiative heating rates and photodissociation rates in inhomogeneous multiple scattering atmospheres", Journal of Geophysical Research 94 (1989). DOI: 10.1029/JD094iD13p16287
- Gordon, I. E. et al., "The HITRAN2020 molecular spectroscopic database", Journal of Quantitative Spectroscopy and Radiative Transfer 277 (2022). DOI: 10.1016/j.jqsrt.2021.107949
- Mlawer, E. J. et al., "Development and recent evaluation of the MT_CKD model of continuum absorption", Philosophical Transactions of the Royal Society A 370 (2012). DOI: 10.1098/rsta.2011.0295
- Hu, Y. X. and Stamnes, K., "An Accurate Parameterization of the Radiative Properties of Water Clouds Suitable for Use in Climate Models", Journal of Climate 6 (1993). DOI: 10.1175/1520-0442(1993)006<0728:AAPOTR>2.0.CO;2
- Fu, Q., "An Accurate Parameterization of the Solar Radiative Properties of Cirrus Clouds for Climate Models", Journal of Climate 9 (1996). DOI: 10.1175/1520-0442(1996)009<2058:AAPOTS>2.0.CO;2
- Martin, G. M., Johnson, D. W. and Spice, A., "The Measurement and Parameterization of Effective Radius of Droplets in Warm Stratocumulus Clouds", Journal of the Atmospheric Sciences 51 (1994). DOI: 10.1175/1520-0469(1994)051<1823:TMAPOE>2.0.CO;2
- Abdul-Razzak, H. and Ghan, S. J., "A parameterization of aerosol activation: 2. Multiple aerosol types", Journal of Geophysical Research 105 (2000). DOI: 10.1029/1999JD901161
- Tiedtke, M., "A Comprehensive Mass Flux Scheme for Cumulus Parameterization in Large-Scale Models", Monthly Weather Review 117 (1989). DOI: 10.1175/1520-0493(1989)117<1779:ACMFSF>2.0.CO;2
- Khairoutdinov, M. and Kogan, Y., "A New Cloud Physics Parameterization in a Large-Eddy Simulation Model of Marine Stratocumulus", Monthly Weather Review 128 (2000). DOI: 10.1175/1520-0493(2000)128<0229:ANCPPI>2.0.CO;2
- Mellor, G. L. and Yamada, T., "Development of a turbulence closure model for geophysical fluid problems", Reviews of Geophysics 20 (1982). DOI: 10.1029/RG020i004p00851
- Bougeault, P. and Lacarrere, P., "Parameterization of Orography-Induced Turbulence in a Mesobeta-Scale Model", Monthly Weather Review 117 (1989). DOI: 10.1175/1520-0493(1989)117<1872:POOITI>2.0.CO;2
- Businger, J. A., Wyngaard, J. C., Izumi, Y. and Bradley, E. F., "Flux-Profile Relationships in the Atmospheric Surface Layer", Journal of the Atmospheric Sciences 28 (1971). DOI: 10.1175/1520-0469(1971)028<0181:FPRITA>2.0.CO;2
- Lott, F. and Miller, M. J., "A new subgrid-scale orographic drag parametrization: Its formulation and testing", Quarterly Journal of the Royal Meteorological Society 123 (1997). DOI: 10.1002/qj.49712353704
- Zalesak, S. T., "Fully multidimensional flux-corrected transport algorithms for fluids", Journal of Computational Physics 31 (1979). DOI: 10.1016/0021-9991(79)90051-2
- Chapman, S., "A theory of upper-atmospheric ozone", Memoirs of the Royal Meteorological Society 3 (1930). Locator: Mem. R. Meteorol. Soc. 3, 103-125
- Rothman, L. S. et al., "HITEMP, the high-temperature molecular spectroscopic database", Journal of Quantitative Spectroscopy and Radiative Transfer 111 (2010). DOI: 10.1016/j.jqsrt.2010.05.001
- Tennyson, J. et al., "The ExoMol database: Molecular line lists for exoplanet and other hot atmospheres", Journal of Molecular Spectroscopy 327 (2016). DOI: 10.1016/j.jms.2016.05.002
- Wilzewski, J. S., Gordon, I. E., Kochanov, R. V., Hill, C. and Rothman, L. S., "H2, He, and CO2 line-broadening coefficients, pressure shifts and temperature-dependence exponents for the HITRAN database. Part 1: SO2, NH3, HF, HCl, OCS and C2H2", Journal of Quantitative Spectroscopy and Radiative Transfer 168 (2016). DOI: 10.1016/j.jqsrt.2015.09.003
- Tan, Y. et al., "H2, He, and CO2 Pressure-induced Parameters for the HITRAN Database. II. Line Lists of CO2, N2O, CO, SO2, OH, OCS, H2CO, HCN, PH3, H2S, and GeH4", The Astrophysical Journal Supplement Series 262, 40 (2022). DOI: 10.3847/1538-4365/ac83a6
- Tran, H., Turbet, M., Chelin, P. and Landsheere, X., "Measurements and modeling of absorption by CO2 + H2O mixtures in the spectral region beyond the CO2 nu3-band head", Icarus 306 (2018). DOI: 10.1016/j.icarus.2018.02.009
- Perrin, M. Y. and Hartmann, J. M., "Temperature-dependent measurements and modeling of absorption by CO2-N2 mixtures in the far line-wings of the 4.3 um CO2 band", Journal of Quantitative Spectroscopy and Radiative Transfer 42 (1989). DOI: 10.1016/0022-4073(89)90077-0
- Karman, T. et al., "Update of the HITRAN collision-induced absorption section", Icarus 328 (2019). DOI: 10.1016/j.icarus.2019.02.034
- Charnock, H., "Wind stress on a water surface", Quarterly Journal of the Royal Meteorological Society 81 (1955). DOI: 10.1002/qj.49708135027
- Brutsaert, W., "A theory for local evaporation (or heat transfer) from rough and smooth surfaces at ground level", Water Resources Research 11 (1975). DOI: 10.1029/WR011i004p00543
- Bohren, C. F. and Huffman, D. R., "Absorption and Scattering of Light by Small Particles", Wiley (1983). ISBN 978-0-471-29340-8 (Mie theory)

## Amendments

- 2026-09-08: added atmospheric mass to the list of declared inputs every scheme depends on (audit row 1), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: replaced the lowest-kilometre ladder rule with the scale-height and u*/|f| wording shared with decision 0005 (audit row 11), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: added the thermodynamics and gas-mixture paragraph declaring the condensable and pointing every gas property to REQ-ATM-017, with the dimensionless-literal lint (audit rows 1, 8, 9), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: stated what HITRAN air-broadened widths and the MT_CKD air continuum can and cannot carry, with per-perturber widths Sourced, the gap Bracketed, continuum per pair with range, far-wing shape and collision-induced absorption per pair, and the line list chosen against the temperature bracket (audit rows 2, 3, 13, 14), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: made the pressure-temperature grid of the k-tables Derived from the profile's state brackets (audit row 4), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: dispositioned the ice-habit mixture as Bracketed and named the liquid optical constants' measurement temperature (audit rows 15, 26), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: routed the activation growth coefficient through REQ-ATM-017 (audit row 19), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: made ozone conditional on declared molecular oxygen with a Bracketed catalytic loss of stated provenance (audit row 12), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: tied theta_v in the convective buoyancy to the core's one definition (audit row 1), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: stated that the autoconversion coefficient absorbs densities and that fall speeds read viscosity and mean free path from REQ-ATM-017 (audit rows 9, 16), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: added roughness over water and sea ice and scalar roughness with their dispositions (audit row 10), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: replaced the claim that convection is the one place the atmosphere carries Earth-fitted numbers with a pointer to the registry's list (audit pattern 5), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: day length removed from the declared-input list; both ends named for the first-guess temperature, the Bond albedo, the u*/|f| multiple and the catalytic loss; the open-water roughness and the whitecap fraction each defined here once with both bracket ends, every consumer citing this record, from notes/findings/2026-09-08-implicit-earth-audit.md
