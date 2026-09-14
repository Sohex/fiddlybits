+++
id = "REQ-BIO-004"
title = "A bioclimatic limit is a tissue-level threshold applied to the temperature the tissue experiences as the land column resolves it, never a monthly-mean index calibrated on another planet's climatology"
old_path = ["/home/cfutro/git/vesper/notes/audits/lpj-pft-set-implicit-earth.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

An Earth vegetation model's cold-survival limit is not a tissue threshold. It
is a coldest-month MEAN, compared against the mean of the last twenty years'
coldest monthly means, calibrated on a planet where a monthly mean of -31 C
implies absolute minima tens of kelvin below it and where roots sit under
snow. The predecessor's audit of the shipped plant functional types found that
two Earth-derived things are imported at once, the number and the statistic
that relates it to what tissue experiences (measured on the old world's port
at the archived commit):

- Hardened frost resistance by tissue (Larcher 2005) runs -40 to below -70 C
  for leaves, buds, twigs and stems of boreal conifers and -20 to -30 C for
  roots; the roots are the exception because Earth's soil at 20 cm stayed
  between 0 and -7 C while the air fell below -20 C, so Earth's roots were
  never selected for deep hardiness. Two mechanisms, not one scale: deep
  supercooling caps at -30 to -50 C, and beyond that survival is freezing
  tolerance. The model carries one number for the whole plant.
- On the configuration measured, the polar coldest-month mean was -68.75 C
  and the coldest-month minimum -69.59 C, a gap of 0.84 K: the mean-based
  criterion was accidentally safe there and would not be at a lower latitude
  where the two differ by tens of kelvin. The root zone under a 0.07 m
  snowpack ran near -79.5 C at the surface stand-in, against a root tolerance
  of -20 to -30 C; snow that thin buys 0.5 to 1.4 K of ground warming (Yershov
  1998 as reviewed by Zhang 2005) and its sign is not assured under a thin
  high-albedo cover.
- The port ran a 30-hour rotation, which widens the diurnal range, and the
  vegetation model was structurally blind to it: no daily-minimum mortality
  anywhere, every cold limit through a twenty-year mean of monthly means, and
  the only reader of the diurnal range a disabled volatile-emission scheme.
- Only the survival limit kills; establishment limits bar recruitment and a
  type barred from recruiting legitimately persists. The audit that
  generalised the polar finding across the planet had to keep killed and
  barred apart, and found that a barred count is evidence of nothing (7.3 to
  10.1 of twelve types barred in every band, including the fullest); the
  signature that generalises is the cover-weighted share of the growing season
  the RESIDENT types spend above their own declared photosynthetic ceiling
  (31.8 percent above `pstemp_high` and 7.5 percent above `pstemp_max`
  poleward of 75 degrees).

## Why it carries

A monthly-mean index encodes a proxy relation (index to tissue temperature)
that is a property of Earth's diurnal amplitude, month length, snow regime and
soil buffering, none of which a generic configuration shares (rotation,
obliquity, snow climatology and gravity are all free in A0). The one land
column (B4) resolves soil heat with phase change under a multilayer snowpack,
canopy temperature and the planet's own day, so the temperature a tissue
experiences is available at the column step and the proxy is unnecessary.
Applying a limit to the resolved extremum is what makes the limit a piece of
physiology that transfers rather than a climatology that does not.

## What this system must do

1. Every thermal tolerance in the strategy space (REQ-BIO-006) is a trait of a
   named tissue (leaf, bud, stem, root, storage organ) and is applied to the
   resolved temperature of that tissue's zone: leaf and bud from the canopy
   energy balance, stem from the canopy air, root and storage organ from the
   soil heat column at the depth the root profile occupies under the snowpack
   the tile actually carries. The comparison uses the interval extremum the
   column resolves at its step, never a monthly or multi-year mean.
2. A cold limit carries hardening as physiology: a hardening state that
   follows recent temperature with a bracketed memory (acclimation, REQ-BIO-007)
   and a carbon cost (B7: frost tolerance with its carbon cost). A heat limit
   is the photosynthetic temperature response's declining limb and its
   acclimation, not a separate fixed ceiling.
3. Survival and establishment are separate filters with separate traits, and
   every diagnostic names which one acted (killed versus barred).
4. No climate index (degree-day sum, coldest-month mean, chilling days) enters
   a biosphere filter unless the system derives it from the same resolved state
   on the system clock (REQ-BIO-001, REQ-BIO-005); an index imported with its
   Earth threshold is refused.
5. Standard diagnostics: per tile, the cover-weighted share of the growing
   season each resident strategy spends above its declared photosynthetic
   ceiling, and the killed and barred counts, so a strategy space that leaves
   ground empty for a thermal reason is visible without a special study.

## Enforced by

- Type: a tolerance trait is parameterised by tissue and by the `Field` it
  reads (tissue-zone temperature extremum at the column step); the refusal
  table refuses a monthly-mean field as an argument.
- Fixture: two configurations identical except rotation period must differ in
  frost mortality where the column's resolved minimum differs (a
  diurnal-range sensitivity that the old model could not express).
- Oracle: the Earth test instance reports treeline position and boreal
  extent as REPORT metrics (C1 tier 2); a snow-buffer identity test (root-zone
  minimum under a declared pack against an analytic conduction solution).
- Decision records for B4 (soil heat with phase change, multilayer snow) and
  B7.

## References

- Larcher, W. (2005). Climatic Constraints Drive the Evolution of Low
  Temperature Resistance in Woody Plants. Journal of Agricultural Meteorology
  61, 189-202. DOI: to confirm. Frost resistance by tissue; roots as the
  unhardened exception.
- Sakai, A. and Larcher, W. (1987). Frost Survival of Plants: Responses and
  Adaptation to Freezing Stress. Ecological Studies 62, Springer.
  DOI: to confirm. Supercooling versus freezing tolerance as two mechanisms.
- Zhang, T. (2005). Influence of the seasonal snow cover on the ground thermal
  regime: An overview. Reviews of Geophysics 43, RG4002.
  DOI: 10.1029/2004RG000157. Snow depth to ground warming, and the sign
  reversal under thin cover.
- Sitch, S. et al. (2003). Evaluation of ecosystem dynamics, plant geography
  and terrestrial carbon cycling in the LPJ dynamic global vegetation model.
  Global Change Biology 9, 161-185. DOI: 10.1046/j.1365-2486.2003.00569.x.
  The monthly-mean bioclimatic limits as shipped.
- /home/cfutro/git/vesper/biosphere/notes/underoccupied-niches.md (the
  killed versus barred separation and the thermal-share diagnostic).
- /home/cfutro/git/vesper/biosphere/README.md, section "The 30-hour day widens
  the diurnal range, and neither side carries it yet".
