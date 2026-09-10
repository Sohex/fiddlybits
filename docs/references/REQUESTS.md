# Requests

The fetch list for the user: every primary source in `design-citations.md` not already held as a
PDF in the predecessor tree. 194 papers, grouped by subsystem. The 25 that are held in the old
index are not listed here; they are linked or copied from `/home/cfutro/docs/world/references/pdf/`
under the filename recorded in `design-citations.md`.

Filing convention: `references/pdf/<firstauthor><year>-<slug>.pdf` at the repository root, where
`<firstauthor>` is the first author's family name in lower-case ASCII with diacritics stripped
(`zangl2015-...`, `fecan1999-...`), `<year>` is the year of the published version, and `<slug>` is a
short hyphenated fragment of the title. The suggested filename at the end of each line follows that
rule; a second paper by the same first author and year takes a letter suffix (`schaphoff2018a-...`).
`references/pdf/` is untracked payload; the row in `INDEX.md` is what is tracked, and on arrival the
row moves from `requested` to `held`, never straight to `read`.

Identifiers were confirmed against Crossref (or DataCite for datasets) by title, first author and
year before being listed, so each DOI resolves to the intended work. A line marked `no DOI` gives the
stable locator instead; two of those carry a `to confirm` on the locator itself. Dataset entries are
for the documentation paper or the dataset record; the data itself is fetched under the oracle
registry, not here.


## Dynamical core and mesh (A1, A9, F5, M3)


## Numerics, precision and reproducibility (A6, A7, C3, C4, C6)


## Atmosphere radiation and column physics (B2, M4)


## Non-Earth and aquaplanet oracles (C1 tier 3, M4, M4b)


## System, star and constants (A0, A4, F6)


## Terrain and lithology (B1, M1)


## Hydrology (B5, M2)


## Land column, snow and lakes (B4, M5)


## Cryosphere (B6, M10)


## Vegetation and biogeochemistry (B7, M9)


## Pedology, weathering, brines and carbon (B8, M10)


## Ocean, sea ice and marine ecosystem (B3, M6)


## Managed biosphere (B10, F4, M11)


## Earth oracle datasets (C1 tier 2, M4, M6, M7)

- MODIS/Terra+Aqua BRDF/Albedo Model Parameters Daily L3 Global 0.05Deg CMG V061 (MCD43C3, the albedo CMG product) -- Schaaf and Wang (2021). DOI: 10.5067/MODIS/MCD43C3.061. Anchors: M7 earth.modis_albedo_by_class. DATASET, not a paper: every daily file for a declared window (2001-2020 preferred; 2015-2019 acceptable), fetched by short name and date range with earthaccess or an Earthdata token, into oracles/data/mcd43c3/ with a hashed manifest.

## Requested by requirement records

Sources cited by `docs/requirements/` records that were neither in the predecessor tree nor already listed above. Identifiers confirmed against Crossref, DataCite or a live catalogue by the M-1 citation pass; the resolution notes are in `requests-from-requirements-part1.md` and `-part2.md`.

### Atmosphere, radiation, snow optics and system defaults
### Biosphere
### Hydrology and terrain
### Pedology and weathering

## Requested from the recent-literature sweep (paywalled; OpenAlex reports no open-access copy)

## Requested by the implicit-Earth audit amendments (2026-09-08)

Sources cited by the atmosphere, ocean, terrain, biosphere and system amendment passes of
2026-09-08 (source lists in the audit scratchpad; the amended records name each by author
and year) that OpenAlex and Unpaywall report as closed, or whose one open-access copy
refused an automated fetch. Identifiers confirmed against Crossref by title, first author
and year on 2026-09-08. Rule for this pass: one lookup and one fetch per source, no mirrors. The user supplied 29 of the 30 on 2026-09-08 and 2026-09-09; those rows now sit in INDEX.md as held. One remains.

### Biosphere and lakes (0018, 0021, REQ-BIO-006, -007, -015)

- Biochemical Models of Leaf Photosynthesis -- von Caemmerer, S. (2000). Techniques in Plant Sciences 2, CSIRO Publishing, Collingwood. DOI: 10.1071/9780643103405 (CSIRO monograph record); ISBN 978-0-643-06379-2 (0-643-06379-X). Anchors: REQ-BIO-007, 0021. Suggested filename: voncaemmerer2000-biochemical-models-leaf-photosynthesis.pdf Left open by the user for a later date.

## Born-digital replacements for scanned holdings

These are already held, as scans, and were read by OCR. The request is not for the work but for a
born-digital copy of it: the publisher's own PDF, with a real text layer, in place of a scan whose
tables were transcribed by a model. Each certainly exists born-digital behind a paywall, so none can
be fetched here.

Why it matters, measured: on the one scanned source whose columns check each other, the NIST-JANAF
fourth edition, the OCR damaged 493 of 1071 table pages silently
(`notes/findings/2026-09-09-janaf-table-identities.md`). These sources carry 719 OCR'd table pages
between them and have no such internal check. A born-digital copy removes the question rather than
re-reading a scan and hoping.

