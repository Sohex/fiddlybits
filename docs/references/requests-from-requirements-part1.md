# Requests from requirement records, part 1

Triage of the first 101 primary sources cited by requirement records that a fuzzy title
match did not find in `INDEX.md`, `design-citations.md` or `REQUESTS.md`. Each line of the
input was checked by first-author surname and year, and by DOI where one was given,
against those three files and against the predecessor index at
`/home/cfutro/docs/world/references/INDEX.md` (with the PDF confirmed on disk under
`/home/cfutro/docs/world/references/pdf/`). Everything else was resolved against Crossref
by title and first author (DataCite for dataset and report DOIs; OpenLibrary for ISBNs).
No identifier below was taken from memory.

Counts: 101 input lines; 9 already indexed here; 33 held in the predecessor tree with a
PDF on disk; 59 to request, of which 1 is `to confirm` (no registered identifier found).

Filename convention and the `File as:` rule are those of `REQUESTS.md`. Titles are as
deposited with the registration agency, Unicode dashes and accents normalised to ASCII.


## Already indexed

- Long-Term Variations of Daily Insolation and Quaternary Climatic Changes (Berger 1978) -> `design-citations.md` line 129 (A4/F6) and `REQUESTS.md` line 114. Records: REQ-SYS-102.
- A parameterization of aerosol activation: 2. Multiple aerosol types (Abdul-Razzak and Ghan 2000) -> `design-citations.md` line 85 (B2) and `REQUESTS.md` line 77. Records: REQ-ATM-005.
- Present-day climate forcing and response from black carbon in snow (Flanner et al. 2007) -> `design-citations.md` line 190 (B4) and `REQUESTS.md` line 163. Records: REQ-ATM-011.
- Linking tree form, allocation and growth with an allometrically explicit model (King 2005) -> `INDEX.md` line 297, `king_2005_linking-tree-form-allocation-and-growth-with-an-allometrically-explici.pdf`, `10.1016/j.ecolmodel.2004.11.017`. Records: REQ-BIO-008.
- Chemical weathering rates of silicate-dominated lithological classes and associated liberation rates of phosphorus on the Japanese Archipelago - Implications for global scale analysis (Hartmann and Moosdorf 2011) -> `INDEX.md` line 382, `hartmann2011-japan-silicate-weathering-phosphorus.pdf`, `10.1016/j.chemgeo.2010.12.004`. Records: REQ-BIO-012, REQ-PED-010.
- Lightning chemistry on Earth-like exoplanets (Ardaseva et al. 2017) -> `INDEX.md` line 338, `ardaseva_2017_lightning-chemistry-on-earth-like-exoplanets.pdf`, `10.1093/mnras/stx1012`. Records: REQ-BIO-012.
- Geographic information systems, remote sensing and mapping for the development and management of marine aquaculture (Kapetsky and Aguilar-Manjarrez 2007) -> `design-citations.md` line 297 (B10) and `REQUESTS.md` line 245. Records: REQ-BIO-020.
- A global model for present-day atmospheric/soil CO2 consumption by chemical erosion of continental rocks (GEM-CO2) (Amiotte Suchet and Probst 1995) -> `INDEX.md` line 74, `amiottesuchet1995-gem-co2-lithology-weathering.pdf`, `10.3402/tellusb.v47i1-2.16047`. Records: REQ-PED-003.
- "Borate deposits: an overview and future forecast with regard to mineral deposits" (Helvaci 2019) -> `INDEX.md` line 109, `helvaci2019-turkish-borate-deposits.pdf`, `10.1007/978-3-030-02950-0_11`. The published title is "Turkish Borate Deposits: Geological Setting, Genesis and Overview of the Deposits" (in Pirajno et al., eds, Mineral Resources of Turkey, Modern Approaches in Solid Earth Sciences 16, 535-597); the record's title should be corrected to that. Records: REQ-PED-003.


## Held in the predecessor's tree

Format: title | old filename under `/home/cfutro/docs/world/references/pdf/` | DOI or locator | record ids. Identifiers are those of the old index row; the PDF was confirmed present on disk.

