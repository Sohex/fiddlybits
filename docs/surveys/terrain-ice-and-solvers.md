+++
epic = "fiddlybits-bon"
title = "Terrain, ice and solvers: the geodynamics GPU stack, shallow-ice ecosystems, flow routing and complementarity solvers"
trees = [
  "JuliaGeodynamics",
  "ParallelStencil.jl",
  "ImplicitGlobalGrid.jl",
  "ODINN-SciML",
  "fastflow",
  "whitebox_next_gen",
  "PATHSolver.jl",
]
status = "filed"
date = 2026-09-09
+++

This is the group the user asked to be combed through properly, and it repaid the
attention. Forty-one repositories were read; nine earn a real closer look (seven
write-ups below, two of them covering a package pair or trio read together) and one
tree is a name collision that would have wasted a milestone if it went unflagged.

Commit read at, by path (`git -C <path> rev-parse --short HEAD`):
`JuliaGeodynamics/AdriaArrayGeometryPicker.jl` ef8fedf,
`JuliaGeodynamics/CompGrids.jl` e24d421, `JuliaGeodynamics/DRex.jl` b36786b,
`JuliaGeodynamics/FiniteDiffWENO5.jl` 192ad34,
`JuliaGeodynamics/GeoBackwardsTracing.jl` df08a5b,
`JuliaGeodynamics/GeoDataPicker.jl` 4b589b2, `JuliaGeodynamics/geomIO` bfa40bd,
`JuliaGeodynamics/GeoParams.jl` 68ac1af,
`JuliaGeodynamics/GeophysicalModelGenerator.jl` 9e47c0f,
`JuliaGeodynamics/InjectSills.jl` 181059f,
`JuliaGeodynamics/InteractiveGeodynamics.jl` e10347c,
`JuliaGeodynamics/JustPIC.jl` 9fa5f6b, `JuliaGeodynamics/LaMEM.jl` d0e7364,
`JuliaGeodynamics/RheologyCalculator.jl` b089455,
`JuliaGeodynamics/TinyKernels.jl` 3879c88, `JuliaGeodynamics/WorldBuilder.jl` 572b90c,
`JuliaGeodynamics/ZirconGrowth.jl` b47c1d9,
`JuliaGeodynamics/ZirconIsotopeDiffusion.jl` f81d28e; `ParallelStencil.jl` 1f1c1f5;
`ImplicitGlobalGrid.jl` a8f2e36; `ODINN-SciML/Database-Exploration` fcdba19,
`ODINN-SciML/DiffEqSensitivity-Review` 44fae1a,
`ODINN-SciML/GlacierStripes.jl` 52bdcff, `ODINN-SciML/Glaciexplo` 24746ab,
`ODINN-SciML/Gungnir` fc858db, `ODINN-SciML/Huginn.jl` 0eb4e6d,
`ODINN-SciML/iceflow_sandbox` 38ad149, `ODINN-SciML/MassBalanceMachine` 65c357a,
`ODINN-SciML/MassBalanceMachine.jl` 05274c7, `ODINN-SciML/Muninn.jl` 7cbcf94,
`ODINN-SciML/ODINN.jl` c830cb6, `ODINN-SciML/ODINN-JOSS-paper` 833ffd0,
`ODINN-SciML/ODINN_notebooks` 993e810, `ODINN-SciML/oggm` 157c44b,
`ODINN-SciML/Sleipnir.jl` 76a9ed3, `ODINN-SciML/SphereUDE-examples` 6df92df,
`ODINN-SciML/SphereUDE.jl` 8837206,
`ODINN-SciML/universal_differential_equations` ebe7787; `fastflow` d476f66a;
`whitebox_next_gen` cd24675; `PATHSolver.jl` 704fbfe.

The three findings that matter most:

