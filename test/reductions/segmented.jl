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
        for s in eachindex(kernel, reference)
            tol = Reductions.error_bound(Float64, starts[s+1] - starts[s], maximum(abs, xs))
            @test abs(kernel[s] - reference[s]) <= tol
        end
    end

    @testset "each segment's sum equals the exact sum of its own slice" begin
        kernel = Reductions.segmented_sum(Float64, xs, starts)
        for s in 1:ReductionFixtures.NSEG
            slice = xs[starts[s]:starts[s+1]-1]
            exact = ReductionFixtures.exact_sum(slice)
            tol = Reductions.error_bound(Float64, length(slice), maximum(abs, slice))
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
        for s in eachindex(kernel, reference)
            n = starts[s+1] - starts[s]
            tol = Reductions.error_bound(Float64, n, maximum(abs, xs)) / minimum(weights)
            @test abs(kernel[s] - reference[s]) <= tol
        end
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
end
