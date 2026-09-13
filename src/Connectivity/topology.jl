# A change in the graph's topology between two derivations, emitted as a
# topology_change event through the one emitter of decision 0042.

using ..Events

"The component name every event this module emits carries."
const COMPONENT = "Connectivity"

"""
    EDITS

The closed vocabulary of graph edits, each with what its quantity is.
"""
const EDITS = (
    (name = :seaway_closed,
     quantity = "the greatest water column before the edit over a cell of the edit now at or above the datum; for an ocean gate lost with no cell of its coarse cells changing class, its sill depth before the edit"),
    (name = :island_emerged,
     quantity = "the greatest water column before the edit over a cell of the edit now at or above the datum"),
    (name = :land_bridge_flooded,
     quantity = "the greatest water column after the edit over a cell of the edit that lay at or above the datum; for an ocean gate gained with no cell of its coarse cells changing class, its sill depth after the edit"),
    (name = :island_submerged,
     quantity = "the greatest water column after the edit over a cell of the edit that lay at or above the datum"),
    (name = :basin_captured,
     quantity = "the area at the support's radius of the captured basin's catchment that drains to its captor after the edit"),
)

"Every edit name `EDITS` declares, in order."
edit_names() = map(e -> e.name, EDITS)

"""
    Edit(name, cells, quantity)

One edit of the graph: `name` from `EDITS`, the coarse cells it touches as ascending
memory indices at the coarse level, and its quantity as `EDITS` declares it. Refuses a
`name` outside `EDITS`.
"""
struct Edit
    name::Symbol
    cells::Vector{Int}
    quantity::Float64

    function Edit(name::Symbol, cells::Vector{Int}, quantity::Float64)
        name in edit_names() ||
            refuse("edit", "Connectivity.Edit",
                   "$(repr(name)) is not one of $(join(map(repr, edit_names()), ", "))")
        return new(name, cells, quantity)
    end
end

Base.:(==)(a::Edit, b::Edit) = a.name === b.name && a.cells == b.cells && a.quantity == b.quantity

"""
    cluster!(members, visited, was_ocean, is_ocean, stencils, seed)

`members` filled, ascending, with the cells joined to `seed` through edge neighbours
that each changed between ocean and non-ocean in the same direction as `seed`, each
marked in `visited`.
"""
function cluster!(members::Vector{Int}, visited::BitVector, was_ocean::BitVector,
                  is_ocean::BitVector, stencils::Mesh.Stencils, seed::Int)
    empty!(members)
    visited[seed] = true
    push!(members, seed)
    head = 1
    while head <= length(members)
        i = members[head]
        head += 1
        for k in 1:3
            j = Int(stencils.edge_neighbour[k, i])
            (visited[j] || was_ocean[j] != was_ocean[seed] || is_ocean[j] != is_ocean[seed]) && continue
            visited[j] = true
            push!(members, j)
        end
    end
    return sort!(members)
end

"The coarse edges carrying a gate in `gates`."
gate_edges(gates) = Set{Int32}(g.edge for g in gates)

"""
    cluster_edit(old, new, members, was_ocean, is_ocean, toggles, attributed, site)

The `Edit` a cluster of cells that changed between ocean and non-ocean makes, or
`nothing` when it changes no topology. Every coarse edge of `toggles` with a coarse
cell holding a cell of the cluster is added to `attributed`.

A cluster that left the ocean changes topology when the non-ocean cells beside it,
non-ocean in both graphs, lay in other than one land component of `old`; when a cell
of it lies below the datum in `new`; or when a coarse edge of `toggles.closing`, the
edges that lost an ocean gate or gained a land gate, has a coarse cell holding a cell
of the cluster. It is `:island_emerged` when no land lay beside it and `:seaway_closed`
otherwise. A cluster that joined the ocean is the same with the two graphs exchanged
and `toggles.flooding`, and is `:island_submerged` or `:land_bridge_flooded`.

Refuses at `site` a cluster in which no cell crossed the datum, since the two graphs
then name different oceans.
"""
function cluster_edit(old::Graph, new::Graph, members::Vector{Int}, was_ocean::BitVector,
                      is_ocean::BitVector, toggles, attributed::Set{Int32}, site::AbstractString)
    closing = was_ocean[first(members)]
    wet, dry = closing ? (old, new) : (new, old)
    st = new.terrain.stencils
    cst = new.coarse.stencils
    depth = new.terrain.index - new.coarse.index
    inside = Set(members)
    components = Set{Int32}()
    for i in members, k in 1:3
        j = Int(st.edge_neighbour[k, i])
        j in inside && continue
        was_ocean[j] || is_ocean[j] || push!(components, something(wet.land_component[j]))
    end
    holding = Set{Int}(coarse_cell(i, depth) for i in members)
    touches(e) = Int(cst.edge_cell[1, e]) in holding || Int(cst.edge_cell[2, e]) in holding
    for e in union(toggles.closing, toggles.flooding)
        touches(e) && push!(attributed, e)
    end
    gate_changed = any(touches, closing ? toggles.closing : toggles.flooding)
    enclosed = any(i -> dry.datum - dry.elevation[i] > 0, members)
    length(components) == 1 && !enclosed && !gate_changed && return nothing

    crossed = [i for i in members if dry.datum - dry.elevation[i] <= 0]
    isempty(crossed) &&
        refuse("world ocean", site,
               "cells $(first(members)) and the $(length(members) - 1) joined to it changed between ocean and non-ocean with none crossing the datum, so the two graphs do not name the same ocean")
    quantity = maximum(i -> wet.datum - wet.elevation[i], crossed)
    name = closing ? (isempty(components) ? :island_emerged : :seaway_closed) :
                     (isempty(components) ? :island_submerged : :land_bridge_flooded)
    cells = sort!(unique!(Int[coarse_cell(i, depth) for i in members]))
    return Edit(name, cells, quantity)
