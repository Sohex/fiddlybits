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
and year on 2026-09-08. Rule for this pass: one lookup and one fetch per source, no mirrors.

### Atmosphere: spectroscopy, boundary layer, deposition, gas properties (0016, 0022, REQ-ATM-003, -006, -012, -017)

- HITEMP, the high-temperature molecular spectroscopic database -- Rothman, L. S., Gordon, I. E., Barber, R. J., Dothe, H., Gamache, R. R., Goldman, A., Perevalov, V. I., Tashkun, S. A., Tennyson, J. (2010). J. Quant. Spectrosc. Radiat. Transfer 111(15), 2139-2150. DOI: 10.1016/j.jqsrt.2010.05.001. Anchors: 0016, REQ-ATM-003. Suggested filename: rothman2010-hitemp-high-temperature-molecular-spectroscopic-database.pdf
- H2, He, and CO2 line-broadening coefficients, pressure shifts and temperature-dependence exponents for the HITRAN database. Part 1: SO2, NH3, HF, HCl, OCS and C2H2 -- Wilzewski, J. S., Gordon, I. E., Kochanov, R. V., Hill, C., Rothman, L. S. (2016). J. Quant. Spectrosc. Radiat. Transfer 168, 193-206. DOI: 10.1016/j.jqsrt.2015.09.003. Anchors: 0016, REQ-ATM-003. Suggested filename: wilzewski2016-h2-he-co2-line-broadening-coefficients-part-1.pdf
- H2, He, and CO2 Pressure-induced Parameters for the HITRAN Database. II. Line Lists of CO2, N2O, CO, SO2, OH, OCS, H2CO, HCN, PH3, H2S, and GeH4 -- Tan, Y., Kochanov, R. V., Rothman, L. S., Gordon, I. E., et al. (2022). Astrophys. J. Suppl. Ser. 262(2), 40. DOI: 10.3847/1538-4365/ac83a6. The amendment cited this as JQSRT 222-223 (2019) with the DOI to confirm; Crossref resolves the verbatim title to the 2022 ApJS paper and no 2019 JQSRT paper of that title exists, so the records' citation year and venue want correcting. Open access at IOP, but the publisher's PDF endpoint answers an automated fetch with a bot captcha; a browser download works. Anchors: 0016, REQ-ATM-003. Suggested filename: tan2022-h2-he-co2-pressure-induced-parameters-part-ii.pdf
- Temperature-dependent measurements and modeling of absorption by CO2-N2 mixtures in the far line-wings of the 4.3 um CO2 band -- Perrin, M. Y., Hartmann, J. M. (1989). J. Quant. Spectrosc. Radiat. Transfer 42(4), 311-317. DOI: 10.1016/0022-4073(89)90077-0. Anchors: 0016, REQ-ATM-003. Suggested filename: perrin1989-absorption-co2-n2-mixtures-far-line-wings.pdf
- Update of the HITRAN collision-induced absorption section -- Karman, T., Gordon, I. E., van der Avoird, A., et al. (2019). Icarus 328, 160-175. DOI: 10.1016/j.icarus.2019.02.034. An open-access copy sits in the Radboud Repository (hdl.handle.net/2066/204360) but the bitstream answers an automated fetch with 403; a browser download works. Anchors: 0016, REQ-ATM-003. Suggested filename: karman2019-update-hitran-collision-induced-absorption.pdf
- A theory for local evaporation (or heat transfer) from rough and smooth surfaces at ground level -- Brutsaert, W. (1975). Water Resour. Res. 11(4), 543-550. DOI: 10.1029/WR011i004p00543. Anchors: 0016, REQ-ATM-012. Suggested filename: brutsaert1975-theory-local-evaporation-rough-smooth-surfaces.pdf
- Parameterization of surface resistances to gaseous dry deposition in regional-scale numerical models -- Wesely, M. L. (1989). Atmos. Environ. 23(6), 1293-1304. DOI: 10.1016/0004-6981(89)90153-4. Anchors: REQ-ATM-006. Suggested filename: wesely1989-parameterization-surface-resistances-gaseous-dry-deposition.pdf
- A Model of Marine Aerosol Generation Via Whitecaps and Wave Disruption -- Monahan, E. C., Spiel, D. E., Davidson, K. L. (1986). In Monahan, E. C., Mac Niocaill, G. (eds), Oceanic Whitecaps, Oceanographic Sciences Library, D. Reidel, 167-174. DOI: 10.1007/978-94-009-4668-2_16. Anchors: REQ-ATM-006, 0022. Suggested filename: monahan1986-model-marine-aerosol-generation-whitecaps.pdf
- The IAPWS Formulation 1995 for the Thermodynamic Properties of Ordinary Water Substance for General and Scientific Use -- Wagner, W., Pruss, A. (2002). J. Phys. Chem. Ref. Data 31(2), 387-535. DOI: 10.1063/1.1461829. Anchors: REQ-ATM-017. Suggested filename: wagner2002-iapws-formulation-1995-thermodynamic-properties-water.pdf
- NIST-JANAF Thermochemical Tables, Fourth Edition -- Chase, M. W. (1998). J. Phys. Chem. Ref. Data Monograph 9. No DOI (Crossref has no record for the monograph; OpenAlex W2974895998 carries none). The NIST WebBook serves the same tables one species at a time (janaf.nist.gov), which is not a single fetchable file. Anchors: REQ-ATM-017. Suggested filename: chase1998-nist-janaf-thermochemical-tables-fourth-edition.pdf
- Viscosity and Thermal Conductivity Equations for Nitrogen, Oxygen, Argon, and Air -- Lemmon, E. W., Jacobsen, R. T. (2004). Int. J. Thermophys. 25(1), 21-69. DOI: 10.1023/B:IJOT.0000022327.04529.f3. Anchors: REQ-ATM-017. Suggested filename: lemmon2004-viscosity-thermal-conductivity-nitrogen-oxygen-argon-air.pdf
- A Viscosity Equation for Gas Mixtures -- Wilke, C. R. (1950). J. Chem. Phys. 18(4), 517-519. DOI: 10.1063/1.1747673. Anchors: REQ-ATM-017. Suggested filename: wilke1950-viscosity-equation-gas-mixtures.pdf
- The Mathematical Theory of Non-Uniform Gases, 3rd ed. -- Chapman, S., Cowling, T. G. (1970). Cambridge University Press. No DOI; ISBN 978-0-521-40844-8 (0-521-40844-X). Anchors: REQ-ATM-017 (also listed by the biosphere pass for the same record). Suggested filename: chapman1970-mathematical-theory-non-uniform-gases.pdf
- New Method for Prediction of Binary Gas-Phase Diffusion Coefficients -- Fuller, E. N., Schettler, P. D., Giddings, J. C. (1966). Ind. Eng. Chem. 58(5), 18-27. DOI: 10.1021/ie50677a007. Anchors: REQ-ATM-017 (also listed by the biosphere pass). Suggested filename: fuller1966-new-method-prediction-binary-gas-phase-diffusion.pdf
- The Properties of Gases and Liquids, 5th ed. -- Poling, B. E., Prausnitz, J. M., O'Connell, J. P. (2001). McGraw-Hill. No DOI; ISBN 978-0-07-011682-5 (0-07-011682-2). Compilation, cited for its tables only. Anchors: REQ-ATM-017. Suggested filename: poling2001-properties-of-gases-and-liquids.pdf

