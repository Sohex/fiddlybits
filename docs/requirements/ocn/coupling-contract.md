+++
id = "REQ-OCN-004"
title = "The atmosphere-ocean-ice coupling contract: one owner per flux, temperature-dependent terms against the live ocean, evaporation with one owner, sea ice with one authority"
old_path = ["/home/cfutro/git/vesper/ocean/config/transport_loop.yaml"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's machine-readable coupling declaration (`transport_loop.yaml`,
with its argument in `notes/audits/ocean-and-marine-biosphere.md` sections 7,
7b, 8a and 11, and `notes/external-model-survey.md` section 59f) stated a
hand-over rule taken from a working synchronous coupling (Holden et al. 2016):
the terms that depend on ocean temperature (saturation specific humidity and
hence latent heat, net longwave, sensible heat) are recomputed live against
the ocean's surface temperature; only the transfer coefficients and the
downward radiative and moisture fields are replayed; evaporation is
deliberately not recomputed, for moisture conservation, with rescaling
precipitation and runoff considered and rejected. Its stated reason: naive
replay of net heat flux severs the negative feedback that holds sea surface
temperature.

The same declaration named: no temperature restoring; no salinity restoring,
and any later weak restoring "a named numerical control with its tendency
reported separately" that never replaces precipitation, evaporation, runoff,
ice freshwater, brine or salt conservation; zero freshwater hosing; a wind
stress multiplier the host declares as tuned held as a `declared_bracket`
(1 to 3) with every result carrying the bracket; a dropped surface residual
(`delta_flux`) as diagnostic, not correction. Section 8a: wind stress, net and
penetrative shortwave, longwave, sensible and latent heat, precipitation minus
evaporation, river discharge, salt and ice freshwater each need one owner,
time basis, support and sign convention. Section 7b: sea ice must have one
authority, and the ocean returns a transport agent (surface velocity) rather
than an ice state, because ice fraction is a threshold field at a moving
margin and a stale margin puts the wrong albedo at exactly the latitudes where
the ice-albedo feedback lives. Section 11e: a heat-flux convergence
constructed to integrate to zero over the globe integrated to -0.919 W m-2
over the ocean on one land mask, so the zero-integral condition holds on the
support the flux is applied to. Section 11d: a sea-water heat capacity copied
as 4180 J kg-1 K-1 where the owning module declared 3990.34 rescaled a
convergence verdict silently; the fix was to read the constant from the
component that owns it. Section 11: the channel was verified with a field
whose answer was known in advance before any real field crossed it.

## Why it carries

Any synchronous coupling of a resolved atmosphere to a resolved ocean crosses
the same fluxes and faces the same feedback. The surface energy balance is
nonlinear in the surface temperature, so the terms that carry the SST feedback
must be evaluated at the current ocean and ice state on every exchange, while
the moisture and salt budgets require evaporation to be one number consumed
identically by both sides. Two owners of sea ice, or of evaporation, is a
ledger that cannot close. These are properties of the coupled system and not
of the offline architecture that recorded them; the record carries the rule
and not the architecture.

## What this system must do

- The A5 `Exchange` at the atmosphere-ocean-ice boundary declares, for every
  quantity, one writer, its semantics (flux density or intensive state), its
  interval, its support and its sign convention; the store refuses an
  undeclared field and `assemble` refuses two writers.
- Surface fluxes that depend on the surface temperature (latent, sensible,
  net longwave, and the freezing and melting terms, the last two through the
  basal exchange of REQ-OCN-011) are computed at every coupling step against
  the live ocean and ice surface state, on the atmosphere's column and its
  tiles, and never replayed from an earlier state. Downward shortwave and
  longwave, precipitation, the transfer coefficients, the stress and the
  friction velocity are the atmosphere's outputs.
- The saturation specific humidity over water is evaluated at the seawater
  vapour pressure for the local surface salinity, read through the
  seawater-properties door of B3 (TEOS-10 inside the composition fence of
  REQ-OCN-003); the fixed salinity reduction factor of the classical bulk
  formulae is a literal for one ocean and does not exist here.
- The transfer coefficients of the bulk formulae are functions of the friction
  velocity and of the open-water roughness decision 0016 defines once (Charnock's
  form in gravity with its coefficient `Bracketed` there); this record restates no
  bracket end; the classical
  polynomials in wind speed at a reference height (Large and Yeager 2009) were
  fitted at Earth air density and gravity and are the `EarthRatios`
  comparison. Air density, viscosity, diffusivities and the vapour ratio come
  from REQ-ATM-017 and are not defined here.
