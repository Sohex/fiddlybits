using Test
using Fiddlybits: Mesh, Verdicts

# mesh.support_identity: docs/oracles/registry.toml. This file is the
# acceptance of docs/plans/fiddlybits-52v.2-mesh.md, row 52v.2.6, and of
# REQ-TER-002.

const SI_LEVEL = 2
const SI_KIND = :icosahedral_bisection
const SI_VERSION = Mesh.GEOMETRY_CONSTRUCTOR_VERSION
const SI_ELEMENT_TYPE = :Float64
const SI_RADIUS = 1.0

"""
    si_support(level, geometry; kwargs...)

`Mesh.Support` built at `SI_LEVEL` with one shared recipe of defaults, every
one of which a test overrides to isolate the field it is checking.
"""
function si_support(level::Mesh.Level, geometry::Mesh.Geometry;
                     level_index = SI_LEVEL, kind = SI_KIND, refinement = (),
                     radius = SI_RADIUS, element_type = SI_ELEMENT_TYPE,
                     fractions = ())
    return Mesh.Support(level_index, level, geometry;
                         kind = kind, refinement = refinement,
                         radius = radius, element_type = element_type,
                         fractions = fractions)
end

"""
    si_digest(support; constructor_version)

The digest of `support` recomputed with `constructor_version` put in place of
the one it carries, which is the only door to that field: `Mesh.Support` reads
it from `Mesh.GEOMETRY_CONSTRUCTOR_VERSION` and does not take it.
"""
si_digest(support; constructor_version) =
    Mesh.support_digest(; kind = support.kind, level = support.level,
                          refinement_digest = support.refinement_digest,
                          constructor_version = constructor_version,
                          coordinate_digest = support.coordinate_digest,
                          measure_digest = support.measure_digest,
                          radius = support.radius,
                          element_type = support.element_type,
                          fraction_digest = support.fraction_digest)

const SI_HIERARCHY_A = Mesh.hierarchy(SI_LEVEL)
const SI_HIERARCHY_B = Mesh.hierarchy(SI_LEVEL)
const SI_LEVEL_A = SI_HIERARCHY_A.levels[SI_LEVEL + 1]
const SI_LEVEL_B = SI_HIERARCHY_B.levels[SI_LEVEL + 1]
const SI_STENCILS_A = Mesh.stencils(SI_LEVEL_A)
const SI_STENCILS_B = Mesh.stencils(SI_LEVEL_B)
const SI_GEOMETRY_A = Mesh.geometry(SI_LEVEL_A, SI_STENCILS_A)
const SI_GEOMETRY_B = Mesh.geometry(SI_LEVEL_B, SI_STENCILS_B)

