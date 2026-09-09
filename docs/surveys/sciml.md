+++
epic = "fiddlybits-bon"
title = "The reference-tree triage: sciml"
trees = ["/home/cfutro/git/SciML"]
status = "filed"
date = "2026-09-09"
+++

## What this group is

`/home/cfutro/git/SciML` is the SciML organisation's tree: 224 directories at commit
hashes recorded per repository below (each read individually; the tree itself carries
no single commit). Most of it is the "SciML common interface" -- `SciMLBase.jl`'s
`Problem`/`solve`/`Solution` protocol -- and its downstream solvers for ODEs, SDEs,
DDEs, DAEs, BVPs, PDEs, jump processes, nonlinear systems, optimisation, symbolic
modelling (`ModelingToolkit.jl`), and machine-learning-adjacent packages (neural ODEs,
operator learning, surrogates). None of that protocol is wanted here: decision 0009
and decision 0023 already commit this project to owning its own loop and its own
state, and decision 0012 has already declined `ModelingToolkit.jl` and the
differential-equations stack for the columns by name. What is wanted, and present,
sits in a much narrower slice: statically sized, non-allocating root solvers meant to
run inside a GPU kernel, and a small number of narrow tools (order-condition
generation, a complementarity solver with native GPU batching, tiny in-kernel linear
algebra) that a reader could otherwise miss inside 224 repositories.

Three findings matter most:

