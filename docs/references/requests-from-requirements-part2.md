# Requests from requirement records, part 2

Triage of the 115 primary-source citations in requirement records that a fuzzy match
did not find in `INDEX.md`, `design-citations.md` or `REQUESTS.md` (input list
`refs-gap-part01`). Every line was re-checked by first-author surname and year, and
by DOI where one was given, against those three files and against the predecessor
index `/home/cfutro/docs/world/references/INDEX.md` (archived at commit
6aa93489d233d4e9d531d6479d338c643e34bc5e) and its `pdf/` directory. Every DOI below,
including those copied from the old index, was resolved against the Crossref API on
2026-09-08 and taken only where the returned title and first author match the
citation; titles are as Crossref returns them, with ASCII hyphens for the publisher's
en dashes. Pre-DOI works carry a stable locator and say `no DOI`.

Nineteen input lines (input lines 75 to 93) are not primary sources: they are the
predecessor's own audits, chapters and modules, cited by absolute path under
`/home/cfutro/docs/world/` (notes/audits/tuned-values.md, frozen-derived-quantities.md,
physics-review.md, missed-couplings.md, loop-exit-predicates.md,
pipeline-bookkeeping.md, derived-structure-audit.md, docs-restructure-audit.md;
docs/src/reference/design-intent.md, vocabulary.md, no-time-axis.md;
docs/src/pipeline/loops.md; docs/src/practice/conventions.md, working-agreements.md;
notes/external-tree-checklist.md, external-model-survey.md,
orchestration-frameworks.md; config/planet.yaml; lib/ module docstrings). They are
read in place and have no row in a references index; nothing to request.

Input line 94 (Secure Hash Standard, REQ-TER-002) is the same document as line 32
(FIPS PUB 180-4); the two are merged into one request below.

