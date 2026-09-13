using Test
using Fiddlybits: Connectivity, Mesh

# The gates between adjacent coarse cells: the ocean gate read at the control section of
# the connection, the land gate read between the two cells' land.

isdefined(@__MODULE__, :ConnectivityFixtures) || include(joinpath(@__DIR__, "fixtures.jl"))
using .ConnectivityFixtures
const CG = ConnectivityFixtures

"The primal length at the radius of terrain edge `e`."
cg_length(e) = Mesh.at_radius(CG.TERRAIN.geometry.primal_edge_length[e], CG.RADIUS, 1)

"The graph of a gate world, seeded in A's body."
cg_graph(z; seeds = [CG.A_BODY]) = CG.graph(z; seeds = seeds)

@testset "connectivity gates" begin
    @testset "a shallow bar inside A behind a deep crossing is the sill" begin
        g = cg_graph(CG.gate_world(gap_floor = CG.BAR_FLOOR))
        gate = only(g.ocean_gates)
        @test gate.sill_depth == CG.DATUM - CG.BAR_FLOOR
        @test gate.width == minimum(cg_length, CG.NECK)
        @test length(gate.section) == 1
        @test only(gate.section) in CG.NECK
        @test gate.width == cg_length(only(gate.section))
    end

    @testset "a strait that narrows inside A is as wide as its narrow section" begin
        g = cg_graph(CG.gate_world(gap_floor = CG.STRAIT_FLOOR))
        gate = only(g.ocean_gates)
        @test gate.sill_depth == CG.DATUM - CG.STRAIT_FLOOR
        @test gate.width == minimum(cg_length, CG.NECK)
        @test length(gate.section) == 1
        @test only(gate.section) in CG.NECK
    end

    @testset "an ocean gate gained with no cell changing class is one edit" begin
        seeds = [CG.A_BODY, first(CG.PAIRS[2])]
        shallow = cg_graph(CG.gate_world(gap_floor = CG.LAND); seeds = seeds)
        deep = cg_graph(CG.gate_world(gap_floor = CG.LAND, strip_floor = 2 * CG.B_FLOOR); seeds = seeds)
        @test isempty(shallow.ocean_gates)
        @test Connectivity.is_ocean(shallow) == Connectivity.is_ocean(deep)
        gate = only(deep.ocean_gates)
        @test gate.sill_depth == CG.DATUM - CG.B_FLOOR
        @test Connectivity.topology_changes(shallow, deep) ==
              [Connectivity.Edit(:land_bridge_flooded, sort([CG.A, CG.B]), CG.DATUM - CG.B_FLOOR)]
        @test Connectivity.topology_changes(deep, shallow) ==
              [Connectivity.Edit(:seaway_closed, sort([CG.A, CG.B]), CG.DATUM - CG.B_FLOOR)]
    end

    @testset "a wet crossing joining neither side's ocean body is no ocean gate" begin
        z = CG.gate_world(gap_floor = CG.LAND, walled_b = true)
        g = cg_graph(z; seeds = [CG.A_BODY, CG.B_BODY, first(CG.PAIRS[2])])
        @test Connectivity.is_ocean(g)[first(CG.PAIRS[2])]
        @test Connectivity.is_ocean(g)[CG.PAIRS[2][2]]
        @test isempty(g.ocean_gates)
    end

    @testset "an isolated dry crossing is no land gate" begin
        g = cg_graph(CG.gate_world(gap_floor = CG.STRAIT_FLOOR, islet = true))
        @test !Connectivity.is_ocean(g)[first(CG.PAIRS[7])]
        @test !any(gate -> gate.edge == CG.EDGE, g.land_gates)
        @test length(g.ocean_gates) == 1
    end
end
