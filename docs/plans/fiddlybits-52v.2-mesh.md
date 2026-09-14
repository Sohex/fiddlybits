+++
epic = "fiddlybits-52v.2"
title = "The one icosahedral hierarchy: exact nesting, both dual measures, graded local refinement, and the support identity"
decisions = ["0005", "0010", "0011", "0029", "0031"]
requirements = ["REQ-TER-002", "REQ-TER-010", "REQ-TER-011", "REQ-TER-012", "REQ-SYS-103"]
oracles = ["mesh.area_closure", "mesh.nesting_identity", "mesh.refinement_balance", "mesh.support_identity", "mesh.connectivity_topology_event"]
status = "filed"
date = 2026-09-10
+++

## Scope

This plan builds the one spherical discretisation every component lives on: the base
icosahedron and its bisection, the hierarchical numbering that makes a coarsening a
contiguous segmented reduction, both dual measures, the dense stencil tables, graded
local refinement with 2:1 balance, the support identity two arrays are compared by,
and the connectivity graph that carries the small features a coarse level would drop.

There is no second grid anywhere in the model, and this plan is where that holds or
fails. A remap between grids is not a thing this module can express, because there is
nothing to remap between: a coarse field is a relation between a parent and its
children.

Two things are left out on purpose:

- **The mesh does not read `System`.** It is built on the unit sphere and the radius
  enters every measure through exactly one function, applied at the point of use. A
  radius multiplied into stored coordinates forecloses the area identity at any other
  radius, which is what CGDycore.jl's stored radius cost
  (`docs/imports/cgdycore-jl.md`) and what decision 0005 forbids in as many words.
  The volumetric mean radius comes from `Systems`, and that one number is the whole
  coupling between the two plans.
- **`Connectivity` is its own submodule above `Fields`**, because its graph is
  derived from a terrain-level field. A `Mesh` that built it would depend on
  `Fields`, which depends on `Mesh`. The skeleton plan made this boundary and
  `build.module_order_acyclic` is what holds it.

## Module boundaries

| path | holds | row |
| --- | --- | --- |
| `src/Mesh/hierarchy.jl` | the base icosahedron, bisection, `CellId`, the numbering | 52v.2.2 |
| `src/Mesh/geometry.jl` | both dual measures, frames, edge normals and lengths | 52v.2.3 |
| `src/Mesh/stencils.jl` | the dense neighbour tables, `edge_vertices` | 52v.2.4, 52v.2.20 |
| `src/Mesh/location.jl` | `Location`, `Cells`, `Vertices`, `Edges`, `element_count`, `axis_name`, the shared axis names | 52v.2.20 |
| `src/Mesh/refinement.jl` | variable-level meshes, 2:1 balance, hanging edges, graded rings | 52v.2.5 |
| `src/Mesh/identity.jl` | `Support{L}`, the digest, the mismatch refusal | 52v.2.6 |
| `src/Connectivity/` | the graph, sill depth and width, contiguity, terminals, topology events | 52v.2.7 |
| `test/mesh/` | one file per row above, plus `stencil_valence.jl` which `docs/imports/kernelabstractions.md` names | 52v.2.2 to 52v.2.6 |
| `test/connectivity/` | the graph suite and its synthetic terrains | 52v.2.7 |

`Mesh` references `Backends`, `Reductions` and `Verdicts`. It references neither
`Systems` nor `Fields`, and that absence is the point of the first bullet above.

## Types and functions

### The hierarchy

The base icosahedron is constructed from the golden ratio in the working type. The
shipped icosphere artifact of `CombinatorialSpaces.jl` is not a source of vertex
positions: it is a Blender export at six decimal places, which puts its radius error
some nine orders above the rounding the identities here are measured at
(`notes/findings/2026-09-10-chordal-bisection-and-spherical-area.md`).

**Bisection renormalises at every level.** For two unit vectors the chord midpoint
lies in the plane through them and the origin and bisects their angle, so normalising
it gives the great-circle midpoint itself rather than an approximation to it. Without
the normalisation every new vertex stays inside the plane of the parent triangle, the
surface never leaves the base polyhedron, and refinement buys resolution with no
convergence: the same finding measured a total-area residual frozen at the base
level's value through five refinements. The renormalisation is one operation and it
is exact.

