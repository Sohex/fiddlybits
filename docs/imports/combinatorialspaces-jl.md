# CombinatorialSpaces.jl

**What it is.** A discrete-exterior-calculus engine over simplicial complexes carried as
attributed C-sets: a schema of tables for vertices, edges, triangles and their
incidences, plus the circumcentric dual of the same complex, with the boundary,
coboundary, Hodge star, sharp, flat, wedge and Laplace-Beltrami operators written
against those tables. Complexes embedded in three dimensions are a first-class case, so
a sphere is not a special construction here, and the pointwise wedge kernels are written
in `KernelAbstractions.jl` with CUDA and Metal extension modules.

**What of it is used.** Nothing. This is a reading record. It is read because decision
0005 builds an icosahedral bisection hierarchy with triangle cells and an explicit
connectivity record, and decision 0013 puts a finite-volume C-grid on those triangles,
and this is the one surveyed tree that already holds the whole geometric engine those two
describe.

**Licence.** MIT. **Version.** 0.10.1. **Read at.**
`6ed8acf4a88c2d4940ef62cdb99f2617bf375c75`, committed 2026-06-14, in
`/home/cfutro/git/AlgebraicJulia/CombinatorialSpaces.jl`. Read:
`src/DiscreteExteriorCalculus.jl`, `src/FastDEC.jl`, `src/Multigrid.jl`,
`src/SimplicialSets.jl`, `src/CombMeshes.jl`, `src/MeshOptimization.jl`, `ext/`,
`test/Multigrid.jl`, `Project.toml` and `Artifacts.toml`.

**Verdict.** Algorithmic reference, not a dependency, and the reason is a measure and not
a licence. Its operators are defined on the polyhedron the mesh vertices span; decision
0005 declares its cells on the sphere those vertices lie on. Both are coherent
discretisations and they are not the same one, so the operator definitions can be read
and their construction reused, and the numbers they produce cannot be mixed with this
project's.

## The subdivision gap, settled

`propagate_points(::BinarySubdivision, topo, coarse_points)` in `src/Multigrid.jl` places
each new vertex at the flat average of its two parents and returns; no code in
`Multigrid.jl` or in the `PrimalGeometricMapSeries` machinery that drives it normalises
afterwards. The topology beside it is exactly decision 0005's: split every edge at its
midpoint, four children per triangle, original vertices kept and midpoints appended, so
the coarse numbering is a prefix of the fine one.

What the flat midpoint costs is measured in
`notes/findings/2026-09-10-chordal-bisection-and-spherical-area.md`. Every new vertex
lands in the plane of the parent triangle it was born in, so the refined surface never
leaves the polyhedron the base level already described: total area and worst radial
defect are constant under further refinement rather than converging. Refinement buys
resolution and buys no convergence to the sphere. This is not a defect in the library.
`test/Multigrid.jl` exercises subdivision on `triangulated_grid`, a planar mesh, where
the flat midpoint is the right answer and the whole question is empty.

The correction is exact rather than approximate, which is the useful half of the answer.
For two unit vectors the chord midpoint lies in the plane through them and the origin and
bisects their angle, so normalising it returns the great-circle midpoint itself. One
normalisation per new vertex restores exact nesting, and the finding measures the
resulting radial defect at the rounding of that normalisation.

There is no spherical variant elsewhere in the package. `MeshOptimization.jl` carries a
`spherical` flag that renormalises a jittered vertex onto a declared radius during
simulated annealing, and that is the only projection in the tree. The bundled icospheres
are a downloaded artifact of Wavefront files whose generator is not in the tree; the
artifact was fetched and every vertex is on the sphere, to the six decimal places a
Blender export writes, which is measured in the same finding and is why this project
constructs its own base icosahedron rather than loading one.

## Do the operator definitions survive the correction

They survive it untouched, because none of them knows about the sphere, and that is
exactly what has to be recorded about them.

Every length, area and volume in the package is Euclidean. `volume` in
`src/SimplicialSets.jl` is the Cayley-Menger determinant of the embedded points, so a
triangle's area is the flat area of the chord triangle and an edge's length is the chord
length. The dual is circumcentric: `geometric_center(points, ::Circumcenter)` inverts the
Cayley-Menger matrix to get barycentric coordinates and takes that combination of the
points, which for a triangle embedded in three dimensions is the circumcentre in the
triangle's own plane, inside the sphere rather than on it. Dual areas and dual lengths
are then Euclidean measures of those dual points.

