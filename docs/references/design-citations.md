# Design citations

Every primary source the plan's design rests on, enumerated from Parts A to G of the plan at
`/home/cfutro/.claude/plans/this-is-an-intial-melodic-stallman.md`, grouped by subsystem. A row here is a
claim that the named decision, scheme, oracle or dataset cannot be trusted until the paper is held
and read; it is not a claim that the paper is held. Status is measured against the predecessor's
index at `/home/cfutro/git/vesper/references/INDEX.md` and the PDFs under
`/home/cfutro/git/vesper/references/pdf/`; anything marked `to request` is listed in `REQUESTS.md`.

Counts: 219 citations; 203 DOIs confirmed against Crossref by title, first author and year; 7 dataset DOIs
confirmed against DataCite; 9 pre-DOI or report works carrying a stable locator (`no DOI`), of which
2 carry a `to confirm` note on the locator itself; 25 held in the old index with a PDF on disk;
194 to request. Every identifier was resolved by the API, none by memory. Titles are as deposited
with the registration agency, with Unicode dashes and quotes normalised to ASCII; where a
title-search hit was a discussion-paper or a publisher alias DOI, the final published DOI was
resolved directly and is the one recorded.

The `held` status below is inherited from the old index and means only that a PDF exists on disk
there. Under this project's references discipline (plan Part G) a held row is an open exposure: it
moves to `read` only when someone here takes a number or a scheme from the paper and names the
anchor. Nothing here is `read` yet.


## Dynamical core and mesh (A1, A9, F5, M3)

| what it anchors (plan item) | verbatim title | authors, year | identifier | status |
|---|---|---|---|---|
| A9/B2 ICON hydrostatic core on the triangle C-grid, the reference formulation | The ICON-1.2 hydrostatic atmospheric dynamical core on triangular grids - Part 1: Formulation and performance of the baseline version | Wan et al. (2013) | DOI: 10.5194/gmd-6-735-2013 | to request |
| A9/F5 ICON non-hydrostatic core, the general formulation the hydrostatic solver is a limit of; ICON grid nesting | The ICON (ICOsahedral Non-hydrostatic) modelling framework of DWD and MPI-M: Description of the non-hydrostatic dynamical core | Zängl et al. (2015) | DOI: 10.1002/qj.2378 | to request |
| A9 TRiSK geostrophic-mode representation on arbitrary C-grids, comparison for the rejected hexagonal dual | Numerical representation of geostrophic modes on arbitrarily structured C-grids | Thuburn et al. (2009) | DOI: 10.1016/j.jcp.2009.08.006 | to request |
| A9 TRiSK energy and PV conserving C-grid scheme (MPAS), comparison | A unified approach to energy conservation and potential vorticity dynamics for arbitrarily-structured C-grids | Ringler et al. (2010) | DOI: 10.1016/j.jcp.2009.12.007 | to request |
| A9 MPAS atmosphere on centroidal Voronoi hexagons, comparison for the rejected hexagonal dual | A Multiscale Nonhydrostatic Atmospheric Model Using Centroidal Voronoi Tesselations and C-Grid Staggering | Skamarock et al. (2012) | DOI: 10.1175/mwr-d-11-00215.1 | to request |
| A9/M3 the Hollingsworth instability, a named acceptance item of the shallow-water gate | An internal symmetric computational instability | Hollingsworth et al. (1983) | DOI: 10.1002/qj.49710946012 | to request |
| A9 triangle versus hexagon C-grid shallow water, the checkerboard divergence mode analysis | Inspection of hexagonal and triangular C-grid discretizations of the shallow water equations | Gassmann (2011) | DOI: 10.1016/j.jcp.2011.01.014 | to request |
| A9 Hollingsworth analysis on the hexagonal C-grid and energetic consistency | A global hexagonal C-grid non-hydrostatic dynamical core (ICON-IAP) designed for energetic consistency | Gassmann (2013) | DOI: 10.1002/qj.1960 | to request |
| A9/M3 Hollingsworth-class instability of the vector-invariant form on C-grids | Numerical instabilities of vector-invariant momentum equations on rectangular C-grids | Bell et al. (2017) | DOI: 10.1002/qj.2950 | to request |
| A9/M3 instabilities of spherical shallow-water models at small equivalent depth, the Hollingsworth check on icosahedral grids | Numerical instabilities of spherical shallow-water models considering small equivalent depths | Peixoto et al. (2018) | DOI: 10.1002/qj.3191 | to request |
| A9 accuracy of mimetic finite-volume operators on geodesic grids | Accuracy analysis of mimetic finite volume operators on geodesic grids and a consistent alternative | Peixoto (2016) | DOI: 10.1016/j.jcp.2015.12.058 | to request |
| A9 Z-grid fallback: geostrophic adjustment properties of the Z-grid | Geostrophic Adjustment and the Finite-Difference Shallow-Water Equations | Randall (1994) | DOI: 10.1175/1520-0493(1994)122<1371:gaatfd>2.0.co;2 | to request |
| A1 icosahedral bisection discretisation of the sphere | Icosahedral Discretization of the Two-Sphere | Baumgardner and Frederickson (1985) | DOI: 10.1137/0722066 | to request |
| A1 divergence damping inside refinement transition rings | A Stability Analysis of Divergence Damping on a Latitude-Longitude Grid | Whitehead et al. (2011) | DOI: 10.1175/2011mwr3607.1 | to request |
| A1 two-way nesting of a global FV core, reflected-wave treatment at the refinement boundary | A Two-Way Nested Global-Regional Dynamical Core on the Cubed-Sphere Grid | Harris and Lin (2013) | DOI: 10.1175/mwr-d-11-00201.1 | to request |
| F5 deep-atmosphere quasi-hydrostatic equations with complete Coriolis force | Dynamically consistent, quasi-hydrostatic equations for global models with a complete representation of the Coriolis force | WHITE and BROMLEY (1995) | DOI: 10.1256/smsqj.52207 | to request |
| F5 the shallow/deep, hydrostatic/non-hydrostatic family the general formulation is drawn from | Consistent approximate models of the global atmosphere: shallow, deep, hydrostatic, quasi-hydrostatic and non-hydrostatic | White et al. (2005) | DOI: 10.1256/qj.04.49 | to request |
| C3/M3 shallow-water test suite | A standard test set for numerical approximations to the shallow water equations in spherical geometry | Williamson et al. (1992) | DOI: 10.1016/0021-9991(92)90060-c | to request |
| C3/M3 baroclinic wave test case | A baroclinic instability test case for atmospheric model dynamical cores | Jablonowski and Williamson (2006) | DOI: 10.1256/qj.06.12 | to request |
| C3/M3 Held-Suarez forcing and climatology band | A Proposal for the Intercomparison of the Dynamical Cores of Atmospheric General Circulation Models | Held and Suarez (1994) | DOI: 10.1175/1520-0477(1994)075<1825:apftio>2.0.co;2 | to request |
| C3/M3 DCMIP baroclinic wave for deep and shallow atmospheres | A proposed baroclinic wave test case for deep- and shallow-atmosphere dynamical cores | Ullrich et al. (2014) | DOI: 10.1002/qj.2241 | to request |
| C3/M3 DCMIP 2012 tracer transport test cases | Dynamical core model intercomparison project: Tracer transport test cases | Kent et al. (2014) | DOI: 10.1002/qj.2208 | to request |
| C3/M3 DCMIP 2012 test case definitions (small planet, orographic, baroclinic) | Dynamical Core Model Intercomparison Project (DCMIP) Test Case Document | Ullrich et al. (2012) | no DOI. Ullrich, Jablonowski, Kent, Lauritzen, Nair, Taylor (2012), DCMIP-2012 test case document v1.7, distributed by the DCMIP organisers; mirrored at https://github.com/ClimateGlobalChange/DCMIP2012 (to confirm the current mirror) | to request |
| C3/M3 DCMIP 2016 test cases and intercomparison spread | DCMIP2016: a review of non-hydrostatic dynamical core design and intercomparison of participating models | Ullrich et al. (2017) | DOI: 10.5194/gmd-10-4477-2017 | to request |
| C3/M3 small-planet framework for testing non-hydrostatic cores | A framework for testing global non-hydrostatic models | Wedi and Smolarkiewicz (2009) | DOI: 10.1002/qj.377 | to request |

