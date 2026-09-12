using Test
using Fiddlybits: Backends, Verdicts

# The obligation a case carries and the door that refuses to skip it: docs/plans/
# fiddlybits-52v.7-kernels.md, section "Certification", decision 0005's twelve
# degree-five vertices, decision 0025's verdict vocabulary and decision 0029.
#
# fiddlybits-52v.7.17 put the exhaustive arm beside the sampled envelope, which
# is what notes/findings/2026-09-11-ulp-ensemble-member-count.md asks for so the
# declared miss rate keeps its meaning, and left the two arms for the caller to
# assemble. This file is the assembly: the case declares the sub-population the
# sampled draw does not reach, `Backends.certification` names what a scope left
# out, `Backends.certify` refuses a verdict that left one out, and
# `Backends.case_certification` runs both arms from a case and a step count.
#
# MESH_CASE and the MESH_* constants are degree_five.jl's, which runtests.jl
# includes first.

const OBLIGATION_ROUNDOFF = scope -> CertifyMeshFixture.roundoff(MESH_CASE; sites = scope)

# The stand-in case's gains from the initial state as notes/findings/2026-09-12-
# ulp-ensemble-amplitude-and-injection-step.md recorded them, section "The
# stand-in case at the two amplitudes". The row is the draw's own signature: a
# member set that moved would not reproduce it.
const FINDING_AMPLIFICATION =
    [1.5370733437594026, 1.49623842316214, 1.5326636934187263, 1.5908572526823264,
     1.6080869103316218, 1.6191722891526297, 1.6264993406366557, 1.6330749358749017,
     1.651457596803084, 1.6652258010581136, 1.6752443460281938, 1.6837054369971156,
     1.6935136308893561, 1.7129886508919299, 1.7329219253733754, 1.7526412960141897,
     1.7716029654257, 1.7909559129038826, 1.813414293807, 1.8346782953012735]

# Unchanged by that finding: the initial divergence is the Float32 rounding of
# the case's own initial state and no envelope enters it.
const FINDING_INITIAL = 4.253610957849485e-5

@testset "certify.obligation_is_carried_by_the_case" begin
    @testset "the case declares the degree-five vertices and nothing else" begin
        @test length(MESH_CASE.obligations) == 1
        ob = MESH_CASE.obligations[1]
        @test ob.name == CertifyMeshFixture.DEGREE_FIVE
        @test Set(ob.sites) == Set(MESH_PENTAGON_SITES)
        @test length(ob.sites) == 2 * 12
        @test all(v -> MESH_VALENCE[v] == 5, last.(ob.sites))

        @testset "the stand-in case declares none" begin
            @test isempty(CASE.obligations)
        end
    end

    @testset "a case refuses an obligation it cannot carry" begin
        fields = [collect(1.0:4.0)]
        step! = state -> state

        @testset "an obligation naming no site" begin
            caught = try
                Backends.EnsembleCase("empty-obligation", fields, step!,
                                      [Backends.Obligation("none", Tuple{Int,Int}[])])
            catch e
                e
            end
            @test caught isa Verdicts.Refusal
            @test caught.quantity == "certification obligation"
            @test occursin("names no site", caught.reason)
        end

        @testset "an obligation naming a cell the case does not have" begin
            caught = try
                Backends.EnsembleCase("out-of-range", fields, step!,
                                      [Backends.Obligation("beyond", [(1, 9)])])
            catch e
                e
            end
            @test caught isa Verdicts.Refusal
            @test occursin("field 1 cell 9", caught.reason)
        end

        @testset "two obligations with one name" begin
            caught = try
                Backends.EnsembleCase("twice", fields, step!,
                                      [Backends.Obligation("same", [(1, 1)]),
                                       Backends.Obligation("same", [(1, 2)])])
            catch e
                e
            end
            @test caught isa Verdicts.Refusal
            @test occursin("declared twice", caught.reason)
        end

        @testset "an obligation naming one of its own sites twice" begin
            caught = try
                Backends.EnsembleCase("repeated-site", fields, step!,
                                      [Backends.Obligation("dup", [(1, 3), (1, 3)])])
            catch e
                e
            end
            @test caught isa Verdicts.Refusal
            @test caught.quantity == "certification obligation"
            @test occursin("dup", caught.reason)
            @test occursin("field 1 cell 3", caught.reason)
            @test occursin("twice", caught.reason)

            @testset "positive control: the same duplicate list construct today, and must not" begin
                @test_throws Verdicts.Refusal Backends.EnsembleCase("repeated-site", fields, step!,
                                                                    [Backends.Obligation("dup",
                                                                     [(1, 3), (1, 3)])])
            end
        end

        @testset "two different obligations naming the same site" begin
            ok = Backends.EnsembleCase("shared-site", fields, step!,
                                       [Backends.Obligation("first", [(1, 3)]),
                                        Backends.Obligation("second", [(1, 3), (1, 4)])])
            @test length(ok.obligations) == 2
            @test ok.obligations[1].sites == [(1, 3)]
            @test ok.obligations[2].sites == [(1, 3), (1, 4)]
        end

        @testset "positive control: a well-formed obligation constructs" begin
            ok = Backends.EnsembleCase("well-formed", fields, step!,
                                       [Backends.Obligation("corner", [(1, 1), (1, 4)])])
            @test length(ok.obligations) == 1
            @test ok.obligations[1].sites == [(1, 1), (1, 4)]
        end
    end