1. **`SimpleNonlinearSolve.jl`'s bracketing methods are exactly the Kepler solver
   decision 0008 requires**, and it is demonstrated, not just claimed: the package's own
   test suite launches `solve(prob, alg)` from inside a `@cuda` kernel
   (`NonlinearSolve.jl/lib/SimpleNonlinearSolve/test/gpu/cuda_tests__item2.jl`), and
   the bracketing loop (`internal_bisection` in
   `NonlinearSolve.jl/lib/BracketingNonlinearSolve/src/bisection.jl`) is a plain scalar
   loop with a tolerance derived from the floating-point type
   (`NonlinearSolveBase.jl`'s `get_tolerance`), never a chosen literal. The one thing
   the demonstration does not cover is `KernelAbstractions.@kernel` specifically (the
   test uses raw `CUDA.@cuda`); nothing in the loop suggests that matters, but it is
   the honest gap.
2. **`OrdinaryDiffEq.jl`'s multirate and IMEX integrators are welded to the SciMLBase
   problem/solution/callback stack that decision 0023 already declines**, in a way
   `ClimaTimeSteppers.jl` (`docs/imports/climatimesteppers-jl.md`) is not:
   `OrdinaryDiffEqCore`'s `Project.toml` depends directly on `SciMLBase`, `DiffEqBase`,
   `RecursiveArrayTools`, `SciMLOperators`, `SciMLStructures` and
   `SymbolicIndexingInterface`, none of which `ClimaTimeSteppers.jl` needs. The
   numerical schemes overlap heavily (IMEX-ARK, SSP-RK, low-storage and multirate
   methods exist in both), so the comparison is a dependency-weight question, not a
   scheme-availability one, and it comes out the same way decision 0012 already argued
   for the columns: the lighter package wins.
3. **A dependency carried by `OrdinaryDiffEqCore` is a live reproducibility hazard**:
   `FastPower.jl`, an opt-in approximate `x^y` that trades roughly twelve digits of
   `Float64` accuracy for speed, is a direct dependency of `OrdinaryDiffEqCore`'s
   `Project.toml`. If the multirate/IMEX integrators were ever adopted despite finding
   1, decision 0011's ulp-ensemble certification would have to trace every call site
   before trusting the reservoir- and ledger-adjacent arithmetic.

## Every repository

`repo` names the directory under `/home/cfutro/git/SciML`; `what it is` is one clause;
`bears on` names a decision or requirement id, or `-`; `when` follows decision 0034's
build order, or `-` for `not pertinent`.

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| 2025-JuliaCon-DifferentialEquations-Workshop | workshop notes for `DifferentialEquations.jl` | - | not pertinent | - |
| ADTypes.jl | marker types for choosing an AD backend by dispatch, no AD engine itself | 0033 | import review | now |
| AlgebraicDiffEq.jl | old DAE solver bindings | - | not pertinent | - |
| AudioPlugins.jl | audio-plugin hosting (CLAP/LV2), unrelated domain | - | not pertinent | - |
| AutoOffload.jl | experimental auto GPU-offload heuristic | - | not pertinent | - |
| AutoOptimize.jl | experimental "make my code faster automatically" package | - | not pertinent | - |
| BaseModelica.jl | Modelica model import for ModelingToolkit | 0012 | not pertinent | - |
| BinaryHeaps.jl | binary heap extracted from DataStructures.jl for latency | - | not pertinent | - |
| BipartiteGraphs.jl | bipartite-graph utility backing ModelingToolkit's structural analysis | 0012 | not pertinent | - |
| BlackBoxOptim.jl | global stochastic optimisation (DE, NES) | - | not pertinent | - |
| BorderedLinearSolve.jl | bordered linear systems for continuation/bifurcation, built on LinearSolve.jl | 0012 | not pertinent | - |
| BoundaryValueDiffEq.jl | boundary-value ODE solvers | - | not pertinent | - |
| BridgeDiffEq.jl | bindings to Bridge.jl for SDE bridge sampling | - | not pertinent | - |
| CasADi.jl | bindings to the CasADi optimal-control library | - | not pertinent | - |
| Catalyst.jl | chemical reaction network DSL atop ModelingToolkit | 0012 | not pertinent | - |
| CatalystNetworkAnalysis.jl | reaction-network structural analysis, pre-release | - | not pertinent | - |
| Catalyst_PLOS_COMPBIO_2023 | benchmark code accompanying a Catalyst paper | - | not pertinent | - |
| CellMLToolkit.jl | imports CellML biology models into ModelingToolkit | 0012 | not pertinent | - |
| CKTSO.jl | wrapper for a proprietary (licence-key) sparse circuit solver | 0012 | not pertinent | - |
| ColPrac | contributor collaboration-practices document | - | not pertinent | - |
| CommonSolve.jl | defines the generic `solve`/`init` verbs SciMLBase dispatches on | 0012 | not pertinent | - |
| CommonWorldInvalidations.jl | compiler-invalidation-latency mitigation tool | - | not pertinent | - |
| ComplementaritySolve.jl | LCP/MCP solvers with native CUDA batching and PSOR/PGS/interior-point methods | REQ-HYD-004 | algorithmic reference | M2 |
| ComponentArrays.jl | labelled-component state vectors for ODE problems | 0012 | not pertinent | - |
| ConcreteStructs.jl | macro forcing concrete struct fields | - | not pertinent | - |
| Corleone.jl | dynamic optimisation / multiple-shooting trajectory optimiser | - | not pertinent | - |
| CurveFit.jl | curve-fitting utilities | - | not pertinent | - |
| DASKR.jl | Fortran DASKR DAE solver binding | - | not pertinent | - |
| DASSL.jl | DASSL DAE algorithm implementation | - | not pertinent | - |
| DataCollocations.jl | non-parametric smoothing/derivative estimation from data | - | not pertinent | - |
| DataDrivenDiffEq.jl | SINDy-style equation discovery from measured trajectories | - | not pertinent | - |
| DataInterpolations.jl | generic 1D interpolation library | - | not pertinent | - |
| DataInterpolationsND.jl | generic N-D interpolation library | - | not pertinent | - |
| Dedalus.jl | spectral PDE solver (Cartesian/cylindrical/spherical-ball), not an icosahedral C-grid | 0005 | not pertinent | - |
| DEDataArrays.jl | deprecated array type for mixed continuous/discrete ODE state | - | not pertinent | - |
| DeepEquilibriumNetworks.jl | implicit-layer neural networks | - | not pertinent | - |
| DelayDiffEq.jl | delay-ODE solvers, moved into `OrdinaryDiffEq.jl`'s sublibraries; no delay physics here | - | not pertinent | - |
| deSolveDiffEq.jl | binding to R's deSolve | - | not pertinent | - |
| DiffEqApproxFun.jl | old ApproxFun-based PDE discretisation for DiffEq | - | not pertinent | - |
| DiffEqBase.jl | moved into `OrdinaryDiffEq.jl`'s sublibraries; stale stand-alone snapshot | 0012 | not pertinent | - |
| DiffEqBayes.jl | Bayesian parameter estimation for DiffEq problems | - | not pertinent | - |
| DiffEqBenchmarkServer.jl | web bot infrastructure for a benchmark server | - | not pertinent | - |
| DiffEqCallbacks.jl | prebuilt event callbacks for OrdinaryDiffEq's integrator; this project owns its own loop | 0023 | not pertinent | - |
| DiffEqDevDocs.jl | developer documentation | - | not pertinent | - |
| DiffEqDevMaterials | development materials, no README | - | not pertinent | - |
| DiffEqDevTools.jl | convergence-order testing harness for DiffEq solvers | - | not pertinent | - |
| DiffEqDiagrams.jl | diagram assets, no README | - | not pertinent | - |
| DiffEqDocs.jl | documentation source | - | not pertinent | - |
| DiffEqDSL.jl | old macro DSL for ODE definitions | - | not pertinent | - |
| DiffEqFinancial.jl | financial-model ODE/SDE problem library | - | not pertinent | - |
| DiffEqFlux.jl | neural ODE / universal differential equation layers | 0033 | not pertinent | - |
| DiffEqGPU.jl | ensembles-of-small-ODEs-on-GPU via the SciMLBase problem stack | 0023 | not pertinent | - |
| DiffEqIO.jl | ODE problem serialisation | - | not pertinent | - |
| DiffEqMonteCarlo.jl | Monte Carlo ensemble solving, superseded | - | not pertinent | - |
| DiffEqNoiseProcess.jl | noise processes for SDE solvers | - | not pertinent | - |
| DiffEqOnline | front-end for a browser DiffEq demo | - | not pertinent | - |
| DiffEqOnlineServer | back-end for the same demo | - | not pertinent | - |
| DiffEqOperators.jl | old finite-difference operator library for PDEs | - | not pertinent | - |
| DiffEqParamEstim.jl | parameter estimation for DiffEq problems | - | not pertinent | - |
| DiffEqPDEBase.jl | old shared base for PDE-DiffEq packages | - | not pertinent | - |
| DiffEqPhysics.jl | `HamiltonianProblem` for AD-based Hamiltonian systems | - | not pertinent | - |
| DiffEqProblemLibrary.jl | premade test/example ODE problems | - | not pertinent | - |
| diffeqpy | Python binding for DifferentialEquations.jl | - | not pertinent | - |
| DiffEqPy.jl | older Python binding, superseded by diffeqpy | - | not pertinent | - |
| diffeqr | R binding for DifferentialEquations.jl | - | not pertinent | - |
| DiffEqWebBase.jl | shared base for the web demo | - | not pertinent | - |
| DifferenceEquations.jl | discrete-time (macro/econ) difference-equation solving | - | not pertinent | - |
| DifferentialEquations.jl | umbrella meta-package bundling the whole DiffEq stack | 0012, 0023 | not pertinent | - |
| DimensionalPlotRecipes.jl | Plots.jl recipes for DiffEq solutions | - | not pertinent | - |
| EasyModelAnalysis.jl | high-level parameter-sweep wrapper atop ModelingToolkit | 0012 | not pertinent | - |
| EllipsisNotation.jl | `..` array-indexing macro | - | not pertinent | - |
| Evolutionary.jl | evolutionary/genetic optimisation algorithms | - | not pertinent | - |
| Expmv.jl | matrix-exponential-times-vector library, no README | - | not pertinent | - |
| ExponentialUtilities.jl | phi-function support for exponential integrators, none chosen here | - | not pertinent | - |
| FastAlmostBandedMatrices.jl | banded-bulk-plus-dense-correction matrix type for spectral BVP collocation | 0012 | not pertinent | - |
| FastBroadcast.jl | `@..` fused-broadcast-loop macro for the CPU | - | not pertinent | - |
| FastPower.jl | opt-in approximate `x^y`, about 12 fewer digits of accuracy than `^`; a direct dependency of `OrdinaryDiffEqCore` | 0011 | algorithmic reference | now |
| FastSolvers.jl | placeholder ("kernel methods, wavelets and more"), no implementation visible | - | not pertinent | - |
| FEniCS.jl | bindings to the Python FEniCS finite-element library | - | not pertinent | - |
| FindFirstFunctions.jl | faster `findfirst`-family functions | - | not pertinent | - |
| FiniteElementDiffEq.jl | old finite-element PDE solver | - | not pertinent | - |
| FiniteStateProjection.jl | chemical master equation solver atop Catalyst | - | not pertinent | - |
| FiniteVolumeMethod.jl | planar unstructured finite-volume solver (`DelaunayTriangulation.jl`-based), not a spherical or icosahedral grid | 0005 | not pertinent | - |
| FiniteVolumeMethod1D.jl | 1D finite-volume solver | - | not pertinent | - |
| FluxNeuralOperators.jl | neural-operator layers (duplicate of NeuralOperators.jl) | - | not pertinent | - |
| FunctionProperties.jl | function-property (e.g. purity) introspection utility | - | not pertinent | - |
| FunctionWrappersWrappers.jl | nested function-wrapper type-stability utility | - | not pertinent | - |
| GeiloInverseProblemWorkshop | inverse-problems workshop notes | - | not pertinent | - |
| GeometricIntegratorsDiffEq.jl | binding to GeometricIntegrators.jl for symplectic integration; N-body secular variation is a declared absence (0008) | 0008 | not pertinent | - |
| GlobalDiffEq.jl | ODE solvers with global (not local) error estimates | - | not pertinent | - |
| GlobalSensitivity.jl | Sobol/Morris/variance-based global sensitivity analysis | 0025 | algorithmic reference | M4b |
| HelicopterSciML.jl | a SciML challenge problem (helicopter model discovery) | - | not pertinent | - |
| HighDimPDE.jl | deep-BSDE high-dimensional PDE solver | - | not pertinent | - |
| IfElse.jl | branchless `ifelse` dispatch utility | - | not pertinent | - |
| Integrals.jl | generic numerical quadrature library | - | not pertinent | - |
| IRKGaussLegendre.jl | 16th-order implicit RK for Hamiltonian (N-body) systems; not needed under the declared Kepler-orbit absence of secular N-body integration | 0008 | not pertinent | - |
| JuliaCon2017 | conference slides | - | not pertinent | - |
| JuliaCon2022_Catalyst_Workshop | workshop notebooks | - | not pertinent | - |
| Julia_Modeling_Workshop | training materials | - | not pertinent | - |
| juliatorch | bridges Julia functions into PyTorch autograd | - | not pertinent | - |
| JumpProcesses.jl | stochastic jump/Gillespie process solvers | - | not pertinent | - |
| LabelledArrays.jl | named-field array type, largely superseded by ComponentArrays.jl | - | not pertinent | - |
| LHLFactorization.jl | one factorization of `J` reused across many shifted systems `(sigma*I + tau*J)x=b` | 0012 | not pertinent | - |
| LightweightStats.jl | basic statistics functions | - | not pertinent | - |
| LinearSolve.jl | polyalgorithm dispatcher over host LU/QR/Krylov backends, plus whole-matrix GPU offload (>=100x100) | 0012 | algorithmic reference | M2 |
| LineSearch.jl | line-search algorithms backing NonlinearSolve's Broyden/quasi-Newton methods | 0012 | not pertinent | - |
| MathML.jl | MathML expression parsing | - | not pertinent | - |
| MATLABDiffEq.jl | binding to MATLAB's ODE solvers | - | not pertinent | - |
| MaybeInplace.jl | macro utility selecting in-place vs out-of-place code paths | - | not pertinent | - |
| MethodOfLines.jl | finite-difference PDE discretiser for ModelingToolkit `PDESystem`s on Cartesian grids | 0012 | not pertinent | - |
| MinimallyDisruptiveCurves.jl | parameter-identifiability curve tracing | - | not pertinent | - |
| ModelingToolkitCourse | MIT IAP course materials | - | not pertinent | - |
| ModelingToolkit.jl | symbolic-numeric modelling framework: Jacobian/Hessian codegen, index reduction, DAE handling | 0012 | not pertinent | - |
| ModelingToolkitNeuralNets.jl | neural-network components inside ModelingToolkit models | - | not pertinent | - |
| ModelingToolkitStandardLibrary.jl | standard component library for ModelingToolkit | 0012 | not pertinent | - |
| ModelingToolkitWorkshop_JuliaCon2024 | workshop materials | - | not pertinent | - |
| ModelOrderReduction.jl | reduced-order modelling for ModelingToolkit systems | - | not pertinent | - |
| MomentClosure.jl | moment-closure equations for chemical reaction networks | - | not pertinent | - |
| MuladdMacro.jl | rewrites `a*b+c` as `muladd` for FMA | - | not pertinent | - |
| MultiScaleArrays.jl | hierarchical array type for multiscale biological models | - | not pertinent | - |
| NBodySimulator.jl | gravitational and molecular-dynamics N-body simulator; not needed under the declared secular-variation absence | 0008 | not pertinent | - |
| NeuralLinearSolve.jl | learned preconditioners for LinearSolve.jl | - | not pertinent | - |
| NeuralLyapunov.jl | neural Lyapunov-function synthesis | - | not pertinent | - |
| NeuralOperators.jl | Fourier/graph neural operator layers | - | not pertinent | - |
| NeuralPDE.jl | physics-informed neural network PDE solving | - | not pertinent | - |
| NonlinearSolveBase.jl | stale (2024) stand-alone snapshot of the shared interfaces now maintained inside `NonlinearSolve.jl/lib/NonlinearSolveBase` | 0008, 0023 | not pertinent | - |
| NonlinearSolve.jl | monorepo: root-finding, including the in-kernel bracketing/simple solvers this project needs | 0008, 0023, 0033 | import review | now |
| NonlinearSolveMINPACK.jl | binding to Fortran MINPACK, host-only C dependency | 0012 | not pertinent | - |
| ODEInterfaceDiffEq.jl | binding to the Fortran ODEInterface solvers | - | not pertinent | - |
| ODE.jl | early/basic ODE solver collection | - | not pertinent | - |
| OperatorLearning.jl | neural operator learning | - | not pertinent | - |
| OptimalControl.jl | optimal-control problem solving | - | not pertinent | - |
| OptimalUncertaintyQuantification.jl | worst/best-case distribution bounds (OUQ algorithm) | - | not pertinent | - |
| OptimizationBase.jl | shared AD/caching base for Optimization.jl | - | not pertinent | - |
| Optimization.jl | unified optimisation-algorithm dispatcher | - | not pertinent | - |
| OrdinaryDiffEqExtendedTests.jl | extended/long-running test suite for OrdinaryDiffEq.jl | - | not pertinent | - |
| OrdinaryDiffEq.jl | ODE/DAE integrator monorepo: explicit, implicit, IMEX, multirate, SSP-RK schemes on the SciMLBase problem stack | 0012, 0023 | algorithmic reference | now |
| OrdinaryDiffEqOperatorSplitting.jl | operator-splitting integrator wrapper atop OrdinaryDiffEq | 0023 | not pertinent | - |
| OrgMaintenanceScripts.jl | automated cross-repository maintenance scripts for the SciML org | - | not pertinent | - |
| ParallelBroadcastArrays.jl | experimental parallel broadcast array type, stale | - | not pertinent | - |
| ParallelParticleSwarms.jl | particle-swarm optimisation | - | not pertinent | - |
| ParameterizedFunctions.jl | old macro DSL for ODE functions, superseded by ModelingToolkit | - | not pertinent | - |
| PDEBase.jl | shared base for ModelingToolkit-based PDE discretisers | - | not pertinent | - |
| PDERoadmap | PDE-tooling discussion/tutorial repository | - | not pertinent | - |
| PDESystemLibrary.jl | library of PDE systems defined with ModelingToolkit | - | not pertinent | - |
| PETScDiffEq.jl | binding to PETSc's TS time integrators | - | not pertinent | - |
| PoissonRandom.jl | fast Poisson random-number generation | - | not pertinent | - |
| PolyChaos.jl | orthogonal polynomials and polynomial chaos for UQ | - | not pertinent | - |
| PowerModels.jl | electrical power-grid optimisation (LANL-ANSI), unrelated domain | - | not pertinent | - |
| PreallocationTools.jl | dual-cache utility for AD-compatible preallocated ODE buffers | 0033 | not pertinent | - |
| ProcessSimulator.jl | chemical process (unit-operation) simulator | - | not pertinent | - |
| PropertyModels.jl | empty/placeholder repository (no Project.toml or src) | - | not pertinent | - |
| PubChem.jl | PubChem chemical-database client | - | not pertinent | - |
| PubChemReactions.jl | reaction-network generation from PubChem data | - | not pertinent | - |
| PureGebal.jl | pure-Julia port of a LAPACK-family matrix-balancing routine, host-only | 0012 | not pertinent | - |
| PureKLU.jl | pure-Julia port of SuiteSparse KLU, a LinearSolve.jl sparse backend, host-only | 0012 | not pertinent | - |
| PureUMFPACK.jl | pure-Julia port of SuiteSparse UMFPACK, a LinearSolve.jl sparse backend, host-only | 0012 | not pertinent | - |
| PyDSTool.jl | binding to the Python PyDSTool package | - | not pertinent | - |
| Pyomo.jl | interface to the Python Pyomo optimisation package | - | not pertinent | - |
| QuantumNLDiffEq.jl | nonlinear ODE solving via differential quantum circuits | - | not pertinent | - |
| QuasiMonteCarlo.jl | low-discrepancy sequence generation | - | not pertinent | - |
| ReactionNetworkImporters.jl | imports reaction networks (e.g. BioNetGen) into Catalyst | - | not pertinent | - |
| RebuildAction | CI action for rebuilding hosted content | - | not pertinent | - |
| RecursiveArrayTools.jl | nested/recursive array utilities backing SciMLBase solution types | 0012 | not pertinent | - |
| ReservoirComputing.jl | echo-state-network (reservoir computing) library | - | not pertinent | - |
| ResettableStacks.jl | resettable stack, backs OrdinaryDiffEq's delay/dense-output history | - | not pertinent | - |
| RespecializeParams.jl | compiler-latency mitigation for parameter respecialisation | - | not pertinent | - |
| Roadmap | issue-tracker pointer for the (defunct) DiffEq roadmap | - | not pertinent | - |
| RootedTrees.jl | rooted-tree order-condition generation for Runge-Kutta methods, no planetary content | 0023, 0025 | algorithmic reference | M3 |
| RuntimeGeneratedFunctions.jl | runtime code generation avoiding world-age issues, backs MTK/Catalyst | 0012 | not pertinent | - |
| SBMLToolkit.jl | imports SBML biology models into Catalyst/ModelingToolkit | - | not pertinent | - |
| SBMLToolkitTestSuite.jl | SBML test-suite runner | - | not pertinent | - |
| Scientific_Modeling_Cheatsheet | MATLAB/Python/Julia comparison cheatsheet | - | not pertinent | - |
| sciml.ai | organisation website source | - | not pertinent | - |
| SciMLAssets | logo/branding assets | - | not pertinent | - |
| SciMLBase.jl | the common `Problem`/`solve`/`Solution` interface every package above depends on | 0012, 0023 | not pertinent | - |
| SciMLBenchmarks.jl | cross-package benchmark suite | - | not pertinent | - |
| SciMLBenchmarksOutput | rendered benchmark output | - | not pertinent | - |
| SciMLBook | MIT 18.337 course notes | - | not pertinent | - |
| SciMLDocs | unified documentation site source | - | not pertinent | - |
| SciMLExpectations.jl | expectation-value / uncertainty-quantification over simulations | - | not pertinent | - |
| SciMLIterators.jl | convenience iterators over SciMLBase solution/integrator objects | - | not pertinent | - |
| SciMLLogging.jl | structured verbosity control for the SciML ecosystem | - | not pertinent | - |
| SciMLNLSolve.jl | old NLsolve.jl wrapper for the NonlinearSolve common interface, superseded | - | not pertinent | - |
| SciMLOperators.jl | lazy linear-operator algebra for implicit solves and Jacobian-free methods | 0012 | not pertinent | - |
| SciMLPublic.jl | backport of Julia 1.11's `public` keyword | - | not pertinent | - |
| SciMLSensitivity.jl | adjoint/forward sensitivity analysis, but only over SciMLBase ODE/SDE solves this project does not have | 0033 | not pertinent | - |
| SciMLStructures.jl | parameter-struct introspection for ModelingToolkit-generated systems | 0012 | not pertinent | - |
| SciMLStyle | the org's Julia style guide | - | not pertinent | - |
| SciMLTesting.jl | shared test-harness boilerplate for SciML packages | - | not pertinent | - |
| SciMLTutorials.jl | tutorial notebooks | - | not pertinent | - |
| SciMLTutorialsOutput | rendered tutorial output | - | not pertinent | - |
| SciMLWorkshop.jl | training exercises | - | not pertinent | - |
| SciPyDiffEq.jl | binding to SciPy's `solve_ivp` | - | not pertinent | - |
| SimpleBoundaryValueDiffEq.jl | teaching-grade basic BVP solvers | - | not pertinent | - |
| SimpleDiffEq.jl | teaching-grade "no cruft" basic ODE solvers | - | not pertinent | - |
| SimpleNonlinearSolve.jl | deprecated top-level shell; the live code moved to `NonlinearSolve.jl/lib/SimpleNonlinearSolve`, surveyed there | 0008, 0023, 0033 | import review | now |
| SimpleNorm.jl | pure-Julia norm functions without LinearAlgebra/BLAS/LAPACK | - | not pertinent | - |
| SimpleOptimization.jl | minimal optimisation-algorithm collection | - | not pertinent | - |
| SparseBandedMatrices.jl | sparse banded matrix type, a LinearSolve.jl backend candidate | 0012 | not pertinent | - |
| SparseColumnPivotedQR.jl | rank-revealing sparse QR, a LinearSolve.jl backend candidate | 0012 | not pertinent | - |
| SparseMatrixIdentification.jl | detects matrix structure (diagonal, tridiagonal, ...) and returns the specialised type | 0012 | not pertinent | - |
| SparseWithDenseRowColMatrices.jl | sparse-bulk-plus-low-rank-correction matrix type | 0012 | not pertinent | - |
| SparsityDetection.jl | automatic Jacobian/Hessian sparsity-pattern detection, deprecated in favour of Symbolics.jl | 0012 | not pertinent | - |
| SpecializingFactorizations.jl | type-stable structure-detecting dense LU/QR dispatcher, allocation-free hot path | 0012 | algorithmic reference | M4 |
| Static.jl | compile-time value-carrying types (`True`, `False`, `StaticInt`, ...) | - | not pertinent | - |
| SteadyStateDiffEq.jl | steady-state wrapper atop NonlinearSolve/OrdinaryDiffEq via the SciMLBase stack | 0023 | not pertinent | - |
| StochasticDelayDiffEq.jl | stochastic delay-ODE solvers; no such physics here | - | not pertinent | - |
| StochasticDiffEq.jl | SDE solvers, moved into OrdinaryDiffEq's sublibraries; no stochastic-forcing physics here | - | not pertinent | - |
| StokesDiffEq.jl | old Stokes-flow solver | - | not pertinent | - |
| StructuralIdentifiability.jl | differential-algebra parameter-identifiability analysis | - | not pertinent | - |
| SundialsBuilder | binary builder for the Sundials C library | - | not pertinent | - |
| Sundials.jl | binding to the Sundials C ODE/DAE solvers, breaks GPU-portable-kernel design | 0011 | not pertinent | - |
| SurrogatesBase.jl | shared interface for surrogate-model packages | - | not pertinent | - |
| Surrogates.jl | surrogate-modelling library (kriging, radial basis, ...) | - | not pertinent | - |
| SymbolicAnalysis.jl | Symbolics.jl-based convexity/DCP property propagation for optimisation | - | not pertinent | - |
| SymbolicIndexingInterface.jl | standardised symbolic-variable indexing for ModelingToolkit/SciMLBase problems | 0012 | not pertinent | - |
| SymbolicLimits.jl | symbolic limit computation | - | not pertinent | - |
| SymbolicNumericIntegration.jl | hybrid symbolic/numeric indefinite integration | - | not pertinent | - |
| TensorFlowDiffEq.jl | binding to TensorFlow-based ODE solving | - | not pertinent | - |
| TestPackage | placeholder package skeleton | - | not pertinent | - |
| TruncatedStacktraces.jl | stacktrace-truncation dev tool, superseded by Julia 1.10 itself | - | not pertinent | - |
| TupleLU.jl | LU factorisation for small statically-sized (tuple-backed) matrices | 0008, 0012 | algorithmic reference | M4 |
| YOLOWeights.jl | pinned, checksummed YOLO object-detector weight downloads, unrelated domain | - | not pertinent | - |

224 repositories: 3 `import review`, 8 `algorithmic reference`, 0 `oracle arm`, 213
`not pertinent`.

## The closer look

### `NonlinearSolve.jl` (including `SimpleNonlinearSolve.jl` and the merger into it)

**Import review**, bearing on decision 0008 (Kepler's equation to rounding for any
eccentricity below one), decision 0023 (the fast tier's per-cell implicit solves), and
decision 0033 (kernel purity). Read against commit `0dccd34d` (`NonlinearSolve.jl`);
`SimpleNonlinearSolve.jl` at commit `34208c8` is the deprecated top-level shell -- its
own README states in a warning banner that "this package has been moved into a
subpackage in NonlinearSolve", and the code now lives at
`NonlinearSolve.jl/lib/SimpleNonlinearSolve` and
`NonlinearSolve.jl/lib/BracketingNonlinearSolve`. The two `import review` rows above
point to the same code; this section is the one closer look for both.

**Which methods are bracketed and stay inside their bracket.** The bracketing family
in `BracketingNonlinearSolve/src/`: `bisection.jl`, `brent.jl`, `itp.jl`, `ridder.jl`,
`alefeld.jl`, `falsi.jl`, `muller.jl`. Reading `bisection.jl`'s `internal_bisection`
and `itp.jl`'s `ITP` solve loop directly: both narrow `(left, right)` monotonically --
every branch either returns or replaces `left` or `right` with a point already known
to lie between them -- so the invariant that the root stays bracketed is visible in
the loop body, not merely documented. ITP (`itp.jl`) is Oliveira & Takahashi's
Interpolate-Truncate-Project method, cited to its DOI in the docstring, with a proven
worst case no worse than bisection and superlinear average behaviour; it is the one
reference_repos_desc.md names for the Kepler solve, and reading the loop confirms
nothing about it depends on the equation being Kepler's specifically -- it is `f(x)`
and a bracket, which is exactly `M = E - e*sin(E)` and `E in [0, 2*pi)` (or a tighter
bracket derived from `M` and `e`).

**Whether the tolerance is a supplied type rather than a chosen number.**
`NonlinearSolveBase/src/common_defaults.jl`'s `get_tolerance` is the single place
every solver reads a default `abstol` from: with no user value, scalar/static-array
callers get `T(real(oneunit(T)) * eps(real(one(T)))^0.8)` -- a formula in the floating
type's own epsilon, not a literal the package author picked once for `Float64` and
left unexamined for `Float32`. (`Float64` alone gets a slightly different constant,
`3.0e-13`, with a code comment explaining it exists only because a `Rational` literal
hangs a static-compilation trimming pass -- an accuracy-irrelevant workaround, not a
second policy.) `Bisection` and `ITP` both call this through
`NonlinearSolveBase.get_tolerance(left, abstol, promote_type(...))`, so a caller who
wants tighter-than-default control at compile time supplies the type, not a run-time
constant.

**Whether it allocates.** `SimpleNewtonRaphson`'s own docstring
(`NonlinearSolve.jl/lib/SimpleNonlinearSolve/src/raphson.jl`) states it "is
non-allocating on scalar and static array problems"; reading the solve loop confirms
it holds exactly the state (`x`, `xo`, `fx`, `J`) and rebuilds nothing across
iterations. The bracketing loops hold four scalars (`left`, `right`, `fl`, `fr`) and
no container at all.

**Whether it works under KernelAbstractions on a device.** This is demonstrated, not
inferred: `NonlinearSolve.jl/lib/SimpleNonlinearSolve/test/gpu/cuda_tests__item2.jl`
launches `@cuda kernel_function(prob, alg)` where `kernel_function` calls
`solve(prob, alg)` directly inside the kernel body, for `SimpleNewtonRaphson`,
`SimpleDFSane`, `SimpleTrustRegion`, `SimpleBroyden`, `SimpleLimitedMemoryBroyden` and
`SimpleKlement`, over both a scalar `Float32` and a `StaticArrays.SVector` state. The
one method excluded from that kernel test, by a code comment, is `SimpleHalley` --
"due to dynamic dispatch issues (requires LU factorization, second derivatives, and
complex type-dependent operations)" -- which is the concrete boundary of what "in a
kernel" buys: methods needing a general dense factorisation or a second derivative
are not kernel-safe by default, methods that are plain scalar iteration or a
static-array residual are. The test is written against `CUDA.@cuda` rather than
`KernelAbstractions.@kernel`; nothing in the solve loops is CUDA-specific (no
`@cuda`-only intrinsics, no shared memory, no atomics), so the gap to
`KernelAbstractions` is a demonstration gap, not a known obstruction, and the honest
statement is that this project would need to write and run that test itself before
trusting it inside a `KernelAbstractions` kernel body on both backends.

**What a Newton/Halley variant costs in AD policy.** `SimpleNewtonRaphson`'s default
`autodiff` is `AutoForwardDiff()` (`configure_autodiff` in `raphson.jl`), selected
through `ADTypes.jl`'s marker type and materialised by `DifferentiationInterface.jl`
(a `JuliaDiff`-org package, not present in this tree, pulled in transitively). Decision
0033 wants kernels kept pure so differentiation stays possible later, and `ADTypes.jl`
itself is inert -- a compile-time dispatch tag with no differentiation logic of its
own -- so adopting it costs nothing against that constraint. What would cost something
is choosing a Newton/Halley variant with the default `autodiff`: it pulls in
`ForwardDiff.jl`'s dual-number machinery into the kernel body. For the four named
uses in this project's requirements (Kepler, stomatal conductance, matric-potential
inversion, saturation adjustment), the derivative-free bracketing methods (ITP,
Bisection, Brent) sidestep that question entirely, and where a derivative is cheap to
write by hand (Kepler's `dM/dE = 1 - e*cos(E)`), supplying it explicitly through
`SciMLBase.has_jac` avoids pulling `ForwardDiff` into the kernel at all.

### `OrdinaryDiffEq.jl`

**Algorithmic reference**, bearing on decision 0012's open sub-decision (which
integrator the fast tier of decision 0023 uses) and on decision 0023 directly. Read
against commit `4b1c5c42c`.

