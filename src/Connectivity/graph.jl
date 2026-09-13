# The graph and the one door that derives it from a terrain-level field.

using ..Fields
using ..Dimensions
using ..Backends

"""
    Graph

The connectivity graph of one terrain-level elevation field.

`terrain` and `coarse` are the levels it was derived on and reports at. `datum` is the
elevation of the world ocean's surface and `elevation` a host copy of the field it was
derived from. `surface` is the terrain-level `CategoricalLabel{SURFACE_LEGEND}` field
of each cell's class from `SURFACE_CLASSES`, and `fractions` its coarsening, the
`CategoricalFraction{SURFACE_LEGEND}` field of each coarse cell's land, ocean and
inland-water area shares weighted by the primal cell area at the terrain level.
`land_component` and `terminal` are per terrain cell, from `land_components` and
`drainage_terminals`. `ocean_gates` and `land_gates` are per coarse edge, from `gates`.
"""
struct Graph{S<:Fields.Field,F<:Fields.Field,T,C}
    terrain::LevelMesh{T}
    coarse::LevelMesh{C}
    datum::Float64
    elevation::Vector{Float64}
    surface::S
    fractions::F
    land_component::Vector{Union{Nothing,Int32}}
    terminal::Vector{Terminal}
    ocean_gates::Vector{OceanGate}
    land_gates::Vector{LandGate}
end

"""
    host_values(f, quantity, site)

A host `Vector{Float64}` copy of `f`'s data, moved through `Backends.on`. Refuses at
`site`, naming `quantity`, data that is not one value per cell of `f`'s level and any
value that is not finite.
"""
function host_values(f::Fields.Field, quantity::AbstractString, site::AbstractString)
    d = Fields.data(f)
    d isa AbstractVector ||
        refuse(quantity, site, "$(ndims(d)) dimensions; the graph reads one value per cell")
    n = Mesh.ncells(Fields.level(f))
    length(d) == n ||
        refuse(quantity, site, "level $(Fields.level(f)) is $n cells and the field holds $(length(d))")
    values = Vector{Float64}(Backends.on(d, Backends.CPU()))
    for i in eachindex(values)
        isfinite(values[i]) || refuse(quantity, site, "cell $i holds $(values[i])")
    end
    return values
end

"""
    derive(elevation; datum, ocean_seeds, water_depth, terrain, coarse, coarse_support)

The `Graph` of `elevation`, an `Intensive` field of dimension `LENGTH` on the uniform
level `terrain`, reported at the coarser uniform level `coarse` whose support is
`coarse_support`.

A cell is ocean when `world_ocean` joins it to a cell of `ocean_seeds` below `datum`;
otherwise it is inland water where `water_depth`, a field declaring what `elevation`
declares, is positive, and land elsewhere. Every keyword is required.

Refuses a field that is not `Intensive` of dimension `LENGTH`; a `water_depth` that
`Fields.require_combinable` refuses beside `elevation`; a mesh that is not the one
its support was built from; a coarse level not coarser than the terrain level; a
non-finite `datum`, elevation or water depth; a negative water depth; a positive
water depth on an ocean cell; and a coarsening of the surface classes whose ledger for
some class is open, naming the class.
"""
function derive(elevation::Fields.Field{Fields.Intensive,TS,typeof(Dimensions.LENGTH)};
                datum::Real, ocean_seeds, water_depth::Fields.Field, terrain::LevelMesh,
                coarse::LevelMesh, coarse_support::Mesh.Support) where {TS}
    site = "Connectivity.derive"
    Fields.require_combinable(elevation, water_depth, site)
    terrain_support = Fields.support(elevation)
    require_on_support(terrain, terrain_support, site)
    require_on_support(coarse, coarse_support, site)
    coarse.index < terrain.index ||
        refuse("coarse level", site,
               "level $(coarse.index) is not coarser than the terrain level $(terrain.index)")
    isfinite(datum) || refuse("datum", site, "the datum is $datum")
    datum64 = Float64(datum)

    z = host_values(elevation, "elevation", site)
    depth = host_values(water_depth, "water depth", site)
    ocean = world_ocean(z, datum64, terrain.stencils, ocean_seeds, site)
    for i in eachindex(depth)
        depth[i] >= 0 || refuse("water depth", site, "cell $i holds a negative depth $(depth[i])")
        ocean[i] && depth[i] > 0 &&
            refuse("water depth", site,
                   "cell $i is world ocean and holds an inland water depth $(depth[i])")
    end

    surface = Fields.Field(semantics = Fields.CategoricalLabel{SURFACE_LEGEND}(),
                           dimension = Dimensions.DIMENSIONLESS,
                           data = surface_labels(ocean, depth), support = terrain_support,
                           time = Fields.time_support(elevation),
                           origin = Fields.unstamped(:connectivity, Fields.origin(elevation).run))
    fractions, class_areas = Fields.coarsen(surface, coarse_support; legend = SURFACE_CLASSES,
                                            measure = Fields.Measured{:primal_cell_area}(terrain.geometry.cell_area),
                                            reservoir = false, backend = Backends.CPU())
    Fields.closed(class_areas) ||
        refuse("surface fractions", site,
               "the coarsening does not conserve the $(Fields.quantity(class_areas)) of " *
               join((String(c) for (c, l) in zip(Fields.classes(class_areas),
                                                  Fields.ledgers(class_areas))
                     if !Fields.closed(l)), ", "))
    ocean_gates, land_gates = gates(z, datum64, ocean, terrain, coarse,
                                    terrain_support.radius, site)
    return Graph(terrain, coarse, datum64, z, surface, fractions,
                 land_components(ocean, terrain.stencils),
                 drainage_terminals(z, ocean, terrain.stencils), ocean_gates, land_gates)
end

derive(elevation::Fields.Field; kwargs...) =
    refuse("elevation", "Connectivity.derive",
           "$(Fields.describe(elevation)); the graph is derived from an Intensive field of dimension LENGTH")

"""
    is_ocean(graph)

Whether each terrain cell of `graph` is world ocean, read from its surface field.
"""
is_ocean(graph::Graph) = BitVector([label === :ocean for label in Fields.data(graph.surface)])
