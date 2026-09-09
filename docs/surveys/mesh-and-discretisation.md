+++
epic = "fiddlybits-bon"
title = "Mesh and discretisation: AlgebraicJulia, JuliaApproximation, WIAS-PDELib"
trees = [
  "/home/cfutro/git/AlgebraicJulia",
  "/home/cfutro/git/JuliaApproximation",
  "/home/cfutro/git/WIAS-PDELib",
]
status = "filed"
date = 2026-09-09
+++

## What this group is

Three organisations read for one question each. AlgebraicJulia is read for whether
its discrete-exterior-calculus engine, `CombinatorialSpaces.jl`, already builds the
circumcentric dual and Hodge stars decision 0013's triangle C-grid needs, and on a
sphere. JuliaApproximation is read for an independent, scattered-point-exact way to
generate the manufactured solutions and eigenvalues decision 0026 needs to certify a
discrete triangle Laplacian's convergence order. WIAS-PDELib is read for
`VoronoiFVM.jl`'s flux discretisation and Newton damping, because the unconfined water
table (REQ-HYD-004) names Picard limit-cycling by name as a hazard and
`VoronoiFVM.jl`'s exponentially-fitted flux family is the general case of the upstream
weighting the requirement prescribes.

Three findings matter most:

1. **`CombinatorialSpaces.jl` gives the whole geometric engine decision 0013 needs, on
   a sphere, as an explicit table-backed structure, with one load-bearing gap.** It
   builds circumcentric duals, Hodge stars (both diagonal and the non-diagonal
   geometric 1-form star that off-diagonal energy consistency needs), boundary
   operators, sharp and flat reconstruction, and wedge products, all on embedded 2D
   delta sets that are represented in 3D (so a sphere is a first-class case, not an
   afterthought). Its own icosphere generator and its binary-subdivision refinement
   (`src/Multigrid.jl`) split each edge at its midpoint and each triangle into four,
   which is decision 0005's exact bisection topologically -- but the runtime
   subdivision computes each new vertex as the flat chordal average of its two parents
   (`propagate_points`, `BinarySubdivision`) with no renormalisation back onto the
   sphere. Decision 0005 needs the children's outer boundary to be the parent's three
   great-circle arcs; a chordal midpoint is not on the sphere and is not on the
   great-circle arc between its parents. This is not a defect in the library -- it is
   general-manifold code, and a planar mesh has no such requirement -- but it means the
   exact-nesting property decision 0005 rests on is not free from this package's
   subdivision and must be re-derived or patched at the point where fiddlybits builds
   its own hierarchy.
2. **The compiler is cleanly separable from the geometry, and the geometry is the
   useful half.** `Decapodes.jl` depends on `CombinatorialSpaces.jl`, never the other
   way around, and the categorical DSL (`DiagrammaticEquations.jl`) that compiles
   equations to operator calls is a separate package again. Reading
   `CombinatorialSpaces.jl`'s dual-mesh and operator code costs nothing extra from the
   category-theory machinery Decapodes is built from.
3. **`VoronoiFVM.jl`'s flux scheme already generalises upstream weighting, and its
   assembly is welded to a CPU-only grid type.** The Bernoulli-function exponential
   fitting (`fbernoulli`, `src/vfvm_functions.jl`) that VoronoiFVM uses for every flux
   is the Scharfetter-Gummel scheme; upstream weighting (what REQ-HYD-004 prescribes
   for a head-dependent transmissivity) is its zero-drift limit, so the same function
   family covers both, which is worth reading before writing the water-table flux term.
   Its Newton solver takes a damped, adaptively-grown step (`SolverControl`,
   `damp_initial`, `damp_growth`) rather than a bare Picard iteration, which is the
   general fix for the limit-cycling failure mode REQ-HYD-004's finding names. But
   every function dispatches on `grid::ExtendableGrids.ExtendableGrid`, there is no CUDA
   or KernelAbstractions dependency anywhere in `Project.toml`, and the Jacobian comes
   from `ForwardDiff.jl` dense per-node autodiff -- the assembly is not separable from
   the WIAS grid stack, and none of it is GPU-first. It is an algorithmic reference and
   a Tier-3 oracle-arm candidate, never an import.

## Repositories surveyed

