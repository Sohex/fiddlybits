# The CliMA organisation, swept

**What this is.** The completeness half of the CliMA survey. Every public
repository in the organisation appears below exactly once, with either a one-line
dismissal and its reason, or a pointer to the record that judges it. The point is
that a later reader can see that nothing was skipped silently, and can tell the
difference between a repository that was judged and one that was passed over
because it holds a dashboard or a conference handout.

**Coverage.** The organisation reported sixty-six public repositories when this
sweep was taken. All sixty-six are listed. The list was taken from the
organisation's repository index, and the description quoted in each dismissal is
the repository's own, not a reading of its source; where a dismissal rests on
something other than the description, the file it rests on is named.

**Date and method.** Swept 2026-09-09 against the organisation index and, for the
repositories where the description alone did not settle the question, against
`main` of each. A sweep of a moving target is worthless without a date, and this
one is a snapshot: a repository added after this date is not in it.

## Judged in their own records by this survey

| repository | record |
| --- | --- |
| Insolation.jl | `docs/imports/insolation-jl.md`; do not adopt |
| ClimaCoupler.jl | `docs/imports/climacoupler-jl.md`; do not adopt |
| ClimaDiagnostics.jl | `docs/imports/clima-output-and-tooling.md`; do not adopt |
| ClimaAnalysis.jl | `docs/imports/clima-output-and-tooling.md`; do not adopt |
| ClimaUtilities.jl | `docs/imports/clima-output-and-tooling.md`; borrow ideas only |

## Judged elsewhere in this survey or already in decision 0012

Each of these is the subject of another row of the survey plan, or already
carries a verdict in decision 0012. This sweep does not judge them; it records
where the judgement lives so the reader is not left wondering whether they were
missed.

| repository | where it is judged |
| --- | --- |
| Thermodynamics.jl | thermodynamics and gas properties row |
| ClimaParams.jl | thermodynamics and gas properties row; decision 0012 already borrows its read-logging idea |
| ClimaTimeSteppers.jl | numerics and time row |
| ClimaCore.jl | numerics and time row; decision 0012 already refuses it as a component and borrows its axis-tensor idea |
| ClimaComms.jl | numerics and time row |
| RRTMGP.jl | radiation row |
| SurfaceFluxes.jl | surface and column row |
| CloudMicrophysics.jl | surface and column row |
| ClimaLand.jl | surface and column row |
| Oceananigans.jl | ocean and ice row; decision 0012 already refuses it as a component and borrows three ideas |
| ClimaOcean.jl | ocean and ice row |
| ClimaSeaIce.jl | ocean and ice row |
| ClimaAtmos.jl | decision 0012 already refuses it: a model core on a cubed sphere, with a parameter library that defaults to Earth |

## Flagged: bears on Part A or Part B and deserves a record of its own

Three repositories came out of the sweep as more than tooling. None is judged
here; each is named with what makes it worth a record, so a later row can be
filed against it.

**CGDycore.jl.** Described only as an experimental Julia dycore, which
undersells it for this project's purposes. Its `src/Grids/` directory holds
`Triangular.jl`, `HexGrid.jl`, `HexagonalGrid.jl`, `Grid2KiteGrid.jl`,
`HealpixGrid.jl`, `SphereEqualArea.jl`, `CubedGrid.jl` and `TriPolarGrid.jl`
beside `Connectivity.jl`, `EdgesInNodes.jl` and `FacesInNodes.jl`;
`Triangular.jl` builds a node, edge and face structure and refines it by
projecting edge midpoints back onto the unit sphere, which is icosahedral
refinement. It runs on `KernelAbstractions` across CUDA and Metal, decomposes the
sphere by space-filling curve or by equal-area bands, and integrates in time with
Rosenbrock-W methods. This is the one repository in the organisation whose grid
machinery is not cubed-sphere-only, and the one whose mesh, connectivity record
and GPU model sit where decisions 0005 and 0006 sit. It is at version 0.1.0,
Apache 2.0, and its ideas rather than its code are the likely value; a record
should read its connectivity and orientation handling against the
conventions-travel-by-name rule and its metric terms against the named-basis
vector semantics. Recommended as a new row on the survey plan.