The Hodge stars are ratios of exactly those measures, and nothing else
(`dec_p_hodge_diag`, `src/FastDEC.jl`): the 0-form star accumulates dual area onto its
vertex, the 1-form star is dual length over primal length per edge, the 2-form star is the
reciprocal of triangle area. The non-diagonal geometric 1-form star assembles a 3x3 block
per triangle from the same quantities. So substituting spherical measure for Euclidean
measure is a substitution into the same definitions, not a different operator family:
great-circle arc length for chord length, l'Huilier or the vector form for flat area,
spherical dual area for flat dual area. What does not survive is mixing them. A Hodge star
built from chord lengths applied to a flux defined over a spherical cell area is wrong at
second order in spacing, and the finding measures that spacing dependence directly: the
chord-triangle area of the projected hierarchy is short of the spherical area by 4.8e-03
relative at level 3 and 1.9e-05 at level 7.

Two further properties of the construction that carry, and one that does not:

- **The circumcentric dual has no Delaunay guard.** A dual area is a signed Cayley-Menger
  volume of dual points, and nothing in the tree tests that a circumcentre falls inside
  its own triangle. On a near-equilateral icosahedral mesh it always does; on a locally
  refined mesh with graded transition rings (decision 0031) it is a property to check
  rather than assume, and the check belongs in this project's mesh module because it does
  not exist upstream.
- **The wedge products are portable kernels.** `wedge_kernel_01!` through
  `wedge_kernel_21!` in `src/FastDEC.jl` are `KernelAbstractions.@kernel` functions
  dispatched through CUDA and Metal extensions, so the pointwise operator evaluation is
  genuinely backend-portable in the shape decision 0011 asks for. The mesh construction
  around them is not: dual-complex assembly and the factorisation behind the inverse Hodge
  star are CPU sparse and dense linear algebra.
- **The carrier does not carry.** The mesh is an `ACSet` from `Catlab` and `ACSets`, with
  `GATlab` beneath it, and every operator is written against that representation. Decision
  0005's hierarchy is an index rule with dense neighbour tables, where a cell's children
  are an arithmetic expression rather than a table lookup. Taking the operators means
  rewriting them against that representation, which is small work, and taking the package
  would mean adopting the category-theory stack to store a structure this project can
  address arithmetically.

## Assumptions it carries

**Earth defaults (A2, A3).** Clean negative in the operator code. The only hits for the
Earth literal list are in the docstring examples of `makeSphere` in `src/CombMeshes.jl`,
where `6371` and `6371+90` are passed as the radius argument. No constant block exists and
no radius has a default; the example is worth naming only because it is the exact shape of
an implicit-Earth leak, a number that travels as an idiom rather than as an argument.

**Calendar and time (A1).** Clean negative. No `Dates` import anywhere in `src/` or
`ext/`, and no notion of time in the package at all; it is a spatial engine.

**Grid, mesh and index base (A6).** The mesh is the package, so there is nothing implicit
here, but two conventions are fixed. Parts are 1-based `Int` throughout, being `ACSet`
part indices, and the dual complex numbers its dual vertices with the primal vertices
first, then edge centres, then triangle centres, which `dec_p_hodge_diag(::Val{1}, ...)`
depends on by subtracting `nv(sd)` from a dual vertex index to recover an edge. That is an
offset rule inside a hot loop, and it is the same class of thing decision 0010 fixes at
each boundary rather than leaving to arithmetic.

**Precision.** Parametric on the point type and the float type in every operator
signature. The package's own aliases `Point2D` and `Point3D` are Float64, as are
`Point2d`/`Point3d` from `GeometryBasics`, so Float64 is the idiom without being a
constraint. The finding measures why that matters here: cell area in Float32 is wrong in
the fourth digit by level 7 whatever formula is used, so mesh geometry is a Float64
quantity independent of what precision a component runs at.

**Threading and GPU model.** `KernelAbstractions` for the pointwise wedge kernels with
CUDA and Metal extensions; everything else is serial CPU, with sparse assembly and
factorisation from `SparseArrays`, `Krylov` and `LazyArrays`.

