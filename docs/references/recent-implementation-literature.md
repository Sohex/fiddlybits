# Recent implementation literature (arXiv, 2023 to 2026)

A sweep of arXiv for papers that bear on the implementation side of decisions 0005, 0011,
0013, 0015, 0016, 0021 and 0029. The sweep was run against the arXiv API (metadata search
over `physics.ao-ph`, `physics.comp-ph`, `physics.geo-ph`, `cs.MS`, `cs.DC`, `math.NA`,
`astro-ph.EP` and neighbours) with web search used to locate titles the metadata search
missed. Every arXiv identifier below was resolved through the API's `id_list` endpoint and
the abstract read before the row was kept; title, first author, year of first version and
primary category are as the API returns them, with LaTeX markup left as deposited. Nothing
here is `read` in the sense of `README.md`: a row is a pointer to a paper worth opening, not
a number or a scheme taken from it.

Scope rule applied: a paper is kept only if it offers something an implementer of the
named decision would open it for (a scheme, a test case, a measured limit, a tool, a
protocol). Result papers about particular planets, retrieval codes, machine-learning
emulators and surveys of a code ecosystem were dropped unless the abstract named a
transferable method.

Staged copies: `/tmp/claude-1000/-home-cfutro-git-fiddlybits/a2ccfc38-65d3-4990-b354-fcf364fdacee/scratchpad/arxiv-staging/<arxivid>.pdf`.
The staging directory is session-scoped scratch; ingest into `references/pdf/` under the
naming convention of `README.md` is a separate step and has not been done.

Counts: 40 papers kept; 8 mesh and dynamical core, 9 GPU and portable kernels, 7 radiation
tables, 6 reproducibility, 4 vegetation and photosynthesis, 3 landscape evolution, 3
exoplanet intercomparison. Most Copernicus-journal (GMD, ESurf) papers on these topics never
reach arXiv, so this list is a complement to `design-citations.md`, not a replacement; the
notes at the end name the non-arXiv items the search surfaced.

## 1. Finite-volume cores on icosahedral and Voronoi grids, C-grid modes, local refinement

Bears on 0005 (one mesh, graded refinement) and 0013 (triangle C-grid core, checkerboard
mode, Hollingsworth check, fallback ladder).

| arXiv id | title | first author | year | category | what it offers the implementation | decision | staged file |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2309.12832 | Accuracy and stability analysis of horizontal discretizations used in unstructured grid ocean models | Fabricio Rodrigues Lapolli | 2023 | physics.flu-dyn | Side-by-side accuracy and inertia-gravity-wave analysis of the A-, B- and two C-grid (ICON triangle, MPAS hexagon) shallow-water operators on icosahedral meshes, which is the operator-level comparison the shallow-water gate has to reproduce. | 0013 | `lapolli2023-accuracy-and-stability-analysis-horizontal-discretizations.pdf` |
| 2605.16554 | A no-go theorem and its resolution for the discrete compressible barotropic Navier--Stokes equations | Peter Korn | 2026 | math.AP | Proves that on Delaunay-Voronoi meshes every density-independent mass matrix leaves an O(h^2) energy residual in the vector-invariant form for A-, B-, C- and D-grid staggerings, and that a density-weighted mass matrix restores exact energy; this is the energy-consistency condition behind the Hollingsworth check, stated as a theorem. | 0013 | `korn2026-theorem-and-its-resolution-for-the.pdf` |
| 2501.09752 | A vertical slice frontogenesis test case for compressible nonhydrostatic dynamical cores of atmospheric models | Hiroe Yamazaki | 2025 | math.NA | A quasi-2D compressible test that exercises frontogenesis on a workstation and compares advective against vector-invariant momentum forms, a cheap acceptance case for the non-hydrostatic solver of the fallback ladder. | 0013 | `yamazaki2025-vertical-slice-frontogenesis-test-case-for.pdf` |
| 2604.07103 | A new high-order finite-volume advection scheme on spherical Voronoi grids and a comparative study in a mimetic finite-volume moist shallow-water model | Luan F. Santos | 2026 | math.NA | k-exact high-order reconstruction for tracer advection on irregular spherical cells with locally refined regions, evaluated inside a mimetic moist shallow-water model; the tracer-transport half of the shallow-water gate on a non-uniform mesh. | 0005, 0013 | `santos2026-new-high-order-finite-volume-advection.pdf` |
| 2405.10505 | Local Time-Stepping for the Shallow Water Equations using CFL Optimized Forward-Backward Runge-Kutta Schemes | Jeremy R. Lilly | 2024 | math.NA | A local time-stepping scheme that keeps exact mass and absolute-vorticity conservation on the TRiSK C-grid discretisation across a highly variable-resolution mesh, which is what a graded refinement region needs if the fine level is not to set the global step. | 0005 | `lilly2024-local-time-stepping-for-the-shallow.pdf` |
| 2505.05624 | Stability analyses of divergence and vorticity damping on gnomonic cubed-sphere grids | Timothy C. Andrews | 2025 | math.NA | Von Neumann stability limits for divergence and vorticity damping coefficients as functions of cell area, aspect ratio and non-orthogonality; the same derivation gives the admissible damping inside a refinement transition ring and on the cubed-sphere fallback. | 0005, 0013 | `andrews2025-stability-analyses-divergence-and-vorticity-damping.pdf` |
| 2403.06844 | ExoCubed: A Riemann-Solver based Cubed-Sphere Dynamic Core for Planetary Atmospheres | Sihe Chen | 2024 | astro-ph.EP | A finite-volume Riemann-solver core with vertical implicit correction on an equiangular cubed sphere, validated on shallow-water through hot-Jupiter tests; the closest existing instance of the second fallback in the ladder. | 0013 | `chen2024-exocubed-riemann-solver-based-cubed-sphere.pdf` |
| 2402.19277 | The impact of the explicit representation of convection on the climate of a tidally locked planet in global stretched-mesh simulations | Denis E. Sergeev | 2024 | astro-ph.EP | A global non-hydrostatic model run with a stretched mesh refined to 4.7 km over the substellar region and parameterised convection switched off there; a measured example of what local refinement plus a non-hydrostatic solver buys, and of the mesh-stretching side effects to test for. | 0005, 0013 | `sergeev2024-the-impact-the-explicit-representation-convection.pdf` |