1. **The margin clamp fiddlybits' own audits already rejected is alive in the field's
   own reference implementation.** Huginn.jl (ODINN's shallow-ice solver) enforces
   `H >= 0` with `Hclip = map(x -> ifelse(x > 0.0, x, 0.0), H)`
   (`Huginn.jl/src/models/iceflow/SIA2D/SIA2D_utils.jl:63`), a plain clip, not the
   active-set or complementarity treatment REQ-CRY-001 requires. Räss and Omlin's own
   ParallelStencil.jl miniapp for a bound-constrained field does the same thing:
   `@inn(Phi) = max(0.0, @inn(Phi) + dt*@all(dPhidt))`
   (`ParallelStencil.jl/miniapps/scalar_porowaves2D.jl:32`). Two independent, mature
   codebases, built by people who know this physics, both reach for the clamp. That is
   not evidence the clamp is fine; decision 0019's water-table record already measured
   what a clamp costs (740 m3/s of invented seepage on a pinned cell that closure alone
   caught). It is evidence that the active-set solve REQ-CRY-001 and REQ-HYD-004
   demand is genuinely the harder, less-traveled road, and that fiddlybits should
   expect no shortcut from adjacent GPU-native codebases when it builds one.
2. **Gravity and density are already carried as explicit, overridable struct fields
   through the whole ODINN-SciML ice-flow stack**, not folded into a fitted
   coefficient: `PhysicalParameters` in Sleipnir.jl carries `ρ` and `g` as named
   fields (default 900.0, 9.81, both overridable), and Huginn.jl's diffusivity writes
   `gravity_term = ρ * g` then raises it to `n` or `p - q` explicitly
   (`SIA2D_utils.jl:86,93,98,105`), matching REQ-CRY-002's requirement almost exactly.
   GeoParams.jl does the same for the geodynamics side, with gravity as a
   `ConstantGravity` or `DippingGravity` struct rather than a literal. This is the
   encouraging finding of the survey: the pattern REQ-CRY-002 and REQ-TER-018 ask for
   (explicit `g`, no per-metre constant hiding it) is not a fiddlybits idiosyncrasy;
   it is achievable and already achieved elsewhere, which raises confidence that the
   discipline is realistic to hold.
3. **`fastflow` at `/home/cfutro/git/fastflow` is not the flow-routing algorithm
   the reasoning document named.** It is `github.com/fastflow/fastflow`, a C++
   structured-parallel-programming library from Pisa and Turin (task farms,
   pipelines, MPMC queues, distributed streaming), unrelated to Jain et al.'s
   GPU flow-accumulation and depression-hierarchy algorithm referenced in
   `reference_repos_desc.md` and behind decision 0019's parallel-routing question.
   The tree earns `not pertinent` on its own content, and the real target is
   unaddressed: whoever plans the M2 hydrology row needs to locate Jain et al.
   (2024)'s actual code or reimplement from the paper, because this survey found
   nothing to read on that specific question.

## Repositories

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| JuliaGeodynamics/GeophysicalModelGenerator.jl | 3D planetary geometry, layer setup and an age-dependent 1D conductive geotherm solver (`LithosphericTemp`) | 0015 | algorithmic reference | M1 |
| JuliaGeodynamics/GeoParams.jl | a general material-parameter and rheology library with gravity as a runtime struct, not a literal | 0015 | algorithmic reference | M1 |
| JuliaGeodynamics/LaMEM.jl | Julia interface to LaMEM, a Fortran/C+PETSc visco-elasto-plastic thermomechanical solver, downloaded as a binary | 0015 | algorithmic reference | M1 |
| JuliaGeodynamics/WorldBuilder.jl | Julia interface to the Geodynamic World Builder: a declarative feature language (plates, ridges, cratons) with half-space-cooling thermal models per feature | 0015 | algorithmic reference | M1 |
| JuliaGeodynamics/JustPIC.jl | GPU particle-in-cell / semi-Lagrangian material advection on KernelAbstractions | - | not pertinent: tracks material advecting through a deforming mesh, which is exactly what 0015 declares a scope exclusion (no plate advection or remeshing during `T_int`) |
| JuliaGeodynamics/RheologyCalculator.jl | a point-wise (0D) Newton solver composing viscous/elastic/plastic constitutive elements | - | not pertinent: 0015 has no active visco-elasto-plastic composite solve (flexure is linear-elastic, thermal subsidence is a conductive analytic form); nothing in the terrain record calls a rheology composition solver |
| JuliaGeodynamics/TinyKernels.jl | a second GPU kernel abstraction (CUDA/ROCm/limited Metal) | - | not pertinent: decision 0012 already committed to KernelAbstractions.jl |
| JuliaGeodynamics/CompGrids.jl | a thin grid-setup convenience layer over ParallelStencil or PETSc, assuming MPI | - | not pertinent: no physics content, and its multi-process assumption does not fit decision 0009's one-process design |
| JuliaGeodynamics/AdriaArrayGeometryPicker.jl | a GUI for one regional seismic-array dataset | - | not pertinent: Earth-specific instrument tooling |
| JuliaGeodynamics/DRex.jl | crystal-fabric seismic anisotropy evolution | - | not pertinent: fiddlybits has no seismic-anisotropy subsystem |
| JuliaGeodynamics/FiniteDiffWENO5.jl | a WENO5 finite-difference advection scheme | - | not pertinent: no shock-capturing compositional advection exists in the terrain or mantle scope |
| JuliaGeodynamics/GeoBackwardsTracing.jl | postprocessing backward particle tracing for P-T-t paths | - | not pertinent: petrology postprocessing with no analogue here |
| JuliaGeodynamics/GeoDataPicker.jl | a web GUI layered on GeophysicalModelGenerator.jl | - | not pertinent: interactive tool, no algorithm beyond GMG itself |
| JuliaGeodynamics/geomIO | 2D-cross-section-to-3D-solid geometry construction for CAD/3D printing | - | not pertinent |
| JuliaGeodynamics/InjectSills.jl | analytic elastic-half-space displacement solutions for sills and dikes | - | not pertinent: no magmatic intrusion subsystem exists or is planned |
| JuliaGeodynamics/InteractiveGeodynamics.jl | teaching GUIs wrapping LaMEM | - | not pertinent |
| JuliaGeodynamics/ZirconGrowth.jl | zircon crystal growth and trace-element modelling | - | not pertinent |
| JuliaGeodynamics/ZirconIsotopeDiffusion.jl | zircon isotope diffusion, a MATLAB port, not yet coupled to anything | - | not pertinent |
| ParallelStencil.jl | architecture-agnostic stencil macros with pseudo-transient (PT) relaxation for stiff nonlinear multi-physics | 0019, 0020, REQ-HYD-004, REQ-CRY-001 | algorithmic reference | M2 |
| ImplicitGlobalGrid.jl | MPI halo exchange for multi-GPU/multi-node domain decomposition | - | not pertinent: decision 0009 runs the whole coupled system in one process; there is no multi-node domain to decompose |
| ODINN-SciML/Sleipnir.jl | glacier state, parameter and simulation-config types for the ODINN ecosystem | 0020, REQ-CRY-002 | algorithmic reference | M10 |
| ODINN-SciML/Huginn.jl | the SIA2D shallow-ice solver: diffusivity, sliding, margin handling, explicit adaptive time-stepping, a Halfar-solution test | 0020, REQ-CRY-001, REQ-CRY-002 | algorithmic reference | M10 |
| ODINN-SciML/Muninn.jl | glacier surface mass balance: temperature-index models with one or two degree-day factors | 0020 | algorithmic reference (negative) | M10 |
| ODINN-SciML/ODINN.jl | the top-level orchestrator coupling Sleipnir/Huginn/Muninn through SciML universal differential equations for parameter learning | - | not pertinent: the UDE/inverse-learning machinery is exactly what fiddlybits does not want; the physics it orchestrates is read directly from the three packages above |
| ODINN-SciML/MassBalanceMachine.jl | ports MassBalanceMachine's neural-network (Lux.jl) mass-balance models into Muninn as `MBmodel`s | - | not pertinent: a second, statistical mass-balance route, same objection as the temperature-index route, sharper |
| ODINN-SciML/MassBalanceMachine | the Python source project: ML-based point mass-balance modelling from geodetic and glaciological data | - | not pertinent: Earth glacier data science, not a physical scheme |
| ODINN-SciML/SphereUDE.jl | non-parametric regression of data on the sphere via neural ODEs | - | not pertinent: a statistical interpolation tool, no physics |
| ODINN-SciML/SphereUDE-examples | example notebooks for SphereUDE.jl | - | not pertinent |
| ODINN-SciML/Gungnir | OGGM-based preprocessing of real DEM and climate reanalysis data for ODINN | - | not pertinent: Earth-specific data ingestion pipeline |
| ODINN-SciML/oggm | vendored copy of the Python OGGM open global glacier model, used here as Gungnir's data backend | - | not pertinent: Earth-specific glacier inventory and climate data pipeline, not Julia, not this project's concern |
| ODINN-SciML/iceflow_sandbox | experimental coupling of a Julia SIA model into OGGM's Python driver loop | - | not pertinent: an integration experiment, no physics beyond what Huginn.jl already gives directly |
| ODINN-SciML/Database-Exploration | tooling to intersect glacier inventory and velocity databases (RGI, Theia, Millan et al.) | - | not pertinent: Earth glacier data wrangling |
| ODINN-SciML/Glaciexplo | a Python tool for choosing which real glaciers to study, by data availability | - | not pertinent |
| ODINN-SciML/GlacierStripes.jl | a "climate stripes" visualization for a glacier's mass-balance history | - | not pertinent: a plotting tool |
| ODINN-SciML/DiffEqSensitivity-Review | a LaTeX review paper on differentiable-programming sensitivity methods | - | not pertinent: a paper, not code; adjacent to decision 0033 but not this group's question |
| ODINN-SciML/universal_differential_equations | the companion repository to the Rackauckas et al. UDE paper | - | not pertinent: generic SciML methodology, no glacier or terrain content |
| ODINN-SciML/ODINN-JOSS-paper | the JOSS journal-article source for ODINN.jl | - | not pertinent: a paper |
| ODINN-SciML/ODINN_notebooks | demonstration Jupyter notebooks | - | not pertinent |
| fastflow | github.com/fastflow/fastflow: a C++ structured-parallel-programming library (task farms, pipelines, MPMC queues) | - | not pertinent: a name collision; not Jain et al.'s GPU flow-routing algorithm named in the reasoning document. See finding 3 above. |
| whitebox_next_gen | the Rust rewrite of WhiteboxTools (John Lindsay): least-cost depression breaching, wetness-index and flow-routing tools | 0019, REQ-HYD-004, REQ-HYD-005 | algorithmic reference | M2 |
| PATHSolver.jl | Julia wrapper for the PATH solver, the standard benchmark for mixed complementarity and LCP problems | 0019, REQ-HYD-004, 0025 | oracle arm | M2 |

Counts: 41 repositories surveyed. 31 not pertinent, 9 algorithmic reference (one of
those, Muninn.jl, negatively - what to avoid rather than what to borrow), 1 oracle arm,
0 import review.

## Closer look

### JuliaGeodynamics/GeophysicalModelGenerator.jl

`Setup_geometry.jl` defines `LithosphericTemp` (line 1521) and its solver
`compute_thermal_structure` (line 1551): an age-dependent 1D conductive geotherm, not
the closed-form half-space-cooling formula decision 0015 uses, but a transient
explicit finite-difference diffusion (`SolveDiff1Dexplicit_vary!`) run forward from an
adiabatic initial profile for the plate's age, with density, heat capacity,
conductivity and radiogenic heat production read per-phase from a `GeoParams.jl`
rheology struct rather than hardcoded. It reproduces what a closed-form half-space
cooling solution gives in the constant-property limit, but generalises past it: it
carries radiogenic heat production and depth-varying conductivity, which the pure
Turcotte-and-Schubert form decision 0015 currently uses does not.

The closer look decision 0015's geotherm row should answer: does the age-dependent
basal heat flux and cover-class thermal subsidence this project derives from the
lithosphere block ever need to carry a depth-varying conductivity or a radiogenic-heat
term that the closed-form half-space solution cannot express (a thick sedimentary
cover with different `k` than basement, for instance)? If so, this transient 1D
explicit solve - or the general shape of it - is the fallback path to read before
writing one from scratch, and the question of whether its stability criterion
(`dtfac * dz^2 / 2κ`) is cheap enough to run once per province at seed time, not per
timestep, should be checked before ruling it out on cost.

### JuliaGeodynamics/GeoParams.jl

`GravitationalAcceleration.jl` defines gravity as a material-parameter struct
(`ConstantGravity`, `DippingGravity`) read at the use site rather than a compiled-in
literal, with a default of `9.81 m/s^2` that every constructor can override. This is
the shape decision 0004's lithosphere block and REQ-CRY-002 already require of
fiddlybits' own code, demonstrated in a mature, independently-built library that
serves the same rheology-and-thermal-structure domain the brief points to.

The closer look: GeoParams.jl's `CreepLaw`, `Plasticity` and `Viscosity` submodules
are a candidate vocabulary check for whatever fiddlybits eventually writes for
crustal rheology (currently decision 0015 needs only elastic flexure and a conductive
geotherm, neither of which touches creep or plasticity) - the question is whether a
future decision extending 0015 toward active deformation should borrow GeoParams'
dispatch pattern (a parameter struct type dispatching to a `compute_*` function) or
whether that collides with decision 0007's own tracked-constant wrapper, which already
serves the same "where did this value come from" purpose by a different mechanism.

### JuliaGeodynamics/LaMEM.jl

`LaMEM.jl` is a thin Julia wrapper (`run_lamem`, `IO_functions.jl`) around a downloaded
PETSc-based Fortran/C binary; `Model`, `Phase`, `Grid` and `SolutionParams` in
`LaMEM_ModelGeneration/` are Julia-side setup structs that get serialised out to the
binary's input format, with `SolutionParams.jl` and `Multigrid.jl` exposing the direct
and multigrid solver choices LaMEM itself offers for the visco-elasto-plastic Stokes
problem.

The closer look: LaMEM is the most complete answer available anywhere in this survey
to "how does a mature code express visco-elasto-plastic rheology and thermal
structure in a way that stays general in gravity and material properties" (its `Phase`
struct takes `eta`, `rho` per phase as GeoParams rheology objects, not literals) - but
it is a compiled external binary, not GPU-native, not on KernelAbstractions, and not a
fit for decision 0011's portable-kernel rule. The question for whoever eventually
extends decision 0015 toward active crustal deformation (if that is ever proposed) is
narrow: read LaMEM's solver-option struct and its multigrid preconditioner choices as
prior art on what a visco-elasto-plastic Stokes solve needs to expose, without
importing the binary itself.

