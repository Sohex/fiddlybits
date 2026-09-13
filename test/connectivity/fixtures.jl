# The synthetic terrain the connectivity suite reads, built on one hierarchy.
#
# Coarse cells A and B share one coarse edge. A is ocean, B is ocean holding a one-cell
# island, and every other coarse cell is land. The terrain cells of A along the shared
# edge are land except three, which are a strait of declared floor joining A's ocean to
# B's. Coarse cell C holds an enclosed basin below the datum whose lowest cell carries
# a lake; coarse cell D holds two adjacent closed basins above the datum.

module ConnectivityFixtures

using Fiddlybits: Mesh, Fields, Dimensions, Time, Connectivity
using LinearAlgebra: dot
using UUIDs: UUID

const COARSE_INDEX = 1
const TERRAIN_INDEX = 4
const DEPTH = TERRAIN_INDEX - COARSE_INDEX
const RADIUS = 3.0e6
const DATUM = 25.0
const RUN = UUID("7c0a51e2-0000-4000-8000-000000000000")

const LAND = 500.0
const A_FLOOR = -3000.0
const B_FLOOR = -4000.0
const STRAIT_FLOOR = -125.0
const ISLAND_TOP = 300.0
const BASIN_FLOOR = -200.0
const BASIN_PIT_FLOOR = -250.0
const LAKE_DEPTH = 40.0
const P_FLOOR = 100.0
const P_PIT_FLOOR = 90.0
const Q_FLOOR = 50.0
const Q_PIT_FLOOR = 40.0
const SILT_TOP = 40.0

const HIERARCHY = Mesh.hierarchy(TERRAIN_INDEX)
const TERRAIN = Connectivity.LevelMesh(HIERARCHY, TERRAIN_INDEX)
const COARSE = Connectivity.LevelMesh(HIERARCHY, COARSE_INDEX)
const NCELLS = Mesh.ncells(TERRAIN_INDEX)
const NCOARSE = Mesh.ncells(COARSE_INDEX)

"The `Mesh.Support` of `mesh` at `radius`."
support(mesh::Connectivity.LevelMesh; radius = RADIUS) =
    Mesh.Support(mesh.index, mesh.level, mesh.geometry; kind = :icosahedral_bisection,
                 refinement = (), radius = radius, element_type = :Float64, fractions = ())

const TERRAIN_SUPPORT = support(TERRAIN)
const COARSE_SUPPORT = support(COARSE)

"A terrain-level `Fields.Field` over `data`, every declaration overridable."
field(data; semantics = Fields.Intensive(), dimension = Dimensions.LENGTH,
      support = TERRAIN_SUPPORT, run = RUN) =
    Fields.Field(semantics = semantics, dimension = dimension, data = data,
                 support = support, time = Time.TimeSupport(Time.Static()),
                 origin = Fields.unstamped(:fixture, run))

"The terrain cell at the centre of coarse cell `cell`: the central child at every level."
function centre(cell::Integer)
    for _ in 1:DEPTH
        cell = last(Mesh.children(cell))
    end
    return Int(cell)
end

"Coarse cell `cell` and every coarse cell sharing a vertex with it."
near(cell::Integer) = Set{Int}([cell; Int.(COARSE.stencils.vertex_neighbour[:, cell])])

const A = 1
const B = Int(COARSE.stencils.edge_neighbour[1, A])
const EDGE = Int(COARSE.stencils.cell_edge[1, A])
const NEAR_AB = union(near(A), near(B))
const C = first(c for c in 1:NCOARSE if !(c in NEAR_AB))
const D = first(c for c in 1:NCOARSE if !(c in NEAR_AB) && !(c in near(C)))

