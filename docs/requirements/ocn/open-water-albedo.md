+++
id = "REQ-OCN-012"
title = "Open-water albedo is a zenith-dependent Fresnel term plus a water-leaving term owned by the marine ecosystem, computed per band under the declared spectrum; no capped literal and no switch between fits"
old_path = ["/home/cfutro/git/vesper/notes/external-model-survey.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

`notes/external-model-survey.md` section 29: the predecessor's atmosphere
overwrote its declared ocean albedo scalar with one of two zenith-angle
parameterisations selected by a switch, ECHAM-3's `min(0.05/(mu0+0.15), 0.15)`
by default and a Briegleb polynomial otherwise, both written identically into
both spectral bands under a comment saying so. Flux-weighted over the daylight
period the two agree within ten per cent at high sun and diverge to 1.64x at
45 degrees at solstice under a 32 degree obliquity and to 1.82x at 60 degrees
in winter, because the ECHAM-3 cap binds above 79.5 degrees zenith and the
polynomial has no ceiling; the divergence region is larger at higher obliquity
and is where sea ice forms. `ocean-and-marine-biosphere.md` sections 5a and
13: the water-leaving (pigment and particle) part of the reflectance belongs
to the ecosystem and the Fresnel part does not see it; reweighting water's
nearly flat albedo for a K star was worth about 0.002; a two-band ocean
albedo installed in the surface module was discarded by the radiation module
unless it landed inside the radiation's own expression; a band normalisation
defect in the radiation applied to the ocean as to the ice.

## Why it carries

Ocean surface albedo is set by physics that is the same on any planet:
Fresnel reflection of the direct beam at the solar zenith angle over a
wind-roughened surface, diffuse-sky reflection, whitecaps, and the
water-leaving radiance set by pure-water absorption and the pigments and
particles in the mixed layer, all per wavelength. B2 computes N-band surface
albedo from reflectance spectra per surface class; the ocean class must not
be a constant, a capped fit or a switch between fits, and the low-sun regime
where the fits diverge is exactly the axis a generic builder sweeps (obliquity,
stellar type, day length).

## What this system must do

- Open-water albedo per B2 band, at every radiation call, inside the
  radiation's own surface treatment: Fresnel reflectance of the direct beam at
  the local zenith angle integrated over a wave-slope distribution whose
  variance is a function of the surface stress (or friction velocity) the
  atmosphere writes and of the declared gravity, with its dimensionless
  coefficients `Bracketed` (mechanisms: gravity-wave slopes at the low end,
  capillary-wave slopes at the high end), plus diffuse-sky reflectance, plus a
  whitecap term reading the whitecap fraction decision 0016 defines once (a
  function of the friction velocity and gravity, bracketed there), plus the
  water-leaving reflectance. No cap and no fit
  selected by a switch, and no wind speed at a reference height as the argument
  of any term. The Cox and Munk (1954) slope law and the Monahan and
  O'Muircheartaigh (1980) whitecap law in wind speed were fitted at Earth air
  density and gravity and are the `EarthRatios` comparison; air density comes
  from REQ-ATM-017.
- Water-leaving reflectance per band is a field written by the marine
  ecosystem from its own bio-optical state (pigment absorption, particle
  backscatter, pure-water absorption) and read by B2 (REQ-OCN-007); a
  declared absence writes the pure-water value with its leverage bracketed.
- The bands are anchored so that their flux-weighted combination reproduces
  any sourced broadband datum under the spectrum the datum was measured under,
  and are then re-weighted under the declared spectrum (the convention of
  REQ-CRY-004).
- The refractive index of water (and its temperature and salinity
  dependence) is `Sourced`; it is the only constant in the Fresnel term.

## Enforced by

- B2 decision record (N-band surface albedo from reflectance spectra per
  surface class).
- C3 radiation identities: Fresnel reflectance at normal incidence and at
  Brewster's angle for water's refractive index; the diffuse-sky integral of
  the Fresnel curve; a flat-sea limit of the wave-slope integral.
- C1 tier 2: the Earth ocean albedo climatology as a REPORT distance metric.
- M4b sweeps over obliquity and stellar type.
- Lint: no numeric cap or `min`/`max` literal in a surface albedo expression;
  no wind speed at a reference height as the argument of a surface-optics law.

## References

- Cox, C. and Munk, W. (1954). "Measurement of the Roughness of the Sea
  Surface from Photographs of the Sun's Glitter". Journal of the Optical
  Society of America 44, 838-850. DOI: 10.1364/JOSA.44.000838. (The wave-slope
  distribution, fitted in wind speed at Earth air density and gravity; restated
  here in stress and gravity.)
- Monahan, E. C. and O'Muircheartaigh, I. (1980). "Optimal Power-Law
  Description of Oceanic Whitecap Coverage Dependence on Wind Speed". Journal
  of Physical Oceanography 10, 2094-2099. DOI: to confirm. (The whitecap law
  kept as the Earth comparison.)
- Payne, R. E. (1972). "Albedo of the Sea Surface". Journal of the
  Atmospheric Sciences 29, 959-970. DOI: to confirm. (The observational
  zenith and cloudiness dependence used as an Earth oracle.)
- Jin, Z., Charlock, T. P., Smith, W. L. and Rutledge, K. (2004). "A
  parameterization of ocean surface albedo". Geophysical Research Letters 31,
  L22301. DOI: to confirm. (The decomposition into direct, diffuse, foam and
  water-leaving terms.)
- Pope, R. M. and Fry, E. S. (1997). "Absorption spectrum (380-700 nm) of
  pure water. II. Integrating cavity measurements". Applied Optics 36,
  8710-8723. DOI: 10.1364/AO.36.008710.
- Morel, A. and Maritorena, S. (2001). "Bio-optical properties of oceanic
  waters: A reappraisal". Journal of Geophysical Research 106(C4), 7163-7180.
  DOI: 10.1029/2000JC000319. (The water-leaving term as a function of pigment.)

## Amendments

- 2026-09-08: wave-slope variance and whitecap fraction restated in the surface stress or friction velocity and gravity with `Bracketed` dimensionless coefficients and mechanisms; the Cox-Munk and Monahan wind-speed laws named as fits at Earth air density and gravity; air density cited from REQ-ATM-017; lint extended (row 15), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: the whitecap term reads the one whitecap-fraction definition of decision 0016, from notes/findings/2026-09-08-implicit-earth-audit.md
