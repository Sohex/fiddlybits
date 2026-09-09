+++
id = "REQ-ATM-005"
title = "Aerosol activation closes the aerosol-to-cloud-albedo chain, with hygroscopicity per species, a sub-grid updraught from the turbulence scheme, and the droplet radius handed to both radiation bands"
old_path = ["/home/cfutro/docs/world/notes/audits/aerosol-indirect-effect-cost.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's climate model, in which nothing connected any link
of the chain aerosol, condensation nuclei, droplet number, effective radius,
cloud albedo: the aerosol products were offline and mass-based, the clouds were
diagnostic, and optical depth was a function of water path alone.

- The size of the absent term was computed as a sensitivity through the model's
  own cloud water, optical-depth fits, two-stream tables and cover, weighted by
  where the model put its cloud: a doubling of droplet number was worth 3.6 to
  4.6 W/m2 in the global mean (2.5 to 3.2 K); a quadrupling 7.0 to 9.1 W/m2. The
  bracket was the product of two arms (vertical shape of cover, surface
  underneath) and both were reported ("What the term is worth").
- The criterion was fixed before the size was computed: worth buying if the
  bracket crossed the project's own 1.5 W/m2 reopening threshold anywhere. Every
  corner cleared it by 2.4 to 3.1. The useful inversion: a 25 to 33 per cent
  change in droplet number already reaches the threshold, so the question is
  about the aerosol products and not the parameterisation.
- The chain had four breaks, not one. Hygroscopicity existed nowhere (three
  declared literals from a paper on disk). The activation parameterisation was
  acquired twice over, and the better-retargeted implementation carried gravity,
  densities, surface tension and the fit coefficients as fields of one runtime
  parameter struct, so a new planet was a constructor call; gravity entered at
  first power in one place, degenerate with the updraught. The sub-grid updraught
  was the real cost: the model had no turbulence kinetic energy, no boundary-layer
  depth and no convective mass flux to build one from. The radiation side had no
  slot for a droplet radius in either band and a grey longwave.
- The longwave response was omitted and named as the only term that could move
  the answer toward the threshold; it would have had to remove three quarters of
  the term.

## Why it carries

Decision 0016 includes aerosol activation from dust and sea-salt tracers using
TKE updraughts, with cloud optics regenerated from an effective radius. This
audit is the evidence that the term is first-order in any atmosphere with wind-
driven aerosol, that its size is decidable before a droplet number exists, and
that the price sits in the boundary-layer diagnostic and the radiation interface
rather than in the activation arithmetic. The criterion-first pricing is the
method every declared absence is judged by (REQ-ATM-013).

## What this system must do

1. Activation is computed per cloudy column from the aerosol tracers' number,
   median radius, width and hygroscopicity per species (each `Sourced`), and a
   sub-grid updraught from the 1.5-order TKE scheme (decision 0016), with the
   correction for pre-existing liquid and ice so a cell does not re-activate its
   whole population every step.
2. Droplet and crystal number are state or per-step diagnostics with a declared
   owner (decision 0009); the effective radius derived from them and the
   condensate mass is the one the shortwave and longwave optics read
   (REQ-ATM-004).
3. Gravity, densities, surface tension and every fit coefficient of the
   activation scheme are fields of the component parameter struct with
   dispositions; no module-level constant (decision 0007). The growth
   coefficient's vapour diffusivity and thermal conductivity, and the
   condensable's surface tension and saturation vapour pressure, are read from
   the gas-mixture group (REQ-ATM-017), never from a value for air. The theory's
   own factors are dimensionally explicit in gravity, molar masses, latent heat,
   heat capacity, pressure and temperature and so transfer; the fit functions of
   the size-distribution width were validated over one atmosphere's updraught,
   pressure and temperature range, which is in the registry and is evaluated over
   the profile's brackets by the margin test of REQ-NUM-003 item 4.
4. The sensitivity of global-mean shortwave to a factor of two in droplet number
   is a row in the lever table at M4, computed through the model's own optics.
5. Any activation code adopted from outside carries an import-review record
   stating the assumptions it embeds (decision 0012).
6. Earth oracle: droplet number and effective radius over ocean and land against
   published observational ranges as REPORT rows (decision 0025).

## Enforced by

- Decision 0016; the `Exchange` between the aerosol tracer component and cloud
  microphysics with one owner for droplet number (decision 0009).
- The import-review record for any adopted activation implementation
  (decision 0012).
- The lever table at the M4 gate (decision 0034).

## References

- Abdul-Razzak, H., Ghan, S. J. (2000). *A parameterization of aerosol activation:
  2. Multiple aerosol types.* J. Geophys. Res. 105(D5), 6837-6844.
  DOI: 10.1029/1999JD901161 (to confirm).
- Petters, M. D., Kreidenweis, S. M. (2007). *A single parameter representation of
  hygroscopic growth and cloud condensation nucleus activity.* Atmos. Chem. Phys.
  7, 1961-1971. DOI: 10.5194/acp-7-1961-2007.
- Twomey, S. (1977). *The Influence of Pollution on the Shortwave Albedo of
  Clouds.* J. Atmos. Sci. 34(7), 1149-1152.
  DOI: 10.1175/1520-0469(1977)034<1149:TIOPOT>2.0.CO;2 (to confirm). The
  `A(1-A)` sensitivity the closed form reproduced.
- Korolev, A. V., Mazin, I. P. (2003). *Supersaturation of Water Vapor in Clouds.*
  J. Atmos. Sci. 60(24), 2957-2974.
  DOI: 10.1175/1520-0469(2003)060<2957:SOWVIC>2.0.CO;2 (to confirm). The
  pre-existing-condensate correction.

## Amendments

- 2026-09-08: routed the growth coefficient and condensable properties through REQ-ATM-017 and registered the fit's validated range for the margin test (audit rows 9, 19), from notes/findings/2026-09-08-implicit-earth-audit.md