```
ncells(L) = 20 * 4^L      nedges(L) = 30 * 4^L      nvertices(L) = 10 * 4^L + 2
children(i) = 4i-3 : 4i
parent(i)   = (i + 3) >> 2
```

The numbering is 1-based in memory and 0-based on disk, and `CellId` is the type that
crosses that boundary refusing arithmetic, so a mixed-base defect is a type error
rather than a wrong answer (REQ-TER-010). `children` returning a contiguous range is
what makes a coarsening a segmented reduction over a power-of-four segment, which is
the reduction `Reductions` is built for.

### Both measures

Every level and every refinement region carries, by name and never as an unqualified
"area": primal cell area, dual cell area, primal edge length, dual edge length, the
dual vertex definition (circumcentre), and the primal-to-dual edge angle as a tested
property (REQ-TER-011). No function accepts an area without saying which.

**Cell area is the Van Oosterom and Strackee vector form, with l'Huilier as the
second arm of the identity.** The two agree with a 400-bit reference at that
precision and disagree at working precision by a known factor: about one eighth of an
epsilon of absolute error per cell for the vector form against about one epsilon for
l'Huilier, at every level measured. An order of magnitude for no change of cost, and
two arms that agree at high precision are what let the identity distinguish a formula
defect from rounding.

Two consequences the same finding fixes, and both are now in the registry rather than
in this plan's prose: a per-cell identity is bounded in **absolute** area and never in
relative area, because a relative bar would have to loosen by four per level to stay
true; and a sum over cells is bounded by the cell count times that absolute floor.

**Mesh geometry is built and stored in double precision whatever the component's
working type.** At level 7 the vector form in FP32 is already wrong in the fourth
digit. This is a constraint on the support record rather than on any kernel, and it
is why `Support` carries the type its geometry was formed in.

The radius reaches both measures through exactly one function (REQ-TER-011,
REQ-SYS-103). No lint decides that today, and the plan does not claim one: the check
is the suite building one mesh at two radii and asserting each measure closes against
its own `4 pi R^2`, which fails if any measure carried a radius of its own. The
one-geometry-constructor rule of REQ-TER-010 is held the same way, by there being one
constructor in the module and the suite asserting it is the only definition.

### Stencils

Three edge neighbours for every cell, twelve vertex neighbours except at the sixty
cells touching the twelve base vertices, which have eleven and are padded with self
at zero weight. The tables are dense `Int32` arrays with no special cells, which is
what lets a kernel index them without a branch, and the padding is why there is no
branch: a special case handled by weight is not a special case in the kernel.

`stencil_valence.jl` is the leak test `docs/imports/kernelabstractions.md` names. It
asserts that the stencil tables are the only geometry a kernel sees, which is the
claim that keeps the kernel layer free of the mesh.

### Locations

A value of a level sits at its cells, its vertices or its edges, and `Mesh.Location` is
the closed vocabulary that says which: `Cells`, `Vertices` and `Edges`, enumerated by
`locations()` and closed by a test against the subtypes, the way the semantics are.
`element_count(location, level)` is `ncells`, `nvertices` or `nedges`, and
`axis_name(location)` names the axis a stored or exported array holds those elements
along, `Backends.LAYOUT`'s first name at cells. The trailing axis names the store and
the export share are declared beside it: `COMPONENT_AXIS`, the three components of a
position or a direction in the mesh's Cartesian coordinates; `CORNER_AXIS`, a cell's
three corners in the winding order of `Level.cells`, local edge `k` opposite corner `k`;
and `PAIR_AXIS`, the two cells or the two vertices of an edge. The vocabulary lives here
because the counts do: `Fields` puts a location on the type of a field, `Coupling` on a
write, and `Provenance` and `Render` write its name.

**Only cells nest by range.** `children(i)` is contiguous, so a cell's descendants are a
range. `bisect` keeps every vertex of a level at its index and appends each new one in
order of first appearance while scanning the parent cells, so a level's vertices are a
prefix of every finer level's and no cell owns a range of them. `build_edges` numbers
edges by first appearance, scanning cells in index order and local edges within a cell,
so the creating cell `edge_cell[1, e]` never decreases with `e` and the edges a range of
cells created are contiguous; a cell creates from none to three of them, so their count
varies from one cell to the next. That is why `coarsen` and `refine` refuse vertices and
edges (the fields plan, section Location) and why the store chunks a vertex or edge
array by index range (the provenance plan, section The store).