The scheme families match `ClimaTimeSteppers.jl` closely: `lib/OrdinaryDiffEqIMEXMultistep`,
`lib/OrdinaryDiffEqMultirate`, `lib/OrdinaryDiffEqMultirateImplicit`,
`lib/OrdinaryDiffEqSSPRK`, `lib/OrdinaryDiffEqLowStorageRK`, plus the SDIRK, Rosenbrock
and fully implicit (FIRK) families `ClimaTimeSteppers.jl` does not carry. The
dependency weight does not match. `lib/OrdinaryDiffEqCore/Project.toml` depends
directly on `SciMLBase`, `DiffEqBase`, `RecursiveArrayTools`, `SciMLOperators`,
`SciMLStructures` and `SymbolicIndexingInterface` -- the entire apparatus decision
0012 already declined for the columns ("the symbolic layer hides the discretisation").
The top-level README confirms the coupling is not incidental: "OrdinaryDiffEq v7 bumps
to SciMLBase v3 ... with breaking changes across all sublibraries." `docs/imports/climatimesteppers-jl.md`
already established the contrast on the other side: `ClimaTimeSteppers.jl`'s own
`ODEProblem` is not SciMLBase's, its state contract is `zero`, `eltype` and
broadcasting, and `ClimaCore` is only a twenty-line weak extension. Nothing in
`OrdinaryDiffEq.jl`'s `lib/OrdinaryDiffEqMultirate/src/` is column-layout-specific
(the band structure, as with `ClimaTimeSteppers`, lives in the caller's implicit
solve), so the scheme *implementations* are legitimate reading if a chosen tableau's
coefficients need to be checked against a second source; the *package* is not a
lighter-weight alternative to the one already surveyed and provisionally preferred.

