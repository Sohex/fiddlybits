using Test
using Fiddlybits: Reductions, Backends, Verdicts

# Segmented sums and means: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The reductions", and decision 0027 (reference path).

@testset "segmented_sum and segmented_mean" begin
    xs = ReductionFixtures.seeded_vector(Float64, ReductionFixtures.N)
    starts = ReductionFixtures.segment_starts(ReductionFixtures.N, ReductionFixtures.NSEG)
    weights = abs.(xs) .+ 0.1

    @testset "segmented_sum agrees with segmented_sum_reference (decision 0027)" begin
        kernel = Reductions.segmented_sum(Float64, xs, starts)
        reference = Reductions.segmented_sum_reference(Float64, xs, starts)
        @test length(kernel) == ReductionFixtures.NSEG
        # The kernel and the reference perform the identical fixed-order
        # per-segment accumulation, so the observed agreement is exact.
        @test kernel == reference
    end

    @testset "each segment's sum equals the exact sum of its own slice" begin
        kernel = Reductions.segmented_sum(Float64, xs, starts)
        for s in 1:ReductionFixtures.NSEG
            slice = xs[starts[s]:starts[s+1]-1]
            exact = ReductionFixtures.exact_sum(slice)
            tol = Reductions.error_bound(Float64, length(slice), ReductionFixtures.term_magnitude(slice))
            @test abs(kernel[s] - exact) <= tol
        end
    end

    @testset "block partition invariance: same boundaries, different workgroup" begin
        result_wg4 = Reductions.segmented_sum(Float64, xs, starts, Backends.CPU(4))
        result_wg16 = Reductions.segmented_sum(Float64, xs, starts, Backends.CPU(16))
        @test result_wg4 == result_wg16
    end

    @testset "segmented_mean agrees with segmented_mean_reference (decision 0027)" begin
        kernel = Reductions.segmented_mean(Float64, xs, starts, weights)
        reference = Reductions.segmented_mean_reference(Float64, xs, starts, weights)
        # Both a weighted numerator and a weight total accumulated in the
        # identical fixed order, divided by the identical operation, so the
        # observed agreement is exact.
        @test kernel == reference
    end

    @testset "refuses boundaries that do not describe xs" begin
        @test_throws Verdicts.Refusal Reductions.segmented_sum(Float64, xs, [2, ReductionFixtures.N + 1])
        @test_throws Verdicts.Refusal Reductions.segmented_sum(Float64, xs, [1, ReductionFixtures.N])
        @test_throws Verdicts.Refusal Reductions.segmented_sum(Float64, xs, [1, 10, 5, ReductionFixtures.N + 1])

        @testset "positive control: the fixture's own boundaries do not refuse" begin
            @test Reductions.segmented_sum(Float64, xs, starts) isa AbstractVector
        end
    end

    @testset "refuses a zero-weight segment" begin
        zero_weights = zeros(length(xs))
        @test_throws Verdicts.Refusal Reductions.segmented_mean(Float64, xs, starts, zero_weights)
        @test_throws Verdicts.Refusal Reductions.segmented_mean_reference(Float64, xs, starts, zero_weights)
    end

    @testset "a Segmentation reduces to the same answers as its boundary array" begin
        segmentation = Reductions.Segmentation(xs, starts)
        @test segmentation.nseg == ReductionFixtures.NSEG
        @test segmentation.nelement == ReductionFixtures.N

        @test Reductions.segmented_sum(Float64, xs, segmentation) ==
              Reductions.segmented_sum(Float64, xs, starts)
        @test Reductions.segmented_sum(Float64, xs, segmentation) ==
              Reductions.segmented_sum_reference(Float64, xs, segmentation)
        @test Reductions.segmented_mean(Float64, xs, segmentation, weights) ==
              Reductions.segmented_mean(Float64, xs, starts, weights)
        @test Reductions.segmented_mean(Float64, xs, segmentation, weights) ==
              Reductions.segmented_mean_reference(Float64, xs, segmentation, weights)

        @testset "block partition invariance through a Segmentation" begin
            @test Reductions.segmented_sum(Float64, xs, segmentation, Backends.CPU(4)) ==
                  Reductions.segmented_sum(Float64, xs, segmentation, Backends.CPU(16))
        end

        @testset "a zero-weight segment is still refused through a Segmentation" begin
            zero_weights = zeros(length(xs))
            @test_throws Verdicts.Refusal Reductions.segmented_mean(Float64, xs, segmentation, zero_weights)
            @test_throws Verdicts.Refusal Reductions.segmented_mean_reference(Float64, xs, segmentation, zero_weights)
        end
    end

    @testset "a malformed boundary array is refused when a Segmentation is built from it" begin
        @test_throws Verdicts.Refusal Reductions.Segmentation(xs, Int[])
        @test_throws Verdicts.Refusal Reductions.Segmentation(xs, [2, ReductionFixtures.N + 1])
        @test_throws Verdicts.Refusal Reductions.Segmentation(xs, [1, ReductionFixtures.N])
        @test_throws Verdicts.Refusal Reductions.Segmentation(xs, [1, 10, 5, ReductionFixtures.N + 1])

        @testset "positive control: the fixture's own boundaries build one" begin
            @test Reductions.Segmentation(xs, starts) isa Reductions.Segmentation
        end

        @testset "refused on the first call and on every call after it" begin
            bad = [1, 10, 5, ReductionFixtures.N + 1]
            for _ in 1:3
                @test_throws Verdicts.Refusal Reductions.segmented_sum(Float64, xs, bad)
            end
        end
    end

    @testset "a Segmentation refuses an xs of a length it was not checked against" begin
        segmentation = Reductions.Segmentation(xs, starts)
        shorter = xs[1:(ReductionFixtures.N - 1)]
        @test_throws Verdicts.Refusal Reductions.segmented_sum(Float64, shorter, segmentation)
        @test_throws Verdicts.Refusal Reductions.segmented_sum_reference(Float64, shorter, segmentation)
        @test_throws Verdicts.Refusal Reductions.segmented_mean(Float64, shorter, segmentation, weights[1:end-1])
        @test_throws Verdicts.Refusal Reductions.segmented_mean_reference(Float64, shorter, segmentation, weights[1:end-1])

        @testset "positive control: the length it was checked against does not refuse" begin
            @test Reductions.segmented_sum(Float64, xs, segmentation) isa AbstractVector
        end
    end

    @testset "a Segmentation holds its own copies of what it checked" begin
        mutable_starts = copy(starts)
        segmentation = Reductions.Segmentation(xs, mutable_starts)
        expected = Reductions.segmented_sum(Float64, xs, segmentation)

        mutable_starts[2] = mutable_starts[3]
        @test Reductions.segmented_sum(Float64, xs, segmentation) == expected

        @testset "positive control: the mutated array itself reduces differently" begin
            mutated = Reductions.segmented_sum(Float64, xs, mutable_starts)
            @test expected[2] != 0.0
            @test mutated[2] == 0.0
            @test mutated != expected
        end
    end
end