- Evaporation has exactly one owner and enters the energy, water and salt
  ledgers as the same number; it is never recomputed on the ocean side.
- Sea ice has one authority (the sea-ice component of B3). The atmosphere
  reads its fraction, thickness, surface temperature and albedo; the ocean
  supplies surface velocity, mixed-layer temperature and the local freezing
  point; brine rejection and meltwater freshwater and salt fluxes are
  ice-owned.
- No restoring of surface temperature or salinity in a production run. Any
  numerical restoring in a diagnostic run is a declared control whose
  tendency is a separate ledger term.
- Every flux multiplier or scaling factor is a `Bracketed` control that is
  swept; none is a fixed coupling factor.
- Ledgers for energy, water and salt close at every exchange (C3), including
  the flux the coupling could not place, which is reported and never added
  back as a correction.
- An integral condition on a coupling field states the support it holds on.
- Physical constants of sea water and ice (density, specific heat, latent
  heats) are read from the component that owns them, as functions of state
  from the equation of state and the ice material properties, never as
  scalars; no consumer carries a copy.

## Enforced by

- A5 decision record: `WorldState` with one declared writer per quantity,
  checked at `assemble`; `Exchange` ledgers at every boundary.
- B3 decision record: synchronous coupling; sea ice as one authority; Winton
  thermodynamics with the freezing point from local salinity.
- C3: ledgers at every exchange with float-derived tolerance; the residual's
  time signature classified as leak, stock omission or roundoff.
- Identity test at M6: a prescribed analytic surface flux field crosses the
  exchange and is delivered to the ocean column at the declared heat capacity
  and interval; the field is asymmetric in both coordinates so a flip, roll,
  transpose or sign error names itself.
- C4 mutation run with "replay net heat flux against a stale SST",
  "recompute evaporation on the ocean side" and "a planted fixed salinity
  reduction factor in the surface humidity" as named breaks.

## References

- Holden, P. B., Edwards, N. R., Fraedrich, K., Kirk, E., Lunkeit, F. and
  Zhu, X. (2016). "PLASIM-GENIE v1.0: a new intermediate complexity AOGCM".
  Geoscientific Model Development 9, 3347-3361.
  DOI: 10.5194/gmd-9-3347-2016. (The working hand-over rule the contract was
  taken from.)
- Large, W. G. and Yeager, S. G. (2009). "The global climatology of an
  interannually varying air-sea flux data set". Climate Dynamics 33, 341-364.
  DOI: 10.1007/s00382-008-0441-3. (Bulk flux formulae and the SST dependence of
  the turbulent fluxes.)
- Griffies, S. M. et al. (2016). "OMIP contribution to CMIP6: experimental and
  diagnostic protocol for the physical component of the Ocean Model
  Intercomparison Project". Geoscientific Model Development 9, 3231-3296.
  DOI: 10.5194/gmd-9-3231-2016. (Flux sign conventions and the freshwater and
  salt budget diagnostics a closed ledger reports.)
- Winton, M. (2000). "A Reformulated Three-Layer Sea Ice Model". Journal of
  Atmospheric and Oceanic Technology 17, 525-531.
  DOI: 10.1175/1520-0426(2000)017<0525:ARTLSI>2.0.CO;2.
- Charnock, H. (1955). "Wind stress on a water surface". Quarterly Journal of
  the Royal Meteorological Society 81, 639-640. DOI: 10.1002/qj.49708135027.
  (The roughness length in gravity that replaces the wind-speed polynomial.)

## Amendments

- 2026-09-08: surface humidity over water at the seawater vapour pressure for the local salinity through the seawater-properties door; the fixed salinity reduction factor removed (row 11), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: bulk transfer coefficients in friction velocity with a Charnock roughness in gravity, dimensionless coefficients `Bracketed`, the Large and Yeager wind-speed polynomials named as an Earth fit; air properties cited from REQ-ATM-017 (row 11), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: freezing and melting terms pointed at the basal exchange of REQ-OCN-011; owned constants read as functions of state, not scalars (rows 17, 26), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: mutation run: a planted salinity reduction factor; reference Charnock 1955, from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: the roughness length read from decision 0016's one definition, the restated bracket ends dropped, from notes/findings/2026-09-08-implicit-earth-audit.md