## Numerics, precision and reproducibility (A6, A7, C3, C4, C6)

| what it anchors (plan item) | verbatim title | authors, year | identifier | status |
|---|---|---|---|---|
| C3 method of manufactured solutions for PDE convergence order | Code Verification by the Method of Manufactured Solutions | Roache (2002) | DOI: 10.1115/1.1436090 | to request |
| A6 counter-based RNG keyed on physical identity | Parallel random numbers: as easy as 1, 2, 3 | Salmon et al. (2011) | DOI: 10.1145/2063384.2063405 | to request |
| A7/C6 error bounds for recursive, pairwise and compensated summation; fixed-order reductions | The Accuracy of Floating Point Summation | Higham (1993) | DOI: 10.1137/0914050 | to request |
| A7 compensated summation for FP64 accumulators | Pracniques: further remarks on reducing truncation errors | Kahan (1965) | DOI: 10.1145/363707.363723 | to request |
| B9/C6 integrated autocorrelation time for the exit window standard error | Monte Carlo Methods in Statistical Mechanics: Foundations and New Algorithms | Sokal (1997) | DOI: 10.1007/978-1-4899-0319-8_6 | to request |
| B9/C1 serial-correlation-corrected tests of a mean for the distance report | Taking Serial Correlation into Account in Tests of the Mean | Zwiers and von Storch (1995) | DOI: 10.1175/1520-0442(1995)008<0336:tsciai>2.0.co;2 | to request |
| A8 the language; multiple dispatch on Field type parameters | Julia: A Fresh Approach to Numerical Computing | Bezanson et al. (2017) | DOI: 10.1137/141000671 | to request |
| A8 SpeedyWeather.jl, the independent reference arm for dynamical-core comparison | SpeedyWeather.jl: Reinventing atmospheric general circulation models towards interactivity and extensibility | Klöwer et al. (2024) | DOI: 10.21105/joss.06323 | to request |
| A8 Oceananigans, Field location typing and boundary conditions borrowed as ideas | Oceananigans.jl: Fast and friendly geophysical fluid dynamics on GPUs | Ramadhan et al. (2020) | DOI: 10.21105/joss.02018 | to request |

## Atmosphere radiation and column physics (B2, M4)

| what it anchors (plan item) | verbatim title | authors, year | identifier | status |
|---|---|---|---|---|
| B2 SOCRATES radiation code, the pipeline shape | Studies with a flexible new radiation code. I: Choosing a configuration for a large-scale model | Edwards and Slingo (1996) | DOI: 10.1002/qj.49712253107 | to request |
| B2 HITRAN2020 line list for the line-by-line generation | The HITRAN2020 molecular spectroscopic database | Gordon et al. (2022) | DOI: 10.1016/j.jqsrt.2021.107949 | to request |
| B2 MT_CKD continuum model | Development and recent evaluation of the MT_CKD model of continuum absorption | Mlawer et al. (2012) | DOI: 10.1098/rsta.2011.0295 | held in old index: mlawer2012-mt-ckd-continuum-absorption.pdf (read there) |
| B2 MT_CKD continuum, the current release inside HITRAN | The inclusion of the MT_CKD water vapor continuum model in the HITRAN molecular spectroscopic database | Mlawer et al. (2023) | DOI: 10.1016/j.jqsrt.2023.108645 | to request |
| B2 correlated-k distribution method | A description of the correlated k distribution method for modeling nongray gaseous absorption, thermal emission, and multiple scattering in vertically inhomogeneous atmospheres | Lacis and Oinas (1991) | DOI: 10.1029/90jd01945 | to request |
| B2 two-stream approximations, unified | Two-Stream Approximations to Radiative Transfer in Planetary Atmospheres: A Unified Description of Existing Methods and a New Improvement | Meador and Weaver (1980) | DOI: 10.1175/1520-0469(1980)037<0630:tsatrt>2.0.co;2 | to request |
| B2 two-stream multiple scattering solver for inhomogeneous atmospheres | Rapid calculation of radiative heating rates and photodissociation rates in inhomogeneous multiple scattering atmospheres | Toon et al. (1989) | DOI: 10.1029/jd094id13p16287 | to request |
| C3/M4 RFMIP line-by-line reference profiles | The Radiative Forcing Model Intercomparison Project (RFMIP): experimental protocol for CMIP6 | Pincus et al. (2016) | DOI: 10.5194/gmd-9-3447-2016 | to request |
| C3/M4 analytic grey radiative equilibrium for irradiated atmospheres | On the radiative equilibrium of irradiated planetary atmospheres | Guillot (2010) | DOI: 10.1051/0004-6361/200913396 | to request |
| B2 Mie scattering algorithm for cloud and aerosol optics regenerated per band | Improved Mie scattering algorithms | Wiscombe (1980) | DOI: 10.1364/ao.19.001505 | to request |
| B2 water cloud optical properties by effective radius, comparison for the Mie regeneration | An Accurate Parameterization of the Radiative Properties of Water Clouds Suitable for Use in Climate Models | Hu and Stamnes (1993) | DOI: 10.1175/1520-0442(1993)006<0728:aapotr>2.0.co;2 | to request |
| B2 ice cloud solar optical properties, comparison | An Accurate Parameterization of the Solar Radiative Properties of Cirrus Clouds for Climate Models | Fu (1996) | DOI: 10.1175/1520-0442(1996)009<2058:aapots>2.0.co;2 | to request |
| B2 effective radius from droplet number and LWC | The Measurement and Parameterization of Effective Radius of Droplets in Warm Stratocumulus Clouds | Martin et al. (1994) | DOI: 10.1175/1520-0469(1994)051<1823:tmapoe>2.0.co;2 | to request |
| B2 aerosol activation from dust and sea-salt tracers | A parameterization of aerosol activation: 2. Multiple aerosol types | Abdul-Razzak and Ghan (2000) | DOI: 10.1029/1999jd901161 | to request |
| B2 warm-rain autoconversion and accretion in single-moment microphysics | A New Cloud Physics Parameterization in a Large-Eddy Simulation Model of Marine Stratocumulus | Khairoutdinov and Kogan (2000) | DOI: 10.1175/1520-0493(2000)128<0229:ancppi>2.0.co;2 | to request |
| B2 sub-grid PDF condensation scheme | Subgrid-Scale Condensation in Models of Nonprecipitating Clouds | Sommeria and Deardorff (1977) | DOI: 10.1175/1520-0469(1977)034<0344:sscimo>2.0.co;2 | to request |
| B2 mass-flux convection with entrainment | A Comprehensive Mass Flux Scheme for Cumulus Parameterization in Large-Scale Models | Tiedtke (1989) | DOI: 10.1175/1520-0493(1989)117<1779:acmfsf>2.0.co;2 | to request |
| B2 CAPE closure for mass-flux convection | Sensitivity of climate simulations to the parameterization of cumulus convection in the Canadian climate centre general circulation model | Zhang and McFarlane (1995) | DOI: 10.1080/07055900.1995.9649539 | to request |
| B2 1.5-order TKE boundary-layer closure | Development of a turbulence closure model for geophysical fluid problems | Mellor and Yamada (1982) | DOI: 10.1029/rg020i004p00851 | to request |
| B2 TKE closure with the Bougeault-Lacarrere mixing length | Parameterization of Orography-Induced Turbulence in a Mesobeta--Scale Model | Bougeault and Lacarrere (1989) | DOI: 10.1175/1520-0493(1989)117<1872:pooiti>2.0.co;2 | to request |
| B2/B4 Monin-Obukhov flux-profile relations, bulk aerodynamic fluxes | Flux-Profile Relationships in the Atmospheric Surface Layer | Businger et al. (1971) | DOI: 10.1175/1520-0469(1971)028<0181:fprita>2.0.co;2 | to request |
| B2/B4 flux-profile relations, review | A review of flux-profile relationships | Dyer (1974) | DOI: 10.1007/bf00240838 | to request |
| B2/B4 Monin-Obukhov similarity, the surface layer | Osnovnye zakonomernosti turbulentnogo peremeshivaniya v prizemnom sloe atmosfery (Basic laws of turbulent mixing in the surface layer of the atmosphere) | Monin and Obukhov (1954) | no DOI. Trudy Geofizicheskogo Instituta, Akademiya Nauk SSSR 24(151), 163-187 (1954). English translation: Monin and Obukhov (1959), American Meteorological Society translation; ADS bibcode 1954TrGeo..24..163M | to request |
| B2 orographic drag from sub-grid variance | A new subgrid-scale orographic drag parametrization: Its formulation and testing | Lott and Miller (1997) | DOI: 10.1002/qj.49712353704 | to request |
| B2 sea-salt source function | A parameterization of sea-salt aerosol source function for sub- and super-micron particles | Gong (2003) | DOI: 10.1029/2003gb002079 | held in old index: gong2003-sea-salt-source-function.pdf (? there) |
| B2/B7 lightning frequency for lightning N fixation | A simple lightning parameterization for calculating global lightning distributions | Price and Rind (1992) | DOI: 10.1029/92jd00719 | to request |
| B2 Chapman ozone photochemistry driven by the declared UV | A theory of upper-atmospheric ozone | Chapman (1930) | no DOI. Memoirs of the Royal Meteorological Society 3(26), 103-125 (1930). Royal Meteorological Society archive; ADS bibcode 1930MRMS....3..103C | to request |
| B2 reflectance spectra per surface class for N-band albedo | The ASTER spectral library version 2.0 | Baldridge et al. (2009) | DOI: 10.1016/j.rse.2008.11.007 | held in old index: baldridge2009-aster-spectral-library-v2.pdf (? there) |
| B2 reflectance spectra per surface class, current library | The ECOSTRESS spectral library version 1.0 | Meerdink et al. (2019) | DOI: 10.1016/j.rse.2019.05.015 | held in old index: meerdink2019-ecostress-spectral-library-v1.pdf (? there) |

