# CGDycore.jl

**What it is.** An experimental Julia dynamical core from the CliMA organisation,
described in one line in its own README and undersold by it. Beneath the core sits
`src/Grids/`, a collection of sphere discretisations that is unusual in this
organisation and in this ecosystem: triangular, hexagonal, kite, Healpix,
equal-area, cubed and tripolar grids behind one `GridStruct`, with explicit node,
edge and face records, a connectivity routine and a space-filling-curve domain
decomposition, running on `KernelAbstractions` across CUDA and Metal, and
integrating in time with Rosenbrock-W methods.

**What of it is used.** Nothing. This is a survey record. It is read because
`src/Grids/Triangular.jl` builds an icosahedral bisection of the sphere, which is
the discretisation decision 0005 chose, and because it is the one repository in
CliMA whose grid machinery is not welded to the cubed sphere.

**Licence.** Apache 2.0. **Version.** 0.1.0. **Read at.**
`9dfd007f2c600576dd276e53c00fb817dffca7a8`, committed 2026-08-18, in
`/home/cfutro/git/CliMA/CGDycore.jl`.

**Verdict.** Borrow ideas only, and one of them is a negative result. The
refinement is the great-circle bisection decision 0005 requires and the sibling
ordering is the arithmetic hierarchy decision 0005 requires, both arrived at
without being named as properties, tested, or used. Everything built on top of
them, the storage, the radius handling and the connectivity, is the shape this
project refuses. There is nothing here to adopt as infrastructure, and the tree
carries no tests at all, so nothing in it is demonstrated.

## The nesting question, answered from source

This is the question the row was filed to settle, and the answer is favourable.

`MidPoint(P1,P2)` in `src/Grids/Triangular.jl` forms the arithmetic mean of two
node positions and then divides by its own norm:

    function MidPoint(P1::Point,P2::Point)
      P = Point(0.5 * (P1.x + P2.x), 0.5 * (P1.y + P2.y), 0.5 * (P1.z + P2.z))
      M = Div(P, Norm(P) )
    end

For two unit vectors, `(P1 + P2) / |P1 + P2|` is exactly the great-circle
midpoint: it is the unique unit vector in the plane of `P1` and `P2` that
bisects the angle between them. The chordal midpoint is an intermediate value
that the normalisation removes, so the result is the geodesic bisection and not
the flat one. `RefineEdge!` calls it for every edge, and `CreateIcosahedronGrid`
seeds the base vertices on the unit sphere, so every vertex at every level lies
on the sphere and every child edge is a sub-arc of its parent's great circle.
The four children of a triangle therefore tile the parent exactly, which is the
property decision 0005's exact-nesting argument rests on.

This is worth recording precisely because it is the gap that sank the other
candidate. `fiddlybits-bon.1` found that CombinatorialSpaces places a subdivided
vertex at the flat chordal midpoint with no renormalisation. Two trees, the same
subdivision, one line apart: CGDycore normalises and CombinatorialSpaces does
not. The correction that record has to cost out is a line this tree already has.

The areas are consistent with that. `AreaSphericalTriangle` in
`src/Grids/geometry_circle.jl` is a half-angle form of the spherical excess,

    area = 2 * atan(abs(dot(P1,cross(P2,P3))) / (1 + dot(P1,P2) + dot(P2,P3) + dot(P3,P1)))

on normalised copies of its arguments, so a cell's area is its geodesic area and
not the area of its chordal triangle. Two cautions. The triple product is taken
in absolute value, so an inverted or degenerate cell has a positive area and
cannot be detected from it; and `AreaFace` fans a polygon from its first node
with that absolute value inside the sum, so a non-convex polygon would be
over-counted. Neither bites on triangles, and both would bite on the hexagonal
and kite grids in the same directory.

## The hierarchy is built and then thrown away

`RefineFace!` refines a face in place. It creates three new faces and splices
each in immediately after the parent with `insertafter!`, then overwrites the
parent's own three edges with the three interior edges, so the parent record
becomes the central child. `RefineFaceTriangularGrid!` walks the list and
advances four nodes per step, which lands it on the next unrefined parent.

