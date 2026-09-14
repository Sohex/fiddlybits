+++
id = "REQ-SYS-005"
title = "An Earth-calibrated scheme is transferred by re-deriving what its calibration held fixed"
old_path = ["/home/cfutro/git/vesper/notes/audits/physics-review.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The physics review of 2026-08-17 asked not whether numbers were current but whether the
physics was right for the configuration it ran on (measured on the predecessor's
baseline climatology: a 12.81 m/s2, 1.2 Earth-radius planet with a 30-hour day around a
K2.5V host at 0.945 of Earth's instellation). Its archetype was a saltation scheme whose
standardisation corrected for air density and nothing else, so Earth's gravity sat
inside a constant used at 1.31 g and correcting it moved emission 30 per cent. Nothing
was wrong; an Earth-calibrated parameterisation was used unchanged. Five findings, each
of which generalises:

1. **A scheme fitted as a fraction of a reference spectrum carries that spectrum's
   band weights.** The shortwave absorptances of Lacis and Hansen (1974) are fractions
   of total incident solar flux, so each carries the Sun's share of flux in its band.
   The ozone terms had been re-weighted for the declared star; the water vapour term
   had not, and water vapour absorbs in the near infrared where a K dwarf puts more of
   its flux. Integrating the laboratory band absorptions of Howard, Burch and Williams
   (1956), the data Yamamoto (1962) weighted with the solar flux to make the fit Lacis
   and Hansen then fitted, against the declared spectrum gave a weight of 1.346
   (bracket 1.301 to 1.363). A flux-share ratio (1.274) is a lower bound, because an
   absorptance-weighted average must exceed a flux-weighted one. Worth +15.0 W/m2 of
   atmospheric absorption, -13.0 W/m2 at the surface, +2.9 W/m2 at the top of the
   atmosphere (bracket +2.0 to +4.5), on that climatology.
2. **A normalisation is derived on one grid, and an identity is its check.** The
   Rayleigh coefficient paired a reference Planck curve tabulated on the scheme's own
   grid with a spectrum file's wavelengths on another; the two grids start at different
   short-wavelength edges and a lambda^-4 weighting makes the short end decisive. The
   coded value was 0.2097 where the honest one was 0.7125. The check that made this a
   finding was the identity the normalisation is built on: a 5772 K spectrum must
   return exactly 1, and did. The same subroutine had also run every orbit after the
   first on a 4965 K blackbody because a driver rebuilt a namelist without the spectrum
   file, worth +0.024 on the albedo of every snow-covered cell, and nothing in the
   run's output distinguished the two cases.
3. **A calibration target that is an Earth population statistic may itself depend on
   gravity.** The incision coefficient was calibrated to reproduce the density of
   Earth's standing through-flowing basins, which is honest, but stream power per unit
   bed area scales with g, so incision is faster and fewer basins survive at a given
   age; the target has no gravity term and is wrong by the same factor at any future
   value of the coefficient. Of order 30 to 40 basins in a marginal class of 98.
4. **No stability correction is an omission, not a neutral choice.** A neutral bulk
   transfer coefficient with no Monin-Obukhov correction was applied where it is least
   valid: a lake cooler than the hot air above it in an arid basin is a stably
   stratified surface layer, where the neutral coefficient overstates exchange by 20 to
   30 per cent on a daily mean and a factor of 2 to 5 in strongly stable conditions.
   One-signed, compounding with the next finding.
5. **A nonlinear rate evaluated at the mean state is not the mean of the rate.**
   Saturation vapour pressure is convex, about 6.7 per cent per kelvin at 290 K, so
   the mean of e_s over a diurnal cycle exceeds e_s of the daily mean; on that
   climatology's own extrema (land-mean diurnal range 8.08 K, 90th percentile 12.3 K)
   the rectification is +1.2 per cent at the land mean and +4.4 per cent at the 90th
   percentile. Beside it, the companion finding (`missed-couplings.md` finding 2): the
   saturation term was read at 2 m and the actual humidity at the lowest model level
   near 300 m, inflating the deficit systematically; reading all four inputs at the
   level the transfer coefficient is derived over moved the error against the model's
   own open-water evaporation from 8.45 per cent high to 3.28 per cent low.

Knocked down, with evidence: the tropospheric lapse rate was Earth-like because latent
heat release, not gravity, sets it (6.4 to 6.7 K/km measured, against a dry adiabat of
12.75); the Hadley cell width barely moves because g H = R T cancels gravity; the
Rayleigh column mass carried an explicit gravity factor and was right.

## Why it carries

Every parameterisation fitted on Earth data holds something fixed that the fit never
names: the spectrum, the gravity, the reference level, the diurnal and seasonal range
it was averaged over, the stability regime of its calibration sites. Transferring the
number without re-deriving what was held fixed is an implicit-Earth constant wearing a
scheme's name. The plan's design removes the specific instances (line-by-line
absorption per declared spectrum in B2; a Monin-Obukhov surface layer; a column step
that resolves the planet's day; gravity entering incision through K in SI), but every
remaining parameterisation, and every one a future configuration adds, is the same
shape, and the plan says so: "every parameterisation fitted on Earth data stays
Earth-fitted; a struct makes the value nameable, not correct".

## What this system must do

- For every scheme with a `Sourced` constant, the record names what the calibration
  held fixed and which `System` quantities (spectrum, g, rotation, composition,
  reference level, averaging period) it therefore depends on; that dependency set is
  what the tracking wrapper of A3 measures.
- Any quantity defined as a fraction of incident flux, any band weight, and any
  spectrally weighted surface property is derived by an integral against the declared
  spectrum (and the sum of spectra where the system has several sources), on one grid,
  with an identity: the reference spectrum the scheme was published for reproduces the
  published value to a declared tolerance, through the same code path the declared
  spectrum takes.
- The spectrum a run uses is part of the run identity and is verified against the
  declaration before the first step; a fallback to a blackbody is a refusal, never a
  silent branch.
- A calibration target taken from an Earth population statistic is examined for
  dependence on gravity, rotation, spectrum and size class before use; the dependence
  is derived or `Bracketed`, never absent.
- A rate that is nonlinear in a state variable is integrated over the cycle that
  variable varies on, at the cadence the process has (the column step resolves the
  shortest forcing cycle the configuration has: the solar day, or the orbit or
  eclipse cycle for a synchronous rotator; the slow tier reads distributions over
  declared cycles), and is evaluated at a mean state only where the rectification is
  bounded and reported.
- Every input of a bulk formula is read at the level the coefficient is derived over,
  and the reference height is this planet's (hypsometric in its own R, T and g).
- The absence of a physical correction (stability, a continuum, an absorber, a
  gravity term) is a declared absence with its one-signed magnitude bracketed, never
  an implicit neutral choice; the sign of an omission is recorded beside the item it
  compounds with.

## Enforced by

C3's radiation oracles (grey and Guillot analytics, line-by-line references for any
declared spectrum, blackbody and photon-currency identities); A6 identity including the
spectrum key; declared-absence records; the M4b parameter sweeps across rotation,
obliquity, gravity, stellar type and flux; the C1 Earth distance report.

## References

- /home/cfutro/git/vesper/notes/audits/physics-review.md
- /home/cfutro/git/vesper/notes/audits/missed-couplings.md, finding 2 (the reference-level pair)
- /home/cfutro/git/vesper/lib/stellar.py (module docstring: the identity and the grid defect)
- Lacis and Hansen (1974). *A Parameterization for the Absorption of Solar Radiation in the Earth's Atmosphere.* DOI 10.1175/1520-0469(1974)031<0118:APFTAO>2.0.CO;2
- Yamamoto (1962). *Direct Absorption of Solar Radiation by Atmospheric Water Vapor, Carbon Dioxide and Molecular Oxygen.* DOI 10.1175/1520-0469(1962)019<0182:DAOSRB>2.0.CO;2
- Howard, Burch and Williams (1956). *Infrared Transmission of Synthetic Atmospheres. III. Absorption by Water Vapor.* DOI 10.1364/JOSA.46.000242
- Segura et al. (2003). *Ozone Concentrations and Ultraviolet Fluxes on Earth-Like Planets Around Other Stars.* Astrobiology 3(4), 689-708. DOI: to confirm
- Kok et al. (2014). *An improved dust emission model - Part 1: Model description and comparison against measurements.* DOI 10.5194/acp-14-13023-2014
- Monin and Obukhov (1954). *Basic laws of turbulent mixing in the surface layer of the atmosphere.* Trudy Geofiz. Inst. AN SSSR 24(151), 163-187. Locator: to confirm (pre-DOI; English translation widely reprinted)
- Louis (1979). *A parametric model of vertical eddy fluxes in the atmosphere.* DOI 10.1007/BF00117978
- Penman (1948). *Natural evaporation from open water, bare soil and grass.* Proc. R. Soc. Lond. A 193, 120-145. DOI: to confirm
- Plan decisions B2, B4, C1, C3.

## Amendments

- 2026-09-08: the column step resolves the configuration's shortest forcing cycle, not "the day", so the rule holds for a synchronous rotator, from notes/findings/2026-09-08-implicit-earth-audit.md.
