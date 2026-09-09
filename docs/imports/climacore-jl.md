# ClimaCore.jl

**What it is.** The spatial discretisation library under the CliMA atmosphere and
land models: domains, meshes, topologies, spectral-element and finite-difference
spaces, a `Field` type bound to a space, the operators over them, a
matrix-field solver stack, and input-output. Decision 0012 recorded it as an
idea to borrow (axis-tensor vectors) and refused it as a component (cubed
sphere). This record confirms that from the source and sharpens both halves.

## Is the spatial discretisation separable from the geometry?

Partly, and the part that separates cleanly is the part worth borrowing.

**What does separate.** The operators never see a sphere. They see, at each
quadrature node, a `LocalGeometry` (`src/Geometry/localgeometry.jl`) holding the
node's coordinates, the Jacobian determinant `J`, the quadrature-weighted `WJ`,
the coordinate map `dx/dxi`, and the contravariant metric tensor `g^ij` with the
covariant one recovered by inversion. Curvature, panel orientation and radius
enter only by having shaped those numbers. The vector components the operators
carry are covariant or contravariant in the element's own generalised
coordinates, so the metric is the whole of the geometry an operator reads. That
is a real separation and it is the design idea this project should keep.

The global geometry is a separate, small object
(`src/Geometry/globalgeometry.jl`): `CartesianGlobalGeometry`, or a spherical one
carrying a `radius` field, with `ShallowSphericalGlobalGeometry` and
`DeepSphericalGlobalGeometry` as the two metric treatments. A radius as a
declared field with the shallow and deep variants named is the same shape
decision 0013 chose, and is a clean piece of design.

**What does not separate.** Three things, and they run to the bottom of the
package:

1. **The element is a quadrilateral, by construction.** `AbstractMesh{2}`
   (`src/Meshes/Meshes.jl`) documents faces and vertices as `[1,2,3,4]` with an
   ASCII diagram of a quadrilateral, and `Topology2D`
   (`src/Topologies/topology2d.jl`) loops `for face in 1:4` and `for vert in 1:4`
   literally. A triangle is not expressible in the mesh interface, never mind the
   meshes that implement it.
2. **The data layout is a tensor product inside each element.** The layouts are
   `VIJFH` and its transposes (`src/DataLayouts/DataLayouts.jl`), an
   `Nv x Ni x Nj x Nh` array: vertical level, two element-local quadrature
   indices, element. A triangle has no `(i, j)` pair. Every operator, every
   broadcast and every CUDA launch is written against that shape.
3. **The concrete meshes are three.** `IntervalMesh`, `RectilinearMesh`, and the
   cubed spheres `EquiangularCubedSphere`, `EquidistantCubedSphere` and
   `ConformalCubedSphere` (`src/Meshes/cubedsphere.jl`). There is no unstructured
   mesh and no icosahedron. The file `src/Spaces/triangulation.jl` is not an
   exception: it is twenty-seven lines that cut each quadrilateral element into
   two triangles so a plotting backend can draw it.

So decision 0012's verdict stands and can be stated more sharply than "cubed
sphere". The refusal is not that the shipped mesh happens to be a cubed sphere;
it is that the element topology is welded into the data layout, so a triangle
mesh is not a new `AbstractMesh` subtype but a different library.

## How deeply the geometry reaches into the field type

`Field{V, S}` (`src/Fields/Fields.jl`) is a `DataLayout` and a space, with the
space as a type parameter. Everything about the discretisation is therefore in
the field's type: the mesh type, the quadrature degree, the topology, the
vertical grid and the device. Two fields are on the same grid if their grid
objects are identical by `===`, which is why the package memoises grids (see
mutable global state below).

What the type does not carry is what this project's `Field{S, T, D, L, A}`
(decision 0006) carries: there is no semantics parameter, so nothing distinguishes
an extensive total from an intensive state and nothing dispatches a coarsening
rule; no time semantics, so an interval mean and an instantaneous value are the
same type; no SI dimension; no level in a hierarchy; and no provenance. A
ClimaCore field knows where it lives and nothing about what it means. That is the
axis on which this project's field type is the more careful of the two.

## What the axis-tensor design actually provides

Read against `src/Geometry/tensors.jl` and `src/Geometry/conversions.jl`, three
things this project wants:

- **The basis is on the type, and the component names with it.** A tensor is
  `Tensor{N, T, B, C}` over a tuple of `Components{T, names}` axes, where the
  component type is `Covariant`, `Contravariant`, `Orthonormal` or the trivial
  `OneScalar` row of a covector, and `names` is which components are present, so
  a two-component covariant vector in the first and third directions is a
  distinct type from a three-component one. This is decision 0006's
  `VectorComponent{Basis}` with the sparsity pattern also on the type, and it
  costs nothing at run time because `Components` is a singleton.
- **Raising and lowering an index is the only operation that needs the metric,
  and it says so.** Changing the component type multiplies by `g_ij` or `g^ij`
  from the `LocalGeometry`; reordering, dropping or zero-filling names within one
  component type needs no metric at all and is what `reshape` does. Separating
  those two classes of conversion is exactly decision 0006's rule that east-north
  must be lifted through the source geometry's local frames while a Cartesian
  component may change support directly.
