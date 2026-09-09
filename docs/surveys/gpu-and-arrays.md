+++
epic = "fiddlybits-bon"
title = "gpu-and-arrays: the GPU stack and the Julia array, math and linear-algebra ecosystem"
status = "filed"
date = 2026-09-09
trees = [
  "/home/cfutro/git/CUDA.jl",
  "/home/cfutro/git/KernelAbstractions.jl",
  "/home/cfutro/git/GPUArrays.jl",
  "/home/cfutro/git/AcceleratedKernels.jl",
  "/home/cfutro/git/JuliaArrays",
  "/home/cfutro/git/JuliaMath",
  "/home/cfutro/git/JuliaLinearAlgebra",
  "/home/cfutro/git/DimensionalData.jl",
  "/home/cfutro/git/StaticCompiler.jl",
  "/home/cfutro/git/Bumper.jl",
]
+++

## What this group is

This is the substrate group: the portable kernel stack already adopted (`CUDA.jl`,
`KernelAbstractions.jl`, `GPUArrays.jl`; see `docs/imports/cuda.md` and
`docs/imports/kernelabstractions.md`) plus the three large JuliaHub organisations that
hold every generic array, numeric and linear-algebra package in the Julia ecosystem,
and five single repositories chosen for a specific role: `AcceleratedKernels.jl`
(cross-backend parallel primitives), `DimensionalData.jl` (the broadcast pattern
decision 0006's `Field` needs), `StaticCompiler.jl` and `Bumper.jl` (allocation
discipline for kernels), and the three adopted GPU packages themselves, read again
here only for what else in their trees bears on this project.

Three findings matter most:

1. **`StructArrays.jl` already carries the Adapt and KernelAbstractions integration
   decision 0011 needs**, and it is not a hypothetical: `ext/StructArraysAdaptExt.jl`
   defines `Adapt.adapt_structure` for a whole `StructArray` in one line
   (`replace_storage(adapt(to), s)`), and `ext/StructArraysGPUArraysCoreExt.jl` defines
   `KernelAbstractions.get_backend` for a `StructArray` by checking every component
   array agrees on backend, and forces struct-level (not per-field) broadcast dispatch
   for GPU array styles. A column state struct wrapped in `StructArray` already
   indexes with natural field syntax inside a kernel while storing struct-of-arrays in
   memory, which is exactly what decision 0011's cells-first layout wants.

2. **`AcceleratedKernels.jl`'s CPU reduction path is not thread-count invariant by
   default**, which is a direct conflict with decision 0029. Its `mapreduce_1d_cpu`
   (`src/reduce/mapreduce_1d_cpu.jl`) partitions the source into `TaskPartitioner`
   chunks, reduces each chunk with `Base.mapreduce`, then combines chunk results with
   `Base.reduce(op, shared)`; `max_tasks` defaults to `Threads.nthreads()`
   (`src/task_partitioner.jl`), so the number of chunks -- and therefore the
   floating-point association order of a `+` reduction -- changes with the thread
   count. A one-thread and a sixteen-thread run of the default `AK.sum` are not
   guaranteed bitwise identical, which decision 0029 requires. The fix is available
   inside the package (pin `max_tasks` and `min_elems` to fixed values at every call
   site, never the default), not a defect that rules it out, but it is not the
   library's default and would silently pass unless a test specifically checks it.

3. **`DimensionalData.jl`'s own Adapt extension strips metadata for GPU compatibility,
   which is the same boundary decision 0006's `Provenance` sits on.**
   `ext/DimensionalDataAdaptExt.jl` defines `Adapt.adapt_structure(to, m::Metadata) =
   NoMetadata()` with the comment "Metadata nearly always contains strings, which
   break GPU compat." This is a worked answer to a question `Field`'s device-adapt
   path will face directly: `Provenance` carries a content key, a writer, a parameter
   subset hash and a run id, at least one of which (the content key or run UUID) is
   very likely string- or `Base.UUID`-shaped and therefore either not `isbits` or not
   what a kernel should be touching at all. The pattern to borrow is "adapt strips
   what a kernel cannot use and keeps it host-side," not "adapt refuses."

## Repositories surveyed

### Direct trees

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| CUDA.jl | adopted CUDA stack (`CuArray`, kernel compilation, streams) | 0011, 0029 | algorithmic reference | M0 |
| KernelAbstractions.jl | adopted portable kernel language (`@kernel`, backends) | 0011, 0029 | algorithmic reference | M0 |
| GPUArrays.jl | adopted generic GPU array machinery under CUDA.jl/AMDGPU.jl/etc. | 0011, 0029 | algorithmic reference | M0 |
| AcceleratedKernels.jl | cross-backend parallel primitives (map, reduce, sort, accumulate) over KernelAbstractions | 0011, 0029 | import review | M0 |
| DimensionalData.jl | dimension- and metadata-carrying array wrapper with a custom `BroadcastStyle` | 0006 | algorithmic reference | M0 |
| StaticCompiler.jl | experimental ahead-of-time compiler to a standalone library, requires no dynamic allocation or dispatch to succeed | 0011, 0029 | algorithmic reference | M0 |
| Bumper.jl | task-local bump/arena allocator with a scoped `@no_escape` API | 0011 | import review | M4 |