## 2. GPU dynamical cores and portable kernel frameworks

Bears on 0011 (portable kernel layer, CPU fallback, mixed precision by declaration) and,
through the reduction primitives, on 0029.

| arXiv id | title | first author | year | category | what it offers the implementation | decision | staged file |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2309.06662 | Oceananigans.jl: A Julia library that achieves breakthrough resolution, memory and energy efficiency in global ocean simulations | Simone Silvestri | 2023 | physics.ao-ph | Measured throughput, memory footprint and energy per simulated year of a from-scratch Julia finite-volume ocean on hundreds of GPUs; the existence proof and the benchmark scale for a Julia GPU-first fluid core. | 0011 | `silvestri2023-oceananigans-julia-library-that-achieves-breakthrough.pdf` |
| 2502.14148 | High-level, high-resolution ocean modeling at all scales with Oceananigans | Gregory L. Wagner | 2025 | physics.ao-ph | Design description of the same code: how a structured finite-volume algorithm, GPU kernels and a programmable user interface are layered, which is the architecture question 0011 answers for this project. | 0011 | `wagner2025-high-level-high-resolution-ocean-modeling.pdf` |
| 2603.18695 | High-Performance Portable GPU Primitives for Arbitrary Types and Operators in Julia | Emmanuel Pilliat | 2026 | cs.DC | Backend-agnostic scan, mapreduce and matrix-vector primitives (KernelForge.jl over KernelIntrinsics.jl) matching CUB on NVIDIA and running on AMD; a reference design for the project's own fixed-order segmented reductions. | 0011, 0029 | `pilliat2026-high-performance-portable-gpu-primitives-for.pdf` |
| 2507.16710 | AcceleratedKernels.jl: Cross-Architecture Parallel Algorithms from a Unified, Transpiled Codebase | Andrei-Leonard Nicusan | 2025 | cs.DC | Backend-agnostic parallel algorithms (reductions, sorting, CPU-GPU co-processing) in Julia targeting NVIDIA, AMD, Intel and Apple; a candidate for the segment-sort and reduction layer, to be checked for deterministic ordering before use. | 0011, 0029 | `nicusan2025-acceleratedkernels-cross-architecture-parallel-algorithms-from.pdf` |
| 2303.06195 | Evaluating performance and portability of high-level programming models: Julia, Python/Numba, and Kokkos on exascale nodes | William F. Godoy | 2023 | cs.DC | Measured CPU and GPU (AMD MI250X, NVIDIA A100) performance of naive Julia kernels against C/OpenMP, CUDA and HIP; the lower-bound-performance data point for choosing a Julia kernel layer over a vendor language. | 0011 | `godoy2023-evaluating-performance-and-portability-high-level.pdf` |
| 2404.08849 | Mixed-Precision Computing in the GRIST Dynamical Core for Weather and Climate Modelling | Siyuan Chen | 2024 | physics.ao-ph | Term-by-term precision sensitivity of an unstructured-mesh dynamical core: pressure-gradient and gravity terms stay double, advective terms go single, with measured runtime gains; a template for the per-kernel FP32 certification of 0011 and 0029. | 0011, 0029 | `chen2024-mixed-precision-computing-the-grist-dynamical.pdf` |
| 2608.21150 | Integrating a Python Dynamical core into ICON | Mauro Bianco | 2026 | cs.DC | The triangle-C-grid ICON core rewritten in a DSL and run on GPUs faster than the directive-based Fortran, with the integration and data-layout choices reported; the operational triangle core's own GPU path. | 0011, 0013 | `bianco2026-integrating-python-dynamical-core-into-icon.pdf` |
| 2511.02021 | Computing the Full Earth System at 1 km Resolution | Daniel Klocke | 2025 | physics.ao-ph | A coupled ICON run on thousands of GPUs with the heterogeneous CPU/GPU component placement and the code-separation choices that halved complexity while raising portability; the scaling ceiling of the same mesh family. | 0011, 0005 | `klocke2025-computing-the-full-earth-system-resolution.pdf` |
| 2608.01546 | FESOM2-JAX v1.0: a differentiable shadow of the ocean-sea-ice model FESOM2, cast onto GPUs | Nikolay V. Koldunov | 2026 | physics.ao-ph | An unstructured-mesh cell-vertex finite-volume ocean re-implemented in an array framework, verified kernel by kernel against the original and run from laptop to 256 GPUs; the kernel-by-kernel verification protocol is reusable regardless of language. | 0011, 0029 | `koldunov2026-fesom2-jax-differentiable-shadow-the-ocean.pdf` |

