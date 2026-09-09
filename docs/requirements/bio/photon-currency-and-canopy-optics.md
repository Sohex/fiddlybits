+++
id = "REQ-BIO-003"
title = "One photon-currency conversion from the declared spectrum, shared by radiation and photosynthesis, with the pigment window a declared trait and leaf optics carried as reflectance and transmittance per band"
old_path = ["/home/cfutro/docs/world/biosphere/notes/productivity-prediction.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

A photosystem counts quanta and a radiation scheme carries joules, and the
predecessor found the conversion between them split into two halves on two
different windows and two different stars (measured on the old world's port at
the archived commit, under a K2.5V spectrum):

- The energy fraction inside the photosystem window had been derived for the
  declared star over 400 to 750 nm, while the quanta-per-joule constant was the
  vegetation model's shipped 4.6e-6 mol/J, the monochromatic 550 nm value for
  the Sun, carrying no spectrum at all. Derived on one spectrum over one
  window the constant became 4.864e-6 mol/J, 5.7 percent higher: 3.9 points
  from the wider window and 2.6 from the redder star, one-signed, so the
  shipped constant understated absorbed photon flux and assimilation with it.
- The same Earth-solar photon conversion, 4.6 umol per J, appeared in three
  independent models (a land demography model, a marine ecosystem model and
  the vegetation model): three instances, one constant.
- The energy fraction itself moved from 0.396 to 0.4913 when a
  low-resolution spectrum file that started at 0.34 um was replaced; the
  missing ultraviolet had inflated the solar reference's share of its own
  truncated total by 6.4 percent. The solar reference must stay on Earth's
  own 400 to 700 nm window whatever window the declared flora is given,
  because Earth's 0.5 is anchored there.
- Two controls stood behind the derivation: the monochromatic conversion at
  550 nm reproduces the shipped 4.6e-6, and a solar spectrum through the same
  integral over 400 to 700 nm gives 4.567e-6, 0.7 percent below it;
  integrating in wavelength and in frequency must agree.
- The window is a prediction of the star. The spectral optimisation of
  Lehmer et al. (2021) puts peak absorbance for a K2V at 675, 711 and 746 nm
  against 644 and 672 nm for the Sun; a 400 to 750 nm window on the declared
  spectrum recovered 0.99 of Earth's photon flux where 400 to 700 nm gave
  0.81. The outer bound is photochemical, not pigment absorption: charge
  separation is demonstrated on chlorophyll f at 745 nm in PSI and 727 nm in
  PSII (Nurnberg et al. 2018), and oxygenic photosynthesis is capped near
  800 nm on known biochemistry; anoxygenic schemes reaching 1.1 um cannot
  sustain an oxygen-bearing atmosphere. Where far-red photosynthesis is found
  on Earth (deep shade) is where it wins under a G2V, a statement about
  competition and not about what the chemistry can do; treating that as a
  caveat is itself the implicit-Earth error.
- Leaf optics are four numbers per class, not two: reflectance AND
  transmittance in each of two bands. Canopy albedo depends on the
  single-scattering albedo omega = alpha + tau, and a leaf that transmits
  strongly in the near-infrared raises omega_NIR without raising omega_PAR.
  Under a red star the leaf-to-canopy correction is therefore not one-signed:
  for two of three CLM5 leaf classes the canopy ratio exceeded the leaf ratio
  (measured in /home/cfutro/docs/world/notes/external-model-survey.md section
  38), so a reflectance library cannot settle the sign.
- A two-band surface albedo returned to the atmosphere had to be anchored on
  the radiation scheme's own band weights; anchoring on a leaf library's flux
  share left vegetated ground 0.0025 too bright, one-signed, and the identity
  z1*a1 + z2*a2 = a_broadband was asserted cell by cell before writing.

## Why it carries

The declared spectrum is a free parameter of the system (A0, B2 band edges
from flux quantiles of whatever spectrum is declared, multiple sources when the
system has them), so the photon currency is a derived quantity of `System` and
the pigment window is a trait of the declared flora, never an Earth number.
Splitting one conversion into two halves owned by two modules is the "N
definitions" failure (design idea 4). Carrying transmittance is a data
requirement that decides a sign, which the design's two-stream canopy (B4)
needs regardless of star.

## What this system must do

1. The radiation module owns one conversion: per declared band, photon flux
   density = integral over the band of spectral irradiance times
   lambda / (h c N_A), evaluated on the declared spectrum of every source in
   the system at the surface after the atmosphere (B2). The biosphere reads
   photons per band in mol per m2 per s and never multiplies an energy flux by
   a fraction. The conversion is `Derived` and refuses a caller value.
2. The pigment window (band edges the photosystem uses) is a declared trait
   of the strategy space (REQ-BIO-006), `Bracketed` between the spectral
   optimisation prediction for the declared star and the photochemical outer
   limit consistent with the declared atmospheric oxygen; its Earth value is a
   `Sourced` datum the Earth test instance uses and `EarthRatios` holds.
3. Controls run before the star's own value is returned: the monochromatic
   identity at a named wavelength, the solar spectrum over 400 to 700 nm
   against the standard quantum conversion, and agreement of the wavelength and
   frequency routes to floating-point tolerance (C3 photon-currency
   identity).
4. Canopy radiation (two-stream, B4) takes per-band leaf reflectance AND
   transmittance from the trait registry, where both are `Derived` from the
   strategy's pigment-window trait: absorptance inside the window `Bracketed`
   (dimensionless) between the measured leaf absorptance of Earth pigments
   (McCree 1972) and unit absorptance, and a scattering regime outside the
   window `Bracketed` on the measured near-infrared leaf optics, so that a
   leaf's absorption edge coincides with its window edge by construction; a
   published leaf optics table is the Earth test instance's entry and never a
   default. Leaf angle distribution and clumping are traits. All are
   integrated over the declared spectrum with the radiation scheme's band
   weights, whose edges include the window edges so that no band straddles the
   window. The N-band surface albedo returned to the atmosphere is anchored on
   those same weights so the broadband identity holds cell by cell at
   floating-point tolerance.
5. No sign is asserted for a leaf-to-canopy correction; it is computed.

## Enforced by

- Type: photon flux is a `Field` of dimension mol m^-2 s^-1 per band; an energy
  field cannot be passed where a photon field is expected (A2 dimension on the
  type).
- Lint: the Earth PAR fraction and 4.6 umol/J exist only in `EarthRatios`.
- Oracle: C3 photon-currency identities; blackbody identity; the Earth test
  instance reproduces the standard solar quantum conversion as a PASS metric.
- Registry: the trait registry refuses a leaf optics entry missing transmittance
  in any declared band, or whose absorption edge disagrees with the strategy's
  pigment window.

## References

- McCree, K. J. (1972). The action spectrum, absorptance and quantum yield of
  photosynthesis in crop plants. Agricultural Meteorology 9, 191-216.
  DOI: 10.1016/0002-1571(71)90022-7. The measured quantum yield the solar
  control is checked against.
- Kiang, N. Y. et al. (2007). Spectral Signatures of Photosynthesis. II.
  Coevolution with Other Stars and The Atmosphere on Extrasolar Worlds.
  Astrobiology 7, 252-274. DOI: 10.1089/ast.2006.0108. Pigment coevolution
  with the host star; the oxygenic constraint.
- Lehmer, O. R., Catling, D. C., Parenteau, M. N., Kiang, N. Y. and Hoehler,
  T. M. (2021). The Peak Absorbance Wavelength of Photosynthetic Pigments Around
  Other Stars From Spectral Optimization. Frontiers in Astronomy and Space
  Sciences 8, 689441. DOI: 10.3389/fspas.2021.689441. The optimisation that
  predicts the window per stellar type.
- Nurnberg, D. J. et al. (2018). Photochemistry beyond the red limit in
  chlorophyll f-containing photosystems. Science 360, 1210-1213.
  DOI: 10.1126/science.aar8313. The demonstrated 745 nm and 727 nm donors.
- Chen, M., Schliep, M., Willows, R. D., Cai, Z.-L., Neilan, B. A. and Scheer,
  H. (2010). A Red-Shifted Chlorophyll. Science 329, 1318-1319.
  DOI: 10.1126/science.1191127.
- Sellers, P. J. (1985). Canopy reflectance, photosynthesis and
  transpiration. International Journal of Remote Sensing 6, 1335-1372.
  DOI: 10.1080/01431168508948283. The two-stream canopy on single-scattering
  albedo alpha + tau.
- Lawrence, D. M. et al. (2019). The Community Land Model Version 5:
  Description of New Features, Benchmarking, and Impact of Forcing
  Uncertainty. Journal of Advances in Modeling Earth Systems 11, 4245-4287.
  DOI: 10.1029/2018MS001583. The per-class leaf reflectance and
  transmittance table that supplied the sign test.
- /home/cfutro/docs/world/notes/external-model-survey.md section 38 (the
  leaf-to-canopy bound is not one-signed).
- /home/cfutro/docs/world/biosphere/notes/implicit-earth-assumptions.md
  finding 5 (the two halves of one conversion).

## Amendments

- 2026-09-08: leaf optics per band Derived from the pigment-window trait with
  a registry refusal on a mismatched edge; band edges include the window edges
  (audit row 19), from notes/findings/2026-09-08-implicit-earth-audit.md
