+++
id = "REQ-OCN-011"
title = "Sea-ice motion is a declared class on a ladder of schemes with its forcing inputs named; the ice state has one authority, no velocity clamp or Coriolis floor, and a freezing point from local salinity and pressure"
old_path = ["/home/cfutro/docs/world/notes/external-model-survey.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

`notes/external-model-survey.md` section 19 read an intermediate-complexity
"dynamic" sea ice at source: area and thickness advected by the upper-ocean
velocity plus a diffusion term; no momentum equation, no internal stress, no
wind stress on the floe; a separate ice-velocity field commented out at every
use site. Section 43 priced a full elastic-viscous-plastic scheme (Hunke and
Dukowicz 1997, SIS2-derived): five new prognostic two-dimensional fields in
the restart (two velocities and three stress-tensor components), ice
concentration promoted to prognostic and separately advected, five forcing
fields in (ocean velocity, wind stress, sea-surface height) and two stresses
returned to the ocean, a 50-substep subcycle per ice step, and numerical
guards it cannot run without: a hard velocity clamp at 0.1 dx/dt "for CFL
stability near the Poles", a minimum shear rate capping the viscosity, and
stress limiting before every step; two ice densities disagreeing between the
dynamics (905) and the thermodynamics (910). Section 43b: the statement "a
slab has no velocity to advect with" is true for advection-by-current and
false for a momentum solve, in which wind stress, internal stress and Coriolis
all remain with the ocean at rest, so free drift is the coherent reduced
case. `ocean-and-marine-biosphere.md` section 7b: the ice state must have one
authority, and ice fraction is a threshold field at a moving margin, so a
stale margin puts the wrong albedo where the ice-albedo feedback lives.
`ocean-tier-implicit-earth.md` recorded a freezing point computed from local
salinity as the correct form against a single declared number in the tier that
ran, and that the density, specific heat and conductivity of sea ice are
functions of brine volume, hence of ice salinity and temperature, which a
model carrying one thickness per cell cannot derive, so they were declared
rather than sourced.

## Why it carries

On any planet with sea ice the dynamics class fixes what forcing the ice needs
and what it returns, and the classes form a ladder: thermodynamic only;
advection by the ocean current; free drift under wind stress and ocean drag
with a thickness-dependent strength cap; full rheology. B3 selects free drift
with a thickness-dependent stress cap, and the interface principle of Part F
requires the fields of the higher rungs to exist. The lessons on one
authority, the moving margin, the salinity-dependent freezing point and the
brine-dependent properties are properties of sea ice, not of the old stack;
the velocity clamp and Coriolis floor are the fail-open class of REQ-OCN-002
in ice form.

## What this system must do

- The sea-ice component (B3) declares its dynamics class from the ladder. The
  forcing inputs (ocean surface velocity, wind stress, sea-surface tilt, the
  Coriolis parameter), the returned ice-ocean stress and the prognostic fields
  of every rung are declared in the `Exchange`, including the rungs that are
  declared absences.
- Free drift: ice velocity from the balance of the stress the atmosphere
  writes, ocean drag against the ice-ocean relative velocity, Coriolis, and an
  internal-stress cap that is a function of thickness and concentration with
  its coefficients `Bracketed` (mechanisms: thin, unconsolidated ice at the low
  end, thick ridged ice at the high end; the classical values are Arctic fits
  and are the `EarthRatios` comparison). The air-ice and ice-ocean drag
  coefficients are dimensionless and `Bracketed` (mechanisms: smooth level ice
  at the low end, keel and sail form drag at the high end), applied to the
  stress and the relative velocity, never to a wind speed at a reference
  height; air density comes from REQ-ATM-017. The ice-ocean turning angle is
  not a constant: it emerges when the ocean's surface layer resolves the Ekman
  spiral, and otherwise is `Derived` from the Ekman solution at the local
  Coriolis parameter and the mixed-layer viscosity, with a diagnostic of the
  cells where the derived form is used. No velocity clamp, no Coriolis floor,
  no minimum-shear literal; where a limiter is needed it is a declared closure
  with a diagnostic of the cells where it binds.
- Basal exchange: the heat and salt flux between ice and ocean is a named
  scheme in the ice-ocean friction velocity and the departure of the
  mixed-layer temperature from the freezing point (McPhee 1992), with the
  dimensionless transfer coefficients `Bracketed` (mechanisms: a smooth ice
  base at the low end, a rough or melting base at the high end) and no
  friction-velocity floor; a floor there is the fail-open class of REQ-OCN-002,
  and where a regularisation is needed it is a declared closure with a
  diagnostic of the cells where it binds.
- Lead fraction: the lead-closing thickness of the Hibler (1979) law is
  `Bracketed` (mechanisms: rapid thin-ice growth that closes leads at the low
  end, rafting and ridging of thin ice at the high end) and the floe size of
  the lateral-melt law is `Bracketed` (mechanisms: wave fracture at the low
  end, thermodynamic consolidation at the high end), with the lateral-melt
  coefficients `Bracketed` (mechanisms: thin first-year ice at the low end, thick
  multiyear ice at the high end) about the Maykut and Perovich (1987) fit with its
  Arctic provenance. The two formulations carry the thickness dependence of the
  closing rate and the temperature dependence of the melt rate; neither
  derives its length scale, so the scales are brackets and no record claims a
  derivation.
- Concentration, thickness and snow on ice are prognostic and advected
  conservatively on the mesh with a monotone scheme; the ice-covered fraction
  is a mosaic tile of the ocean cell (A1).
- Thermodynamics: Winton three-layer (B3), with the freezing point from the
  local salinity and pressure (TEOS-10, REQ-OCN-003, under its composition
  fence); the liquidus slope inside the brine-pocket heat capacity and
  conductivity is the derivative of that one function, never a second
  constant; the brine-conductivity coefficient is `Bracketed` (mechanisms: thin
  first-year ice at the low end, thick multiyear ice at the high end) about the
  fit with its Arctic-ice provenance and its composition limit stated; one ice density and
  one set of material properties shared by dynamics and thermodynamics;
  brine-dependent properties `Bracketed` over ice salinity between the first-year
  and the multiyear values until ice salinity is prognostic. The shortwave that penetrates bare ice and is absorbed within
  it is per band, `Derived` from the radiation's band structure with a
  per-band ice absorption coefficient `Sourced`; there is no broadband
  penetrating-fraction literal, because that fraction is the visible share of
  one star's spectrum.
- One authority: the ice component owns fraction, thickness, snow, surface
  temperature, albedo, and the freshwater and salt fluxes of freezing and
  melting; the atmosphere and ocean read; nothing else writes them
  (REQ-OCN-004).

## Enforced by

- B3 decision record; A5 ownership check at `assemble`.
- C3 oracles: the Stefan problem for thermodynamic growth; an analytic
  free-drift solution (the steady balance of surface stress, quadratic ocean
  drag and Coriolis gives drift at a closed-form angle and speed ratio,
  evaluated at the test's Coriolis parameter, densities and drag
  coefficients, never at the observed drift ratio of one ocean; registry
  ocean.free_drift_closed_form); conservation of ice mass and salt across
  advection (registry seaice.mass_salt_conservation).
- M6 gate: the Earth ice extent cycle as a distance report.
- C4 mutation run: a planted Coriolis floor, a planted velocity clamp, a
  planted friction-velocity floor in the basal exchange, and a planted
  broadband penetrating-fraction literal.

## References

- Winton, M. (2000). "A Reformulated Three-Layer Sea Ice Model". Journal of
  Atmospheric and Oceanic Technology 17, 525-531.
  DOI: 10.1175/1520-0426(2000)017<0525:ARTLSI>2.0.CO;2.
- Hibler, W. D. (1979). "A Dynamic Thermodynamic Sea Ice Model". Journal of
  Physical Oceanography 9, 815-846.
  DOI: 10.1175/1520-0485(1979)009<0815:ADTSIM>2.0.CO;2. (The viscous-plastic
  rheology and the free-drift limit.)
- Hunke, E. C. and Dukowicz, J. K. (1997). "An Elastic-Viscous-Plastic Model
  for Sea Ice Dynamics". Journal of Physical Oceanography 27, 1849-1867.
  DOI: 10.1175/1520-0485(1997)027<1849:AEVPMF>2.0.CO;2.
- Bitz, C. M. and Lipscomb, W. H. (1999). "An energy-conserving thermodynamic
  model of sea ice". Journal of Geophysical Research 104(C7), 15669-15677.
  DOI: 10.1029/1999JC900100. (Brine-volume dependence of the material
  properties.)
- IOC, SCOR and IAPSO (2010). "The international thermodynamic equation of
  seawater - 2010: Calculation and use of thermodynamic properties". UNESCO
  Manuals and Guides No. 56. Locator: no DOI. (Freezing temperature as a
  function of salinity and pressure.)
- McPhee, M. G. (1992). "Turbulent heat flux in the upper ocean under sea
  ice". Journal of Geophysical Research 97(C4), 5365-5379. DOI: 10.1029/92JC00239.
  (The basal exchange law in the ice-ocean friction velocity.)
- Maykut, G. A. and Perovich, D. K. (1987). "The role of shortwave radiation
  in the summer decay of a sea ice cover". Journal of Geophysical Research
  92(C7), 7032-7044. DOI: 10.1029/JC092iC07p07032. (The lateral-melt law and its floe-size
  argument.)

## Amendments

- 2026-09-08: free drift stated in the atmosphere's stress and the ice-ocean relative velocity; cap and drag coefficients `Bracketed` with mechanisms and the Arctic fits named as the Earth comparison; the turning angle emergent or `Derived`, never a constant (row 16), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: new bullet: basal heat and salt exchange as a named scheme with `Bracketed` transfer coefficients and no friction-velocity floor (row 17), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: new bullet: lead-closing thickness and floe size `Bracketed`, lateral-melt coefficients `Sourced`; the claim of derivation withdrawn and what each formulation carries and cannot stated (row 9), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: thermodynamics: liquidus slope as the derivative of the one freezing-point function, brine conductivity `Sourced` with provenance, per-band penetrating shortwave with no broadband literal (rows 7, 8), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: free-drift oracle evaluated at the test's parameters with registry ids named; mutation breaks and references added (rows 16, 31), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: lateral-melt and brine-conductivity coefficients `Bracketed` between first-year and multiyear ice, ice salinity's ends named; Maykut and Perovich and McPhee identifiers filled, from notes/findings/2026-09-08-implicit-earth-audit.md