**Mutable global state (C5).** Clean negative for state. Module-scope `const`s are type
aliases, operator aliases and the string fragments the dual-type names are generated from.
No cache, no package-level configuration, no second constant set.

**Clamps and limiters (B5).** None in the geometry. The circumcentre inversion carries a
`try`/`catch` on `ArgumentError` that strips units, inverts and restores them, which is a
fallback with a declared cause rather than an open one.

**Declared against demonstrated (C3).** The operator suite is tested. The subdivision
machinery is tested on planar meshes only, so its behaviour on an embedded sphere is
declared by the code's generality and demonstrated nowhere, which is how the flat-midpoint
gap survived. The bundled icosphere artifact is used by tests but its generator is
upstream of the repository.

**Fail-open branches (C4).** Two. The circumcentric dual with no Delaunay or containment
guard, above. And `propagate_points` on an embedded manifold, which returns a mesh that is
no longer on the manifold and reports nothing, which is the same shape: a plausible answer
to a question the caller did not know it was asking.

## What this project takes

1. **The subdivision topology and its numbering**, as the reference to match: split every
   edge, four children per triangle, coarse vertices a prefix of fine. Decision 0005's
   `children(i) = 4i-3:4i` and `parent(i) = (i+3)>>2` are the cell-side statement of the
   same rule, and `refine(::BinarySubdivision, topo)` is a worked edge and triangle
   incidence construction to check an independent implementation against.
2. **The Hodge star as a ratio of dual to primal measure**, with this project's spherical
   measures substituted throughout and the substitution stated once, so that no operator
   mixes chord length with spherical area.
3. **The circumcentric dual construction**, with a containment check added, since decision
   0013's C-grid puts velocity on edges and needs the dual edge that crosses each of them.
4. **The wedge kernels' shape** as a precedent for decision 0011: an operator evaluated
   pointwise over a table of indices in a portable kernel, with the mesh construction left
   on the host.

## Checklist

| item | result |
| --- | --- |
| A1 day and year | clean negative; no `Dates`, no time of any kind |
| A2 planetary constant block | clean negative; no constants beyond type aliases |
| A3 Earth literals | `6371` and `6371+90` as the radius argument in `makeSphere` docstring examples; nowhere in code |
| A6 grid and index base | 1-based `ACSet` parts; dual vertices numbered primal-then-edge-then-triangle, with the offset recovered by subtraction inside `dec_p_hodge_diag` |
| B4 comment against value | no mismatch found; the `Circumcenter` docstring names its source and the code matches it |
| B5 clamps and limiters | none in the geometry; one unit-stripping `try`/`catch` in the circumcentre inversion |
| C1 use site of every constant | the only constants are type aliases; `Point2D`/`Point3D` fix Float64 at their use sites and are not reached by the parametric operator paths |
| C3 declared against demonstrated | operators tested; subdivision tested on planar meshes only; the spherical case is untested and is where the flat-midpoint gap lives |
| C4 fail-open branches | circumcentric dual with no containment guard; `propagate_points` leaving an embedded manifold silently |
| C5 duplicate state and second constant sets | clean negative |
| D2 boundary field by field | not exchanged with; the surface read is the operator definitions, whose measures are Euclidean throughout and are not compatible with spherical-measure cells |
| D4 conservation identity | run here as the identity this project owns: the nesting and area-closure identities of the finding, measured on the projected hierarchy rather than on the package's |

## References

- The measurements: `notes/findings/2026-09-10-chordal-bisection-and-spherical-area.md`.
- The survey entry this record answers: `docs/surveys/mesh-and-discretisation.md`,
  AlgebraicJulia.
- Decision 0005 (one mesh, icosahedral bisection, exact nesting), decision 0010 (the index
  base at each boundary), decision 0011 (portable kernels, precision by declaration),
  decision 0013 (the triangle C-grid), decision 0031 (local refinement and graded rings).
- `docs/oracles/registry.toml`, `mesh.area_closure` and `mesh.nesting_identity`, whose
  thresholds the finding supplies.
- `Decapodes.jl`, the one place these operators are exercised end to end on an equation
  set, is read when decision 0013's horizontal operators are written, not here.
