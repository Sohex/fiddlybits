using Test
using Fiddlybits: Backends, Mesh

# The location vocabulary and edge_vertices: docs/plans/fiddlybits-52v.2-mesh.md,
# section "Locations", row 52v.2.20.
#
# closed_set and its fixture come from test/closure.jl, which Dispositions,
# Events, Time and Verdicts read through the same guarded include.

isdefined(@__MODULE__, :VocabularyClosure) ||
    include(joinpath(@__DIR__, "..", "closure.jl"))
using .VocabularyClosure: closed_set

const TOP_LEVEL = 3
const HIERARCHY = Mesh.hierarchy(TOP_LEVEL)

@testset "Mesh.Location" begin
    @testset "the enumeration is complete" begin
        undeclared, unreachable = closed_set(Mesh.Location, Mesh.locations())
        @test isempty(undeclared)
        @test isempty(unreachable)
        @test length(Mesh.locations()) == 3
    end

    @testset "the enumeration is the set section Locations declares" begin
        @test Mesh.locations() == (Mesh.Cells(), Mesh.Vertices(), Mesh.Edges())
    end

    @testset "element_count against the level's counts" begin
        for l in 0:TOP_LEVEL
            level = HIERARCHY.levels[l + 1]
            st = Mesh.stencils(level)
            @test Mesh.element_count(Mesh.Cells(), l) == size(level.cells, 2)
            @test Mesh.element_count(Mesh.Vertices(), l) == size(level.vertices, 2)
            @test Mesh.element_count(Mesh.Edges(), l) == size(st.edge_cell, 2)
        end
    end

    @testset "axis_name" begin
        @test Mesh.axis_name(Mesh.Cells()) === Backends.LAYOUT[1]
        @test Mesh.axis_name(Mesh.Vertices()) === :vertices
        @test Mesh.axis_name(Mesh.Edges()) === :edges
    end
end

"A Location subtype locations() does not enumerate, defined only after the
closure test above has run, so it never hides an omission from that test."
module FourthLocation
    using Fiddlybits: Mesh
    struct Faces <: Mesh.Location end
end

@testset "positive control: a fourth subtype is reported missing" begin
    undeclared, _ = closed_set(Mesh.Location, Mesh.locations())
    @test undeclared == [FourthLocation.Faces]
end

@testset "Mesh.edge_vertices" begin
    for l in 0:TOP_LEVEL
        level = HIERARCHY.levels[l + 1]
        st = Mesh.stencils(level)
        geom = Mesh.geometry(level, st)
        ev = Mesh.edge_vertices(level, st)
        ne = size(st.edge_cell, 2)
        @test size(ev) == (2, ne)

        for e in 1:ne
            a, b = ev[1, e], ev[2, e]
            pa = view(level.vertices, :, a)
            pb = view(level.vertices, :, b)

            @test Mesh.arc_length(pa, pb) == geom.primal_edge_length[e]
            @test Mesh.great_circle_midpoint(pa, pb) == geom.edge_midpoint[:, e]

            c1, c2 = st.edge_cell[1, e], st.edge_cell[2, e]
            @test a in level.cells[:, c1] && b in level.cells[:, c1]
            @test a in level.cells[:, c2] && b in level.cells[:, c2]

            # positive control: the creating cell's next local edge, mod1(k + 1, 3),
            # in place of edge k's, must fail the midpoint and corner comparisons.
            k = findfirst(kk -> st.cell_edge[kk, c1] == e, 1:3)
            k2 = mod1(k + 1, 3)
            ca, cb = Mesh.edge_local_vertices(level.cells, c1, k2)
            wrong_pa = view(level.vertices, :, ca)
            wrong_pb = view(level.vertices, :, cb)
            @test Mesh.great_circle_midpoint(wrong_pa, wrong_pb) != geom.edge_midpoint[:, e]
            @test !(ca in level.cells[:, c1] && cb in level.cells[:, c1] &&
                    ca in level.cells[:, c2] && cb in level.cells[:, c2])

            # positive control: the diagonal across the two cells sharing the edge,
            # the far corner of each cell (the corner that is not an endpoint of
            # e), is longer than the edge, so arc_length must fail.
            f1 = level.cells[k, c1]
            k1 = findfirst(kk -> st.cell_edge[kk, c2] == e, 1:3)
            f2 = level.cells[k1, c2]
            diagonal = Mesh.arc_length(view(level.vertices, :, f1), view(level.vertices, :, f2))
            @test diagonal != geom.primal_edge_length[e]
        end
    end
end
