+++
epic = "fiddlybits-bon"
title = "Biogeochemistry and conceptual: PALEOtoolkit, JuliaOcean, OceanBioME, JuliaDynamics, CellularPotts.jl, Mimi.jl"
trees = [
  "/home/cfutro/git/PALEOtoolkit",
  "/home/cfutro/git/JuliaOcean",
  "/home/cfutro/git/OceanBioME",
  "/home/cfutro/git/JuliaDynamics",
  "/home/cfutro/git/CellularPotts.jl",
  "/home/cfutro/git/Mimi.jl",
]
status = "filed"
date = "2026-09-09"
+++

## What this group is

Six trees spanning deep-time biogeochemistry, ocean biogeochemistry and carbonate
chemistry, a large general-purpose nonlinear-dynamics organisation, one lattice-based
cellular model and one integrated-assessment framework. Ninety-eight repositories were
enumerated; five earn a closer look.

Three findings matter most. First, the two deep-time and marine biogeochemistry trees
this project would most expect to lean on both carry, in their working code, exactly
the Earth-fitted forms decision 0022 and decision 0017 named and fenced before this
survey read a line of their source: `LandCOPSEReloaded.jl`'s `ReactionLandWeatheringRates`
is the runoff-and-temperature silicate weathering law (its `f_runoff="original"` branch
literally reads `TEMP - 288.15`, Earth's own mean surface temperature, as the reference
point of the kinetic exponent), and both PALEOaqchem's `CO2SYS` reaction and OceanBioME's
`CarbonChemistry` compute boron, sulfate and fluoride as literal ratios to salinity
(`0.000232/10.811 * S/1.80655` and the like, the Dickson-table modern-seawater ratios).
Decision 0022 already refused the first form as the carbon balance's driver and kept it
only as a REPORT bracket; decision 0017 already refused ratio-to-salinity composition and
requires total boron, sulfate and fluoride `Derived` from the declared composition. The
audit that produced both decisions was right to distinguish these trees' method from
this project's, and reading the source confirms the distinction was not academic: it is
the majority code path in both packages.

Second, PALEOboxes' coupler is a genuinely different, and genuinely useful, comparison
for the single-process ownership model this project has chosen. It couples Domains by
standardised variable names across a YAML-declared reaction network rather than by
Fortran-style positional coupling, which is close in spirit to this project's naming
convention rule (0005: "conventions travel by name, never by coordinate") even though
PALEOboxes remains a multi-process, offline-transport-capable framework built to embed
in Fortran or C host models -- the opposite of this project's one-process, one-mesh
commitment (0009). The comparison is useful precisely because it shows how far
name-based coupling gets you without solving the ownership question this project solves
by declaring exactly one writer per exchanged quantity (0017, 0021, 0022, 0024 "Exchanges"
sections).

Third, the JuliaDynamics packages that matter for decision 0023's exit criteria are not
only the two the survey brief named. `Attractors.jl`'s basin-of-attraction, exit-basin
and tipping-point machinery is a plausible oracle for whether a coupled-loop trajectory
has actually reached an attracting state, but `TransitionsInTimeseries.jl` -- not named
in the brief -- is a closer structural match to the specific failure decision 0023 guards
against: it is a change-point / early-warning-signal package whose stated purpose is
exactly "must not declare convergence on a system that is merely wandering slowly" cast
as a timeseries-analysis problem rather than a dynamical-systems problem. Both are worth
a closer look; they answer different halves of the same question.

## Repository table

