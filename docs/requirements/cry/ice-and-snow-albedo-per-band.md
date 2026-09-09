+++
id = "REQ-CRY-004"
title = "Ice and snow surface albedo is computed per band from a reflectance spectrum under the declared stellar spectrum, with different values in each band and the bands anchored to reproduce any sourced broadband value"
old_path = ["/home/cfutro/docs/world/notes/external-model-survey.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

`notes/external-model-survey.md` section 22: an exoplanet configuration of
CESM modified the land-ice albedo to 0.80 in the visible and 0.55 in the near
infrared, anchored against a stated full-spectral value of about 0.5 from
Paterson with a named precedent. The predecessor's atmosphere carried seven
surface albedo arrays with the same value written into both bands (its
failure-mode class 31), which the independent implementation showed to be
anomalous rather than conventional. The predecessor's own two-band derivation
from reflectance spectra gave 0.766 and 0.455 under the Sun for a
glacial-minimum blend and 0.764 and 0.406 under its declared K-star spectrum:
the visible barely moved and the near infrared fell by 0.049 with the redder
star. Section 29 found the ocean's zenith branches spectrally flat in the same
way. Section 43f recorded a peer carrying prognostic snow grain size with dust
darkening and a zenith correction on sea ice. `ocean-tier-implicit-earth.md`
section A3 recorded the sea-ice albedo ramp and the material properties of
ice and snow as declared quantities.

## Why it carries

Ice and snow reflectance is strongly wavelength-dependent, high in the visible
and low in the near infrared, falling with grain size and impurity load, and
a planet's star sets how much of the incident flux sits in each band. A single
broadband number, or one number copied into both bands, mis-states the
absorbed flux by an amount that grows with the star's redness and the
surface's spectral contrast, and the ice-albedo feedback is where a climate's
bistability lives. B2 computes N-band surface albedo from reflectance spectra
per surface class; this record fixes the anchoring convention and forbids the
flat-array class.

## What this system must do

- Every ice and snow surface class (glacier ice, bare sea ice, melt ponds,
  snow on ice, snow on land) carries a reflectance spectrum or a spectral
  model (SNICAR-style for snow with prognostic grain size and impurity mass,
  B4; a `Sourced` spectrum for bare ice and ponds) from which B2's band
  albedos are computed by flux-weighting under the declared stellar spectrum,
  per band, at every radiation call.
- Band values differ where the reflectance spectrum differs. A surface class
  whose band values are identical is a lint warning that requires a stated
  physical reason.
- Where a broadband value is the sourced datum, the band pair is anchored so
  that its flux-weighted combination reproduces the datum under the spectrum
  the datum was measured under, and is then re-weighted under the declared
  spectrum; both steps are recorded with the datum's disposition.
- The zenith-angle dependence and the direct and diffuse split are carried
  per band.
- The material properties of ice and snow that set thermodynamics (density,
  conductivity, heat capacity, latent heat) are `Sourced` for pure phases
  and `Bracketed` over brine volume for sea ice (REQ-OCN-011); they are never
  shared by copy between components.

## Enforced by

- B2 and B4 decision records.
- C3 radiation identity: the band-weighted albedo reproduces the broadband
  datum under the measurement spectrum to float tolerance.
- Lint on identical band values within a surface class.
- C1 tier 2: snow and ice albedo against observational compilations as
  REPORT.
- M4b stellar-type sweep.

## References

- Warren, S. G. (1982). "Optical properties of snow". Reviews of Geophysics
  20, 67-89. DOI: 10.1029/RG020i001p00067.
- Wiscombe, W. J. and Warren, S. G. (1980). "A Model for the Spectral Albedo
  of Snow. I: Pure Snow". Journal of the Atmospheric Sciences 37, 2712-2733.
  DOI: to confirm.
- Flanner, M. G. and Zender, C. S. (2006). "Linking snowpack microphysics and
  albedo evolution". Journal of Geophysical Research 111, D12208.
  DOI: 10.1029/2005JD006834.
- Grenfell, T. C. and Maykut, G. A. (1977). "The optical properties of ice and
  snow in the Arctic Basin". Journal of Glaciology 18(80), 445-463.
  DOI: to confirm.
- Cuffey, K. M. and Paterson, W. S. B. (2010). "The Physics of Glaciers", 4th
  edition. Butterworth-Heinemann. ISBN: to confirm. (The broadband glacier
  ice albedo datum the two-band anchoring reproduces.)
