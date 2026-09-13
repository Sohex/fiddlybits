using Test
using Random
using Fiddlybits: Fields, Reductions
using Fiddlybits.Verdicts: Refusal

# ledger.closure: docs/oracles/registry.toml and
# docs/plans/fiddlybits-52v.3-fields.md, section "Ledgers", row 52v.3.6.

const L = Fields

raised(thunk) = try
    thunk()
catch e
    e
end

@testset "Fields.Ledger" begin
    @testset "an exactly closing ledger has a zero residual and is closed" begin
        l = L.Ledger{:mass}(Float64, 3, 100.0, 100.0, 100.0, 0.0; reservoir = false)
        @test L.quantity(l) === :mass
        @test L.residual(l) == 0.0
        @test L.closed(l)
    end

    @testset "positive control: a residual larger than the tolerance is open" begin
        l = L.Ledger{:mass}(Float64, 3, 100.0, 100.0, 100.0, 0.5; reservoir = false)
        @test L.residual(l) == -0.5
        @test !L.closed(l)
    end

    @testset "named losses enter the residual with the opposite sign from flux" begin
        l = L.Ledger{:water}(Float64, 4, 20.0, 10.0, 9.0, 0.0, (evaporation = 1.0,);
                             reservoir = false)
        @test L.residual(l) == 0.0
        @test L.losses(l) == (evaporation = 1.0,)
        @test L.closed(l)

        under = L.Ledger{:water}(Float64, 4, 20.0, 10.0, 9.0, 0.0,
                                 (evaporation = 0.7,); reservoir = false)
        @test L.residual(under) ≈ -0.3
        @test !L.closed(under)
    end

    @testset "the tolerance is read from Reductions, not declared here" begin
        for (n, magnitude) in ((3, 10.0), (5, 1.0e6))
            l = L.Ledger{:energy}(Float64, n, magnitude, magnitude, magnitude, 0.0;
                                  reservoir = false)
            expected = Float64(Reductions.error_bound(Float64, n, magnitude))
            @test L.tolerance(l) == expected
        end

        small = L.Ledger{:energy}(Float64, 3, 10.0, 10.0, 10.0, 0.0; reservoir = false)
        large = L.Ledger{:energy}(Float64, 3, 1.0e6, 1.0e6, 1.0e6, 0.0;
                                  reservoir = false)
        @test L.tolerance(large) > L.tolerance(small)
        @test L.tolerance(large) == Float64(Reductions.error_bound(Float64, 3, 1.0e6))
    end

    @testset "an FP32 accumulator for a declared reservoir refuses naming the quantity" begin
        err = raised(() -> L.Ledger{:soil_carbon}(Float32, 3, 1.0f0, 1.0f0, 1.0f0,
                                                  0.0f0; reservoir = true))
        @test err isa Refusal
        @test err.site == "Fields.Ledger"
        @test occursin("soil_carbon", err.reason)
        @test occursin("reservoir", err.reason)
    end

    @testset "control: a non-reservoir at FP32 is accepted" begin
        l = L.Ledger{:surface_soil_moisture}(Float32, 3, 1.0f0, 1.0f0, 1.0f0, 0.0f0;
                                             reservoir = false)
        @test l isa L.Ledger{:surface_soil_moisture}
        @test L.closed(l)
    end

    @testset "a declared reservoir at Float64 is accepted" begin
        l = L.Ledger{:soil_carbon}(Float64, 3, 100.0, 100.0, 100.0, 0.0;
                                   reservoir = true)
        @test l isa L.Ledger{:soil_carbon}
    end

    @testset "every field returns a concrete type" begin
        @test @inferred(L.Ledger{:mass}(Float64, 3, 1.0, 1.0, 1.0, 0.0;
                                        reservoir = false)) isa L.Ledger{:mass}
        l = L.Ledger{:mass}(Float64, 3, 1.0, 1.0, 1.0, 0.0; reservoir = false)
        @test @inferred(L.closed(l)) isa Bool
        @test @inferred(L.residual(l)) isa Float64
        @test @inferred(L.tolerance(l)) isa Float64
        @test @inferred(L.quantity(l)) === :mass
    end

    @testset "the losses field is concretely typed" begin
        l = L.Ledger{:water}(Float64, 4, 20.0, 10.0, 9.0, 0.0, (evaporation = 1.0,);
                             reservoir = false)
        @test isconcretetype(fieldtype(typeof(l), :losses))
        @test isconcretetype(typeof(l))
    end
end

"""
    old_slope_against_tolerance_classify(windows, residuals, tolerances)

The pre-review `Fields.classify`: `Leak` when the least-squares slope of `residuals`
against `windows`, times the window span, exceeds the largest of `tolerances`;
otherwise `StockOmission` when the mean residual exceeds the mean tolerance;
otherwise `Rounding`. Kept only to show that the new tests below fail on it.
"""
function old_slope_against_tolerance_classify(windows, residuals, tolerances)
    _, slope = Fields.linear_fit(windows, residuals)
    span = maximum(windows) - minimum(windows)
    growth = abs(slope) * span
    growth > maximum(tolerances) && return Fields.Leak()
    sum(abs, residuals) / length(residuals) > sum(tolerances) / length(tolerances) &&
        return Fields.StockOmission()
    return Fields.Rounding()