63 repositories in AlgebraicJulia, 44 in JuliaApproximation (the reasoning that led to
this group names a `SphericalHarmonics.jl` that does not exist in this org; see its
row below), and 13 in WIAS-PDELib: 120 total.

Five repositories carry a verdict other than `not pertinent`; `VoronoiFVM.jl` carries
two verdicts at once.

| verdict | repositories |
| --- | --- |
| algorithmic reference | CombinatorialSpaces.jl, Decapodes.jl, FastTransforms.jl, VoronoiFVM.jl |
| oracle arm | HarmonicOrthogonalPolynomials.jl, VoronoiFVM.jl |
| not pertinent | the remaining 115 |

## Table

### AlgebraicJulia (commit `6ed8acf` for CombinatorialSpaces.jl, `13c6d45` for Decapodes.jl; all others read at their current checkout)

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| CombinatorialSpaces.jl | discrete exterior calculus on simplicial complexes: circumcentric duals, Hodge stars, boundary/sharp/flat operators, mesh refinement | 0005, 0013 | algorithmic reference | M0 |
| Decapodes.jl | a diagrammatic PDE-to-operator compiler built on CombinatorialSpaces | 0013 | algorithmic reference | M3 |
| ACSets.jl | the attributed-C-set (table-of-arrays) data structure CombinatorialSpaces' meshes are built from | - | not pertinent: infrastructure read incidentally while reading CombinatorialSpaces, not a decision-bearing tree on its own |  |
| acsets4j | a Java port of ACSets | - | not pertinent: wrong language |  |
| ACT2023Tutorials | conference tutorial notebooks | - | not pertinent: teaching material |  |
| ActionsPackage.jl | CI Actions template (README mislabelled AlgebraicTemplate) | - | not pertinent: repo tooling |  |
| AlgebraicABMs.jl | agent-based modelling on top of Catlab | - | not pertinent: agent-based modelling, not field discretisation |  |
| AlgebraicControl.jl | compositional optimal control | - | not pertinent: control theory, not PDE discretisation |  |
| AlgebraicDynamics.jl | compositional dynamical systems (open systems, operads) | - | not pertinent: category-theoretic composition, not geometry |  |
| AlgebraicInterfaces.jl | shared method names for the AlgebraicJulia ecosystem | - | not pertinent: naming convention package |  |
| algebraicjulia.org | organisation landing page | - | not pertinent: website |  |
| AlgebraicJuliaZoo.jl | example zoo, actually an Agents.jl mirror | - | not pertinent: misfiled example repo |  |
| AlgebraicMetabolism.jl | metabolic network modelling | - | not pertinent: biochemistry domain |  |
| AlgebraicOptimization.jl | compositional optimisation | - | not pertinent: optimisation, not mesh geometry |  |
| AlgebraicPetri.jl | Petri-net epidemiological/reaction modelling | - | not pertinent: compartmental modelling |  |
| AlgebraicRelations.jl | relational-database backend for ACSets | - | not pertinent: data-management layer |  |
| AlgebraicRewriting.jl | graph and C-set rewriting (DPO/SPO/SqPO) | - | not pertinent: term rewriting, not numerics |  |
| AlgebraicTemplate.jl | package template | - | not pertinent: scaffolding |  |
| AlgebraicWorkflows.jl | workflow composition | - | not pertinent: workflow orchestration |  |
| ASKEM-demos | epidemiology demos | - | not pertinent: epidemiology domain |  |
| ASKEM.jl | archived epidemiology framework | - | not pertinent: archived, epidemiology domain |  |
| AssociatedTests.jl | inline unit-test macro | - | not pertinent: testing utility |  |
| CANMOD-2022 | workshop materials | - | not pertinent: teaching material |  |
| CategoricalTensorNetworks.jl | tensor networks via category theory | - | not pertinent: no mesh or PDE content |  |
| Catlab.jl | the core category-theory library everything above is built on | - | not pertinent: category-theory substrate, not itself geometry or discretisation |  |
| CellularSheaves.jl | sheaf-theoretic cellular models | - | not pertinent: no mesh discretisation content |  |
| CliqueTrees.jl | tree-decomposition graph algorithms | - | not pertinent: general graph algorithm, not spatial |  |
| CombinatorialChains.jl | MCMC over C-sets | - | not pertinent: statistical sampling |  |
| CompTime.jl | compile-time metaprogramming helper | - | not pertinent: language tooling |  |
| CSetAutomorphisms.jl | graph/C-set automorphism finding | - | not pertinent: symmetry detection, not numerics |  |
| DataMigrations.jl | schema migration for C-sets | - | not pertinent: data management |  |
| DECAPODES-Benchmarks | benchmark scripts for a Decapodes paper | - | not pertinent: paper artifact |  |
| DecapodesMeshes.jl | mesh-loading helpers for Decapodes examples | - | not pertinent: thin example glue over CombinatorialSpaces |  |
| DiagrammaticEquations.jl | the DSL/diagram layer Decapodes compiles | 0013 | not pertinent as a separate read: it is the compiler layer decision 0013's "is the compiler separable" question already answers as skippable |  |
| Dtries.jl | directory-like data structure | - | not pertinent: generic data structure |  |
| EnzymeKinetics | enzyme kinetics modelling notes | - | not pertinent: biochemistry domain |  |
| GATlab.jl | generalized algebraic theories tooling | - | not pertinent: type-theory substrate |  |
| GraphicalLinearAlgebra.jl | string-diagram linear algebra | - | not pertinent: symbolic algebra, not discretisation |  |
| GraphsTreewidth.jl | treewidth-based combinatorial optimisation | - | not pertinent: graph optimisation |  |
| intertypes | cross-language type-definition DSL | - | not pertinent: serialization tooling |  |
| InterTypesTemplate.jl | template for intertypes | - | not pertinent: scaffolding |  |
| Kittenlab.jl | (no README) | - | not pertinent: undocumented, name suggests category-theory play package |  |
| Metatheory.jl | e-graph term rewriting (JuliaSymbolics, mirrored here) | - | not pertinent: symbolic rewriting |  |
| ModelExploration.jl | model-space search interface | - | not pertinent: search/exploration tooling |  |
| Petri.jl | Petri-net modelling | - | not pertinent: compartmental modelling |  |
| Poly.jl | (no README) | - | not pertinent: undocumented |  |
| Presentations | (no README) | - | not pertinent: undocumented |  |
| pubs-database | bibliography database | - | not pertinent: reference management |  |
| py-acsets | Python port of ACSets | - | not pertinent: wrong language |  |
| quarto-website | (no README) | - | not pertinent: website source |  |
| RegNets.jl | gene regulatory network modelling | - | not pertinent: biology domain |  |
| Semagrams.jl | graphical editor for graph-like structures | - | not pertinent: UI tooling |  |
| SemiringFactorizations.jl | semiring/Kleene-star matrix factorisation | - | not pertinent: abstract algebra |  |
| StateCharts.jl | statechart modelling | - | not pertinent: discrete-event modelling |  |
| StatisticalTheories.jl | categorical statistical models | - | not pertinent: statistics, not geometry |  |
| StockFlow.jl | stock-and-flow diagram modelling | - | not pertinent: system-dynamics diagrams |  |
| StructuredDecompositions.jl | structured (sheaf) tree decompositions | - | not pertinent: combinatorial decomposition |  |
| Structured-Epidemic-Modeling | epidemic modelling preprint code | - | not pertinent: epidemiology domain |  |
| SyntacticModels.jl | syntactic model representation | - | not pertinent: modelling-language tooling |  |
| TemporalData.jl | temporal data utilities | - | not pertinent: time-series tooling |  |
| TraitInterfaces.jl | trait-based interface macros | - | not pertinent: language tooling |  |
| ts-acsets | TypeScript port of ACSets | - | not pertinent: wrong language |  |
| WiringDiagrams.jl | wiring-diagram combinatorics | - | not pertinent: category-theory diagrams |  |