## Non-Earth and aquaplanet oracles (C1 tier 3, M4, M4b)

| what it anchors (plan item) | verbatim title | authors, year | identifier | status |
|---|---|---|---|---|
| C1/M4 aquaplanet experiment proposal | A standard test for AGCMs including their physical parametrizations: I: the proposal | Neale and Hoskins (2000) | DOI: 10.1006/asle.2000.0022 | to request |
| C1/M4 APE control simulation spread | The Aqua-Planet Experiment (APE): CONTROL SST Simulation | BLACKBURN et al. (2013) | DOI: 10.2151/jmsj.2013-a02 | to request |
| C1/M4 APE Atlas, the multi-model aquaplanet spread | The APE atlas | Williamson et al. (2012) | DOI: 10.5065/D6FF3QBR (DataCite) | to request |
| C1 THAI protocol | TRAPPIST-1 Habitable Atmosphere Intercomparison (THAI): motivations and protocol version 1.0 | Fauchez et al. (2020) | DOI: 10.5194/gmd-13-707-2020 | to request |
| C1 THAI dry cases inter-model spread | The TRAPPIST-1 Habitable Atmosphere Intercomparison (THAI). I. Dry Cases - The Fellowship of the GCMs | Turbet et al. (2022) | DOI: 10.3847/psj/ac6cf0 | to request |
| C1 THAI moist cases inter-model spread | The TRAPPIST-1 Habitable Atmosphere Intercomparison (THAI). II. Moist Cases - The Two Waterworlds | Sergeev et al. (2022) | DOI: 10.3847/psj/ac6cf2 | to request |
| C1 THAI synthesis | The TRAPPIST-1 Habitable Atmosphere Intercomparison (THAI). III. Simulated Observables - the Return of the Spectrum | Fauchez et al. (2022) | DOI: 10.3847/psj/ac6cf1 | to request |
| C1/M4b rotation, gravity, radius and flux sweeps | ATMOSPHERIC DYNAMICS OF TERRESTRIAL EXOPLANETS OVER A WIDE RANGE OF ORBITAL AND ATMOSPHERIC PARAMETERS | Kaspi and Showman (2015) | DOI: 10.1088/0004-637x/804/1/60 | to request |
| C1/M4b high-obliquity coupled climate | Climate at high-obliquity | Ferreira et al. (2014) | DOI: 10.1016/j.icarus.2014.09.015 | to request |
| C1/M4b obliquity sweep near the outer habitable-zone edge | Enhanced Habitability on High Obliquity Bodies near the Outer Edge of the Habitable Zone of Sun-like Stars | Colose et al. (2019) | DOI: 10.3847/1538-4357/ab4131 | to request |
| C1/M4b obliquity and eccentricity sweep | Climate of Earth-like planets with high obliquity and eccentric orbits: Implications for habitability conditions | Linsenmeier et al. (2015) | DOI: 10.1016/j.pss.2014.11.003 | to request |
| C1/M4b obliquity and irradiance multiple states | Multiple Climate States of Habitable Exoplanets: The Role of Obliquity and Irradiance | Kilic et al. (2017) | DOI: 10.3847/1538-4357/aa7a03 | to request |
| C1/M4b gravity sweep identities | The effects of gravity on the climate and circulation of a terrestrial planet | Thomson and Vallis (2019) | DOI: 10.1002/qj.3582 | to request |
| C1/M4b tidally locked cloud feedback | STABILIZING CLOUD FEEDBACK DRAMATICALLY EXPANDS THE HABITABLE ZONE OF TIDALLY LOCKED PLANETS | Yang et al. (2013) | DOI: 10.1088/2041-8205/771/2/l45 | to request |
| C1/M4b rotation-rate GCM intercomparison spread | Simulations of Water Vapor and Clouds on Rapidly Rotating and Tidally Locked Planets: A 3D Model Intercomparison | Yang et al. (2019) | DOI: 10.3847/1538-4357/ab09f1 | to request |