`edge_vertices(level, st)` gives each edge its two vertices, from the local edge of the
cell that created it: the table a store entry and a mesh-topology export need and
`Stencils` does not carry. `CellId` is the type every 0-based element index crosses the
disk boundary in, whatever its location.

### Refinement

A variable-level mesh is 2:1 balanced by construction rather than by repair. Hanging
edges carry their own flux-conserving measure: a flux through a coarse edge equals the
sum over its children exactly, which is what makes the ledgers of decision 0009 able
to demand identity rather than tolerance.

**Fluid refinement is graded; damped refinement may be abrupt.** Atmosphere and ocean
step down one level at a time through transition rings of a declared minimum width in
cells, with divergence damping inside the transition, because an abrupt 2:1 step
reflects gravity and acoustic waves and seeds grid-scale storms at the boundary.
Terrain, hydrology and the land column use abrupt boundaries. The ring width is an
argument of the refinement API, never a constant here and never read from the
profile here: `Mesh` does not reference `Systems`, so the caller passes the width it
read from the profile, the same shape as the memory budget taking its ceiling.

The refinement region API takes a region and a depth in levels. Invoking refinement
from an instrument, per decision 0031's third layer, is not this plan: the sensitivity
probe belongs to the feature records that declare the metrics, and this plan provides
only the mechanism a probe would call.

### The support identity

`Support{L}` is a value type carrying a digest over: kind, hierarchy level, the
refinement region set, the geometry constructor version, the coordinate digest, both
native measures with the radius they were formed from, the type they were formed in,
and any effective fraction a field uses (REQ-TER-002). Two supports with the same
shape and different geometry have different identities, which is the whole point: a
consumer holding two arrays compares two identities, never two axes or two shapes.

A binary operation between fields on mismatched supports raises the `Refusal` of
`Verdicts`, naming both identities. That refusal is what `Fields` relies on, and it
is declared here because the identity is declared here.

### Connectivity

Derived from a terrain-level field every slow step. Its nodes are the ocean and land
bodies of each coarse cell, joined through edge neighbours inside it (decision 0031);
for each pair of bodies joined across a coarse edge there is one gate, for ocean the
minimum sill depth and the width of their connection and for land contiguity; for
basins, the drainage terminal.

A surface class is decided by connectivity to the world ocean, never by the sign of
elevation (REQ-TER-012). Land, ocean and inland-water fractions are exact areas from
the terrain level, and a cell with a fraction strictly between zero and one holds an
island or lake tile: an island is never rounded to ocean and a strait is never
rounded to land.

A change in the graph's topology is an **event**, not a diagnostic. A seaway closing,
a land bridge flooding, a basin capturing its neighbour forces a climate refresh, so
a closure happens when it happens rather than being averaged away by the slow tier.
The event vocabulary is the closed one of decision 0042 and the front door is
`Events.emit`, declared in group A with a no-op sink that `Provenance` installs
(`fiddlybits-52v.6.8`). `Connectivity` sits below `Provenance`, so it could not reach
the writer directly; it does not declare a hook of its own either, because the plan
review found three plans doing that and consolidated them.

The physics of strait exchange, the discharge coefficients and the overflow closure
are decision 0031's second layer and belong to the ocean milestone. This plan builds
the graph those read, and its geometry: sill depth, width, contiguity, terminal.

## Oracles

Five registry entries. Three exist: `mesh.area_closure`, `mesh.nesting_identity` and
`mesh.refinement_balance`, the first two already carrying thresholds derived from the
bisection finding rather than the word roundoff. Two are added.