### JuliaApproximation (commit `5126667` for FastTransforms.jl, `eb34c0a` for HarmonicOrthogonalPolynomials.jl; all others read at their current checkout)

Note: the reasoning document that led to this group (`/home/cfutro/reference_repos_desc.md`) names `SphericalHarmonics.jl` as a JuliaApproximation package; no such repository is cloned under this org. `HarmonicOrthogonalPolynomials.jl` is the org's actual spherical-harmonics package and is read in its place.

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| FastTransforms.jl | Julia binding to a C library of fast orthogonal-polynomial and spherical-harmonic transforms | 0026 | algorithmic reference | M3 |
| HarmonicOrthogonalPolynomials.jl | spherical harmonics and harmonic polynomials, with pointwise (scattered-point) evaluation and exact Laplace-Beltrami eigenvalues | 0026 | oracle arm | M3 |
| MultivariateOrthogonalPolynomials.jl | orthogonal polynomials on disks, spheres and triangles, built on ContinuumArrays | - | not pertinent: overlaps HarmonicOrthogonalPolynomials.jl for the sphere case and adds nothing beyond it that decision 0026's Laplacian-convergence oracle needs |  |
| FastGaussQuadrature.jl | Gauss-type quadrature node/weight generator | - | not pertinent: a utility beneath FastTransforms and ClassicalOrthogonalPolynomials, not itself decision-bearing |  |
| AlgebraicCurveOrthogonalPolynomials.jl | orthogonal polynomials on algebraic plane curves | - | not pertinent: 2D planar curves, not spherical or mesh-related |  |
| AnnuliOrthogonalPolynomials.jl | orthogonal polynomials on an annulus | - | not pertinent: planar domain |  |
| ApproxFunBase.jl | core of the ApproxFun function-approximation framework | - | not pertinent: 1D/interval function approximation |  |
| ApproxFunExamples | example notebooks for ApproxFun | - | not pertinent: examples |  |
| ApproxFunFourier.jl | Fourier spaces for ApproxFun | - | not pertinent: 1D periodic approximation |  |
| ApproxFunIntrospect.jl | operator-graph visualisation for ApproxFun | - | not pertinent: developer tooling |  |
| ApproxFun.jl | function approximation via Chebyshev/orthogonal expansions | - | not pertinent: 1D interval approximation, no mesh |  |
| ApproxFunOrthogonalPolynomials.jl | orthogonal-polynomial spaces for ApproxFun | - | not pertinent: 1D |  |
| ApproxFunSingularities.jl | singularity-aware spaces for ApproxFun | - | not pertinent: 1D |  |
| BasisFunctions.jl | generic basis-function framework | - | not pertinent: 1D/tensor-product basis library |  |
| ChebyshevTransforms.jl | Chebyshev transform library | - | not pertinent: 1D transform |  |
| ClassicalOrthogonalPolynomials.jl | classical 1D orthogonal polynomial families | - | not pertinent: 1D, underlies HarmonicOrthogonalPolynomials but not itself spherical |  |
| CompactBases.jl | compact-support basis functions as quasi-arrays | - | not pertinent: 1D FEM-style bases |  |
| CompositeTypes.jl | a small macro-generation utility | - | not pertinent: language tooling |  |
| ContinuumArrays.jl | quasi-arrays with continuous indices | - | not pertinent: infrastructure beneath HarmonicOrthogonalPolynomials, not itself geometry |  |
| ContinuumLinearAlgebra.jl | linear algebra for continuous spectra | - | not pertinent: abstract operator theory |  |
| DomainIntegrals.jl | numerical integration over DomainSets domains | - | not pertinent: generic quadrature utility |  |
| DomainSetsCore.jl | interface types for domains | - | not pertinent: interface package |  |
| DomainSets.jl | domain-set algebra (intervals, products, maps) | - | not pertinent: planar/interval domain algebra |  |
| EquilibriumMeasures.jl | equilibrium measures from potentials | - | not pertinent: potential theory |  |
| FastTransformsForwardDiff.jl | forward-mode autodiff for fast transforms (FFT only so far) | - | not pertinent: autodiff support package |  |
| FrameFun.jl | function approximation with frames | - | not pertinent: 1D/2D frame approximation |  |
| FunctionMaps.jl | function/map composition utilities | - | not pertinent: infrastructure |  |
| GenericFFT.jl | FFT for generic number types | - | not pertinent: numerical-type support |  |
| GridArrays.jl | grid/array abstraction for approximation spaces | - | not pertinent: tensor-product grid utility |  |
| HierarchicalSingularIntegralEquations.jl | hierarchical solvers for singular integral equations | - | not pertinent: integral-equation solver, not mesh discretisation |  |
| MultivariateSingularIntegrals.jl | multivariate singular/Newtonian potential integrals | - | not pertinent: potential-theory integrals on the unit square |  |
| OrthogonalPolynomialsQuasi.jl | superseded by ClassicalOrthogonalPolynomials.jl | - | not pertinent: deprecated |  |
| OscillatoryIntegrals.jl | oscillatory integral quadrature | - | not pertinent: 1D quadrature utility |  |
| PDESchurFactorization.jl | Schur factorisation for rank-2 PDEs | - | not pertinent: 1D/tensor-product PDE solver |  |
| PiecewiseOrthogonalPolynomials.jl | piecewise orthogonal polynomials for p-FEM | - | not pertinent: 1D piecewise FEM basis |  |
| QuasiArrays.jl | quasi-array indexing infrastructure | - | not pertinent: infrastructure |  |
| RaggedArrays.jl | ragged/jagged array container | - | not pertinent: generic data structure |  |
| RatFun.jl | rational functions built from ApproxFun | - | not pertinent: 1D |  |
| RecurrenceRelationshipArrays.jl | arrays for three-term recurrences | - | not pertinent: linear-algebra utility |  |
| RecurrenceRelationships.jl | three-term recurrence solvers | - | not pertinent: underlies orthogonal-polynomial evaluation, not itself geometry |  |
| SemiclassicalOrthogonalPolynomials.jl | semiclassical Jacobi polynomial family | - | not pertinent: 1D polynomial family |  |
| SingularIntegralEquations.jl | acoustic/Helmholtz singular integral equation solver | - | not pertinent: boundary-integral scattering solver |  |
| SingularIntegrals.jl | Hilbert/Cauchy singular integral computation | - | not pertinent: 1D singular integrals |  |
| SpectralMeasures.jl | spectral measures of structured infinite operators | - | not pertinent: operator theory |  |
| SpectralTimeStepping.jl | time-stepping with spectral spatial bases | - | not pertinent: spectral-in-space time integration, no mesh |  |
| ToeplitzMatrices.jl | Toeplitz/Hankel matrix arithmetic | - | not pertinent: linear-algebra utility |  |