**RootSolvers.jl.** Robust scalar root finding with bisection, regula falsi,
Brent's method, the secant method and Newton's method with and without automatic
differentiation, broadcastable over abstract arrays and written to run inside a
GPU kernel; tolerances are types (`ResidualTolerance`, `SolutionTolerance`,
`RelativeSolutionTolerance`, `RelativeOrAbsoluteSolutionTolerance`, `NoTolerance`)
that a caller supplies rather than numbers the package chooses, and every one of
them also reports convergence when the residual falls below the machine epsilon.
Its only dependencies are `ForwardDiff` and `Printf`. It contains no planetary
content whatever, which puts it on the adoptable side of decision 0012's line,
and it is exactly the machinery two of this project's requirements need: decision
0008's Kepler solve to rounding for any eccentricity below one wants a bracketing
method with guaranteed convergence, and a saturation adjustment wants a
broadcastable in-kernel Newton solve. Apache 2.0, version 1.1.0. Recommended as a
new row; the `ForwardDiff` dependency also touches decision 0033 on
differentiability and should be read against it.

**SeawaterPolynomials.jl.** Polynomial approximations to the Boussinesq seawater
equation of state as a function of conservative temperature, absolute salinity
and geopotential height, with a reference density taken from the average at the
surface of one ocean on one planet. This is the package that actually answers the
plan's ocean and ice question about what the sea-ice and ocean thermodynamics
assume about seawater composition, and it sits outside the three repositories that
row's boundary names. It is a small, pure, dependency-free package (Apache 2.0,
version 0.3.10) whose code is general polynomial evaluation and whose
coefficients are fitted to Earth's ocean, which is the common and useful case
this survey was told to separate. Recommended as an addition to the ocean and ice
row's boundary rather than as a row of its own.

## Physics and model repositories, dismissed

| repository | one-line verdict |
| --- | --- |
| Cloudy.jl | a moment-based toy cloud microphysics model; superseded for this project's purposes by whatever the surface and column row concludes about CloudMicrophysics.jl, and a toy by its own description |
| KinematicDriver.jl | prescribed-flow test harness for microphysics schemes; not a component, but the pattern (drive a parameterisation with an analytic flow that has a right answer) is the same instinct as this project's positive controls, and needs no import to reuse |
| ClimaOceanBiogeochemistry.jl | ocean biogeochemistry built on the Oceananigans grid, so it inherits that grid verdict; the tracer set is Earth's ocean and the code is bound to ClimaOcean |
| ClimaRivers.jl | land water routing at version 0.1.0, with CSV, DataFrames and JSON dependencies and a river-network representation that presumes a drainage dataset; this project derives its connectivity graph from its own terrain and does not read one |
| Land | a collection of tutorials and sub-module pointers for the older CliMA Land effort, superseded by ClimaLand.jl; not a package to import |
| CubedSphere.jl | cubed sphere grid generation; refused by decision 0012's one-mesh rule at the first line |
| pycles | a Python and Fortran large-eddy simulation infrastructure, not Julia and not in this process |
| ClimateMachine.jl | archived; the organisation's previous-generation Earth system model, superseded by the ClimaCore stack that decision 0012 already refuses |
| SCAMPy | archived fork of a Python single-column boundary-layer model |
| tempestmodel | archived fork of a C++ Earth system model |
| ShallowWaterBench | archived benchmark harness with no description |

## Data, inputs and artifacts

These bear on `docs/inputs/` rather than on the model, and none is adoptable as
infrastructure, because what they carry is Earth data and this project declares
its system rather than reading one.

| repository | one-line verdict |
| --- | --- |
| ClimaArtifacts | pre-processing pipelines and `Artifacts.toml` entries for the organisation's Earth input datasets; useful as a worked example of a per-dataset manifest with the producing script beside it, which is the shape `docs/inputs/` wants, but the datasets themselves are Earth's |
| GriddingMachine.jl | readers for gridded Earth land datasets feeding ClimaLand; an input pipeline for one planet |
| AtmosphericProfilesLibrary.jl | a library of named Earth soundings used to initialise large-eddy simulation cases; possible oracle inputs for a column model, never model inputs |
| InitialConditions.jl | ERA5 initial conditions, per its README's only line; an Earth reanalysis reader |
| ArtifactWrappers.jl | a thin download-and-cache wrapper over Julia's `Pkg` artifacts; superseded within the organisation by `ClimaUtilities.ClimaArtifacts`, and in any case not an artifact store in decision 0010's sense, which is content-addressed on what produced an object rather than on the bytes of a download |
| LESbrary.jl | a generated library of Oceananigans large-eddy simulation output for calibrating ocean parameterisations; data, and Earth's ocean |

