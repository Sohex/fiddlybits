+++
id = "REQ-OCN-008"
title = "The marine ecosystem is a trait community generated from a declared low-dimensional trait space; its coupling arithmetic, light path and export carry no fixed Earth ratios, no buried photon constants and no gravity-blind length scales"
old_path = ["/home/cfutro/docs/world/notes/audits/ecosystem-tier-ecogem-marbl.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor read two ecosystem candidates at line level. ECOGEM's trait
space is not its population file (three columns: functional type, diameter,
replicate count) but an allometric generator: 36 coefficient pairs of the form
`coef_a * volume ** coef_b` plus a size grid, all reachable from configuration
and all Earth laboratory-culture fits (Ward et al. 2012); community composition
emerges inside that space. MARBL takes a hand-written table of 38 parameters
per autotroph with a poison default and no generator. The defects that
generalise, each measured on the source trees as vendored:

- Coupling arithmetic reverting to fixed ratios: ECOGEM's plankton
  stoichiometry is emergent through dynamic quotas, but the arithmetic that
  returns fluxes to the chemistry uses literals (138/106 for O2:C, 16 for N:P
  twice, 6.625 for C:Chl, 40 for diazotroph N:P) wherever a quota is switched
  off, with no warning; MARBL derives seven of ten Redfield ratios from three
  with a bare 150 in one of them.
- The light path: both candidates are single-band below the surface. MARBL's
  shortwave-to-PAR fraction (0.45) and six attenuation coefficients are
  compile-time; ECOGEM exposes its band fraction and two attenuation
  coefficients but buries the photon conversion (0.2174 W per micromole of
  photons). Measured against the predecessor's declared K-star spectrum the
  band fraction moves 15 per cent and the mean photon energy 2.3 per cent
  from their solar values; a clear-water e-folding depth of 25 to 43 m is a
  solar calibration neither model can express the reason for.
- Sinking: MARBL states export as e-folding lengths (a speed divided by a
  rate, with neither factor exposed), so there is no defensible way to rescale
  it for another gravity; ECOGEM's sinking parameter is dead code; the
  chemistry's opal path keeps the sinking speed and the dissolution rate as
  two separately reachable numbers, which is the seam a gravity scaling
  needs, and the settling regime (Stokes, g^1, to aggregate, g^0.5 to g^0.67)
  was bracketed and not determined.
- Host obligations: MARBL requires its host to supply a global reduction for
  burial closure; without it the silicon cycle has no global closure at all.
- Guards with no failing state: a viability guard `maxval(qmin/qmax) > 1`
  evaluates 0/0 for every non-silicifier, a NaN under an optimised build, so
  the comparison is false and the guard never fires; two latent out-of-bounds
  index paths; a conservation requirement enforced on a dissolved tracer and
  not on its sediment counterpart, so uptake with the sink unselected is a
  silent permanent removal.
- Time and provenance: rates per day through a seconds-per-day literal
  declared three times; half of the live silicon parameters trace to
  references absent from the describing paper's own list, so "an undocumented
  value is a test case rather than an anchor"; an element inventory is a
  design decision the model will not raise, and the published configuration
  answered "source and sink: neither".

`ocean-and-marine-biosphere.md` section 8e added: a transplanted-Earth trait
set is a labelled bracket, never traits tuned to a desired productivity map;
light limitation needs the declared spectrum and spectral water-column
attenuation; rates need an absolute-time registry.

## Why it carries

B3 adopts a trait-based marine community. The lessons are structural: a
community is a prediction only inside a declared trait space, so the space
must be a small set of covarying allometric and strategy relations, each with
a disposition under the "biology assumption" of B7; coupling arithmetic must
use the community's own stoichiometry, because a fallback literal is a second
model hiding under a switch; the light path must be spectral against the
declared star with the photon currency derived; export must expose the
gravity-dependent speed separately from the biological rate; every host
obligation must be a declared exchange; every guard must be able to fail;
every element cycle must close or refuse.

## What this system must do

- The marine community (B3) is generated from a declared trait space:
  size-structured allometric relations with declared coefficient pairs, and
  strategy traits (nitrogen fixation, calcification, silicification,
  mixotrophy, motility, photoprotection), each coefficient carrying a
  disposition (`Irreducible` under the biology assumption, `Bracketed` where a
  range is defensible). An Earth-fitted trait set is one labelled
  configuration, never the default.
- All stoichiometric conversions at the ecosystem-chemistry boundary (O2:C,
  alkalinity:N, N:P, Chl:C, Si:C, Fe:C) use the populations' own quotas; no
  fixed ratio appears in coupling arithmetic; a switched-off element is a
  refusal at assembly, not a fallback literal.
- Photosynthetically available irradiance is computed per band from B2's
  spectral shortwave at the surface, with the photon currency (photons per
  joule per band) derived from the declared stellar spectrum, and the
  water-column attenuation per band from pure-water absorption, pigment
  absorption and particle scattering; the ecosystem writes the attenuation
  profile that the ocean column's shortwave heating reads (REQ-OCN-007).
- Particle export is a settling speed, a function of particle size, excess
  density, the viscosity read through the seawater-properties door of B3
  (under the composition fence of REQ-OCN-003) and the system's gravity, with
  the settling regime declared and its gravity exponent `Bracketed`, multiplied
  by a remineralisation rate on the SI clock; an e-folding length is a
  diagnostic, never a parameter.
- Iron speciation and scavenging are a named scheme that is a function of the
  modelled oxygen and pH state, with the ligand concentration `Bracketed`
  (mechanisms: photolysis and scavenging loss at the low end, biological ligand
  production at the high end); iron limitation is an outcome of the ocean's
  redox state, never a declared limiter, because it exists on an oxic ocean
  only through the insolubility of the oxidised metal. No solubility or
  scavenging constant assumes the oxygen level of one atmosphere.
- Every global reduction the ecosystem needs (burial closure, inventories) is
  a declared exchange field with a writer; every element cycle (C, N, P, Si,
  Fe, S, O2, alkalinity) has a ledger with source, sink and inventory
  declared, the inventory `Bracketed` where the system has no mechanism to
  derive it; an element with uptake and no return path is a refusal.
- Every guard has a failing state under FP32 and FP64 (NaN-safe comparisons),
  demonstrated by mutation.
- Rates are on the SI clock (A4); no per-day literal exists.
- A parameter whose provenance cannot be followed to a read primary source is
  a `Bracketed` test case, never `Sourced` (Part G).

## Enforced by

- B3 and B7 decision records; A3 dispositions and the `EarthRatios`
  quarantine.
- A2 dimension types: photon flux and energy flux are distinct dimensions; a
  length used where a rate times a speed is required is a type error.
- C3 element ledgers with float-derived tolerance; a refusal table entry for
  an element with no sink.
- C4 mutation run: a planted NaN guard, a planted fixed ratio, a planted
  per-day literal, a planted oxic-ocean iron solubility constant.
- A8 import review for any ecosystem or chemistry library adopted.
- M6 gate: marine NPP in the observational range as REPORT; the export
  profile against sediment-trap compilations as a distance report; M4b
  stellar-type sweep of the light path.

## References

- Follows, M. J., Dutkiewicz, S., Grant, S. and Chisholm, S. W. (2007).
  "Emergent Biogeography of Microbial Communities in a Model Ocean". Science
  315, 1843-1846. DOI: 10.1126/science.1138544.
- Ward, B. A., Dutkiewicz, S., Jahn, O. and Follows, M. J. (2012). "A
  size-structured food-web model for the global ocean". Limnology and
  Oceanography 57, 1877-1891. DOI: 10.4319/lo.2012.57.6.1877.
- Ward, B. A., Wilson, J. D., Death, R. M., Monteiro, F. M., Yool, A. and
  Ridgwell, A. (2018). "EcoGEnIE 1.0: plankton ecology in the cGENIE Earth
  system model". Geoscientific Model Development 11, 4241-4267.
  DOI: 10.5194/gmd-11-4241-2018.
- Litchman, E. and Klausmeier, C. A. (2008). "Trait-Based Community Ecology of
  Phytoplankton". Annual Review of Ecology, Evolution, and Systematics 39,
  615-639. DOI: 10.1146/annurev.ecolsys.39.110707.173549.
- Morel, A. and Maritorena, S. (2001). "Bio-optical properties of oceanic
  waters: A reappraisal". Journal of Geophysical Research 106(C4), 7163-7180.
  DOI: 10.1029/2000JC000319.
- Kriest, I. and Oschlies, A. (2008). "On the treatment of particulate
  organic matter sinking in large-scale models of marine biogeochemical
  cycles". Biogeosciences 5, 55-72. DOI: 10.5194/bg-5-55-2008.
- Redfield, A. C. (1958). "The biological control of chemical factors in the
  environment". American Scientist 46, 205-221. Locator: no DOI; JSTOR
  27827150, to confirm.

## Amendments

- 2026-09-08: settling-law viscosity read through the seawater-properties door under the composition fence (row 24), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: new bullet: iron speciation as a function of the modelled oxygen and pH state, ligand `Bracketed` with mechanisms, iron limitation an outcome; mutation break added (row 10), from notes/findings/2026-09-08-implicit-earth-audit.md