### WIAS-PDELib (commit `f658ccab3` for VoronoiFVM.jl; all others read at their current checkout)

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| VoronoiFVM.jl | finite-volume solver for nonlinear degenerate diffusion-convection-reaction on Voronoi/Delaunay pairs, Scharfetter-Gummel flux, damped Newton | REQ-HYD-004, 0026 | algorithmic reference and oracle arm | M2 |
| ExtendableGrids.jl | the unstructured-grid container VoronoiFVM's assembly dispatches on (`grid::ExtendableGrid`) | REQ-HYD-004 | not pertinent as a separate read: it is the answer to VoronoiFVM's own "is assembly separable from its grid type" question (no), not a second decision-bearing tree |  |
| SimplexGridFactory.jl | high-level mesh-generation frontend (Triangle/TetGen wrappers) for ExtendableGrids | - | not pertinent: mesh-generation convenience layer, not a discretisation algorithm |  |
| ExtendableSparse.jl | convenience/efficient sparse matrix assembly | - | not pertinent: generic sparse-assembly utility, CPU-only |  |
| GridVisualize.jl | plotting for ExtendableGrids meshes and fields | - | not pertinent: visualisation |  |
| GridVisualizeTools.jl | low-level helpers for GridVisualize | - | not pertinent: visualisation infrastructure |  |
| PDELib.jl | meta-package re-exporting the WIAS stack | - | not pertinent: umbrella package, no content of its own |  |
| ChargeTransport.jl | semiconductor drift-diffusion device simulator on VoronoiFVM | - | not pertinent: domain application (semiconductor devices), not a new discretisation |  |
| ElectroMechanicsFEM.jl | electro-mechanical FEM for nanowire strain | - | not pertinent: domain application, unrelated physics |  |
| ExtendableASGFEM.jl | adaptive sparse-grid FEM | - | not pertinent: sparse-grid FEM, not the triangle C-grid's finite-volume family |  |
| ExtendableFEMBase.jl | finite-element basis/assembly infrastructure | - | not pertinent: FEM, not the finite-volume family decision 0013/0019 use |  |
| ExtendableFEM.jl | gradient-robust finite element library | - | not pertinent: FEM, alternative discretisation family not chosen by this project |  |
| StrainedElectronicBandstructures.jl | strained semiconductor bandstructure computation | - | not pertinent: solid-state physics domain application |  |

