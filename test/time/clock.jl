using Test
using Fiddlybits: Time, Verdicts

# system.time_encode_decode, the clock arm. The orbital-phase and calendar arms read
# Orbit and Render and are run by fiddlybits-52v.5.3 and fiddlybits-52v.5.5; the lint
# arm is lint_calendar in test/lint/.
#
# The bar is the registry's: exact for the integer part, roundoff for the fractional
# part.

module ClockControl
    # The control: a round trip that carries the instant as a single 32-bit float
    # rather than as whole seconds and a remainder. It is the encoding the identity
    # must be able to reject, and it loses the integer part at run lengths this
    # model reaches.
    encode32(seconds::Float64) = Float32(seconds)
    decode32(x::Float32) = Float64(x)
end

"Instants spanning a short run, a long run, and both signs of the epoch offset."
const INSTANTS = (0.0, 0.5, 1.0, -1.5, 3600.25, 1.2345e9, -1.2345e9, 8.64e12 + 0.125)

@testset "Time.clock" begin
    @testset "SimTime and Interval" begin
        t = Time.SimTime(1234.5)
        @test t.seconds == 1234.5
        @test Time.SimTime(1234.5) == t
        @test Time.SimTime(1) isa Time.SimTime{Float64}
        @test t + 0.5 == Time.SimTime(1235.0)
        @test t - 0.5 == Time.SimTime(1234.0)
        @test Time.SimTime(10.0) - Time.SimTime(4.0) == 6.0
        @test Time.SimTime(1.0) < Time.SimTime(2.0)

        i = Time.Interval(100.0, 400.0)
        @test Time.duration(i) == 300.0
        @test i == Time.Interval(Time.SimTime(100.0), Time.SimTime(400.0))
    end

    @testset "an interval is half-open in both directions" begin
        i = Time.Interval(100.0, 400.0)
        @test Time.SimTime(100.0) in i
        @test Time.SimTime(399.999) in i
        @test !(Time.SimTime(400.0) in i)
        @test !(Time.SimTime(99.999) in i)
    end

    @testset "an interval with no positive duration is refused" begin
        @test_throws Verdicts.Refusal Time.Interval(400.0, 100.0)
        @test_throws Verdicts.Refusal Time.Interval(100.0, 100.0)
        @test_throws Verdicts.Refusal Time.Interval(0.0, Inf)
        @test_throws Verdicts.Refusal Time.Interval(NaN, 1.0)

        # The refusal names both bounds rather than only the fact of the refusal.
        refusal = try
            Time.Interval(400.0, 100.0)
        catch e
            e
        end
        @test occursin("400.0", refusal.reason) && occursin("100.0", refusal.reason)
    end

    @testset "system.time_encode_decode: the round trip" begin
        for seconds in INSTANTS
            t = Time.SimTime(seconds)
            whole, fraction = Time.encode(t)

            @test whole == Int64(floor(seconds))
            @test 0.0 <= fraction < 1.0

            back = Time.decode(whole, fraction)
            @test Int64(floor(back.seconds)) == whole
            @test abs(back.seconds - seconds) <= 8 * eps(abs(seconds) + 1.0)
        end
    end

    @testset "system.time_encode_decode: encode is the inverse of decode" begin
        for seconds in INSTANTS
            whole, fraction = Time.encode(Time.SimTime(seconds))
            again = Time.encode(Time.decode(whole, fraction))
            @test again[1] == whole
            @test abs(again[2] - fraction) <= 8 * eps(1.0)
        end
    end

    @testset "system.time_encode_decode: the positive control fires" begin
        # A run of some forty years in seconds. The pair encoding returns its integer
        # part exactly; the single-float control does not, which is what makes the
        # identity a check rather than a restatement.
        seconds = 1.2345e9
        whole, fraction = Time.encode(Time.SimTime(seconds))
        @test Int64(floor(Time.decode(whole, fraction).seconds)) == Int64(floor(seconds))

        control = ClockControl.decode32(ClockControl.encode32(seconds))
        @test Int64(floor(control)) != Int64(floor(seconds))
    end

    @testset "an instant encode cannot carry is refused" begin
        @test_throws Verdicts.Refusal Time.encode(Time.SimTime(Inf))
        @test_throws Verdicts.Refusal Time.encode(Time.SimTime(NaN))
        @test_throws Verdicts.Refusal Time.encode(Time.SimTime(1.0e30))
        @test_throws Verdicts.Refusal Time.decode(1, 1.0)
        @test_throws Verdicts.Refusal Time.decode(1, -0.25)
        @test_throws Verdicts.Refusal Time.decode(1, NaN)
        @test_throws Verdicts.Refusal Time.decode(typemin(Int64), 0.0)
    end
end