| id | right answer | the mutation that must make it fail |
| --- | --- | --- |
| `mesh.area_closure` | the area sum against `4 pi R^2` at every level, by both the vector form and l'Huilier | an unrenormalised bisection, whose total area is frozen at the base level and misses by about two parts in a hundred |
| `mesh.nesting_identity` | `children(parent(i))` contains `i`; child areas sum to the parent's; the radial defect after bisection | the same unrenormalised bisection, whose radial defect converges to the base sagitta rather than to zero |
| `mesh.refinement_balance` | 2:1 balance holds; hanging-edge fluxes sum to the coarse flux | a hanging edge given the coarse measure rather than its own |
| `mesh.support_identity` | two meshes from one recipe share a digest; a perturbed vertex changes it; a mismatched binary operation refuses | a digest taken over shape alone, which two different geometries must then collide on |
| `mesh.connectivity_topology_event` | on a synthetic terrain with one strait, the graph reports its sill depth and width exactly; closing the strait emits a topology event | a class decided by the sign of elevation, which must misclassify an enclosed basin below sea level |

`mesh.constant_field_reduction` and `mesh.vector_round_trip` are in the registry under
this subsystem but are field operations, not mesh ones: they are the fields plan's to
run, and `fiddlybits-52v.3` names them.

The Laplacian orthogonality test of REQ-TER-011, against the analytic spherical
eigenvalues on the production mesh at the production level, is the dynamical core's
and is named in `fiddlybits-52v.9`; it is recorded here because it is the check that
makes the dual measures mean something, and because REQ-TER-011 requires it on the
production mesh rather than only on a synthetic near-regular one.

## Rows filed

| row | tier | boundary | acceptance |
| --- | --- | --- | --- |
| 52v.2.2 | sonnet | `src/Mesh/hierarchy.jl`, `test/mesh/hierarchy.jl` | `parent(children(i)) == i` at every level of the declared range; the cell, edge and vertex counts; `CellId` refuses arithmetic; the renormalised midpoint sits at rounding |
| 52v.2.3 | sonnet | `src/Mesh/geometry.jl`, `test/mesh/area_closure.jl`, `test/mesh/nesting_identity.jl` | `mesh.area_closure` and `mesh.nesting_identity` pass at their derived absolute thresholds, both arms agreeing; the unrenormalised control fails both |
| 52v.2.4 | sonnet | `src/Mesh/stencils.jl`, `test/mesh/stencil_valence.jl` | every cell has three edge neighbours; twelve vertex neighbours except the sixty base-vertex cells at eleven, padded with self at zero weight; the tables are symmetric and dense |
| 52v.2.5 | frontier | `src/Mesh/refinement.jl`, `test/mesh/refinement_balance.jl` | `mesh.refinement_balance` passes with its control firing; a graded region steps one level per ring and the ring width is an argument, with `Mesh` reaching no profile |
| 52v.2.6 | sonnet | `src/Mesh/identity.jl`, `test/mesh/identity.jl` | `mesh.support_identity` passes with its control firing; the mismatch refusal names both identities |
| 52v.2.7 | frontier | `src/Connectivity/`, `test/connectivity/` | `mesh.connectivity_topology_event` passes with its control firing; the topology event goes through `Events.emit` and is counted by a fixture sink |
| 52v.2.8 | sonnet | none; reports only | all five oracles ran; verdicts by name |
| 52v.2.20 | sonnet | `src/Mesh/location.jl` and its include, `edge_vertices` in `src/Mesh/stencils.jl`, the `CellId` docstring in `src/Mesh/hierarchy.jl`, `test/mesh/location.jl` and its include | `locations()` holds exactly the subtypes of `Location` and a fixture fourth subtype is reported missing; `element_count` equals the level's cell, vertex and edge counts at levels 0 through 3; for every edge `arc_length` of its `edge_vertices` equals `primal_edge_length` and their great-circle midpoint equals `edge_midpoint`, bitwise, both vertices corners of both its cells, and the next local edge's vertices fail each comparison |

52v.2.4 depends on 52v.2.2; 52v.2.3 depends on 52v.2.4, because an edge length
needs the global edge enumeration the stencil tables carry; 52v.2.6 depends on
52v.2.3, because the support digest covers both native measures; 52v.2.5 depends
on 52v.2.3 and 52v.2.4; 52v.2.7 depends on 52v.2.6, on the fields plan's `Field`,
and on `fiddlybits-52v.6.8` for `Events.emit`. 52v.2.20 depends on nothing unmerged and
blocks `fiddlybits-52v.3.26`, `fiddlybits-52v.11.7`, `fiddlybits-52v.6.35` and
`fiddlybits-52v.6.36`, every row that reads a location.
