using Test
using Fiddlybits: Connectivity, Events, Fields, Mesh, Reductions

# mesh.connectivity_topology_event: docs/oracles/registry.toml. This file is the
# acceptance of docs/plans/fiddlybits-52v.2-mesh.md, row 52v.2.7, and of REQ-TER-012.

isdefined(@__MODULE__, :ConnectivityFixtures) || include(joinpath(@__DIR__, "fixtures.jl"))
using .ConnectivityFixtures
const CF = ConnectivityFixtures

const CT_GRAPH = CF.graph(CF.elevation())
const CT_CLOSED = CF.graph(CF.edited(first.(CF.STRAIT), CF.LAND))

"The width the strait's crossings declare: their primal lengths at the radius, in edge order."
const CT_STRAIT_WIDTH = Reductions.compensated_sum(
    Float64[Mesh.at_radius(CF.TERRAIN.geometry.primal_edge_length[e], CF.RADIUS, 1)
            for e in sort!(last.(CF.STRAIT))])

"The primal cell area at the radius summed over `cells`, in ascending cell order."
ct_area(cells) = Reductions.compensated_sum(
    Float64[Mesh.at_radius(CF.TERRAIN.geometry.cell_area[i], CF.RADIUS, 2) for i in sort(collect(cells))])

"The events `f()` hands the emitter, collected by a fixture sink and then uninstalled."
function ct_collect(f)
    sink = Events.Collector{Events.Event}()
    Events.sink!(sink)
    try
        f()
    finally
        Events.sink!(Events.noop_sink)
    end
    return Events.collected(sink)
end