## 3. Correlated-k and line-by-line generation for declared compositions and spectra

Bears on 0016 (k-distribution built once per composition and spectrum from line data, gas
overlap, continuum and collision-induced absorption).

| arXiv id | title | first author | year | category | what it offers the implementation | decision | staged file |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2508.18049 | SpeCT: A state-of-the-art tool to calculate correlated-k tables and continua of CO$_2$-H$_2$O-N$_2$ gas mixtures | G. Chaverot | 2025 | astro-ph.EP | An open tool that builds correlated-k tables and continua for mixtures with updated far-wing chi factors, showing where summing single-species opacities fails; the direct model for the offline build step. | 0016 | `chaverot2025-spect-state-the-art-tool-calculate.pdf` |
| 2402.04329 | Modeling Atmospheric Lines By the Exoplanet Community (MALBEC) version 1.0: A CUISINES radiative transfer intercomparison project | Geronimo L. Villanueva | 2024 | astro-ph.EP | A radiative-transfer intercomparison protocol spanning hot Jupiters to temperate terrestrials with defined atmospheres and outputs; the reference cases against which generated line-by-line tables can be validated. | 0016 | `villanueva2024-modeling-atmospheric-lines-the-exoplanet-community.pdf` |
| 2311.00775 | Harnessing machine learning for accurate treatment of overlapping opacity species in general circulation models | Aaron David Schneider | 2023 | astro-ph.EP | Compares adaptive equivalent extinction, random overlap with resort-rebin and a learned mixer for combining per-species k-tables inside a GCM, with accuracy and cost; the gas-overlap choice of 0016 measured. | 0016 | `schneider2023-harnessing-machine-learning-for-accurate-treatment.pdf` |
| 2508.07072 | A tunable Monte Carlo method for mixing correlated-k opacities. PRAS: polynomial reconstruction and sampling | Elspeth K. H. Lee | 2025 | astro-ph.EP | A random-overlap mixing method with a tunable accuracy-cost knob via CDF fits and Monte Carlo convolution; an alternative to equivalent extinction when a declared composition makes overlap errors matter. | 0016 | `lee2025-tunable-monte-carlo-method-for-mixing.pdf` |
| 2406.03977 | PyExoCross: a Python program for generating spectra and cross-sections from molecular line lists | Jingxin Zhang | 2024 | astro-ph.IM | Cross-section generation from ExoMol, HITRAN and HITEMP line lists with several Voigt evaluation options tested for speed and accuracy; a reference for the line-by-line kernel and for the HITRAN parsing layer. | 0016 | `zhang2024-pyexocross-python-program-for-generating-spectra.pdf` |
| 2510.20870 | pyROX: Rapid Opacity X-sections | Sam de Regt | 2025 | astro-ph.IM | Molecular and atomic cross-sections plus collision-induced absorption from public line lists, parallelisable across a cluster; a second reference implementation to check the project's GPU line-by-line against. | 0016 | `regt2025-pyrox-rapid-opacity-sections.pdf` |
| 2506.09257 | Improved H2-He and H2-H2 Collision-Induced Absorption Models and Application to Outer-Planet Atmospheres | Glenn S. Orton | 2025 | astro-ph.EP | Ab initio rototranslational collision-induced absorption for H2-He and H2-H2 at 40 to 400 K with stated uncertainty; the sourced CIA input for a declared hydrogen-helium bulk gas. | 0016 | `orton2025-improved-and-collision-induced-absorption-models.pdf` |

