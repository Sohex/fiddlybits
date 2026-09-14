+++
id = "REQ-ATM-004"
title = "Cloud condensate is prognostic with an explicit effective radius; a diagnostic profile anchored to another planet's scale height is refused; every optics fit is used inside its fitted range"
old_path = ["/home/cfutro/git/vesper/exoplasim/notes/cloud-water-reference.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's diagnostic cloud scheme (CCM3's exponential
liquid-water profile feeding a Stephens optical-depth fit) on a planet with 0.766
of Earth's scale height.

- The in-cloud liquid water profile `rho_l0 exp(-z/hl)` had `hl = 700 ln(1+PW)`
  in Earth metres against layer heights that scaled as 1/g. Deriving the length
  from `R/g` cut column liquid water by 31 per cent and the top-level water by a
  factor of 10.9; longwave cloud emissivity at sigma 0.19 was 0.67 against the
  derived profile's 0.25 (`model-earth-centrism.md` finding 5).
- The reference density 0.21 g/m3 had one source, no range and no sensitivity,
  and anchored a profile that had been analytically prescribed for the previous
  model version rather than measured ("What the sources settle"). Its own
  authors' global cloud water path was 0.57 of the observed value.
- A factor of two either side of that value moved the modelled global mean by
  +4.34 and -4.64 K, about 9 K across a factor of four: larger than any term in
  the forcing bundle and larger than the bundle's registered sum ("Measured: the
  three arms"). The sign was predicted from the saturated longwave emissivity of
  low cloud and held; the magnitude bracket, widened in the direction a previous
  offline estimate had erred, missed the other way.