### PALEOtoolkit (13 repositories)

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| PALEOboxes.jl | the model coupler: Domains, standardised-name variable coupling, YAML-declared reaction networks | 0005, 0009, 0022 | algorithmic reference | later |
| PALEOcopse.jl | pure-Julia COPSE (Bergman 2004 / COPSE Reloaded 2018): Phanerozoic C-O-S-P cycle, weathering, land biota, ocean and sediment reservoirs | 0022 | algorithmic reference | now |
| PALEOaqchem.jl | aquatic biogeochemistry: organic matter remineralisation, generic reaction networks, `CO2SYS`-based carbonate chemistry | 0017, 0022 | algorithmic reference | now |
| PALEOocean.jl | catalog of ocean circulation representations (box models, transport-matrix GCM reductions), air-sea exchange, biological production, burial | 0017 | not pertinent -- box and transport-matrix circulation is a different method from the primitive-equation ocean of 0017, and its air-sea and burial parameterisations are downstream of the same composition and weathering assumptions already read in PALEOaqchem and PALEOcopse |
| PALEOsediment.jl | 1D sediment column reaction-transport, combined with PALEOaqchem and PALEOboxes | 0022 (burial) | not pertinent -- decision 0022's carbonate burial is a lysocline parameterisation, not a resolved sediment column; the diagenesis detail here is a finer grain than the declared scope |
| PALEOmodel.jl | numerical solvers and output structures for a standalone PALEOboxes model | - | not pertinent -- generic ODE/DAE solver and output tooling, no domain content |
| PALEOtutorials.jl | worked examples and Julia-workflow tutorials for the framework | - | not pertinent -- documentation only |
| cfortranapi | proof-of-concept C/Fortran host embedding for a PALEO model | - | not pertinent -- this project has no host-model embedding target |
| libSOCRATES_C_jll.jl | autogenerated binary package for the SOCRATES Fortran radiative-transfer library | - | not pertinent -- a binary JLL wrapper, not a biogeochemistry reference |
| NLsolve.jl | generic nonlinear-equation and mixed-complementarity solver, vendored here as a PALEO dependency | - | not pertinent -- surveyed properly under the sciml or gpu-and-arrays groups if adopted; not a biogeochemistry reference itself |
| SOCRATES.jl | Julia wrapper around the SOCRATES Fortran radiative-transfer code | - | not pertinent -- radiation belongs to the dycores-and-frameworks or orbits-and-stellar groups, not this one |
| SparsityTracing.jl | automatic Jacobian sparsity detection by scalar tracing | - | not pertinent -- numerical-infrastructure utility, superseded upstream by Symbolics.jl per its own README |
| PALEOtoolkit (org)/PALEOtutorials, .github | org metadata | - | not pertinent |

### JuliaOcean (14 repositories)

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| AIBECS.jl | steady-state marine biogeochemistry: `Tx = G(x)` solved by nonlinear/implicit methods against precomputed offline circulation matrices (OCIM, OCCA) | 0017, 0022, 0026 | oracle arm | later |
| AirSeaFluxes.jl | air-sea flux computation and analysis, early development | 0017 | not pertinent -- a thin, early-stage utility layer; its gas-transfer forms are the same family already read in OceanBioME and would be redundant to re-read |
| ArgoData.jl | Argo float data processing | - | not pertinent -- observational data tooling |
| Climatology.jl | downloading, reading and visualising gridded ocean state estimates | - | not pertinent -- data-access tooling, not a model |
| JuliaOceanSciencesMeeting2020 | conference workshop material | - | not pertinent |
| MarineEcosystemNotebooks | teaching notebooks using marine ecosystem models and ocean-colour data | - | not pertinent -- notebooks, not a model implementation |
| MarineEcosystemsJuliaCon2021.jl | conference workshop material | - | not pertinent |
| meta | organisational discussion repository | - | not pertinent |
| OceanColorData.jl | ocean-colour data processing, early development | - | not pertinent -- data tooling |
| OceanDistributions.jl | probabilistic and geographic analysis of ocean distributions | - | not pertinent -- analysis tooling, not a biogeochemical model |
| OceanGames | recreational demos | - | not pertinent |
| OceanRobots.jl | access and analysis of ocean robotic-platform data | - | not pertinent -- data tooling |
| PhysicalOceanography.jl | physical-oceanography teaching and analysis code | - | not pertinent -- pedagogical, not a biogeochemical or carbonate-chemistry reference |
| PlanktonIndividuals.jl | individual-based (Lagrangian) plankton model, GPU-capable | 0017, 0021 | not pertinent -- an individual-based method rather than the trait-population method 0017 and 0021 already committed to; noted for completeness but not a closer-look candidate against a decision already made |