- **There are two conversions, and the strict one refuses.** `project(basis, v,
  local_geometry)` converts and drops what does not fit; `transform` is the same
  conversion but throws an `InexactError` if any dropped component is non-zero.
  A named strict form beside a named lossy form, at the same call site, is a
  better answer than this project's current sketch, which has only the rule that
  an undefined combination does not exist. It is the shape to copy: the lossy
  operation exists, but it has to be asked for by a different name.

The rank-2 machinery (`mul_with_projection.jl`, the `MatrixFields` module) is
where the tensor design earns its keep upstream and is not needed here.

## Assumptions it carries

| assumption | present | how a leak is caught |
| --- | --- | --- |
| Earth defaults | `MultiColumnGrid` in `src/CommonGrids/CommonGrids.jl` defaults `radius = 6.371229e6`, and the module's worked examples use the same number; every other constructor takes the radius from the domain, which is a declared field | not adopted, so nothing to catch; recorded because it is the implicit-Earth pattern decision 0012 named, present in ClimaCore itself and not only in its parameter library |
| calendar or time | none in the discretisation; the package has no clock | n/a |
| grid or mesh | the whole package; quadrilateral elements in the mesh interface, a tensor-product data layout, three concrete meshes of which the spherical ones are cubed | n/a; this is the refusal |
| index base | 1-based, with element-local indices `1:Ni`, `1:Nj` and face and vertex numbering `1:4` | n/a |
| precision | `FT` is a type parameter of the domain and propagates; mixed-precision fields on one grid are not a supported combination | n/a |
| threading and GPU model | CUDA.jl directly, in `ext/cuda`, via `CUDA.@cuda` and an `auto_launch!` helper with its own occupancy logic; not KernelAbstractions, so NVIDIA only and no shared CPU-GPU kernel source | n/a; this project's KernelAbstractions choice (decision 0012) is the incompatible one |
| mutable global state | `Utilities.Cache.OBJECT_CACHE`, a process-global `Dict` that memoises every topology and grid ever constructed and, as its own docstring says, keeps them from the garbage collector until `clean_cache!` is called; `DebugOnly.allow_mismatched_spaces_unsafe` is a redefinable global switch that disables the space-equality check | n/a; recorded as the reason a parameter sweep over grids leaks memory upstream, which is a defect this project's grid identity by content key avoids |
| fail-open branches | `project` silently drops components where `transform` would refuse; the default in most conversion paths is `project` | n/a; the lesson is the one borrowed above |

## Checklist items applied

**A1** none: no day, no year, no calendar type. **A2** no planetary constant
block; the one planetary quantity is `radius`, a field of the domain, defaulted
to one planet's value in exactly one constructor. **A3** the Earth-literal grep
over `src/` returns nothing for `9.81`, `101325`, `1361` or `7.2921e-5`, and
returns `6.371229e6` at three sites, all in `CommonGrids`/`CommonSpaces`
convenience constructors and docstrings. **A6** the compile-time bounds are the
ones that matter: `1:4` faces and vertices in `Topology2D`, and the `(Ni, Nj)`
tensor-product node indices in every data layout. Their rebuild trigger is a
different element topology, which is to say the whole library. **B4** the comment
beside the quadrilateral face numbering is an accurate diagram of the assumption,
which is the honest case. **B5** the limiters in the used surface are none, since
nothing is used. **C1** the one carried constant, `radius`, has its use sites read
in `globalgeometry.jl`, where it sets the spherical metric. **C3** the capability
decision 0012 credited, axis-tensor vectors with named bases, is demonstrated
upstream by the conversion tests and by the `project`/`transform` pair; the
capability this project would have needed, an unstructured element topology, is
neither declared nor demonstrated. **C4** `project` against `transform` is the
fail-open branch, and it has a refusing twin, which is the design to copy.
**C5** the object cache is a second live copy of every grid, and its authoritative
copy is the cache entry, by construction. **D2** not applicable; no array crosses
a boundary into this project. **D4** not applicable for the same reason.

**Licence.** Apache 2.0. **Version.** Read against `main` at commit
`25f0906cc7f423600c5ba045a189bfb6df09251e` (2026-09-08), tagged v0.16.1. No pin,
because nothing is adopted.

## Verdict

**Borrow ideas only**, confirming decision 0012 with the reason restated: the
element topology and the tensor-product data layout are welded together beneath
every operator, so a triangle mesh is a different library rather than a new mesh
subtype, and the cubed sphere is a symptom rather than the disease.

The ideas to carry, beyond the axis-tensor vectors decision 0012 already records:
`LocalGeometry` as the only geometry an operator reads, so the discretisation
depends on a per-node metric and nothing else; the named strict conversion
`transform` beside the lossy `project`, so dropping a component has to be asked
for by name; and the shallow and deep spherical metrics as two named global
geometries over one declared radius. The anti-pattern to record is the
process-global grid cache, which buys grid identity by `===` at the price of a
memory leak across a parameter sweep, where this project buys the same identity
from a content key.