## Closer look, per repository with a verdict

### CombinatorialSpaces.jl -- bears on decision 0005 and decision 0013

Read: `src/DiscreteExteriorCalculus.jl` (2195 lines), `src/FastDEC.jl` (942 lines),
`src/Multigrid.jl` (875 lines), `src/SimplicialSets.jl` (1150 lines), `src/CombMeshes.jl`,
and `Project.toml`.

What is there: `AbstractDeltaDualComplex2D` and its embedded variant build the full
circumcentric dual of a 2D simplicial complex -- dual vertices at circumcenters
(`geometric_center(points, ::Circumcenter)`), dual edges, dual volumes by the
Cayley-Menger determinant (`dual_volume(::Val{2}, ..., ::CayleyMengerDet)`). Hodge
stars are defined for both the diagonal approximation and a geometric (non-diagonal)
form (`dec_hodge_star`, `dec_p_hodge_diag`, `FastDEC.jl` lines 637-750); sharp and flat
operators (sharp and flat) reconstruct vectors between primal edges, dual edges and full
Cartesian vectors, in several named variants (`PPSharp`, `LLSDDSharp`, `DPPFlat`,
`PPFlat`). Wedge products are written as `KernelAbstractions.jl` `@kernel` functions
(`wedge_kernel_01!` through `wedge_kernel_21!`, `FastDEC.jl` lines 159-236) and the
package carries `CombinatorialSpacesCUDAExt` and `CombinatorialSpacesMetalExt`
extension modules, so at least the pointwise wedge-product evaluation is genuinely
GPU-dispatched; the mesh construction itself (dual complex assembly, Hodge-star
factorisation for the inverse) stays on the CPU as sparse/dense linear algebra.