### JuliaArrays (50 repositories)

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| AbstractArraysOfArrays.jl | empty clone (checked-out tree has no files beyond `.git`) | - | not pertinent | - |
| ArrayInterface.jl | SciML's generic array-trait glue other packages dispatch on | - | not pertinent: internal interface layer, not something `Field`'s closed type vocabulary needs | - |
| ArraysOfArrays.jl | ragged/jagged array-of-arrays (`VectorOfArrays`) | - | not pertinent: not the flat cells-first layout of decision 0011 | - |
| ArrayViews.jl | pre-0.4 view type | - | not pertinent: superseded by Base's own views | - |
| AxisArrays.jl | named-axis indexing wrapper, an ancestor of DimensionalData.jl | 0006 | not pertinent: superseded here by DimensionalData.jl | - |
| BlockArrays.jl | block-structured array concatenation | - | not pertinent | - |
| BlockDiagonals.jl | block-diagonal dense matrix type | - | not pertinent: no dense block-diagonal solve is in scope | - |
| CatIndices.jl | bidirectionally growable vectors with custom axes | 0010 | not pertinent: arbitrary-index arrays are what decision 0010's `CellId` design avoids | - |
| CheckedSizeProduct.jl | overflow-checked `size`-product helper | - | not pertinent | - |
| CustomUnitRanges.jl | support for non-1-based axis ranges | 0010 | not pertinent: opposite of the fixed 1-based-in-kernel rule | - |
| DualArrays.jl | forward-mode-AD dual vector type | - | not pertinent: no differentiation requirement is open | - |
| ElasticArrays.jl | resizeable-in-last-dimension arrays | - | not pertinent: store arrays are fixed-shape per level | - |
| EndpointRanges.jl | `ibegin`/`iend` sugar for non-1-based arrays | 0010 | not pertinent: same reason as CustomUnitRanges.jl | - |
| FFTViews.jl | periodic-boundary FFT view | - | not pertinent: no spectral solver in this group's scope | - |
| FillArrays.jl | lazy constant arrays (`Zeros`, `Ones`, `Fill`) without allocation | - | not pertinent: convenience only, not load-bearing on any decision | - |
| FixedSizeArrays.jl | heap-allocated, immutable-size arrays | 0011 | not pertinent: StaticArrays and Field's flat arrays already cover the stack and heap ends | - |
| GetindexArrays.jl | lazy array built from a callable | - | not pertinent | - |
| HybridArrays.jl | arrays mixing static and dynamic axes | 0011 | not pertinent: StructArrays plus StaticArrays already give this without a third dependency | - |
| IdentityRanges.jl | index-preserving view ranges, predates Base's own | - | not pertinent | - |
| IndirectArrays.jl | index-plus-value-table array (a palette array) | 0006 | not pertinent: `CategoricalLabel{Legend}` is already a closed, more specific type for this idea | - |
| InfiniteArrays.jl | arrays with infinite axes for lazy linear algebra | - | not pertinent | - |
| LazyArrays.jl | lazy broadcasting, concatenation, matrix-free composition | 0006 | not pertinent for now: `Field` operators are eager (every operator returns a field and a ledger, not a further thunk) | - |
| LazyGrids.jl | lazy Cartesian meshgrid | - | not pertinent: mesh geometry here is icosahedral, not Cartesian | - |
| LightBoundsErrors.jl | opt-in leaner bounds-check messages | - | not pertinent | - |
| MappedArrays.jl | lazy elementwise view `M[i] = f(A[i])` | 0006 | not pertinent: same lazy-vs-eager mismatch as LazyArrays.jl | - |
| MetadataArrays.jl | array wrapper carrying a metadata field | 0006 | not pertinent: `Field`'s `Provenance` already plays this role, typed more specifically | - |
| MosaicViews.jl | tiles same-shape images into a mosaic for display | - | not pertinent: a visualisation helper, not simulation state | - |
| NamedDims.jl | named-dimension wrapper; DimensionalData.jl's README credits its `BroadcastStyle` trick as the ancestor of its own | 0006 | not pertinent: read together with DimensionalData.jl, not a separate need | - |
| NonResizableVectors.jl | vector wrapper that forbids `push!`/`resize!` | - | not pertinent: fixed-length flat arrays already get this from Julia's own type system | - |
| OffsetArrays.jl | arbitrary-index-base arrays | 0010 | not pertinent, and a caution: the opposite of decision 0010's fixed 1-based-in-kernel design; nothing in this project's array plumbing should end up wrapped in one | - |
| OneTwoMany.jl | a "singleton, pair or vector" union type | - | not pertinent | - |
| PaddedViews.jl | virtual constant-fill padding view | - | not pertinent: no boundary-padding scheme is open | - |
| RangeArrays.jl | arrays whose columns are ranges | - | not pertinent: legacy | - |
| Ranges.jl | pre-0.5 `LinSpace` backport | - | not pertinent: obsolete | - |
| ReadOnlyArrays.jl | immutable-view wrapper | - | not pertinent: `Field`'s own operator table already controls mutation | - |
| ShiftedArrays.jl | lag/lead shifted views for time series | - | not pertinent | - |
| ShowItLikeYouBuildIt.jl | deprecated, folded into `Base.showarg` | - | not pertinent | - |
| SpatioTemporalTraits.jl | runtime trait system for declaring an array's spatial/temporal axis roles | 0006 | not pertinent: documents the rejected alternative (runtime trait vs. type parameter) that decision 0006 already argues against | - |
| SquareBlockDiagonalArrays | near-empty skeleton package | - | not pertinent | - |
| StackViews.jl | lazy `cat`/`eachslice`-inverse view | - | not pertinent | - |
| StaticArrayInterface.jl | SciML's internal trait glue for static/strided array introspection | - | not pertinent: several tools here depend on it, but `Field` does not need a third-party trait layer | - |
| StaticArraysCore.jl | type-only interface package StaticArrays.jl depends on | 0011 | not pertinent as a separate row; covered under StaticArrays.jl | - |
| StaticArrays.jl | stack-allocated, statically sized arrays (`SVector`, `SMatrix`, `MVector`) | 0011 | import review | M0 |
| StaticBitSets.jl | empty clone (checked-out tree has no files beyond `.git`) | - | not pertinent | - |
| StructArrays.jl | struct-of-arrays layout with array-of-structs indexing syntax | 0011, 0006 | import review | M0 |
| StructsOfArrays.jl | StructArrays.jl's unmaintained predecessor by the same idea | 0011 | not pertinent: StructArrays.jl is the maintained, GPU-aware successor | - |
| TiledIteration.jl | cache-tiling iterator helper for CPU stencils | - | not pertinent: KernelAbstractions' own indexing and the mesh's cells-first layout already give this | - |
| UnalignedVectors.jl | deprecated, superseded by `reinterpret` | - | not pertinent | - |
| UnsafeArrays.jl | stack-allocated pointer-based views, a workaround for a since-fixed Julia issue | 0011 | not pertinent: Bumper.jl's arena allocator is this project's answer to scratch memory, with GC-safety scoping this package does not have | - |
| ZeroDimensionalArrays.jl | a 0-d array type | - | not pertinent | - |

