# The connections between adjacent coarse cells, read off the terrain-level edges lying
# on the coarse edge they share.

using ..Reductions: compensated_sum

"""
    OceanGate

The ocean connection across one coarse edge. `edge` is the coarse edge and `cells` the
two coarse cells sharing it, in the coarse `edge_cell` order. A crossing is a
terrain-level edge lying on the coarse edge with a world-ocean cell on both sides, and
`crossings` counts them. `sill_depth` is the greatest, over the crossings, of the datum
less the higher of the crossing's two elevations. `width` is the sum of the crossings'
primal edge lengths at the support's radius, accumulated in ascending terrain edge
order.
"""
struct OceanGate
    edge::Int32
    cells::NTuple{2,Int32}
    sill_depth::Float64
    width::Float64
    crossings::Int
end

"""
    LandGate

The land connection across one coarse edge: as `OceanGate`, with a crossing a
terrain-level edge on the coarse edge with a non-ocean cell on both sides, and no sill.
"""
struct LandGate
    edge::Int32
    cells::NTuple{2,Int32}
    width::Float64
    crossings::Int
end

"""
    crossings(ocean, terrain, coarse, site)

`(wet, dry)`: every terrain edge lying on a coarse edge, as `(coarse edge, terrain
edge)`, split into those with an ocean cell on both sides and those with a non-ocean
cell on both sides, each sorted by coarse edge and then terrain edge. An edge with one
ocean side is in neither.
"""
function crossings(ocean::BitVector, terrain::LevelMesh, coarse::LevelMesh, site::AbstractString)
    depth = terrain.index - coarse.index
    st = terrain.stencils
    wet = Tuple{Int32,Int32}[]
    dry = Tuple{Int32,Int32}[]
    for e in axes(st.edge_cell, 2)
        i = Int(st.edge_cell[1, e])
        j = Int(st.edge_cell[2, e])
        a = coarse_cell(i, depth)
        b = coarse_cell(j, depth)
        a == b && continue
        if ocean[i] && ocean[j]
            push!(wet, (coarse_edge_between(coarse.stencils, a, b, site), Int32(e)))
        elseif !ocean[i] && !ocean[j]
            push!(dry, (coarse_edge_between(coarse.stencils, a, b, site), Int32(e)))
        end
    end
    return sort!(wet), sort!(dry)
end

"""
    edge_runs(pairs)

The index ranges of `pairs` holding one coarse edge each, in order.
"""
function edge_runs(pairs::Vector{Tuple{Int32,Int32}})
    runs = UnitRange{Int}[]
    start = 1
    for k in 2:(length(pairs) + 1)
        if k > length(pairs) || first(pairs[k]) != first(pairs[start])
            push!(runs, start:(k - 1))
            start = k
        end
    end
    return runs
end

"""
    edge_width(pairs, run, lengths, radius)

The sum of the primal edge lengths at `radius` of the terrain edges `pairs[run]` name.
"""
edge_width(pairs::Vector{Tuple{Int32,Int32}}, run::UnitRange{Int}, lengths::Vector{Float64},
           radius::Float64) =
    compensated_sum(Float64[Mesh.at_radius(lengths[last(pairs[k])], radius, 1) for k in run])

"""
    gates(elevation, datum, ocean, terrain, coarse, radius, site)

`(ocean_gates, land_gates)`: one `OceanGate` for every coarse edge carrying a wet
crossing and one `LandGate` for every coarse edge carrying a dry one, each sorted by
coarse edge.
"""
function gates(elevation::Vector{Float64}, datum::Float64, ocean::BitVector,
               terrain::LevelMesh, coarse::LevelMesh, radius::Float64, site::AbstractString)
    wet, dry = crossings(ocean, terrain, coarse, site)
    st = terrain.stencils
    lengths = terrain.geometry.primal_edge_length
    cells_of(edge) = (coarse.stencils.edge_cell[1, edge], coarse.stencils.edge_cell[2, edge])
    ocean_gates = OceanGate[]
    for run in edge_runs(wet)
        edge = first(wet[first(run)])
        sill = maximum(k -> datum - max(elevation[st.edge_cell[1, last(wet[k])]],
                                        elevation[st.edge_cell[2, last(wet[k])]]), run)
        push!(ocean_gates, OceanGate(edge, cells_of(edge), sill,
                                     edge_width(wet, run, lengths, radius), length(run)))
    end
    land_gates = LandGate[]
    for run in edge_runs(dry)
        edge = first(dry[first(run)])
        push!(land_gates, LandGate(edge, cells_of(edge), edge_width(dry, run, lengths, radius),
                                   length(run)))
    end
    return ocean_gates, land_gates
end