### OceanBioME (3 repositories)

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| OceanBioME.jl | biogeochemistry and carbonate chemistry environment; NPZD, PISCES, `CarbonChemistry`, gas exchange, sediments; standalone box/1D or coupled to Oceananigans.jl | 0017 | algorithmic reference | now |
| GlobalOceanBioME.jl | glue utilities pairing OceanBioME with a specific external ocean model (NumericalEarth): grid, river nutrient export, dust-iron deposition | 0017, 0022 | not pertinent -- site-specific integration glue for another framework's grid and forcing, not a biogeochemistry formulation of its own |
| OceanBioMEArtifacts | a data-artifact bundle (VIIRS, Mercator Ocean, CODAP-NA, GlobalNEWS2 river loads) | - | not pertinent -- a dataset bundle, not code; any use of GlobalNEWS2-class river-load data belongs to a future hydrology or nutrient-export finding, not this survey |

### JuliaDynamics (67 repositories)

Most of this organisation is general-purpose nonlinear-dynamics, agent-based-modelling
and timeseries-analysis tooling with no climate or biogeochemistry content; each is
dismissed in one clause below. Five repositories bear on decision 0023's exit criteria
or decision 0026's oracle programme.

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| ConceptualClimateModels.jl | ModelingToolkit-composed low-order climate models: global-mean and latitudinal energy-balance models, glaciation-cycle and tipping models, integrated with DynamicalSystems.jl for start-up and bifurcation workflows | 0026 | algorithmic reference | now |
| Attractors.jl | finding attractors and basins (including exit/divergent basins), nonlocal stability, global continuation of attractors over a parameter range, tipping-point analysis | 0023 | algorithmic reference | now |
| DynamicalSystems.jl | the umbrella package integrating ChaosTools, Attractors, DelayEmbeddings, RecurrenceAnalysis and the rest of the ecosystem behind one dynamical-system interface | 0023, 0026 | algorithmic reference | now |
| TransitionsInTimeseries.jl | generic pipeline for detecting transitions/regime shifts in a timeseries and testing their significance, explicitly framed as early-warning-signal / change-point detection | 0023 | algorithmic reference | now |
| CriticalTransitions.jl | sampling noise- and rate-induced transition paths and minimum-action paths for a dynamical system with a known stochastic rule (large-deviation and transition-path theory) | 0023 | not pertinent -- it characterises *why* and *how* a system tips given its SDE, which is a modelling question this project has not posed; decision 0023's exit criteria need a diagnostic on an observed drift series, which TransitionsInTimeseries.jl and Attractors.jl already cover |
| Agents.jl | general agent-based modelling framework (the org's flagship) | - | not pertinent -- discrete-agent simulation, not a field or trait-population method this project uses |
| AgentsExampleZoo.jl, AgentsPlots.jl, ABMFrameworksComparison, InteractiveDynamics.jl | Agents.jl satellites: examples, deprecated plotting, a framework benchmark | - | not pertinent -- satellites of a not-pertinent package |
| ARFIMA.jl | long-memory timeseries simulation | - | not pertinent -- a synthetic-data generator, not a climate or biogeochemistry reference |
| Associations.jl, CausalityToolsBase.jl, CrossMappings.jl, TransferEntropy.jl, PerronFrobenius.jl | information-theoretic and causal-inference measures between timeseries | - | not pertinent -- statistical association tooling with no physical model content |
| BasinsCollection, BasinVolumes.jl | companion research code and a volume-estimation method for basins of attraction, both satellites of Attractors.jl | - | not pertinent -- covered by the Attractors.jl entry; these are research code and an early-stage estimator, not general-purpose machinery |
| BijectiveHilbert.jl | Hilbert-curve indexing | - | not pertinent -- spatial-indexing utility, unrelated to this group's subject |
| CaosDB.jl | a database client | - | not pertinent |
| Changepoints.jl | changepoint detection in timeseries, predates and is narrower than TransitionsInTimeseries.jl | - | not pertinent -- superseded in scope by the TransitionsInTimeseries.jl entry above |
| chaospp, ChaosThroughBilliards, MCMC-DIFFUSION, HardSphereDynamics.jl, DynamicalBilliards.jl | billiard and hard-sphere chaotic-dynamics research code and demos | - | not pertinent -- pure chaotic-dynamics pedagogy and research, no climate content |
| ChaosTools.jl, ComplexityMeasures.jl, DelayEmbeddings.jl, RecurrenceAnalysis.jl, RecurrenceMicrostatesAnalysis.jl, FractalDimensions.jl, PeriodicOrbits.jl, StateSpaceReconstruction.jl, StateSpaceSets.jl, TimeseriesPrediction.jl, TimeseriesSurrogates.jl, TreeEmbedding.jl, SignalDecomposition.jl, DynamicalSystemsBase.jl, PredefinedDynamicalSystems.jl, LagrangianDescriptors.jl, PeriodicOrbits.jl | general nonlinear-timeseries and dynamical-systems-analysis toolboxes underneath the DynamicalSystems.jl umbrella | - | not pertinent -- generic infrastructure the umbrella entry already covers; a closer look at the umbrella is the closer look at these |
| ConcurrentSim.jl, DiscreteEvents.jl, ResumableFunctions.jl | discrete-event simulation frameworks | - | not pertinent -- event-scheduling infrastructure, no physical content |
| DrWatson.jl, ScienceProjectTemplate, GoodScientificCodeWorkshop, doctheme, ExercisesRepo, NonlinearDynamicsComplexSystemsCourse, NonlinearDynamicsTextbook, JuliaDynamics, JuliaDynamics-NGRIP, example-python | reproducibility tooling, documentation theming, course and textbook material, org website | - | not pertinent -- process and pedagogy, not domain content |
| HybridStructs.jl, LightSumTypes.jl, StreamSampling.jl | Julia-language struct and sampling utilities | - | not pertinent -- general-purpose language tooling |
| Jumbo | a curated package-distribution fork for nonlinear/complex-systems work | - | not pertinent -- a package bundle, not a model |
| LightOSM.jl | OpenStreetMap network loading | - | not pertinent -- unrelated domain |
| NetworkDynamics.jl | dynamical systems on complex networks (e.g. power grids) | - | not pertinent -- its network-coupling abstraction is closer to the mesh-and-discretisation group's graph work than to this group's subject, and it targets a different kind of network (arbitrary graphs, not a spatial mesh) |
| PredefinedDynamicalSystems.jl | a library of textbook example systems (Lorenz, Rössler, etc.) for the ecosystem | - | not pertinent -- example fixtures |
| ProcessBasedModelling.jl | the general symbolic-equation-composition layer ConceptualClimateModels.jl is built on | 0026 | not pertinent -- covered by the ConceptualClimateModels.jl entry; it is infrastructure, not itself a climate model |
| RigorousInvariantMeasures.jl | rigorous (interval-arithmetic) computation of invariant measures | - | not pertinent -- a specialised rigorous-numerics tool without an application to this project's oracle programme |
| saokit | Python library for chaotic-system frequency analysis | - | not pertinent -- different language, narrow scope |
| Simplices.jl | simplex geometry and volume computation for state-space partitioning | - | not pertinent -- a partitioning utility for causality/entropy work, not mesh geometry (the mesh-and-discretisation group covers that subject) |
| SpatioTemporalSystems.jl | a unified stepping interface for spatiotemporal dynamical systems | - | not pertinent -- a thin API-unification layer, no physical content of its own |

### CellularPotts.jl (1 repository)

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| CellularPotts.jl | Cellular Potts Model (Hamiltonian energy minimisation over cell configurations) on a graph-represented lattice, with 2D/3D environments, adhesion, volume and division penalties | 0021, 0024 | algorithmic reference | later |

### Mimi.jl (1 repository)

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| Mimi.jl | integrated assessment modelling framework: a component graph wired by `connect_param!`, hosting simple climate models (DICE, FUND, PAGE-class) coupled to economic-damage modules | 0024 | algorithmic reference | later |

## Closer look

### PALEOboxes.jl (`/home/cfutro/git/PALEOtoolkit/PALEOboxes.jl`, `6e0761d`)

`PALEOboxes.jl` is the coupler underneath the whole PALEOtoolkit: it defines Domains
(spatial regions carrying biogeochemical Variables), Reactions that read and write those
Variables, and couples separate Domains -- atmosphere, ocean, sediment -- purely by
matching standardised Variable names across a YAML configuration (`src/Model.jl`,
`src/VariableReaction.jl`, `src/ReactionFactory.jl`). No Domain holds a reference to
another Domain's internals; a Reaction declares a dependency by name and the coupler
resolves it. This is architecturally close to this project's naming-not-coordinate rule
(0005) and worth reading when the coupler/exchange machinery of the coupled loop (0023)
is implemented, not as a dependency but as a worked example of how far a name-resolution
coupler gets you before you need the single-writer-per-quantity discipline this project's
"Exchanges" sections already declare per subsystem. The closer look should answer: does
PALEOboxes ever have two Reactions writing the same named Variable (the failure mode this
project's "no silent default across a component boundary" and "one definition per
quantity" rules exist to prevent), and how does its YAML-driven reaction network differ
in practice from a compile-time-checked Julia interface -- is the flexibility worth the
loss of static verification this project has otherwise chosen throughout.

### PALEOcopse.jl (`/home/cfutro/git/PALEOtoolkit/PALEOcopse.jl`, `4d9b7a6`)

The pure-Julia COPSE implementation (Bergman 2004, COPSE Reloaded 2018 per
`src/landsurface/LandCOPSEReloaded.jl` and `src/PALEOcopse.jl`) is the closest existing
system to decision 0022's global carbon balance: prognostic atmospheric and ocean carbon,
weathering, organic burial, and the same Walker-Hays-Kasting thermostat argument decision
0022 cites. Its `ReactionLandWeatheringRates` (lines ~170-320 of `LandCOPSEReloaded.jl`)
implements exactly the runoff-and-temperature form decision 0022 fenced: the `original`
branch's temperature dependence is `exp(0.09*(TEMP-288.15))` and the runoff branches
(`geoclim_2004`, `linear_runoff`) normalise a spatial runoff field against
`k_runoff_mean = 30e-6 kg/m2/s`, Earth's own global mean -- a literal this project's
kinetic dissolution form (0022, REQ-PED-001) never carries. The reservoir structure
(`src/COPSE/OceanCOPSE.jl`, `SedCrustCOPSE.jl`, `Strontium.jl`) is worth reading for how
it closes every element budget (C, O, S, P, Sr) simultaneously across land, ocean and
sediment reservoirs at the box-model scale decision 0022 does not resolve spatially. The
closer look should answer: does every COPSE reservoir have an explicit mass-balance check
analogous to this project's ledgers (0026), or does it rely on the ODE structure alone to
conserve mass -- and does its multi-element simultaneous-closure pattern (C, O, S, P
solved together, not element by element) suggest anything about how this project's carbon
balance (0022) should eventually extend to oxygen, sulfur and phosphorus if those are
ever added.

### PALEOaqchem.jl (`/home/cfutro/git/PALEOtoolkit/PALEOaqchem.jl`, `192af82`)

`src/CarbChem.jl`'s `ReactionCO2SYS` wraps `PALEOcarbchem` (a `CO2SYS`-family solver) and
its `defaultconcs` parameter set (`["TS", "TF", "TB", "Ca"]`, described in-code as "modern
[concentrations] calculated from salinity") is precisely the ratio-to-salinity
composition decision 0017 refused ("total boron, sulfate and fluoride ... `Derived` from
the declared composition, never ratios to salinity"). The package is nonetheless the
right place to read the aqueous-chemistry machinery this project's brine and carbonate
chemistry (0022's brine chemistry, the ocean's carbonate system in 0017) will eventually
need: multi-species equilibrium and kinetic reaction networks (`GenericReactions.jl`),
reactive-continuum organic matter degradation (`RCmultiG.jl`), and the pH-solver
approaches (`solve`, `speciation`, `speciationTAlk` in the `ReactionCO2SYS` docstring) for
handling alkalinity as either a state variable or an algebraic constraint. The closer
look should answer: can `PALEOcarbchem`'s equilibrium-constant machinery be read
independently of its default modern-seawater concentration table -- i.e. does the solver
itself take total boron/sulfate/fluoride as free inputs, so that only the `defaultconcs`
convenience layer carries the Earth-fitted defect and the numerical core is reusable as a
reference -- and does its `speciationTAlk` DAE-constraint pattern suggest a cleaner way to
solve this project's pH-at-declared-pCO2 buffers (0022) than a from-scratch Newton solve.

### OceanBioME.jl (`/home/cfutro/git/OceanBioME/OceanBioME.jl`, `b4881761`)

`src/Models/CarbonChemistry/carbon_chemistry.jl` carries the same ratio-to-salinity
composition as PALEOaqchem, but as literal numeric expressions rather than a named
default table: `boron = 0.000232 / 10.811 * S / 1.80655` and the equivalent lines for
sulfate and fluoride (lines ~92-94 and ~119-121), the standard Dickson/DOE modern-seawater
formulas. This independently confirms decision 0017's fence is not specific to one
tree's convenience default; it is the standard form the whole carbonate-chemistry
literature ships with, in two unrelated Julia implementations. Past that defect,
OceanBioME's NPZD and PISCES biogeochemistry (`src/Models/AdvectedPopulations/`), its
gas-exchange parameterisations (`src/Models/GasExchange/`) and its sediment closure
(`src/Models/Sediments/`) are a working, actively maintained reference for how a marine
trait/functional-group community's carbon and nutrient state couples to carbonate
chemistry and air-sea exchange -- structurally close to what decision 0017's marine
ecosystem section needs to hand the carbon loop (0022) and the managed biosphere (0024).
The closer look should answer: is OceanBioME's equilibrium-constant evaluation
(`carbon_chemistry.jl`'s `KS`, `KF`, `Is` ionic-strength machinery) separable from its
salinity-ratio default inputs in the same way asked of PALEOaqchem above, and does its
`InorganicCarbon` coupling to the NPZD/PISCES plankton pools show a cleaner interface
than PALEOaqchem's for exchanging DIC and alkalinity between a trait-based community and
a carbonate solver.

### AIBECS.jl (`/home/cfutro/git/JuliaOcean/AIBECS.jl`, `f747c741`)

AIBECS solves `dx/dt + Tx = G(x)` for marine tracers at steady state by implicit/Newton
methods (`ReadMe.md`), where `T` is a precomputed offline circulation matrix (OCIM,
OCCA) -- a fundamentally different method from this project's explicit time integration
on the shared mesh (0017, 0023). It is not a component candidate because `T` is tied to
Earth's own circulation product and this project's ocean state is prognostic, not
offline. It is a plausible oracle arm (0025's third tier, 0026's oracle programme)
because its steady-state solve is an independent numerical route to the same fixed point
this project's slow-tier carbon balance (0022) seeks by iterated time-stepping and
climate refreshes (0023): given a reduced, this-project-declared box representation of
ocean transport and biogeochemistry, AIBECS's implicit solver could supply an
independently-computed steady state to check the coupled loop's own fixed point against,
the way decision 0026 already uses closed-form linear systems (barotropic gyres,
geostrophic adjustment) as ocean oracles. The closer look should answer: how much of
AIBECS's steady-state machinery is separable from its OCIM-specific transport matrices --
can a small `T` be hand-built from this project's own transport operator on a coarse
mesh and handed to AIBECS's solver as an independent cross-check of a slow-tier fixed
point, or does the package assume the OCIM data format too deeply to reuse for that.

### ConceptualClimateModels.jl (`/home/cfutro/git/JuliaDynamics/ConceptualClimateModels.jl`, `aa249d7`)

The `GlobalMeanEBM` submodule (`src/GlobalMeanEBM/`, documented at
`docs/src/submodules/globalmeanebm.md`) composes Budyko-Sellers-family energy balance
models symbolically via ModelingToolkit, with named process choices for longwave
emissivity, cloud longwave forcing and meridional temperature diffusion
(`src/GlobalMeanEBM/longwave/emissivity.jl`, `clouds/longwave.jl`,
`temperature/tempdiff.jl`). Because these models are assembled as explicit symbolic
equation systems rather than opaque numerical kernels, their fixed points and
bifurcation structure (ice-albedo runaway thresholds, Stommel-class multiple
equilibria where present) are closed-form or semi-analytically characterisable, and the
package is wired directly to DynamicalSystems.jl for that analysis. This is a plausible
first-tier analytic/identity oracle (0026) for the coupled loop's qualitative behaviour:
a reduced EBM built in this package, at this project's own gravity/rotation/instellation
parameters rather than Earth's, could give a known bifurcation diagram to check that the
coupled loop's climate-refresh criterion (0023) neither misses a real regime change nor
falsely reports one. The closer look should answer: can a Budyko-Sellers instance be
parameterised with this project's own `System` struct's insolation and albedo relations
closely enough that its bifurcation point becomes a numeric prediction this project's own
reduced-physics limit should reproduce, and does the package's process-choice framework
(swappable longwave and diffusion closures) map onto a useful minimal test of which of
this project's own closures the loop's stability is most sensitive to.

### Attractors.jl (`/home/cfutro/git/JuliaDynamics/Attractors.jl`, `2ac1e83`) and DynamicalSystems.jl (`/home/cfutro/git/JuliaDynamics/DynamicalSystems.jl`, `3e3a902`)

Attractors.jl's basin-of-attraction and exit-basin (divergence-to-infinity) finding,
nonlocal stability analysis and global continuation of attractors over a parameter
range are read together with the DynamicalSystems.jl umbrella that hosts them, because
the umbrella is how ConceptualClimateModels.jl and Attractors.jl are meant to be used
together (its README states the integration explicitly). Decision 0023's exit criteria
must distinguish a coupled-loop trajectory that has reached (or is oscillating tightly
around) an attracting state from one that is merely drifting slowly toward one -- exactly
the boundary Attractors.jl's basin-fraction and nonlocal-stability tools are built to
characterise for a system with a known dynamic rule. The closer look should answer:
could a reduced surrogate of the coupled loop (built at low order, e.g. from a
ConceptualClimateModels.jl instance standing in for the fast-slow tier structure of
0023) be handed to Attractors.jl to test whether its basin-stability measures would have
flagged a "wandering slowly, not converged" trajectory that a naive drift-window test
(REQ-NUM-005) would pass -- i.e. is there a cheap surrogate test that could serve as a
pre-registered acceptance check on the exit-criteria design itself, separate from
running it on the full model.

### TransitionsInTimeseries.jl (`/home/cfutro/git/JuliaDynamics/TransitionsInTimeseries.jl`, `35e234b`)

Not named in the survey brief, but the closest structural match found to decision 0023's
own stated risk. The package's generic pipeline -- indicator computation, a
significance test, and an explicit statement that it covers "Early Warning Signals /
Resilience Indicators / Regime-Shift Identifiers / Change-Point Detectors" under one
interface -- is a diagnostic on an *observed* timeseries rather than on a system with a
known dynamic rule, which is the situation decision 0023's exit criteria are actually in
(they read accumulated climate statistics, not the coupled loop's equations). It answers
the other half of the question Attractors.jl answers: not "is this attracting" but "has
this series' character changed." The closer look should answer: does the package's
change-point/significance-testing machinery generalise to decision 0023's specific
tolerances (fractions of a reservoir's stock per relaxation time, multiples of A/A
scatter, per REQ-NUM-005's autocorrelation-corrected window), or is it built around a
different class of indicator (variance, autocorrelation-at-lag-1, skewness as early
warning signals of an approaching bifurcation) that would need adaptation before it could
serve as anything more than a design check on the drift-detection logic decision 0023
already specifies in prose.

### CellularPotts.jl (`/home/cfutro/git/CellularPotts.jl`, `406a5ff`)

CellularPotts.jl's Hamiltonian-based cell dynamics runs on a *graph* representation of
space (`README.md`: "the space cells occupy is modeled as a network/graph"), not a fixed
regular lattice -- periodic boundaries and diagonal connectivity are graph properties, and
the package explicitly leverages this for articulation points (avoiding cell
fragmentation), graph-partitioning-based division and graphical-Laplacian diffusion. This
is the detail that makes it worth a closer look rather than a dismissal on the
lattice-vs-mesh objection the survey brief anticipated: a graph-based transition-rule
formulation is not intrinsically tied to a regular lattice, and the connectivity graph
this project's mesh hierarchy already carries (0005) is exactly the kind of graph
CellularPotts.jl's `CellSpace` could in principle be built over, at least for the
"which tile competes with which neighbour" part of decision 0021's per-tile vegetation
strategy competition, or decision 0024's land-use/land-cover class transitions. The
Hamiltonian energy-minimisation update rule itself (adhesion, volume and surface
penalties minimised by stochastic cell-copy attempts) is Earth-cell-biology-specific and
not itself a candidate for reuse. The closer look should answer: is `CellSpace`'s graph
representation decoupled enough from its regular-lattice convenience constructors
(`CellSpace(50,50; ...)`) to be built directly over this project's triangle/hex
connectivity graph, and if so, is a Potts-style stochastic energy-minimisation update
rule (rather than the deterministic strategy-competition rule 0021 already specifies) a
plausible reference for expressing dispersal and succession as local transition rules --
or does 0021's continuous-trait competition already cover the same ground by a different,
already-decided method, making this purely a "how might a discrete-state alternative have
looked" comparison rather than something with an open question attached.

### Mimi.jl (`/home/cfutro/git/Mimi.jl`, `d5769280`)

Mimi's component model wires named components into a directed graph via `connect_param!`
(referenced throughout `docs/src/howto/`), with each component's parameters resolved
against another component's variables by name -- again a name-based coupling discipline,
this time specifically built to let a socio-economic damage module read a physical
climate module's output without the physical module ever importing or depending on the
economic one. This is exactly the structural shape decision 0024's potential/driven mode
split needs for its own future extension: potential mode is a pure function of the
physical run, and driven mode's land-use and water-use map is an external input the
physical subsystems must not depend on for their own definitions. The closer look should
answer: does Mimi enforce the one-directional dependency (economic reads physical, never
the reverse) structurally, or only by convention -- and is there anything in how it
handles a component's own internal timestep against another component's (its models are
typically annual, ill-matched to this project's tiered timesteps) that bears on how a
future driven-mode managed-biosphere component should declare its own cadence against the
daily and orbital tiers of decision 0023.

## Recommended rows

1. **Read PALEOboxes' coupler before the coupled-loop exchange/registry machinery is
   built** (0023, 0009) -- `algorithmic reference`, timed to when the coupler/exchange
   layer of the coupled loop is implemented (per decision 0034's build order, not `now`
   since 0023 is already accepted; the coupler is an implementation-time comparison).
2. **Read PALEOcopse's reservoir-closure pattern before decision 0022's carbon balance is
   implemented** -- `algorithmic reference`, `now`, since 0022 is open/on the near build
   order and the weathering-form confirmation above is directly load-bearing for
   REQ-PED-011's REPORT bracket.
3. **Read PALEOaqchem and OceanBioME's carbonate-chemistry solvers (not their default
   composition tables) before decision 0017's carbonate system and decision 0022's brine
   chemistry are implemented** -- `algorithmic reference`, `now`, for the same reason: both
   are open build-order items and both need reusable equilibrium-constant machinery
   decoupled from a salinity-ratio composition default.
4. **Evaluate AIBECS as an independent steady-state cross-check for the carbon balance's
   fixed point** -- `oracle arm`, timed to when decision 0026's ocean- and carbon-cycle
   oracle rows are built out, since it needs the reduced box representation the closer
   look above describes before it can be exercised.
5. **Read ConceptualClimateModels.jl, Attractors.jl/DynamicalSystems.jl and
   TransitionsInTimeseries.jl before decision 0023's exit criteria and decision 0026's
   analytic-oracle rows are implemented** -- `algorithmic reference`, `now`, since 0023
   and 0026 are both accepted-but-open in the sense that their instruments do not yet
   exist; these three answer, respectively, whether a reduced climate model gives a
   closed-form bifurcation oracle, whether a known-rule system's basin/attractor state
   can validate the exit-criteria design on a surrogate, and whether an observed-series
   change-point method generalises to the specific drift tolerances 0023 already declares.
6. **Read CellularPotts.jl's graph-based `CellSpace` before any discrete-transition-rule
   alternative to decision 0021's strategy competition or decision 0024's land-use
   transitions is considered** -- `algorithmic reference`, `later`, since both decisions
   are accepted with a continuous-trait/continuous-mode method already chosen; this is a
   comparison to keep on file, not a near-term build dependency.
7. **Read Mimi's component-graph enforcement before decision 0024's driven mode is
   built** -- `algorithmic reference`, `later`, since driven mode is explicitly deferred
   in 0024 itself.