### JuliaMath (79 repositories)

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| AbstractFFTs.jl | spectral-transform interface | - | not pertinent: no FFT solver is in this group's scope | - |
| AccurateArithmetic.jl | error-free, faithful and compensated floating-point transforms (`two_sum`, `two_prod`) | 0011, 0029 | algorithmic reference | M0 |
| Bessels.jl | pure-Julia Bessel and related special functions | - | algorithmic reference (for a later radiative-transfer survey, out of this group's core remit) | M4 |
| BFloat16s.jl | the bfloat16 type | 0011 | not pertinent: a lower-precision format, the opposite direction from what decision 0011 needs | - |
| Calculus.jl | unmaintained numeric-derivative toolkit | - | not pertinent | - |
| ChangePrecision.jl | macro that rewrites float literals in a code block to a target type | 0011 | not pertinent: decision 0011 makes precision a type parameter end to end, not a source-rewrite macro | - |
| ChangesOfVariables.jl | Jacobian-of-a-bijection interface for measure-theoretic code | - | not pertinent | - |
| CheckedArithmetic.jl | opt-in integer overflow checking | - | not pertinent | - |
| Combinatorics.jl | discrete combinatorics helpers | - | not pertinent | - |
| Cubature.jl | C-library-backed adaptive cubature | - | not pertinent: not a mesh-hierarchy integral, and C-backed | - |
| DecFP.jl | IEEE decimal floating point | 0011 | not pertinent: the wrong axis of precision entirely | - |
| Decimals.jl | arbitrary-precision decimal arithmetic | - | not pertinent | - |
| DensityInterface.jl | statistics density-function interface | - | not pertinent | - |
| Dierckx.jl | Fortran spline wrapper | - | not pertinent: C/Fortran-backed, not kernel-safe, no spline interpolation is open | - |
| DoubleDouble.jl | double-double arithmetic, unmaintained | 0011 | not pertinent: its own README says use DoubleFloats.jl instead | - |
| DoubleFloats.jl | double-double extended-precision float and complex types | 0011, 0029 | import review | M0 |
| DSFMTBuilder | binary-artifact builder repo | - | not pertinent | - |
| FastChebInterp.jl | Chebyshev interpolation on a Cartesian hypercube | - | not pertinent: wrong mesh topology | - |
| FastPow.jl | integer-power rewrite macro, trades accuracy for speed | 0029 | not pertinent: the wrong trade for a project that measures ulp envelopes | - |
| FFTA.jl | pure-Julia FFT | - | not pertinent: spectral transform, out of this group's scope | - |
| FFTWBuilder | binary-artifact builder for FFTW | - | not pertinent | - |
| FFTW.jl | FFTW bindings | - | not pertinent: spectral transform, out of this group's scope | - |
| FixedPointDecimals.jl | fixed-point decimal arithmetic | - | not pertinent | - |
| FixedPointNumbers.jl | fixed-point number types (used by image/colour types elsewhere) | - | not pertinent: no bearing on float-precision ledgers | - |
| Float8s.jl | 8-bit float types | 0011 | not pertinent: ultra-low precision, the wrong direction | - |
| FunctionAccuracyTests.jl | exhaustive ULP-error testing for scalar functions (`FloatIterator`, `test_acc`) | 0029 | algorithmic reference | M0 |
| FunctionZeros.jl | zeros of Bessel functions | - | not pertinent | - |
| Gamma.jl | a single Gamma-function implementation | - | not pertinent | - |
| GMPBuilder | archived, folded into Yggdrasil | - | not pertinent | - |
| GSL.jl | GNU Scientific Library bindings | - | not pertinent: C-library-backed, not kernel-safe by construction | - |
| Hadamard.jl | FFTW-backed Walsh-Hadamard transform | - | not pertinent | - |
| HCubature.jl | pure-Julia h-adaptive cubature | - | not pertinent: wrong mesh topology (Cartesian hypercube) | - |
| HypergeometricFunctions.jl | hypergeometric functions | - | not pertinent: no such requirement is open | - |
| ILog2.jl | integer log2 helper | - | not pertinent | - |
| Infinities.jl | a symbolic infinity type | - | not pertinent | - |
| IntegerMathUtils.jl | integer math helpers | - | not pertinent | - |
| IntelVectorMath.jl | Intel MKL VML bindings | 0011 | not pertinent: vendor-specific, the same spirit decision 0011 rejects for GPU code | - |
| Interpolations.jl | Cartesian-grid interpolation | - | not pertinent: the mesh hierarchy's own segmented reductions (decision 0005) are the answer here | - |
| IntervalSets.jl | the `a..b` interval/range type used by many packages in this list | - | not pertinent, and a gap worth naming: this is a type convenience, not verified-enclosure interval arithmetic; no true interval-arithmetic package (e.g. IntervalArithmetic.jl) is cloned in this org | - |
| InverseFunctions.jl | function-inversion trait interface | - | not pertinent | - |
| InverseLaplace.jl | numerical inverse Laplace transform | - | not pertinent | - |
| IrrationalConstants.jl | precomputed higher-precision irrational literals for internal package use | - | not pertinent: every constant here already carries a disposition; this is not a channel for one | - |
| KahanSummation.jl | Kahan-compensated `sum` and `cumsum` | 0011, 0029 | algorithmic reference | M0 |
| LambertW.jl | the Lambert W function | - | not pertinent | - |
| Libm.jl | unmaintained, folded into `Base.Math` | - | not pertinent | - |
| MeasureBase.jl | measure-theoretic probability framework | - | not pertinent | - |
| MeasureTheory.jl | measure-theoretic probability framework | - | not pertinent | - |
| MittagLeffler.jl | the Mittag-Leffler function | - | not pertinent | - |
| MPFRBuilder | binary-artifact builder | - | not pertinent | - |
| NaNMath.jl | NaN-returning instead of throwing math functions | 0029 | not pertinent: decision 0029 wants certified bounds or refusal, not a silent NaN fallback | - |
| NestedNumbers.jl | nested-number-type helper | - | not pertinent | - |
| NFFT.jl | non-equispaced FFT | - | not pertinent | - |
| NumericalIntegration.jl | unmaintained trapezoid/Simpson integrator | - | not pertinent | - |
| openlibm | Julia's default CPU `libm` | 0029 | algorithmic reference | M0 |
| OpenlibmBuilder | binary-artifact builder for openlibm | - | not pertinent | - |
| openlibm-test | test harness for openlibm | - | not pertinent | - |
| openspecfun | C-backed Bessel/Faddeeva special functions (AMOS/Faddeeva) | - | not pertinent: not kernel-safe, underlies SpecialFunctions.jl's C paths | - |
| OpenspecfunBuilder | binary-artifact builder | - | not pertinent | - |
| OverflowContexts.jl | integer arithmetic-mode contexts | - | not pertinent | - |
| Polynomials.jl | general polynomial arithmetic and root-finding | - | not pertinent: not a kernel primitive at the scale needed | - |
| Primes.jl | prime-number utilities | - | not pertinent | - |
| QuadGK.jl | adaptive 1-d Gauss-Kronrod quadrature | - | not pertinent: host-side only if ever needed, not a kernel primitive | - |
| Quadmath.jl | `Float128` via libquadmath | 0011 | not pertinent: a C-library dependency; flagged in DoubleFloats.jl's own dependency chain below | - |
| RandomMatrices.jl | random matrix ensembles | - | not pertinent | - |
| RealDot.jl | real-part-of-dot-product helper for complex arrays | - | not pertinent | - |
| RealFFTs.jl | in-place real FFTs | - | not pertinent | - |
| Richardson.jl | Richardson extrapolation | - | not pertinent for this group's decisions; may resurface in a mesh/discretisation-order survey | - |
| Roadmap.jl | a placeholder repository, no code | - | not pertinent | - |
| Roots.jl | general scalar root-finding | - | not pertinent: `SimpleNonlinearSolve.jl` (the sciml survey group) is this project's own pick for in-kernel non-allocating root solves | - |
| RoundingIntegers.jl | rounding-integer types | - | not pertinent | - |
| Sobol.jl | quasi-random low-discrepancy sequences | 0010 | not pertinent: decision 0010's stochastic streams are counter-based on physical identity, a different design | - |
| SpecialFunctions.jl | Bessel, Airy, error, gamma and related special functions | 0011 | algorithmic reference | M4 |
| Tau.jl | the constant tau = 2*pi | - | not pertinent | - |
| TensorCore.jl | a lightweight tensor-operation interface | 0006 | not pertinent: decision 0006 already defines its own closed operator set; noted only as a name-collision risk | - |
| TupleVectorSpaces.jl | tuple-as-vector-space wrapper | - | not pertinent | - |
| VisualizeULPError.jl | a CLI app to plot a function's ULP error | 0029 | algorithmic reference | M0 |
| WrightOmega.jl | the Wright omega function | - | not pertinent | - |
| Xsum.jl | exactly rounded floating-point summation (xsum algorithm, C-backed) | 0011, 0029 | algorithmic reference | M0 |
| Yeppp.jl | abandoned vectorized-math library binding | - | not pertinent | - |

### JuliaLinearAlgebra (49 repositories)

| repo | what it is | bears on | verdict | when |
| --- | --- | --- | --- | --- |
| AlgebraicMultigrid.jl | algebraic multigrid solver for sparse SPD systems | 0011 | algorithmic reference | M2 |
| AOCL.jl | AMD-vendor BLAS/LAPACK binding | 0011 | not pertinent: vendor-specific, the same rejection decision 0011 gives GPU vendor code | - |
| AppleAccelerate.jl | Apple-vendor BLAS/LAPACK binding | 0011 | not pertinent: same reasoning | - |
| ArnoldiMethod.jl | Arnoldi/IRAM iterative eigensolver | - | not pertinent: no eigenproblem is open in this group's remit | - |
| ArpackBuilder | binary-artifact builder | - | not pertinent | - |
| Arpack.jl | ARPACK eigensolver bindings | - | not pertinent: C-library-backed | - |
| ArpackMKLBuilder | binary-artifact builder | - | not pertinent | - |
| ArpackMKL.jl | deprecated, archived | - | not pertinent | - |
| ArrayLayouts.jl | BLAS-dispatch layout trait system for lazy/structured matrices | - | not pertinent: no bearing on `Field`'s own dispatch | - |
| BandedMatrices.jl | dense-storage banded matrix type | - | not pertinent: BLAS-oriented, no banded system is open | - |
| BenchmarkPlottingUtilities.jl | plotting helper for benchmark repositories | - | not pertinent | - |
| BLASBenchmarksCPU.jl | BLAS benchmarking harness | - | not pertinent | - |
| BLASBenchmarksGPU.jl | BLAS benchmarking harness | - | not pertinent | - |
| BLISBLAS.jl | BLIS BLAS vendor binding | 0011 | not pertinent | - |
| BLIS.jl | unmaintained, superseded by BLISBLAS.jl | - | not pertinent | - |
| BlockBandedMatrices.jl | block-banded matrix type | - | not pertinent | - |
| GenericLinearAlgebra.jl | pure-Julia LAPACK-equivalent that works over any number type (not BLAS-backed) | 0011 | algorithmic reference | M0 |
| GenericSVD.jl | unmaintained, folded into GenericLinearAlgebra.jl | - | not pertinent | - |
| HierarchicalMatrices.jl | hierarchical matrix framework | - | not pertinent | - |
| IncrementalSVD.jl | incremental/updating SVD | - | not pertinent | - |
| InfiniteLinearAlgebra.jl | linear algebra with infinite banded matrices | - | not pertinent | - |
| IterativeSolvers.jl | Krylov and stationary iterative solvers (CG, GMRES, MINRES, Chebyshev) | 0011 | algorithmic reference | M2 |
| LAPACK.jl | raw LAPACK wrapper | - | not pertinent: a subset of what stdlib `LinearAlgebra` already gives | - |
| LazyBandedMatrices.jl | lazy banded/block-banded matrices | - | not pertinent | - |
| libblastrampoline | the BLAS/LAPACK demux shim Julia already ships with | 0029 | not pertinent: decision 0029 keeps BLAS out of the hot path regardless of which vendor sits behind this shim | - |
| LinearMaps.jl | matrix-free linear-operator composition (`mul!` without materialising a matrix) | 0011 | algorithmic reference | M2 |
| LowRankApprox.jl | low-rank matrix approximation | - | not pertinent | - |
| LowRankMatrices.jl | the `LowRankMatrix` type split off LowRankApprox.jl | - | not pertinent | - |
| Magma.jl | NVIDIA MAGMA BLAS/LAPACK vendor binding | 0011 | not pertinent | - |
| MatrixDepot.jl | a test-matrix collection for benchmarking algorithms | - | not pertinent: useful only if this project needed generic sparse benchmark matrices, which it does not | - |
| MatrixFactorizations.jl | QL/RQ and other non-standard dense factorizations | - | not pertinent | - |
| MKL.jl | Intel-vendor BLAS/LAPACK swap-in | 0011 | not pertinent | - |
| MultiThreadedLU.jl | unmaintained multi-threaded dense LU | 0029 | not pertinent: the exact shape of routine decision 0029 excludes from the hot path (BLAS only single-threaded and deterministic) | - |
| NonNegLeastSquares.jl | nonnegative least-squares solvers | - | not pertinent | - |
| Octavian.jl | pure-Julia multi-threaded GEMM competitive with vendor BLAS | 0029 | not pertinent: same multi-threading-determinism caution as MultiThreadedLU.jl; no dense GEMM is a hot-path operation here | - |
| OpenBLAS32.jl | LP64 forwarding for OpenBLAS | - | not pertinent | - |
| OpenBLASBuilder | binary-artifact builder | - | not pertinent | - |
| Preconditioners.jl | Jacobi/ILU/AMG preconditioner glue for IterativeSolvers.jl | - | not pertinent: its `AMGPreconditioner` wraps AlgebraicMultigrid.jl, already flagged directly | - |
| RandomizedLinAlg.jl | randomized SVD/eigensolvers, split off IterativeSolvers.jl | - | not pertinent | - |
| RectangularFullPacked.jl | the RFP matrix storage format | - | not pertinent | - |
| RecursiveFactorization.jl | recursive-blocked dense LU | - | not pertinent: no dense LU is a hot-path operation here | - |
| SemiseparableMatrices.jl | semiseparable/almost-banded matrices | - | not pertinent | - |
| SkewLinearAlgebra.jl | skew-symmetric matrix factorizations | - | not pertinent | - |
| SparseLinearAlgebra.jl | small generic sparse-linear-algebra package | - | not pertinent | - |
| SpecialMatrices.jl | a collection of named special matrix types | - | not pertinent | - |
| SuiteSparseBuilder | binary-artifact builder for SuiteSparse | - | not pertinent | - |
| ToeplitzMatrices.jl | Toeplitz matrix type | - | not pertinent | - |
| TSVD.jl | truncated SVD | - | not pertinent | - |
| WoodburyMatrices.jl | low-rank-update matrix identity | - | not pertinent: no such solve is open | - |

## Repositories worth a closer look

### StructArrays.jl (JuliaArrays)

The struct-of-arrays type decision 0011's cells-first layout and decision 0006's
`Field` want. `struct StructArray{T, N, C<:Tup, I} <: AbstractArray{T, N}`
(`src/structarray.jl`) holds one array per field and reconstructs a `T` instance on
`getindex` via `createinstance` -- exactly array-of-structs syntax over
struct-of-arrays memory. Three extension files matter, all already present in the
pinned tree:

- `ext/StructArraysAdaptExt.jl`: `Adapt.adapt_structure(to, s::StructArray) =
  replace_storage(adapt(to), s)`. A `StructArray` adapts to a device the same way a
  plain array does.
- `ext/StructArraysGPUArraysCoreExt.jl`: defines `KernelAbstractions.get_backend` for
  a `StructArray` by checking every component array agrees on backend (throwing if
  they do not), and sets `StructArrays.always_struct_broadcast(::AbstractGPUArrayStyle)
  = true` so a GPU broadcast over a `StructArray` stays struct-shaped rather than
  falling back to per-field broadcast.
- `ext/StructArraysStaticArraysExt.jl`: interoperates with StaticArrays.jl directly.

**Question a closer look should answer:** does a `StructArray` of an `isbits` column
state struct (mirroring the sketch in decision 0006, minus the array field) compile
inside a `KernelAbstractions.@kernel` function on the CUDA backend with the same
generated code as hand-written flat arrays and manual field offsets, and does
`Adapt.adapt_structure`'s `replace_storage` round-trip survive the adapt test pattern
already used for `Field`/`Geometry` in `test/fields/adapt_roundtrip.jl`
(`docs/imports/adapt.md`)?

### StaticArrays.jl (JuliaArrays)

Stack-allocated statically sized arrays (`SVector`, `SMatrix`, `MVector`) whose size
is a type parameter, so the compiler can keep small per-cell state in registers
rather than heap or global memory. This is the concrete mechanism behind decision
0011's "column physics is fused into few kernels per step": a per-cell state vector
(mixing ratios, layer temperatures) held as an `SVector` inside a kernel loop body
compiles to register-resident arithmetic with no allocation, provided its length is
known at compile time.

**Question a closer look should answer:** for the largest per-cell state vector this
project's column physics is expected to need (an atmospheric column's prognostic
variables at its coarsest working level count), does `SVector`-of-that-length still
fit in registers on the target GPU architecture without spilling to local memory, and
at what length does spilling begin -- because past that point `StaticArrays.jl` stops
being free and decision 0011's "atmosphere is bound by kernel launches rather than
arithmetic" claim needs re-checking against register pressure instead.

