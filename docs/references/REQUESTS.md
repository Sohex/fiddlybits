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


## Land column, snow and lakes (B4, M5)


## Cryosphere (B6, M10)


## Vegetation and biogeochemistry (B7, M9)

- Biochemical Models of Leaf Photosynthesis -- von Caemmerer, S. (2000). Techniques in Plant Sciences 2, CSIRO Publishing, Collingwood. DOI: 10.1071/9780643103405 (CSIRO monograph record); ISBN 978-0-643-06379-2 (0-643-06379-X). Anchors: REQ-BIO-007, 0021. Suggested filename: voncaemmerer2000-biochemical-models-leaf-photosynthesis.pdf Left open by the user for a later date.


## Pedology, weathering, brines and carbon (B8, M10)


## Ocean, sea ice and marine ecosystem (B3, M6)


## Managed biosphere (B10, F4, M11)


## Earth oracle datasets (C1 tier 2, M4, M6, M7)

- MODIS/Terra+Aqua BRDF/Albedo Model Parameters Daily L3 Global 0.05Deg CMG V061 (MCD43C3, the albedo CMG product) -- Schaaf and Wang (2021). DOI: 10.5067/MODIS/MCD43C3.061. Anchors: M7 earth.modis_albedo_by_class. DATASET, not a paper: every daily file for a declared window (2001-2020 preferred; 2015-2019 acceptable), fetched by short name and date range with earthaccess or an Earthdata token, into oracles/data/mcd43c3/ with a hashed manifest.
- Mixed layer depth over the global ocean: An examination of profile data and a profile-based climatology -- de Boyer Montegut, C. et al. (2004). Journal of Geophysical Research 109, C12003. DOI: 10.1029/2004JC002378. Anchors: earth.mld_by_basin. Unpaywall reports a green open-access copy at HAL (hal-00266983); the one fetch attempt here returned a bot-interstitial page rather than the PDF. Suggested filename: deboyermontegut2004-mixed-layer-depth-global-ocean.pdf
- High-resolution fields of global runoff combining observed river discharge and simulated water balances -- Fekete, B. M., Vorosmarty, C. J., Grabs, W. (2002). Global Biogeochemical Cycles 16 (3), 1042. DOI: 10.1029/1999GB001254. Anchors: earth.land_pme_vs_runoff, earth.grdc_basin_discharge. Unpaywall reports an open publisher copy; the one fetch attempt here returned a bot-interstitial page rather than the PDF. Suggested filename: fekete2002-high-resolution-fields-global-runoff.pdf
- Mineralogy and geochemistry of clay fractions in soils developed from different parent rocks in Limpopo Province, South Africa -- Oyebanjo, O. O. et al. (2021). Heliyon 7 (7), e07664. DOI: 10.1016/j.heliyon.2021.e07664. Anchors: earth.basalt_granite_clay_divergence. Open access (Heliyon, CC BY) at PMC8346642; the one fetch attempt here (PMC, EuropePMC, ScienceDirect) returned no PDF. Suggested filename: oyebanjo2021-clay-fractions-parent-rocks-limpopo.pdf
- Global products of vegetation leaf area and fraction absorbed PAR from year one of MODIS data -- Myneni, R. B. et al. (2002). Remote Sensing of Environment 83 (1-2), 214-231. DOI: 10.1016/S0034-4257(02)00074-3. Anchors: earth.modis_lai_seasonal. Unpaywall reports no open copy (Elsevier, subscription). Suggested filename: myneni2002-global-products-leaf-area-fpar-modis.pdf