The consequence, which the tree never states, is that after every refinement
pass the four children of the face at position `p` occupy positions `4p-3`
through `4p` of the face list. That is decision 0005's `children(i) = 4i-3:4i`
exactly, arrived at as a side effect of list surgery. `NumberingTriangularGrid!`
then walks the list once and assigns `1:NumFaces` in order, so the numbers carry
the relation.

And then it is discarded. `NumberingTriangularGrid!` is called once, after the
whole refinement loop in `TriangularGrid(backend,FT,RefineLevel,RadEarth,nz)`
has finished. No intermediate level is numbered, no parent index is stored, no
coarse grid is retained, and a grep of `src/Grids/` for a parent, a coarsening
or a multigrid transfer returns nothing but an unrelated `coarsen` on a
topography raster in `EarthTopo.jl`. A `GridStruct` holds one level. There is no
hierarchy object, no reduction from a fine level to a coarse one, and therefore
none of the segmented-reduction machinery that is the reason decision 0005
wanted the arithmetic relation in the first place.

Refinement is also global only: `RefineLevel` is a scalar passed to a loop over
the whole sphere. There is no local refinement, no 2:1 balance, no hanging-edge
bookkeeping and no graded transition ring, so the half of decision 0005 that
deals with refinement regions has no precedent here.

## Assumptions it carries

**Earth defaults (A2, A3).** Two complete copies of an Earth parameter block,
and they disagree. `src/Parameters/Parameters.jl` declares them as `const
global`: `RadEarth = 6.37122e+6 / ScaleFactor`, `Grav = 9.80616`, `Omega = 2 *
pi / 24.0 / 3600.0 * ScaleFactor`, and a thermodynamic set for moist air.
`src/DyCore/GlobalVariables.jl:220` declares the same names again as defaults
inside `PhysParameters{FT}(;ScaleFactor=FT(1))`. A third copy sits in
`src/Examples/parameters.jl` at lines 94 and 398. Nothing names which is
authoritative (C5).

**The small-planet scaling is dropped on the radius it is named for (B4, C1,
C4).** The command-line flag's own help text at
`src/Parameters/parse_commandline.jl:401` reads "ScaleFactor for EarthRadius".
`PhysParameters` takes `ScaleFactor` as a keyword and applies it to `Omega` at
line 239 and to nothing else; `RadEarth::FT = 6.37122e+6` at line 221 is
untouched. The drivers then scale a separate local copy by hand:
`Examples/DriverCG.jl:189` builds `Phys = DyCore.PhysParameters{FTB}(;ScaleFactor)`,
and 129 lines later,

    if RadEarth == 0.0
      RadEarth = Phys.RadEarth
      if ScaleFactor != 0.0
        RadEarth = RadEarth / ScaleFactor
      end
    end

passes that local to the grid constructor. So on any reduced-radius run the
radius the mesh is built with and the radius `Phys.RadEarth` reports are
different numbers, and `src/Sources/gravitation.jl:91` reads the unscaled one
through a keyword default `RadEarth=P.RadEarth`. The same block shows two
fail-open branches: `RadEarth == 0.0` is a sentinel for "not supplied", and
`ScaleFactor != 0.0` silently skips the scaling rather than refusing a zero.

This is the exact failure decision 0007 is built to make impossible. A radius
that is `Derived` from a declared figure is computed from its inputs and checked
against any supplied value, and a disagreement is a refusal rather than two live
numbers. Worth citing in the M0 plan for `System` as a worked example of the
thing the disposition types prevent.

**The radius is baked into the mesh (D2).** `TriangularGridToGrid` stores
`Node(Rad*NodeL.data.P, ...)`, and `GridStruct` carries a `Rad::FT` field.
Decision 0005 says the opposite in as many words: the mesh holds unit-sphere
geometry, physical geometry is unit geometry times a radius read from the system
struct at call time, and there is no radius in the mesh object. Their choice
also forecloses the identity oracle this project wants, because a mesh that has
already been multiplied by a radius cannot be checked against `4 pi R^2` for a
different `R` without rebuilding it. Note that the parameter is named `RadEarth`
in the signature of the general grid constructor, which is a planet welded into
an interface rather than into a value.