"""
    edge_pairs()

Every terrain edge on `EDGE` as `(cell in A, cell in B, terrain edge)`, ordered along
the coarse edge.
"""
function edge_pairs()
    st = TERRAIN.stencils
    u, v = Mesh.edge_local_vertices(COARSE.level.cells, A, 1)
    direction = COARSE.level.vertices[:, v] .- COARSE.level.vertices[:, u]
    pairs = Tuple{Int,Int,Int}[]
    for e in axes(st.edge_cell, 2)
        i, j = Int(st.edge_cell[1, e]), Int(st.edge_cell[2, e])
        owners = (Mesh.ancestor(i, DEPTH), Mesh.ancestor(j, DEPTH))
        owners == (A, B) && push!(pairs, (i, j, e))
        owners == (B, A) && push!(pairs, (j, i, e))
    end
    return sort!(pairs; by = p -> dot(TERRAIN.geometry.edge_midpoint[:, p[3]], direction))
end

const PAIRS = edge_pairs()
const STRAIT = PAIRS[4:6]

"The terrain edge neighbours of cell `i`."
neighbours(i) = Int.(TERRAIN.stencils.edge_neighbour[:, i])

"The cell of A sharing an edge with both A-side cells `u` and `v`."
between(u, v) = only(i for i in Mesh.descendants(A, DEPTH) if count(in((u, v)), neighbours(i)) == 2)

"""
The wall of land along the shared edge outside the strait: the A-side cell of every
other pair, and the A cell between each two consecutive such cells.
"""
const SHORE = Set{Int}(vcat([first(p) for p in PAIRS if !(p in STRAIT)],
                            [between(first(PAIRS[k]), first(PAIRS[k + 1])) for k in 1:(length(PAIRS) - 1)
                             if !(PAIRS[k] in STRAIT) && !(PAIRS[k + 1] in STRAIT)]))
const ISLAND = centre(B)
const A_CENTRE = centre(A)
const BASIN = collect(Mesh.descendants(last(Mesh.children(C)), DEPTH - 1))
const BASIN_PIT = first(BASIN)
const P = collect(Mesh.descendants(first(Mesh.children(D)), DEPTH - 1))
const Q = collect(Mesh.descendants(last(Mesh.children(D)), DEPTH - 1))

"The ocean cell of A beside the wall, inland of the cell between the second and third pairs."
const SILT = only(i for i in neighbours(between(first(PAIRS[2]), first(PAIRS[3]))) if !(i in SHORE))

"A cell of A's ocean that no scenario raises."
const OCEAN_SEED = first(i for i in Mesh.descendants(A, DEPTH)
                         if !(i in SHORE) && i != A_CENTRE && i != SILT &&
                            !any(p -> first(p) == i, STRAIT))

"""
    distances_from(cell, starts)

The breadth-first distance, through edge neighbours within coarse cell `cell`, of each
of its terrain cells from the cells `starts`. A cell at distance `d` lies in row
`d ÷ 2` counted from the shared edge.
"""
function distances_from(cell::Integer, starts)
    distance = Dict{Int,Int}(s => 0 for s in starts)
    queue = collect(Int, starts)
    head = 1
    while head <= length(queue)
        i = queue[head]
        head += 1
        for j in neighbours(i)
            (Mesh.ancestor(j, DEPTH) == cell && !haskey(distance, j)) || continue
            distance[j] = distance[i] + 1
            push!(queue, j)
        end
    end
    return distance
end

const A_DISTANCE = distances_from(A, first.(PAIRS))
const B_DISTANCE = distances_from(B, [p[2] for p in PAIRS])
const A_BODY = minimum(i for (i, d) in A_DISTANCE if d >= 4)
const B_BODY = minimum(i for (i, d) in B_DISTANCE if d >= 4)

"The global terrain edge cells `i` and `j` share."
edge_between(i, j) = Int(TERRAIN.stencils.cell_edge[findfirst(==(j), neighbours(i)), i])