- The National Center for Atmospheric Research Community Climate Model: CCM3 | `kiehl1998-ccm3-description.pdf` | `10.1175/1520-0442(1998)011<1131:TNCFAR>2.0.CO;2` | REQ-ATM-004, REQ-SYS-101
- A Parameterization for the Absorption of Solar Radiation in the Earth's Atmosphere | `lacis1974-solar-absorption-parameterization.pdf` | `10.1175/1520-0469(1974)031<0118:APFTAO>2.0.CO;2` | REQ-ATM-002, REQ-ATM-003, REQ-SYS-005
- Description of the NCAR Community Climate Model (CCM3) | `kiehl1996-ccm3-technical-note.pdf` | `10.5065/D6FF3Q99` (NCAR/TN-420+STR) | REQ-ATM-004
- A Shortwave Parameterization Revised to Improve Cloud Absorption | `stephens1984-shortwave-parameterization-revised-to-improve-cloud-absorption.pdf` | `10.1175/1520-0469(1984)041<0687:ASPRTI>2.0.CO;2` | REQ-ATM-004
- In situ measurements of cloud microphysical and aerosol properties during the break-up of stratocumulus cloud layers in cold air outbreaks over the North Atlantic | `lloyd2018-cold-air-outbreak-stratocumulus.pdf` | `10.5194/acp-18-17191-2018` | REQ-ATM-004
- 3D simulations of photochemical hazes in the atmosphere of hot Jupiter HD 189733b | `stab1053.pdf` | `10.1093/mnras/stab1053` | REQ-ATM-006. The old index row (line 1200) carries a wrong title for this file ("Photochemical hazes in tidally locked sub-Neptunes/mini-Neptunes I", a different Steinrueck paper); the PDF's first page and Crossref both give the HD 189733b title for this DOI. Rename on copy to `steinrueck2021-3d-photochemical-hazes-hd189733b.pdf`.
- A decade of global volcanic SO2 emissions measured from space | `carn2017-volcanic-so2-from-space.pdf` | `10.1038/srep44095` | REQ-ATM-006
- A general model for the light-use efficiency of primary production | `haxeltine1996-light-use-efficiency.pdf` | `10.2307/2390165` | REQ-BIO-001, REQ-BIO-007
- Evaluation of ecosystem dynamics, plant geography and terrestrial carbon cycling in the LPJ dynamic global vegetation model | `sitch2003.pdf` | `10.1046/j.1365-2486.2003.00569.x` | REQ-BIO-001, REQ-BIO-002, REQ-BIO-004, REQ-BIO-005
- Stochastic simulation of daily precipitation, temperature, and solar radiation | `richardson_1981_stochastic-simulation-of-daily-precipitation-temperature-and-solar-rad.pdf` | `10.1029/WR017i001p00182` | REQ-BIO-002
- Terrestrial vegetation and water balance - hydrological evaluation of a dynamic global vegetation model | `gerten_2004_terrestrial-vegetation-and-water-balancehydrological-evaluation-of-a-d.pdf` | `10.1016/j.jhydrol.2003.09.029` | REQ-BIO-002
- A process-based, terrestrial biosphere model of ecosystem dynamics (Hybrid v3.0) | `friend1997-hybrid-v3-biosphere-model.pdf` | `10.1016/S0304-3800(96)00034-8` | REQ-BIO-007
- Representation of vegetation dynamics in the modelling of terrestrial ecosystems: comparing two contrasting approaches within European climate space | `smith_2001_representation-of-vegetation-dynamics-in-the-modelling-of-terrestrial.pdf` | `10.1046/j.1466-822x.2001.00256.x` | REQ-BIO-009
- Forest models defined by field measurements: I. The design of a northeastern forest simulator | `pacala1993.pdf` (a duplicate `pacala_1993_forest-models-defined-by-field-measurements-i-the-design-of-a-northeas.pdf` also exists) | `10.1139/x93-249` | REQ-BIO-009
- Projecting the future distribution of European potential natural vegetation zones with a generalized, tree species-based dynamic vegetation model | `hickler2011.pdf` (published 2012; rename on copy to `hickler2012-...`) | `10.1111/j.1466-8238.2010.00613.x` | REQ-BIO-009
- Implications of incorporating N cycling and N limitations on primary production in an individual-based dynamic vegetation model | `smith_2014_implications-of-incorporating-n-cycling-and-n-limitations-on-primary-p.pdf` | `10.5194/bg-11-2027-2014` | REQ-BIO-010
- Nutrient Cycling in Moist Tropical Forest | `vitousek1986-nutrient-cycling-moist-tropical-forest.pdf` | `10.1146/annurev.es.17.110186.001033` | REQ-BIO-012
- Impact of human population density on fire frequency at the global scale | `knorr_2014_impact-of-human-population-density-on-fire-frequency-at-the-global-sca.pdf` | `10.5194/bg-11-1085-2014` | REQ-BIO-015
- McArthur's fire-danger meters expressed as equations | `noble_1980_mcarthurs-fire-danger-meters-expressed-as-equations.pdf` | `10.1111/j.1442-9993.1980.tb01243.x` | REQ-BIO-016
- Tree mortality patterns following prescribed fires in a mixed conifer forest | `kobziar_2006_tree-mortality-patterns-following-prescribed-fires-in-a-mixed-conif.pdf` | `10.1139/x06-183` | REQ-BIO-016
- Optimising CH4 simulations from the LPJ-GUESS model v4.1 using an adaptive Markov chain Monte Carlo algorithm | `kallingal_2024_lpj-guess-methane-mcmc.pdf` | `10.5194/gmd-17-2299-2024` | REQ-BIO-017
- Process-based estimates of terrestrial ecosystem isoprene emissions: incorporating the effects of a direct CO2-isoprene interaction | `arneth2007-process-based-isoprene.pdf` | `10.5194/acp-7-31-2007` | REQ-BIO-018
- Process-based modelling of biogenic monoterpene emissions combining production and release from storage | `schurgers2009-process-based-monoterpene.pdf` | `10.5194/acp-9-3409-2009` | REQ-BIO-018
- Effect of climate-driven changes in species composition on regional emission capacities of biogenic compounds | `schurgers2011-species-composition-bvoc.pdf` | `10.1029/2011JD016278` | REQ-BIO-018
- The Model of Emissions of Gases and Aerosols from Nature version 2.1 (MEGAN2.1): an extended and updated framework for modeling biogenic emissions | `guenther2012-megan21.pdf` | `10.5194/gmd-5-1471-2012` | REQ-BIO-018
- Recent advances in understanding secondary organic aerosol: Implications for global climate forcing | `shrivastava2017-secondary-organic-aerosol.pdf` | `10.1002/2016RG000540` | REQ-BIO-018
- The AeroCom evaluation and intercomparison of organic aerosol in global models | `tsigaridis2014-aerocom-organic-aerosol.pdf` | `10.5194/acp-14-10845-2014` | REQ-BIO-018
- Ion-induced nucleation of pure biogenic particles | `kirkby2016-pure-biogenic-nucleation.pdf` | `10.1038/nature17953` | REQ-BIO-018
- Reduced anthropogenic aerosol radiative forcing caused by biogenic new particle formation | `gordon2016-biogenic-particle-formation.pdf` | `10.1073/pnas.1602360113` | REQ-BIO-018
- Large contribution of natural aerosols to uncertainty in indirect forcing | `carslaw2013-natural-aerosol-uncertainty.pdf` | `10.1038/nature12674` | REQ-BIO-018
- The impact of climate on the biogeochemical functioning of volcanic soils | `chadwick_2003_the-impact-of-climate-on-the-biogeochemical-functioning-of-volcanic-so.pdf` (Chadwick et al. 2003, confirming the "believed" DOI) | `10.1016/j.chemgeo.2002.09.001` | REQ-PED-001
- Influences of eolian and pedogenic processes on the origin and evolution of desert pavements | `mcfadden1987-desert-pavement-origin.pdf` | `10.1130/0091-7613(1987)15<504:IOEAPP>2.0.CO;2` | REQ-PED-001, REQ-PED-009
- Allophane and imogolite: role in soil biogeochemical processes | `parfitt_2009_allophane-and-imogolite-role-in-soil-biogeochemical-processes.pdf` | `10.1180/claymin.2009.044.1.135` | REQ-PED-006