**Calendar and time (A1).** Clean negative for the grid machinery: nothing in
`src/Grids/` imports `Dates` or states a day or a year. The only day in the tree
is `day_to_sec = 86400.0` in `src/Sources/forcing.jl`, a Held-Suarez relaxation
timescale, outside the surface read here. Separately, `Omega` is computed as
`2 * pi / 24.0 / 3600.0`, which is `7.2722e-5` and not the sidereal rate
`7.2921e-5`; the solar day is used where the rotation rate belongs, a 0.27
percent difference with no comment either way.

**Grid and topology bounds (A6).** The triangular constructor takes its
refinement level as an argument and allocates from it, so there is no
compile-time bound. `Coloring` in `src/Grids/Connectivity.jl` is the exception
and a bad one: it iterates `for k = 1:10` over a greedy colouring with no
convergence test and returns whatever it has, so a mesh needing more than ten
colours yields a silently wrong partition (C4, B5).

**Index base.** One-based throughout, in memory and in the face, edge and node
records alike. No on-disk representation is fixed in the grid module.

**Precision.** `GridStruct` is parameterised on `FT`, but `Face` in
`src/Grids/Face.jl` hardcodes `Area::Float64` and `Radius::Float64`, so a
Float32 run still carries double-precision cell areas inside a struct the rest
of the code treats as `FT`-typed. The mix is not obviously wrong, since an area
is a quantity worth keeping wide, but it is unstated.

**Data layout, threading and GPU (D2).** This is the sharpest break with
decision 0011. The mesh is built as three doubly linked lists of mutable structs
(`NodeTri_T`, `EdgeTri_T`, `FaceTri_T`), converted to `Array{Face,1}`,
`Array{Edge,1}` and `Array{Node,1}` of mutable structs, each of which holds
variable-length `Array{Int,1}` fields for its nodes, edges, orientations and
stencil. That is array-of-structs with a heap allocation per cell per field:
not isbits, not `Adapt`-able, and not transferable to a device. Only two
flattened integer tables, `EF` and `FE`, are allocated through
`KernelAbstractions` and reach the GPU. So the GPU story is real for the solver
and absent for the mesh, which is the reverse of what this project needs, where
the connectivity tables are dense `Int32` arrays by design.

**Mutable global state (C5).** `src/Parameters/Parameters.jl` is a module of
`const global` bindings. They are constants rather than mutable state, but they
are a second authority for every number in `PhysParameters`, reachable without
passing a struct, which is the door decision 0007 closes.

**Connectivity is recomputed, not recorded.** `ConnectivityGraph(Grid)` in
`src/Grids/Connectivity.jl` builds a face-to-face adjacency by pushing into
three untyped `[]` vectors and returning `sparse(I,J,V)`. It is derived rather
than enumerated, which is the right side of the line decision 0005 draws, and it
is thrown away after each call rather than being an artifact with an identity.
Two details matter for anyone reading it as precedent. It pushes an entry for
every shared edge and again for every shared node, and Julia's `sparse` sums
duplicate index pairs, so the stored weight is a multiplicity, not the `1` the
code appears to write. And `EdgesInNodes!` in `src/Grids/EdgesInNodes.jl`
contains a bare `exit` on its own line where `break` was meant; it is a no-op
reference to a function, harmless because only one index matches, and a clean
illustration of the method note that a name is evidence about intent and never
about behaviour.

Decision 0005's connectivity graph is a different object from this one, a
physical record of sill depths, land contiguity and basin terminals. The name
collides; the concepts do not. Nothing here bears on that.

**Declared against demonstrated (C3).** Decisive. There is no test suite. The
repository has no `test/` directory, no `runtests.jl`, and no test file
anywhere; the path `test` is an ASCII file holding pasted console output of
`sum(abs.(...))` values from a CPU and GPU comparison. So the nesting property,
the sibling ordering, the spherical areas and the Metal and CUDA backends are
all read capability with nothing upstream that would catch a regression in any
of them. Every claim in this record is read from source, and none of it is
demonstrated by the tree.

**Conservation identity (D4).** Not run. Nothing in the tree computes a total
area, a nesting residual or any other closed identity, so there was nothing to
run and no positive control to run it against.

## What carries, and what it changes here

1. **The renormalised midpoint is the reference implementation of decision
   0005's bisection**, in five lines, and it settles by example that the
   correction `fiddlybits-bon.1` must cost out for CombinatorialSpaces is
   trivial in isolation.