The mesh is carried as an ACSet: a schema of tables (vertex, edge, triangle incidence,
plus the dual complex's own tables) rather than an implicit coordinate rule, so it is
an explicit connectivity structure in the sense decision 0005 wants, and every operator
above is written against those tables. It is genuinely spherical, not planar-only:
`EmbeddedDeltaSet2D`/`EmbeddedDeltaDualComplex2D` embed in 3D, `CombMeshes.jl` ships an
`Icosphere` mesh loader (subdivisions 1 through 8, from a bundled artifact) and a
UV-sphere generator (`makeSphere`), and `MeshOptimization.jl` has a `spherical` option
to keep jittered points on a declared-radius sphere.

The gap that matters for decision 0005: `src/Multigrid.jl`'s `BinarySubdivision`
(`propagate_points`, lines 111-122) creates each new edge midpoint as the flat average
`(p0 + p1) / 2` of its two parent points, with no renormalisation step anywhere in
`Multigrid.jl` or the `PrimalGeometricMapSeries` machinery that calls it. On a sphere
that is the chord midpoint, not the great-circle midpoint decision 0005's exact-nesting
argument needs (the four children's outer boundary must be the parent's three
great-circle arcs, so that area sums are exact). The package's own bundled icospheres
are presumably built correctly offline (their generation script is not part of this
tree), but the *runtime* refinement path used by its multigrid solvers is planar
bisection embedded in 3D, not spherical bisection. A closer look before decision 0005's
mesh module is written should answer: does adopting or adapting
`BinarySubdivision`'s topology (which is exactly right: split each edge, four children
per triangle, contiguous fine-vertex numbering) require writing a fiddlybits-side
`propagate_points` that projects to the sphere, or is there a spherical variant
elsewhere in the package not found in this pass?

### Decapodes.jl -- bears on decision 0013

Read: `Project.toml`, `README.md`, `src/` file listing.

