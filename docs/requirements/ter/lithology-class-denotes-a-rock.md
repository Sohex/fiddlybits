+++
id = "REQ-TER-015"
title = "A lithology class denotes a rock with cited properties, never a position or a climate band, and a surface's albedo is computed from reflectance spectra against the declared stellar spectrum and the surface's state"
old_path = ["/home/cfutro/docs/world/notes/audits/orogen-lithology.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's builds `precarve-craton` and `precarve-craton-10m`
and its lithology module. Class semantics: `evaporite` denoted a POSITION (the
lowest quarter of a preserved basin's relief), with no water chemistry
entering, so a gypsum class was structurally impossible and the brine decision
was made downstream by the Hardie-Eugster divide; `playa_clastic` was a
residual (inside a closed basin, not in its lowest quarter) spanning a basin
from sump to rim, half of it above 83 per cent of its basin's relief and a
third to a half on gradients a mud flat does not have, so a consumer that gave
the class one roughness was a factor of 13 off, and the class's extent was a
pre-carve limit that moved a sixth between region counts; a shelf was
`carbonate` below 30 degrees of latitude and `shelf_clastic` above, two classes
five times apart in erodibility separated by a coordinate, when the deciders
are water temperature, depth and terrigenous supply, none of which the
generator held. The obliquity and the stellar spectrum pushed a latitude band
in opposite directions, so no honest refit of the number existed; it was
labelled a bootstrap and a test asserted the label still described the
classifier. Twenty classes carried sixty numbers with no reference. The
erodibility ORDERING was supported and its SPREAD was about four times too wide
(14x from quartzite to salt against a published global index of 3.2x and a
fluvially expressed contrast within one mountain belt of about 4x, because
channels adjust width and slope to the rock); one pair was inverted (andesite
above basalt), which a strength slider that compresses toward the mean cannot
catch; the "mean-normalised to 1" property was no longer true of the shipped
field (0.9735 and 0.9995) after cover stripping. Correcting erodibility left
the land-sea mask bit-identical and basin identities intact, and moved finished
basin volumes by 8.1 per cent in the median; two corrections partially
cancelled, so applying one moved the terrain five times further than both.

Albedo: the only published broadband-per-rock table was albedo relative to an
MgO standard on 0 to 74 micrometre powders (a sample can read 1.13), unusable
without two corrections; slab, crushed and powder measurements of the same
rocks gave a powder-over-slab factor of median 2.74, range 2.19 to 5.11,
lithology-dependent, so powder ratios must never be carried across the
felsic-mafic contrast; on slabs the table's felsic values were 2.4x too bright
and the felsic-to-mafic contrast collapsed from an assumed 3.0 to 1.2, the same
direction as the erodibility error. Under a redder star silicates brightened
(+0.006 to +0.087) while hydrous salts darkened (gypsum -0.029, trona -0.027)
because of structural-water bands beyond 1.4 micrometres, where 19 to 22 per
cent of that star's shortwave fell against 12 to 14 per cent of the Sun's, so
the stellar correction has opposite signs for rock and for hydrous salt. Within
one mineral the spread across specimens (halite 0.311 to 0.877) exceeded the
difference between minerals; field crusts read 0.18 to 0.65 against 0.74 to
0.88 in the library; wetting switched a crust from 0.64 to 0.24. Surface state
dominated mineralogy, and a static class albedo was wrong by up to 0.28
wherever standing water or a damp crust sat. A field albedo was reconciled from
two disagreeing groundings by taking a ratio inside one library so the
preparation offset cancelled. Against an Earth compilation, the evaporite
comparison had been taken against the "dominant" column (0.3 per cent of land)
rather than the "present" column (3.8 per cent), a factor of thirteen inside
one dataset between two numbers both called evaporite; the composition table's
denominator was the elevation-sign mask, understating evaporite by 1.17x.

## Why it carries

Decision B1 carries stratigraphy (basement class plus age, cover layers with
deposition age), B8 writes evaporite cover from brine chemistry, B2 computes
N-band surface albedo from reflectance spectra per surface class under
whatever spectrum is declared, and B4 and B7 change cover and wetness. Each of
those needs a class to mean a rock, a value to carry its source and
preparation, an erodibility contrast that is the one landscapes express, an
albedo that is a computed product of spectrum and state, and an Earth
comparison that names its column.

## What this system must do

- A lithology class is a rock (composition, fabric) with `Sourced` density and
  reflectance spectrum, `Bracketed` expressed erodibility, and `Sourced`
  nutrient content; every value carries source, table and preparation (slab,
  crushed, powder, field crust).
- No class is assigned by latitude, coordinate or position in a landform. A
  class that depends on a coupled variable is written by the process that owns
  it (evaporite by the brine divide in B8, carbonate shelf by water
  temperature, depth and terrigenous supply from B3 and B1's sediment, cover by
  deposition in B1) with its deposition age; where the deciding variables do
  not exist yet, the classifier emits unknown and mixed fractions, never a
  binary bootstrap.
- The erodibility contrast in the incision law is the expressed contrast,
  `Bracketed` from field measurements, with ordering a tested invariant; any
  normalisation claimed of a field is re-checked on the field as shipped. The
  contrast scales one absolute anchor `k_e`, converted from its source landscape by
  the rule in 0015 (dividing out that landscape's `rho_w g`, mean runoff and year),
  so no class carries another landscape's runoff or gravity inside its
  erodibility.
- Surface albedo per class is computed per radiation band from
  directional-hemispherical reflectance spectra of slab and field-state
  samples (never powders across the felsic-mafic contrast), integrated against
  the declared stellar spectrum and the surface downward spectrum after
  atmospheric transmission (B2); where a landscape sits between slab floor and
  particulate ceiling is a `Bracketed` regolith state.
- Wetness, crust, standing water and snow modify albedo as prognostic state at
  the column step (B4); they are never part of a class constant.
- A comparison with an Earth lithology compilation names the column and the
  denominator and is a `REPORT` metric (decision C1).

## Enforced by

- Class table schema: a value without source, table and preparation fields is
  refused at load.
- Lint: latitude and coordinates are unreadable in the lithology module.
- A3 dispositions on every class property; the ordering invariant test.
- Albedo pipeline test: a reflectance spectrum with a structural-water band
  integrated under two blackbody temperatures reproduces the sign of the
  hydrous-salt versus silicate shift; a wetted-surface test.
- C1 distance report on lithology composition with named columns; M1 gate.

## References

- Hartmann, J., Moosdorf, N. (2012). "The new global lithological map database
  GLiM: A representation of rock properties at the Earth surface".
  Geochemistry, Geophysics, Geosystems 13, Q12004. DOI: 10.1029/2012GC004370.
- Moosdorf, N., Cohen, S., von Hagke, C. (2018). "A global erodibility index to
  represent sediment production potential of different rock types". Applied
  Geography 101, 36-44. DOI: 10.1016/j.apgeog.2018.10.010.
- Zondervan, J. R., Stokes, M., Boulton, S. J., Telfer, M. W., Mather, A. E.
  (2020). "Rock strength and structural controls on fluvial erodibility:
  Implications for drainage divide mobility in a collisional mountain belt".
  Earth and Planetary Science Letters 538, 116221.
  DOI: 10.1016/j.epsl.2020.116221.
- Stock, J. D., Montgomery, D. R. (1999). "Geologic constraints on bedrock
  river incision using the stream power law". Journal of Geophysical Research
  104(B3), 4983-4993. DOI: 10.1029/98JB02139.
- Sklar, L. S., Dietrich, W. E. (2001). "Sediment and rock strength controls on
  river incision into bedrock". Geology 29(12), 1087-1090.
  DOI: 10.1130/0091-7613(2001)029<1087:SARSCO>2.0.CO;2.
- Bursztyn, N., Pederson, J. L., Tressler, C., Mackley, R. D., Mitchell, K. J.
  (2015). "Rock strength along a fluvial transect of the Colorado Plateau -
  quantifying a fundamental control on geomorphology". Earth and Planetary
  Science Letters 429, 90-100. DOI: 10.1016/j.epsl.2015.07.042.
- Portenga, E. W., Bierman, P. R. (2011). "Understanding Earth's eroding
  surface with 10Be". GSA Today 21(8), 4-10. DOI: 10.1130/G111A.1.
- Hunt, G. R. (1982). "Spectroscopic properties of rocks and minerals". In
  Carmichael, R. S. (ed.), Handbook of Physical Properties of Rocks, volume I,
  CRC Press. Locator: chapter 3, Table 9; ISBN to confirm.
- Logan, L. M., Hunt, G. R., Salisbury, J. W., Balsamo, S. R. (1973).
  "Compositional implications of Christiansen frequency maximums for infrared
  remote sensing applications". Journal of Geophysical Research 78(23),
  4983-5003. DOI: to confirm.
- Paragas, K. et al. (2025). The POSEIDON surface albedo database: slab,
  crushed and powder reflectance of the same rocks. Verbatim title and DOI: to
  confirm.
- Hu, R., Ehlmann, B. L., Seager, S. (2012). "Theoretical Spectra of Terrestrial
  Exoplanet Surfaces". The Astrophysical Journal 752, 7.
  DOI: 10.1088/0004-637X/752/1/7.
- Meerdink, S. K., Hook, S. J., Roberts, D. A., Abbott, E. A. (2019). "The
  ECOSTRESS spectral library version 1.0". Remote Sensing of Environment 230,
  111196. DOI: 10.1016/j.rse.2019.05.015.
- Kokaly, R. F. et al. (2017). "USGS Spectral Library Version 7". U.S.
  Geological Survey Data Series 1035. DOI: 10.3133/ds1035.
- Post, D. F. et al. (2000). "Predicting Soil Albedo from Soil Color and
  Spectral Reflectance Data". Soil Science Society of America Journal 64,
  1027-1034. DOI: 10.2136/sssaj2000.6431027x.
- Henderson-Sellers, A., Wilson, M. F. (1983). "Surface albedo data for
  climatic modeling". Reviews of Geophysics 21(8), 1743-1778.
  DOI: 10.1029/RG021i008p01743.
- Kampf, S. K., Tyler, S. W., Ortiz, C. A., Munoz, J. F., Adkins, P. L. (2005).
  "Evaporation and land surface energy budget at the Salar de Atacama, Northern
  Chile". Journal of Hydrology 310, 236-252.
  DOI: 10.1016/j.jhydrol.2005.01.005.
- Hardie, L. A., Eugster, H. P. (1970). "The evolution of closed-basin brines".
  Mineralogical Society of America Special Paper 3, 273-290. Locator: MSA
  Special Paper 3 (pre-DOI).
- Daly, R. A., Manger, G. E., Clark, S. P. (1966). "Density of rocks". In
  Clark, S. P. (ed.), Handbook of Physical Constants, Geological Society of
  America Memoir 97. DOI: to confirm.

## Amendments

- 2026-09-08: erodibility contrast stated as scaling one anchor converted by the 0015 rule, so runoff and gravity of the source landscape do not ride inside a class (row 1), from notes/findings/2026-09-08-implicit-earth-audit.md
