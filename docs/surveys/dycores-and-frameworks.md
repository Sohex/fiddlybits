+++
epic = "fiddlybits-bon"
title = "dycores-and-frameworks: SpeedyWeather.jl, FourierFlows, ShallowWaters.jl, gaelforget, JuliaClimate"
trees = [
  "SpeedyWeather.jl",
  "FourierFlows/FourierFlows.jl",
  "FourierFlows/GeophysicalFlows.jl",
  "FourierFlows/BenchFourierFlows.jl",
  "FourierFlows/Brusselator.jl",
  "FourierFlows/FourierFlowsDocumentation",
  "FourierFlows/GeophysicalFlowsDocumentation",
  "FourierFlows/GeophysicalFlowsDocumentationPreviews",
  "FourierFlows/GeophysicalFlows-Examples",
  "FourierFlows/MultilayerQG-example",
  "FourierFlows/OscillatoryFlowsDocumentation",
  "FourierFlows/OscillatoryFlows.jl",
  "FourierFlows/PassiveTracerFlowsDocumentation",
  "FourierFlows/PassiveTracerFlows.jl",
  "FourierFlows/TurbulenceTools.jl",
  "ShallowWaters.jl",
  "gaelforget (121 repositories, enumerated below)",
  "JuliaClimate (14 repositories, enumerated below)",
]
status = "filed"
date = "2026-09-09"
+++

## What this group is

151 trees: one atmospheric GCM already recorded as a reference arm (SpeedyWeather.jl),
a pseudospectral beta-plane framework and its 13 sibling repositories (FourierFlows),
a 16-bit shallow-water testbed (ShallowWaters.jl), and two personal/organisational
umbrellas of mostly unrelated notebooks, data-access clients and teaching material
(gaelforget, 121 repositories; JuliaClimate, 14 repositories, six of them duplicated
inside gaelforget). Two packages buried in the umbrellas, `MeshArrays.jl` and
`ClimateModels.jl`, are where the reading went; the other 119 gaelforget repos and 13
JuliaClimate repos are notebooks, data clients, websites, and Earth-specific analysis
tools, dismissed in one clause each below.

Three findings matter most:

1. **SpeedyWeather.jl's reference-arm record (`docs/imports/speedyweather-reference-arm.md`)
   is still accurate but stale on two points.** The tree has been restructured into a
   five-package monorepo (`LowerTriangularArrays`, `RingGrids`, `SpeedyTransforms`,
   `SpeedyWeatherInternals`, `SpeedyWeather`) and now carries Enzyme-based
   differentiability and land/sea-ice components that did not exist when the record was
   written; none of that changes the verdict (still not a component, still an
   independent implementation to compare against), but the commit pin and the
   description of what it now contains are out of date.
2. **`MeshArrays.jl`'s halo-exchange machinery is not separable from its grid types**:
   `exchange!` dispatches on a `grid.class` string fixed to `"LatLonCap"`,
   `"CubeSphere"`, `"PeriodicChannel"`, `"PeriodicDomain"`, and each has its own
   hand-written face-rotation logic in a separate file
   (`src/exchanges/CubeSphere.jl` etc.). It is a worked example of the pattern
   decision 0013 is committed to avoiding for the triangle mesh (a small enumerated
   set of hardcoded topologies rather than a general connectivity graph), and it is
   worth fifteen minutes before the connectivity graph's exchange operator is written,
   as a instance of what *not* to copy.
3. **`ClimateModels.jl`'s run identity is a random UUID, not a content address.**
   `ModelConfig.ID = UUIDs.uuid4()` is assigned at construction, uncorrelated with the
   model, its parameters, or its inputs; provenance is a per-run git repository under
   the run's own `log/` folder that commits `README.md` and `tracked_parameters.toml`
   as the run proceeds. It is an honest, working answer to "what happened during this
   run" and a weaker answer than decision 0010 to "is this the artifact I think it
   is": two identical runs get two UUIDs and nothing recognises they agree.

## Repositories surveyed

### SpeedyWeather.jl

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| SpeedyWeather.jl | spectral atmospheric GCM on ring grids; already the certified reference arm | 0012, 0013, 0025 | oracle arm (existing record; refresh) | M3 |