## System, star and constants (A0, A4, F6)

| what it anchors (plan item) | verbatim title | authors, year | identifier | status |
|---|---|---|---|---|
| A0 synthetic stellar spectra for any declared stellar type | A new extensive library of PHOENIX stellar atmospheres and synthetic spectra | Husser et al. (2013) | DOI: 10.1051/0004-6361/201219058 | to request |
| A0/C3 solar reference spectrum for the Earth instance | The TSIS-1 Hybrid Solar Reference Spectrum | Coddington et al. (2021) | DOI: 10.1029/2020gl091709 | to request |
| A0 stellar luminosity and radius from mass and age | New evolutionary models for pre-main sequence and main sequence low-mass stars down to the hydrogen-burning limit | Baraffe et al. (2015) | DOI: 10.1051/0004-6361/201425481 | to request |
| A4/F6 daily insolation from orbital elements, declination and epoch | Long-Term Variations of Daily Insolation and Quaternary Climatic Changes | Berger (1978) | DOI: 10.1175/1520-0469(1978)035<2362:ltvodi>2.0.co;2 | to request |
| A0 composition-derived planet radius | MASS-RADIUS RELATION FOR ROCKY PLANETS BASED ON PREM | Zeng et al. (2016) | DOI: 10.3847/0004-637x/819/2/127 | to request |
| F2 tidal locking timescale interface | Synchronous Locking of Tidally Evolving Satellites | Gladman et al. (1996) | DOI: 10.1006/icar.1996.0117 | to request |
| F2/B3 tidal dissipation in the deep ocean, the tidal mixing interface | Significant dissipation of tidal energy in the deep ocean inferred from satellite altimeter data | Egbert and Ray (2000) | DOI: 10.1038/35015531 | to request |
| A3 Sourced fundamental constants | CODATA Recommended Values of the Fundamental Physical Constants: 2018 | Tiesinga et al. (2021) | DOI: 10.1063/5.0064853 | to request |
| A3 nominal solar and planetary quantities for EarthRatios denominators | NOMINAL VALUES FOR SELECTED SOLAR AND PLANETARY QUANTITIES: IAU 2015 RESOLUTION B3 * † | Prša et al. (2016) | DOI: 10.3847/0004-6256/152/2/41 | to request |
| A3/A4 rotational elements and cartographic conventions | Report of the IAU Working Group on Cartographic Coordinates and Rotational Elements: 2015 | Archinal et al. (2018) | DOI: 10.1007/s10569-017-9805-5 | held in old index: archinal2018-iau-cartographic-coordinates-and-rotational-elements.pdf (read there) |

## Terrain and lithology (B1, M1)

| what it anchors (plan item) | verbatim title | authors, year | identifier | status |
|---|---|---|---|---|
| B1 implicit O(n) stream-power solver, the terrain reference | A very efficient O(n), implicit and parallel method to solve the stream power equation governing fluvial incision and landscape evolution | Braun and Willett (2013) | DOI: 10.1016/j.geomorph.2012.10.008 | to request |
| B1 stream power with sediment deposition | A New Efficient Method to Solve the Stream Power Law Model Taking Into Account Sediment Deposition | Yuan et al. (2019) | DOI: 10.1029/2018jf004867 | to request |
| B1/C3 stream-power dynamics, relief limits and response timescales | Dynamics of the stream-power river incision model: Implications for height limits of mountain ranges, landscape response timescales, and research needs | Whipple and Tucker (1999) | DOI: 10.1029/1999jb900120 | to request |
| B1 nonlinear hillslope diffusion closure with critical slope | Evidence for nonlinear, diffusive sediment transport on hillslopes and implications for landscape morphology | Roering et al. (1999) | DOI: 10.1029/1998wr900090 | to request |
| B1 glacial erosion law and exponent | Erosion by an Alpine glacier | Herman et al. (2015) | DOI: 10.1126/science.aab2386 | to request |
| B1/C3 Hack's law and longitudinal profiles | Studies of longitudinal stream profiles in Virginia and Maryland | Hack (1957) | DOI: 10.3133/pp294b | to request |
| M1 concavity oracle: stream gradient against drainage area | Stream gradient as a function of order, magnitude, and discharge | Flint (1974) | DOI: 10.1029/wr010i005p00969 | to request |
| M1 hypsometric integral oracle | HYPSOMETRIC (AREA-ALTITUDE) ANALYSIS OF EROSIONAL TOPOGRAPHY | STRAHLER (1952) | DOI: 10.1130/0016-7606(1952)63[1117:haaoet]2.0.co;2 | to request |
| M1 denudation-versus-relief oracle | Functional relationships between denudation, relief, and uplift in large, mid-latitude drainage basins | Ahnert (1970) | DOI: 10.2475/ajs.268.3.243 | to request |
| B1 strength-limited relief | Limits to Relief | Schmidt and Montgomery (1995) | DOI: 10.1126/science.270.5236.617 | to request |
| B1 erodibility contrast by rock strength | Sediment and rock strength controls on river incision into bedrock | Sklar and Dietrich (2001) | DOI: 10.1130/0091-7613(2001)029<1087:sarsco>2.0.co;2 | held in old index: sklar2001-rock-strength-river-incision.pdf (? there) |
| B1 flexural isostasy solver, comparison for the multigrid flexure | Open-source modular solutions for flexural isostasy: gFlex v1.0 | Wickert (2016) | DOI: 10.5194/gmd-9-997-2016 | to request |
| B1 thermal subsidence from seed age | An analysis of the variation of ocean floor bathymetry and heat flow with age | Parsons and Sclater (1977) | DOI: 10.1029/jb082i005p00803 | to request |
| B1 stretching model of rift subsidence from seed age | Some remarks on the development of sedimentary basins | McKenzie (1978) | DOI: 10.1016/0012-821x(78)90071-7 | to request |
| B1 vegetation effects on incision threshold and hillslope erodibility | Vegetation-modulated landscape evolution: Effects of vegetation on landscape processes, drainage density, and topography | Istanbulluoglu and Bras (2005) | DOI: 10.1029/2004jf000249 | to request |
| B1 root cohesion values by vegetation | The variability of root cohesion as an influence on shallow landslide susceptibility in the Oregon Coast Range | Schmidt et al. (2001) | DOI: 10.1139/t01-031 | to request |
| B1/B8 soil production function for the regolith clock | The soil production function and landscape equilibrium | Heimsath et al. (1997) | DOI: 10.1038/41056 | held in old index: heimsath_1997_the-soil-production-function-and-landscape-equilibrium.pdf (read there) |
| A1 multiple-flow-direction routing | Calculating catchment area with divergent flow based on a regular grid | Freeman (1991) | DOI: 10.1016/0098-3004(91)90048-i | to request |
| A1 multiple-flow-direction routing | The prediction of hillslope flow paths for distributed hydrological modelling using digital terrain models | Quinn et al. (1991) | DOI: 10.1002/hyp.3360050106 | to request |
| M1 denudation-rate database for the terrain oracle | OCTOPUS: an open cosmogenic isotope and luminescence database | Codilean et al. (2018) | DOI: 10.5194/essd-10-2123-2018 | to request |
| M1 global 10Be erosion-rate compilation | Understanding Earth's eroding surface with 10Be | Portenga and Bierman (2011) | DOI: 10.1130/g111a.1 | held in old index: portenga2011-10be-eroding-surface.pdf (read there) |