## 4. Bitwise reproducibility, reductions and precision on GPUs

Bears on 0029 (fixed-order reductions, no atomics, ulp-ensemble envelope, counter-based
streams) and 0011 (compensated accumulation of reservoirs).

| arXiv id | title | first author | year | category | what it offers the implementation | decision | staged file |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2408.05148 | Impacts of floating-point non-associativity on reproducibility for HPC and deep learning applications | Sanjif Shanmugavelu | 2024 | cs.DC | Measures run-to-run variability of parallel reductions on modern GPUs and its effect on iterative codes and correctness tests; the empirical case for fixed-order reductions and the size of the effect the nightly oracle guards against. | 0029 | `shanmugavelu2024-impacts-floating-point-non-associativity-reproducibility.pdf` |
| 2510.09180 | RepDL: Bit-level Reproducible Deep Learning Training and Inference | Peichen Xie | 2025 | cs.LG | An open library that gets bitwise reproducibility across environments by enforcing correct rounding and order invariance in every reduction; the design pattern (order-invariant accumulation, no atomics) that 0029 requires. | 0029 | `xie2025-repdl-bit-level-reproducible-deep-learning.pdf` |
| 2505.18791 | Automatic Verification of Floating-Point Accumulation Networks | David K. Zhang | 2025 | math.NA | Computer-verified, bit-tight error bounds for compensated-summation and double-double networks, and a new faster double-double addition; verified bounds for the accumulators that hold ledgers and reservoirs. | 0029, 0011 | `zhang2025-automatic-verification-floating-point-accumulation-networks.pdf` |
| 2602.19452 | Dekker's floating point number system and compensated summation algorithms | Longfei Gao | 2026 | math.NA | Step-by-step error behaviour of compensated summation variants when addends are not known in advance, identifying the accuracy-limiting operation; guidance for choosing the reservoir accumulator under reduced working precision. | 0011, 0029 | `gao2026-dekker-floating-point-number-system-and.pdf` |
| 2603.11084 | Realizing Common Random Numbers: Event-Keyed Hashing for Causally Valid Stochastic Models | Vince Buffalo | 2026 | stat.ME | Argues that stateful generators tie draws to execution path and replaces them with hashing keyed on the modelled event; the same construction as 0029's streams keyed on (seed, support, cell, process, time index), with the causal argument written out. | 0029 | `buffalo2026-realizing-common-random-numbers-event-keyed.pdf` |
| 2505.01140 | Robustness and uncertainty of direct numerical simulation under the influence of rounding and noise | Martin Karp | 2025 | physics.flu-dyn | A perturbation methodology that compares reduced-precision rounding against injected white noise to measure divergence and statistical uncertainty in a chaotic flow; the closest published analogue of the ulp-ensemble envelope. | 0029, 0011 | `karp2025-robustness-and-uncertainty-direct-numerical-simulation.pdf` |

## 5. Trait-based vegetation and photosynthesis for generic stellar spectra

