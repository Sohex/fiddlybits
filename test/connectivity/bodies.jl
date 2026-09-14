using Test
using Fiddlybits: Connectivity, Mesh, Reductions, Verdicts

# The acceptance of fiddlybits-52v.2.17: a coarse cell holding two ocean bodies carries a
# gate for each, and a body splitting or two bodies joining is a topology edit.

isdefined(@__MODULE__, :ConnectivityFixtures) || include(joinpath(@__DIR__, "fixtures.jl"))
using .ConnectivityFixtures
const CB = ConnectivityFixtures

"The graph of an isthmus world, seeded in B, with no inland water."
cb_graph(z) = CB.graph(z; seeds = [CB.centre(CB.B)], depth = zeros(CB.NCELLS))

"The primal lengths at the radius of the terrain edges `edges`, summed in ascending order."
cb_width(edges) = Reductions.compensated_sum(
    Float64[Mesh.at_radius(CB.TERRAIN.geometry.primal_edge_length[e], CB.RADIUS, 1) for e in sort(edges)])

"The one ocean gate of `g` on coarse edge `edge`."
cb_gate(g, edge) = only(gate for gate in g.ocean_gates if gate.edge == edge)

"The body a gate names on the side of coarse cell `cell`."
cb_side(gate, cell) = gate.bodies[findfirst(==(cell), gate.cells)]

const CB_WORLD = cb_graph(CB.isthmus_world())

"The primal length at the radius of terrain edge `e`."
cb_length(e) = Mesh.at_radius(CB.TERRAIN.geometry.primal_edge_length[e], CB.RADIUS, 1)

"""
    cb_parallel(sea, sills, neighbour)

Whether the network over the horizon of a sea's gate is parallel two-edge paths, one
per sill: the sea's cells off its sills joined, no two sills sharing an edge, and each
sill's crossing to coarse cell `neighbour` shorter than its two edges into the sea
together, so the least section is the sills' crossings.
"""
function cb_parallel(sea, sills, neighbour)
    CB.joined([i for i in sea if !(i in sills)]) || return false
    for i in sills
        any(in(sills), CB.neighbours(i)) && return false
        inner = [CB.edge_between(i, j) for j in CB.neighbours(i) if j in sea]
        outer = only(CB.edge_between(i, j) for j in CB.neighbours(i)
                     if CB.Mesh.ancestor(j, CB.DEPTH) == neighbour)
        cb_length(outer) < cb_length(inner[1]) + cb_length(inner[2]) || return false
    end
    return true
end

@testset "connectivity bodies" begin
    @testset "an isthmus cell with a sea on each side carries both connections" begin
        @test cb_parallel(CB.SEA_B, CB.SILL_B, CB.B)
        @test cb_parallel(CB.SEA_Z, CB.SILL_Z, CB.Z)
        b = cb_gate(CB_WORLD, CB.EDGE)
        z = cb_gate(CB_WORLD, CB.EDGE_Z)
        @test Set(b.cells) == Set((CB.A, CB.B))
        @test Set(z.cells) == Set((CB.A, CB.Z))
        @test b.sill_depth == CB.DATUM - CB.SILL_B_FLOOR
        @test z.sill_depth == CB.DATUM - CB.SILL_Z_FLOOR
        @test b.section == Int32.(CB.CROSSINGS_B)
        @test z.section == Int32.(CB.CROSSINGS_Z)
        @test b.width == cb_width(CB.CROSSINGS_B)
        @test z.width == cb_width(CB.CROSSINGS_Z)
        @test b.width != z.width
    end

    @testset "each sea is a body of A, and each gate names its own" begin
        b = cb_gate(CB_WORLD, CB.EDGE)
        z = cb_gate(CB_WORLD, CB.EDGE_Z)
        @test Connectivity.ocean_bodies(CB_WORLD, CB.A) ==
              sort(Int32[minimum(CB.SEA_B), minimum(CB.SEA_Z)])
        @test all(i -> CB_WORLD.ocean_body[i] == minimum(CB.SEA_B), CB.SEA_B)
        @test all(i -> CB_WORLD.ocean_body[i] == minimum(CB.SEA_Z), CB.SEA_Z)
        @test cb_side(b, CB.A) == minimum(CB.SEA_B)
        @test cb_side(z, CB.A) == minimum(CB.SEA_Z)
        @test length(Set(CB_WORLD.land_body[i] for i in CB.ISTHMUS)) == 1
        @test Connectivity.ocean_bodies(CB_WORLD, CB.B) == [first(Mesh.descendants(CB.B, CB.DEPTH))]
    end

    @testset "positive control: one ocean body per coarse cell reports only one of the two" begin
        ocean = Connectivity.is_ocean(CB_WORLD)
        control, _ = Connectivity.gates(CB_WORLD.elevation, CB_WORLD.datum, ocean,
                                        Connectivity.coarse_cell_bodies(ocean, CB.DEPTH),
                                        CB_WORLD.land_body, CB.TERRAIN, CB.COARSE, CB.RADIUS,
                                        "connectivity bodies control")
        @test length([gate for gate in control if CB.A in gate.cells]) == 1
        @test length([gate for gate in CB_WORLD.ocean_gates if CB.A in gate.cells]) == 2
    end

    @testset "the isthmus flooding joins A's two bodies and is one edit, and rising splits them" begin
        flooded = cb_graph(CB.isthmus_world(isthmus_floor = CB.A_FLOOR))
        @test length(Connectivity.ocean_bodies(flooded, CB.A)) == 1
        @test Connectivity.topology_changes(CB_WORLD, flooded) ==
              [Connectivity.Edit(:land_bridge_flooded, [CB.A], CB.DATUM - CB.A_FLOOR)]
        @test Connectivity.topology_changes(flooded, CB_WORLD) ==
              [Connectivity.Edit(:seaway_closed, [CB.A], CB.DATUM - CB.A_FLOOR)]
    end

    @testset "a bar splitting a sea whose two parts keep a gate each is one edit" begin
        barred = cb_graph(CB.isthmus_world(raised = CB.BAR_B))
        sides = sort([cb_side(gate, CB.A) for gate in barred.ocean_gates if gate.edge == CB.EDGE])
        @test length(sides) == 2
        @test length(Connectivity.ocean_bodies(barred, CB.A)) == 3
        @test Connectivity.land_bodies(barred, CB.A) == Connectivity.land_bodies(CB_WORLD, CB.A)
        @test minimum(CB.SEA_B) in sides
        column = maximum(i -> CB.DATUM - CB.isthmus_world()[i], CB.BAR_B)
        @test Connectivity.topology_changes(CB_WORLD, barred) ==
              [Connectivity.Edit(:seaway_closed, [CB.A], column)]
        @test Connectivity.topology_changes(barred, CB_WORLD) ==
              [Connectivity.Edit(:land_bridge_flooded, [CB.A], column)]
    end

    @testset "a coarse cell outside the level is refused" begin
        err = try
            Connectivity.ocean_bodies(CB_WORLD, CB.NCOARSE + 1)
            nothing
        catch caught
            caught
        end
        @test err isa Verdicts.Refusal && err.quantity == "coarse cell"
    end
end