2. **The in-place refinement that makes siblings contiguous is a pattern worth
   taking**, not as code but as the observation that reusing the parent slot for
   the central child is what produces `children(i) = 4i-3:4i` without a sort.
   This project fixes that relation by construction and tests it; the value here
   is the confirmation that an independent implementation lands on it naturally.
3. **The radius-in-the-mesh choice is a negative result to cite.** Their
   `GridStruct.Rad` and the `RadEarth` argument name are exactly what decision
   0005 forbids, and the `ScaleFactor` split above is what it costs: a second
   live radius, reachable through a keyword default, on every reduced-radius
   run.
4. **Nothing about the storage layout carries.** Linked lists of mutable structs
   with variable-length integer vectors per cell is the anti-pattern decision
   0011 was written against.

## If an adopt were ever proposed

It is not, and no decision is asked for by this record. Were one proposed, the
leak tests it would need are already named by the M0 mesh plan and would apply
unchanged: the area-closure oracle (`mesh.area_closure`, cell areas summing to
`4 pi R^2` at every level) would catch a chordal or a mis-scaled geometry, and
the nesting identity (`mesh.nesting_identity`, `children(parent(i))` containing
`i` and child areas summing to the parent's) would catch a lost hierarchy. A third would be needed and does not exist yet: a check that no
mesh object carries a radius, which is a lint over the mesh module rather than
an oracle.

## Checklist

| item | result |
| --- | --- |
| A1 day and year | clean negative in `src/Grids/`; `86400.0` in `src/Sources/forcing.jl` outside the surface read; `Omega` formed from the solar day, not the sidereal day |
| A2 planetary constant block | three copies: `src/Parameters/Parameters.jl`, `PhysParameters` in `src/DyCore/GlobalVariables.jl:220`, `src/Examples/parameters.jl`; none named authoritative |
| A3 Earth literals | `6.37122e+6` four times, `9.80616` twice, `9.81` five times in example parameters, `6371e3` in `src/IMEXRosenbrock/HeVi.jl:57`; all accounted for above |
| A6 grid and topology bounds | refinement level is an argument, no compile-time bound; `for k = 1:10` in `Coloring` is an undeclared iteration bound with no convergence test |
| B4 comment against value | `--ScaleFactor` help text says "ScaleFactor for EarthRadius" and the constructor does not scale the radius; `Omega` named a rotation rate and valued as a solar-day rate |
| B5 clamps and limiters | the ten-iteration colouring bound; `abs` inside the spherical-excess area, which hides an inverted cell; `ScaleFactor != 0.0` skipping rather than refusing |
| C1 use site of every constant | `RadEarth` read at `Examples/DriverCG.jl:318` and at `src/Sources/gravitation.jl:91` with different values on a scaled run |
| C3 declared against demonstrated | no test suite anywhere in the tree; the path `test` is pasted console output. Nothing is demonstrated |
| C4 fail-open branches | `RadEarth == 0.0` as an unset sentinel; `ScaleFactor != 0.0` skipping the scaling; `Coloring` returning an unconverged partition |
| C5 duplicate constant sets | the `const global` block against `PhysParameters` against the example parameters, with the radius disagreeing under scaling |
| D2 boundary field by field | mesh is host-side array-of-structs with variable-length integer vectors; only the flattened `EF` and `FE` tables cross to the device; the radius is pre-multiplied into node coordinates |
| D4 conservation identity | not run; the tree computes no closed identity and offers no positive control |

## References

- The organisation sweep that flagged this repository:
  `docs/imports/clima-organisation-sweep.md`.
- The plan this record answers to: `docs/plans/clima-survey.md`, the mesh and
  connectivity group.
- Decision 0005 (the mesh, exact nesting, arithmetic hierarchy, no radius in the
  mesh object), decision 0006 (Field), decision 0007 (dispositions and the
  `Derived` refusal), decision 0011 (cells-first layout and precision),
  decision 0012 (the adopt, borrow and reject lists this verdict feeds).
- The sibling finding on the same subdivision without renormalisation:
  `fiddlybits-bon.1`, against `docs/surveys/mesh-and-discretisation.md`.