### JuliaGeodynamics/WorldBuilder.jl

The README's own quick-start example builds an `OceanicPlate` feature with
`OceanicPlateHalfSpaceModelTemperature(max_depth=100e3, spreading_velocity=0.04,
ridge_coordinates=...)` - a declarative, per-feature half-space cooling thermal model,
composed alongside `MantleLayer` and other feature types into a `World`. This is
close in spirit to decision 0015's tectonic seed: named features (arcs, ridges,
cratons, hotspot traces) each carrying their own age and thermal-structure rule, which
the seed already declares as "requestable features" a configuration can ask for.

The closer look: WorldBuilder.jl wraps the Geodynamic World Builder, a C++ library
called once at setup (not per-timestep), so the GPU/KernelAbstractions objection that
rules out LaMEM does not automatically apply here - but CLAUDE.md's rule that
"conventions travel by name, never by coordinate; there are no translation layers"
cuts the other way: GWB's own coordinate and composition conventions would need
exactly the kind of translation layer this project refuses. The question is whether
the tectonic seed's own Voronoi-plate feature language should simply borrow
WorldBuilder's vocabulary of composable named features (a design idea, free to take)
rather than the library (a binary dependency, not free to take), and whether GWB's
half-space cooling implementation is worth reading once as a second, independent
statement of the same Turcotte-and-Schubert form decision 0015 already cites, as a
cheap cross-check rather than a dependency.

