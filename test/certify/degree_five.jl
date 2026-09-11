using Test
using Fiddlybits: Backends, Verdicts

include(joinpath(@__DIR__, "mesh_fixture.jl"))
using .CertifyMeshFixture

# The degree-five cells the sampled ulp ensemble cannot see: docs/plans/
# fiddlybits-52v.7-kernels.md, section "Certification", decision 0005's twelve
# degree-five cells, and notes/findings/2026-09-11-ulp-ensemble-member-
# count.md, "What the ensemble cannot see", which row fiddlybits-52v.7.17
# carries out.
#
# The domain-wide certification of `certification.jl` sums `observed` and
# `roundoff` over the whole case, so a defect confined to one cell is a share
# of that sum as small as the cell's own share of the case, the same relative
# dilution the finding measures for the sampled ensemble itself. Scoping
# `observed`, `roundoff` and the envelope to the named degree-five sites
# (`Backends.certification`'s `sites` door, `Backends.exhaustive_envelope`)
# removes that dilution for exactly the sub-population the sampled ensemble
# is too coarse to reach.

const MESH_CASE, MESH_NEIGHBOUR, MESH_W, MESH_VALENCE, MESH_PENTAGON = CertifyMeshFixture.real_mesh_case()
const MESH_NV = length(MESH_CASE.fields[1])
const MESH_PENTAGON_SITES = Tuple{Int,Int}[(f, v) for f in eachindex(MESH_CASE.fields) for v in MESH_PENTAGON]
const MESH_SAMPLED_ENVELOPE = Backends.envelope(MESH_CASE, CertifyMeshFixture.STEPS)
const MESH_PENTAGON_ENVELOPE = Backends.exhaustive_envelope(MESH_CASE, CertifyMeshFixture.STEPS,
                                                             MESH_PENTAGON_SITES)
const MESH_ROUNDOFF_DOMAIN = CertifyMeshFixture.roundoff(MESH_CASE)
const MESH_ROUNDOFF_PENTAGON = CertifyMeshFixture.roundoff(MESH_CASE; sites = MESH_PENTAGON_SITES)
const MESH_DEFECT_VERTEX = MESH_PENTAGON[1]

# Chosen to separate the two verdicts with margin on both sides (section
# "Every constant, with its disposition" in the finding this row carries out
# does not cover this value: it is a demonstration magnitude for this test,
# not a bisected detection threshold the way certification.jl's is).
const MESH_DEFECT_RELATIVE = 1.0e-2

@testset "certify.degree_five_cells_are_not_a_special_case" begin
    @testset "the twelve degree-five cells, identified from valence rather than assumed" begin
        @test length(MESH_PENTAGON) == 12
        @test all(==(Int32(5)), MESH_VALENCE[MESH_PENTAGON])
        @test count(==(Int32(5)), MESH_VALENCE) == 12
        @test count(==(Int32(6)), MESH_VALENCE) == MESH_NV - 12
        @test sort(unique(MESH_VALENCE)) == Int32[5, 6]

        @testset "their relative share of sites is below the ensemble's declared miss rate" begin
            share = length(MESH_PENTAGON_SITES) / MESH_SAMPLED_ENVELOPE.sites
            @test share < Backends.ENSEMBLE_MISS_RATE
        end
    end

    @testset "the certification perturbs every degree-five cell in addition to the sampled ensemble" begin
        @test MESH_SAMPLED_ENVELOPE.case == MESH_CASE.name
        @test MESH_SAMPLED_ENVELOPE.exhaustive == false
        @test MESH_SAMPLED_ENVELOPE.members == Backends.ENSEMBLE_MEMBERS

        @test MESH_PENTAGON_ENVELOPE.case == MESH_CASE.name
        @test MESH_PENTAGON_ENVELOPE.exhaustive == true
        @test MESH_PENTAGON_ENVELOPE.miss_rate == 0
        @test MESH_PENTAGON_ENVELOPE.members == length(MESH_PENTAGON_SITES)
        @test MESH_PENTAGON_ENVELOPE.sites == length(MESH_PENTAGON_SITES)
        @test length(MESH_PENTAGON_SITES) == length(MESH_CASE.fields) * length(MESH_PENTAGON)

        @testset "every field and every degree-five cell is named, and nothing else" begin
            named = Set(MESH_PENTAGON_SITES)
            expected = Set((f, v) for f in eachindex(MESH_CASE.fields) for v in MESH_PENTAGON)
            @test named == expected
            @test all(v -> MESH_VALENCE[v] == 5, last.(MESH_PENTAGON_SITES))
        end
    end

    @testset "the correct candidate certifies at both scopes: positive control" begin
        correct = CertifyMeshFixture.make_step(MESH_NV, MESH_NEIGHBOUR, MESH_W)
        domain = Backends.certification(correct, MESH_CASE, MESH_SAMPLED_ENVELOPE;
                                        roundoff = MESH_ROUNDOFF_DOMAIN)
        pentagon = Backends.certification(correct, MESH_CASE, MESH_PENTAGON_ENVELOPE;
                                          roundoff = MESH_ROUNDOFF_PENTAGON,
                                          sites = MESH_PENTAGON_SITES)
        @test domain.verdict == Backends.PASS()
        @test pentagon.verdict == Backends.PASS()
        @test all(domain.observed .<= domain.bound)
        @test all(pentagon.observed .<= pentagon.bound)
    end

    @testset "a defect planted at one degree-five cell alone is caught" begin
        @test MESH_VALENCE[MESH_DEFECT_VERTEX] == 5
        defect = CertifyMeshFixture.localized_defect(MESH_NV, MESH_NEIGHBOUR, MESH_W,
                                                      MESH_DEFECT_VERTEX, MESH_DEFECT_RELATIVE)

        report = Backends.certification(defect, MESH_CASE, MESH_PENTAGON_ENVELOPE;
                                        roundoff = MESH_ROUNDOFF_PENTAGON,
                                        sites = MESH_PENTAGON_SITES)
        @test report.verdict == Backends.FAIL()
        @test any(report.observed .> report.bound)

        @testset "the verdict is an OracleVerdict and never a boolean" begin
            verdict = Backends.certify(defect, MESH_CASE, MESH_PENTAGON_ENVELOPE;
                                       roundoff = MESH_ROUNDOFF_PENTAGON, sites = MESH_PENTAGON_SITES)
            @test verdict isa Verdicts.OracleVerdict
            @test !(verdict isa Bool)
            @test verdict == report.verdict
        end

        @testset "positive control: the sampled ensemble alone is shown to miss it" begin
            missed = Backends.certification(defect, MESH_CASE, MESH_SAMPLED_ENVELOPE;
                                            roundoff = MESH_ROUNDOFF_DOMAIN)
            @test missed.verdict == Backends.PASS()
            @test all(missed.observed .<= missed.bound)
        end
    end
end
