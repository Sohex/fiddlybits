using Test
using Fiddlybits: Backends, Verdicts

# The ulp-ensemble envelope and the refusals that keep an unmeasurable case out
# of the verdict vocabulary: docs/plans/fiddlybits-52v.7-kernels.md, section
# "Certification", and decision 0029.

@testset "envelope" begin
    @testset "the stand-in case" begin
        @test CASE_ENVELOPE.case == CASE.name
        @test CASE_ENVELOPE.steps == CertifyFixtures.STEPS
        @test length(CASE_ENVELOPE.amplification) == CertifyFixtures.STEPS
        @test all(>(0), CASE_ENVELOPE.amplification)
        @test all(isfinite, CASE_ENVELOPE.amplification)
    end

    @testset "the same case measures the same envelope, bit for bit" begin
        again = Backends.envelope(CASE, CertifyFixtures.STEPS)
        @test again.amplification == CASE_ENVELOPE.amplification
        @test again.members == CASE_ENVELOPE.members
    end

    @testset "a case with fewer sites than the member count is exhaustive" begin
        small = Backends.envelope(CertifyFixtures.small_case(), 4)
        @test small.sites < Backends.ENSEMBLE_MEMBERS
        @test small.members == small.sites
        @test small.exhaustive
        @test small.miss_rate == 0
    end

    @testset "certify.unmeasurable_envelope_refuses" begin
        @testset "a case that does not propagate a one-ulp perturbation" begin
            constant = CertifyFixtures.constant_case()
            @test_throws Verdicts.Refusal Backends.envelope(constant, 4)
            caught = try
                Backends.envelope(constant, 4)
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
                @test Backends.envelope(CASE, 1) isa Backends.Envelope
            end
        end

        @testset "a case with no field an ulp can be taken of" begin
            caught = try
                Backends.envelope(CertifyFixtures.zero_case(), 4)
            catch e
                e
            end
            @test caught isa Verdicts.Refusal
            @test caught.quantity == "ulp-ensemble perturbation site"
            @test occursin("no field holds a finite nonzero normal scale", caught.reason)
        end

        @testset "a step count that is not positive" begin
            caught = try
                Backends.envelope(CASE, 0)
            catch e
                e
            end
            @test caught isa Verdicts.Refusal
            @test occursin("step count 0", caught.reason)

            @testset "positive control: one step is measurable" begin
                @test Backends.envelope(CASE, 1).steps == 1
            end
        end

        @testset "a trajectory that leaves the finite range names the step" begin
            doubling = CertifyFixtures.doubling_case()
            caught = try
                Backends.envelope(doubling, 1100)
            catch e
                e
            end
            @test caught isa Verdicts.Refusal
            @test occursin("cannot be measured", caught.reason)
            @test occursin("Inf", caught.reason)

            @testset "positive control: the same case inside the finite range is measurable" begin
                @test Backends.envelope(doubling, 8) isa Backends.Envelope
            end
        end
    end

    @testset "a refusal is not a loop verdict and never reads as a pass" begin
        @test Verdicts.NotEvaluable <: Verdicts.LoopVerdict
        @test !(Verdicts.NotEvaluable <: Verdicts.OracleVerdict)
        @test !(Verdicts.Refusal <: Verdicts.OracleVerdict)
        @test !(Verdicts.Refusal <: Verdicts.LoopVerdict)
    end
end
