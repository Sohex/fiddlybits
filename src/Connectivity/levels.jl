# The two levels a graph reads: the terrain level it is derived on and the coarse level
# it reports at.

using ..Mesh

"""
    LevelMesh{T}

One uniform level of the hierarchy with the stencils and both measures built from it:
`index` is the level, `level` its vertices and cells, `stencils` its neighbour tables
and `geometry` its measures on the unit sphere.
"""
struct LevelMesh{T}
    index::Int
    level::Mesh.Level{T}
    stencils::Mesh.Stencils
    geometry::Mesh.Geometry{Float64}
end

"""
    LevelMesh(hierarchy, index)

Level `index` of `hierarchy`, with its stencils and geometry built from it. Refuses an
`index` the hierarchy does not hold.
"""
function LevelMesh(hierarchy::Mesh.Hierarchy, index::Integer)
    0 <= index < length(hierarchy.levels) ||
        refuse("level", "Connectivity.LevelMesh",
               "level $index is not one of the $(length(hierarchy.levels)) levels the hierarchy holds")
    level = hierarchy.levels[index + 1]
    stencils = Mesh.stencils(level)
    return LevelMesh(Int(index), level, stencils, Mesh.geometry(level, stencils))
end

"""
    require_on_support(mesh, support, site)

Returns `nothing` when `support` is the uniform level `mesh` holds, and refuses at
`site` otherwise, naming what differs: the level, the refinement, the vertex
coordinates, or both native measures at the support's radius.
"""
function require_on_support(mesh::LevelMesh, support::Mesh.Support, site::AbstractString)
    support.level == mesh.index ||
        refuse("support level", site,
               "the support is level $(support.level) and the mesh is level $(mesh.index)")
    support.refinement_digest == Mesh.digest_refinement(()) ||
        refuse("support refinement", site,
               "the support at level $(support.level) carries refinement regions, and the graph reads a uniform level")
    support.coordinate_digest == Mesh.digest_coordinates(mesh.level.vertices) ||
        refuse("support coordinates", site,
               "the support at level $(support.level) was not built from the vertices of the mesh passed with it")
    support.measure_digest == Mesh.digest_measures(mesh.geometry, support.radius) ||
        refuse("support measures", site,
               "the support at level $(support.level) was not built from the measures of the mesh passed with it")
    return nothing
end

"""
    coarse_cell(fine, depth)

The cell `depth` levels coarser that the cell `fine` lies in.
"""
coarse_cell(fine::Integer, depth::Integer) = Mesh.ancestor(Int(fine), depth)

"""
    coarse_edge_between(stencils, a, b, site)

The global edge of the level `stencils` describes that cells `a` and `b` share. Refuses
at `site` when they share none.
"""
function coarse_edge_between(stencils::Mesh.Stencils, a::Integer, b::Integer, site::AbstractString)
    for k in 1:3
        stencils.edge_neighbour[k, a] == b && return stencils.cell_edge[k, a]
    end
    return refuse("coarse edge", site, "cells $a and $b share no edge")
end
