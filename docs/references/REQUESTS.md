# Requests

The fetch list for the user: every primary source in `design-citations.md` not already held as a
PDF in the predecessor tree. 194 papers, grouped by subsystem. The 25 that are held in the old
index are not listed here; they are linked or copied from `/home/cfutro/git/vesper/references/pdf/`
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

- Parallel algorithms for tree accumulations -- Sevilgen, F. E., Aluru, S., Futamura, N. (2005). Journal of Parallel and Distributed Computing 65 (1), 85-93. DOI: 10.1016/j.jpdc.2004.09.001. Anchors: the rake-and-compress tree accumulation FastFlow adapts, and any bound it proves on the round count (notes/findings/2026-09-13-fastflow-tree-contraction-reads-no-coordinates-and-its-fixed-round-count-leaves-trees-unfinished.md). OpenAlex reports no open copy. Suggested filename: sevilgen2005-parallel-algorithms-tree-accumulations.pdf
- Fast minimum spanning tree for large graphs on the GPU -- Vineet, V., Harish, P., Patidar, S., Narayanan, P. J. (2009). Proceedings of the Conference on High Performance Graphics 2009, 167-171. DOI: 10.1145/1572769.1572796. Anchors: the parallel Boruvka construction FastFlow's basin merge follows. OpenAlex reports no open copy. Suggested filename: vineet2009-fast-minimum-spanning-tree-large-graphs.pdf
- A phenomenon-based approach to upslope contributing area and depressions in DEMs -- Rieger, W. (1998). Hydrological Processes 12 (6), 857-872. DOI: 10.1002/(SICI)1099-1085(199805)12:6<857::AID-HYP659>3.0.CO;2-B. Anchors: depression carving, the receiver path reversed from pit to spill. OpenAlex reports no open copy. Suggested filename: rieger1998-phenomenon-based-approach-upslope-contributing-area.pdf

## Land column, snow and lakes (B4, M5)


## Cryosphere (B6, M10)


## Vegetation and biogeochemistry (B7, M9)

- Biochemical Models of Leaf Photosynthesis -- von Caemmerer, S. (2000). Techniques in Plant Sciences 2, CSIRO Publishing, Collingwood. DOI: 10.1071/9780643103405 (CSIRO monograph record); ISBN 978-0-643-06379-2 (0-643-06379-X). Anchors: REQ-BIO-007, 0021. Suggested filename: voncaemmerer2000-biochemical-models-leaf-photosynthesis.pdf Left open by the user for a later date.


## Pedology, weathering, brines and carbon (B8, M10)


## Ocean, sea ice and marine ecosystem (B3, M6)


## Managed biosphere (B10, F4, M11)


## Earth oracle datasets (C1 tier 2, M4, M6, M7)

- MODIS/Terra+Aqua BRDF/Albedo Model Parameters Daily L3 Global 0.05Deg CMG V061 (MCD43C3, the albedo CMG product) -- Schaaf and Wang (2021). DOI: 10.5067/MODIS/MCD43C3.061. Anchors: M7 earth.modis_albedo_by_class. DATASET, not a paper: every daily file for a declared window (2001-2020 preferred; 2015-2019 acceptable), fetched by short name and date range with earthaccess or an Earthdata token, into oracles/data/mcd43c3/ with a hashed manifest.