On arrival, replace `references/pdf/<file>.pdf`, delete `references/text/<file>/`, and re-extract with
`tools/references/extract_text.py`; no OCR pass is needed for a file with a real text layer.

| OCR'd table pages | title | identifier | held as |
|---|---|---|---|
| 239 | Spectroscopic properties of rocks and minerals | `10.1201/9780203712115` | `Robert S. Carmichael (Editor) - Handbook of Physical Properties of Rocks (1982)_ Volume I (2017, CRC Press) [10.1201_9780203712115] - libgen.li.pdf` |
| 139 | Magmatic Sulfide Deposits: Geology, Geochemistry and Exploration | `10.1007/978-3-662-08444-1` | `naldrett2004-magmatic-sulfide-deposits.pdf` |
| 101 | Frost Survival of Plants | `10.1007/978-3-642-71745-1` | `sakai1987-frost-survival-of-plants.pdf` |
| 64 | Solving Ordinary Differential Equations II | `10.1007/978-3-642-05221-7` | `hairer1996-solving-ordinary-differential-equations-ii.pdf` |
| 35 | The Linear Complementarity Problem | `10.1137/1.9780898719000` | `cottle2009-the-linear-complementarity-problem.pdf` |
| 33 | A Model of Marine Aerosol Generation Via Whitecaps and Wave Disruption (the whole Springer volume Oceanic Whitecaps and Their Role in Air-Sea Exchange Processes, Monahan and Mac Niocaill eds, 1986, 298 pages, scanned original with an OCR layer; the cited chapter 16 is book pages 167-174, PDF pages 174-181) | `10.1007/978-94-009-4668-2_16` | `monahan1986-oceanic-whitecaps.pdf` |
| 30 | Evaporation into the Atmosphere | `10.1007/978-94-017-1497-6` | `brutsaert1982-evaporation-into-the-atmosphere.pdf` |
| 16 | On the Distribution and Continuity of Water Substance in Atmospheric Circulations. | `10.1007/978-1-935704-36-2` | `kessler1969-on-the-distribution-and-continuity-of-water-substance.pdf` |
| 12 | Saline Lakes | `10.1007/978-1-4757-1152-3_8` | `eugster1978-saline-lakes.pdf` |
| 9 | Modeling the Primary Productivity of the World. | `10.1007/978-3-642-80913-2_12` | `lieth1975-miami-model.pdf` |
| 9 | A global analysis of root distributions for terrestrial biomes. | `10.1007/BF00333714` | `jackson_1996_a-global-analysis-of-root-distributions-for-terrestrial-biomes.pdf` |
| 8 | Determination of biomass burning emission factors: Methods and results | `10.1007/BF00546762` | `delmas1995-determination-biomass-burning-emission-factors.pdf` |
| 5 | The Accuracy of Floating Point Summation | `10.1137/0914050` | `higham1993-accuracy-floating-point-summation.pdf` |
| 4 | Dynamics of C, N, P and S in grassland soils: a model. | `10.1007/BF02180320` | `parton1988-century-c-n-p-s-grassland-model.pdf` |
| 3 | A biochemical model of photosynthetic CO2 assimilation in leaves of C3 species | `10.1007/bf00386231` | `farquhar1980-biochemical-model-photosynthetic-co2-assimilation.pdf` |
| 2 | Thermophysical Properties of Ice, Snow, and Sea Ice. | `10.1007/BF01133567` | `fukusako1990.pdf` |
| 2 | Sur les fonctions convexes et les inegalites entre les valeurs moyennes | `10.1007/BF02418571` | `jensen1906-sur-les-fonctions-convexes.pdf` |
| 2 | Monte Carlo Methods in Statistical Mechanics: Foundations and New Algorithms | `10.1007/978-1-4899-0319-8_6` | `sokal1997-monte-carlo-methods-statistical-mechanics.pdf` |
| 2 | Monotone Piecewise Cubic Interpolation | `10.1137/0717021` | `fritsch1980-monotone-piecewise-cubic-interpolation.pdf` |
| 2 | Icosahedral Discretization of the Two-Sphere | `10.1137/0722066` | `baumgardner1985-icosahedral-discretization-two-sphere.pdf` |
| 1 | Self-formed straight rivers with equilibrium banks and mobile bed. Part 2. The gravel river (scanned original with the publisher OCR layer) | `10.1017/S0022112078002505` | `parker1978-self-formed-straight-rivers-part-2-gravel-river.pdf` |
| 1 | A comparison of the Two One-Sided Tests Procedure and the Power Approach for assessing the equivalence of average bioavailability | `10.1007/BF01068419` | `schuirmann1987-two-one-sided-tests-procedure.pdf` |

719 table pages over 22 works.