## Hydrology (B5, M2)

| what it anchors (plan item) | verbatim title | authors, year | identifier | status |
|---|---|---|---|---|
| B5 priority-flood depression filling | Priority-flood: An optimal depression-filling and watershed-labeling algorithm for digital elevation models | Barnes et al. (2014) | DOI: 10.1016/j.cageo.2013.04.024 | to request |
| B5 depression hierarchy | Computing water flow through complex landscapes - Part 2: Finding hierarchies in depressions and morphological segmentations | Barnes et al. (2020) | DOI: 10.5194/esurf-8-431-2020 | to request |
| B5 fill-spill-merge | Computing water flow through complex landscapes - Part 3: Fill-Spill-Merge: flow routing in depression hierarchies | Barnes et al. (2021) | DOI: 10.5194/esurf-9-105-2021 | to request |
| B5/M2 water-table depth skill bars | Global Patterns of Groundwater Table Depth | Fan et al. (2013) | DOI: 10.1126/science.1229881 | held in old index: fan_2013_global-patterns-of-groundwater-table-depth.pdf (read there) |
| B5 permeability by lithology for the water-table solve | Mapping permeability over the surface of the Earth | Gleeson et al. (2011) | DOI: 10.1029/2010gl045565 | held in old index: gleeson_2011_mapping-permeability-over-the-surface-of-the-earth.pdf (read there) |
| B4 TOPMODEL saturation-excess runoff (SIMTOP) | A simple TOPMODEL-based runoff parameterization (SIMTOP) for use in global climate models | Niu et al. (2005) | DOI: 10.1029/2005jd006111 | to request |
| B4/B5 TOPMODEL index | A physically based, variable contributing area model of basin hydrology / Un modèle à base physique de zone d'appel variable de l'hydrologie du bassin versant | BEVEN and KIRKBY (1979) | DOI: 10.1080/02626667909491834 | to request |
| M2 HydroLAKES equilibrium test | Estimating the volume and age of water stored in global lakes using a geo-statistical approach | Messager et al. (2016) | DOI: 10.1038/ncomms13603 | to request |
| C3 Dupuit unconfined-aquifer analytic oracle | Études théoriques et pratiques sur le mouvement des eaux dans les canaux découverts et à travers les terrains perméables | Dupuit (1863) | no DOI. Second edition, Dunod, Paris (1863). Digitised at Bibliothèque nationale de France, Gallica ark:/12148/bpt6k9764919z (to confirm the ark against the 2nd edition) | to request |
| M5 basin discharge to coasts oracle | Estimates of Freshwater Discharge from Continents: Latitudinal and Seasonal Variations | Dai and Trenberth (2002) | DOI: 10.1175/1525-7541(2002)003<0660:eofdfc>2.0.co;2 | to request |

## Land column, snow and lakes (B4, M5)

| what it anchors (plan item) | verbatim title | authors, year | identifier | status |
|---|---|---|---|---|
| B4/C3 mass-conservative Richards solver | A general mass-conservative numerical solution for the unsaturated flow equation | Celia et al. (1990) | DOI: 10.1029/wr026i007p01483 | to request |
| B4 Richards equation | CAPILLARY CONDUCTION OF LIQUIDS THROUGH POROUS MEDIUMS | Richards (1931) | DOI: 10.1063/1.1745010 | to request |
| B4 soil water retention closure | A Closed-form Equation for Predicting the Hydraulic Conductivity of Unsaturated Soils | van Genuchten (1980) | DOI: 10.2136/sssaj1980.03615995004400050002x | to request |
| B4 soil hydraulic parameters by texture, alternative closure | Empirical equations for some soil hydraulic properties | Clapp and Hornberger (1978) | DOI: 10.1029/wr014i004p00601 | to request |
| B4 CLM5 structure | The Community Land Model Version 5: Description of New Features, Benchmarking, and Impact of Forcing Uncertainty | Lawrence et al. (2019) | DOI: 10.1029/2018ms001583 | to request |
| B4 linear-theory orographic precipitation downscaling | A Linear Theory of Orographic Precipitation | Smith and Barstad (2004) | DOI: 10.1175/1520-0469(2004)061<1377:altoop>2.0.co;2 | to request |
| B4 snow compaction and energy balance | A point energy and mass balance model of a snow cover | Anderson (1976) | no DOI. NOAA Technical Report NWS 19, U.S. Department of Commerce, Silver Spring MD (1976). NOAA Institutional Repository https://repository.library.noaa.gov/view/noaa/6392 | to request |
| B4 prognostic snow grain size | Linking snowpack microphysics and albedo evolution | Flanner and Zender (2006) | DOI: 10.1029/2005jd006834 | to request |
| B4 SNICAR snow optics with impurities | Present-day climate forcing and response from black carbon in snow | Flanner et al. (2007) | DOI: 10.1029/2006jd008003 | to request |
| B4 SNICAR-ADv3, the current snow optics | SNICAR-ADv3: a community tool for modeling spectral snow albedo | Flanner et al. (2021) | DOI: 10.5194/gmd-14-7673-2021 | to request |
| B4 two-stream canopy radiation | Canopy reflectance, photosynthesis and transpiration | SELLERS (1985) | DOI: 10.1080/01431168508948283 | to request |
| B4 1-D lake model with ice | An improved lake model for climate simulations: Model structure, evaluation, and sensitivity analyses in CESM1 | Subin et al. (2012) | DOI: 10.1029/2011ms000072 | to request |
| C3/M6 Stefan problem analytic oracle for soil, lake and sea ice | Ueber die Theorie der Eisbildung, insbesondere über die Eisbildung im Polarmeere | Stefan (1891) | DOI: 10.1002/andp.18912780206 | to request |
| B4/B7 Medlyn stomatal conductance and g1 trait | Reconciling the optimal and empirical approaches to modelling stomatal conductance | MEDLYN et al. (2011) | DOI: 10.1111/j.1365-2486.2010.02375.x | to request |
| B4/B7/C3 Farquhar assimilation and A-Ci oracle | A biochemical model of photosynthetic CO2 assimilation in leaves of C3 species | Farquhar et al. (1980) | DOI: 10.1007/bf00386231 | to request |
| B7 Rubisco kinetics temperature response, the biology assumption | Improved temperature response functions for models of Rubisco-limited photosynthesis | Bernacchi et al. (2001) | DOI: 10.1111/j.1365-3040.2001.00668.x | to request |
| B7 photosynthetic temperature acclimation | Temperature acclimation in a biochemical model of photosynthesis: a reanalysis of data from 36 species | KATTGE and KNORR (2007) | DOI: 10.1111/j.1365-3040.2007.01690.x | to request |
| B7 C4 photosynthetic pathway | Coupled Photosynthesis-Stomatal Conductance Model for Leaves of C4 Plants | Collatz et al. (1992) | DOI: 10.1071/pp9920519 | to request |
| M5 site-level snow benchmarks | ESM-SnowMIP: assessing snow models and quantifying snow-related climate feedbacks | Krinner et al. (2018) | DOI: 10.5194/gmd-11-5027-2018 | to request |
| B4/B8 emitted dust size distribution | A scaling theory for the size distribution of emitted dust aerosols suggests climate models underestimate the size of the global dust cycle | Kok (2011) | DOI: 10.1073/pnas.1014798108 | held in old index: kok_2010_a-scaling-theory-for-the-size-distribution-of-emitted-dust-aerosols-su.pdf (read there) |
| B4/B8 dust emission on bare tiles | An improved dust emission model - Part 1: Model description and comparison against measurements | Kok et al. (2014) | DOI: 10.5194/acp-14-13023-2014 | held in old index: kok_2014_an-improved-dust-emission-model-part-1-model-description-and-compariso.pdf (read there) |
| B4/B8 soil-moisture threshold correction for dust emission | Parametrization of the increase of the aeolian erosion threshold wind friction velocity due to soil moisture for arid and semi-arid areas | Fécan et al. (1999) | DOI: 10.1007/s005850050744 | held in old index: fecan_1999_parametrization-of-the-increase-of-the-aeolian-erosion-threshold-wind.pdf (read there) |
| B4/B8 threshold friction velocity and dust emission scheme | Modeling the atmospheric dust cycle: 1. Design of a soil-derived dust emission scheme | Marticorena and Bergametti (1995) | DOI: 10.1029/95jd00690 | held in old index: marticorena_1995_modeling-the-atmospheric-dust-cycle-1-design-of-a-soilderived-dust-emi.pdf (read there) |
| B4/B8 threshold friction velocity expression | A simple expression for wind erosion threshold friction velocity | Shao and Lu (2000) | DOI: 10.1029/2000jd900304 | held in old index: shao2000-threshold-friction-velocity.pdf (read there) |
| M10 dust compilation range oracle | Global dust model intercomparison in AeroCom phase I | Huneeus et al. (2011) | DOI: 10.5194/acp-11-7781-2011 | to request |

