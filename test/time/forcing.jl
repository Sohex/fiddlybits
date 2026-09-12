using Test
using Fiddlybits: Time, Verdicts

# A forcing list is contiguous and non-overlapping, checked at construction. The gap
# and the overlap are the two refusals the row names, each reported with the pair of
# intervals that carries it.
#
# The spacings below are arbitrary numbers of seconds and are not a cadence
# enumeration: the same constructor builds all three (decision 0008).

@testset "Time.forcing" begin
    @testset "a contiguous list is accepted and read back" begin
        f = Time.Forcing([Time.Interval(0.0, 10.0),
                          Time.Interval(10.0, 25.0),
                          Time.Interval(25.0, 30.0)],
                         [:a, :b, :c])
        @test length(f) == 3
        @test Time.span(f) == Time.Interval(0.0, 30.0)
        @test f[2] == (Time.Interval(10.0, 25.0), :b)
        @test Time.at(f, Time.SimTime(0.0)) === :a
        @test Time.at(f, Time.SimTime(9.999)) === :a
        @test Time.at(f, Time.SimTime(10.0)) === :b
        @test Time.at(f, Time.SimTime(24.999)) === :b
        @test Time.at(f, Time.SimTime(25.0)) === :c
    end

    @testset "a gap is refused, naming the pair" begin
        refusal = try
            Time.Forcing([Time.Interval(0.0, 10.0), Time.Interval(12.0, 25.0)], [:a, :b])
        catch e
            e
        end
        @test refusal isa Verdicts.Refusal
        @test occursin("gap", refusal.reason)
        @test occursin("10.0", refusal.reason) && occursin("12.0", refusal.reason)
    end

    @testset "an overlap is refused, naming the pair" begin
        refusal = try
            Time.Forcing([Time.Interval(0.0, 10.0), Time.Interval(8.0, 25.0)], [:a, :b])
        catch e
            e
        end
        @test refusal isa Verdicts.Refusal
        @test occursin("overlap", refusal.reason)
        @test occursin("10.0", refusal.reason) && occursin("8.0", refusal.reason)
    end

    @testset "a malformed list is refused" begin
        @test_throws Verdicts.Refusal Time.Forcing([Time.Interval(0.0, 10.0)], [:a, :b])
        @test_throws Verdicts.Refusal Time.Forcing(Time.Interval{Float64}[], Symbol[])
    end

    @testset "one instant belongs to one interval" begin
        f = Time.uniform_forcing(Time.SimTime(0.0), 7.0, collect(1:5))
        for k in eachindex(f)
            span, value = f[k]
            @test Time.at(f, span.t0) == value
            @test Time.index_at(f, span.t0) == k
        end
    end

    @testset "the binary search agrees with the reference path" begin
        f = Time.uniform_forcing(Time.SimTime(-500.0), 3.25, collect(1:64))
        s = Time.span(f)
        for x in range(s.t0.seconds, s.t1.seconds - 1e-6, length = 400)
            t = Time.SimTime(x)
            @test Time.index_at(f, t) == Time.index_at_reference(f, t)
        end
    end

    @testset "an instant outside the declared span is refused" begin
        f = Time.uniform_forcing(Time.SimTime(0.0), 10.0, [:a, :b])
        @test_throws Verdicts.Refusal Time.at(f, Time.SimTime(-0.001))
        @test_throws Verdicts.Refusal Time.at(f, Time.SimTime(20.0))
        @test_throws Verdicts.Refusal Time.index_at_reference(f, Time.SimTime(20.0))
    end

    @testset "three spacings are the same code path" begin
        # One at a declared rotation period, one at thirty hours, one at a timestep.
        # Nothing in the constructor or the lookup distinguishes them.
        for step in (51234.5, 108000.0, 450.0)
            f = Time.uniform_forcing(Time.SimTime(0.0), step, collect(1:9))
            @test length(f) == 9
            @test Time.duration(Time.span(f)) ≈ 9 * step
            @test Time.at(f, Time.SimTime(step * 4.5)) == 5
        end
    end

    @testset "uniform_forcing builds exact boundaries" begin
        f = Time.uniform_forcing(Time.SimTime(0.0), 0.1, collect(1:1000))
        for k in 2:length(f)
            @test f[k][1].t0.seconds === f[k - 1][1].t1.seconds
        end
    end

    @testset "a malformed uniform list is refused" begin
        @test_throws Verdicts.Refusal Time.uniform_forcing(Time.SimTime(0.0), 0.0, [:a])
        @test_throws Verdicts.Refusal Time.uniform_forcing(Time.SimTime(0.0), -1.0, [:a])
        @test_throws Verdicts.Refusal Time.uniform_forcing(Time.SimTime(0.0), 1.0, Symbol[])
    end
end