### ParallelStencil.jl

The README describes "second order pseudo-transient relaxation" delivering "implicit
solutions" for stiff nonlinear coupled multi-physics (`README.md:455`), demonstrated
on Stokes flow, thermal convection and porous waves. The `scalar_porowaves2D.jl`
miniapp enforces its one bound constraint (porosity `Phi >= 0`) with a plain clamp at
the end of every pseudo-transient step (line 32: `@inn(Phi) = max(0.0, @inn(Phi) +
dt*@all(dPhidt))`) rather than any active-set or projection treatment.

The closer look, and it is the central question of this whole tree for fiddlybits:
pseudo-transient relaxation is built to drive a smooth nonlinear PDE to steady state
by adding a physically-motivated damped-inertia term and iterating an explicit update;
nothing in the method as demonstrated here handles an inequality constraint natively,
and the one place PT meets a bound constraint in this codebase, it reaches for the
same clamp decision 0019's own audit measured inventing 740 m3/s of seepage. REQ-HYD-004
and REQ-CRY-001 both require the constraint solved as an active set, never a clip. The
question to answer before deciding whether PT is any part of the water-table or
ice-margin solver: can a PT iteration be wrapped in an outer active-set loop (freeze
cells at their bound, PT-relax the free set, release cells whose residual says they
should be free, repeat - the same shape REQ-HYD-004's uniqueness identity already
requires as "two active-set trajectories, from all-free and all-pinned, must reach the
one solution") without losing the damped-inertia contraction property Räss et al.
rely on for convergence, or does the constraint have to be handled by a fundamentally
different iteration (projected SOR, multigrid with a projected smoother) with PT
reserved for the unconstrained smooth stages elsewhere in the model (Stokes,
diffusion). This question is worth resolving before M2's water-table solver and M10's
ice-margin solver are designed, not after.

### ODINN-SciML/Sleipnir.jl, Huginn.jl and Muninn.jl

Read together because they are one ecosystem: Sleipnir.jl's `PhysicalParameters`
(`parameters/PhysicalParameters.jl:28`) carries `ρ` (default 900.0) and `g` (default
9.81) as ordinary struct fields, alongside `DDF_min`/`DDF_max` fields whose docstring
names them "degree-day factor for TI model calibration" - the temperature-index route
is not an afterthought, it is wired into the parameter struct's own numerical bounds.
Huginn.jl's `SIA2D!` (`models/iceflow/SIA2D/SIA2D_utils.jl:36`) computes
`gravity_term = ρ * g` once and raises it to `n.value` for the deformation term and to
`p.value - q.value` for the Weertman-type sliding term (lines 86-107), which is
algebraically the overburden convention REQ-CRY-002 asks for (substituting `tau_b ~
rho g H |grad z_S|` and `N ~ rho g H` into a `C tau_b^p / N^q` sliding law gives
exactly this `H^(p-q+1)` and `gravity_term^(p-q)` form) even though the code never
names `N` as a separate quantity the way fiddlybits' erosion law (REQ-TER-013) needs
to read it. The margin clamp is at line 63, covered in finding 1 above. The solver
(`parameters/SolverParameters.jl:37`) defaults to `RDPK3Sp35()`, an explicit adaptive
Runge-Kutta scheme from OrdinaryDiffEq, matching decision 0020's "explicit time
stepping with adaptive substeps." `models/solutions/halfar.jl` already implements the
Halfar similarity solution as a test fixture, independently confirming that REQ-CRY-001's
choice of the Halfar dome as the exact test is the field's own standard, not a
fiddlybits invention. Muninn.jl's `MBmodel.jl` (`TImodel1`, `TImodel2`, lines 53-131)
is a pure positive-degree-day scheme with one or two degree-day factors converting
temperature excess directly to melt - exactly the "Earth calibration of ablation
against air temperature" decision 0020 names and rejects, with no energy-balance
alternative anywhere in the package.

The closer look this pairing earns: read Huginn.jl's sliding-law algebra once, closely,
as a worked cross-check that fiddlybits' own `N = rho_i g H` formulation and REQ-CRY-002's
dimension-carrying sliding coefficient produce the same diffusivity form when
substituted through - a cheap identity check before the fiddlybits solver is written,
not a code borrow. Separately: Huginn.jl's margin clamp and Muninn.jl's
temperature-index scheme are both examples to name explicitly in whatever design note
motivates REQ-CRY-001's active-set requirement and decision 0020's energy-balance
choice, as evidence that the easier, wrong answer is the one a mature adjacent
ecosystem actually shipped, not a strawman.

### whitebox_next_gen

`crates/wbtools_oss/src/tools/hydrology/mod.rs` (line 3389, `BreachDepressionsLeastCostTool`)
wraps a Dijkstra-style least-cost search (`breach_depressions_least_cost_core`, line 1879,
following Lindsay 2016) that only ever lowers a cell's elevation down to a computed
`desired` value along the cheapest path to an outlet (line 1992: `if data[ti] > desired
{ data[ti] = desired; }`), bounded by an explicit `max_cost` and `max_dist`, with an
optional fall-back fill for whatever breaching could not resolve within those bounds.
It never raises the DEM and never touches a water-volume field; "not inventing water"
here means the tool conditions geometry only, under an explicit, auditable search-cost
budget, rather than snapping a channel to a threshold or filling a basin outright. The
wetness-index tool (`geomorphometry/terrain_analysis_tools.rs:8465`,
`run_wetness_index`) computes the classic `ln(a / tan(beta))` topographic index
directly from flow accumulation and slope, with a second SAGA-variant form
(`saga_wetness_index`, line 8706) available beside it, each tested against its
published formula (`terrain_analysis_tools.rs:9727,9748`).

The closer look: REQ-HYD-005 forbids exactly the class of thing a threshold-breaching
tool could tempt a builder toward (an absolute, non-transporting index threshold) -
the question is whether whitebox_next_gen's own `max_cost`/`max_dist` parameterisation
of the breaching search should be read as a `Bracketed` disposition candidate for
however fiddlybits' terrain conditioning (if any is needed on the triangle mesh, as
opposed to relying entirely on the depression hierarchy and fill-spill-merge of
decision 0019) bounds its own search, and separately whether this Rust
implementation's least-cost formulation generalises off a regular raster onto an
unstructured triangle mesh with an explicit connectivity graph, which decision 0019
needs and this tool, built for gridded DEMs, does not demonstrate - that gap is worth
naming rather than assuming closed.