### Ocean and sea ice (0004, 0017, REQ-OCN-003, -011)

- The composition of Standard Seawater and the definition of the Reference-Composition Salinity Scale -- Millero, F. J., Feistel, R., Wright, D. G., McDougall, T. J. (2008). Deep-Sea Res. I 55(1), 50-72. DOI: 10.1016/j.dsr.2007.10.001. Anchors: 0017, REQ-OCN-003, 0004. Suggested filename: millero2008-composition-standard-seawater-reference-composition-salinity.pdf
- Abyssal recipes II: energetics of tidal and wind mixing -- Munk, W., Wunsch, C. (1998). Deep-Sea Res. I 45, 1977-2010. DOI: 10.1016/S0967-0637(98)00070-3. Anchors: 0017. Suggested filename: munk1998-abyssal-recipes-ii-energetics-tidal-wind-mixing.pdf
- Relationship between wind speed and gas exchange over the ocean revisited -- Wanninkhof, R. (2014). Limnol. Oceanogr. Methods 12, 351-362. DOI: 10.4319/lom.2014.12.351. Anchors: 0017. Suggested filename: wanninkhof2014-relationship-wind-speed-gas-exchange-revisited.pdf
- The role of shortwave radiation in the summer decay of a sea ice cover -- Maykut, G. A., Perovich, D. K. (1987). J. Geophys. Res. 92(C7), 7032-7044. DOI: 10.1029/JC092iC07p07032. Anchors: 0017, REQ-OCN-011. Suggested filename: maykut1987-role-shortwave-radiation-summer-decay-sea-ice.pdf
- Turbulent heat flux in the upper ocean under sea ice -- McPhee, M. G. (1992). J. Geophys. Res. 97(C4), 5365-5379. DOI: 10.1029/92JC00239. Anchors: 0017, REQ-OCN-011. Suggested filename: mcphee1992-turbulent-heat-flux-upper-ocean-under-sea-ice.pdf
- Ocean pCO2 calculated from dissolved inorganic carbon, alkalinity, and equations for K1 and K2: validation based on laboratory measurements of CO2 in gas and seawater at equilibrium -- Lueker, T. J., Dickson, A. G., Keeling, C. D. (2000). Mar. Chem. 70, 105-119. DOI: 10.1016/S0304-4203(00)00022-0. Anchors: REQ-OCN-003. Suggested filename: lueker2000-ocean-pco2-calculated-dissolved-inorganic-carbon.pdf
- Carbon dioxide in water and seawater: the solubility of a non-ideal gas -- Weiss, R. F. (1974). Mar. Chem. 2, 203-215. DOI: 10.1016/0304-4203(74)90015-2. Anchors: REQ-OCN-003. Suggested filename: weiss1974-carbon-dioxide-water-seawater-solubility.pdf