### DoubleFloats.jl (JuliaMath)

`DoubleFloat{T}` (`src/Double.jl`) is an immutable, `isbits` pair `(hi::T, lo::T)`
with `Double64 = DoubleFloat{Float64}` and `Double32 = DoubleFloat{Float32}`, so the
type itself is device-safe: a struct of two plain floats adapts and passes through a
kernel like any other `isbits` value. Basic arithmetic (`+`, `*` against a
`Tuple{T,T}` in `src/math/ops/op_dbdb_db.jl`) is built from error-free transforms
(`two_sum`) on the component type `T` alone -- no allocation, no external call.
`Double32` is the type the description doc's argument for this package rests on: a
compensated pair of `Float32`s giving roughly twice single precision using pure FP32
instructions, which sidesteps the FP64 throttle decision 0011 names.

The catch is the *package*, not the type: `Project.toml` pulls in `Quadmath` (a
`libquadmath` C-library `Float128` binding), `SpecialFunctions` (a C-library-backed
special-function package, also flagged separately below), `GenericLinearAlgebra` and
`GenericSchur`, for the elementary-function and linear-algebra surface of
`DoubleFloat`. None of that is `isbits`- or kernel-safe, and none of it is needed for
the one operation decision 0011 actually wants: compensated `+=` accumulation into a
ledger or reservoir.