### FourierFlows (14 repositories)

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| FourierFlows.jl | the pseudospectral periodic-domain PDE framework GeophysicalFlows is built on | - | not pertinent: periodic-box spectral infrastructure with no planetary content; decision 0013 has already rejected a spectral core for the same reason SpeedyWeather's grid was rejected | - |
| GeophysicalFlows.jl | single-layer barotropic QG, multi-layer QG, surface QG and 2D Navier-Stokes solvers on a periodic beta-plane | 0025 | oracle arm | M3 |
| TurbulenceTools.jl | analysis utilities (spectra, statistics) for 2D turbulence output | 0025 (supporting) | not pertinent as a separate row: its statistics routines are what a GeophysicalFlows comparison would use, folded into that entry rather than surveyed separately | - |
| BenchFourierFlows.jl | performance-benchmarking harness for FourierFlows.jl | - | not pertinent: benchmarking only | - |
| Brusselator.jl | a reaction-diffusion (Brusselator) example built on FourierFlows.jl | - | not pertinent: chemistry toy problem, no GFD content | - |
| FourierFlowsDocumentation | documentation site source | - | not pertinent: docs build | - |
| GeophysicalFlowsDocumentation | documentation site source | - | not pertinent: docs build | - |
| GeophysicalFlowsDocumentationPreviews | preview deployments of the docs site | - | not pertinent: docs build artifact | - |
| GeophysicalFlows-Examples | example gallery for GeophysicalFlows.jl | - | not pertinent: examples, no new content over the package itself | - |
| MultilayerQG-example | a standalone multi-layer QG example | - | not pertinent: subsumed by GeophysicalFlows.jl's own examples | - |
| OscillatoryFlowsDocumentation | documentation site source | - | not pertinent: docs build | - |
| OscillatoryFlows.jl | oscillatory (tidally forced) periodic-box flow solver | - | not pertinent: periodic-box, not the tidal-forcing interface decision 0017/0032 describe | - |
| PassiveTracerFlowsDocumentation | documentation site source | - | not pertinent: docs build | - |
| PassiveTracerFlows.jl | passive-tracer advection on the FourierFlows periodic grids | - | not pertinent: periodic-box tracer advection, not this project's tracer scheme | - |

### ShallowWaters.jl

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| ShallowWaters.jl | a shallow-water model with precision (down to 16-bit, posits, stochastic rounding) as a type parameter | 0011 | algorithmic reference | M3 |

### gaelforget (121 repositories)

Only `MeshArrays.jl` and `ClimateModels.jl` earned a closer look; the source-level
reading is in the next section. Everything else, one clause each:

| repo | what it is | verdict |
| --- | --- | --- |
| 2021-03-17-parallelization-tutorial | workshop tutorial materials | not pertinent |
| AIBECS.jl | ocean-biogeochemistry box-model framework on precomputed circulation matrices | not pertinent to this group (biogeochemistry-and-conceptual's territory) |
| AirSeaFluxes.jl | air-sea flux computation/analysis tool | not pertinent |
| ALGCM1D.jl | under-construction 1D atmosphere/land coupled-model stub | not pertinent |
| AOGCM1D.jl | simple 1D coupled ocean-atmosphere toy model | not pertinent |
| apt_install | shell helper for installing non-Julia system packages | not pertinent |
| ArgoData.jl | Argo float data processing/analysis | not pertinent |
| Atlantic_Innovation_Week_2023_Julia_Tutorial | workshop tutorial | not pertinent |
| bayesian_cbiomes | Bayesian-methods workshop notebooks | not pertinent |
| big-data-tutorial | tutorial notebooks | not pertinent |
| CatViews.jl | array-of-views utility for parameters distributed across arrays | not pertinent |
| CbiomesProcessing.jl | post-processing workflow for MITgcm/Darwin output | not pertinent |
| ChemostatPlanktonModelNotebook | teaching notebook, single-species chemostat plankton model | not pertinent |
| ClimateBase.jl | DimensionalData-based longitude/latitude/time analysis toolkit | not pertinent: structured lat-lon array, the pattern already rejected for Oceananigans/ClimaCore under decision 0012 |
| ClimateModels.jl | uniform run/track interface for models of any complexity | algorithmic reference, see below |
| ClimatePlots.jl | plotting library for ClimateTools fields | not pertinent |
| ClimateTasks.jl | task scheduling/orchestration helpers for climate workflows | not pertinent |
| ClimateTools.jl | bias correction, interpolation and shapefile subsetting toolkit | not pertinent |
| CO2System.jl | port of the CO2SYS carbonate-chemistry calculator | not pertinent to this group (0017's carbonate chemistry is a Sourced-equilibria concern, not a framework one) |
| corn | JupyterHub base image for a hackweek | not pertinent |
| crocolake-julia | client for the CrocoLake oceanographic-observation database | not pertinent |
| crocolaketools-public | Python client for CrocoLake | not pertinent (not Julia) |
| CyclicArrays.jl | generic array type for multi-face cyclic domains, addressed by an explicit face-connection array | not pertinent to this group's verdict set, but adjacent to the MeshArrays finding: it generalises face adjacency past MeshArrays' four hardcoded classes while still indexing by structured (x,y,z) faces rather than an arbitrary triangle graph; worth a name-check if the mesh-and-discretisation survey wants a second data point |
| darwin3 | MITgcm master source and documentation (Fortran) | not pertinent (not Julia, not this project's core) |
| dataverse | Dataverse data-repository software | not pertinent |
| demo-julia | Binder demo of Julia | not pertinent |
| DGGS.jl | Discrete Global Grid Systems (H3/S2-family tessellations) package | not pertinent to this group; a grid-machinery candidate for the mesh-and-discretisation survey, not read further here |
| DiffEqu-Methods | teaching notebook on differential-equation methods | not pertinent |
| Diffusion.jl | toy 2D Cartesian diffusion-equation solver | not pertinent |
| Documenter.jl | Julia documentation generator | not pertinent (tooling) |
| Drifters.jl | Lagrangian particle-trajectory analysis over gridded ocean/climate models | not pertinent to this group |
| earthcube-meeting-2022 | conference talk materials | not pertinent |
| ecco-2024 | workshop/course materials | not pertinent |
| ECCO-cloud | ECCO/MITgcm cloud deployment scripts | not pertinent |
| ECCO-Docker | Docker image for ECCO/MITgcm analysis | not pertinent |
| ECCO.jl | examples of algorithmic-differentiation-based model optimisation | not pertinent |
| ECCOv4 | docs/tools for the ECCO v4 ocean-state estimate | not pertinent |
| ECCOv4_flt_offline | tools for MITgcm float/offline packages on ECCO grids | not pertinent |
| EH24-Drifters | hackathon proposal template | not pertinent |
| EH24-Drifters.tmp | duplicate/temp copy of the above | not pertinent |
| EH24-ToyECCO | toy AD-based ECCO estimation benchmark | not pertinent |
| EpiGen | epidemiological model code | not pertinent (unrelated domain) |
| Extremes.jl | extreme-value statistics package | not pertinent |
| flt_example | example configuration, empty README | not pertinent |
| gaelforget | personal profile repo | not pertinent |
| gaelforget.github.io | personal website | not pertinent |
| gcmfaces | the original Matlab/Octave toolbox MeshArrays.jl succeeded | not pertinent (superseded by MeshArrays.jl, surveyed) |
| General | mirror of the Julia General package registry | not pertinent |
| Genie.jl | full-stack web framework | not pertinent (unrelated) |
| GeoMakie.jl | Makie-based geographic plotting | not pertinent |
| GeometryOps.jl | geometry-operations library, in development | not pertinent |
| GEOS_OceanGridComp | GEOS ocean grid-component glue code | not pertinent |
| gradientsWG1 | working-group notes on observed spatial/temporal gradients | not pertinent |
| GRID_CS32 | MITgcm/ECCOv4 cubed-sphere unit-test grid data | not pertinent (Earth grid data) |
| GRID_LL360 | MITgcm/OCCA lat-lon grid data | not pertinent |
| GRID_LLC90 | MITgcm/ECCOv4 LLC90 grid data | not pertinent |
| hector | the Hector simple climate model (R/C++), wrapped as a ClimateModels.jl example | not pertinent to this group |
| HelloDocs.jl | Documenter.jl example package | not pertinent |
| IQuOD.github.io | website assets for an ocean-data QC project | not pertinent |
| Isca | idealised-GCM framework mirror, empty README | not pertinent |
| IsopycnalSurfaces.jl | isopycnal-surface computation, split from ECCOtour.jl | not pertinent to this group |
| JuliaBoxTutorials | old JuliaBox tutorial notebooks | not pertinent |
| JuliaBoxTutorialSubset | subset of the above | not pertinent |
| Julia-Cheat-Sheet | language cheat sheet | not pertinent |
| juliaclimate.github.io | org website (duplicate of the JuliaClimate group entry) | not pertinent |
| JuliaEO | Earth-observation workshop resources | not pertinent |
| JuliaEO25 | 2025 workshop resources | not pertinent |
| JuliaEO26 | 2026 workshop resources | not pertinent |
| Juls.jl | predecessor of ShallowWaters.jl by the same author (Milan Klwer), mirrored into this account | not pertinent (superseded by ShallowWaters.jl, surveyed) |
| Lasso_CBIOMES_Julia | meeting discussion notebook | not pertinent |
| MapTiles.jl | map-tile provider utility | not pertinent |
| MarineEcosystemsJuliaCon2021.jl | conference-talk plankton-model demo | not pertinent |
| MeshArrays.jl | older personal fork of MeshArrays.jl (module layout predates the current org repo) | not pertinent: superseded by the canonical JuliaClimate/MeshArrays.jl, surveyed below |
| meta | org discussion repo | not pertinent |
| MITgcm | mirror of darwin3 (MITgcm source) | not pertinent |
| MITgcm_flt_Rousselet2020 | paper-specific MITgcm configuration | not pertinent |
| MITgcm.jl | Julia interface to build/run/analyse MITgcm | not pertinent |
| MITgcm_MascareneISWs_Run04c | paper-specific MITgcm configuration | not pertinent |
| mitgcm_to_iglobe | MITgcm-to-visualisation interpolation script | not pertinent |
| MIT-PraCTES | tutorial materials | not pertinent |
| NCDatasets.jl | NetCDF reader/writer | not pertinent to this group: already adopted, decision 0012 |
| NCTiles.jl | tiled NetCDF I/O for MITgcm-family grids | not pertinent |
| nctiles-testcases | test data for NCTiles.jl | not pertinent |
| NewEnglandTemperature | teaching notebook | not pertinent |
| Notebooks | JuliaClimate demo notebook collection (duplicate of the JuliaClimate group entry) | not pertinent |
| Oceananigans.jl | structured-grid ocean/fluid model | not pertinent to this group: already verdicted (do not adopt), decision 0012 |
| ocean_clustering | clustering-method research code | not pertinent |
| ocean_data_tools | curated list of oceanographic software, not code itself | not pertinent |
| Ocean-Plastic-Assimilator | particle-dispersion data-assimilation program | not pertinent |
| OceanRobots.jl | ocean-observing-platform data access/processing | not pertinent |
| OceanScalingTests.jl | HPC scaling-test scripts | not pertinent |
| omd | optimal-transport analysis of oceanographic data | not pertinent |
| opedia | ocean-data visualisation database service | not pertinent |
| opedia_docs | documentation for opedia | not pertinent |
| osm2020tutorial | Pangeo cloud-analysis workshop | not pertinent |
| pangeo-julia-examples | Zarr/Pangeo usage examples | not pertinent |
| PhysicalOceanography.jl | early-stage oceanography teaching package | not pertinent |
| PlanktonIndividuals.jl | individual-based plankton model, CPU/GPU | not pertinent to this group (marine-ecosystem territory, not a dycore or framework) |
| plot_bathymetry | plotting script, empty README | not pertinent |
| PlutoCon2021-demos | conference demo notebooks | not pertinent |
| plutonotebooks | statistics teaching notebooks | not pertinent |
| pluto-on-binder | internal demo-link repo | not pertinent |
| pluto-on-jupyterlab | JupyterLab/Pluto integration glue | not pertinent |
| Sharpie.jl | joke/fake-content generator | not pertinent |
| SPEAD | phytoplankton adaptive-dynamics model | not pertinent to this group |
| speedy.f90 | the original Fortran SPEEDY GCM | not pertinent: superseded by SpeedyWeather.jl's own reference-arm record and decision 0012 |
| STAC.jl | SpatioTemporal Asset Catalog client | not pertinent: a satellite/geospatial data-discovery convention, not a store or grid interoperability concern (duplicate of the JuliaClimate group entry) |
| TeoBot.jl | joke bot | not pertinent |
| TheNumberLine.jl | K-12 teaching tool | not pertinent |
| TileProviders.jl | map-tile provider metadata | not pertinent |
| tmp2 | empty placeholder repo | not pertinent |
| Tracking_Julian | heat-wave event tracking/analysis package for spatiotemporal climate data | not pertinent |
| TS-lookup | salinity-inference code from a specific paper | not pertinent |
| Tyler.jl | Makie-based map-tile downloader/viewer | not pertinent |
| UROP-bootcamp | teaching exercises | not pertinent |
| verification_other | misc verification scripts, empty README | not pertinent |
| workshop2025 | hackathon resource hub | not pertinent |
| WorldOceanAtlasTools.jl | World Ocean Atlas data-access tools | not pertinent |
| www.julialang.org | Julia language website source | not pertinent |
| xysum | small utility, empty README | not pertinent |
| Zarr.jl | chunked, compressed N-dimensional array store | not pertinent to this group: already adopted, decision 0012 |

### JuliaClimate (14 repositories)

| repo | what it is | bears on | verdict |
| --- | --- | --- | --- |
| CDSAPI.jl | Copernicus Climate Data Store API client | - | not pertinent |
| ClimateBase.jl | DimensionalData-based lon/lat/time analysis toolkit (same package surveyed under gaelforget) | - | not pertinent: structured lat-lon array, already the rejected pattern |
| ClimatePlots.jl | plotting library for ClimateTools fields | - | not pertinent |
| ClimateSatellite.jl | satellite climate-data access | - | not pertinent |
| ClimateTools.jl | bias-correction/interpolation/shapefile toolkit | - | not pertinent |
| doctheme | Documenter.jl theme for the org's packages | - | not pertinent |
| Drifters.jl | Lagrangian trajectory analysis over gridded models | - | not pertinent to this group |
| INMET.jl | Brazilian meteorological-institute data API client | - | not pertinent |
| JuliaClimate | org meta-repo, a list of the org's packages | - | not pertinent |
| juliaclimate.github.io | org website | - | not pertinent |
| MeshArrays.jl | data structures for decomposed spherical grids (cubed sphere, tripolar, LLC) with a halo-exchange layer | 0005, 0013 | algorithmic reference, see below |
| meta | org discussion repo | - | not pertinent |
| Notebooks | demo notebook collection | - | not pertinent |
| STAC.jl | SpatioTemporal Asset Catalog client | - | not pertinent: satellite/geospatial cataloguing convention, not a store or interoperability concern for decision 0010 |

## Closer look

### SpeedyWeather.jl  --  the reference-arm record needs a refresh, not a new verdict

Read at `SpeedyWeather.jl` commit `60aff029`. The tree has been split into a five-package
monorepo since the reference-arm record (`docs/imports/speedyweather-reference-arm.md`)
was written: `LowerTriangularArrays`, `RingGrids`, `SpeedyTransforms`,
`SpeedyWeatherInternals` and `SpeedyWeather` itself, each with its own `Project.toml`
and test suite (`CLAUDE.md` in the tree documents the split). None of this changes the
record's verdict.

`SpeedyWeather/src/dynamics/planet.jl` confirms the record's central claim still holds
exactly: `Earth <: AbstractPlanet` carries `radius`, `rotation`, `gravity`,
`length_of_day`, `length_of_year` and `equinox` all defaulted to Earth's own values
(`DEFAULT_RADIUS = 6.371e6`, `EARTH_DAY = Hour(24)`, `EARTH_EQUINOX = DateTime(2000, 3,
20)`), which is exactly what the harness's "constructs its planet from our `System`
explicitly, every field" rule exists to override. `SpeedyWeather/src/dynamics/forcing.jl`
still exports `HeldSuarez` as a `SpectralGrid`-parameterised struct
(`HeldSuarez(SG::SpectralGrid; kwargs...)`), and `ocean.jl`/`land_sea_mask.jl` still
carry the aquaplanet setup the record's comparison protocol depends on, so the Held-Suarez
and aquaplanet configurations the record names are still there to construct.

What is new and worth a second look: `test/differentiability/` and `test/reactant/`
exercise Enzyme-based automatic differentiation through the full model, and
`SpeedyWeather/src/parameterizations/` is now explicitly composable (`abstract_types.jl`
plus one file per scheme: convection, large-scale condensation, radiation, surface
fluxes, vertical diffusion, land, sea ice, stochastic physics), which is what decision
0012's "borrow ideas" list already credits it for. Neither changes what is read from
the tree (still nothing; it runs beside the model, never in it), but the composable
parameterisation pattern is worth a look again when the atmosphere's own
parameterisation interface is designed, and the differentiability suite is worth a
look when decision 0033 (differentiability) is worked, both outside this group's
decisions.

**The question a closer look should answer:** does the current release tag (rather
than this working commit) still carry the same planet-struct shape and `HeldSuarez`/
aquaplanet constructors, so the version pin in the reference-arm record and its
`test/reference_arm/no_defaults.jl` harness sketch can be written against a real
version rather than "to pin".

### GeophysicalFlows.jl  --  an oracle arm for beta-plane turbulence and jet statistics

Read at `FourierFlows/GeophysicalFlows.jl` commit `886ce6b` (built on
`FourierFlows/FourierFlows.jl` commit `d801323`). `src/singlelayerqg.jl`,
`src/multilayerqg.jl`, `src/surfaceqg.jl` and `src/twodnavierstokes.jl` are
pseudospectral solvers on a periodic, doubly-Fourier beta-plane; there is no
sphere, no mesh, and nothing here could ever be a component under decision 0013's
one-mesh rule. That is not a reason to dismiss it: decision 0025's third tier is
exactly a published-spread comparison for "a one-parameter-away sweep with a
published multi-model record," and multi-layer QG baroclinic-turbulence
equilibria and barotropic/surface-QG energy-spectrum statistics are two of the
most heavily published such sweeps in the field (`examples/multilayerqg_2layer.jl`
is the canonical two-layer baroclinic-turbulence case). Landing this project's
own beta-plane or small-Rossby-number limit inside the published inter-model
spread for those statistics is evidence of the same kind decision 0025 already
asks for elsewhere; it is a genuinely new tier-3 protocol entry, not a
restatement of an existing one (`APE()`, `THAI_Hab1()`, `THAI_Hab2()` and
`HeldSuarez()` are all spherical protocols).

**The question a closer look should answer:** which published statistic
(the multi-layer QG baroclinic-turbulence energy spectrum slope, or the
barotropic/surface-QG inverse-cascade spectrum) has a genuine inter-model
spread this project's core could be checked against at the spacings and beta
values the shallow-water/baroclinic gate already produces, and what system
configuration (an f-plane or beta-plane patch of the triangle mesh, at what
size) would make the comparison honest rather than approximate.

### ShallowWaters.jl  --  precision as a type parameter, and where rescaling was needed

Read at `ShallowWaters.jl` commit `7ae91f2`. `src/default_parameters.jl` and
`src/model_setup.jl` show the shape decision 0011 asks for: a `Parameter` struct
carries `T` (the base number format), `Tprog` (prognostic-variable precision,
defaults to `T`), `Tcomm` (ghost-point communication precision, defaults to
`Tprog`) and `Tini` (initial-condition precision, defaults to `Tprog`), and every
state array (`PrognosticVars{T}`, the `DiagnosticVars{T,Tprog}` sub-structs) is
parameterised on these types rather than switched at runtime. That is a smaller,
working precedent for "precision is a type parameter" than anything else surveyed
here, and it demonstrates the part decision 0011 does not yet spell out: the four
independent precision knobs (state, communication, initial condition, and the
diagnostics' own working precision) that a single-precision-parameter design
would collapse into one.

What the tree also shows, and what the two cited papers (Klwer et al. 2019, 2020,
2022) measured, is *why* a bare type-parameter swap is not enough: `Parameter`
carries `scale = 2^6` (a multiplicative rescaling of the momentum equations) and
`scale_sst = 2^15` (rescaling of the SST tracer) whose entire purpose is to keep
the prognostic values inside the representable dynamic range of Float16 before
the reduced-precision kernels ever run; reduced precision failed first not in the
dynamics but in values falling outside a 16-bit format's useful range, and the fix
was a per-field rescaling declared beside the precision choice, not a numerical
scheme change. That is a candidate mechanism for what a low-precision kernel's
certification test (decision 0011: "each low-precision kernel certified against
its double-precision self") needs to check beyond bitwise/ulp comparison: whether
the field's own dynamic range fits the format, before the comparison is even run.

**The question a closer look should answer:** does this project's `Field` type
(decision 0006) need the same per-field or per-quantity rescaling declaration
ShallowWaters.jl makes explicit (`scale`, `scale_sst`), or does keeping
ledgers and reductions in double precision (decision 0011's stated rule) make
the rescaling unnecessary here because the quantities most sensitive to a
narrow dynamic range are exactly the ones already carried in Float64.

### MeshArrays.jl  --  structured face exchange, not a connectivity graph

Read at `JuliaClimate/MeshArrays.jl` commit `f812fc9` (an older personal fork
lives at `gaelforget/MeshArrays.jl` commit `9105671`, superseded by the canonical
org repo). `src/types/main.jl` defines `gcmgrid` with a `class::String` field, and
`src/exchanges/main.jl`'s `exchange!`/`exchange_main!` dispatch on that string:

```
if x.grid.class == "LatLonCap" || x.grid.class == "CubeSphere"
    ...
elseif x.grid.class == "PeriodicChannel"
    ...
elseif x.grid.class == "PeriodicDomain"
    ...
```

Each branch's face-adjacency and rotation logic is hand-written in its own file
(`src/exchanges/CubeSphere.jl`, 203 lines; `src/exchanges/PeriodicChannel.jl`, 72
lines; `src/exchanges/PeriodicDomain.jl`, 103 lines), keyed to a small,
closed, named enumeration of topologies rather than a graph the mesh declares.
`gcmfaces`, the `MeshArray` concrete type actually used, stores one dense
`Array{T,N}` per face plus a per-face size table (`fSize`); every face is a
structured `(i,j)` rectangle, and the exchange machinery's job is to know, for
each of the four named classes, which face's edge glues to which other face's
edge and with what rotation. That works well for a small fixed number of
quadrilateral faces (six for a cube sphere, five for LLC), and it does not
generalise to an arbitrary triangle connectivity graph without becoming, in
effect, a fifth hardcoded class per new topology: decision 0005's connectivity
graph exists precisely so a new topology (a strait opening, a graded-refinement
boundary) is data the exchange operator reads rather than a case a dispatch
statement enumerates. This tree is therefore a clean worked instance of the
class of defect decision 0013 is designed to avoid, not a source of exchange
code to reuse.

**The question a closer look should answer:** when the connectivity graph's own
exchange/halo operator is designed (decision 0005/0013), does it read the
graph generically enough that a strait-closing or graded-refinement topology
change requires no new code path at all, in the way MeshArrays' four
hardcoded classes each required one; CyclicArrays.jl's explicit face-connection
array (a four-dimensional table of face/direction adjacency, read rather than
branched on) is a second, more general worked example worth five minutes next
to this one.

### ClimateModels.jl  --  provenance as a git journal, not a content address

Read at `gaelforget/ClimateModels.jl` commit `7b3b51e`. `src/interface.jl`
defines `ModelConfig` with `ID :: UUID = UUIDs.uuid4()`: every run gets a fresh
random identifier at construction, independent of the model function, its
configuration, or its `inputs` dictionary. `pathof(x) = joinpath(x.folder,
string(x.ID))` makes that UUID the run's directory name, so two runs built from
identical inputs land in two different, unrelated directories with no shared
key. Provenance is tracked by `git_log_init`, `git_log_msg`, `git_log_fil` and
`git_log_prm`: a `log/` subfolder inside the run directory is its own git
repository, initialised with a README and then committed to as the run
proceeds (`tracked_parameters.toml` is committed as it changes; arbitrary output
files can be committed by name). `log(x)`, `log(x, commit_id)` and
`git_log_show` read that history back with `git log`/`git show`.

That is a genuinely useful pattern for "what happened during this run, in
order, with diffs" (`ModelConfig.channel`, an in-memory `Channel`, exists for the
same reason: a live status/log stream), and it is exactly what decision 0010
does not attempt (0010's manifests carry no chronological log, only the key that
identifies the object). But it answers a different question than decision 0010
asks. 0010 makes identity a hash over the code version, the declared parameter
subset, the input keys, the support id and the operator version, precisely so
that `plan(system, ladder, code)` can compute which artifacts a change reaches
without running anything and so that two runs with the same declared inputs are
recognised as the same run. `ClimateModels.jl`'s UUID-per-construction plus
per-run git history gives none of that: nothing in the tree computes "is this
run's identity already in the store," nothing recognises two runs as
equivalent, and a rerun with unchanged inputs produces a new UUID, a new
directory, and a new git history that has no relationship to the first except
by the human reading both logs. It is a weaker provenance model exactly along
the axis decision 0010 was written to fix, and useful mainly as a comparison
for what a content address buys that a run journal does not.

**The question a closer look should answer:** is there anything in
`git_log_msg`/`git_log_fil`'s per-run commit journal worth keeping as a
*human-readable companion* to the content-addressed store (a chronological
"what changed and why" narrative beside the hash-addressed manifest), or does
decision 0029's reproducibility record already cover that ground so the
pattern is fully redundant.

## Recommended rows

1. **Refresh `docs/imports/speedyweather-reference-arm.md`'s commit pin and package
   description** against the current five-package monorepo structure. Serves: keeping
   the existing oracle-arm record accurate. Timing: M3 (the dynamical-core milestone
   the reference arm is a deliverable of).
2. **Register a tier-3 oracle-registry entry for a GeophysicalFlows.jl beta-plane
   turbulence/jet comparison**, naming the specific published statistic and the
   protocol system it is anchored to, per decision 0025's tier-3 requirements. Serves:
   the oracle arm verdict on GeophysicalFlows.jl. Timing: M3.
3. **Write ShallowWaters.jl's rescaling pattern (`scale`, `scale_sst`) into the
   low-precision kernel certification plan** for decision 0011, alongside the
   bitwise/ulp comparison against the double-precision self. Serves: the algorithmic
   reference verdict on ShallowWaters.jl. Timing: M3 (the shallow-water gate is where
   the first reduced-precision kernels would be exercised).
4. **Name MeshArrays.jl's hardcoded-topology-class pattern as a rejected precedent**
   in the connectivity graph's own design notes, alongside CyclicArrays.jl's more
   general face-connection-array as a smaller worked alternative. Serves: the
   algorithmic reference verdict on MeshArrays.jl. Timing: now (bears on the M0 mesh
   hierarchy and connectivity graph).
5. **Decide whether a human-readable per-run commit journal belongs beside the
   content-addressed store**, informed by ClimateModels.jl's `log/` pattern, when the
   store's manifest format is implemented. Serves: the algorithmic reference verdict on
   ClimateModels.jl. Timing: now (bears on the M0 content-addressed store).

## Read at

| tree | commit |
| --- | --- |
| SpeedyWeather.jl | 60aff029 |
| FourierFlows/FourierFlows.jl | d801323 |
| FourierFlows/GeophysicalFlows.jl | 886ce6b |
| ShallowWaters.jl | 7ae91f2 |
| gaelforget/MeshArrays.jl | 9105671 |
| gaelforget/ClimateModels.jl | 7b3b51e |
| JuliaClimate/MeshArrays.jl | f812fc9 |
| gaelforget/Juls.jl | a377530 |
| gaelforget/gcmfaces | ad9159f |
| gaelforget/CyclicArrays.jl | 4c3ab9b |
| gaelforget/DGGS.jl | 060d976 |
| gaelforget/speedy.f90 | 7979838 |
| gaelforget/STAC.jl | 9f0160f |
| gaelforget/PlanktonIndividuals.jl | 0d11e33 |

Every other repository in gaelforget and JuliaClimate was read at its working-tree
state as of 2026-09-09 by its own README (no source reading, per the survey method:
most of these are notebooks, teaching material and data helpers, and a verdict of
`not pertinent` on a README alone is the point of the triage).