@testset "mesh.support_identity" begin
    @testset "two meshes built from one recipe share a digest, exactly" begin
        support_a = si_support(SI_LEVEL_A, SI_GEOMETRY_A)
        support_b = si_support(SI_LEVEL_B, SI_GEOMETRY_B)
        @test SI_LEVEL_A.vertices !== SI_LEVEL_B.vertices
        @test support_a.digest == support_b.digest
    end

    @testset "perturbing one vertex coordinate by one ulp changes the digest" begin
        base = si_support(SI_LEVEL_A, SI_GEOMETRY_A)
        perturbed_vertices = copy(SI_LEVEL_A.vertices)
        perturbed_vertices[1, 1] = nextfloat(perturbed_vertices[1, 1])
        perturbed_level = Mesh.Level{Float64}(perturbed_vertices, SI_LEVEL_A.cells)
        perturbed = si_support(perturbed_level, SI_GEOMETRY_A)
        @test perturbed.digest != base.digest
    end

    @testset "two supports that differ only in radius have different digests" begin
        base = si_support(SI_LEVEL_A, SI_GEOMETRY_A; radius = 1.0)
        other = si_support(SI_LEVEL_A, SI_GEOMETRY_A; radius = 2.0)
        @test other.digest != base.digest
    end

    @testset "two supports that differ only in level have different digests" begin
        base = si_support(SI_LEVEL_A, SI_GEOMETRY_A; level_index = SI_LEVEL)
        other = si_support(SI_LEVEL_A, SI_GEOMETRY_A; level_index = SI_LEVEL + 1)
        @test other.digest != base.digest
    end

    @testset "two supports that differ only in the refinement region set have different digests" begin
        base = si_support(SI_LEVEL_A, SI_GEOMETRY_A; refinement = ())
        other = si_support(SI_LEVEL_A, SI_GEOMETRY_A; refinement = ((1, 2),))
        @test other.digest != base.digest
    end

    @testset "positive control: two refinements holding the same regions in different orders produce the same digest" begin
        forward = si_support(SI_LEVEL_A, SI_GEOMETRY_A; refinement = ((1, 2), (3, 4), (5, 6)))
        reversed = si_support(SI_LEVEL_A, SI_GEOMETRY_A; refinement = ((5, 6), (3, 4), (1, 2)))
        @test forward.digest == reversed.digest

        forward_vector = si_support(SI_LEVEL_A, SI_GEOMETRY_A;
                                     refinement = [(1, 2), (3, 4), (5, 6)])
        reversed_vector = si_support(SI_LEVEL_A, SI_GEOMETRY_A;
                                      refinement = reverse([(1, 2), (3, 4), (5, 6)]))
        @test forward_vector.digest == reversed_vector.digest

        tuple_form = si_support(SI_LEVEL_A, SI_GEOMETRY_A; refinement = ((1, 2), (3, 4), (5, 6)))
        vector_form = si_support(SI_LEVEL_A, SI_GEOMETRY_A;
                                  refinement = [(1, 2), (3, 4), (5, 6)])
        @test tuple_form.digest == vector_form.digest
    end

    @testset "a refinement with a duplicated region produces the digest of the set" begin
        with_duplicate = si_support(SI_LEVEL_A, SI_GEOMETRY_A; refinement = ((1, 2), (1, 2), (3, 4)))
        without_duplicate = si_support(SI_LEVEL_A, SI_GEOMETRY_A; refinement = ((1, 2), (3, 4)))
        @test with_duplicate.digest == without_duplicate.digest
    end

    @testset "a refinement with a region given in a narrower integer type produces the same digest" begin
        narrow = si_support(SI_LEVEL_A, SI_GEOMETRY_A;
                             refinement = [(Int32(1), Int32(2)), (3, 4)])
        wide = si_support(SI_LEVEL_A, SI_GEOMETRY_A; refinement = ((1, 2), (3, 4)))
        @test narrow.digest == wide.digest
    end

    @testset "two supports that differ only in constructor version have different digests" begin
        support = si_support(SI_LEVEL_A, SI_GEOMETRY_A)
        base = si_digest(support; constructor_version = SI_VERSION)
        other = si_digest(support; constructor_version = SI_VERSION + 1)
        # The constructor reads the constant rather than taking it, so a caller
        # cannot hold an identity at a version the geometry no longer has.
        @test support.constructor_version == Mesh.GEOMETRY_CONSTRUCTOR_VERSION
        @test base == support.digest
        @test other != base
    end

    @testset "two supports that differ only in element type have different digests" begin
        base = si_support(SI_LEVEL_A, SI_GEOMETRY_A; element_type = :Float64)
        other = si_support(SI_LEVEL_A, SI_GEOMETRY_A; element_type = :Float32)
        @test other.digest != base.digest
    end

    @testset "two supports that differ only in an effective fraction have different digests" begin
        base = si_support(SI_LEVEL_A, SI_GEOMETRY_A; fractions = ())
        other = si_support(SI_LEVEL_A, SI_GEOMETRY_A; fractions = ([0.5, 0.25],))
        @test other.digest != base.digest
    end

    @testset "a support equals itself and == compares the digest, not the shape" begin
        support_a = si_support(SI_LEVEL_A, SI_GEOMETRY_A)
        support_b = si_support(SI_LEVEL_B, SI_GEOMETRY_B)
        @test support_a == support_a
        @test SI_LEVEL_A.vertices !== SI_LEVEL_B.vertices
        @test support_a == support_b
    end

    @testset "require_same_support returns on a match and refuses naming both digests on a mismatch" begin
        matching_a = si_support(SI_LEVEL_A, SI_GEOMETRY_A)
        matching_b = si_support(SI_LEVEL_B, SI_GEOMETRY_B)
        @test Mesh.require_same_support(matching_a, matching_b, "test.site") === nothing

        mismatched = si_support(SI_LEVEL_A, SI_GEOMETRY_A; radius = 2.0)
        caught = nothing
        try
            Mesh.require_same_support(matching_a, mismatched, "test.site")
        catch e
            caught = e
        end
        @test caught isa Verdicts.Refusal
        @test occursin(bytes2hex(matching_a.digest), caught.reason)
        @test occursin(bytes2hex(mismatched.digest), caught.reason)
    end

    @testset "positive control: the shape-alone digest collides across radius, the real digest does not" begin
        shape_at_r1 = Mesh.shape_digest(SI_LEVEL_A, SI_GEOMETRY_A, 1.0)
        shape_at_r2 = Mesh.shape_digest(SI_LEVEL_A, SI_GEOMETRY_A, 2.0)
        support_at_r1 = si_support(SI_LEVEL_A, SI_GEOMETRY_A; radius = 1.0)
        support_at_r2 = si_support(SI_LEVEL_A, SI_GEOMETRY_A; radius = 2.0)
        @info "mesh.support_identity positive control: shape digest ignoring radius" shape_at_r1 shape_at_r2
        @test shape_at_r1 == shape_at_r2
        @test support_at_r1.digest != support_at_r2.digest
    end
