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
    @test all(report.observed .<= report.bound)
    @test maximum(report.observed ./ report.bound) < 1 / 32
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
        @test any(report.observed .> report.bound)
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

@testset "certification refuses rather than returning a verdict it cannot stand behind" begin
    @testset "an envelope measured on another case" begin
        other = Backends.envelope(CertifyFixtures.small_case(), 4)
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
end
