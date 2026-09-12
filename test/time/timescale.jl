using Test
using Fiddlybits: Time, Verdicts

# system.damping_in_rotations. The registry's statistic: a timescale declared in
# rotations yields the same per-step damping fraction per rotation at two declared
# rotation periods, and a timescale declared in seconds yields the same fraction per
# second. The bar is roundoff.
#
# The rotation periods below are two arbitrary declarations. The identity is that the
# answer does not move between them, so the numbers themselves carry no meaning
# beyond being different.

module RotationControl
    # The control: a timescale in rotations read through a rotation period fixed in
    # the code rather than taken from the declaration. It is what the rule forbids,
    # and at two declared periods it must give two different answers.
    const FIXED_PERIOD = 90000.0

    damping(rotations, elapsed, _declared_period) =
        exp(-(elapsed / FIXED_PERIOD) / rotations)
end

const PERIOD_A = 51234.5
const PERIOD_B = 119000.0
const ROTATIONS_ELAPSED = (0.25, 1.0, 3.0, 12.0)

@testset "Time.timescale" begin
    @testset "system.damping_in_rotations: the same fraction per rotation" begin
        ts = Time.InRotations(5.0)
        for n in ROTATIONS_ELAPSED
            a = Time.damping(ts, n * PERIOD_A, PERIOD_A)
            b = Time.damping(ts, n * PERIOD_B, PERIOD_B)
            @test a == b
            @test a ≈ exp(-n / 5.0) rtol = 8 * eps(1.0)
        end
    end

    @testset "system.damping_in_rotations: the same fraction per second" begin
        ts = Time.InSeconds(600.0)
        for elapsed in (150.0, 600.0, 1800.0)
            @test Time.damping(ts, elapsed) ≈ exp(-elapsed / 600.0) rtol = 8 * eps(1.0)
        end
    end

    @testset "system.damping_in_rotations: the positive control fires" begin
        # Two declared rotation periods, the same elapsed time in rotations. The
        # declaration holds; the version carrying a period fixed in the code does
        # not, which is the failure the two timescale types prevent.
        ts = Time.InRotations(5.0)
        @test Time.damping(ts, 1.0 * PERIOD_A, PERIOD_A) ==
              Time.damping(ts, 1.0 * PERIOD_B, PERIOD_B)
        @test RotationControl.damping(5.0, 1.0 * PERIOD_A, PERIOD_A) !=
              RotationControl.damping(5.0, 1.0 * PERIOD_B, PERIOD_B)
    end

    @testset "the two declarations are different declarations" begin
        @test Time.InRotations(5.0) isa Time.Timescale
        @test Time.InSeconds(5.0) isa Time.Timescale
        @test typeof(Time.InRotations(5.0)) !== typeof(Time.InSeconds(5.0))

        # Neither reads as the other: a rotations timescale needs the period, and a
        # seconds timescale refuses one.
        @test_throws Verdicts.Refusal Time.damping(Time.InRotations(5.0), 100.0)
        @test_throws Verdicts.Refusal Time.damping(Time.InSeconds(5.0), 100.0, PERIOD_A)
    end

    @testset "a timescale that is not positive and finite is refused" begin
        @test_throws Verdicts.Refusal Time.InRotations(0.0)
        @test_throws Verdicts.Refusal Time.InRotations(-1.0)
        @test_throws Verdicts.Refusal Time.InRotations(Inf)
        @test_throws Verdicts.Refusal Time.InSeconds(0.0)
        @test_throws Verdicts.Refusal Time.InSeconds(NaN)
    end

    @testset "an inadmissible reading is refused" begin
        @test_throws Verdicts.Refusal Time.damping(Time.InSeconds(10.0), -1.0)
        @test_throws Verdicts.Refusal Time.damping(Time.InRotations(10.0), -1.0, PERIOD_A)
        @test_throws Verdicts.Refusal Time.damping(Time.InRotations(10.0), 1.0, 0.0)
        @test_throws Verdicts.Refusal Time.damping(Time.InRotations(10.0), 1.0, Inf)
    end
end
