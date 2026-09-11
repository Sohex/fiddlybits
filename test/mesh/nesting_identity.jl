using Test
using LinearAlgebra: norm
using Fiddlybits: Mesh

# mesh.nesting_identity: docs/oracles/registry.toml carries the derived
# absolute thresholds below, fixed by
# notes/findings/2026-09-10-chordal-bisection-and-spherical-area.md. This
# file is the acceptance of docs/plans/fiddlybits-52v.2-mesh.md, row 52v.2.3.

const NI_TOP_LEVEL = 5
const NI_LEVELS = 0:NI_TOP_LEVEL
const NI_EPS = eps(Float64)

const NI_HIERARCHY = Mesh.hierarchy(NI_TOP_LEVEL)
const NI_CONTROL = Mesh.hierarchy(NI_TOP_LEVEL; project = false)
const NI_STENCILS = [Mesh.stencils(NI_HIERARCHY.levels[l + 1]) for l in NI_LEVELS]
const NI_GEOMETRY = [Mesh.geometry(NI_HIERARCHY.levels[l + 1], NI_STENCILS[l + 1]) for l in NI_LEVELS]
const NI_CONTROL_STENCILS = [Mesh.stencils(NI_CONTROL.levels[l + 1]) for l in NI_LEVELS]
const NI_CONTROL_GEOMETRY = [Mesh.geometry(NI_CONTROL.levels[l + 1], NI_CONTROL_STENCILS[l + 1]) for l in NI_LEVELS]

ni_level(l) = NI_HIERARCHY.levels[l + 1]
ni_geometry(l) = NI_GEOMETRY[l + 1]

"The worst `abs(1 - norm(v))` over every column of `vertices`."
ni_worst_radial_defect(vertices) = maximum(abs(1 - norm(view(vertices, :, i))) for i in axes(vertices, 2))

@testset "mesh.nesting_identity" begin
    @testset "children(parent(i)) contains i, exactly, at every level" begin
        for l in 1:NI_TOP_LEVEL
            nc = Mesh.ncells(l)
            @test all(i -> i in Mesh.children(Mesh.parent(i)), 1:nc)
        end
    end

    @testset "the four child areas sum to the parent's area within 8 eps R^2 per parent" begin
        bar = 8 * NI_EPS
        for l in 0:(NI_TOP_LEVEL - 1)
            parent_geom = ni_geometry(l)
            child_geom = ni_geometry(l + 1)
            nc = Mesh.ncells(l)
            @test all(1:nc) do i
                child_sum = sum(child_geom.cell_area[k] for k in Mesh.children(i))
                abs(child_sum - parent_geom.cell_area[i]) <= bar
            end
        end
    end

    @testset "the worst radial defect of any vertex is within 4 eps R" begin
        bar = 4 * NI_EPS
        for l in NI_LEVELS
            level = ni_level(l)
            @test ni_worst_radial_defect(level.vertices) <= bar
        end
    end

    @testset "positive control: the unrenormalised hierarchy fails child-area sum and radial defect" begin
        bar_area = 8 * NI_EPS
        bar_radial = 4 * NI_EPS
        l = NI_TOP_LEVEL - 1
        parent_geom = NI_CONTROL_GEOMETRY[l + 1]
        child_geom = NI_CONTROL_GEOMETRY[l + 2]
        nc = Mesh.ncells(l)
        worst_area_residual = maximum(abs(sum(child_geom.cell_area[k] for k in Mesh.children(i)) -
                                          parent_geom.cell_area[i]) for i in 1:nc)
        worst_radial = ni_worst_radial_defect(NI_CONTROL.levels[NI_TOP_LEVEL + 1].vertices)
        @info "mesh.nesting_identity positive control: unrenormalised hierarchy" worst_area_residual bar_area worst_radial bar_radial
        @test worst_area_residual > bar_area
        @test worst_radial > bar_radial
    end
end