## To request

Every DOI below was resolved directly against Crossref (DataCite for the two dataset and
report DOIs) and the returned title and first author matched. Where the deposited title
is the main title only, the cover subtitle is given after it.

### Atmosphere, radiation, snow optics and system defaults

- The Sensitivity of the ECMWF Model to the Parameterization of Evaporation from the Tropical Oceans -- Miller et al. (1992). DOI: 10.1175/1520-0442(1992)005<0418:TSOTEM>2.0.CO;2. Anchors: REQ-SYS-101. File as: `miller1992-sensitivity-ecmwf-evaporation-tropical-oceans.pdf`
- Wind stress on a water surface -- Charnock (1955). DOI: 10.1002/qj.49708135027. Anchors: REQ-SYS-101. File as: `charnock1955-wind-stress-on-a-water-surface.pdf`
- A parameterization scheme for non-convective condensation including prediction of cloud water content -- Sundqvist (1978). DOI: 10.1002/qj.49710444110. Anchors: REQ-SYS-104. File as: `sundqvist1978-non-convective-condensation-cloud-water.pdf`
- General Circulation Experiments with the Primitive Equations: I. The Basic Experiment -- Smagorinsky (1963). DOI: 10.1175/1520-0493(1963)091<0099:GCEWTP>2.3.CO;2. Anchors: REQ-SYS-104. Deposited in capitals as "GENERAL CIRCULATION EXPERIMENTS WITH THE PRIMITIVE EQUATIONS" with subtitle "I. THE BASIC EXPERIMENT"; Mon. Wea. Rev. 91(3), 99-164. File as: `smagorinsky1963-general-circulation-experiments-primitive-equations.pdf`
- Models of very-low-mass stars, brown dwarfs and exoplanets -- Allard et al. (2012). DOI: 10.1098/rsta.2011.0269. Anchors: REQ-ATM-001. File as: `allard2012-models-very-low-mass-stars-brown-dwarfs-exoplanets.pdf`
- The Radiative Cooling Calculation for Application to General Circulation Experiments -- Sasamori (1968). DOI: 10.1175/1520-0450(1968)007<0721:TRCCFA>2.0.CO;2. Anchors: REQ-ATM-003. File as: `sasamori1968-radiative-cooling-calculation-general-circulation.pdf`
- A GCM Parameterization for the Shortwave Radiative Properties of Water Clouds -- Slingo (1989). DOI: 10.1175/1520-0469(1989)046<1419:AGPFTS>2.0.CO;2. Anchors: REQ-ATM-004. File as: `slingo1989-gcm-parameterization-shortwave-water-clouds.pdf`
- The Influence of Pollution on the Shortwave Albedo of Clouds -- Twomey (1977). DOI: 10.1175/1520-0469(1977)034<1149:TIOPOT>2.0.CO;2. Anchors: REQ-ATM-005, REQ-ATM-013. File as: `twomey1977-influence-of-pollution-shortwave-albedo-clouds.pdf`
- Supersaturation of Water Vapor in Clouds -- Korolev and Mazin (2003). DOI: 10.1175/1520-0469(2003)060<2957:SOWVIC>2.0.CO;2. Anchors: REQ-ATM-005. File as: `korolev2003-supersaturation-of-water-vapor-in-clouds.pdf`
- A Model for the Spectral Albedo of Snow. I: Pure Snow -- Wiscombe and Warren (1980). DOI: 10.1175/1520-0469(1980)037<2712:AMFTSA>2.0.CO;2. Anchors: REQ-ATM-011, REQ-CRY-004. File as: `wiscombe1980a-spectral-albedo-of-snow-i-pure-snow.pdf` (suffix because `wiscombe1980-improved-mie-scattering-algorithms.pdf` is already requested)
- A Model for the Spectral Albedo of Snow. II: Snow Containing Atmospheric Aerosols -- Warren and Wiscombe (1980). DOI: 10.1175/1520-0469(1980)037<2734:AMFTSA>2.0.CO;2. Anchors: REQ-ATM-011. File as: `warren1980-spectral-albedo-of-snow-ii-atmospheric-aerosols.pdf`
- Optical constants of ice from the ultraviolet to the microwave: A revised compilation -- Warren and Brandt (2008). DOI: 10.1029/2007JD009744. Anchors: REQ-ATM-011. File as: `warren2008-optical-constants-of-ice-revised-compilation.pdf`
- A physical parameterization of snow albedo for use in climate models -- Marshall (1989). DOI: to confirm. NCAR Technical Note NCAR/TN-339+STR, National Center for Atmospheric Research, Boulder, Colorado, 1989. No DataCite record was found under the 10.5065 NCAR prefix by title or note number, and NCAR OpenSky could not be queried from here; the OpenSky record (which normally carries a 10.5065 DOI) is the locator to confirm. Anchors: REQ-ATM-011. File as: `marshall1989-physical-parameterization-snow-albedo-climate-models.pdf`
- The effect of solar radiation variations on the climate of the Earth -- Budyko (1969). DOI: 10.1111/j.2153-3490.1969.tb00466.x. Anchors: REQ-ATM-014. Tellus 21(5), 611-619; the Taylor and Francis alias 10.3402/tellusa.v21i5.10109 resolves to the same article. File as: `budyko1969-effect-of-solar-radiation-variations-climate-earth.pdf`
- Theory of Energy-Balance Climate Models -- North (1975). DOI: 10.1175/1520-0469(1975)032<2033:TOEBCM>2.0.CO;2. Anchors: REQ-ATM-014. File as: `north1975-theory-of-energy-balance-climate-models.pdf`
- Practical Markov Chain Monte Carlo -- Geyer (1992). DOI: 10.1214/ss/1177011137. Anchors: REQ-ATM-015, REQ-NUM-005. File as: `geyer1992-practical-markov-chain-monte-carlo.pdf`
- Robust Responses of the Hydrological Cycle to Global Warming -- Held and Soden (2006). DOI: 10.1175/JCLI3990.1. Anchors: REQ-ATM-016. File as: `held2006-robust-responses-hydrological-cycle-global-warming.pdf`

