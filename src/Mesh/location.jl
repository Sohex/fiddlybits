# Where a value of a level sits: docs/plans/fiddlybits-52v.2-mesh.md, section
# "Locations".

using ..Backends: LAYOUT

"""
    Location

Where a value of a level sits: at its cells, its vertices or its edges. The
closed set `locations()` enumerates; `Fields` puts a `Location` on the type
of a field, `Coupling` on a write, and `Provenance` and `Render` write its
name.
"""
abstract type Location end

"A value at a level's cells."
struct Cells <: Location end

"A value at a level's vertices."
struct Vertices <: Location end

"A value at a level's edges."
struct Edges <: Location end

"Every `Location` singleton, in the order this section declares them."
locations() = (Cells(), Vertices(), Edges())

"""
    element_count(location, level)

The element count of `location` at hierarchy depth `level`: `ncells`,
`nvertices` or `nedges`.
"""
element_count(::Cells, level::Integer) = ncells(level)
element_count(::Vertices, level::Integer) = nvertices(level)
element_count(::Edges, level::Integer) = nedges(level)

"""
    axis_name(location)

The name of the axis a stored or exported array holds `location`'s elements
along: `Backends.LAYOUT`'s first name at cells, `:vertices` at vertices and
`:edges` at edges.
"""
axis_name(::Cells) = LAYOUT[1]
axis_name(::Vertices) = :vertices
axis_name(::Edges) = :edges

"""
    COMPONENT_AXIS

The trailing axis name of the three components of a position or a direction
in the mesh's Cartesian coordinates.
"""
const COMPONENT_AXIS = :component

"""
    CORNER_AXIS

The trailing axis name of a cell's three corners, in the winding order of
`Level.cells`, local edge `k` opposite corner `k`.
"""
const CORNER_AXIS = :corner

"""
    PAIR_AXIS

The trailing axis name of the two cells or the two vertices of an edge.
"""
const PAIR_AXIS = :pair
