using Test
using Fiddlybits: Backends, Verdicts

# The ensemble member count, the miss rate it detects, and the seeded draw the
# miss rate is a probability over: docs/plans/fiddlybits-52v.7-kernels.md,
# section "Certification", decision 0029,
# notes/findings/2026-09-11-ulp-ensemble-member-count.md, which carries the
# measurements the two bracketed constants sit on, and
# docs/decisions/0052-the-sampled-ensemble-is-a-seeded-draw.md, which fixes the
# draw.

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

    @testset "the envelope carries the count, the rate and the seed it was measured with" begin
        @test CASE_ENVELOPE.members == Backends.ENSEMBLE_MEMBERS
        @test CASE_ENVELOPE.sites == 2 * CertifyFixtures.N_CELLS
        @test !CASE_ENVELOPE.exhaustive
        @test CASE_ENVELOPE.miss_rate == Backends.ENSEMBLE_MISS_RATE
        @test CASE_ENVELOPE.seed === Backends.ENSEMBLE_SEED
    end
end

# The number of seeds the miss frequency is taken over.
const DRAW_SEEDS = 400

@testset "certify.sampled_draw_is_seeded" begin
    usable = Backends.usable_sites(CASE, Float32)
    m = Backends.ENSEMBLE_MEMBERS
    seed = Backends.ENSEMBLE_SEED
    drawn = Backends.sampled_sites(usable, m, seed)

    @testset "the envelope's members are reproduced from what the envelope carries" begin
        @test CASE_ENVELOPE.perturbed ==
              Backends.sampled_sites(Backends.usable_sites(CASE, CASE_ENVELOPE.precision),
                                     CASE_ENVELOPE.members, CASE_ENVELOPE.seed)
    end

    @testset "a draw is without replacement, from the list it is given" begin
        @test length(drawn) == m
        @test allunique(drawn)
        @test issubset(drawn, usable)
    end

    @testset "a repeated seed repeats the draw" begin
        @test Backends.sampled_sites(copy(usable), m, seed) == drawn

        @testset "positive control: a changed seed changes the draw" begin
            other = Backends.sampled_sites(usable, m, seed + 1)
            @test Set(other) != Set(drawn)
        end
    end

    @testset "a site's key does not depend on the rest of the list or its order" begin
        outside = first(s for s in usable if !(s in drawn))
        @test Backends.sampled_sites(filter(!=(outside), usable), m, seed) == drawn
        @test Backends.sampled_sites(reverse(usable), m, seed) == drawn

        @testset "positive control: removing a drawn site changes the draw" begin
            @test Backends.sampled_sites(filter(!=(drawn[1]), usable), m, seed) != drawn
        end
    end

    @testset "a draw it cannot take is refused" begin
        for (sites, members) in ((usable, 0), (usable, length(usable) + 1), ([(1, 1), (1, 1)], 1))
            caught = try
                Backends.sampled_sites(sites, members, seed)
            catch e
                e
            end
            @test caught isa Verdicts.Refusal
            @test caught.quantity == "ulp-ensemble draw"
        end

        @testset "positive control: every site at once is a draw" begin
            @test Set(Backends.sampled_sites(usable, length(usable), seed)) == Set(usable)
        end
    end

    @testset "the miss rate is a probability over the seed" begin
        # A sub-population of relative size 1 / ENSEMBLE_MISS_RATE_RECIPROCAL on
        # the site positions 1 modulo that reciprocal. The miss probability of a
        # draw without replacement is hypergeometric and known exactly; the
        # frequency over DRAW_SEEDS seeds must sit within four standard errors of
        # it, and at or below the declared confidence.
        n = length(usable)
        r = Backends.ENSEMBLE_MISS_RATE_RECIPROCAL
        alpha = 1 / Backends.ENSEMBLE_CONFIDENCE_RECIPROCAL
        sub = Set(usable[k] for k in 1:n if mod(k - 1, r) == 1)
        @test length(sub) == div(n, r)
        exact(members) = prod((n - members - k) / (n - k) for k in 0:(length(sub) - 1))
        @test exact(m) <= (1 - 1 / r)^m <= alpha

        missed = Dict(m => 0, 2 => 0)
        for s in 1:DRAW_SEEDS
            order = Backends.sampled_sites(usable, n, UInt64(s))
            for members in keys(missed)
                isdisjoint(view(order, 1:members), sub) && (missed[members] += 1)
            end
        end
        within(members) = abs(missed[members] / DRAW_SEEDS - exact(members)) <=
                          4 * sqrt(exact(members) * (1 - exact(members)) / DRAW_SEEDS)

        @test within(m)
        @test missed[m] / DRAW_SEEDS <= alpha

        @testset "positive control: two members miss it at more than the declared confidence" begin
            @test within(2)
            @test missed[2] / DRAW_SEEDS > alpha
        end

        @testset "positive control: the bit-reversed prefix misses it at every seed" begin
            prefix = Set(usable[k] for k in CertifyFixtures.bit_reversed_prefix(n, m))
            @test isdisjoint(prefix, sub)
        end
    end
end