"The row-0 cell of A between the fourth and fifth pairs, where the neck leaves the strip."
const NECK_MOUTH = between(first(PAIRS[4]), first(PAIRS[5]))
const GAP_UP = only(j for j in neighbours(NECK_MOUTH) if get(A_DISTANCE, j, -1) == 2)
const GAP_DOWN = minimum(j for j in neighbours(GAP_UP) if get(A_DISTANCE, j, -1) == 3)
const GAP_INNER = only(j for j in neighbours(GAP_DOWN) if get(A_DISTANCE, j, -1) == 4)

"The three terrain edges along the one-cell neck through A's wall, from the strip inward."
const NECK = [edge_between(NECK_MOUTH, GAP_UP), edge_between(GAP_UP, GAP_DOWN),
              edge_between(GAP_DOWN, GAP_INNER)]

const BAR_FLOOR = -35.0

"""
    gate_world(; gap_floor, strip_floor, walled_b, islet)

A second synthetic world, land everywhere but A and B. In A, row 0 along the shared
edge is a strip at `strip_floor`, row 1 a wall of land pierced by the two-cell neck
`GAP_UP`, `GAP_DOWN` at `gap_floor`, and every further row A's body at `A_FLOOR`. B is
its body at `B_FLOOR` throughout, or, when `walled_b`, a strip, a wall with no neck and
a body laid out as A's. `islet` raises the two cells of the seventh pair to land.
"""
function gate_world(; gap_floor, strip_floor = STRAIT_FLOOR, walled_b = false, islet = false)
    z = fill(LAND, NCELLS)
    for (i, d) in A_DISTANCE
        z[i] = d < 2 ? strip_floor : (d < 4 ? LAND : A_FLOOR)
    end
    z[GAP_UP] = gap_floor
    z[GAP_DOWN] = gap_floor
    for (i, d) in B_DISTANCE
        z[i] = !walled_b ? B_FLOOR : (d < 2 ? strip_floor : (d < 4 ? LAND : B_FLOOR))
    end
    if islet
        z[first(PAIRS[7])] = LAND
        z[PAIRS[7][2]] = LAND
    end
    return z
end

"The terrain elevation of the synthetic world, before any edit."
function elevation()
    z = fill(LAND, NCELLS)
    for i in 1:NCELLS
        owner = Mesh.ancestor(i, DEPTH)
        owner == A && (z[i] = A_FLOOR)
        owner == B && (z[i] = B_FLOOR)
    end
    for i in SHORE
        z[i] = LAND
    end
    for p in STRAIT
        z[first(p)] = STRAIT_FLOOR
    end
    z[ISLAND] = ISLAND_TOP
    z[BASIN] .= BASIN_FLOOR
    z[BASIN_PIT] = BASIN_PIT_FLOOR
    z[P] .= P_FLOOR
    z[first(P)] = P_PIT_FLOOR
    z[Q] .= Q_FLOOR
    z[first(Q)] = Q_PIT_FLOOR
    return z
end

"The elevation with the cells `cells` set to `height`."
function edited(cells, height)
    z = elevation()
    for i in cells
        z[i] = height
    end
    return z
end

"The inland water depth: `LAKE_DEPTH` on the basin's lowest cell and zero elsewhere."
function water_depth()
    d = zeros(NCELLS)
    d[BASIN_PIT] = LAKE_DEPTH
    return d
end

"The graph of the terrain `z`, every input overridable."
graph(z; depth = water_depth(), seeds = [OCEAN_SEED], datum = DATUM, support = TERRAIN_SUPPORT,
      terrain = TERRAIN, coarse = COARSE, coarse_support = COARSE_SUPPORT) =
    Connectivity.derive(field(z; support = support); datum = datum, ocean_seeds = seeds,
                        water_depth = field(depth; support = support), terrain = terrain,
                        coarse = coarse, coarse_support = coarse_support)

"""
    no_enclosed_ocean(labels)

Whether no cell of the enclosed basin is classed `:ocean` in `labels`: the predicate of
the positive control.
"""
no_enclosed_ocean(labels::AbstractVector{Symbol}) = all(i -> labels[i] !== :ocean, BASIN)

end # module ConnectivityFixtures