Bears on 0021 (strategy space filtered by the planet, pigment window as a declared and
bracketed property, photon flux integrated from the declared spectrum). No trait-based or
eco-evolutionary vegetation model paper of 2023 to 2026 was found on arXiv; that literature
publishes in Biogeosciences, GMD and bioRxiv, and the note below names one.

| arXiv id | title | first author | year | category | what it offers the implementation | decision | staged file |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2409.01746 | Impact of vegetation albedo on the habitability of Earth-like exoplanets | Erica Bisesi | 2024 | astro-ph.EP | Two competing vegetation types with an age stage coupled to a surface-temperature model across rocky-planet configurations, with the albedo feedback measured; a minimal working example of the vegetation-to-climate write path. | 0021 | `bisesi2024-impact-vegetation-albedo-the-habitability-earth.pdf` |
| 2606.24458 | An Agnostic Machine Learning Model of Photosynthetic Habitability | Callum Gray | 2026 | astro-ph.EP | A generalised photosynthesis model built from thermodynamics and redox chemistry, with optical properties and CO2 reduction rate optimised against stellar irradiance spectra rather than taken from Earth organisms; a way to derive the pigment window from the declared spectrum instead of bracketing it. | 0021 | `gray2026-agnostic-machine-learning-model-photosynthetic-habitability.pdf` |
| 2602.20789 | Photosynthetic exergy I. Thermodynamic limits for habitable-zone planets | Giovanni Covone | 2026 | astro-ph.EP | Exergy-based bounds on photosynthetic power and long-wavelength absorption cut-offs for FGK and M hosts; the physical ceiling that the bracketed pigment-window edge must sit inside. | 0021 | `covone2026-photosynthetic-exergy-thermodynamic-limits-for-habitable.pdf` |
| 2305.02067 | Photosynthesis Under a Red Sun: Predicting the absorption characteristics of an extraterrestrial light-harvesting antenna | Christopher D. P. Duffy | 2023 | astro-ph.EP | An antenna model optimised against stellar spectra from 2300 K to 5800 K predicting absorption characteristics; a second, independent derivation of the pigment window from the spectrum. | 0021 | `duffy2023-photosynthesis-under-red-sun-predicting-the.pdf` |

## 6. Landscape evolution, flow routing and stratigraphy

Bears on 0015 (implicit stream-power solve along receivers, hillslope diffusion as a
declared closure, stratigraphy per cell). GPU landscape-evolution work is published in
computer-graphics venues and Copernicus journals rather than arXiv; see the notes.

| arXiv id | title | first author | year | category | what it offers the implementation | decision | staged file |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2606.12800 | Massively parallel flow routing and drainage area determination | Wolfgang Bangerth | 2026 | math.NA | Parallel flow-routing and drainage-area algorithms that route 1.88 billion points in seconds on twelve thousand processes; the algorithmic basis for accumulation on the twelve-neighbour stencil without a sequential receiver walk. | 0015 | `bangerth2026-massively-parallel-flow-routing-and-drainage.pdf` |
| 2401.04113 | Self-similarity and vanishing diffusion in fluvial landscapes | Shashank Kumar Anand | 2023 | nlin.PS | Shows the stream-power plus diffusion model is self-similar in a channelisation index and that diffusion localises to ridge and valley loci as it vanishes; the scaling argument for declaring D a closure in the spacing rather than a constant. | 0015 | `anand2023-self-similarity-and-vanishing-diffusion-fluvial.pdf` |
| 2302.05272 | Stratigraphic forward modeling software package for research and education | Daniel Tetzlaff | 2023 | physics.geo-ph | An open stratigraphic forward model with concurrent alluvial, fluvial, turbiditic, carbonate, wave and tectonic processes and 3D-plus-time output; a reference for the per-cell cover-layer record (thickness, class, deposition age). | 0015 | `tetzlaff2023-stratigraphic-forward-modeling-software-package-for.pdf` |

## 7. Exoplanet model intercomparison since THAI

Bears on 0013 (dynamical-core test recipes and the deep versus quasi-hydrostatic question)
and on the oracle tiers that consume intercomparison protocols.