@testset "mesh.connectivity_topology_event" begin
    @testset "the strait's sill depth and width are reported exactly" begin
        @test length(CT_GRAPH.ocean_gates) == 1
        gate = only(CT_GRAPH.ocean_gates)
        @test gate.edge == CF.EDGE
        @test Set(gate.cells) == Set((CF.A, CF.B))
        @test gate.section == sort!(Int32.(last.(CF.STRAIT)))
        @test gate.sill_depth == CF.DATUM - CF.STRAIT_FLOOR
        @test gate.width == CT_STRAIT_WIDTH
        @test !any(g -> g.edge == CF.EDGE, CT_GRAPH.land_gates)
    end

    @testset "a land gate between two land coarse cells spans the whole edge" begin
        x = first(c for c in 1:CF.NCOARSE if !(c in CF.NEAR_AB))
        k = findfirst(k -> !(Int(CF.COARSE.stencils.edge_neighbour[k, x]) in CF.NEAR_AB), 1:3)
        edge = CF.COARSE.stencils.cell_edge[k, x]
        gate = only(g for g in CT_GRAPH.land_gates if g.edge == edge)
        st = CF.TERRAIN.stencils
        on_edge = [e for e in axes(st.edge_cell, 2)
                   if Set(Mesh.ancestor.(Int.(st.edge_cell[:, e]), CF.DEPTH)) ==
                      Set(Int.(CF.COARSE.stencils.edge_cell[:, edge]))]
        @test gate.crossings == length(on_edge) == 2^CF.DEPTH
        @test gate.width == Reductions.compensated_sum(
            Float64[Mesh.at_radius(CF.TERRAIN.geometry.primal_edge_length[e], CF.RADIUS, 1) for e in on_edge])
    end

    @testset "land contiguity: the island is its own component and all other land is one" begin
        components = CT_GRAPH.land_component
        @test components[CF.ISLAND] == CF.ISLAND
        others = Set(c for (i, c) in enumerate(components) if c !== nothing && i != CF.ISLAND)
        @test length(others) == 1
        @test components[CF.OCEAN_SEED] === nothing
        @test components[CF.BASIN_PIT] == only(others)

        @testset "closing the strait encloses B and joins the island to the land" begin
            @test length(Set(c for c in CT_CLOSED.land_component if c !== nothing)) == 1
            @test isempty(CT_CLOSED.ocean_gates)
        end
    end

    @testset "basin terminals" begin
        terminal = CT_GRAPH.terminal
        @test all(i -> terminal[i] == CF.BASIN_PIT, CF.BASIN)
        @test terminal[CF.OCEAN_SEED] === Connectivity.WORLD_OCEAN
        @test all(i -> terminal[i] === Connectivity.WORLD_OCEAN, CF.SHORE)
        @test terminal[first(CF.P)] == first(CF.P)
        @test all(i -> terminal[i] == first(CF.Q), CF.Q)
        @test terminal[CF.ISLAND] === Connectivity.WORLD_OCEAN

        @testset "the sea closing encloses drains to a closed basin of its own" begin
            b_cells = [i for i in 1:CF.NCELLS if Mesh.ancestor(i, CF.DEPTH) == CF.B && i != CF.ISLAND]
            pits = Set(CT_CLOSED.terminal[i] for i in b_cells)
            @test length(pits) == 1
            @test only(pits) isa Int32
        end
    end

    @testset "a class is decided by connectivity, and the elevation-sign control fires" begin
        labels = Fields.data(CT_GRAPH.surface)
        @test all(i -> labels[i] === :land, CF.BASIN[2:end])
        @test labels[CF.BASIN_PIT] === :inland_water
        @test CF.no_enclosed_ocean(labels)

        control = Connectivity.elevation_sign_surface(CF.elevation(), CF.DATUM)
        @test !CF.no_enclosed_ocean(control)
        @test all(i -> control[i] === :ocean, CF.BASIN)
    end

    @testset "an island is never rounded to ocean and an enclosed basin never to ocean" begin
        shares = Fields.data(CT_GRAPH.fractions)
        land, ocean, inland = 1, 2, 3
        @test Connectivity.SURFACE_CLASSES[land] === :land
        b_block = Mesh.descendants(CF.B, CF.DEPTH)
        @test 0 < shares[CF.B, land] < 1
        @test shares[CF.B, land] ≈ ct_area([CF.ISLAND]) / ct_area(b_block) rtol = 64 * eps()
        @test shares[CF.C, ocean] == 0
        @test shares[CF.C, inland] > 0
        @test all(k -> isapprox(sum(shares[k, :]), 1; atol = 64 * eps()), 1:CF.NCOARSE)
    end

    @testset "closing the strait emits one topology event through the one emitter" begin
        log = ct_collect(() -> Connectivity.emit_topology_changes(CT_GRAPH, CT_CLOSED;
                                                                   sequence = 7, instant = 3.5e9,
                                                                   tier = :slow))
        @test length(log) == 1
        event = only(log)
        @test event.header.kind isa Events.TopologyChange
        @test Events.name(event.header.kind) === :topology_change
        @test event.header.kind in Events.kinds()
        @test event.header.component == Connectivity.COMPONENT
        @test event.header.sequence == 7
        @test event.header.tier === :slow
        @test event.payload.edit == "seaway_closed"
        @test event.payload.quantity == CF.DATUM - CF.STRAIT_FLOOR

        @testset "the cells read back at the declared level and base are the strait's two coarse cells" begin
            @test eltype(event.payload.cells) === Mesh.CellId
            # The cells at level L holding a terrain cell of a crossing of the strait.
            strait_at(L) = Set(Mesh.ancestor(Int(i), CF.TERRAIN_INDEX - L)
                               for e in only(CT_GRAPH.ocean_gates).section
                               for i in CF.TERRAIN.stencils.edge_cell[:, e])
            placed = Mesh.memory_index.(event.payload.cells)
            @test all(i -> 1 <= i <= Mesh.ncells(event.payload.level), placed)
            @test Set(placed) == strait_at(event.payload.level)
            @test placed == sort([CF.A, CF.B])

            @testset "positive control: the same cells read at the memory base, or at any other level, miss the strait" begin
                as_memory = [c.value for c in event.payload.cells]
                @test Set(as_memory) != strait_at(event.payload.level)
                others = [L for L in 0:CF.TERRAIN_INDEX if L != event.payload.level]
                @test all(L -> Set(placed) != strait_at(L), others)
            end
        end

        @testset "reopening it emits the reverse edit" begin
            back = Connectivity.topology_changes(CT_CLOSED, CT_GRAPH)
            @test length(back) == 1
            @test only(back).name === :land_bridge_flooded
            @test only(back).quantity == CF.DATUM - CF.STRAIT_FLOOR
        end
    end

    @testset "a graph compared with itself emits nothing" begin
        log = ct_collect(() -> Connectivity.emit_topology_changes(CT_GRAPH, CT_GRAPH;
                                                                   sequence = 1, instant = 0.0,
                                                                   tier = :slow))
        @test isempty(log)
    end

    @testset "silt on a coast changes no topology" begin
        silted = CF.graph(CF.edited([CF.SILT], CF.SILT_TOP))
        @test Fields.data(silted.surface)[CF.SILT] === :land
        @test isempty(Connectivity.topology_changes(CT_GRAPH, silted))
    end

    @testset "an island emerging is one edit" begin
        risen = CF.graph(CF.edited([CF.A_CENTRE], CF.SILT_TOP))
        @test Connectivity.topology_changes(CT_GRAPH, risen) ==
              [Connectivity.Edit(:island_emerged, [CF.A], CF.DATUM - CF.A_FLOOR)]
        @test Connectivity.topology_changes(risen, CT_GRAPH) ==
              [Connectivity.Edit(:island_submerged, [CF.A], CF.DATUM - CF.A_FLOOR)]
    end

    @testset "a basin captured by its neighbour is one edit" begin
        filled = CF.graph(CF.edited([first(CF.P)], CF.P_FLOOR))
        edits = Connectivity.topology_changes(CT_GRAPH, filled)
        @test length(edits) == 1
        edit = only(edits)
        @test edit.name === :basin_captured
        @test edit.cells == [CF.D]
        captured = [i for i in 1:CF.NCELLS
                    if CT_GRAPH.terminal[i] == first(CF.P) && filled.terminal[i] == first(CF.Q)]
        @test first(CF.P) in captured
        @test edit.quantity == ct_area(captured)
    end
end
