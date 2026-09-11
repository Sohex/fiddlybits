using Test
using LinearAlgebra: cross, dot, normalize
using Fiddlybits: Mesh

# mesh.area_closure: docs/oracles/registry.toml carries the derived absolute
# thresholds below, fixed by
# notes/findings/2026-09-10-chordal-bisection-and-spherical-area.md for the
# primal sum and by
# notes/findings/2026-09-11-mesh-measure-floors-at-working-precision.md for the
# dual sum, the right angle and the circumcentre spread. This file is the
# acceptance of docs/plans/fiddlybits-52v.2-mesh.md, row 52v.2.3.

const AC_TOP_LEVEL = 5
const AC_LEVELS = 0:AC_TOP_LEVEL
const AC_EPS = eps(Float64)

const AC_HIERARCHY = Mesh.hierarchy(AC_TOP_LEVEL)
const AC_CONTROL = Mesh.hierarchy(AC_TOP_LEVEL; project = false)
const AC_STENCILS = [Mesh.stencils(AC_HIERARCHY.levels[l + 1]) for l in AC_LEVELS]
const AC_GEOMETRY = [Mesh.geometry(AC_HIERARCHY.levels[l + 1], AC_STENCILS[l + 1]) for l in AC_LEVELS]
const AC_CONTROL_STENCILS = [Mesh.stencils(AC_CONTROL.levels[l + 1]) for l in AC_LEVELS]
const AC_CONTROL_GEOMETRY = [Mesh.geometry(AC_CONTROL.levels[l + 1], AC_CONTROL_STENCILS[l + 1]) for l in AC_LEVELS]

ac_level(l) = AC_HIERARCHY.levels[l + 1]
ac_stencils(l) = AC_STENCILS[l + 1]
ac_geometry(l) = AC_GEOMETRY[l + 1]

"The primal sum's bar at level `l`: the per-cell floor times the cell count."
ac_primal_bar(l) = Mesh.ncells(l) * AC_EPS

"The dual sum's bar at level `l`: the same floor times the six sub-triangles a dual cell takes from each primal cell."
ac_dual_bar(l) = 6 * Mesh.ncells(l) * AC_EPS

"The right angle's bar at level `l`, which doubles with the level because the cell's edge halves."
ac_angle_bar(l) = AC_EPS * 2.0^l

"The circumcentre spread's bar at level `l`, scaling with the level for the same reason."
ac_circumcentre_bar(l) = 4 * AC_EPS * 2.0^l

"""
    ac_edge_vertices(level, st)

The primal vertex pair spanning each edge of `st`, found the same way
`build_edges` numbers edges: scanning cells in index order and recording
each edge's local vertex pair the first time its global index is seen.
"""
function ac_edge_vertices(level::Mesh.Level, st::Mesh.Stencils)
    ne = size(st.edge_cell, 2)
    a = Vector{Int32}(undef, ne)
    b = Vector{Int32}(undef, ne)
    recorded = falses(ne)
    for i in axes(level.cells, 2), k in 1:3
        e = st.cell_edge[k, i]
        recorded[e] && continue
        recorded[e] = true
        u, v = Mesh.edge_local_vertices(level.cells, i, k)
        a[e] = u
        b[e] = v
    end
    return a, b
end