**Question a closer look should answer:** is it better to depend on `DoubleFloats.jl`
for the `DoubleFloat{T}`/`Double32` type and its `two_sum`-based `+`/`-`/`*` alone
(accepting the transitive `Quadmath`/`SpecialFunctions`/`GenericLinearAlgebra`
dependency weight even though a kernel never reaches it), or to write a project-owned
error-free-transform accumulator modelled on `AccurateArithmetic.jl`'s `two_sum`/
`two_prod` (below), which has no such baggage? Either way the import review should
name the exact operator surface a kernel is allowed to call.

### AccurateArithmetic.jl, KahanSummation.jl, Xsum.jl (JuliaMath)

Three different weights of the same idea, all bearing on decision 0011's "every
ledger, every global reduction, and every accumulated reservoir ... is held and
accumulated in double precision or by compensated summation" and decision 0029's
fixed-order reduction requirement:

- `AccurateArithmetic.jl` (`src/EFT.jl`, `src/errorfree.jl`): scalar error-free
  transforms (`two_sum`, `two_prod`, `two_diff`) returning `(result, error)` pairs.
  Pure arithmetic on the input type, no allocation; this is the primitive a
  project-owned compensated-summation kernel would be built from, and is the same
  primitive `DoubleFloats.jl` uses internally. Its `VectorizationBase` dependency is
  only exercised by the CPU-SIMD accumulator path, not the scalar EFT functions.
- `KahanSummation.jl`: `sum_kbn`/`cumsum_kbn`, Kahan-Babuska compensated variants of
  `sum`/`cumsum` -- a smaller, single-purpose alternative if only compensated
  summation (not general compensated arithmetic) is needed.
- `Xsum.jl`: a C-library (`xsum_jll`) binding for Radford Neal's exactly-rounded
  summation algorithm. Not kernel-safe itself (it is a host-side C call), but a
  candidate as a ground-truth oracle to check a project-owned compensated-summation
  kernel's ledger closure against, independent of the kernel's own arithmetic.

**Question a closer look should answer:** does a KernelAbstractions kernel that
calls `AccurateArithmetic.two_sum` inline for its running total compile to the same
PTX/LLVM as one with the error-free transform written out by hand, and does
`Xsum.jl`'s host-side exact sum agree with that kernel's ledger total to the
tolerance decision 0029's ledger-closure oracle registers?

### FunctionAccuracyTests.jl, VisualizeULPError.jl, openlibm (JuliaMath)

The concrete tools behind decision 0029's ulp-ensemble certification and bitwise
debug mode. `FunctionAccuracyTests.jl` provides `FloatIterator{T}(min, max)`, an
indexable iterator over every representable float in a range, and `test_acc`, which
sweeps it against a reference implementation -- an exhaustive, not sampled, per-ulp
check, directly reusable for certifying a project-owned polynomial transcendental
(the kind decision 0029's bitwise mode requires in place of a platform libm) at
`Float32`. `VisualizeULPError.jl` is the companion plotting app for the same
workflow. `openlibm` is Julia's own default CPU `libm` -- the concrete
implementation whose transcendentals (`sin`, `exp`, `log`, ...) differ from CUDA's
`libdevice` at the ulp level, which is exactly why decision 0029 requires "the
project's own polynomial transcendentals" for the bitwise debug mode rather than
either platform's native math library. Reading `openlibm`'s C source for the
functions this project actually calls names precisely which ones need a
project-owned replacement.

**Question a closer look should answer:** which transcendental functions does this
project's kernel surface actually call (likely: `sqrt`, `exp`, `log`, `sin`/`cos` for
orbital and radiative geometry), and for each one, does `openlibm`'s implementation
and CUDA's `libdevice` implementation already agree to within the measured
ulp-ensemble envelope on the certification case -- in which case no project-owned
replacement is needed for that function -- or not, in which case
`FunctionAccuracyTests.jl`'s exhaustive sweep is the harness to certify the
replacement against.

### SpecialFunctions.jl, Bessels.jl (JuliaMath)

Named because the brief calls out special functions explicitly, but out of this
group's core remit (they bear on radiation and stellar-spectrum decisions, not
0006/0010/0011/0029 directly), so recorded here rather than deep-read.
`SpecialFunctions.jl` wraps `openspecfun` (C: AMOS and Faddeeva) for Bessel, Airy,
error and gamma functions -- not kernel-safe as shipped. `Bessels.jl` is a pure-Julia
reimplementation of the same functional surface, which is what a GPU kernel could
actually call. Whichever radiative-transfer or stellar-spectrum survey group owns
decision 0016 should read `Bessels.jl` on its own merits when that work opens; this
group's finding is only the CPU-C-library-vs-pure-Julia split.

### AlgebraicMultigrid.jl, IterativeSolvers.jl, LinearMaps.jl, GenericLinearAlgebra.jl (JuliaLinearAlgebra)

The four together answer the description doc's pointer to multigrid for isostasy,
free-surface and groundwater solves, and decision 0011's placement of "the
box-constrained water-table solve" on the CPU backend as a sequential algorithm.

`AlgebraicMultigrid.jl` (`src/multilevel.jl`, `src/smoother.jl`,
`src/aggregation.jl`, `src/strength.jl`) is CPU-only: it depends only on
`SparseArrays`/`LinearSolve`, no `CUDA`/`GPUArrays`/`KernelAbstractions` anywhere in
`src` or `Project.toml`. That is not a defect for this project -- decision 0011
already assigns sequential and sparse algorithms to the CPU backend by design, and
classical AMG's smoothers (Gauss-Seidel sweeps) are loop-carried and not naturally
data-parallel in the first place, which is exactly why they belong there. The setup
phase (strength-of-connection, aggregation) is a sequential graph algorithm over a
`SparseMatrixCSC`, also CPU-shaped.

