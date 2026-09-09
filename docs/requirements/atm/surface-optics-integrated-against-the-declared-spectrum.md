+++
id = "REQ-ATM-002"
title = "Every surface reflectance and every absorptance is integrated against the declared spectrum per band, and nothing downstream of a star-weighted endmember is spectrum-blind"
old_path = ["/home/cfutro/docs/world/notes/audits/inherited-earth-constants.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's surface and cloud optics under a 4965 K host whose
spectrum put 0.382 of its flux below 0.75 um where the Sun puts 0.517.

- The vegetated land albedo was 0.15 with no source, integrated against the Sun.
  553 green-vegetation reflectance spectra integrated against the host and
  against a 5772 K Planck curve gave a ratio of 1.10 (1.14 with the tails), so a
  canopy is brighter under a redder star while a mineral with near-infrared
  absorption is darker: the sign of the correction flips with the surface. The
  term was worth 0.7 to 1.0 K, one-signed, larger than any priced aerosol term
  (finding 1). Three surface codes had carried one array, asserting that a canopy
  reflects equally either side of 0.75 um.
- Deriving an endmember from the spectrum did not make everything downstream of
  it star-aware. The snow-over-forest masking applied one pair of Earth-Sun
  broadband ratios to both bands, so the band-2 forested endmember was 0.097 too
  dark at full canopy (`model-earth-centrism.md` finding 7). The sea-ice albedo
  ramp kept Earth's broadband slope of 0.025 per K under star-weighted endpoints,
  so the two bands saturated 4.7 K apart, a gap set by the re-weighting and by
  nothing about the ice (finding 12).
- Four gas absorptances had been re-weighted for the host on the argument that
  a fitted absorptance is a fraction of solar flux; the cloud shortwave co-albedo
  had not. Derived from a quantity carrying no spectrum, liquid water's optical
  constants, through Mie and flux-weighted over the band, the ratio was 1.192
  (1.184 to 1.205 across droplet radii), worth about +2 K (finding 2).
- The star file the runs had used was an M dwarf at about 3450 K rather than a
  K dwarf; replacing it moved overall snow albedo from 0.562 to 0.395
  (`parameter-decisions.md`, "Stellar spectrum"). A sentence written for a rock
  surface, "ground and ocean barely move", survived a switch to a vegetated
  surface it was never measured on.
- Under the declared spectrum the same snow at the same grain size was roughly a
  tenth of an albedo darker than under the Sun, growing with grain size, because
  the flux moved into the half of the spectrum where ice absorbs
  (`snow-albedo-grain.md`).

## Why it carries

An albedo is a reflectance integrated against the light falling on it; an
absorptance fitted as a fraction of a flux carries that flux's shape. Neither is a
property of a surface or a gas alone, and a generic builder has a different
spectrum for every configuration and several at once when the system has several
stars. The lesson is structural: the star enters every optical property, and the
only way that holds after the first derivation is that every operation on an
optical property is performed on its per-band values. "Snow is bright" and
"vegetation is dark" are solar facts, which is the coupling lesson of the plan
applied to radiation.

## What this system must do

1. Surface albedo is N-band, computed per surface class (rock class, soil, water,
   vegetation by trait, snow by grain and impurity, sea and glacier ice) from
   reflectance spectra integrated against the declared spectrum per band at run
   setup (decision 0016). No scalar broadband albedo constant exists in physics
   code.
2. Every operation on an optical property (canopy masking, snow-cover blending,
   temperature or age ramps, wetting, mixing of classes within a tile) acts on
   the per-band values; a broadband factor applied across bands is a type error.
3. Cloud and aerosol optical properties are regenerated per band from optical
   constants through Mie for the declared band edges; no fitted absorptance is
   re-weighted by a per-star factor (REQ-ATM-003). Every optical-constant table
   carries the temperature it was measured at in its source entry, with the
   table's own stated temperature dependence as the bracket on evaluations away
   from it.
4. The band edges themselves come from the flux quantiles of the declared
   spectrum, so a band means the same fraction of the star's light for every
   configuration (decision 0016).
5. A change of spectrum invalidates every derived optical property through the
   artifact graph (decision 0010), and the distance report states per class how
   far each albedo sits from its solar-weighted published value and in which
   direction.
6. Where a photosynthetic or photochemical window is declared against the
   spectrum (decision 0021, ozone in decision 0016), the same per-band integral
   supplies it.

## Enforced by

- Decision 0006: spectral quantities are typed by band; an operation on a band
  vector with a scalar factor does not dispatch.
- Decision 0010: the spectrum hash in every optical artifact's key.
- An Earth-tier oracle (decision 0025): the `Earth()` instance reproduces the
  published solar-weighted albedo of each reference spectrum inside a stated bar.
- The mutation run (decision 0027): applying a broadband masking factor must be
  caught by the per-band identity.

## References

- Meerdink, S. K., Hook, S. J., Roberts, D. A., Abbott, E. A. (2019). *The
  ECOSTRESS spectral library version 1.0.* Remote Sensing of Environment 230,
  111196. DOI: 10.1016/j.rse.2019.05.015. The reflectance spectra of rocks, soils,
  vegetation and snow the per-band integrals were measured on.
- Baldridge, A. M., Hook, S. J., Grove, C. I., Rivera, G. (2009). *The ASTER
  spectral library version 2.0.* Remote Sensing of Environment 113(4), 711-715.
  DOI: 10.1016/j.rse.2008.11.007.
- Hale, G. M., Querry, M. R. (1973). *Optical Constants of Water in the 200-nm to
  200-um Wavelength Region.* Applied Optics 12(3), 555-563.
  DOI: 10.1364/AO.12.000555. The spectrum-free quantity from which a cloud
  co-albedo is derived for any star.
- Lacis, A. A., Hansen, J. E. (1974). *A Parameterization for the Absorption of
  Solar Radiation in the Earth's Atmosphere.* J. Atmos. Sci. 31(1), 118-133.
  DOI: 10.1175/1520-0469(1974)031<0118:APFTAO>2.0.CO;2. The fitted absorptances
  expressed as fractions of solar flux, which is why they cannot be carried to
  another star.
- Kiang, N. Y., Segura, A., Tinetti, G., Govindjee, Blankenship, R. E., Cohen, M.,
  Siefert, J., Crisp, D., Meadows, V. S. (2007). *Spectral Signatures of
  Photosynthesis. II. Coevolution with Other Stars And The Atmosphere on
  Extrasolar Worlds.* Astrobiology 7(1), 252-274. DOI: 10.1089/ast.2006.0108.
  Vegetation reflectance as a function of the host spectrum.

## Amendments

- 2026-09-08: added the measurement temperature of optical-constant tables to their source entries (audit row 26), from notes/findings/2026-09-08-implicit-earth-audit.md