- The value could not carry its calibration across optics schemes: the source
  put the water path into a scheme linear in path with an effective radius, the
  consumer into a fit whose elasticity ran from 1.9 at 5 g/m2 to 0.73 at 200,
  so no single rescaling of the water matched at more than one path ("`clwref`
  does not move under Stephens").
- The fit was made over 10 to 10,000 g/m2; the model's top three layers sat one
  to three decades below it, in the regime the fit's own revision excludes by
  name. Band 1 had been using band 2's fit, 4 to 19 per cent too bright. Three
  tuned coefficients sat a factor of two from the published tables, worth -5 to
  -16 K when replaced. The scheme carried an effective radius silently, the
  relation of eight terrestrial stratiform clouds, 5 to 11 um.
- The source split condensate into liquid and ice with separate optics and
  modified optical depth for overlap; the consumer did neither.

## Why it carries

Cloud water is the first-order radiative lever in any atmosphere model, and a
generic builder has no Earth precipitable-water-to-cloud-water regression to
borrow and no Earth stratiform effective radius to bury. Decision 0016 makes
condensate prognostic with a single-moment microphysics and an effective radius
from droplet number and water content, so the lever becomes a computed state
rather than a constant with one source. The fit-range lesson generalises to every
tabulated or fitted optical property: the range is part of the source entry and
is checked at every evaluation.

## What this system must do

1. Liquid and ice condensate are prognostic with sources and sinks in SI; no
   diagnostic condensate profile exists, and no length in physics code encodes
   another planet's scale height (REQ-SYS-101).
2. The effective radius is computed from droplet or crystal number and
   condensate mass and passed to both shortwave and longwave optics; a grey
   longwave absorption with no size dependence is refused (decision 0016).
3. Cloud optical properties per band are generated from optical constants by
   Mie for the declared band edges (REQ-ATM-002); a fitted or tabulated property
   carries its fitted range in the registry, and an evaluation outside it is
   recorded in the radiation ledger as an extrapolation with the fraction of
   cloud it affected. Ice optics are generated from ice optical constants over an
   effective-size axis; the habit mixture that maps size to optics is `Bracketed`,
   with the cloud population it was fitted on and its size range in the registry,
   because no habit parameterisation carries a form that generalises beyond the
   population it was fitted to.
4. The sub-grid condensate distribution is a TKE-derived PDF whose width is a
   `Closure` (REQ-SYS-104), not a critical-humidity threshold.
5. Every `Bracketed` microphysical constant (autoconversion, fall-speed drag
   coefficients, entrainment) has its global-mean sensitivity to a factor of two
   reported in a lever table at the M4 gate, so the first-order levers are known
   before any Earth comparison is read (decision 0034). The autoconversion
   coefficient is dimensional and absorbs the air and condensate densities of the
   simulation it was fitted on, so the rate is evaluated in per-volume condensate
   and droplet number with both densities read from the state and from
   REQ-ATM-017, and the bracket is on the dimensionless remainder.
6. Earth oracle: global cloud water path and cloud radiative effect against
   published observations as REPORT rows; a cloud-optics fit against the tables
   it was fitted to as an identity oracle (decisions 0025, 0026).
7. The condensable is a declared field of the system, water by declaration
   (decision 0016); every phase-change and optics relation in this record reads the
   condensable's latent heats, saturation vapour pressure, surface tension and
   optical constants from the one `Sourced` set REQ-ATM-017 owns, and a
   configuration declaring another condensable is a priced declared absence
   (REQ-ATM-013) until those relations exist for it.

## Enforced by

- Decision 0016 (prognostic clouds, single-moment microphysics, TKE PDF);
  decision 0007 (`Closure`, no `Tuned`).
- The registry rule that a Sourced table carries its range, and a runtime check
  that writes out-of-range evaluations to the ledger.
- The lever table as a named M4 deliverable and the mutation run (decision 0027).

## References

- Kiehl, J. T., Hack, J. J., Bonan, G. B., Boville, B. A., Williamson, D. L., Rasch,
  P. J. (1998). *The National Center for Atmospheric Research Community Climate
  Model: CCM3.* J. Climate 11(6), 1131-1149.
  DOI: 10.1175/1520-0442(1998)011<1131:TNCFAR>2.0.CO;2. Eqs. 3, 4, 12-15.
- Kiehl, J. T., Hack, J. J., Bonan, G. B., Boville, B. A., Briegleb, B. P.,
  Williamson, D. L., Rasch, P. J. (1996). *Description of the NCAR Community
  Climate Model (CCM3).* NCAR Technical Note NCAR/TN-420+STR.
  DOI: 10.5065/D6FF3Q99. Eqs. 4.a.11 to 4.a.14 and the CCM2 provenance of the
  reference density.
- Stephens, G. L. (1978). *Radiation Profiles in Extended Water Clouds. II:
  Parameterization Schemes.* J. Atmos. Sci. 35(11), 2123-2132.
  DOI: 10.1175/1520-0469(1978)035<2123:RPIEWC>2.0.CO;2. Eqs. (7), (10a), (10b);
  the fitted range and the buried effective radius.
- Stephens, G. L., Ackerman, S., Smith, E. A. (1984). *A Shortwave
  Parameterization Revised to Improve Cloud Absorption.* J. Atmos. Sci. 41(4),
  687-690. DOI: 10.1175/1520-0469(1984)041<0687:ASPRTI>2.0.CO;2. Tables 1(a)-(c)
  and the thin-cloud exclusion.
- Slingo, A. (1989). *A GCM Parameterization for the Shortwave Radiative
  Properties of Water Clouds.* J. Atmos. Sci. 46(10), 1419-1427.
  DOI: 10.1175/1520-0469(1989)046<1419:AGPFTS>2.0.CO;2 (to confirm). The scheme
  linear in water path with an explicit effective radius.
- Lloyd, G., et al. (2018). *In situ measurements of cloud microphysical and
  aerosol properties during the break-up of stratocumulus cloud layers in cold
  air outbreaks over the North Atlantic.* Atmos. Chem. Phys. 18, 17191-17206.
  DOI: 10.5194/acp-18-17191-2018. The observable the bracket was taken from.
- Covert, J. M., Mechem, D. B., Zhang, Z. (2022). *Subgrid-scale horizontal and
  vertical variation of cloud water in stratocumulus clouds: a case study based on
  LES and comparisons with in situ observations.* Atmos. Chem. Phys. 22,
  1159-1174. DOI: 10.5194/acp-22-1159-2022.

## Amendments

- 2026-09-08: dispositioned the ice-habit mixture as Bracketed with its fitted population and range (audit row 15), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: stated that the autoconversion coefficient absorbs densities and is evaluated with them explicit (audit row 16), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: declared the condensable as water by declaration with its properties owned by REQ-ATM-017 (audit row 8), from notes/findings/2026-09-08-implicit-earth-audit.md