The one thing this closer look adds beyond confirming decision 0012's framing: a
concrete reproducibility hazard riding along. `FastPower.jl` -- an opt-in `x^y`
approximation losing about twelve digits of `Float64` accuracy for speed, per its own
README -- is a direct `Project.toml` dependency of `OrdinaryDiffEqCore`. Its own
documentation frames it as deliberately opt-in ("very easy but deliberate on the side
of the user"), so it is presumably called only in adaptive-step-size error-norm
paths rather than the state update itself, but this survey did not trace every call
site, and decision 0011's ulp-ensemble certification would have to before any
production use, single- or double-precision. This is exactly the class of transitive,
unaudited precision dependency decision 0012's import-review discipline exists to
catch before it rides in silently.

Two more things worth naming for whoever writes the eventual decision: `EnzymeCore` is
also a direct `OrdinaryDiffEqCore` dependency (a thin AD-annotation package, not the
differentiation engine itself, so it does not by itself pull `Enzyme.jl` in), and
`NonlinearSolveBase.jl`'s `L2_NORM` carries a code comment worth reading regardless of
which integrator is chosen: `@fastmath` was deliberately removed from the termination
check's norm because the LLVM `nnan`/`ninf` flags it sets let the optimiser
constant-fold away the `isfinite`/`isnan` guard, so a diverged solve was silently
reported as converged. That is a documented, first-hand instance of exactly the
`@fastmath`-breaks-a-guard failure mode decision 0029's reproducibility discipline
would want caught, from inside the org whose numerics this project is otherwise
declining to adopt wholesale.

### `LinearSolve.jl`, `TupleLU.jl`, `SpecializingFactorizations.jl`

**Algorithmic reference**, bearing on decision 0012's already-made choice (a
hand-written tridiagonal implicit solve in a kernel, not an imported dispatcher) and,
for `LinearSolve.jl` specifically, on the CPU-backend sequential/sparse algorithms of
decision 0011 (the depression-hierarchy construction, the box-constrained water-table
solve). Read against commits `360d9c76` (`LinearSolve.jl`), `d0f68b9` (`TupleLU.jl`),
`0a39639` (`SpecializingFactorizations.jl`).