end

"""
    captures(old, new, is_ocean)

A `:basin_captured` edit for every closed basin of `old` whose naming cell is not ocean
in `new` and drains in `new` to a terminal other than the one that basin became: the
world ocean, or a closed basin whose naming cell drained in `old` to a terminal other
than the captured basin. Its cells are the coarse cells of the two naming cells and its
quantity the area of the captured catchment that drains to the captor in `new`.
"""
function captures(old::Graph, new::Graph, is_ocean::BitVector)
    out = Edit[]
    depth = new.terrain.index - new.coarse.index
    radius = Fields.support(new.surface).radius
    area = new.terrain.geometry.cell_area
    for i in eachindex(old.terminal)
        basin = old.terminal[i]
        (basin isa Int32 && basin == i && !is_ocean[i]) || continue
        captor = new.terminal[i]
        if captor isa Int32
            previous = old.terminal[captor]
            previous isa Int32 && previous == basin && continue
        end
        cells = captor isa Int32 ?
            sort!(unique!(Int[coarse_cell(i, depth), coarse_cell(captor, depth)])) :
            Int[coarse_cell(i, depth)]
        shares = Float64[Mesh.at_radius(area[j], radius, 2) for j in eachindex(area)
                         if old.terminal[j] == basin && new.terminal[j] == captor]
        push!(out, Edit(:basin_captured, cells, compensated_sum(shares)))
    end
    return out
end

"""
    topology_changes(old, new)

Every `Edit` between two graphs derived on the same terrain and coarse supports: one
per cluster of cells that changed between ocean and non-ocean and changed topology,
in ascending order of the cluster's lowest cell; then, in ascending coarse edge order,
a `:seaway_closed` for every ocean gate lost and a `:land_bridge_flooded` for every
ocean gate gained whose coarse cells hold no cell of any such cluster, with the gate's
sill depth and its two coarse cells; then the basin captures in ascending order of the
captured basin. Refuses graphs on different supports, naming both.
"""
function topology_changes(old::Graph, new::Graph)
    site = "Connectivity.topology_changes"
    Mesh.require_same_support(Fields.support(old.surface), Fields.support(new.surface), site)
    Mesh.require_same_support(Fields.support(old.fractions), Fields.support(new.fractions), site)
    was_ocean = is_ocean(old)
    now_ocean = is_ocean(new)
    old_ocean = Dict{Int32,OceanGate}(g.edge => g for g in old.ocean_gates)
    new_ocean = Dict{Int32,OceanGate}(g.edge => g for g in new.ocean_gates)
    old_land = gate_edges(old.land_gates)
    new_land = gate_edges(new.land_gates)
    lost_ocean = setdiff(Set{Int32}(keys(old_ocean)), keys(new_ocean))
    gained_ocean = setdiff(Set{Int32}(keys(new_ocean)), keys(old_ocean))
    toggles = (closing = union(lost_ocean, setdiff(new_land, old_land)),
               flooding = union(gained_ocean, setdiff(old_land, new_land)))
    attributed = Set{Int32}()
    edits = Edit[]
    visited = falses(length(was_ocean))
    members = Int[]
    for i in eachindex(was_ocean)
        (visited[i] || was_ocean[i] == now_ocean[i]) && continue
        cluster!(members, visited, was_ocean, now_ocean, new.terrain.stencils, i)
        edit = cluster_edit(old, new, members, was_ocean, now_ocean, toggles, attributed, site)
        edit === nothing || push!(edits, edit)
    end
    cst = new.coarse.stencils
    for e in sort!(collect(union(lost_ocean, gained_ocean)))
        e in attributed && continue
        cells = sort!(Int[cst.edge_cell[1, e], cst.edge_cell[2, e]])
        push!(edits, e in lost_ocean ? Edit(:seaway_closed, cells, old_ocean[e].sill_depth) :
                                       Edit(:land_bridge_flooded, cells, new_ocean[e].sill_depth))
    end
    append!(edits, captures(old, new, now_ocean))
    return edits
end

"""
    emit_topology_changes(old, new; sequence, instant, tier)

Every `Edit` of `topology_changes(old, new)`, each handed to `Events.emit` as one
`topology_change` event whose payload carries the edit's name, cells and quantity,
numbered from `sequence` in order, at `instant` on `tier`, from `COMPONENT`. Returns
the edits.
"""
function emit_topology_changes(old::Graph, new::Graph; sequence::Integer, instant::Real,
                               tier::Symbol)
    edits = topology_changes(old, new)
    for (k, edit) in enumerate(edits)
        payload = Events.TopologyChangePayload(edit = String(edit.name), cells = edit.cells,
                                               quantity = edit.quantity)
        Events.emit(Events.Event(Events.TopologyChange(), sequence + k - 1, instant, tier,
                                 COMPONENT, payload))
    end
    return edits
end