@testset "mesh.area_closure" begin
    @testset "primal cell areas sum to 4 pi R^2 at every level" begin
        for l in AC_LEVELS
            geom = ac_geometry(l)
            @test abs(sum(geom.cell_area) - 4 * pi) <= ac_primal_bar(l)
        end
    end

    @testset "dual cell areas sum to 4 pi R^2 at every level" begin
        for l in AC_LEVELS
            geom = ac_geometry(l)
            @test abs(sum(geom.dual_area) - 4 * pi) <= ac_dual_bar(l)
        end
    end

    @testset "the vector form and l'Huilier agree per cell to twice the per-cell floor" begin
        bar = 2 * AC_EPS
        for l in AC_LEVELS
            level = ac_level(l)
            nc = Mesh.ncells(l)
            @test all(1:nc) do i
                v1, v2, v3 = level.cells[1, i], level.cells[2, i], level.cells[3, i]
                p1 = view(level.vertices, :, v1)
                p2 = view(level.vertices, :, v2)
                p3 = view(level.vertices, :, v3)
                vector_form = Mesh.cell_area_vector_form(p1, p2, p3)
                lhuilier = Mesh.cell_area_lhuilier(p1, p2, p3)
                abs(vector_form - lhuilier) <= bar
            end
        end
    end

    @testset "the two-radius check: each measure closes against its own 4 pi R^2" begin
        l = AC_TOP_LEVEL
        geom = ac_geometry(l)
        for R in (1.0, 6371000.0)
            target = 4 * pi * R^2
            primal_sum = sum(Mesh.at_radius(a, R, 2) for a in geom.cell_area)
            dual_sum = sum(Mesh.at_radius(a, R, 2) for a in geom.dual_area)
            @test abs(primal_sum - target) <= ac_primal_bar(l) * R^2
            @test abs(dual_sum - target) <= ac_dual_bar(l) * R^2
        end
    end

    @testset "building the geometry allocates within a small multiple of it" begin
        l = AC_TOP_LEVEL
        level = ac_level(l)
        st = ac_stencils(l)
        nc, nv, ne = Mesh.ncells(l), Mesh.nvertices(l), Mesh.nedges(l)
        returned = (4 * nc + nv + 8 * ne) * sizeof(Float64)
        Mesh.geometry(level, st)
        GC.gc()
        used = @allocated Mesh.geometry(level, st)
        @info "Mesh.geometry allocation" level = l returned_bytes = returned allocated_bytes = used
        @test used <= 2 * returned
    end

    @testset "positive control: the unrenormalised bisection fails the bar" begin
        l = AC_TOP_LEVEL
        geom = AC_CONTROL_GEOMETRY[l + 1]
        primal_residual = abs(sum(geom.cell_area) - 4 * pi)
        dual_residual = abs(sum(geom.dual_area) - 4 * pi)
        @info "mesh.area_closure positive control: unrenormalised bisection" primal_residual dual_residual primal_bar = ac_primal_bar(l) dual_bar = ac_dual_bar(l)
        @test primal_residual > ac_primal_bar(l)
        @test dual_residual > ac_dual_bar(l)
    end

    @testset "the primal-to-dual edge angle is a right angle at every edge" begin
        for l in AC_LEVELS
            bar = ac_angle_bar(l)
            level = ac_level(l)
            st = ac_stencils(l)
            geom = ac_geometry(l)
            ea, eb = ac_edge_vertices(level, st)
            ne = Mesh.nedges(l)
            @test all(1:ne) do e
                pa = view(level.vertices, :, ea[e])
                pb = view(level.vertices, :, eb[e])
                chord_direction = normalize(pb .- pa)
                abs(dot(geom.edge_normal[:, e], chord_direction)) <= bar
            end
        end
    end

    @testset "the circumcentre is equidistant from a cell's own three vertices" begin
        for l in AC_LEVELS
            bar = ac_circumcentre_bar(l)
            level = ac_level(l)
            geom = ac_geometry(l)
            nc = Mesh.ncells(l)
            @test all(1:nc) do i
                v1, v2, v3 = level.cells[1, i], level.cells[2, i], level.cells[3, i]
                cc = view(geom.dual_vertex, :, i)
                d = (Mesh.arc_length(cc, view(level.vertices, :, v1)),
                     Mesh.arc_length(cc, view(level.vertices, :, v2)),
                     Mesh.arc_length(cc, view(level.vertices, :, v3)))
                maximum(d) - minimum(d) <= bar
            end
        end
    end
end