end

@testset "Fields.classify" begin
    @testset "the review's two adversarial series" begin
        # docs/requirements/num/closure-tolerance-from-floating-point.md, REQ-NUM-004
        # item 3. Every ledger here is closed (residuals within one tolerance unit)
        # or, for the second series, an omission far past it; neither grows with the
        # window, which the least-squares fit alone cannot see through the noise, and
        # which is exactly what made the old rule call both series Leak.
        windows = [10.0, 100.0, 500.0, 1200.0]
        tolerances = fill(1.0, 4)

        rounding_like = [-0.9, -0.5, 0.5, 0.9]
        @test old_slope_against_tolerance_classify(windows, rounding_like,
                                                    tolerances) == L.Leak()
        @test L.classify(windows, rounding_like, tolerances) == L.Rounding()

        stock_omission_like = [4.1, 5.2, 4.7, 5.9]
        @test old_slope_against_tolerance_classify(windows, stock_omission_like,
                                                    tolerances) == L.Leak()
        @test L.classify(windows, stock_omission_like, tolerances) ==
              L.StockOmission()
    end

    @testset "seeded synthetic series of each class" begin
        windows = [10.0, 210.0, 410.0, 610.0, 810.0]
        tolerances = fill(1.0, length(windows))

        @testset "rounding noise classifies Rounding, not Leak" begin
            for seed in (1, 2, 3)
                rng = Random.Xoshiro(seed)
                residuals = 0.3 .* randn(rng, length(windows))
                @test all(<=(1.0), abs.(residuals))
                @test L.classify(windows, residuals, tolerances) == L.Rounding()
            end
        end

        @testset "a leak under one tolerance unit at the shortest window" begin
            # the easy wrong answer at the shortest window alone is Rounding; only
            # the growth across the whole ladder reveals it.
            rate = 0.9 / windows[1]
            for seed in (1, 2, 3)
                rng = Random.Xoshiro(seed)
                noise = 0.15 .* randn(rng, length(windows))
                residuals = rate .* windows .+ noise
                @test abs(residuals[1]) < tolerances[1]
                @test L.classify(windows, residuals, tolerances) == L.Leak()
            end
        end

        @testset "a stock omission carrying rounding noise" begin
            # the easy wrong answer is Leak, since the offset sits far past
            # tolerance; only its flatness against the window rules that out.
            offset = 5.0
            for seed in (1, 2, 3)
                rng = Random.Xoshiro(seed)
                noise = 0.3 .* randn(rng, length(windows))
                residuals = fill(offset, length(windows)) .+ noise
                @test L.classify(windows, residuals, tolerances) == L.StockOmission()
            end
        end
    end

    @testset "classify refuses mismatched lengths, non-increasing and too few windows" begin
        err = raised(() -> L.classify([1.0, 2.0], [0.0, 0.0, 0.0], [1.0, 1.0, 1.0]))
        @test err isa Refusal
        @test err.site == "Fields.classify"

        err = raised(() -> L.classify([1.0, 2.0, 2.0, 3.0], fill(0.0, 4), fill(1.0, 4)))
        @test err isa Refusal
        @test occursin("increasing", err.reason)

        err = raised(() -> L.classify([1.0, 3.0, 2.0, 4.0], fill(0.0, 4), fill(1.0, 4)))
        @test err isa Refusal
        @test occursin("increasing", err.reason)

        err = raised(() -> L.classify([1.0, 2.0, 3.0], fill(0.0, 3), fill(1.0, 3)))
        @test err isa Refusal
        @test occursin("4", err.reason)
    end

    @testset "lag1_autocorrelation refuses fewer than 4 values" begin
        err = raised(() -> L.lag1_autocorrelation([1.0, 2.0, 3.0]))
        @test err isa Refusal
        @test err.site == "Fields.lag1_autocorrelation"
    end

    @testset "linear_fit refuses windows that are not all distinct" begin
        err = raised(() -> L.linear_fit([1.0, 1.0, 1.0], [1.0, 2.0, 3.0]))
        @test err isa Refusal
        @test err.site == "Fields.linear_fit"
    end

    @testset "residual_signatures enumerates the closed set" begin
        @test L.residual_signatures() == (L.Leak(), L.StockOmission(), L.Rounding())
    end

    @testset "classify infers a concrete return type" begin
        rt = Base.return_types(L.classify,
                               (Vector{Float64}, Vector{Float64}, Vector{Float64}))
        @test length(rt) == 1
        @test rt[1] <: L.ResidualSignature
        @test rt[1] != Any
    end
end