`LinearSolve.jl` confirms decision 0012's choice rather than complicating it: its own
GPU tutorial (`docs/src/tutorials/gpu.md`) states its two GPU paths are "offloading"
(move a CPU matrix to the GPU, solve, bring the answer back) and an "array type
interface" for an `AbstractGPUArray` problem, and its own warning names the shapes
where either pays off -- "around 1,000x1,000 matrices" for offloading, "around
100x100" for the array-type interface. A per-cell soil-column tridiagonal system is
neither; `LinearSolve.jl`'s GPU story is for one big matrix, not millions of tiny
independent ones running one per thread, which is the shape decision 0012's kernel
already targets. The **closer-look question this leaves open**: `LinearSolve.jl`'s
`default.jl` polyalgorithm (choosing among KLU, UMFPACK, MKLPardiso, Sparspak by
matrix property) is worth reading if the CPU-backend sequential solves of decision
0011 -- the depression-hierarchy construction or a sparse Poisson-type step in the
water-table solve -- ever want an automatic best-factorization choice instead of
picking one sparse library by hand; nothing here argues for or against that, only
that the polyalgorithm's dispatch logic, not the package as a dependency, is what
would be worth reading at that point.

`TupleLU.jl` and `SpecializingFactorizations.jl` are the two packages in this tree
that actually answer the "small system, in a kernel" question `LinearSolve.jl` does
not. `TupleLU.jl` (a `Drvi`-authored, SciML-hosted repository) provides `lu` for an
`NTuple`-backed `TupleMatrix` with dimensions carried in the type -- exactly the
statically-sized, stack-resident shape decision 0011's kernels want, though this
survey did not find a GPU test for it the way `SimpleNonlinearSolve.jl` has one, so
that would be the thing to confirm before relying on it.
`SpecializingFactorizations.jl` detects matrix structure (diagonal, tridiagonal,
banded, triangular, symmetric) in `O(n)` to `O(n^2)` and dispatches to the matching
`O(n)`-to-`O(n^2)` specialised solve behind one concrete, type-stable workspace so the
hot path is allocation-free -- its own README frames this as the type-stable answer to
`SparseMatrixIdentification.jl`'s type-unstable one. Neither displaces the
hand-written tridiagonal kernel decision 0012 already chose; both are worth a read if
a future kernel needs a *different* small structured system (e.g. a banded
matric-potential Jacobian wider than tridiagonal) and the choice is between writing
that specialisation by hand again or reading how these two structure this problem
once, generically, behind a single allocation-free workspace type.