### Terrain and hydrology (0015, 0019)

- A Simple Universal Equation for Grain Settling Velocity -- Ferguson, R. I., Church, M. (2004). J. Sediment. Res. 74(6), 933-937. DOI: 10.1306/051204740933. An open-access copy is listed at Durham Research Online (durham-repository.worktribe.com/output/1597463) behind a browser check that refuses an automated fetch. Anchors: 0015. Suggested filename: ferguson2004-simple-universal-equation-grain-settling-velocity.pdf
- Self-formed straight rivers with equilibrium banks and mobile bed. Part 2. The gravel river -- Parker, G. (1978). J. Fluid Mech. 89(1), 127-146. DOI: 10.1017/S0022112078002505. Anchors: 0015. Suggested filename: parker1978-self-formed-straight-rivers-part-2-gravel-river.pdf
- Open Channel Flow -- Henderson, F. M. (1966). Macmillan, New York, 522 pp. No DOI; ISBN 978-0-02-353790-5 (0-02-353790-6, Open Library record; the ISBN was assigned to the reprint). Any held fluid-mechanics text stating the Darcy-Weisbach open-channel form with g explicit may replace it (0019). Anchors: 0019. Suggested filename: henderson1966-open-channel-flow.pdf

### Biosphere and lakes (0018, 0021, REQ-BIO-006, -007, -015)

- Methanogenesis, fires and the regulation of atmospheric oxygen -- Watson, A. J., Lovelock, J. E., Margulis, L. (1978). BioSystems 10, 293-298. DOI: 10.1016/0303-2647(78)90012-6. The amendment cited 10.1016/0303-2647(78)90012-X, which does not resolve; the -6 suffix is the registered DOI for this title, first author and year. Anchors: REQ-BIO-015, 0021. Suggested filename: watson1978-methanogenesis-fires-regulation-atmospheric-oxygen.pdf
- An effective wind speed for models of fire spread -- Nelson, R. M., Jr. (2002). Int. J. Wildland Fire 11, 153-161. DOI: 10.1071/WF02031. Anchors: REQ-BIO-015. Suggested filename: nelson2002-effective-wind-speed-models-fire-spread.pdf
- Biochemical Models of Leaf Photosynthesis -- von Caemmerer, S. (2000). Techniques in Plant Sciences 2, CSIRO Publishing, Collingwood. DOI: 10.1071/9780643103405 (CSIRO monograph record); ISBN 978-0-643-06379-2 (0-643-06379-X). Anchors: REQ-BIO-007, 0021. Suggested filename: voncaemmerer2000-biochemical-models-leaf-photosynthesis.pdf
- Inhibition of nitrogenase-catalyzed reductions -- Hwang, J. C., Chen, C. H., Burris, R. H. (1973). Biochim. Biophys. Acta 292, 256-270. DOI: 10.1016/0005-2728(73)90270-3. Anchors: 0021, REQ-BIO-006. Suggested filename: hwang1973-inhibition-nitrogenase-catalyzed-reductions.pdf
- New formulation of eddy diffusion thermocline models -- Henderson-Sellers, B. (1985). Appl. Math. Modelling 9, 441-446. DOI: 10.1016/0307-904X(85)90110-6. Anchors: 0018. Suggested filename: hendersonsellers1985-new-formulation-eddy-diffusion-thermocline-models.pdf
