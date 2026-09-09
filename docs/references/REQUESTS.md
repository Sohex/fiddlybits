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