### `RootedTrees.jl`

**Algorithmic reference**, bearing on decision 0025 (tier-1 identity and analytic
oracles) and decision 0023 (the fast tier's chosen tableau). Read against commit
`def4827`.

`RootedTrees.jl` generates Runge-Kutta order conditions from rooted-tree
(B-series) combinatorics; its own README states its purpose plainly: "generate order
conditions for Runge-Kutta methods." It carries no planetary content, no grid, no
calendar -- it is pure discrete combinatorics over trees. Decision 0025's tier-1
oracles are exact answers "the implementation is wrong" tests can be built from; a
hand-rolled IMEX-ARK or SSP-RK tableau (whichever decision 0012's open sub-decision
lands on, whether from `ClimaTimeSteppers.jl`, read from `OrdinaryDiffEq.jl`, or
written from a paper directly) is exactly the kind of thing whose designed order is a
known-in-advance answer, and `RootedTrees.jl` is the tool that computes and checks
those conditions symbolically rather than by a convergence-rate curve fit at run time.
The closer-look question for whoever plans the fast-tier integrator's oracle: whether
verifying a chosen tableau's order conditions this way is worth adopting as a
dependency (small, no planetary content, fits decision 0012's infrastructure line) or
worth doing once by hand from the tableau's source paper and not carrying the
dependency at all.

### `ComplementaritySolve.jl`

**Algorithmic reference**, bearing on the box-constrained water-table linear
complementarity problem `reference_repos_desc.md` names (REQ-HYD-004) and on decision
0011's CPU-backend-for-sequential-algorithms line. Read against commit `c0af7fa`.

Its README lists, among the LCP solvers: PSOR (Projected Successive Over-Relaxation),
PGS and RPGS (Projected/Randomized Projected Gauss-Seidel), all CPU-only and
non-batched, plus a `NonlinearReformulation` solver with native CUDA batching (via
`NonlinearSolve.jl`, so it would need a CUDA-compatible algorithm choice such as
`SimpleNewtonRaphson`) and an adjoint method
(`LinearComplementarityAdjoint`) compatible with `ChainRules`. This is precisely the
algorithm family `reference_repos_desc.md`'s terrain-and-hydrology notes point to by
name for the water table's box-constrained obstacle problem ("Projected Successive
Over-Relaxation (PSOR) and monotone multigrid methods ... check `IterativeSolvers.jl`
and the multigrid relaxation kernels"), found here inside the SciML org rather than
the terrain-and-hydrology survey group's trees. The closer-look question: whether the
PSOR/PGS implementations here are worth reading as a second, independently-written
reference for the hand-written multigrid active-set solver the water table needs, or
whether `PATHSolver.jl` (the terrain-and-hydrology group's named oracle arm, a
different tree) is sufficient on its own as the tier-3 verification bar and this
package is redundant with it.

### `GlobalSensitivity.jl`

**Algorithmic reference**, bearing on decision 0025's bracket-sweep methodology. Read
against commit `f87575f`.

Sobol, Morris and related variance-based sensitivity methods, generic and
planet-agnostic. Decision 0025 already commits every `Bracketed` and `Closure`
constant to a sweep at milestone M4b and M8; nothing here changes that commitment, but
an exhaustive grid sweep over tens of bracketed constants (the exact cost decision
0033 names as the reason finite-difference sensitivity is expensive) is one thing a
variance-based method is built to reduce. The closer-look question: whether a
Sobol-index ranking of which `Bracketed` constants dominate a given exit criterion is
worth adopting once the M4b sweep exists to sweep, so the exhaustive grid is replaced
or pruned by an importance ranking rather than run in full every time.

### `FastPower.jl`

**Algorithmic reference**, bearing on decision 0011's precision-by-declaration
discipline and the ulp-ensemble certification it names. Read against commit
`674cbaa`. Covered above under `OrdinaryDiffEq.jl` as the concrete instance found;
repeated here as its own row because it is a reproducibility hazard independent of
whether `OrdinaryDiffEq.jl` itself is ever adopted -- any future dependency in this
tree that lists `FastPower` in its own `Project.toml` carries the same hazard
silently, and grepping for it is now a cheap thing to check in any future import
review from this organisation.

### `ModelingToolkit.jl` and the symbolic tree

**Not pertinent**, confirming decision 0012's declination. Read against commit
`fcda4b8c23`. `Symbolics.jl` itself, which `ModelingToolkit.jl` depends on, is not
part of this tree at all -- it lives under the separate `JuliaSymbolics` organisation
and was not cloned here, so this survey's only view of it is through
`ModelingToolkit.jl`'s use of it. `ModelingToolkit.jl`'s own README states its
purpose as symbolic preprocessing that "can automatically generate fast functions for
model components like Jacobians and Hessians ... [and] automatic transformations,
such as index reduction" -- exactly the host-side, offline code-generation shape
decision 0012 already characterised ("the symbolic layer hides the discretisation")
and declined for the columns, which are coupled through the mesh every step with a
fixed operator-split timestep that does not want a generalised DAE index-reduction
pass. Nothing read here corrects that decision; it confirms it.

The narrower question the brief asks -- whether anything in the symbolic tree serves
a narrower purpose, generating a Jacobian or verifying an oracle identity -- turned up
one clear answer already covered above (`RootedTrees.jl`, for Runge-Kutta order
conditions) and no others worth adopting. `SymbolicNumericIntegration.jl` (hybrid
symbolic/numeric indefinite integration) and `SymbolicLimits.jl` (symbolic limit
computation) could in principle check a closed-form derivation such as the
orbit-mean-insolation identity decision 0008 already claims from Murray & Dermott
(1999) directly, or the obliquity-threshold limit where the equinox event stops
existing, but decision 0008's own oracle list already commits these to being checked
against the analytic result from the primary source, not against a second computer
algebra system, and this survey found no case in the read decisions where a symbolic
integration or limit is the open question rather than a citation already in hand.
`SymbolicAnalysis.jl` (convexity/DCP property propagation for optimisation),
`SymbolicIndexingInterface.jl` (ModelingToolkit/SciMLBase's own variable-indexing
glue) and `StructuralIdentifiability.jl` (differential-algebra parameter
identifiability) serve purposes this project's requirements do not raise.

## Recommended rows

- **The Kepler solver, decision 0008's system.\* oracles.** Use `ITP` or `Bisection`
  from `NonlinearSolve.jl/lib/BracketingNonlinearSolve` (or reimplement the same
  about 30-line scalar loop directly, per decision 0027's reference-path discipline) for
  `M = E - e*sin(E)` solved to rounding. Timed `now`: it bears on the M0 gate's
  `system.*` oracle section directly, and decision 0008 is already accepted and
  waiting on an implementation.
- **The fast tier's implicit-explicit integrator, decision 0012's open sub-decision.**
  This survey's comparison (`ClimaTimeSteppers.jl` lighter, `OrdinaryDiffEq.jl`
  welded to the declined SciMLBase/DiffEqBase stack, schemes overlapping heavily
  between them) is evidence for that sub-decision, not a replacement for writing it.
  Timed `now`: decision 0012 states the sub-decision is open and decision 0023's fast
  tier has no integrator behind it until it is written.
- **The stomatal-conductance, matric-potential and saturation-adjustment root solves.**
  Read `SimpleNonlinearSolve.jl`'s Newton/Halley/Broyden family
  (`NonlinearSolve.jl/lib/SimpleNonlinearSolve`) when each of those loops is planned,
  choosing derivative-free (Broyden, Klement, DFSane) over `ForwardDiff`-backed Newton
  where a hand-derived Jacobian is not readily available, per decision 0033's kernel-purity
  argument. Timed to each subsystem's own milestone: M4 (saturation adjustment,
  radiation/column physics), M9 (stomatal conductance, vegetation), M10 (matric
  potential, pedology).
- **A `KernelAbstractions` demonstration of the same claim `cuda_tests__item2.jl`
  makes under raw CUDA.** Before relying on `SimpleNonlinearSolve.jl`'s in-kernel
  behaviour on both the GPU and CPU backends decision 0011 requires, write and run the
  equivalent of that test under `KernelAbstractions.@kernel` rather than `CUDA.@cuda`,
  since this survey found the demonstration only in the latter form. Timed `now`,
  alongside the Kepler solver row, since it is a precondition for trusting the same
  package everywhere else it would be used.
- **The water-table LCP solver's algorithmic reference.** Read
  `ComplementaritySolve.jl`'s PSOR/PGS implementations alongside
  `PATHSolver.jl` (the terrain-and-hydrology group's oracle arm) when the hydrology
  milestone's box-constrained solver is planned. Timed M2, per decision 0034's
  hydrology milestone.
