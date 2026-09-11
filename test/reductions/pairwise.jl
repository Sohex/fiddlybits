using Test
using Fiddlybits: Reductions, Backends, Verdicts

# Fixed-order pairwise summation: docs/plans/fiddlybits-52v.7-kernels.md,
# section "The reductions", and decision 0027 (reference path).

@testset "pairwise_sum" begin
    xs = ReductionFixtures.seeded_vector(Float64, ReductionFixtures.N)
    exact = ReductionFixtures.exact_sum(xs)

    @testset "agrees with pairwise_sum_reference (decision 0027)" begin
        for FT in (Float64, Float32)
            terms = ReductionFixtures.seeded_vector(FT, ReductionFixtures.N)
            kernel = Reductions.pairwise_sum(FT, terms)
            reference = Reductions.pairwise_sum_reference(FT, terms)
            tol = Reductions.error_bound(FT, length(terms), ReductionFixtures.term_magnitude(terms))
            @test abs(kernel - reference) <= tol
        end
    end

    @testset "residual against the exact sum is within the declared bound" begin
        result = Reductions.pairwise_sum(Float64, xs)
        tol = Reductions.error_bound(Float64, length(xs), ReductionFixtures.term_magnitude(xs))
        @test abs(result - exact) <= tol
    end

    @testset "the accumulator type is an explicit argument, not eltype(xs)" begin
        terms32 = ReductionFixtures.seeded_vector(Float32, ReductionFixtures.N)
        result64 = Reductions.pairwise_sum(Float64, terms32)
        @test result64 isa Float64
        result32 = Reductions.pairwise_sum(Float32, terms32)
        @test result32 isa Float32
        # Accumulating a Float32 array in Float64 recovers more of the sum
        # than accumulating it in Float32: two different answers from the
        # same xs, which is only possible if the type came from the
        # argument and not from eltype(xs).
        @test Float64(result32) != result64
    end

    @testset "the contract: the sum is a host scalar of the accumulator type" begin
        # notes/findings/2026-09-11-device-scalar-reduction-contract.md
        for FT in (Float64, Float32)
            terms = ReductionFixtures.seeded_vector(FT, ReductionFixtures.N)
            result = Reductions.pairwise_sum(FT, terms, Backends.CPU(8))
            @test result isa FT
            @test !(result isa AbstractArray)
        end

        @testset "positive control: the block sums it is built from are an array" begin
            # Without this the assertions above would also hold of a
            # reduction that returned nothing but its first block sum.
            partials = Reductions.pairwise_block_sums(Float64, xs, Backends.CPU(8))
            @test partials isa AbstractArray
            @test length(partials) == cld(length(xs), Reductions.BLOCKSIZE)
        end
    end

    @testset "block partition invariance: same blocksize, different workgroup" begin
        result_wg4 = Reductions.pairwise_sum(Float64, xs, Backends.CPU(4))
        result_wg16 = Reductions.pairwise_sum(Float64, xs, Backends.CPU(16))
        @test result_wg4 == result_wg16

        @testset "positive control: a smaller blocksize is a different, still valid, partition" begin
            # Not required to be bitwise equal to the declared blocksize's
            # result (a different blocksize is a different tree), only
            # exercised here to show the two calls above were not trivially
            # equal because blocksize was ignored.
            different_blocksize = Reductions.pairwise_sum(Float64, xs, Backends.CPU(4); blocksize = 17)
            @test different_blocksize != result_wg4
        end
    end

    @testset "empty input sums to zero" begin
        @test Reductions.pairwise_sum(Float64, Float64[]) == 0.0
    end

    @testset "refuses a non-positive blocksize" begin
        @test_throws Verdicts.Refusal Reductions.pairwise_sum(Float64, xs; blocksize = 0)
    end
end
