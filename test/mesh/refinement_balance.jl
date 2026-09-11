using Test
using Fiddlybits: Mesh, Verdicts

# mesh.refinement_balance: the acceptance of
# docs/plans/fiddlybits-52v.2-mesh.md, row 52v.2.5. The grading rule and the
# abrupt boundary admitted for the damped components are decision 0005.

const RB_BASE = 2
const RB_DEPTH = 2
const RB_FINEST = RB_BASE + RB_DEPTH
const RB_EPS = eps(Float64)
const RB_SEEDS = (1, 2)

const RB_HIERARCHY = Mesh.hierarchy(RB_FINEST)
const RB_STENCILS = Mesh.Stencils[Mesh.stencils(RB_HIERARCHY.levels[l + 1]) for l in 0:RB_FINEST]
const RB_GEOMETRY = [Mesh.geometry(RB_HIERARCHY.levels[l + 1], RB_STENCILS[l + 1]) for l in 0:RB_FINEST]

rb_stencils(l) = RB_STENCILS[l + 1]
rb_geometry(l) = RB_GEOMETRY[l + 1]

"The mesh refined into `RB_SEEDS` by `RB_DEPTH` levels through rings of `w` cells."
rb_refine(w) = Mesh.refine(RB_BASE, rb_stencils(RB_BASE), RB_SEEDS, RB_DEPTH; ring_width = w)

"The primal edge length of local edge `k` of `cell` at `level`."
rb_edge_length(level, cell, k) =
    rb_geometry(level).primal_edge_length[rb_stencils(level).cell_edge[k, cell]]

"""
    rb_finest_crossings(m)

The number of finest-level edges whose two sides lie in leaves of different
levels, counted from the coarse side. One hanging edge at level `l` spans
`2^(finest - l)` of them, so this count is what the hanging-edge list has to
add up to.
"""
function rb_finest_crossings(m::Mesh.RefinedMesh)
    owner, level_of = Mesh.leaf_owner(m)
    st = rb_stencils(RB_FINEST)
    crossings = 0
    for f in eachindex(owner), k in 1:3
        g = Int(st.edge_neighbour[k, f])
        level_of[owner[f]] < level_of[owner[g]] && (crossings += 1)
    end
    return crossings
end

"The sum of the leaf cell areas of `m`."
rb_leaf_area(m) = sum(rb_geometry(l).cell_area[i] for (l, i) in Mesh.leaves(m))

@testset "mesh.refinement_balance" begin
    @testset "the ring width is an argument and is read" begin
        abrupt = rb_refine(1)
        graded = rb_refine(3)
        @test abrupt.ring_width == 1
        @test graded.ring_width == 3
        @test abrupt.target != graded.target
    end

    @testset "a width that would step more than one level between neighbours is refused" begin
        @test_throws Verdicts.Refusal rb_refine(0)
        @test_throws Verdicts.Refusal Mesh.refine(RB_BASE, rb_stencils(RB_BASE), RB_SEEDS, -1; ring_width = 1)
        @test_throws Verdicts.Refusal Mesh.refine(RB_BASE, rb_stencils(RB_BASE), Int[], RB_DEPTH; ring_width = 1)
    end

    @testset "2:1 balance holds by construction, graded and abrupt" begin
        for w in (1, 2, 3, 5)
            @test Mesh.balanced(rb_refine(w), rb_stencils(RB_FINEST))
        end
    end

    @testset "positive control: a target set built without the grading rule is not balanced" begin
        # The seeds at full depth and every other cell at the base level, which
        # is the two-level step across a boundary that grading exists to stop.
        target = zeros(Int, Mesh.ncells(RB_BASE))
        for s in RB_SEEDS
            target[s] = RB_DEPTH
        end
        unbalanced = Mesh.RefinedMesh(RB_BASE, RB_DEPTH, 1, target)
        @test !Mesh.balanced(unbalanced, rb_stencils(RB_FINEST))
    end

    @testset "a graded region steps one level per ring" begin
        for w in (1, 2, 3, 5)
            m = rb_refine(w)
            distance = Mesh.ring_distance(rb_stencils(RB_BASE), RB_SEEDS, Mesh.ncells(RB_BASE))
            @test all(c -> m.target[c] == max(0, RB_DEPTH - div(distance[c], w)), eachindex(m.target))
            # Every level between the seed's and the base level is occupied, so
            # the region steps down rather than jumping.
            @test sort(unique(m.target)) == collect(0:RB_DEPTH)
        end
    end

    @testset "the leaves tile the sphere" begin
        for w in (1, 3)
            m = rb_refine(w)
            @test Mesh.nleaves(m) == length(Mesh.leaves(m))
            @test abs(rb_leaf_area(m) - 4 * pi) <= Mesh.nleaves(m) * RB_EPS
        end
    end

    @testset "a hanging edge's children carry their own measure, summing to the coarse one" begin
        bar = 4 * RB_EPS
        for w in (1, 3)
            m = rb_refine(w)
            hanging = Mesh.hanging_edges(m, RB_HIERARCHY, RB_STENCILS)
            @test !isempty(hanging)
            @test sum(2^(RB_FINEST - h.coarse_level) for h in hanging) == rb_finest_crossings(m)
            @test all(hanging) do h
                coarse = rb_edge_length(h.coarse_level, h.coarse_cell, h.coarse_local_edge)
                first = rb_edge_length(h.coarse_level + 1, h.fine_cells[1], h.fine_local_edges[1])
                second = rb_edge_length(h.coarse_level + 1, h.fine_cells[2], h.fine_local_edges[2])
                abs(first + second - coarse) <= bar
            end
        end
    end

    @testset "a constant density gives the coarse edge its own flux, and the control fails" begin
        bar = 4 * RB_EPS
        m = rb_refine(3)
        hanging = Mesh.hanging_edges(m, RB_HIERARCHY, RB_STENCILS)
        density = (1.0, 1.0)
        worst = 0.0
        worst_control = 0.0
        for h in hanging
            coarse = rb_edge_length(h.coarse_level, h.coarse_cell, h.coarse_local_edge)
            lengths = (rb_edge_length(h.coarse_level + 1, h.fine_cells[1], h.fine_local_edges[1]),
                       rb_edge_length(h.coarse_level + 1, h.fine_cells[2], h.fine_local_edges[2]))
            worst = max(worst, abs(Mesh.hanging_flux(density, lengths) - density[1] * coarse))
            worst_control = max(worst_control,
                                abs(Mesh.coarse_measure_flux(density, coarse) - density[1] * coarse))
        end
        @info "mesh.refinement_balance hanging flux" worst worst_control bar
        @test worst <= bar
        @test worst_control > bar
    end

    @testset "the transition ring is what a fluid component reads for its damping" begin
        m = rb_refine(3)
        ring = Mesh.transition_ring(m)
        @test all(c -> ring[c] == RB_DEPTH - m.target[c], eachindex(ring))
        @test all(s -> ring[s] == 0, RB_SEEDS)
    end
end
