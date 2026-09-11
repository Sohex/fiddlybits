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

- Implicit-explicit Runge-Kutta methods for time-dependent partial differential equations -- Ascher, U. M., Ruuth, S. J., Spiteri, R. J. (1997). Applied Numerical Mathematics 25 (2-3), 151-167. DOI: 10.1016/S0168-9274(97)00056-1. Anchors: decision 0041, the ARS tableaux and the ARS343 unconstrained comparison arm for the fast tier's integrator. Unpaywall reports no open copy. Suggested filename: ascher1997-implicit-explicit-runge-kutta-methods.pdf Supplied 2026-09-10.


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

Added 2026-09-10 by the CliMA survey's seawater review
(`docs/imports/seawaterpolynomials-jl.md`) and supplied by the user the same day;
the row is in `INDEX.md` as held. Kept here as the record of the request.

- Defining a Simplified yet "Realistic" Equation of State for Seawater -- Roquet, F., Madec, G., Brodeau, L., Nycander, J. (2015). Journal of Physical Oceanography 45 (10), 2564-2579. DOI: 10.1175/JPO-D-15-0080.1. Anchors: 0017, the second-order equation-of-state form and its six coefficient sets. Filed as roquet2015a-defining-simplified-realistic-equation-state-seawater.pdf. Supplied 2026-09-10. The paper is marked open access on its own first page, so the single automated fetch that failed was aimed at the wrong URL rather than at a paywall.

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

## Not requested: born-digital copies of scanned holdings

A list of 22 paywalled books was briefly here, asking for born-digital copies because their OCR'd
tables could not be trusted. Withdrawn. The model does not take numbers from a book's tables; a
constant enters from a page named in its disposition record, and the corpus is for finding that
page. OCR'd table cells are now removed from the queryable text altogether
(`tools/references/strip_ocr_tables.py`), which removes the hazard without buying anything. Where
a book's *data* has a machine-readable home, that home is the input dataset and the book is a
scan to open by eye; Carmichael's rock properties to ECOSTRESS and splib07 is the one done so far,
and the question is asked per constant as constants are filed. A book whose data has such a home
and whose text offers nothing else is not kept at all.
