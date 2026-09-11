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

    @testset "validity_limit is 2/eps(T), Higham's n*u <= 1 (eq. 2.6, discussion after eq. 3.11)" begin
        @test Reductions.validity_limit(Float32) == 2.0^24
        @test Reductions.validity_limit(Float64) == 2.0^53
    end

    @testset "refuses a term count at or beyond validity_limit(T), naming T, n and the limit" begin
        limit32 = Int(Reductions.validity_limit(Float32))

        @test_throws Verdicts.Refusal Reductions.error_bound(Float32, limit32, 1.0)
        @test_throws Verdicts.Refusal Reductions.error_bound(Float32, limit32 + 1, 1.0)
        try
            Reductions.error_bound(Float32, limit32, 1.0)
        catch e
            @test e isa Verdicts.Refusal
            @test occursin("Float32", e.reason)
            @test occursin(string(limit32), e.reason)
            @test occursin(string(Int(Reductions.validity_limit(Float32))), e.reason)
        end

        @testset "positive control: the same term count at Float64 does not refuse" begin
            @test Reductions.error_bound(Float64, limit32 + 1, 1.0) isa Float64
        end

        @testset "positive control: one term short of the limit does not refuse" begin
            @test Reductions.error_bound(Float32, limit32 - 1, 1.0) isa Float32
        end
    end
end
