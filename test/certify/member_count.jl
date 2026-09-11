using Test
using Fiddlybits: Backends

# The ensemble member count and the miss rate it detects: docs/plans/
# fiddlybits-52v.7-kernels.md, section "Certification", decision 0029, and
# notes/findings/2026-09-11-ulp-ensemble-member-count.md, which carries the
# measurements the two bracketed constants sit on.

@testset "certify.member_count_and_miss_rate_declared" begin
    @testset "the count is derived from the two declared brackets and nothing else" begin
        @test Backends.ENSEMBLE_MISS_RATE_RECIPROCAL == 256
        @test Backends.ENSEMBLE_CONFIDENCE_RECIPROCAL == 20
        @test Backends.ENSEMBLE_MEMBERS == 766
        @test Backends.ENSEMBLE_MEMBERS ==
              Backends.ensemble_members(Backends.ENSEMBLE_MISS_RATE_RECIPROCAL,
                                        Backends.ENSEMBLE_CONFIDENCE_RECIPROCAL)
    end

    @testset "the count meets the declared miss rate and is the smallest that does" begin
        alpha = 1 / Backends.ENSEMBLE_CONFIDENCE_RECIPROCAL
        p = 1 / Backends.ENSEMBLE_MISS_RATE_RECIPROCAL
        @test (1 - p)^Backends.ENSEMBLE_MEMBERS <= alpha
        @test (1 - p)^(Backends.ENSEMBLE_MEMBERS - 1) > alpha
    end

    @testset "the detected miss rate is the inverse of the count rule" begin
        rate = Backends.detectable_miss_rate(Backends.ENSEMBLE_MEMBERS,
                                             Backends.ENSEMBLE_CONFIDENCE_RECIPROCAL)
        @test rate == Backends.ENSEMBLE_MISS_RATE
        @test rate <= 1 / Backends.ENSEMBLE_MISS_RATE_RECIPROCAL
        @test Backends.ensemble_members(floor(Int, 1 / rate),
                                        Backends.ENSEMBLE_CONFIDENCE_RECIPROCAL) ==
              Backends.ENSEMBLE_MEMBERS
    end

    @testset "the declared rate is finer than the stand-in case needs" begin
        # The stand-in case's sites that reach within one binary exponent of its
        # exhaustive envelope are one in 60.2
        # (notes/findings/2026-09-11-ulp-ensemble-member-count.md).
        @test Backends.ENSEMBLE_MISS_RATE < 1 / 60
    end

    @testset "positive control: a pair detects only a sub-population that is most of the sites" begin
        pair = Backends.detectable_miss_rate(2, Backends.ENSEMBLE_CONFIDENCE_RECIPROCAL)
        @test pair > 1 / 2
        @test pair > 100 * Backends.ENSEMBLE_MISS_RATE
    end

    @testset "the member set covers the site list" begin
        sites = 2 * CertifyFixtures.N_CELLS
        order = Backends.bit_reversed_order(sites)
        chosen = sort(order[1:Backends.ENSEMBLE_MEMBERS])
        gaps = diff(vcat(chosen, chosen[1] + sites))
        @test maximum(gaps) == 4

        @testset "positive control: a pair does not" begin
            two = sort(order[1:2])
            @test maximum(diff(vcat(two, two[1] + sites))) == div(sites, 2)
        end
    end

    @testset "the envelope carries the count and the rate it was measured with" begin
        @test CASE_ENVELOPE.members == Backends.ENSEMBLE_MEMBERS
        @test CASE_ENVELOPE.sites == 2 * CertifyFixtures.N_CELLS
        @test !CASE_ENVELOPE.exhaustive
        @test CASE_ENVELOPE.miss_rate == Backends.ENSEMBLE_MISS_RATE
    end
end