Decapodes.jl depends on `CombinatorialSpaces` and on a separate package,
`DiagrammaticEquations.jl`, for its categorical diagram DSL; it does not reimplement
any geometry. `src/operators.jl` and `src/simulation.jl` are where diagrams compile down
to calls against `CombinatorialSpaces`'s DEC operators. This confirms the compiler is
cleanly separable from the geometric engine: a reader can take `CombinatorialSpaces.jl`
alone without pulling in the ACT machinery. The closer look this deserves, timed to
when decision 0013's shallow-water operators are being written, is narrower than
"should fiddlybits use Decapodes" (it should not -- the equations are declared, typed
and dispatched through decision 0006's `Field`, not compiled from a diagrammatic DSL) --
it is whether `src/operators.jl` names any operator combination (a particular
sharp/flat/Hodge composition for the momentum equation, for instance) that is not
already obvious from reading `CombinatorialSpaces.jl` directly, since Decapodes is the
one place in this org where those operators are exercised end-to-end on a real
equation set rather than unit-tested in isolation.

### FastTransforms.jl -- bears on decision 0026

Read: `README.md`, `src/libfasttransforms.jl` (bindings only; the transforms themselves
are in the wrapped C library, not in this tree).

This package is a Julia wrapper around a compiled C library
(`https://github.com/MikaelSlevinsky/FastTransforms`) and needs a structured grid for
its spherical-harmonic transform: `plan_sph_synthesis`/`plan_sph_analysis` convert
between a bivariate Fourier series and function samples on "an equiangular grid that
does not sample the poles" (README, spherical harmonic transform section). That grid
requirement is exactly the second grid decision 0013 was written to avoid coupling to,
so `FastTransforms.jl` itself is not something fiddlybits' Laplacian-convergence oracle
can sample the triangle mesh through directly. What it is good for is generating a
smooth, exactly-known scalar field (a low-degree spherical harmonic or a smooth
combination of a few) on its own equiangular grid, computing the harmonic-transform
coefficients exactly, and using those as an independent cross-check of whatever
pointwise evaluator fiddlybits builds (most likely from
`HarmonicOrthogonalPolynomials.jl`, below) -- a second, differently-implemented
arm for the same exact answer, per decision 0026's positive-control rule. The closer
look: confirm the sign and normalisation convention `sphericalharmonicy` in
`HarmonicOrthogonalPolynomials.jl` uses matches this package's (the latter's README
says it follows FastTransforms' convention), so the two arms are actually comparable
before either is trusted as the oracle.

### HarmonicOrthogonalPolynomials.jl -- bears on decision 0026

Read: `README.md`, `src/laplace.jl`, `src/angularmomentum.jl`, `src/sphericalharmonics.jl`
(listing), `Project.toml`.

`sphericalharmonicy(l, m, theta, phi)` evaluates a single real (or complex) spherical
harmonic at one scattered point -- no grid at all, so it can be evaluated directly at
every triangle centroid or dual vertex of the icosahedral mesh at any level, which is
what a manufactured-solution oracle for the triangle Laplacian needs. `src/laplace.jl`
carries the exact eigenvalue relation as a diagonal operator: applying `laplacian` to
the `SphericalHarmonic` basis multiplies degree `l` by `-(l + l^2)`, i.e. the standard
`-l(l+1)` eigenvalue of the Laplace-Beltrami operator on the unit sphere, so the closed
form decision 0026's "spherical Laplacian eigenvalues on the sphere" oracle needs
(named for the groundwater column solver, and implicitly for any discrete-Laplacian
convergence check) is a two-line read, not a derivation. `src/angularmomentum.jl`
defines the `d/dphi` angular-momentum operator used to build tangential derivatives,
which is the beginning of vector spherical harmonics but this pass did not find a named
vector-spherical-harmonic type; the closer look should confirm whether one exists
(needed if a manufactured *vector* field, e.g. for the C-grid's normal-velocity
component, is wanted) or whether fiddlybits would need to build one from the scalar
harmonics and the angular-momentum operator itself. `FastTransforms.jl` is a listed
dependency (used for internal machinery, per `Project.toml`), but the evaluation
function itself needs no structured grid.

### VoronoiFVM.jl -- bears on REQ-HYD-004 and decision 0026

Read: `README.md`, `src/vfvm_functions.jl`, `src/vfvm_solvercontrol.jl`,
`src/vfvm_xgrid.jl`, `src/vfvm_geometryitems.jl`, `Project.toml`.

The flux discretisation is Scharfetter-Gummel exponential fitting: `fbernoulli(x)`
computes the Bernoulli function `B(x) = x / (e^x - 1)` (with a Horner-scheme Taylor
expansion near zero and asymptotic branches away from it, `src/vfvm_functions.jl`
lines 12-84), and every edge flux in the solver is built from it. That family
degenerates to plain upstream (upwind) weighting in the zero-advection limit, which is
what REQ-HYD-004 prescribes for the water table's head-dependent transmissivity
(Niswonger, Panday and Ibaraki 2011, cited in that requirement) and what the
requirement's own finding says the predecessor's failed solvers used arithmetic face
averaging instead of. Worth reading closely before REQ-HYD-004's flux term is written:
whether the exponentially-fitted form (rather than plain upstream weighting) is worth
carrying into a groundwater context too, since the requirement's finding also names the
Kirchhoff-transform overflow failure mode as a second reason arithmetic and
exponential-transform approaches both misbehave at this problem's scale.

The Newton solver (`SolverControl`, `src/vfvm_solvercontrol.jl`) takes a damped step
with an adaptively grown damping parameter (`damp_initial = 1.0`,
`damp_growth = 1.2`, docstring: `u_{i+1} = u_i - d_i F'(u_i)^{-1} F(u_i)`) rather than an
undamped Picard fixed-point iteration, which is the general remedy for the limit-cycling
REQ-HYD-004's own finding measured (a flat 1.9e-4 water-balance residual from pass 100
to 599 while the head step fell thirtyfold). It is a full Newton with a dense
per-node Jacobian from `ForwardDiff.jl`, not Picard, so it is a different solver family
from what REQ-HYD-004 already committed to (a box-constrained LCP solved by
multigrid-preconditioned iteration on the mesh hierarchy) -- the closer look is not
"adopt this solver" but "read its damping-and-growth schedule and its retry-on-Newton-failure
logic (`SolverControl` around line 209: catch a Newton exception, lower the step,
retry) as a second worked example of the general damped-iteration remedy, independent
of the multigrid literature REQ-HYD-004 already cites."