end

@testset "certify.sampled_scope_names_its_omission" begin
    correct = CertifyMeshFixture.make_step(MESH_NV, MESH_NEIGHBOUR, MESH_W)

    @testset "a certification over the sampled sites alone names the obligation it left out" begin
        domain = Backends.certification(correct, MESH_CASE, MESH_SAMPLED_ENVELOPE;
                                        roundoff = MESH_ROUNDOFF_DOMAIN)
        @test domain.omitted == [CertifyMeshFixture.DEGREE_FIVE]
        @test !isempty(domain.omitted)
    end

    @testset "positive control: the obligation's own arm omits nothing" begin
        pentagon = Backends.certification(correct, MESH_CASE, MESH_PENTAGON_ENVELOPE;
                                          roundoff = MESH_ROUNDOFF_PENTAGON,
                                          sites = MESH_PENTAGON_SITES)
        @test isempty(pentagon.omitted)
    end

    @testset "positive control: a case with no obligation omits nothing" begin
        report = Backends.certification(CASE.step, CASE, CASE_ENVELOPE; roundoff = CASE_ROUNDOFF)
        @test isempty(report.omitted)
    end
end

@testset "certify.uncovered_obligation_refuses_a_verdict" begin
    correct = CertifyMeshFixture.make_step(MESH_NV, MESH_NEIGHBOUR, MESH_W)

    @testset "the sampled envelope alone: the old way, which no longer returns a verdict" begin
        caught = try
            Backends.certify(correct, MESH_CASE, MESH_SAMPLED_ENVELOPE;
                             roundoff = MESH_ROUNDOFF_DOMAIN)
        catch e
            e
        end
        @test caught isa Verdicts.Refusal
        @test !(caught isa Verdicts.OracleVerdict)
        @test caught.quantity == "certification coverage"
        @test caught.site == "Backends.certify"
        @test occursin(CertifyMeshFixture.DEGREE_FIVE, caught.reason)
        @test occursin("Backends.case_certification", caught.reason)
    end

    @testset "the exhaustive envelope with the scope left off" begin
        @test_throws Verdicts.Refusal Backends.certify(correct, MESH_CASE, MESH_PENTAGON_ENVELOPE;
                                                       roundoff = MESH_ROUNDOFF_PENTAGON)
    end

    @testset "positive control: the obligation covered returns a verdict" begin
        verdict = Backends.certify(correct, MESH_CASE, MESH_PENTAGON_ENVELOPE;
                                   roundoff = MESH_ROUNDOFF_PENTAGON, sites = MESH_PENTAGON_SITES)
        @test verdict isa Verdicts.OracleVerdict
        @test verdict == Backends.PASS()
    end

    @testset "positive control: a case with no obligation is not refused" begin
        @test Backends.certify(CASE.step, CASE, CASE_ENVELOPE; roundoff = CASE_ROUNDOFF) isa
              Verdicts.OracleVerdict
    end
end

@testset "certify.coverage_is_the_exact_site_set" begin
    ob = MESH_CASE.obligations[1]

    @test Backends.covers(MESH_PENTAGON_ENVELOPE, MESH_PENTAGON_SITES, ob)

    @testset "the sampled envelope covers nothing" begin
        @test !Backends.covers(MESH_SAMPLED_ENVELOPE, MESH_PENTAGON_SITES, ob)
        @test !Backends.covers(MESH_SAMPLED_ENVELOPE, nothing, ob)
    end

    @testset "the scope left off, or widened by one site" begin
        @test !Backends.covers(MESH_PENTAGON_ENVELOPE, nothing, ob)
        hexagon = findfirst(==(Int32(6)), MESH_VALENCE)
        @test !(hexagon in MESH_PENTAGON)
        extra = vcat(MESH_PENTAGON_SITES, [(1, hexagon)])
        @test !Backends.covers(MESH_PENTAGON_ENVELOPE, extra, ob)
    end

    @testset "an envelope measured over other sites, at the same count" begin
        e = MESH_PENTAGON_ENVELOPE
        elsewhere = Tuple{Int,Int}[(f, v) for f in eachindex(MESH_CASE.fields)
                                   for v in (MESH_NV - 11):MESH_NV]
        @test length(elsewhere) == length(ob.sites)
        @test Set(elsewhere) != Set(ob.sites)
        other = Backends.Envelope(e.case, e.steps, e.precision, e.members, e.sites,
                                  e.exhaustive, e.miss_rate, e.amplification, elsewhere,
                                  elsewhere)
        @test !Backends.covers(other, MESH_PENTAGON_SITES, ob)
        @test !Backends.covers(other, elsewhere, ob)
    end
