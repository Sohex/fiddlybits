using Test
using Fiddlybits: Reductions, Verdicts

# The reduction error bound: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The reductions", and REQ-NUM-004.

@testset "error_bound (REQ-NUM-004)" begin
    @test Reductions.ERROR_BOUND_K isa Integer
    @test Reductions.ERROR_BOUND_K > 0

    @testset "the declared formula, unmoved for ordinary arguments" begin
        n, magnitude = 37, 4.5
        expected64 = Reductions.ERROR_BOUND_K * n * eps(Float64) * magnitude
        bound64 = Reductions.error_bound(Float64, n, magnitude)
        @test bound64 >= expected64
        @test isapprox(bound64, expected64; rtol = 1e-9)

        expected32 = Reductions.ERROR_BOUND_K * n * eps(Float32) * Float32(magnitude)
        bound32 = Reductions.error_bound(Float32, n, magnitude)
        @test bound32 >= expected32
        @test isapprox(bound32, expected32; rtol = 1e-6)
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

    @testset "refuses when the product is not finite in T, naming T, n and magnitude" begin
        @testset "positive control: a magnitude that overflows Float32 today refuses" begin
            n, magnitude = 10, 1e300
            try
                Reductions.error_bound(Float32, n, magnitude)
                @test false
            catch e
                @test e isa Verdicts.Refusal
                @test occursin("Float32", e.reason)
                @test occursin(string(n), e.reason)
                @test occursin(string(magnitude), e.reason)
            end
        end

        @testset "a finite magnitude of the same shape still returns its bound" begin
            n, magnitude = 10, 1e40
            bound = Reductions.error_bound(Float32, n, magnitude)
            @test isfinite(bound)
            @test bound isa Float32
        end

        @testset "overflow also refuses at Float64, at the term count validity_limit admits" begin
            n = Int(Reductions.validity_limit(Float64)) - 1
            magnitude = floatmax(Float64)
            @test_throws Verdicts.Refusal Reductions.error_bound(Float64, n, magnitude)
        end
    end

    @testset "the returned bound is never less than the exact product" begin
        setprecision(BigFloat, 200) do
            for T in (Float32, Float64)
                limit = Int(Reductions.validity_limit(T)) - 1
                for n in (0, 1, 37, 1000, 65537, 1_000_000, limit)
                    n > limit && continue
                    for magnitude in (0.0, 1e-10, 1.0, 1e5, 1e10)
                        exact = BigFloat(Reductions.ERROR_BOUND_K) * BigFloat(n) *
                                BigFloat(eps(T)) * BigFloat(magnitude)
                        bound = Reductions.error_bound(T, n, magnitude)
                        @test BigFloat(bound) >= exact
                    end
                end
            end
        end
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
