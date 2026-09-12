using Test
using Fiddlybits: Time, Verdicts

# A TimeSupport is admissible only in the shape its semantics declares, and a
# mismatch is a refusal naming the semantics rather than a default.

@testset "Time.support" begin
    span = Time.Interval(100.0, 400.0)
    instant = Time.SimTime(250.0)

    @testset "each semantics takes the shape it declares" begin
        static = Time.TimeSupport(Time.Static())
        @test Time.semantics(static) === Time.Static()

        sampled = Time.TimeSupport(Time.Instantaneous(), instant)
        @test Time.instant(sampled) == instant

        for s in (Time.IntervalMean(), Time.IntervalAccumulation(), Time.EndpointState())
            ts = Time.TimeSupport(s, span)
            @test Time.interval(ts) == span
            @test Time.duration(ts) == 300.0
        end
    end

    @testset "a shape the semantics does not declare is refused" begin
        @test_throws Verdicts.Refusal Time.TimeSupport(Time.Static(), span)
        @test_throws Verdicts.Refusal Time.TimeSupport(Time.Static(), instant)
        @test_throws Verdicts.Refusal Time.TimeSupport(Time.Instantaneous())
        @test_throws Verdicts.Refusal Time.TimeSupport(Time.Instantaneous(), span)
        @test_throws Verdicts.Refusal Time.TimeSupport(Time.IntervalMean())
        @test_throws Verdicts.Refusal Time.TimeSupport(Time.IntervalMean(), instant)

        refusal = try
            Time.TimeSupport(Time.Static(), span)
        catch e
            e
        end
        @test occursin("Static", refusal.reason)
    end

    @testset "a reading the semantics does not carry is refused" begin
        static = Time.TimeSupport(Time.Static())
        sampled = Time.TimeSupport(Time.Instantaneous(), instant)
        mean = Time.TimeSupport(Time.IntervalMean(), span)

        @test_throws Verdicts.Refusal Time.interval(static)
        @test_throws Verdicts.Refusal Time.instant(static)
        @test_throws Verdicts.Refusal Time.interval(sampled)
        @test_throws Verdicts.Refusal Time.instant(mean)
        @test_throws Verdicts.Refusal Time.duration(static)
        @test_throws Verdicts.Refusal Time.duration(sampled)
    end

    @testset "the inner constructor is not a way round the shape check" begin
        @test_throws Verdicts.Refusal Time.TimeSupport{Time.Static,typeof(span)}(
            Time.Static(), span)
        @test_throws Verdicts.Refusal Time.TimeSupport{Time.IntervalMean,Nothing}(
            Time.IntervalMean(), nothing)
        @test_throws Verdicts.Refusal Time.TimeSupport(Time.IntervalMean(), 7)
    end

    @testset "the semantics travels in the type" begin
        mean = Time.TimeSupport(Time.IntervalMean(), span)
        accumulation = Time.TimeSupport(Time.IntervalAccumulation(), span)
        @test typeof(mean) !== typeof(accumulation)
        @test mean != accumulation
    end
end