## Cryosphere (B6, M10)

| what it anchors (plan item) | verbatim title | authors, year | identifier | status |
|---|---|---|---|---|
| B6/C3 exact isothermal ice-sheet solutions for verification | Exact solutions and verification of numerical models for isothermal ice sheets | Bueler et al. (2005) | DOI: 10.3189/172756505781829449 | to request |
| B6 PISM shallow-ice plus sliding formulation | Shallow shelf approximation as a "sliding law" in a thermomechanically coupled ice sheet model | Bueler and Brown (2009) | DOI: 10.1029/2008jf001179 | to request |
| B6/C3 Halfar dome exact solution | On the dynamics of the ice sheets | Halfar (1981) | DOI: 10.1029/jc086ic11p11065 | to request |
| B6/C3 Halfar dome exact solution in three dimensions | On the dynamics of the ice sheets 2 | Halfar (1983) | DOI: 10.1029/jc088ic10p06043 | to request |
| B6 area-volume scaling for sub-grid glacier stores | The physical basis of glacier volume-area scaling | Bahr et al. (1997) | DOI: 10.1029/97jb01696 | to request |
| B6 Glen's flow law | The creep of polycrystalline ice | Glen (1955) | DOI: 10.1098/rspa.1955.0066 | to request |
| B6 Weertman sliding | On the Sliding of Glaciers | Weertman (1957) | DOI: 10.3189/s0022143000024709 | to request |
| B6 ice material properties and the flow-law constants | The Physics of Glaciers | Cuffey and Paterson (2010) | no DOI. Cuffey, K. M. and Paterson, W. S. B. (2010), 4th edition, Butterworth-Heinemann/Elsevier, Oxford. ISBN 978-0-12-369461-4 | to request |
| M5/M10 RGI glacier inventory oracle | The Randolph Glacier Inventory: a globally complete inventory of glaciers | Pfeffer et al. (2014) | DOI: 10.3189/2014jog13j176 | to request |
| M5/M10 RGI 7.0 glacier outlines, the current inventory release | Randolph Glacier Inventory - A Dataset of Global Glacier Outlines, Version 7 | RGI Consortium (2023) | DOI: 10.5067/f6jmovy5navz (DataCite) | to request |

## Vegetation and biogeochemistry (B7, M9)

| what it anchors (plan item) | verbatim title | authors, year | identifier | status |
|---|---|---|---|---|
| B7 JeDi trait-based community model, the reference | The Jena Diversity-Dynamic Global Vegetation Model (JeDi-DGVM): a diverse approach to representing terrestrial biogeography and biogeochemistry based on plant functional trade-offs | Pavlick et al. (2013) | DOI: 10.5194/bg-10-4137-2013 | to request |
| B7 SPITFIRE fire | The influence of vegetation, fire spread and fire behaviour on biomass burning and trace gas emissions: results from a process-based model | Thonicke et al. (2010) | DOI: 10.5194/bg-7-1991-2010 | held in old index: thonicke_2010_the-influence-of-vegetation-fire-spread-and-fire-behaviour-on-biomass.pdf (read there) |
| B7 CENTURY soil organic matter pools | Analysis of Factors Controlling Soil Organic Matter Levels in Great Plains Grasslands | Parton et al. (1987) | DOI: 10.2136/sssaj1987.03615995005100050015x | to request |
| B7 CENTURY C-N-P-S dynamics | Dynamics of C, N, P and S in grassland soils: a model | Parton et al. (1988) | DOI: 10.1007/bf02180320 | held in old index: parton1988-century-c-n-p-s-grassland-model.pdf (read there) |
| B7 leaf economics trade-off (LMA, lifespan) | The worldwide leaf economics spectrum | Wright et al. (2004) | DOI: 10.1038/nature02403 | to request |
| B7 wood density trade-off | Towards a worldwide wood economics spectrum | Chave et al. (2009) | DOI: 10.1111/j.1461-0248.2009.01285.x | to request |
| B7 fast-slow plant economics trade-off coefficients | The world-wide 'fast-slow' plant economics spectrum: a traits manifesto | Reich (2014) | DOI: 10.1111/1365-2745.12211 | to request |
| B7 respiration temperature response | On the Temperature Dependence of Soil Respiration | Lloyd and Taylor (1994) | DOI: 10.2307/2389824 | to request |
| B7 wetland methane process model | A process-based, climate-sensitive model to derive methane emissions from natural wetlands: Application to five wetland sites, sensitivity to model parameters, and climate | Walter and Heimann (2000) | DOI: 10.1029/1999gb001204 | to request |
| B7 pigment window against the declared spectrum | The Peak Absorbance Wavelength of Photosynthetic Pigments Around Other Stars From Spectral Optimization | Lehmer et al. (2021) | DOI: 10.3389/fspas.2021.689441 | held in old index: lehmer2021-peak-absorbance-wavelength.pdf (read there) |
| B7 frost tolerance by tissue | Climatic Constraints Drive the Evolution of Low Temperature Resistance in Woody Plants | LARCHER (2005) | DOI: 10.2480/agrmet.61.189 | held in old index: larcher_2005_climatic-constraints-drive-the-evolution-of-low-temperature-resistance.pdf (read there) |
| M9 FLUXNET GPP oracle | The FLUXNET2015 dataset and the ONEFlux processing pipeline for eddy covariance data | Pastorello et al. (2020) | DOI: 10.1038/s41597-020-0534-3 | to request |
| M9 ILAMB benchmarking system | The International Land Model Benchmarking (ILAMB) System: Design, Theory, and Implementation | Collier et al. (2018) | DOI: 10.1029/2018ms001354 | to request |

