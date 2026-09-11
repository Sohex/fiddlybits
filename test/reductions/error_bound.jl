using Test
using Fiddlybits: Reductions, Verdicts

# The reduction error bound: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The reductions", and REQ-NUM-004.

@testset "error_bound (REQ-NUM-004)" begin
    @test Reductions.ERROR_BOUND_K isa Integer
    @test Reductions.ERROR_BOUND_K > 0

    @testset "the declared formula" begin
        n, magnitude = 37, 4.5
        expected = Reductions.ERROR_BOUND_K * n * eps(Float64) * magnitude
        @test Reductions.error_bound(Float64, n, magnitude) == expected
        @test Reductions.error_bound(Float32, n, magnitude) ==
              Reductions.ERROR_BOUND_K * n * eps(Float32) * Float32(magnitude)
    end

    @testset "refuses a negative term count or magnitude" begin
        @test_throws Verdicts.Refusal Reductions.error_bound(Float64, -1, 1.0)
        @test_throws Verdicts.Refusal Reductions.error_bound(Float64, 1, -1.0)

        @testset "positive control: a non-negative call does not refuse" begin
            @test Reductions.error_bound(Float64, 0, 0.0) == 0.0
        end
    end
end