end

# require_ancestor: docs/oracles/registry.toml mesh.support_identity;
# fiddlybits-52v.2.14; REQ-TER-002.
@testset "mesh.support_identity: require_ancestor" begin
    @testset "two levels of one hierarchy are accepted" begin
        coarse_level = SI_HIERARCHY_A.levels[SI_LEVEL]
        coarse_stencils = Mesh.stencils(coarse_level)
        coarse_geometry = Mesh.geometry(coarse_level, coarse_stencils)
        coarse = si_support(coarse_level, coarse_geometry; level_index = SI_LEVEL - 1)
        fine = si_support(SI_LEVEL_A, SI_GEOMETRY_A)
        @test Mesh.require_ancestor(coarse, fine, "test.site") === nothing
    end

    @testset "positive control: two hierarchies bisected from different base icosahedra share kind, radius, element type and refinement, and only lineage_digest tells them apart" begin
        v0, c0 = Mesh.base_icosahedron(Float64)
        perturbed_v0 = copy(v0)
        perturbed_v0[1, 1] = nextfloat(perturbed_v0[1, 1])
        other_level = Mesh.Level{Float64}(perturbed_v0, c0)
        for _ in 1:SI_LEVEL
            other_level = Mesh.bisect(other_level, true)
        end
        other_stencils = Mesh.stencils(other_level)
        other_geometry = Mesh.geometry(other_level, other_stencils)

        from = si_support(SI_LEVEL_A, SI_GEOMETRY_A)
        to = si_support(other_level, other_geometry)

        # what the family check fiddlybits-52v.2.14 replaces compared, and all of it
        # agrees between two hierarchies with different base icosahedra:
        @test from.kind == to.kind
        @test from.radius == to.radius
        @test from.element_type == to.element_type
        @test from.refinement_digest == to.refinement_digest
        @test from.lineage_digest != to.lineage_digest

        caught = nothing
        try
            Mesh.require_ancestor(from, to, "test.site")
        catch e
            caught = e
        end
        @test caught isa Verdicts.Refusal
        @test occursin("lineage_digest", caught.reason)
    end
end