### PATHSolver.jl

The README states plainly: the Julia wrapper (`src/C_API.jl`, `src/MOI_wrapper.jl`) is
MIT-licensed, but the underlying PATH binary is closed source and requires a licence.
Without one, PATH solves problems up to 300 variables and 2000 non-zeros; a free
one-year academic licence is available beyond that from the PATH maintainers'
temporary-licence page. `solve_mcp` (`C_API.jl:707,886`) exposes exactly the box-constrained
mixed complementarity interface REQ-HYD-004 needs: variable bounds, a residual function,
and (for the C API route) a caller-supplied Jacobian.

The closer look: REQ-HYD-004's own tier-1 identities (Dupuit parabola, spherical
Laplacian eigenvalues at two mesh levels) are exactly the small, synthetic-scale
problems the 300-variable free tier can hold, so PATHSolver.jl is usable as a tier-1
oracle arm without an academic licence for the identity-scale checks decision 0025
runs per commit - the question that needs answering before it is registered as an
oracle is whether the C4 mutation-run scale (a "production operator at production
size" per REQ-HYD-004) also needs PATH, in which case the academic licence has to be
requested and its renewal terms tracked as an operational dependency of the nightly
or milestone gate, not just the per-commit tier-1 suite.

## Recommended rows

- **Read Huginn.jl's SIA2D diffusivity and margin clamp, and Muninn.jl's temperature-index
  scheme, as named counter-examples when REQ-CRY-001 and decision 0020's mass-balance
  choice are next revisited.** Serves: algorithmic reference (negative). Timed to M10,
  before the fiddlybits shallow-ice solver's design note is written.
- **Resolve whether pseudo-transient relaxation can carry an active-set/projection
  outer loop for the water table and ice margin, or whether those need a different
  iteration with PT reserved for unconstrained stages.** Serves: algorithmic reference.
  Timed to M2 (water table), revisited at M10 (ice margin) if the answer differs by
  problem.
- **Register PATHSolver.jl as the tier-1 oracle arm for REQ-HYD-004's identity-scale
  checks, and separately confirm whether the C4 mutation-run scale needs the licensed
  tier.** Serves: oracle arm, per decision 0025. Timed to M2, before the water-table
  solver's oracle registry entries are written.
- **Locate the actual Jain et al. (2024) GPU flow-routing and depression-hierarchy
  code (not `/home/cfutro/git/fastflow`, which is a name collision) or budget a
  from-paper reimplementation, and separately read whitebox_next_gen's least-cost
  breaching as a bounded, non-inventing conditioning reference.** Serves: closing the
  gap finding 3 leaves open, and an algorithmic reference for whitebox_next_gen.
  Timed to M2, before decision 0019's routing implementation begins.
- **Read GeophysicalModelGenerator.jl's `LithosphericTemp` transient geotherm solver
  and WorldBuilder.jl's per-feature half-space-cooling model as a cross-check on
  decision 0015's closed-form thermal subsidence, and note GeoParams.jl's
  gravity-as-struct-field pattern as confirmation the discipline REQ-CRY-002 and
  REQ-TER-018 ask for is already achieved elsewhere.** Serves: algorithmic reference.
  Timed to M1, before the terrain snapshot's lithosphere/geotherm code is written.
