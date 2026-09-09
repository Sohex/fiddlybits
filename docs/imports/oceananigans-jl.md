# Oceananigans.jl

*Julia identifiers are transliterated to ASCII below where the source spells them
with Greek letters or with superscript location tags; the tags are described in
words instead.*

**What it is.** A finite-volume ocean and large-eddy simulation model on
structured grids, built on KernelAbstractions with CPU, GPU and Reactant
architectures, MPI distribution, and a composable model-building interface.

**What of it is used.** Nothing, and decision 0012 already says so. This record
confirms that verdict against the source, sharpens one clause of it, and answers
the two questions the plan asks about what carries.

**Confirming 0012's grid verdict.** Confirmed, not corrected. `src/Grids/` holds
`RectilinearGrid`, `LatitudeLongitudeGrid` and `OrthogonalSphericalShellGrid`, and
`src/OrthogonalSphericalShellGrids/` adds a conformal cubed sphere panel, a
tripolar grid, a rotated latitude-longitude grid and a Lambert conformal conic
grid. Every one is logically rectangular, and the whole operator library is
indexed by a triple of integers into a structured array. There is no unstructured
or icosahedral option and no seam at which one could be added without rewriting
`src/Operators/` entire. An ocean here under an icosahedral atmosphere would be
the grid crossing this design exists to delete.

**Correcting 0012's radius clause, in the direction of severity.** 0012 records
that "radius defaults to Earth's". The source says something stronger.
`src/Oceananigans.jl` declares a `mutable struct Defaults` with four fields, the
floating-point type, the gravitational acceleration, the planet radius and the
planet rotation rate, and instantiates it once as a process-wide constant binding
to a mutable object, with Earth's conventional standard gravity, Earth's radius
and Earth's angular speed as the defaults, each with a comment naming Earth and
citing an encyclopaedia entry. Every spherical grid constructor, every Coriolis
constructor (`FPlane`, `BetaPlane`, `ConstantCartesianCoriolis`), the seawater
buoyancy force, and, downstream, `ClimaSeaIce`'s liquidus, phase transitions,
rheologies and momentum equation all read that object silently at construction
time. So the Earth default is not a keyword on a constructor that a caller
overrides once; it is mutable global state that is read at an unbounded number of
sites, and two structs built either side of a mutation disagree with no record of
which is authoritative. That makes it simultaneously an A2 finding (the planetary
constant block), a C4 finding (a silent default across a component boundary) and a
C5 finding (a second copy of live state). The clause in 0012 should read that the
radius, gravity, rotation rate and float type come from a mutable process-global
defaults object.

**What the location typing provides that this project's Field would want.** The
abstract type is `AbstractField{LX, LY, LZ, G, T, N} <: AbstractArray{T, N}`,
where each of the three location parameters is `Center`, `Face` or `Nothing`, and
`location(f)` recovers the triple from the type with no instantiation and no
runtime cost. Four consequences follow, and all four are worth having:

1. **Staggering is a compile-time property of the value, not a convention in a
   comment.** An operator that consumes a centre field and produces a face field
   says so in its name and enforces it by dispatch, so a mis-staggered argument is
   a method error rather than a wrong number. This is decision 0003's rule that
   conventions travel by name, expressed in a type system.
2. **A field cannot disagree with the mesh about its own extent.** `size(f)` is
   defined as `size(f.grid, location(f))`, so the array shape is derived from the
   grid and the location and is never stored on the field. There is one
   definition of how many cells there are.
3. **Legality of a boundary condition at a location is a method, not a runtime
   check.** `validate_boundary_condition_location` accepts anything at a `Center`
   and accepts only a normal-flow, communication, `Nothing` or `Missing` condition
   at a `Face`, and throws for everything else at construction. A rule about where
   a condition may live is written once and cannot be forgotten at a call site.
4. **A reduced-dimension field lives in the same type.** `Nothing` as a location
   is how a surface field is spelled, so a two-dimensional field and a
   three-dimensional field are the same struct and the same operators apply, which
   is what this project needs for a surface quantity on a column mesh.

The part that does not carry is the *arity* of the encoding. Three per-axis
location parameters is a statement that the mesh has three independent staggering
axes, which is true of a structured grid and false of a triangle C-grid, where the
locations are a single enumeration (cell centre, edge with a normal direction,
vertex). The idea to borrow is "location in the type, extent derived from it,
boundary-condition legality by dispatch"; the encoding to reject is the triple.

**Is the operator design separable from the structured grid.** Half of it, and the
halves separate cleanly.

Separable, and directly usable: the finite-volume form. The cell-centred
divergence is written as the reciprocal cell volume times the sum of the
differences of the face-area-weighted fluxes along each axis, where the areas and
the volume are asked of the grid by name and the operator knows nothing else about
the geometry. That is exactly a triangle C-grid divergence with the edge lengths
and cell areas of the connectivity graph substituted, and the pattern of keeping
the metric entirely inside named grid accessors carries whole. So does a second
pattern: every difference and interpolation operator accepts a *function* of the
index and the grid in the same argument slot as a field, so stencils compose over
a lazily evaluated expression without materialising an intermediate array. And so
does a third: `Flat` is a topology, and each operator has a method dispatching on
it that returns a zero of the element type, so a degenerate dimension is removed
at compile time rather than tested at runtime.

