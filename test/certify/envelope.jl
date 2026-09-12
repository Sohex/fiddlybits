using Test
using Fiddlybits: Backends, Verdicts

# The ulp-ensemble envelope and the refusals that keep an unmeasurable case out
# of the verdict vocabulary: docs/plans/fiddlybits-52v.7-kernels.md, section
# "Certification", and decision 0029.
#
# The perturbation amplitude and the injection step are checked here against the
# one case whose right answer is known without an envelope: a linear stationary
# step, whose propagator has an operator one norm the envelope must reproduce
# and whose gains must not depend on the step an error is injected at. The
# measurements behind both are in
# notes/findings/2026-09-12-ulp-ensemble-amplitude-and-injection-step.md.

@testset "envelope" begin
    @testset "the stand-in case" begin
        @test CASE_ENVELOPE.case == CASE.name
        @test CASE_ENVELOPE.steps == CertifyFixtures.STEPS
        @test CASE_ENVELOPE.precision === Float32
        @test size(CASE_ENVELOPE.amplification) ==
              (CertifyFixtures.STEPS, CertifyFixtures.STEPS)
        @test all(isfinite, CASE_ENVELOPE.amplification)

        @testset "a gain is measured at and above the step it is injected at" begin
            for j in 0:(CertifyFixtures.STEPS - 1)
                @test Backends.gain(CASE_ENVELOPE, j, j) == 1
                for s in 1:j
                    @test CASE_ENVELOPE.amplification[j + 1, s] == 0
                end
                for s in (j + 1):CertifyFixtures.STEPS
                    @test CASE_ENVELOPE.amplification[j + 1, s] > 0
                end
            end
        end
    end

    @testset "the same case measures the same envelope, bit for bit" begin
        again = Backends.envelope(CASE, CertifyFixtures.STEPS, Float32)
        @test again.amplification == CASE_ENVELOPE.amplification
        @test again.members == CASE_ENVELOPE.members
    end

    @testset "a case with fewer sites than the member count is exhaustive" begin
        small = Backends.envelope(CertifyFixtures.small_case(), 4, Float32)
        @test small.sites < Backends.ENSEMBLE_MEMBERS
        @test small.members == small.sites
        @test small.exhaustive
        @test small.miss_rate == 0
    end

    @testset "certify.unmeasurable_envelope_refuses" begin
        @testset "a case that does not propagate a one-ulp perturbation" begin
            constant = CertifyFixtures.constant_case()
            @test_throws Verdicts.Refusal Backends.envelope(constant, 4, Float32)
            caught = try
                Backends.envelope(constant, 4, Float32)
            catch e
                e
            end
            @test caught isa Verdicts.Refusal
            @test !(caught isa Verdicts.OracleVerdict)
            @test occursin("constant", caught.reason)
            @test occursin("zero divergence", caught.reason) ||
                  occursin("identical to the reference", caught.reason)
            @test occursin("not measurable", caught.reason)

            @testset "positive control: the stand-in case does not refuse" begin
                @test Backends.envelope(CASE, 1, Float32) isa Backends.Envelope
            end
        end

        @testset "a case with no field an ulp can be taken of" begin
            caught = try
                Backends.envelope(CertifyFixtures.zero_case(), 4, Float32)
            catch e
                e
            end
            @test caught isa Verdicts.Refusal
            @test caught.quantity == "ulp-ensemble perturbation site"
            @test occursin("no field holds a finite nonzero normal scale", caught.reason)
        end

        @testset "a step count that is not positive" begin
            caught = try
                Backends.envelope(CASE, 0, Float32)
            catch e
                e
            end
            @test caught isa Verdicts.Refusal
            @test occursin("step count 0", caught.reason)

            @testset "positive control: one step is measurable" begin
                @test Backends.envelope(CASE, 1, Float32).steps == 1
            end
        end

        @testset "a trajectory that leaves the finite range names the step" begin
            doubling = CertifyFixtures.doubling_case()
            caught = try
                Backends.envelope(doubling, 1100, Float32)
            catch e
                e
            end
            @test caught isa Verdicts.Refusal
            @test occursin("cannot be measured", caught.reason)
            @test occursin("Inf", caught.reason)

            @testset "positive control: the same case inside the finite range is measurable" begin
                @test Backends.envelope(doubling, 8, Float32) isa Backends.Envelope
            end
        end
    end

    @testset "certify.linear_case_envelope_is_the_operator_one_norm" begin
        # The stand-in's step is a fixed gather and a fixed rotation, so it is
        # linear and stationary and its envelope has a right answer that can be
        # read without an envelope. Why that answer is the operator one norm, and
        # why the amplitude decides whether the envelope reaches it, are in
        # notes/findings/2026-09-12-ulp-ensemble-amplitude-and-injection-step.md.
        linear = CertifyFixtures.small_case()
        steps = 6
        env = Backends.envelope(linear, steps, Float32)
        @test env.exhaustive
        norms = CertifyFixtures.operator_one_norms(linear, steps, 1.0e-6)

        # The tolerance covers the Float64 rounding of the two trajectories
        # divided by the smaller of the two perturbations; the control below is
        # out by more than the factor its own assertion names.
        @testset "the envelope reproduces the norm at one Float32 ulp" begin
            for s in 1:steps
                @test isapprox(env.amplification[1, s], norms[s]; rtol = 1.0e-6)
            end
        end

        @testset "and its gains do not depend on the injection step" begin
            for j in 0:(steps - 1), s in (j + 1):steps
                @test isapprox(env.amplification[j + 1, s], env.amplification[1, s - j];
                               rtol = 1.0e-6)
            end
        end

        @testset "positive control: at one Float64 ulp neither holds" begin
            coarse = Backends.envelope(linear, steps, Float64)
            @test all(coarse.amplification[1, s] > 2 * norms[s] for s in 1:steps)
            @test any(!isapprox(coarse.amplification[j + 1, s],
                                coarse.amplification[1, s - j]; rtol = 1.0e-6)
                      for j in 0:(steps - 1) for s in (j + 1):steps)
        end
    end

    @testset "certify.envelope_does_not_depend_on_its_partition" begin
        # Decision 0029: arrival order never reaches a result. measure_envelope runs
        # one task per injection step, and this compares what it produced against the
        # same rows built one at a time in this task.
        case = CertifyFixtures.small_case()
        steps = 5
        env = Backends.envelope(case, steps, Float32)
        sites = Backends.usable_sites(case, Float32)
        base = Backends.advance(case.step, [copy(v) for v in case.fields], steps,
                                case.name, "reference trajectory")
        serial = zeros(Float64, steps, steps)
        for j in 0:(steps - 1)
            Backends.measure_injection!(serial, case, steps, sites, nothing, base, j, Float32)
        end
        @test serial == env.amplification

        @testset "positive control: the comparison can fail" begin
            moved = copy(serial)
            moved[1, steps] = nextfloat(moved[1, steps])
            @test moved != env.amplification
        end
    end

    @testset "certify.nonlinear_case_gains_grow_along_the_trajectory" begin
        # A case whose step is not linear has no propagator and no stationary
        # gain. This is the case the certification's own control runs on.
        growing = CertifyFixtures.growing_case()
        env = Backends.envelope(growing, CertifyFixtures.GROWING_STEPS, Float32)
        @test env.exhaustive
        last = CertifyFixtures.GROWING_STEPS
        @test env.amplification[last, last] > 80 * env.amplification[1, 1]
    end

    @testset "a refusal is not a loop verdict and never reads as a pass" begin
        @test Verdicts.NotEvaluable <: Verdicts.LoopVerdict
        @test !(Verdicts.NotEvaluable <: Verdicts.OracleVerdict)
        @test !(Verdicts.Refusal <: Verdicts.OracleVerdict)
        @test !(Verdicts.Refusal <: Verdicts.LoopVerdict)
    end
end
