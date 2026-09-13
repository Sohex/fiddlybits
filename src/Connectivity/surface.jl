# The surface class of every terrain cell, decided by connectivity to the world ocean
# (REQ-TER-012), and land contiguity.

"""
    SURFACE_LEGEND

The legend name the surface class field carries, `CategoricalLabel{SURFACE_LEGEND}`.
"""
const SURFACE_LEGEND = :surface

"""
    SURFACE_CLASSES

The classes a terrain cell's surface takes, in the column order of the coarse
fractions: `:land`, `:ocean`, `:inland_water`.
"""
const SURFACE_CLASSES = (:land, :ocean, :inland_water)

"""
    world_ocean(elevation, datum, stencils, seeds, site)

Whether each cell belongs to the world ocean: a cell lying strictly below `datum` that
is joined to a cell of `seeds` through edge neighbours each lying strictly below
`datum`. Found by breadth-first search from `seeds` over `stencils.edge_neighbour`.

Refuses at `site` an empty `seeds`, a seed that is not a cell of the level, and a seed
lying at or above `datum`.
"""
function world_ocean(elevation::Vector{Float64}, datum::Float64, stencils::Mesh.Stencils,
                     seeds, site::AbstractString)
    n = length(elevation)
    ocean = falses(n)
    queue = Vector{Int}(undef, n)
    tail = 0
    for s in sort!(unique!(Int[s for s in seeds]))
        1 <= s <= n || refuse("ocean seed", site, "seed $s is not a cell of a level of $n cells")
        elevation[s] < datum ||
            refuse("ocean seed", site,
                   "seed $s lies at $(elevation[s]), not below the datum $datum, so it is not ocean")
        ocean[s] && continue
        ocean[s] = true
        tail += 1
        queue[tail] = s
    end
    tail == 0 && refuse("ocean seed", site, "no seed was given, so the world ocean is not recoverable")
    head = 1
    while head <= tail
        i = queue[head]
        head += 1
        for k in 1:3
            j = Int(stencils.edge_neighbour[k, i])
            (ocean[j] || !(elevation[j] < datum)) && continue
            ocean[j] = true
            tail += 1
            queue[tail] = j
        end
    end
    return ocean
end

"""
    surface_labels(ocean, water_depth)

The class of each cell from `SURFACE_CLASSES`: `:ocean` where `ocean` holds,
`:inland_water` where it does not and `water_depth` is positive, `:land` elsewhere.
"""
function surface_labels(ocean::BitVector, water_depth::Vector{Float64})
    labels = Vector{Symbol}(undef, length(ocean))
    for i in eachindex(labels)
        labels[i] = ocean[i] ? :ocean : (water_depth[i] > 0 ? :inland_water : :land)
    end
    return labels
end

"""
    elevation_sign_surface(elevation, datum)

The positive control of `mesh.connectivity_topology_event`: each cell's class decided
by the sign of its elevation against `datum` alone, `:ocean` strictly below it and
`:land` at or above it, with no connectivity read. It calls an enclosed basin lying
below the datum ocean, which `derive` does not.
"""
elevation_sign_surface(elevation::AbstractVector, datum::Real) =
    Symbol[x < datum ? :ocean : :land for x in elevation]

"""
    land_components(ocean, stencils)

The land component of each cell: `nothing` on an ocean cell, and on every other cell
the lowest cell index of the set of non-ocean cells joined to it through edge
neighbours. Inland water is not ocean and joins the land around it.
"""
function land_components(ocean::BitVector, stencils::Mesh.Stencils)
    n = length(ocean)
    component = Vector{Union{Nothing,Int32}}(nothing, n)
    queue = Vector{Int}(undef, n)
    for start in 1:n
        (ocean[start] || component[start] !== nothing) && continue
        label = Int32(start)
        component[start] = label
        queue[1] = start
        head = 1
        tail = 1
        while head <= tail
            i = queue[head]
            head += 1
            for k in 1:3
                j = Int(stencils.edge_neighbour[k, i])
                (ocean[j] || component[j] !== nothing) && continue
                component[j] = label
                tail += 1
                queue[tail] = j
            end
        end
    end
    return component
end