`IterativeSolvers.jl` (`src/cg.jl`, `src/gmres.jl`, `src/minres.jl`) is written
generically against `mul!`/`dot`/`axpy!` from `LinearAlgebra`, with no `CUDA` or
`GPUArrays` import anywhere in `src` or `Project.toml` -- meaning it is plausible
that `cg`/`gmres`/`minres` already run over a `CuArray` operand through Julia's
generic dispatch (`CuArray` overloads those same generic functions via GPUArrays),
but the package neither tests nor claims this, so it must be verified rather than
assumed. `LinearMaps.jl` is the missing link if it does: it wraps a function-defined
operator (a hand-written KernelAbstractions stencil kernel behind a `mul!`, never
forming a sparse matrix) so it satisfies `IterativeSolvers.jl`'s operator interface,
giving a matrix-free GPU-resident Krylov solve for the same free-surface/isostasy
problems the smoother sits above. `GenericLinearAlgebra.jl` is the pure-Julia
LAPACK-equivalent `DoubleFloats.jl` itself depends on for `DoubleFloat`/`BigFloat`
linear algebra, worth knowing about only if a double-double reservoir field ever
needs more than accumulation (a small dense solve, say), which is not foreseeable
yet.

**Question a closer look should answer:** does `IterativeSolvers.cg` (or `gmres`) run
unmodified over a `CuArray` right-hand side and a `LinearMaps.jl`-wrapped
KernelAbstractions stencil operator standing in for the sparse Laplacian, and if so,
does its convergence-history bookkeeping (which mutates a plain `Vector`) force a
host round-trip per iteration that would dominate the timing at production mesh
sizes -- because if it does, decision 0011's CPU-backend placement for the
sequential solve should include "the residual history stays on the CPU by design,"
not "by an accident of this package's internals."

### DimensionalData.jl

`src/array/broadcast.jl` is the file the description doc points at, and it earns the
attention: `DimensionalStyle{S <: AbstractArrayStyle, N} <: AbstractArrayStyle{N}`
wraps the *inner* array's own `BroadcastStyle` as a type parameter `S`
(`BroadcastStyle(::Type{<:AbstractDimArray{T,N,D,A}}) = DimensionalStyle(BroadcastStyle(A))`),
so a `DimArray` wrapping a `CuArray` gets `DimensionalStyle{CUDA.CuArrayStyle{N}, N}`
and every broadcast still resolves to the CUDA kernel path underneath. Dimension
metadata survives broadcasting through three more methods in the same file:
`Broadcast.instantiate` (checks the broadcasted dims agree, computes output axes
carrying dims via `Dimensions.DimUnitRange`), `Base.similar(bc::Broadcasted{<:DimensionalStyle{S}},
::Type{T})` (allocates via the *inner* style, then re-wraps with `similar(A; data,
dims=...)`), and `Base.copy` (same pattern for the non-in-place path). None of this
allocates beyond what the inner array's own broadcast machinery already allocates,
and none of it drops the outer type's parameters -- `rebuild` reconstructs the
dimension-carrying wrapper every time rather than the machinery returning a bare
array.

The Adapt extension (`ext/DimensionalDataAdaptExt.jl`) is the second finding: it
defines `Adapt.adapt_structure(to, m::Metadata) = NoMetadata()` with the comment
"Metadata nearly always contains strings, which break GPU compat," and separately
adapts `Lookup`, `Span` and `Dimension` wrapper types by recursing into their data
while dropping their metadata the same way. This is a worked precedent for
`Field`'s own device-adapt path and `Provenance` in decision 0006's sketch.

**Question a closer look should answer:** does `Field{S,T,D,L,A}`'s dispatch on `S`,
`T`, `D` and `L` (four extra type parameters DimensionalData.jl does not have --
its dimension identity lives in a runtime `dims` tuple, not the type) survive being
threaded through the same `DimensionalStyle`-wrapping-the-inner-style pattern, or
does `BroadcastStyle`'s single free type parameter `S` force `Field` to either fold
`S`/`T`/`D`/`L` into one packed style type or give up carrying all four through
broadcast the way `Field`'s own operator table (which dispatches on all four
directly, not through `Broadcast.broadcasted`) already does without this problem?

### AcceleratedKernels.jl

Cross-backend `map`/`reduce`/`sort`/`accumulate` over KernelAbstractions, positioned
by the description doc as the source of high-performance reduction and sorting
primitives -- directly relevant to decision 0029's "the reduction primitives are
written once, in the kernel library, and every component uses them."

The GPU reduction path (`src/reduce/mapreduce_1d_gpu.jl`, `_mapreduce_block!`) uses a
fixed `block_size` (must be a power of two, `1 <= block_size <= 1024`) and a fixed
`items_per_thread`, both passed explicitly rather than inferred from live thread
count -- this shape is compatible with decision 0029's "fixed block size for every
global and per-column reduction."

The CPU reduction path is the finding that needs acting on. `mapreduce_1d_cpu`
(`src/reduce/mapreduce_1d_cpu.jl`) builds a `TaskPartitioner(length(src), max_tasks,
min_elems)`, reduces each task's chunk independently with `Base.mapreduce`, then
combines the per-task results with `Base.reduce(op, shared)`. `TaskPartitioner`'s own
default (`src/task_partitioner.jl`) is `max_tasks = Threads.nthreads()`. For a
non-associative-in-floating-point operator like `+`, the number of chunks changes
which partial sums get added in which order, so the default CPU `AK.sum` (and any
other default-`max_tasks` CPU reduction) is not thread-count invariant -- a direct
conflict with decision 0029's "one-thread and sixteen-thread CPU runs are bitwise
identical." The fix is available in the package's own API (pass a fixed `max_tasks`
and `min_elems` at every call site, never rely on the `Threads.nthreads()` default),
but it is not what a caller gets by default, and nothing in the package flags the
mismatch.

**Question a closer look should answer:** with `max_tasks` and `min_elems` pinned to
fixed values (not `Threads.nthreads()`) at every call site this project would use,
does a one-thread and a sixteen-thread run of `AcceleratedKernels.reduce` over the
project's own `+` and `neutral_element` produce bitwise identical output on the short
coupled case, and is pinning those two keywords enough, or does the GPU path's
`block_size`/`items_per_thread` selection (`src/reduce/mapreduce_1d_gpu.jl`, around
where `blocks` is computed) also need to be forced to a fixed value per device rather
than sized from the input length, to keep two separate launches on the same GPU
bitwise identical as decision 0029 also requires?

### Bumper.jl

A task-local bump/arena allocator: `@no_escape` opens a scope, allocations inside it
come from a slab that grows dynamically and is reset (not freed) at scope exit, so
allocation inside the scope is close to stack-allocation cost with none of
`StaticArrays.jl`'s compile-time-size restriction. This is the concrete answer to
decision 0011's zero-heap-allocation requirement for any column kernel whose scratch
size is not known until runtime (a root-finding loop's working array, a variable-length
line-list slice for radiative transfer), which an `SVector` cannot cover because its
length is a type parameter fixed at compile time.

**Question a closer look should answer:** does a `@no_escape` block used inside a
`KernelAbstractions.@kernel` function on the CUDA backend allocate from a per-thread
or per-block slab (needed for correctness under concurrent threads), or does Bumper's
task-local design assume CPU-style one-scope-per-Julia-task and therefore only work
correctly on the CPU backend -- in which case its use is confined to the CPU-backend
sequential algorithms decision 0011 already carves out (the water-table solve, the
depression-hierarchy construction), not GPU column kernels at all.

### StaticCompiler.jl

