using Test
using LinearAlgebra: norm
using Fiddlybits: Mesh

# mesh.nesting_identity and mesh.area_closure read this hierarchy; their oracles
# are the next row's. This file is the interface acceptance named in
# docs/plans/fiddlybits-52v.2-mesh.md, row 52v.2.2.

const TOP_LEVEL = 5
const FORMULA_LEVELS = 0:8

const HIERARCHY = Mesh.hierarchy(TOP_LEVEL)
const CONTROL = Mesh.hierarchy(TOP_LEVEL; project = false)

"The bytes one `Mesh.midpoint` call allocates, measured after a warm-up call."
function midpoint_allocations(vertices)
    Mesh.midpoint(vertices, Int32(1), Int32(2), true)
    return @allocated Mesh.midpoint(vertices, Int32(1), Int32(2), true)
end

"The worst `abs(1 - norm(v))` over every column of `vertices`."
worst_radial_defect(vertices) = maximum(abs(1 - norm(view(vertices, :, i))) for i in axes(vertices, 2))

@testset "Mesh.hierarchy" begin
    @testset "parent(children(i)) == i at every level" begin
        for l in 0:TOP_LEVEL
            @test all(i -> all(==(i), Mesh.parent.(Mesh.children(i))), 1:Mesh.ncells(l))
        end
    end

    @testset "the closed forms" begin
        @testset "ncells, nedges, nvertices against 20*4^L, 30*4^L, 10*4^L + 2" begin
            for l in FORMULA_LEVELS
                @test Mesh.ncells(l) == 20 * 4^l
                @test Mesh.nedges(l) == 30 * 4^l
                @test Mesh.nvertices(l) == 10 * 4^l + 2
            end
        end

        @testset "the Euler characteristic of a sphere holds at every level" begin
            for l in FORMULA_LEVELS
                @test Mesh.nvertices(l) - Mesh.nedges(l) + Mesh.ncells(l) == 2
            end
        end

        @testset "the built arrays match the closed forms" begin
            for l in 0:TOP_LEVEL
                level = HIERARCHY.levels[l + 1]
                @test size(level.cells, 2) == Mesh.ncells(l)
                @test size(level.vertices, 2) == Mesh.nvertices(l)
            end
        end
    end

    @testset "CellId refuses arithmetic" begin
        c = Mesh.CellId(3)
        @test_throws MethodError c + 1
        @test_throws MethodError c - 1
        @test_throws MethodError 1 + c
    end

    @testset "CellId is a scalar under broadcast" begin
        @test Mesh.memory_index.(Mesh.CellId(3)) == 4
        @test tuple.(1:2, Mesh.CellId(7)) == [(1, Mesh.CellId(7)), (2, Mesh.CellId(7))]
        @test Mesh.memory_index.([Mesh.CellId(0), Mesh.CellId(5)]) == [1, 6]
    end

    @testset "bisection allocates nothing per edge" begin
        vertices = HIERARCHY.levels[1].vertices
        @test midpoint_allocations(vertices) == 0
    end

    @testset "CellId round trip, both ways" begin
        disk = 0:(Mesh.ncells(TOP_LEVEL) - 1)
        memory = 1:Mesh.ncells(TOP_LEVEL)
        @test all(i -> Mesh.disk_id(Mesh.memory_index(Mesh.CellId(i))) == Mesh.CellId(i), disk)
        @test all(i -> Mesh.memory_index(Mesh.disk_id(i)) == i, memory)
    end

    @testset "every vertex of a projected hierarchy sits on the unit sphere" begin
        defects = [worst_radial_defect(HIERARCHY.levels[l + 1].vertices) for l in 0:TOP_LEVEL]
        # The bar is the radial-defect threshold mesh.nesting_identity carries
        # in docs/oracles/registry.toml.
        @test maximum(defects[2:end]) <= 4 * eps(Float64)
    end

    @testset "positive control: unrenormalised bisection fails the bar" begin
        projected_defects = [worst_radial_defect(HIERARCHY.levels[l + 1].vertices) for l in 1:TOP_LEVEL]
        control_defects = [worst_radial_defect(CONTROL.levels[l + 1].vertices) for l in 1:TOP_LEVEL]

        # The control's defect never approaches rounding: it stays parked at
        # the scale the first unrenormalised bisection set, not shrinking
        # toward zero the way the projected path's does immediately.
        @test all(>(1e-3), control_defects)
        @test minimum(control_defects) > 0.5 * maximum(control_defects)

        # Orders above the projected path at every level, so the comparison
        # cannot pass vacuously.
        for l in eachindex(control_defects)
            @test control_defects[l] / projected_defects[l] > 1e6
        end
    end

    @testset "a cell's children are geometrically inside it" begin
        for l in (0, 2, TOP_LEVEL - 1)
            parent_level = HIERARCHY.levels[l + 1]
            child_level = HIERARCHY.levels[l + 2]
            for i in (1, Mesh.ncells(l))
                v = parent_level.cells[:, i]
                corners = [parent_level.vertices[:, v[k]] for k in 1:3]
                edge_midpoints = Vector{Float64}[]
                for (a, b) in ((1, 2), (2, 3), (3, 1))
                    m = (corners[a] .+ corners[b]) ./ 2
                    push!(edge_midpoints, m ./ norm(m))
                end
                expected = vcat(corners, edge_midpoints)

                child_vertex_ids = Set{Int32}()
                for k in Mesh.children(i)
                    for row in 1:3
                        push!(child_vertex_ids, child_level.cells[row, k])
                    end
                end
                @test length(child_vertex_ids) == 6
                @test issubset(Set(v), child_vertex_ids)

                actual_positions = [child_level.vertices[:, idx] for idx in child_vertex_ids]
                for e in expected
                    @test any(p -> norm(p .- e) < 1e-12, actual_positions)
                end
            end
        end
    end
end
