using Test
using Fiddlybits: Backends, Verdicts

# The single-precision certification against the envelope: docs/plans/
# fiddlybits-52v.7-kernels.md, section "Certification", decision 0029 and
# decision 0025's verdict vocabulary. The measured detection threshold the two
# injected magnitudes below bracket is in
# notes/findings/2026-09-11-ulp-ensemble-member-count.md.

@testset "certify.correct_fp32_certifies" begin
    report = Backends.certification(CASE.step, CASE, CASE_ENVELOPE; roundoff = CASE_ROUNDOFF)
    @test report.verdict == Backends.PASS()
    @test all(report.observed .<= report.admitted)
    @test maximum(report.observed ./ report.admitted) < 1 / 32
    @test report.initial > 0

    @testset "the verdict is an OracleVerdict and never a boolean" begin
        verdict = Backends.certify(CASE.step, CASE, CASE_ENVELOPE; roundoff = CASE_ROUNDOFF)
        @test verdict isa Verdicts.OracleVerdict
        @test !(verdict isa Bool)
        @test verdict == report.verdict
    end
end

@testset "certify.injected_error_fails" begin
    @testset "a relative defect of 1e-5 in the Float32 path alone" begin
        candidate = CertifyFixtures.injected(CASE_NB, CASE_W, 1.0e-5)
        report = Backends.certification(candidate, CASE, CASE_ENVELOPE; roundoff = CASE_ROUNDOFF)
        @test report.verdict == Backends.FAIL()
        @test any(report.observed .> report.admitted)
    end

    @testset "a relative defect of 1e-4 in the Float32 path alone" begin
        candidate = CertifyFixtures.injected(CASE_NB, CASE_W, 1.0e-4)
        @test Backends.certify(candidate, CASE, CASE_ENVELOPE; roundoff = CASE_ROUNDOFF) ==
              Backends.FAIL()
    end

    @testset "positive control: a relative defect of 1e-6 is below the measured threshold" begin
        candidate = CertifyFixtures.injected(CASE_NB, CASE_W, 1.0e-6)
        @test Backends.certify(candidate, CASE, CASE_ENVELOPE; roundoff = CASE_ROUNDOFF) ==
              Backends.PASS()
    end

    @testset "positive control: a defect both paths share is not this oracle's to catch" begin
        shared = CertifyFixtures.make_step(CertifyFixtures.N_CELLS, CASE_NB, CASE_W;
                                           scale = 1 + 1.0e-4)
        @test Backends.certify(shared, CASE, CASE_ENVELOPE; roundoff = CASE_ROUNDOFF) ==
              Backends.PASS()
    end
end

@testset "certify.later_injection_exceeds_the_initial_state_envelope" begin
    # `growing_case` is nonlinear and its local amplification grows along its
    # trajectory; the candidate injects a declared absolute divergence at Float32
    # alone, and the case's initial state is exact at Float32, so `initial` is
    # zero and the verdict rests on the propagation of the declaration alone.
    # What this falsifies is in
    # notes/findings/2026-09-12-ulp-ensemble-amplitude-and-injection-step.md.
    case = CertifyFixtures.growing_case()
    steps = CertifyFixtures.GROWING_STEPS
    env = Backends.envelope(case, steps, Float32)
    candidate = CertifyFixtures.growing_injection(CertifyFixtures.GROWING_INJECTION)
    declared = CertifyFixtures.measured_roundoff(case, candidate, steps)

    measured = Backends.certification(candidate, case, env; roundoff = declared)
    @test measured.initial == 0
    @test measured.verdict == Backends.PASS()
    @test maximum(measured.observed ./ measured.admitted) < 1 / 2

    @testset "the same candidate against gains measured at the initial state alone" begin
        flat = Backends.certification(candidate, case,
                                      CertifyFixtures.stationary_envelope(env);
                                      roundoff = declared)
        @test flat.verdict == Backends.FAIL()
        @test maximum(flat.observed ./ flat.admitted) > 10
        @test flat.observed == measured.observed
        @test flat.admitted[1] == measured.admitted[1]
    end

    @testset "positive control: on a linear stationary case the two agree" begin
        linear = CertifyFixtures.small_case()
        linear_env = Backends.envelope(linear, 6, Float32)
        flat = CertifyFixtures.stationary_envelope(linear_env)
        for j in 0:5, s in (j + 1):6
            @test isapprox(flat.amplification[j + 1, s], linear_env.amplification[j + 1, s];
                           rtol = 1.0e-6)
        end
    end
end

@testset "certification refuses rather than returning a verdict it cannot stand behind" begin
    @testset "an envelope measured on another case" begin
        other = Backends.envelope(CertifyFixtures.small_case(), 4, Float32)
        caught = try
            Backends.certify(CASE.step, CASE, other; roundoff = CASE_ROUNDOFF)
        catch e
            e
        end
        @test caught isa Verdicts.Refusal
        @test occursin(other.case, caught.reason)
        @test occursin(CASE.name, caught.reason)
    end

    @testset "a negative declared roundoff" begin
        caught = try
            Backends.certify(CASE.step, CASE, CASE_ENVELOPE; roundoff = -CASE_ROUNDOFF)
        catch e
            e
        end
        @test caught isa Verdicts.Refusal
        @test occursin("negative", caught.reason)

        @testset "positive control: zero roundoff is a declaration, not a refusal" begin
            @test Backends.certify(CASE.step, CASE, CASE_ENVELOPE; roundoff = 0) isa
                  Verdicts.OracleVerdict
        end
    end

    @testset "an envelope measured for another precision" begin
        wide = Backends.envelope(CASE, CertifyFixtures.STEPS, Float64)
        caught = try
            Backends.certify(CASE.step, CASE, wide; roundoff = CASE_ROUNDOFF)
        catch e
            e
        end
        @test caught isa Verdicts.Refusal
        @test occursin("Float64", caught.reason)
        @test occursin("Float32", caught.reason)

        @testset "positive control: the Float32 envelope of the same case is taken" begin
            @test Backends.certify(CASE.step, CASE, CASE_ENVELOPE;
                                   roundoff = CASE_ROUNDOFF) isa Verdicts.OracleVerdict
        end
    end
end
