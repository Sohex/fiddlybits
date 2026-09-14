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

    @testset "a sill deepening with no cell changing class moves the gate and no topology" begin
        seeds = [CG.A_BODY, first(CG.PAIRS[2])]
        shallow = cg_graph(CG.gate_world(gap_floor = CG.LAND); seeds = seeds)
        deep = cg_graph(CG.gate_world(gap_floor = CG.LAND, strip_floor = 2 * CG.B_FLOOR); seeds = seeds)
        @test Connectivity.is_ocean(shallow) == Connectivity.is_ocean(deep)
        before = only(shallow.ocean_gates)
        after = only(deep.ocean_gates)
        strip = shallow.ocean_body[first(CG.PAIRS[2])]
        @test before.bodies == after.bodies
        @test strip in before.bodies
        @test !(shallow.ocean_body[CG.A_BODY] in before.bodies)
        @test before.sill_depth == CG.DATUM - CG.STRAIT_FLOOR
        @test after.sill_depth == CG.DATUM - CG.B_FLOOR
        @test isempty(Connectivity.topology_changes(shallow, deep))
        @test isempty(Connectivity.topology_changes(deep, shallow))
    end

    @testset "a wet crossing between two strips joins the strips and neither deep body" begin
        z = CG.gate_world(gap_floor = CG.LAND, walled_b = true)
        g = cg_graph(z; seeds = [CG.A_BODY, CG.B_BODY, first(CG.PAIRS[2])])
        @test Connectivity.is_ocean(g)[first(CG.PAIRS[2])]
        @test Connectivity.is_ocean(g)[CG.PAIRS[2][2]]
        gate = only(g.ocean_gates)
        @test Set(gate.bodies) == Set((g.ocean_body[first(CG.PAIRS[2])], g.ocean_body[CG.PAIRS[2][2]]))
        @test !any(gate -> g.ocean_body[CG.A_BODY] in gate.bodies || g.ocean_body[CG.B_BODY] in gate.bodies,
                   g.ocean_gates)
        @test length(Connectivity.ocean_bodies(g, CG.A)) == 2
        @test length(Connectivity.ocean_bodies(g, CG.B)) == 2
    end

    @testset "an islet across the coarse edge is a land gate between its halves alone" begin
        g = cg_graph(CG.gate_world(gap_floor = CG.STRAIT_FLOOR, islet = true))
        @test !Connectivity.is_ocean(g)[first(CG.PAIRS[7])]
        gate = only(gate for gate in g.land_gates if gate.edge == CG.EDGE)
        @test Set(gate.bodies) == Set((g.land_body[first(CG.PAIRS[7])], g.land_body[CG.PAIRS[7][2]]))
        @test gate.crossings == 1
        @test gate.width == cg_length(CG.PAIRS[7][3])
        @test g.land_body[first(CG.PAIRS[7])] == first(CG.PAIRS[7])

        @testset "the islet cuts the strip's end off as a body of its own, with its own gate" begin
            neck = g.ocean_body[CG.GAP_UP]
            cut = g.ocean_body[first(CG.PAIRS[8])]
            @test neck != cut
            @test g.ocean_body[first(CG.PAIRS[6])] == neck
            @test Set(cb for gate in g.ocean_gates for cb in gate.bodies
                     if Connectivity.coarse_cell(cb, CG.DEPTH) == CG.A) == Set((neck, cut))
            @test length(g.ocean_gates) == 2
        end
    end
end