An experimental ahead-of-time compiler that produces a standalone library with no
Julia runtime dependency. The project relevance is not shipping standalone binaries
(fiddlybits is one Julia process per decision 0011) but the compilation requirement
itself: `StaticCompiler.compile` fails on dynamic allocation and most forms of
dynamic dispatch, which makes a successful compile a free, independent proof that a
given function is allocation-free and dispatch-free -- a check distinct from and
stronger than a runtime allocation-counting test, and one that could run as a CI lint
pass over each declared column-physics kernel alongside the enumeration test decision
0006 already requires.

**Question a closer look should answer:** can `StaticCompiler.compile` (or its
lower-level `generate_obj`/`irgen` path) be pointed at one of this project's
KernelAbstractions kernel bodies directly (not the whole `@kernel`-generated
launch machinery, just the per-cell physics function it wraps), and does a compile
failure reliably localise to the actual offending allocation or dynamic dispatch site
well enough to be worth wiring into CI, or does the `@kernel` macro's own generated
code defeat that kind of direct compilation and require pulling the physics body out
into a plain function first (which decision 0011's "few kernels per step, column
physics fused" structure may already do naturally)?

### CUDA.jl, KernelAbstractions.jl, GPUArrays.jl (residual findings beyond `docs/imports/`)

Two findings beyond what `docs/imports/cuda.md` and `docs/imports/kernelabstractions.md`
already record. First, `GPUArrays.jl`'s generic `Base.mapreduce`/`mapreducedim!`
(`src/host/mapreduce.jl`, the path `CuArray`'s `sum`/`reduce` resolve to when no
project-specific reduction is used) has no documented fixed-order or fixed-block-size
guarantee in that file the way `AcceleratedKernels.jl`'s does -- this is exactly the
"library routine whose reduction order is not deterministic" decision 0029 already
warns against in its consequences section, and `cuda.md`'s "no library reductions in
the ledger path" line already covers it, but this confirms the concrete file to point
a lint or a comment at if `Base.sum(::CuArray)` ever shows up in physics code by
accident. Second, `GPUArrays.jl/lib/JLArrays` is a pure-Julia, CPU-backed array type
that presents the same `AbstractGPUArray` interface as `CuArray` without needing GPU
hardware -- it is already a test dependency of `StructArrays.jl` and of
`GPUArrays.jl`'s own test suite. It is a candidate third backend (alongside the real
CPU and CUDA backends) for exercising the "GPU code path" shape of a kernel in CI on
machines without a GPU, though it would not exercise real device timing or real
FP32-throttle behaviour.

**Question a closer look should answer:** does `JLArrays.JLArray` pass the same
elementwise-bitwise-identity oracle decision 0011 and decision 0029 already require
between the CPU and CUDA backends, and if so, is it worth adding as a required
third leg of that oracle (CPU vs. CUDA vs. JLArrays) so the GPU-shaped code path gets
exercised on every CI machine, not only ones with a card?

## Commit record

Every tree was read at the commit named below, recorded with `git -C <tree>
rev-parse --short HEAD`. `AbstractArraysOfArrays.jl` and `StaticBitSets.jl` have a
git history but an empty checked-out working tree; `StaticBitSets.jl` additionally
has no commit at all (an unborn `master` branch), so both were dismissed on that
basis alone rather than on content.

#### Direct trees

| repo | commit |
| --- | --- |
| CUDA.jl | c34b904a2 |
| KernelAbstractions.jl | 18c697d7 |
| GPUArrays.jl | 49ac504 |
| AcceleratedKernels.jl | 0287c81 |
| DimensionalData.jl | 66659c5 |
| StaticCompiler.jl | 7e36691 |
| Bumper.jl | 7683109 |

#### JuliaArrays

| repo | commit |
| --- | --- |
| AbstractArraysOfArrays.jl | 0c2fb41 |
| ArrayInterface.jl | 8f4fb2e |
| ArraysOfArrays.jl | 59a45f4 |
| ArrayViews.jl | 9b4e077 |
| AxisArrays.jl | ad519de |
| BlockArrays.jl | 2f3c99e |
| BlockDiagonals.jl | d1b2191 |
| CatIndices.jl | debb515 |
| CheckedSizeProduct.jl | cbd7ffd |
| CustomUnitRanges.jl | e7567cf |
| DualArrays.jl | 0f0bb73 |
| ElasticArrays.jl | 87c72ec |
| EndpointRanges.jl | f7ae595 |
| FFTViews.jl | d603d6e |
| FillArrays.jl | 466c058 |
| FixedSizeArrays.jl | 3d1d428 |
| GetindexArrays.jl | 293aaba |
| HybridArrays.jl | 37177a3 |
| IdentityRanges.jl | 0d640a9 |
| IndirectArrays.jl | 03aeb5e |
| InfiniteArrays.jl | d19aee1 |
| LazyArrays.jl | 9fd9b32 |
| LazyGrids.jl | f311038 |
| LightBoundsErrors.jl | 9f7898d |
| MappedArrays.jl | 51c0f77 |
| MetadataArrays.jl | 09672ac |
| MosaicViews.jl | 478b2ed |
| NamedDims.jl | e0dea46 |
| NonResizableVectors.jl | 9e19312 |
| OffsetArrays.jl | 90ebc5f |
| OneTwoMany.jl | 0810450 |
| PaddedViews.jl | ae1c346 |
| RangeArrays.jl | 0d36eb5 |
| Ranges.jl | 1bc247b |
| ReadOnlyArrays.jl | a7f398a |
| ShiftedArrays.jl | 3eecdbc |
| ShowItLikeYouBuildIt.jl | 7dd238d |
| SpatioTemporalTraits.jl | 649d4f7 |
| SquareBlockDiagonalArrays | 33227ed |
| StackViews.jl | 758abd4 |
| StaticArrayInterface.jl | b0b24f9 |
| StaticArraysCore.jl | e1d176a |
| StaticArrays.jl | 8935f70 |
| StaticBitSets.jl | (no commits; unborn branch) |
| StructArrays.jl | 54d7545 |
| StructsOfArrays.jl | 727925d |
| TiledIteration.jl | 01d112c |
| UnalignedVectors.jl | e6eda30 |
| UnsafeArrays.jl | dd6d437 |
| ZeroDimensionalArrays.jl | 9beef22 |

#### JuliaMath

