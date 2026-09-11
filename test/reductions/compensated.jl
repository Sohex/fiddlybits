using Test
using Fiddlybits: Reductions

# Compensated summation: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The reductions", decision 0027 (reference path) and decision 0029 (the
# stagnation argument).

@testset "compensated_sum" begin
    @testset "agrees with compensated_sum_reference on well-scaled input (decision 0027)" begin
        xs = ReductionFixtures.seeded_vector(Float64, ReductionFixtures.N)
        kernel = Reductions.compensated_sum(xs)
        reference = Reductions.compensated_sum_reference(xs)
        tol = Reductions.error_bound(Float64, length(xs), ReductionFixtures.term_magnitude(xs))
        @test abs(kernel - reference) <= tol
    end

    @testset "residual against the exact sum is within the declared bound" begin
        xs = ReductionFixtures.seeded_vector(Float64, ReductionFixtures.N)
        exact = ReductionFixtures.exact_sum(xs)
        result = Reductions.compensated_sum(xs)
        tol = Reductions.error_bound(Float64, length(xs), ReductionFixtures.term_magnitude(xs))
        @test abs(result - exact) <= tol
    end

    @testset "accumulates in Float64 regardless of eltype(xs)" begin
        xs32 = ReductionFixtures.seeded_vector(Float32, ReductionFixtures.N)
        @test Reductions.compensated_sum(xs32) isa Float64
    end

    @testset "the stagnation control (decision 0029): a stock of 1e8 taking a million unit increments moves by exactly a million" begin
        n = 1_000_000
        xs = ReductionFixtures.stock_and_increments(Float32, n)

        naive = 0.0f0
        for x in xs
            naive += x
        end
        @test naive - 1.0f8 == 0.0f0

        compensated = Reductions.compensated_sum(xs)
        @test compensated - 1.0e8 == Float64(n)

        @testset "positive control: the naive Float32 accumulation is the one that stagnates" begin
            @test naive - 1.0f8 != Float64(n)
        end
    end
end
