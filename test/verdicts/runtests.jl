using Test
using InteractiveUtils: subtypes
using Fiddlybits: Verdicts

# The two vocabularies are closed by this check rather than by the language: a
# subtype added anywhere fails the suite until the enumeration and the decision
# that declares it move together.

"""
    closed_set(T, enumeration)

`(undeclared, unreachable)`: the subtypes of `T` that `enumeration` omits, and the
entries of `enumeration` that are not subtypes of `T`.
"""
function closed_set(T::Type, enumeration)
    declared = Set(typeof(v) for v in enumeration)
    present = Set(subtypes(T))
    return (sort(collect(setdiff(present, declared)), by = string),
            sort(collect(setdiff(declared, present)), by = string))
end

module ClosedSetFixture
    abstract type Colour end
    struct Red <: Colour end
    struct Blue <: Colour end
    partial() = (Red(),)
    whole() = (Red(), Blue())
end

@testset "Verdicts" begin
    @testset "the vocabularies are closed" begin
        @test closed_set(Verdicts.LoopVerdict, Verdicts.loop_verdicts()) == (Any[], Any[])
        @test closed_set(Verdicts.OracleVerdict, Verdicts.oracle_verdicts()) == (Any[], Any[])
        @test length(Verdicts.loop_verdicts()) == 5
        @test length(Verdicts.oracle_verdicts()) == 3
    end

    @testset "positive control: an omitted subtype is reported" begin
        undeclared, unreachable = closed_set(ClosedSetFixture.Colour, ClosedSetFixture.partial())
        @test undeclared == [ClosedSetFixture.Blue]
        @test isempty(unreachable)
        @test closed_set(ClosedSetFixture.Colour, ClosedSetFixture.whole()) == (Any[], Any[])
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