| repo | commit |
| --- | --- |
| AbstractFFTs.jl | 31fc5f4 |
| AccurateArithmetic.jl | 3427289 |
| Bessels.jl | 009b615 |
| BFloat16s.jl | b45b12a |
| Calculus.jl | 0386ee2 |
| ChangePrecision.jl | 5474062 |
| ChangesOfVariables.jl | cb671fb |
| CheckedArithmetic.jl | d03ed53 |
| Combinatorics.jl | ad94620 |
| Cubature.jl | aa9143f |
| DecFP.jl | 99bebb8 |
| Decimals.jl | e6b110b |
| DensityInterface.jl | 4c4f066 |
| Dierckx.jl | dd942e4 |
| DoubleDouble.jl | a3dff86 |
| DoubleFloats.jl | 9b37877d |
| DSFMTBuilder | 748c210 |
| FastChebInterp.jl | abe101d |
| FastPow.jl | 584df88 |
| FFTA.jl | 651190f |
| FFTWBuilder | 0e1fe0a |
| FFTW.jl | 290d161 |
| FixedPointDecimals.jl | a61f918 |
| FixedPointNumbers.jl | d1a812f |
| Float8s.jl | 61daa31 |
| FunctionAccuracyTests.jl | 97c84db |
| FunctionZeros.jl | 59b61ba |
| Gamma.jl | a87e984 |
| GMPBuilder | 7131330 |
| GSL.jl | 199242a |
| Hadamard.jl | f47bda7 |
| HCubature.jl | a946726 |
| HypergeometricFunctions.jl | 9a40a7a |
| ILog2.jl | f115a4f |
| Infinities.jl | 13f9e1f |
| IntegerMathUtils.jl | 0a687ff |
| IntelVectorMath.jl | 7bf40dc |
| Interpolations.jl | 1564d00 |
| IntervalSets.jl | 14a3aec |
| InverseFunctions.jl | f6240c1 |
| InverseLaplace.jl | 7811acf |
| IrrationalConstants.jl | 7047878 |
| KahanSummation.jl | 28171c6 |
| LambertW.jl | 8666d64 |
| Libm.jl | cd3d743 |
| MeasureBase.jl | 7abad19 |
| MeasureTheory.jl | 84440f8 |
| MittagLeffler.jl | 1059181 |
| MPFRBuilder | 9b72675 |
| NaNMath.jl | 2cdb23a |
| NestedNumbers.jl | 9569b9f |
| NFFT.jl | d9b72dc |
| NumericalIntegration.jl | 5a71ce0 |
| openlibm | 5fe3997 |
| OpenlibmBuilder | 70f490b |
| openlibm-test | 164e1dc |
| openspecfun | e98d4f4 |
| OpenspecfunBuilder | b260669 |
| OverflowContexts.jl | 58271af |
| Polynomials.jl | e663f40 |
| Primes.jl | 2d6a3ad |
| QuadGK.jl | 0e016df |
| Quadmath.jl | 56f3ea8 |
| RandomMatrices.jl | 0fde454 |
| RealDot.jl | 1e4a6ad |
| RealFFTs.jl | 24fae07 |
| Richardson.jl | d23576f |
| Roadmap.jl | 12aec80 |
| Roots.jl | e1607e5 |
| RoundingIntegers.jl | d6606af |
| Sobol.jl | c108557 |
| SpecialFunctions.jl | b2a7190 |
| Tau.jl | b4ba137 |
| TensorCore.jl | ac1dbab |
| TupleVectorSpaces.jl | 0750858 |
| VisualizeULPError.jl | 8bd085b |
| WrightOmega.jl | dc986f8 |
| Xsum.jl | e6fc0ae |
| Yeppp.jl | f727ee7 |

#### JuliaLinearAlgebra

| repo | commit |
| --- | --- |
| AlgebraicMultigrid.jl | 9377968 |
| AOCL.jl | df8f4d8 |
| AppleAccelerate.jl | 9c7a1c3 |
| ArnoldiMethod.jl | c44070e |
| ArpackBuilder | ed55085 |
| Arpack.jl | 7ca0514 |
| ArpackMKLBuilder | 8889f16 |
| ArpackMKL.jl | dfac5d7 |
| ArrayLayouts.jl | b506a73 |
| BandedMatrices.jl | a8e4257 |
| BenchmarkPlottingUtilities.jl | 24956b8 |
| BLASBenchmarksCPU.jl | 9616594 |
| BLASBenchmarksGPU.jl | b9c072c |
| BLISBLAS.jl | 0e54ff4 |
| BLIS.jl | 255808a |
| BlockBandedMatrices.jl | 102555c |
| GenericLinearAlgebra.jl | 658cf62 |
| GenericSVD.jl | 123c435 |
| HierarchicalMatrices.jl | e0faa95 |
| IncrementalSVD.jl | 906c238 |
| InfiniteLinearAlgebra.jl | 67de4a5 |
| IterativeSolvers.jl | 36844eb |
| LAPACK.jl | 21ba68a |
| LazyBandedMatrices.jl | 7e2c83b |
| libblastrampoline | 6e5b0f2 |
| LinearMaps.jl | 633b928 |
| LowRankApprox.jl | 79327f5 |
| LowRankMatrices.jl | fe8afd3 |
| Magma.jl | 64c6c03 |
| MatrixDepot.jl | 7bda045 |
| MatrixFactorizations.jl | 5982d01 |
| MKL.jl | ed422ad |
| MultiThreadedLU.jl | 10f9cbc |
| NonNegLeastSquares.jl | a13aba5 |
| Octavian.jl | 83f70f1 |
| OpenBLAS32.jl | 8b1051e |
| OpenBLASBuilder | 5a6eca3 |
| Preconditioners.jl | 780abf6 |
| RandomizedLinAlg.jl | be60f87 |
| RectangularFullPacked.jl | 4b44b1c |
| RecursiveFactorization.jl | 22007f5 |
| SemiseparableMatrices.jl | 525942c |
| SkewLinearAlgebra.jl | 08d6868 |
| SparseLinearAlgebra.jl | 72ea3f1 |
| SpecialMatrices.jl | 645eca2 |
| SuiteSparseBuilder | 1e43518 |
| ToeplitzMatrices.jl | c1aa6c2 |
| TSVD.jl | 8a45782 |
| WoodburyMatrices.jl | dd1fade |

## Recommended rows

1. **Import review: StructArrays.jl.** Verdict served: import review above. Timed to
   M0, alongside `Field`'s own implementation, since decision 0011's cells-first
   column-state layout is exactly what it provides and the Adapt/KernelAbstractions
   integration is already present in the pinned tree.
2. **Import review: StaticArrays.jl.** Verdict served: import review above. Timed to
   M0, alongside StructArrays.jl, for the same per-cell-state reason; the review
   should include the register-pressure question above.
3. **Import review: DoubleFloats.jl, scoped to the compensated-arithmetic core.**
   Verdict served: import review above. Timed to M0, since decision 0011 and decision
   0029 both require ledgers and reservoirs in double precision or compensated
   summation from the first coupled column onward, and the reduction primitives
   decision 0029 wants "written once, in the kernel library" belong in the same
   infrastructure pass. The review should explicitly decide between depending on the
   whole package versus writing a project-owned accumulator from
   `AccurateArithmetic.jl`'s `two_sum`/`two_prod` primitives.
4. **Import review: AcceleratedKernels.jl, with the max_tasks fix as an explicit
   checklist item.** Verdict served: import review above. Timed to M0, for the same
   kernel-library-primitives reason as row 3. The review's C4 (fail-open branches)
   checklist item should record `max_tasks=Threads.nthreads()` as the fail-open
   default and name the fixed value(s) this project pins at every call site.
5. **Algorithmic reference note: AlgebraicMultigrid.jl plus IterativeSolvers.jl plus
   LinearMaps.jl, read together, for the CPU-backend hydrology solve.** Verdict
   served: algorithmic reference above (three rows). Timed to M2 (hydrology:
   drainage, lake cascade, groundwater, wetness), when the box-constrained
   water-table solve decision 0011 already assigns to the CPU backend is actually
   designed. The note should answer the `IterativeSolvers.cg`-over-`CuArray`
   question above before deciding whether any part of that solve could move off the
   CPU backend after all.
6. **Import review: Bumper.jl.** Verdict served: import review above. Timed to M4
   (radiation pipeline, column physics), which is where the first column kernels
   with runtime-sized scratch needs (a root-finding loop, a variable-length
   line-list slice) appear; earlier milestones' kernels are simple enough that
   `StaticArrays.jl` alone likely covers their per-cell state.
7. **CI lint note: StaticCompiler.jl as an allocation-free/dispatch-free kernel
   check.** Verdict served: algorithmic reference above. Timed to M0, alongside the
   enumeration test and static-analysis pass decision 0006 already requires for
   missing methods, since this is the same kind of build-time discipline check for
   decision 0011's zero-allocation rule.