end

@testset "certify.case_certification_runs_every_arm" begin
    correct = CertifyMeshFixture.make_step(MESH_NV, MESH_NEIGHBOUR, MESH_W)
    report = Backends.case_certification(correct, MESH_CASE, CertifyMeshFixture.STEPS;
                                         roundoff = OBLIGATION_ROUNDOFF)

    @test report.case == MESH_CASE.name
    @test report.steps == CertifyMeshFixture.STEPS
    @test report.obligations == [CertifyMeshFixture.DEGREE_FIVE]
    @test length(report.obligated) == 1
    @test isempty(report.obligated[1].omitted)
    @test report.sampled.omitted == [CertifyMeshFixture.DEGREE_FIVE]
    @test report.verdict == Backends.PASS()
    @test report.sampled.verdict == Backends.PASS()
    @test report.obligated[1].verdict == Backends.PASS()

    @testset "the sampled arm is the same envelope the caller would have built" begin
        @test report.sampled.admitted == Backends.admitted(MESH_SAMPLED_ENVELOPE,
                                                           report.sampled.initial,
                                                           MESH_ROUNDOFF_DOMAIN)
    end

    @testset "a defect at one degree-five vertex fails the case, not only the arm" begin
        defect = CertifyMeshFixture.localized_defect(MESH_NV, MESH_NEIGHBOUR, MESH_W,
                                                      MESH_DEFECT_VERTEX, MESH_DEFECT_RELATIVE)
        caught = Backends.case_certification(defect, MESH_CASE, CertifyMeshFixture.STEPS;
                                             roundoff = OBLIGATION_ROUNDOFF)
        @test caught.verdict == Backends.FAIL()
        @test caught.obligated[1].verdict == Backends.FAIL()

        @testset "positive control: the sampled arm alone still passes it" begin
            @test caught.sampled.verdict == Backends.PASS()
        end

        @testset "the verdict door is an OracleVerdict and never a boolean" begin
            verdict = Backends.certify_case(defect, MESH_CASE, CertifyMeshFixture.STEPS;
                                            roundoff = OBLIGATION_ROUNDOFF)
            @test verdict isa Verdicts.OracleVerdict
            @test !(verdict isa Bool)
            @test verdict == Backends.FAIL()
        end
    end
end

@testset "certify.sampled_draw_is_unchanged" begin
    @testset "the stand-in case's envelope is what the finding recorded, bit for bit" begin
        @test [CASE_ENVELOPE.amplification[1, s] for s in 1:CertifyFixtures.STEPS] ==
              FINDING_AMPLIFICATION
        @test CASE_ENVELOPE.members == Backends.ENSEMBLE_MEMBERS
        @test CASE_ENVELOPE.sites == 2 * CertifyFixtures.N_CELLS
        @test CASE_ENVELOPE.exhaustive == false
        @test CASE_ENVELOPE.miss_rate == Backends.ENSEMBLE_MISS_RATE
        @test Backends.certification(CASE.step, CASE, CASE_ENVELOPE;
                                     roundoff = CASE_ROUNDOFF).initial == FINDING_INITIAL
    end

    @testset "the members are the bit-reversed prefix, in order, over every usable site" begin
        usable = Backends.usable_sites(CASE, Float32)
        order = Backends.bit_reversed_order(length(usable))
        @test CASE_ENVELOPE.perturbed ==
              [usable[order[t]] for t in 1:Backends.ENSEMBLE_MEMBERS]
        @test CASE_ENVELOPE.scope === nothing

        @testset "the real-mesh case draws the same way" begin
            mesh_usable = Backends.usable_sites(MESH_CASE, Float32)
            mesh_order = Backends.bit_reversed_order(length(mesh_usable))
            @test MESH_SAMPLED_ENVELOPE.perturbed ==
                  [mesh_usable[mesh_order[t]] for t in 1:Backends.ENSEMBLE_MEMBERS]
            @test MESH_SAMPLED_ENVELOPE.scope === nothing
            @test MESH_SAMPLED_ENVELOPE.miss_rate == Backends.ENSEMBLE_MISS_RATE
        end

        @testset "positive control: the obligation's arm draws over its own sites" begin
            @test Set(MESH_PENTAGON_ENVELOPE.perturbed) == Set(MESH_PENTAGON_SITES)
            @test MESH_PENTAGON_ENVELOPE.scope !== nothing
            @test Set(MESH_PENTAGON_ENVELOPE.scope) == Set(MESH_PENTAGON_SITES)
            @test MESH_PENTAGON_ENVELOPE.miss_rate == 0
        end
    end
end