Every function that touches a mesh dispatches on `grid::ExtendableGrids.ExtendableGrid`
(`src/vfvm_xgrid.jl`, `src/vfvm_geometryitems.jl`), and `Project.toml` carries no CUDA,
KernelAbstractions, AMDGPU or Metal dependency anywhere in `[deps]`, `[weakdeps]` or
`[extensions]`. The assembly is not separable from the WIAS grid stack (`ExtendableGrids.jl`,
`ExtendableSparse.jl`), and none of it runs on a GPU. That settles the question the brief
asked: `VoronoiFVM.jl` is an algorithmic reference for the flux scheme and damping
strategy and a Tier-3 oracle-arm candidate (an independent implementation to check a
water-table test case's answer against, per decision 0026's third oracle tier) -- never
an import, because taking it would mean taking a CPU-bound grid representation this
project's mesh module (decision 0005) does not use.

## Rows recommended

1. **Read `CombinatorialSpaces.jl`'s `DiscreteExteriorCalculus.jl` and `FastDEC.jl`
   before decision 0013's horizontal operators (gradient, divergence, curl, the Hodge
   stars for the C-grid's mass/velocity split) are written.** Verdict served:
   algorithmic reference. Timed to **M0**, alongside the mesh module, because the dual
   mesh and boundary-operator code is read once for the mesh hierarchy and reused when
   the dynamical core is built at M3.
2. **Resolve the `BinarySubdivision` chordal-midpoint gap before fiddlybits' own mesh
   hierarchy is implemented**: either confirm the icosphere artifact's offline
   generator does the spherical projection `Multigrid.jl`'s runtime path does not, or
   write the renormalising `propagate_points` fiddlybits needs, using
   `CombinatorialSpaces.jl`'s topology (split-edge, four-children numbering) as the
   reference to match. Verdict served: algorithmic reference (with a load-bearing
   caveat). Timed to **M0**.
3. **Read `HarmonicOrthogonalPolynomials.jl`'s `sphericalharmonicy` and `laplacian`
   before the triangle Laplacian's manufactured-solution and eigenvalue oracles are
   written**, and confirm its sign/normalisation convention against `FastTransforms.jl`
   as the second arm. Verdict served: oracle arm (primary) plus algorithmic reference
   (`FastTransforms.jl`, secondary confirming arm). Timed to **M3**, the shallow-water
   and baroclinic gate where the discrete Laplacian's convergence order is a named
   acceptance item.
4. **Read `VoronoiFVM.jl`'s `fbernoulli`/`fbernoulli_pm` and `SolverControl` before
   REQ-HYD-004's water-table flux and iteration are implemented**, as a worked
   comparison for the upstream-weighting and damped-iteration choices the requirement
   already commits to, and register it as a Tier-3 oracle arm candidate for the
   water-table test cases decision 0026 names (Dupuit-Forchheimer, the spherical
   Laplacian eigenvalue case). Verdict served: algorithmic reference and oracle arm.
   Timed to **M2**, hydrology's build row.