## Calibration, emulation and machine learning

Dismissed as a class. This project's five dispositions do not include Tuned, and
a parameter calibrated against Earth observations is precisely the thing that
cannot enter. These are named individually anyway so the class is visibly
complete and not a wave of the hand.

| repository | one-line verdict |
| --- | --- |
| EnsembleKalmanProcesses.jl | derivative-free ensemble calibration of model parameters; the machinery is planet-free and the use is not, and there is no parameter here for it to fit |
| CalibrateEmulateSample.jl | emulate-and-sample uncertainty quantification built on the above; same reason |
| ClimaCalibrate.jl | the driver that runs the above against CliMA models on a cluster; same reason, and it schedules jobs, which this machine does through `qrun` |
| ClimaOceanCalibration.jl | ocean calibration against prescribed atmospheric states; same reason |
| ParameterEstimocean.jl | parameter estimation for Oceananigans using the above; same reason |
| OceanParameterizations.jl | machine-learned ocean parameterisations; a learned closure is not a process that exists, which the physics-is-not-a-knob rule refuses |
| RandomFeatures.jl | random feature approximation, a component of the emulator stack; same class |
| OperatorFlux.jl | neural operator layers for Flux.jl; same class |
| CliMAgen.jl | archived; generative superresolution research |
| diffusion-bridge-downscaling | archived; a paper's reproduction code for downscaling with diffusion bridges |

## Planet-free Julia infrastructure

These carry no planetary content and so sit on the adoptable side of decision
0012's line. None is proposed for adoption; each is recorded so that a later need
finds it rather than reinventing it, and each would need its own import record
before any adoption.

| repository | one-line verdict |
| --- | --- |
| RootSolvers.jl | flagged above; the strongest candidate in the organisation |
| GilbertCurves.jl | generalised Hilbert curves over arbitrary rectangles, two-dimensional only; the locality problem it solves is real, but this project's cell ordering comes from the icosahedral parent-child relation of decision 0010, which is already contiguous by construction, so there is nothing here to use |
| LazyBroadcast.jl | deferred broadcast expressions, to fuse operations and avoid temporaries; relevant to kernel work, no planetary content |
| MultiBroadcastFusion.jl | fuses several broadcast expressions into one pass; same |
| NullBroadcasts.jl | a `NullBroadcasted()` that is an identity in a broadcast expression at no runtime cost; the clean way to express an absent process without a branch, which is worth knowing given how many of this project's processes are optional |
| UnrolledUtilities.jl | statically sized iterator utilities for type stability and GPU compilation; no planetary content |
| StructuredPrinting.jl | pretty-printing of nested structs; a debugging convenience |
| ClimaInterpolations.jl | interpolation tools with `Adapt` and an optional CUDA extension, version 0.1.3; no planetary content in its dependencies, but what it assumes about the dimensions it interpolates over is `to verify` and was not read for this sweep |

## Visualisation, documentation, teaching and organisation tooling

Out of scope by the survey plan's own terms: no bearing on Part A or Part B.
Listed once, with the reason.

| repository | one-line verdict |
| --- | --- |
| ClimaViz.jl | web dashboards and animations of ClimaAtmos and ClimaLand output; visualisation |
| Nimbus | archived; a JavaScript viewer for large-eddy simulation output |
| ClimaScope | archived fork; a web viewer for CliMA simulations and Earth historical data |
| OceananigansDocumentation | a documentation host for another repository; no code |
| ClimaOceanDocumentation | the same, for ClimaOcean |
| ClimaSeaIceDocumentation | the same, for ClimaSeaIce |
| DeveloperGuides | the organisation's engineering standards and conventions for human and machine contributors; readable as a source of practice, carrying no code and no physics |
| MC3Workshop | 2025 workshop materials; teaching |
| slurm-buildkite | runs Buildkite jobs on a Slurm cluster; continuous integration plumbing, and this machine schedules through `qrun` |
| buildkite-pipeline-action | archived fork; a GitHub action that triggers a Buildkite pipeline |
| .github | the organisation's default issue templates and community health files |

## What this sweep changes

Nothing yet, by design; a survey adopts nothing. Three actions follow from it and
belong to whoever files the next rows: a record for CGDycore.jl, a record for
RootSolvers.jl, and the addition of SeawaterPolynomials.jl to the ocean and ice
row's boundary. Decision 0012's three lists are amended by the verdicts row of
the survey plan, not here.
