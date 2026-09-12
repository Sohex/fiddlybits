using Test
using Fiddlybits: Fields

# The Semantics vocabulary is closed by this check rather than by the language:
# docs/plans/fiddlybits-52v.3-fields.md, row 52v.3.2, and the docstring on
# Fields.Semantics, which names this file.
#
# It reads the types door. Four of the eight members take a parameter and have no one
# instance to stand for them, so semantics_types() enumerates types where
# Events.kinds() and Time.time_semantics() enumerate instances; one definition behind
# both doors is test/closure.jl.

isdefined(@__MODULE__, :VocabularyClosure) ||
    include(joinpath(@__DIR__, "..", "closure.jl"))
using .VocabularyClosure: closed_type_set, TypeFixture

@testset "Fields.semantics_closure" begin
    @testset "the enumeration is complete" begin
        undeclared, unreachable = closed_type_set(Fields.Semantics,
                                                  Fields.semantics_types())
        @test isempty(undeclared)
        @test isempty(unreachable)
        @test length(Fields.semantics_types()) == 8
    end

    @testset "the enumeration is the set decision 0006 declares" begin
        @test Fields.semantics_types() == (Fields.Extensive, Fields.Intensive,
                                           Fields.FluxDensity, Fields.Fraction,
                                           Fields.CategoricalLabel,
                                           Fields.CategoricalFraction,
                                           Fields.VectorComponent, Fields.Quantiles)
    end

    @testset "positive control: an omission from this enumeration is reported" begin
        all_but_last = Fields.semantics_types()[1:(end - 1)]
        undeclared, _ = closed_type_set(Fields.Semantics, all_but_last)
        @test undeclared == [Fields.Quantiles]
    end

    @testset "positive control: an omitted type is reported, parametric or not" begin
        undeclared, unreachable = closed_type_set(TypeFixture.Tone, TypeFixture.partial())
        @test undeclared == [TypeFixture.Graded]
        @test isempty(unreachable)
        @test closed_type_set(TypeFixture.Tone, TypeFixture.whole()) == (Any[], Any[])
    end

    @testset "positive control: a type outside the hierarchy is reported unreachable" begin
        _, unreachable = closed_type_set(TypeFixture.Tone,
                                         (TypeFixture.Flat, TypeFixture.Graded, Int))
        @test unreachable == [Int]
    end
end