| arXiv id | title | first author | year | category | what it offers the implementation | decision | staged file |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2306.03614 | Simulations of idealised 3D atmospheric flows on terrestrial planets using LFRic-Atmosphere | Denis E. Sergeev | 2023 | astro-ph.EP | A non-hydrostatic cubed-sphere core run through the Held-Suarez, Menou-Rauscher and Merlis-Schneider tidally locked recipes with mass, angular-momentum and kinetic-energy conservation reported; the baroclinic-gate recipe list with published norms. | 0013 | `sergeev2023-simulations-idealised-atmospheric-flows-terrestrial-planets.pdf` |
| 2406.09275 | The CUISINES Framework for Conducting Exoplanet Model Intercomparison Projects, Version 1.0 | Linda E. Sohl | 2024 | astro-ph.EP | The community protocol for exoplanet model intercomparisons (experiment definition, output variables, comparison practice) adapted from CMIP practice; the format an external-reference oracle tier should emit. | 0013, 0016 | `sohl2024-the-cuisines-framework-for-conducting-exoplanet.pdf` |
| 2307.00935 | Examining NHD vs QHD in the GCM THOR with non-grey radiative transfer for the hot Jupiter regime | Pascal A. Noti | 2023 | astro-ph.EP | Deep non-hydrostatic against quasi-hydrostatic equation sets on an icosahedral GPU core across a parameter grid, with divergence at low gravity and high rotation rate; the measured regime boundary for the hydrostatic-limit validity check. | 0013 | `noti2023-examining-nhd-qhd-the-gcm-thor.pdf` |

## Notes on what the search surfaced outside arXiv

These have no arXiv identifier. Resolved through OpenAlex on 2026-09-08: the two GMD
papers, the FastFlow and terrain-authoring papers (HAL) and the bioRxiv trait-model
preprint were open access and are filed under `references/pdf/` with rows in
`INDEX.md`; the CliMA core paper is open access at JAMES (10.1029/2025MS005014) but
both the publisher and the ESS Open Archive block programmatic download, and the 2013
Ocean Modelling checkerboard paper is paywalled, so those two are on `REQUESTS.md`.

- GT4Py rewrite of the ICON dynamical core, Geoscientific Model Development 19 (2026),
  "Toward exascale climate modelling: a python DSL approach to ICON's (icosahedral
  non-hydrostatic) dynamical core (icon-exclaim v0.2.0)", and "Operational numerical
  weather prediction with ICON on GPUs (version 2024.10)", same journal and year. DOI: to
  confirm. Bears on 0011 and 0013.
- "The Climate Modeling Alliance Atmosphere Dynamical Core: Concepts, Numerics, and
  Scaling", Journal of Advances in Modeling Earth Systems (2026), first author Yatunin.
  DOI: to confirm. The Julia GPU atmosphere core (ClimaAtmos, ClimaCore). Bears on 0011.
- "SpeedyWeather.jl: Reinventing atmospheric general circulation models towards
  interactivity and extensibility", Journal of Open Source Software (2024), first author
  Kloewer. DOI: 10.21105/joss.06323 (as printed on the journal page; to confirm against
  Crossref). Spectral, so a reference arm under 0012, not a component; bears on 0011 for
  its grid abstraction and GPU work.
- "FastFlow: GPU Acceleration of Flow and Depression Routing for Landscape Simulation",
  Computer Graphics Forum 43 (2024), first author Jain. DOI: to confirm. O(log n) GPU flow
  routing and O(log^2 n) depression routing. Bears on 0015 and 0019.
- "Large-scale terrain authoring through interactive erosion simulation", ACM Transactions
  on Graphics (2023). DOI: to confirm. Parallel drainage-area approximation for the
  stream-power equation on GPUs. Bears on 0015.
- "Prediction in trait-based ecology: global simulations of specific leaf area using a
  trait-based dynamic vegetation model", bioRxiv (2025), the aDGVM2-LL model in which
  community trait distributions emerge from selection. Locator: bioRxiv
  10.1101/2025.04.14.648688 (to confirm). Bears on 0021.
- "Mitigating horizontal divergence 'checker-board' oscillations on unstructured triangular
  C-grids for nonlinear hydrostatic and nonhydrostatic flows", Ocean Modelling (2013), and
  "Inspection of hexagonal and triangular C-grid discretizations of the shallow water
  equations", Journal of Computational Physics (2011). Both pre-date the window and are
  not on arXiv; they are the primary sources for the checkerboard mode named in 0013 and
  should be requested with DOIs confirmed.