### Biosphere

- The action spectrum, absorptance and quantum yield of photosynthesis in crop plants -- McCree (1971). DOI: 10.1016/0002-1571(71)90022-7. Anchors: REQ-BIO-003. File as: `mccree1971-action-spectrum-absorptance-quantum-yield-photosynthesis.pdf`
- Frost Survival of Plants -- Sakai and Larcher (1987). DOI: 10.1007/978-3-642-71745-1. Anchors: REQ-BIO-004. Book, Ecological Studies 62, Springer; cover subtitle "Responses and Adaptation to Freezing Stress". File as: `sakai1987-frost-survival-of-plants.pdf`
- Benchmarking and parameter sensitivity of physiological and vegetation dynamics using the Functionally Assembled Terrestrial Ecosystem Simulator (FATES) at Barro Colorado Island, Panama -- Koven et al. (2020). DOI: 10.5194/bg-17-3017-2020. Anchors: REQ-BIO-005, REQ-BIO-009. File as: `koven2020-benchmarking-fates-barro-colorado-island.pdf`
- Next-generation dynamic global vegetation models: learning from community ecology -- Scheiter et al. (2013). DOI: 10.1111/nph.12210. Anchors: REQ-BIO-006. File as: `scheiter2013-next-generation-dgvms-community-ecology.pdf`
- The limits to tree height -- Koch et al. (2004). DOI: 10.1038/nature02417. Anchors: REQ-BIO-008. File as: `koch2004-the-limits-to-tree-height.pdf`
- Linking hydraulic traits to tropical forest function in a size-structured and trait-driven model (TFS v.1-Hydro) -- Christoffersen et al. (2016). DOI: 10.5194/gmd-9-4227-2016. Anchors: REQ-BIO-008. File as: `christoffersen2016-hydraulic-traits-tfs-v1-hydro.pdf`
- Modeling stomatal conductance in the earth system: linking leaf water-use efficiency and water transport along the soil-plant-atmosphere continuum -- Bonan et al. (2014). DOI: 10.5194/gmd-7-2193-2014. Anchors: REQ-BIO-008. File as: `bonan2014-modeling-stomatal-conductance-earth-system.pdf`
- A Method for Scaling Vegetation Dynamics: The Ecosystem Demography Model (ED) -- Moorcroft et al. (2001). DOI: 10.1890/0012-9615(2001)071[0557:AMFSVD]2.0.CO;2. Anchors: REQ-BIO-009. Deposited in capitals. File as: `moorcroft2001-scaling-vegetation-dynamics-ecosystem-demography.pdf`
- The fate of phosphorus during pedogenesis -- Walker and Syers (1976). DOI: 10.1016/0016-7061(76)90066-5. Anchors: REQ-BIO-010, REQ-BIO-012. File as: `walker1976-the-fate-of-phosphorus-during-pedogenesis.pdf`
- Global patterns of terrestrial biological nitrogen (N2) fixation in natural ecosystems -- Cleveland et al. (1999). DOI: 10.1029/1999GB900014. Anchors: REQ-BIO-012. File as: `cleveland1999-global-patterns-terrestrial-nitrogen-fixation.pdf`
- The generalization of 'Student's' problem when several different population variances are involved -- Welch (1947). DOI: 10.1093/biomet/34.1-2.28. Anchors: REQ-BIO-014. The JSTOR alias 10.2307/2332510 resolves to the same article. File as: `welch1947-generalization-of-students-problem.pdf`
- A comparison of the Two One-Sided Tests Procedure and the Power Approach for assessing the equivalence of average bioavailability -- Schuirmann (1987). DOI: 10.1007/BF01068419. Anchors: REQ-BIO-014. File as: `schuirmann1987-two-one-sided-tests-procedure.pdf`
- Bioequivalence trials, intersection-union tests and equivalence confidence sets -- Berger and Hsu (1996). DOI: 10.1214/ss/1032280304. Anchors: REQ-BIO-014. File as: `berger1996-bioequivalence-intersection-union-tests.pdf`
- A mathematical model for predicting fire spread in wildland fuels -- Rothermel (1972). DOI: 10.2737/INT-RP-115. Anchors: REQ-BIO-015. USDA Forest Service Research Paper INT-115, Intermountain Forest and Range Experiment Station, Ogden. File as: `rothermel1972-mathematical-model-fire-spread-wildland-fuels.pdf`
- The status and challenge of global fire modelling -- Hantson et al. (2016). DOI: 10.5194/bg-13-3359-2016. Anchors: REQ-BIO-015. File as: `hantson2016-status-and-challenge-of-global-fire-modelling.pdf`
- A Drought Index for Forest Fire Control -- Keetch and Byram (1968). no DOI. USDA Forest Service Research Paper SE-38, Southeastern Forest Experiment Station, Asheville; stable locator https://research.fs.usda.gov/treesearch/40 (resolves to this title and report number; no 10.2737 DOI is registered for it). Anchors: REQ-BIO-015. File as: `keetch1968-a-drought-index-for-forest-fire-control.pdf`
- Combustion of forest fuels -- Byram (1959). no DOI. Chapter in Davis, K. P. (ed.), Forest Fire: Control and Use, McGraw-Hill, New York, 1959, pp. 61-89; book locator LCCN 58011167, OCLC 978127. Anchors: REQ-BIO-016. File as: `byram1959-combustion-of-forest-fuels.pdf`
- Determination of biomass burning emission factors: Methods and results -- Delmas et al. (1995). DOI: 10.1007/BF00546762. Anchors: REQ-BIO-016. Environmental Monitoring and Assessment 38, 181-204 (the record's citation); the same text is also registered as a book chapter, 10.1007/978-94-009-1637-1_6. File as: `delmas1995-determination-biomass-burning-emission-factors.pdf`
- Modelling the role of agriculture for the 20th century global terrestrial carbon balance -- Bondeau et al. (2007). DOI: 10.1111/j.1365-2486.2006.01305.x. Anchors: REQ-BIO-020. Global Change Biology 13(3), 679-706. File as: `bondeau2007-role-of-agriculture-terrestrial-carbon-balance.pdf`
- Primary production required to sustain global fisheries -- Pauly and Christensen (1995). DOI: 10.1038/374255a0. Anchors: REQ-BIO-020. File as: `pauly1995-primary-production-required-sustain-global-fisheries.pdf`
- Photosynthesis and Fish Production in the Sea -- Ryther (1969). DOI: 10.1126/science.166.3901.72. Anchors: REQ-BIO-020. File as: `ryther1969-photosynthesis-and-fish-production-in-the-sea.pdf`
- Large-scale redistribution of maximum fisheries catch potential in the global ocean under climate change -- Cheung et al. (2010). DOI: 10.1111/j.1365-2486.2009.01995.x. Anchors: REQ-BIO-020. Global Change Biology 16(1), 24-35. File as: `cheung2010-redistribution-maximum-fisheries-catch-potential.pdf`
- Mapping the global potential for marine aquaculture -- Gentry et al. (2017). DOI: 10.1038/s41559-017-0257-9. Anchors: REQ-BIO-020. File as: `gentry2017-mapping-global-potential-marine-aquaculture.pdf`
- Global agro-ecological zone V4 - Model documentation -- Fischer et al. (2021). DOI: 10.4060/cb4744en. Anchors: REQ-BIO-020. FAO and IIASA, Rome; Crossref deposits no author list, the cover names Fischer, Nachtergaele, van Velthuizen, Chiozza, Franceschini, Henry, Muchoney and Tramberend. File as: `fischer2021-gaez-v4-model-documentation.pdf`

### Hydrology and terrain

- Global river hydrography and network routing: baseline data and new approaches to study the world's large river systems -- Lehner and Grill (2013). DOI: 10.1002/hyp.9740. Anchors: REQ-HYD-001, REQ-HYD-008, REQ-TER-018. File as: `lehner2013-global-river-hydrography-network-routing.pdf`
- Copernicus DEM -- European Space Agency (2022). DOI: 10.5270/ESA-c5d3d65. Anchors: REQ-HYD-001. Dataset record for the Copernicus DEM (GLO-30 and GLO-90), registered with Crossref as type dataset; the record's "believed" DOI is confirmed. Fetch the product handbook to which the record points; the data itself goes under the oracle registry. File as: `esa2022-copernicus-dem-product-handbook.pdf`
- Global Recharge Data Set Indicates Strengthened Groundwater Connection to Surface Fluxes -- Berghuijs et al. (2022). DOI: 10.1029/2022GL099010. Anchors: REQ-HYD-002. File as: `berghuijs2022-global-recharge-data-set-groundwater-connection.pdf`
- USGS Water Data for the Nation -- U.S. Geological Survey (1994). DOI: 10.5066/F7P55KJN. Anchors: REQ-HYD-002. The DataCite record for the National Water Information System (https://waterdata.usgs.gov/nwis), under which groundwater levels (parameter 72019) are served; a dataset record, not a paper. File as: `usgs1994-water-data-for-the-nation-nwis-record.pdf`
- Lithologic composition of the Earth's continental surfaces derived from a new digital map emphasizing riverine material transfer -- Durr et al. (2005). DOI: 10.1029/2005GB002515. Anchors: REQ-HYD-003, REQ-PED-004. File as: `durr2005-lithologic-composition-continental-surfaces.pdf`
- Incorporating water table dynamics in climate modeling: 1. Water table observations and equilibrium water table simulations -- Fan et al. (2007). DOI: 10.1029/2006JD008111. Anchors: REQ-HYD-004, REQ-HYD-005. File as: `fan2007-water-table-dynamics-climate-modeling-1.pdf`
- The Linear Complementarity Problem -- Cottle et al. (2009). DOI: 10.1137/1.9780898719000. Anchors: REQ-HYD-004. SIAM Classics in Applied Mathematics 60. File as: `cottle2009-the-linear-complementarity-problem.pdf`
- Development and validation of a global database of lakes, reservoirs and wetlands -- Lehner and Doll (2004). DOI: 10.1016/j.jhydrol.2004.03.028. Anchors: REQ-HYD-005, REQ-HYD-009. File as: `lehner2004-global-database-lakes-reservoirs-wetlands.pdf`
- Sur les fonctions convexes et les inegalites entre les valeurs moyennes -- Jensen (1906). DOI: 10.1007/BF02418571. Anchors: REQ-HYD-005, REQ-HYD-007, REQ-PED-002, REQ-TER-007, REQ-TER-008, REQ-TER-009, REQ-TER-014. Acta Mathematica 30, 175-193. File as: `jensen1906-sur-les-fonctions-convexes.pdf`
- Natural evaporation from open water, bare soil and grass -- Penman (1948). DOI: 10.1098/rspa.1948.0037. Anchors: REQ-HYD-007, REQ-SYS-005, REQ-TER-008. File as: `penman1948-natural-evaporation-open-water-bare-soil-grass.pdf`
- Evaporation into the Atmosphere -- Brutsaert (1982). DOI: 10.1007/978-94-017-1497-6. Anchors: REQ-HYD-007. Book, Springer; cover subtitle "Theory, History, and Applications". File as: `brutsaert1982-evaporation-into-the-atmosphere.pdf`
- COSMO Technical Report No. 11: Parameterization of Lakes in Numerical Weather Prediction. Description of a Lake Model -- Mironov (2008). DOI: 10.5676/DWD_pub/nwv/cosmo-tr_11. Anchors: REQ-HYD-010. DataCite record by the COSMO consortium and Deutscher Wetterdienst; the record's "pre-DOI" note is superseded. File as: `mironov2008-parameterization-of-lakes-nwp-lake-model.pdf`
- Simulation of lake evaporation with application to modeling lake level variations of Harney-Malheur Lake, Oregon -- Hostetler and Bartlein (1990). DOI: 10.1029/WR026i010p02603. Anchors: REQ-ATM-012, REQ-HYD-010. A second AGU DOI, 10.1029/90WR01240, resolves to the same article. File as: `hostetler1990-lake-evaporation-harney-malheur-lake.pdf`
- Solving Ordinary Differential Equations II -- Hairer and Wanner (1996). DOI: 10.1007/978-3-642-05221-7. Anchors: REQ-HYD-011. Book, Springer Series in Computational Mathematics 14, second revised edition; cover subtitle "Stiff and Differential-Algebraic Problems". File as: `hairer1996-solving-ordinary-differential-equations-ii.pdf`

### Pedology and weathering

- Worldwide distribution of continental rock lithology: Implications for the atmospheric/soil CO2 uptake by continental weathering and alkalinity river transport to the oceans -- Amiotte Suchet et al. (2003). DOI: 10.1029/2002GB001891. Anchors: REQ-PED-003, REQ-PED-011. File as: `amiottesuchet2003-worldwide-distribution-continental-rock-lithology.pdf`
- Aquatic Chemistry: Chemical Equilibria and Rates in Natural Waters -- Stumm and Morgan (1996). no DOI. Third edition, Wiley-Interscience, New York; ISBN 978-0-471-51185-4 (0-471-51185-4), confirmed against the OpenLibrary record. Anchors: REQ-PED-003. File as: `stumm1996-aquatic-chemistry-third-edition.pdf`
- Field studies of hillslope flow processes -- Dunne (1978). no DOI. Chapter in Kirkby, M. J. (ed.), Hillslope Hydrology, Wiley, Chichester, 1978, pp. 227-293; ISBN 978-0-471-99510-4 (0-471-99510-X) confirmed against the OpenLibrary record. The record's "0-471-99510-4" has a wrong check digit and should be corrected. Anchors: REQ-PED-005. File as: `dunne1978-field-studies-of-hillslope-flow-processes.pdf`
- Evaluation of environmental factors affecting yields of major dissolved ions of streams in the United States -- Peters (1984). DOI: 10.3133/wsp2228. Anchors: REQ-PED-005. U.S. Geological Survey Water-Supply Paper 2228; the record's "DOI to confirm" is resolved. File as: `peters1984-environmental-factors-yields-major-dissolved-ions.pdf`