## Pedology, weathering, brines and carbon (B8, M10)

| what it anchors (plan item) | verbatim title | authors, year | identifier | status |
|---|---|---|---|---|
| B8 kinetic mineral dissolution rate constants | A compilation of rate parameters of water-mineral interaction kinetics for application to geochemical modeling | Palandri and Kharaka (2004) | DOI: 10.3133/ofr20041068 | to request |
| B8 hydrologic control on weathering flux | Hydrologic Regulation of Chemical Weathering and the Geologic Carbon Cycle | Maher and Chamberlain (2014) | DOI: 10.1126/science.1250770 | to request |
| B8 water-balance threshold in soil pH | Water balance creates a threshold in soil pH at the global scale | Slessarev et al. (2016) | DOI: 10.1038/nature20139 | held in old index: slessarev2016-water-balance-threshold-in-soil-ph.pdf (read there) |
| B8 weathering and P release by lithology | Global chemical weathering and associated P-release - The role of lithology, temperature and soil properties | Hartmann et al. (2014) | DOI: 10.1016/j.chemgeo.2013.10.025 | held in old index: hartmann2014-weathering-phosphorus-release.pdf (read there) |
| B8 river dissolved loads by lithology, the comparison the kinetic approach is scored against | Global chemical weathering of surficial rocks estimated from river dissolved loads | Meybeck (1987) | DOI: 10.2475/ajs.287.5.401 | held in old index: meybeck1987-global-chemical-weathering.pdf (? there) |
| B8 Hardie-Eugster brine divide | The evolution of closed-basin brines | Hardie and Eugster (1970) | no DOI. Hardie, L. A. and Eugster, H. P. (1970), in Mineralogical Society of America Special Paper 3, 273-290. Mineralogical Society of America archive; GeoRef record | held in old index: MSA_SP3_273-290.pdf (? there) |
| B8 saline lake brine evolution | Saline Lakes | Eugster and Hardie (1978) | DOI: 10.1007/978-1-4757-1152-3_8 | to request |
| B8 laboratory versus field dissolution rates over exposure age | The effect of time on the weathering of silicate minerals: why do weathering rates differ in the laboratory and field? | White and Brantley (2003) | DOI: 10.1016/j.chemgeo.2003.03.001 | to request |
| B8/C3/M10 silicate weathering thermostat analytic | A negative feedback mechanism for the long-term stabilization of Earth's surface temperature | Walker et al. (1981) | DOI: 10.1029/jc086ic10p09776 | held in old index: walker1981-whak-thermostat.pdf (? there) |
| B8 carbonate-silicate cycle balance | The carbonate-silicate geochemical cycle and its effect on atmospheric carbon dioxide over the past 100 million years | Berner et al. (1983) | DOI: 10.2475/ajs.283.7.641 | to request |
| B8 weathering, pCO2 and climate review | Chemical Weathering, Atmospheric CO2, and Climate | Kump et al. (2000) | DOI: 10.1146/annurev.earth.28.1.611 | to request |
| B8 outgassing mass-scaling bracket | GEODYNAMICS AND RATE OF VOLCANISM ON MASSIVE EARTH-LIKE PLANETS | Kite et al. (2009) | DOI: 10.1088/0004-637x/700/2/1732 | held in old index: kite2009-volcanism-massive-earth-like-planets.pdf (read there) |

## Ocean, sea ice and marine ecosystem (B3, M6)

| what it anchors (plan item) | verbatim title | authors, year | identifier | status |
|---|---|---|---|---|
| B3 MPAS-Ocean multi-resolution ocean, the reference | A multi-resolution approach to global ocean modeling | Ringler et al. (2013) | DOI: 10.1016/j.ocemod.2013.04.010 | to request |
| B3 z* vertical coordinate | Rescaled height coordinates for accurate representation of free-surface flows in ocean circulation models | Adcroft and Campin (2004) | DOI: 10.1016/j.ocemod.2003.09.003 | to request |
| B3 partial bottom cells | Representation of Topography by Shaved Cells in a Height Coordinate Ocean Model | Adcroft et al. (1997) | DOI: 10.1175/1520-0493(1997)125<2293:rotbsc>2.0.co;2 | to request |
| B3 TEOS-10 equation of state | The international thermodynamic equation of seawater - 2010: Calculation and use of thermodynamic properties | IOC, SCOR and IAPSO (2010) | no DOI. Intergovernmental Oceanographic Commission, Manuals and Guides No. 56, UNESCO, 196 pp. (2010). https://www.teos-10.org/pubs/TEOS-10_Manual.pdf; UNESDOC record 000188170 | to request |
| B3 polynomial TEOS-10 density for the kernel | Accurate polynomial expressions for the density and specific volume of seawater using the TEOS-10 standard | Roquet et al. (2015) | DOI: 10.1016/j.ocemod.2015.04.002 | to request |
| B3 GM eddy parameterisation | Isopycnal Mixing in Ocean Circulation Models | Gent and Mcwilliams (1990) | DOI: 10.1175/1520-0485(1990)020<0150:imiocm>2.0.co;2 | to request |
| B3 Redi isopycnal diffusion | Oceanic Isopycnal Mixing by Coordinate Rotation | Redi (1982) | DOI: 10.1175/1520-0485(1982)012<1154:oimbcr>2.0.co;2 | to request |
| B3 KPP mixed layer | Oceanic vertical mixing: A review and a model with a nonlocal boundary layer parameterization | Large et al. (1994) | DOI: 10.1029/94rg01872 | to request |
| B3 TKE mixed layer alternative | A simple eddy kinetic energy model for simulations of the oceanic vertical mixing: Tests at station Papa and long-term upper ocean study site | Gaspar et al. (1990) | DOI: 10.1029/jc095ic09p16179 | to request |
| B3/F2 tidally driven deep mixing interface | Estimating tidally driven mixing in the deep ocean | St. Laurent et al. (2002) | DOI: 10.1029/2002gl015633 | to request |
| B3 accelerated deep spin-up | Accelerating the Convergence to Equilibrium of Ocean-Climate Models | Bryan (1984) | DOI: 10.1175/1520-0485(1984)014<0666:atcteo>2.0.co;2 | to request |
| F1 rotating hydraulic control of strait transport | Topographic control of oceanic flows in deep passages and straits | Whitehead (1998) | DOI: 10.1029/98rg01014 | to request |
| F1 the Isthmus of Panama closure as a connectivity event, the guiding case for the connectivity graph | Effect of the formation of the Isthmus of Panama on Atlantic Ocean thermohaline circulation | Haug and Tiedemann (1998) | DOI: 10.1038/31447 | to request |
| B3 three-layer sea ice thermodynamics | A Reformulated Three-Layer Sea Ice Model | Winton (2000) | DOI: 10.1175/1520-0426(2000)017<0525:artlsi>2.0.co;2 | to request |
| B3 sea ice drift with thickness-dependent strength | A Dynamic Thermodynamic Sea Ice Model | Hibler (1979) | DOI: 10.1175/1520-0485(1979)009<0815:adtsim>2.0.co;2 | to request |
| B3/B10 trait-based marine community, the reference | Emergent Biogeography of Microbial Communities in a Model Ocean | Follows et al. (2007) | DOI: 10.1126/science.1138544 | to request |
| B3 size-structured plankton food web | A size-structured food-web model for the global ocean | Ward et al. (2012) | DOI: 10.4319/lo.2012.57.6.1877 | to request |
| B3 spectral light in a marine ecosystem model, light under the declared spectrum | Capturing optically important constituents and properties in a marine biogeochemical and ecosystem model | Dutkiewicz et al. (2015) | DOI: 10.5194/bg-12-4447-2015 | to request |
| C3/M6 Stommel gyre analytic | The westward intensification of wind-driven ocean currents | Stommel (1948) | DOI: 10.1029/tr029i002p00202 | to request |
| C3/M6 Munk gyre analytic | ON THE WIND-DRIVEN OCEAN CIRCULATION | Munk (1950) | DOI: 10.1175/1520-0469(1950)007<0080:otwdoc>2.0.co;2 | to request |
| M6 meridional heat transport oracle | Estimates of Meridional Atmosphere and Ocean Heat Transports | Trenberth and Caron (2001) | DOI: 10.1175/1520-0442(2001)014<3433:eomaao>2.0.co;2 | to request |
| M6 WOA23 temperature climatology | World Ocean Atlas 2023, Volume 1: Temperature | Locarnini et al. (2024) | DOI: 10.25923/54bh-1613 (DataCite) | to request |
| M6 WOA23 salinity climatology | World Ocean Atlas 2023, Volume 2: Salinity | Reagan et al. (2024) | DOI: 10.25923/70qt-9574 (DataCite) | to request |
| M6 sea ice extent seasonal cycle oracle | Sea Ice Index, Version 3 | Fetterer, F.; Knowles K.; Meier W.; Savoie M.; Windnagel A. (2017) | DOI: 10.7265/N5K072F8 (DataCite) | to request |
| M6 marine NPP observational range | Photosynthetic rates derived from satellite-based chlorophyll concentration | Behrenfeld and Falkowski (1997) | DOI: 10.4319/lo.1997.42.1.0001 | to request |