Not separable: the neighbour. The base difference to a face location is literally
the value at an index minus the value at that index less one. The stencil is
arithmetic on the index, so on an unstructured mesh every one of these bodies
becomes a table lookup through the connectivity graph and nothing of the
implementation survives, only the shape. Halo regions, `total_size` and the
fill-halo machinery are likewise structured-grid constructs.

**The boundary-condition design, which 0012 already borrows.** A
`BoundaryCondition{Classification, Condition}` puts the classification in the type
(`Value`, `Gradient`, `Flux`, `Periodic`, `NormalFlow`, `Mixed`, plus
multi-region and distributed communication classifications and a `Zipper` for a
tripolar seam) and admits as its condition a number, an array, a field, a
continuous function of the two coordinates along the boundary and time, or a
discrete function of the boundary indices, the grid, the clock and the model
fields. The continuous form is regularised for the field's location when the
condition set is constructed, and the whole struct has an `Adapt.adapt_structure`
method so it reaches a kernel. That shape carries to a triangle mesh unchanged,
with one caveat for this project: the continuous form is a function of coordinates
along the boundary, and decision 0003 says conventions travel by name and never by
coordinate, so the equivalent here would be a function of the named boundary
element rather than of a parameterisation of it.

**Assumptions it carries, checked item by item.**

| item | finding |
| --- | --- |
| A1, calendar | one statement of a day, in `src/Units.jl`, where a day is defined as twenty-four hours as a script convenience for setting a stop time; the model clock is a mutable `Clock` whose time is a plain number of SI seconds, with a `DateTime` accepted as an alternative. Enumerated, and the default is SI |
| A2, planetary constants | the block is the mutable `defaults` object described above: float type, gravity, planet radius, planet rotation rate. All runtime, all Earth-defaulted |
| A3, Earth literals | the conventional standard gravity, Earth's radius and Earth's angular speed all appear, all three inside that one block, each with a comment naming Earth. Accounted for, and they are the whole of it |
| A6, grid, topology and index base | structured and logically rectangular throughout, with halo regions and one-based interior indexing with explicit halo offsets; `Flat` is a compile-time topology; the grid topology is a type parameter, so a change of topology is a recompile |
| precision | the default float type is a field of the mutable defaults object and starts at double precision; `BFloat16s` is a dependency, so reduced precision is a supported path |
| threading and GPU | KernelAbstractions with `CPU`, a parameterised `GPU` and a `ReactantState` architecture; `Adapt` throughout so structs reach kernels; `DistributedComputations` over MPI and `MultiRegion` for panelled grids. Decision 0012 does not adopt Reactant's traced style, and this is where it would enter |
| mutable global state | present and load-bearing, as above. This is the finding of the record |
| B4, comment against value | the comments beside the three Earth constants match their values and name the planet; the package is honest about it, which is exactly why the constants cannot come along |
| B5, clamps and limiters | not surveyed exhaustively; the advection and closure modules were not read |
| C3, declared against demonstrated | the radius, gravity and rotation rate are declared as settable and are demonstrated so (they are ordinary fields on the grid and the Coriolis struct); the icosahedral capability is neither declared nor present |
| C5, second copies | the defaults object is itself the second copy: a grid holds its own radius and a Coriolis force its own rotation rate, both seeded from the global, and neither is thereafter tied to it |

**Where it is Earth-fitted in its data but general in its code.** Unusually for
this group, the code is general and the *state* is Earth: nothing in the operators
or the field design knows a planet, and the entire planetary content of the
package is four numbers in one mutable struct. That is why the idea-borrow verdict
is the right one and why the grid, not the constants, is the disqualifying
feature.

**Licence.** MIT. **Version.** 0.112.0, read against commit
`31d9b76a94b44c023d0473ca3f373a22aa8690f6` on `main`, dated 2026-09-09. Read
deeply in `src/Fields/`, `src/Operators/`, `src/BoundaryConditions/`,
`src/Grids/`, `src/Coriolis/` and the top-level module; read shallowly in
`src/TurbulenceClosures/`, `src/Advection/`, `src/Solvers/`, `src/Models/` and
`src/ImmersedBoundaries/`, which bear on none of the questions asked here.

**Verdict: borrow ideas only.** Decision 0012's verdict stands: the grid is
structured and there is no icosahedral option, so it cannot be a component; but
the location-typed field, the derivation of extent from location and grid, the
boundary-condition classification-in-the-type with a continuous or discrete
condition, the metric-in-named-grid-accessors finite-volume operator form, the
function-in-the-field-slot stencil composition and the `Flat` compile-time
degenerate dimension are all worth reproducing. The one amendment 0012 needs is to
its radius clause: the Earth values are a mutable process-global, not a
constructor default.