Counts: already indexed 4; held in the predecessor's tree 15; to request 76; `to
confirm` 0.

## Already indexed

- The evolution of closed-basin brines (Hardie and Eugster 1970) -> `design-citations.md` row "B8 Hardie-Eugster brine divide" (no DOI; MSA Special Paper 3, 273-290). The predecessor also holds it as `MSA_SP3_273-290.pdf` (old INDEX.md line 1034, held). Anchors to add: REQ-PED-008, REQ-TER-015.
- Fenske et al. (2025), duricrust formation as a water-table fluctuation model -> `INDEX.md` line 76, `fenske_2025_a-numerical-model-for-duricrust-formation-by-water-table-fluctuations.pdf`, `10.5194/esurf-13-119-2025`, held. Verbatim title: "A numerical model for duricrust formation by water table fluctuations". Anchor to add: REQ-PED-009.
- POSEIDON surface albedo database (Paragas et al. 2025) -> `INDEX.md` line 158, `poseidon_surface_albedo/Paragas2025-P25/` (identifier unverified; ApJ 981, 130), and line 422 (source-tree row). Anchor to add: REQ-TER-015.
- Density of rocks (Handbook of Physical Constants, GSA Memoir 97) -> `INDEX.md` line 62, `daly1966-density-of-rocks.pdf`, `10.1130/MEM97-p19`, read. Verbatim title: "Density of Rocks". Anchor to add: REQ-TER-015.

## Held in the predecessor's tree

Files are under `/home/cfutro/docs/world/references/pdf/` unless stated. Status on
arrival here is `held`; the old row's read claims are not carried.

| title | old filename | DOI or locator | record ids |
| --- | --- | --- | --- |
| Weathering sequence of soils from volcanic ash involving allophane and halloysite, New Zealand | `parfitt1983.pdf` | 10.1016/0016-7061(83)90029-0 | REQ-PED-006 |
| Contribution of Organic Matter and Clay to Soil Cation-Exchange Capacity as Affected by the pH of the Saturating Solution | `helling1964.pdf` | 10.2136/sssaj1964.03615995002800040020x | REQ-PED-006 |
| Predicting Cation-Exchange Capacity from Soil Physical and Chemical Properties | `manrique1991.pdf` | 10.2136/sssaj1991.03615995005500030026x | REQ-PED-006 |
| Allophane and halloysite content and soil solution silicon in soils from rhyolitic volcanic material, New Zealand (Singleton, McLeod, Percival 1989; the record gave no title) | `singleton1989.pdf` | 10.1071/SR9890067 | REQ-PED-006 |
| A Critical Evaluation of the Relationship Between the Effective Cation Exchange Capacity and Soil Organic Carbon Content in Swiss Forest Soils (Solly et al. 2020; the record gave no title) | `solly_2020_a-critical-evaluation-of-the-relationship-between-the-effective-cation.pdf` | 10.3389/ffgc.2020.00098 | REQ-PED-006 |
| Cosmogenic 3He surface-exposure dating of stone pavements: Implications for landscape evolution in deserts | `wells1995-cosmogenic-stone-pavements.pdf` | 10.1130/0091-7613(1995)023<0613:CHSEDO>2.3.CO;2 | REQ-PED-009 |
| The geologic records of dust in the Quaternary | `muhs2013-geologic-records-dust-quaternary.pdf` | 10.1016/j.aeolia.2012.08.001 | REQ-PED-009 |
| Distinguishing pedogenic and non-pedogenic silcretes in the landscape and geological record | `ullyott2016-pedogenic-nonpedogenic-silcretes.pdf` | 10.1016/j.pgeola.2016.03.001 | REQ-PED-009 |
| Palaeoenvironmental significance of palustrine carbonates and calcretes in the geological record | `alonsozarza2003-palustrine-carbonates-calcretes.pdf` | 10.1016/S0012-8252(02)00106-X | REQ-PED-009 |
| Uncertainties due to transport-parameter sensitivity in an efficient 3-D ocean-climate model | `edwards2005-goldstein-transport-parameter-sensitivity.pdf` | 10.1007/s00382-004-0508-8 | REQ-OCN-001, REQ-OCN-006 |
| PLASIM-GENIE v1.0: a new intermediate complexity AOGCM | `holden_2016_plasimgenie-v1-0-a-new-intermediate-complexity-aogcm.pdf` | 10.5194/gmd-9-3347-2016 | REQ-OCN-004, REQ-OCN-006, REQ-PROC-004, REQ-SYS-009 |
| Direct Absorption of Solar Radiation by Atmospheric Water Vapor, Carbon Dioxide and Molecular Oxygen | `yamamoto1962-direct-absorption-solar-radiation.pdf` | 10.1175/1520-0469(1962)019<0182:DAOSRB>2.0.CO;2 | REQ-SYS-005 |
| Infrared Transmission of Synthetic Atmospheres. III. Absorption by Water Vapor | `howard1956b-synthetic-atmospheres-iii-water-vapor.pdf` | 10.1364/JOSA.46.000242 | REQ-SYS-005 |
| A theory of glacial quarrying for landscape evolution models | `iverson_2012_a-theory-of-glacial-quarrying-for-landscape-evolution-models.pdf` (PDF on disk; no row in the old index) | 10.1130/G33079.1 | REQ-TER-013 |
| ESMF Regrid in-source documentation (conservative regridding, DSTAREA and FRACAREA normalisation, unmapped-destination policy) | `/home/cfutro/docs/world/references/esmf/` (source tree, not a PDF; `esmf-org/esmf` commit d8cb7c6c83b3154eeeaadede4676397904916293, old INDEX.md line 67) | no DOI. https://github.com/esmf-org/esmf at that commit; rendered manual https://earthsystemmodeling.org/docs/release/latest/ESMF_refdoc/ | REQ-PROC-003, REQ-SYS-009 |

## To request

- Hydraulic Properties of Porous Media -- Brooks and Corey (1964). no DOI. Colorado State University Hydrology Paper No. 3, Fort Collins; handle https://hdl.handle.net/10217/61288 (resolves to mountainscholar.org). Crossref holds only the authors' 1964 Transactions of the ASAE paper "Hydraulic Properties of Porous Media and Their Relation to Drainage Design" (10.13031/2013.40684), which is a different work. Anchors: REQ-PED-007. File as: `brooks1964-hydraulic-properties-of-porous-media.pdf`
- Direct observations of rock moisture, a hidden component of the hydrologic cycle -- Rempe and Dietrich (2018). DOI: 10.1073/pnas.1800141115. Anchors: REQ-PED-007. File as: `rempe2018-direct-observations-rock-moisture.pdf`
- Thermodynamics of electrolytes. I. Theoretical basis and general equations -- Pitzer (1973). DOI: 10.1021/j100621a026. Anchors: REQ-PED-008. File as: `pitzer1973-thermodynamics-of-electrolytes-i.pdf`
- Constraining climate sensitivity and continental versus seafloor weathering using an inverse geological carbon cycle model -- Krissansen-Totton and Catling (2017). DOI: 10.1038/ncomms15423. Anchors: REQ-PED-011. File as: `krissansentotton2017-constraining-climate-sensitivity-seafloor-weathering.pdf`
- IEEE Standard for Floating-Point Arithmetic -- IEEE (2019). DOI: 10.1109/IEEESTD.2019.8766229 (IEEE Std 754-2019). Anchors: REQ-NUM-001, REQ-NUM-003. File as: `ieee2019-standard-floating-point-arithmetic-754.pdf`
- What every computer scientist should know about floating-point arithmetic -- Goldberg (1991). DOI: 10.1145/103162.103163. Anchors: REQ-NUM-001, REQ-NUM-003, REQ-NUM-004. File as: `goldberg1991-what-every-computer-scientist-floating-point.pdf`
- Deterministic Nonperiodic Flow -- Lorenz (1963). DOI: 10.1175/1520-0469(1963)020<0130:DNF>2.0.CO;2. Anchors: REQ-NUM-001, REQ-NUM-002. File as: `lorenz1963-deterministic-nonperiodic-flow.pdf`
- A new ensemble-based consistency test for the Community Earth System Model (pyCECT v1.0) -- Baker et al. (2015). DOI: 10.5194/gmd-8-2829-2015. Anchors: REQ-NUM-002, REQ-PROV-001. File as: `baker2015-ensemble-based-consistency-test-cesm-pycect.pdf`
- Fast Reproducible Floating-Point Summation -- Demmel and Nguyen (2013). DOI: 10.1109/ARITH.2013.9. Anchors: REQ-NUM-002. File as: `demmel2013-fast-reproducible-floating-point-summation.pdf`
- Designing Bit-Reproducible Portable High-Performance Applications -- Arteaga et al. (2014). DOI: 10.1109/IPDPS.2014.127. Anchors: REQ-NUM-002. File as: `arteaga2014-designing-bit-reproducible-portable-applications.pdf`
- Handbook of Floating-Point Arithmetic -- Muller et al. (2018). DOI: 10.1007/978-3-319-76526-6 (second edition, Birkhauser). Anchors: REQ-NUM-003. File as: `muller2018-handbook-of-floating-point-arithmetic.pdf`
- Über die partiellen Differenzengleichungen der mathematischen Physik -- Courant et al. (1928). DOI: 10.1007/BF01448839. Anchors: REQ-NUM-005. File as: `courant1928-partiellen-differenzengleichungen-mathematischen-physik.pdf`
- Verification of Codes and Calculations -- Roache (1998). DOI: 10.2514/2.457. Anchors: REQ-NUM-005, REQ-TER-004. File as: `roache1998-verification-of-codes-and-calculations.pdf`
- Perspective: A Method for Uniform Reporting of Grid Refinement Studies -- Roache (1994). DOI: 10.1115/1.2910291. Anchors: REQ-NUM-005. File as: `roache1994-uniform-reporting-grid-refinement-studies.pdf`
- Statistical Analysis in Climate Research -- von Storch and Zwiers (1999). DOI: 10.1017/CBO9780511612336. Anchors: REQ-NUM-005. File as: `vonstorch1999-statistical-analysis-in-climate-research.pdf`
- Producing wrong data without doing anything obviously wrong! -- Mytkowicz et al. (2009). DOI: 10.1145/1508244.1508275. Anchors: REQ-NUM-006. File as: `mytkowicz2009-producing-wrong-data.pdf`
- Scientific benchmarking of parallel computing systems: twelve ways to tell the masses when reporting performance results -- Hoefler and Belli (2015). DOI: 10.1145/2807591.2807644 (Crossref carries the subtitle separately). Anchors: REQ-NUM-006. File as: `hoefler2015-scientific-benchmarking-parallel-computing-systems.pdf`
- Hints on Test Data Selection: Help for the Practicing Programmer -- DeMillo et al. (1978). DOI: 10.1109/C-M.1978.218136. Anchors: REQ-NUM-007, REQ-NUM-008. File as: `demillo1978-hints-on-test-data-selection.pdf`
- An Analysis and Survey of the Development of Mutation Testing -- Jia and Harman (2011). DOI: 10.1109/TSE.2010.62. Anchors: REQ-NUM-007, REQ-NUM-008. File as: `jia2011-analysis-and-survey-mutation-testing.pdf`
- Code coverage at Google -- Ivanković et al. (2019). DOI: 10.1145/3338906.3340459. Anchors: REQ-NUM-007. File as: `ivankovic2019-code-coverage-at-google.pdf`
- Secure Hash Standard (SHS) -- National Institute of Standards and Technology (2015). DOI: 10.6028/NIST.FIPS.180-4 (FIPS PUB 180-4). Anchors: REQ-PROV-001, REQ-PROV-002, REQ-PROV-003, REQ-TER-002. File as: `nist2015-fips-180-4-secure-hash-standard.pdf`
- A Digital Signature Based on a Conventional Encryption Function -- Merkle (1988). DOI: 10.1007/3-540-48184-2_32 (Advances in Cryptology, CRYPTO '87, LNCS 293; the proceedings volume is dated 1988). Anchors: REQ-PROV-002, REQ-PROV-003. File as: `merkle1988-digital-signature-conventional-encryption-function.pdf`
- Zarr core specification, version 3 -- Zarr Developers (living document). no DOI. https://zarr-specs.readthedocs.io/en/latest/v3/core/index.html (resolves; pin the spec version and fetch date when filing). Anchors: REQ-PROV-001, REQ-PROV-002, REQ-PROV-003. File as: `zarr-v3-core-specification.pdf`
- Atmospheric and Oceanic Fluid Dynamics: Fundamentals and Large-Scale Circulation -- Vallis (2017). DOI: 10.1017/9781107588417 (second edition). Anchors: REQ-OCN-001, REQ-OCN-002. File as: `vallis2017-atmospheric-and-oceanic-fluid-dynamics.pdf`
- Nonlinear Axially Symmetric Circulations in a Nearly Inviscid Atmosphere -- Held and Hou (1980). DOI: 10.1175/1520-0469(1980)037<0515:NASCIA>2.0.CO;2. Anchors: REQ-OCN-002. File as: `held1980-nonlinear-axially-symmetric-circulations.pdf`
- CO2 in seawater: Equilibrium, kinetics, isotopes -- Zeebe and Wolf-Gladrow (2001). DOI: 10.1016/S0422-9894(01)X8001-X (Elsevier Oceanography Series 65 book record; title matches, Crossref lists no author on the book-level record; ISBN 978-0-444-50579-8). Anchors: REQ-OCN-003. File as: `zeebe2001-co2-in-seawater-equilibrium-kinetics-isotopes.pdf`
- Thermodynamics of the carbon dioxide system in the oceans -- Millero (1995). DOI: 10.1016/0016-7037(94)00354-O. Anchors: REQ-OCN-003. File as: `millero1995-thermodynamics-carbon-dioxide-system-oceans.pdf`
- The global climatology of an interannually varying air-sea flux data set -- Large and Yeager (2009). DOI: 10.1007/s00382-008-0441-3 (Climate Dynamics 33, 341-364; Crossref dates the online record 2008). Anchors: REQ-OCN-004. File as: `large2009-global-climatology-interannually-varying-air-sea-flux.pdf`
- OMIP contribution to CMIP6: experimental and diagnostic protocol for the physical component of the Ocean Model Intercomparison Project -- Griffies et al. (2016). DOI: 10.5194/gmd-9-3231-2016. Anchors: REQ-OCN-004, REQ-OCN-005. File as: `griffies2016-omip-contribution-to-cmip6.pdf`
- Statistical Methods in the Atmospheric Sciences -- Wilks (2019). DOI: 10.1016/C2017-0-03921-6 (fourth edition, Elsevier; book-level record lists no author on Crossref; ISBN 978-0-12-815823-4). Anchors: REQ-OCN-005. File as: `wilks2019-statistical-methods-in-the-atmospheric-sciences.pdf`
- Constraints on dynamical transports of energy on a spherical planet -- Stone (1978). DOI: 10.1016/0377-0265(78)90006-4. Anchors: REQ-OCN-006. File as: `stone1978-constraints-dynamical-transports-energy-spherical-planet.pdf`
- The Partitioning of the Poleward Energy Transport between the Tropical Ocean and Atmosphere -- Held (2001). DOI: 10.1175/1520-0469(2001)058<0943:TPOTPE>2.0.CO;2. Anchors: REQ-OCN-006. File as: `held2001-partitioning-poleward-energy-transport.pdf`
- Heating Rate within the Upper Ocean in Relation to its Bio-optical State -- Morel and Antoine (1994). DOI: 10.1175/1520-0485(1994)024<1652:HRWTUO>2.0.CO;2. Anchors: REQ-OCN-007. File as: `morel1994-heating-rate-upper-ocean-bio-optical-state.pdf`
- Oceanic phytoplankton, atmospheric sulphur, cloud albedo and climate -- Charlson et al. (1987). DOI: 10.1038/326655a0. Anchors: REQ-OCN-007. File as: `charlson1987-oceanic-phytoplankton-atmospheric-sulphur-cloud-albedo.pdf`
- Ocean Biogeochemical Dynamics -- Sarmiento and Gruber (2006). DOI: 10.1515/9781400849079 (Princeton University Press). Anchors: REQ-OCN-007. File as: `sarmiento2006-ocean-biogeochemical-dynamics.pdf`
- Trait-Based Community Ecology of Phytoplankton -- Litchman and Klausmeier (2008). DOI: 10.1146/annurev.ecolsys.39.110707.173549. Anchors: REQ-OCN-008. File as: `litchman2008-trait-based-community-ecology-phytoplankton.pdf`
- Bio-optical properties of oceanic waters: A reappraisal -- Morel and Maritorena (2001). DOI: 10.1029/2000JC000319. Anchors: REQ-OCN-008, REQ-OCN-012. File as: `morel2001-bio-optical-properties-oceanic-waters-reappraisal.pdf`
- On the treatment of particulate organic matter sinking in large-scale models of marine biogeochemical cycles -- Kriest and Oschlies (2008). DOI: 10.5194/bg-5-55-2008. Anchors: REQ-OCN-008. File as: `kriest2008-particulate-organic-matter-sinking-large-scale-models.pdf`
- The biological control of chemical factors in the environment -- Redfield (1958). no DOI. American Scientist 46(3), 205-221; JSTOR stable URL https://www.jstor.org/stable/27827150 (resolves). Anchors: REQ-OCN-008. File as: `redfield1958-biological-control-of-chemical-factors.pdf`
- Rotating Hydraulics: Nonlinear Topographic Effects in the Ocean and Atmosphere -- Pratt and Whitehead (2008). DOI: 10.1007/978-0-387-49572-9 (Springer, Atmospheric and Oceanographic Sciences Library 36; Crossref dates the record 2007). Anchors: REQ-OCN-009. File as: `pratt2008-rotating-hydraulics.pdf`
- Representation of topography by porous barriers and objective interpolation of topographic data -- Adcroft (2013). DOI: 10.1016/j.ocemod.2013.03.002. Anchors: REQ-OCN-009. File as: `adcroft2013-topography-porous-barriers-objective-interpolation.pdf`
- First- and Second-Order Conservative Remapping Schemes for Grids in Spherical Coordinates -- Jones (1999). DOI: 10.1175/1520-0493(1999)127<2204:FASOCR>2.0.CO;2. Anchors: REQ-OCN-010, REQ-TER-001, REQ-TER-003, REQ-TER-005. File as: `jones1999-conservative-remapping-schemes-spherical-coordinates.pdf`
- Arbitrary-Order Conservative and Consistent Remapping and a Theory of Linear Maps: Part I -- Ullrich and Taylor (2015). DOI: 10.1175/MWR-D-14-00343.1. Anchors: REQ-OCN-010. File as: `ullrich2015-arbitrary-order-conservative-consistent-remapping-i.pdf`
- An Elastic-Viscous-Plastic Model for Sea Ice Dynamics -- Hunke and Dukowicz (1997). DOI: 10.1175/1520-0485(1997)027<1849:AEVPMF>2.0.CO;2. Anchors: REQ-OCN-011. File as: `hunke1997-elastic-viscous-plastic-model-sea-ice-dynamics.pdf`
- An energy-conserving thermodynamic model of sea ice -- Bitz and Lipscomb (1999). DOI: 10.1029/1999JC900100. Anchors: REQ-OCN-011. File as: `bitz1999-energy-conserving-thermodynamic-model-sea-ice.pdf`
- Measurement of the Roughness of the Sea Surface from Photographs of the Sun's Glitter -- Cox and Munk (1954). DOI: 10.1364/JOSA.44.000838. Anchors: REQ-OCN-012. File as: `cox1954-roughness-sea-surface-sun-glitter.pdf`
- Albedo of the Sea Surface -- Payne (1972). DOI: 10.1175/1520-0469(1972)029<0959:AOTSS>2.0.CO;2. Anchors: REQ-OCN-012. File as: `payne1972-albedo-of-the-sea-surface.pdf`
- A parameterization of ocean surface albedo -- Jin et al. (2004). DOI: 10.1029/2004GL021180 (Geophysical Research Letters 31, L22301, as the record cites; not the 2011 Optics Express paper of the same title). Anchors: REQ-OCN-012. File as: `jin2004-parameterization-of-ocean-surface-albedo.pdf`
- Absorption spectrum (380-700 nm) of pure water. II. Integrating cavity measurements -- Pope and Fry (1997). DOI: 10.1364/AO.36.008710. Anchors: REQ-OCN-012. File as: `pope1997-absorption-spectrum-pure-water-ii.pdf`
- Steady, Shallow Ice Sheets as Obstacle Problems: Well-Posedness and Finite Element Approximation -- Jouvet and Bueler (2012). DOI: 10.1137/110856654 (the record's wording "ice sheet as an obstacle problem" is not the published title). Anchors: REQ-CRY-001. File as: `jouvet2012-steady-shallow-ice-sheets-obstacle-problems.pdf`
- Dynamics of Ice Sheets and Glaciers -- Greve and Blatter (2009). DOI: 10.1007/978-3-642-03415-2. Anchors: REQ-CRY-001, REQ-CRY-002. File as: `greve2009-dynamics-of-ice-sheets-and-glaciers.pdf`
- An enthalpy formulation for glaciers and ice sheets -- Aschwanden et al. (2012). DOI: 10.3189/2012JoG11J088. Anchors: REQ-CRY-002. File as: `aschwanden2012-enthalpy-formulation-glaciers-ice-sheets.pdf`
- Glaciers and Climate Change -- Oerlemans (2001). no DOI for the 2001 A. A. Balkema edition; ISBN 978-90-265-1813-3 (Open Library record, Taylor and Francis, 2001). The 2026 Taylor and Francis reissue carries 10.1201/9781003760672. Anchors: REQ-CRY-003. File as: `oerlemans2001-glaciers-and-climate-change.pdf`
- Glacier melt: a review of processes and their modelling -- Hock (2005). DOI: 10.1191/0309133305pp453ra. Anchors: REQ-CRY-003. File as: `hock2005-glacier-melt-review-processes-modelling.pdf`
- Climate at the Equilibrium Line of Glaciers -- Ohmura et al. (1992). DOI: 10.3189/S0022143000002276. Anchors: REQ-CRY-003. File as: `ohmura1992-climate-at-the-equilibrium-line-of-glaciers.pdf`
- Optical properties of snow -- Warren (1982). DOI: 10.1029/RG020i001p00067. Anchors: REQ-CRY-004. File as: `warren1982-optical-properties-of-snow.pdf`
- The Optical Properties of Ice and Snow in the Arctic Basin -- Grenfell and Maykut (1977). DOI: 10.3189/S0022143000021122. Anchors: REQ-CRY-004. File as: `grenfell1977-optical-properties-ice-snow-arctic-basin.pdf`
- Inclusion of bedrock vadose zone in dynamic global vegetation models is key for simulating vegetation structure and function -- Lapides et al. (2024). DOI: 10.5194/bg-21-1801-2024. Anchors: REQ-SYS-006. File as: `lapides2024-bedrock-vadose-zone-dynamic-global-vegetation-models.pdf`
- Use of Reduced Gaussian Grids in Spectral Models -- Hortal and Simmons (1991). DOI: 10.1175/1520-0493(1991)119<1057:UORGGI>2.0.CO;2. Anchors: REQ-TER-002, REQ-TER-010. File as: `hortal1991-use-of-reduced-gaussian-grids-spectral-models.pdf`
- NetCDF Climate and Forecast (CF) Metadata Conventions -- Eaton et al. (2025). DOI: 10.5281/zenodo.17801666 (version 1.13, 2025-12-17; concept DOI for all versions 10.5281/zenodo.14274886). Anchors: REQ-TER-002, REQ-TER-010. File as: `eaton2025-cf-metadata-conventions-1-13.pdf`
- Verification and Validation in Scientific Computing -- Oberkampf and Roy (2010). DOI: 10.1017/CBO9780511760396. Anchors: REQ-TER-004, REQ-TER-006. File as: `oberkampf2010-verification-and-validation-scientific-computing.pdf`
- The preregistration revolution -- Nosek et al. (2018). DOI: 10.1073/pnas.1708274114. Anchors: REQ-TER-006. File as: `nosek2018-the-preregistration-revolution.pdf`
- Ein Beitrag zur Optik der Farbanstriche -- Kubelka and Munk (1931). no DOI. Zeitschrift fuer technische Physik 12, 593-601 (no Crossref record; `INDEX.md` line 242 cites the two-flux form only secondhand through Sadeghi et al. 2015). Anchors: REQ-TER-007. File as: `kubelka1931-ein-beitrag-zur-optik-der-farbanstriche.pdf`
- Modeling the land surface boundary in climate models as a composite of independent vegetation stands -- Koster and Suarez (1992). DOI: 10.1029/91JD01696. Anchors: REQ-TER-009, REQ-TER-012. File as: `koster1992-land-surface-boundary-composite-vegetation-stands.pdf`
- On the construction of the Voronoi mesh on a sphere -- Augenbaum and Peskin (1985). DOI: 10.1016/0021-9991(85)90140-8. Anchors: REQ-TER-011. File as: `augenbaum1985-construction-of-the-voronoi-mesh-on-a-sphere.pdf`
- Finite volume methods -- Eymard et al. (2000). DOI: 10.1016/S1570-8659(00)07005-8 (Handbook of Numerical Analysis 7, 713-1018). Anchors: REQ-TER-011. File as: `eymard2000-finite-volume-methods.pdf`
- Numerical Integration of the Shallow-Water Equations on a Twisted Icosahedral Grid. Part I: Basic Design and Results of Tests -- Heikes and Randall (1995). DOI: 10.1175/1520-0493(1995)123<1862:NIOTSW>2.0.CO;2. Anchors: REQ-TER-011. File as: `heikes1995-shallow-water-twisted-icosahedral-grid-i.pdf`
- III. On the computation of the effect of the attraction of mountain-masses, as disturbing the apparent astronomical latitude of stations in geodetic surveys -- Airy (1855). DOI: 10.1098/rstl.1855.0003 (Crossref returns Airy as author; the input line carried no author, and REQ-TER-013 cites it as Airy. Pratt's companion paper is 10.1098/rstl.1855.0002). Anchors: REQ-TER-013. File as: `airy1855-attraction-of-mountain-masses-geodetic-surveys.pdf`
- Geodynamics -- Turcotte and Schubert (2014). DOI: 10.1017/CBO9780511843877 (third edition). Anchors: REQ-TER-013. File as: `turcotte2014-geodynamics-third-edition.pdf`
- Monotone Piecewise Cubic Interpolation -- Fritsch and Carlson (1980). DOI: 10.1137/0717021. Anchors: REQ-TER-014. File as: `fritsch1980-monotone-piecewise-cubic-interpolation.pdf`
- Principles of geostatistics -- Matheron (1963). DOI: 10.2113/gsecongeo.58.8.1246. Anchors: REQ-TER-016. File as: `matheron1963-principles-of-geostatistics.pdf`
- Scaling, Universality, and Geomorphology -- Dodds and Rothman (2000). DOI: 10.1146/annurev.earth.28.1.571. Anchors: REQ-TER-016. File as: `dodds2000-scaling-universality-and-geomorphology.pdf`
- Copernicus DEM -- European Space Agency (2022). DOI: 10.5270/ESA-c5d3d65 (dataset record covering the GLO-30 and GLO-90 tile sets; the input title "Copernicus DEM - Global and European Digital Elevation Model" is the product page name). Anchors: REQ-TER-016. File as: `esa2022-copernicus-dem-product-handbook.pdf` (the dataset is not a PDF; file the product handbook linked from the DOI landing page)
- A new surface-processes model combining glacial and fluvial erosion -- Braun et al. (1999). DOI: 10.3189/172756499781821797. Anchors: REQ-TER-017. File as: `braun1999-surface-processes-model-glacial-fluvial-erosion.pdf`
- Glacial effects limiting mountain height -- Egholm et al. (2009). DOI: 10.1038/nature08263. Anchors: REQ-TER-017. File as: `egholm2009-glacial-effects-limiting-mountain-height.pdf`
- Magmatic Sulfide Deposits: Geology, Geochemistry and Exploration -- Naldrett (2004). DOI: 10.1007/978-3-662-08444-1 (Springer; the predecessor holds only Naldrett 2010, a different work, at `INDEX.md` line 93). Anchors: REQ-TER-018. File as: `naldrett2004-magmatic-sulfide-deposits.pdf`