## Managed biosphere (B10, F4, M11)

| what it anchors (plan item) | verbatim title | authors, year | identifier | status |
|---|---|---|---|---|
| B10 LPJmL4 managed land, the reference | LPJmL4 - a dynamic global vegetation model with managed land - Part 1: Model description | Schaphoff et al. (2018) | DOI: 10.5194/gmd-11-1343-2018 | to request |
| B10 LPJmL4 evaluation bars | LPJmL4 - a dynamic global vegetation model with managed land - Part 2: Model evaluation | Schaphoff et al. (2018) | DOI: 10.5194/gmd-11-1377-2018 | to request |
| M11 crop yield statistics as REPORT | Farming the planet: 2. Geographic distribution of crop areas, yields, physiological types, and net primary production in the year 2000 | Monfreda et al. (2008) | DOI: 10.1029/2007gb002947 | to request |
| B10 driven-mode land-use map | Farming the planet: 1. Geographic distribution of global agricultural lands in the year 2000 | Ramankutty et al. (2008) | DOI: 10.1029/2007gb002952 | to request |
| M11 fishery catch statistics as REPORT | Catch reconstructions reveal that global marine fisheries catches are higher than reported and declining | Pauly and Zeller (2016) | DOI: 10.1038/ncomms10244 | to request |
| B10 FAO aquaculture suitability method | Geographic information systems, remote sensing and mapping for the development and management of marine aquaculture | Kapetsky and Aguilar-Manjarrez (2007) | no DOI. Kapetsky, J. M. and Aguilar-Manjarrez, J. (2007), FAO Fisheries Technical Paper No. 458, FAO, Rome. ISBN 978-92-5-105646-1; https://www.fao.org/4/a1116e/a1116e.pdf | to request |

## Earth oracle datasets (C1 tier 2, M4, M6, M7)

| what it anchors (plan item) | verbatim title | authors, year | identifier | status |
|---|---|---|---|---|
| M4/M7 CERES EBAF TOA fluxes | Clouds and the Earth's Radiant Energy System (CERES) Energy Balanced and Filled (EBAF) Top-of-Atmosphere (TOA) Edition-4.0 Data Product | Loeb et al. (2018) | DOI: 10.1175/jcli-d-17-0208.1 | to request |
| M4/M7 CERES EBAF surface fluxes | Surface Irradiances of Edition 4.0 Clouds and the Earth's Radiant Energy System (CERES) Energy Balanced and Filled (EBAF) Data Product | Kato et al. (2018) | DOI: 10.1175/jcli-d-17-0523.1 | to request |
| M4/M7 ERA5 reanalysis | The ERA5 global reanalysis | Hersbach et al. (2020) | DOI: 10.1002/qj.3803 | to request |
| M4/M7 GPCP precipitation | The Global Precipitation Climatology Project (GPCP) Monthly Analysis (New Version 2.3) and a Review of 2017 Global Precipitation | Adler et al. (2018) | DOI: 10.3390/atmos9040138 | to request |
| M7 MODIS albedo product | First operational BRDF, albedo nadir reflectance products from MODIS | Schaaf et al. (2002) | DOI: 10.1016/s0034-4257(02)00091-3 | to request |
| M7 MODIS MCD43C3 v061 albedo CMG product (replaces the 500 m MCD43A3 request: the oracle scores coarse-cell class means, so the 0.05 degree CMG is the right support) | MODIS/Terra+Aqua BRDF/Albedo Model Parameters Daily L3 Global 0.05Deg CMG V061 | Schaaf and Wang (2021) | DOI: 10.5067/MODIS/MCD43C3.061 (DataCite) | to request (dataset) |
| M7 MODIS MCD12C1 v061 land cover CMG, the per-class key for the albedo oracle | MODIS/Terra+Aqua Land Cover Type Yearly L3 Global 0.05Deg CMG V061 | Friedl and Sulla-Menashe (2022) | DOI: 10.5067/MODIS/MCD12C1.061 (DataCite) | to request (dataset) |
| M5/M9 SoilGrids soil properties | SoilGrids 2.0: producing soil information for the globe with quantified spatial uncertainty | Poggio et al. (2021) | DOI: 10.5194/soil-7-217-2021 | to request |
| M1/M7 ETOPO 2022 global relief for the Earth hypsometry and bathymetry instance | ETOPO 2022 15 Arc-Second Global Relief Model | NOAA NCEI (2022) | DOI: 10.25921/fd45-gt74 (DataCite) | to request |
| M7 ECS assessment range | An Assessment of Earth's Climate Sensitivity Using Multiple Lines of Evidence | Sherwood et al. (2020) | DOI: 10.1029/2019rg000678 | to request |
