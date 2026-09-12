using Test
using Fiddlybits: Verdicts

# The two vocabularies are closed by this check rather than by the language: a
# subtype added anywhere fails the suite until the enumeration and the decision
# that declares it move together.
#
# `closed_set` and its fixture come from `test/closure.jl`, which Events and Time
# read through the same guarded include.

isdefined(@__MODULE__, :VocabularyClosure) ||
    include(joinpath(@__DIR__, "..", "closure.jl"))
using .VocabularyClosure: closed_set, Fixture

@testset "Verdicts" begin
    @testset "the vocabularies are closed" begin
        @test closed_set(Verdicts.LoopVerdict, Verdicts.loop_verdicts()) == (Any[], Any[])
        @test closed_set(Verdicts.OracleVerdict, Verdicts.oracle_verdicts()) == (Any[], Any[])
        @test length(Verdicts.loop_verdicts()) == 5
        @test length(Verdicts.oracle_verdicts()) == 3
    end

    @testset "positive control: an omitted subtype is reported" begin
        undeclared, unreachable = closed_set(Fixture.Colour, Fixture.partial())
        @test undeclared == [Fixture.Blue]
        @test isempty(unreachable)
        @test closed_set(Fixture.Colour, Fixture.whole()) == (Any[], Any[])
    end

    @testset "a refusal names what was read and where" begin
        e = try
            Verdicts.refuse("radius", "Mesh.build", "no system is declared")
        catch err
            err
        end
        @test e isa Verdicts.Refusal
        @test e.quantity == "radius"
        @test e.site == "Mesh.build"
        @test occursin("no system is declared", sprint(showerror, e))
    end
end
