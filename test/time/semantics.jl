using Test
using InteractiveUtils: subtypes
using Fiddlybits: Time

# The TimeSemantics vocabulary is closed by this check rather than by the language.
# Fields runs the other half of the closure: every semantics here has a time_reduce
# method or a declared refusal (docs/plans/fiddlybits-52v.3-fields.md).

module SemanticsClosure
    using InteractiveUtils: subtypes

    """
        closed_set(T, enumeration)

    `(undeclared, unreachable)`: the subtypes of `T` that `enumeration` omits, and
    the entries of `enumeration` that are not subtypes of `T`.
    """
    function closed_set(T::Type, enumeration)
        declared = Set(typeof(v) for v in enumeration)
        present = Set(subtypes(T))
        return (sort(collect(setdiff(present, declared)), by = string),
                sort(collect(setdiff(declared, present)), by = string))
    end

    module Fixture
        abstract type Phase end
        struct Solid <: Phase end
        struct Liquid <: Phase end
        partial() = (Solid(),)
        whole() = (Solid(), Liquid())
    end
end

@testset "Time.semantics" begin
    @testset "the enumeration is complete" begin
        undeclared, unreachable = SemanticsClosure.closed_set(
            Time.TimeSemantics, Time.time_semantics())
        @test isempty(undeclared)
        @test isempty(unreachable)
        @test length(Time.time_semantics()) == 5
    end

    @testset "the enumeration is the set decision 0006 declares" begin
        @test Time.time_semantics() == (Time.Static(), Time.Instantaneous(),
                                        Time.IntervalMean(), Time.IntervalAccumulation(),
                                        Time.EndpointState())
    end

    @testset "the closure check itself can fail" begin
        undeclared, _ = SemanticsClosure.closed_set(
            SemanticsClosure.Fixture.Phase, SemanticsClosure.Fixture.partial())
        @test undeclared == [SemanticsClosure.Fixture.Liquid]

        whole, unreachable = SemanticsClosure.closed_set(
            SemanticsClosure.Fixture.Phase, SemanticsClosure.Fixture.whole())
        @test isempty(whole) && isempty(unreachable)
    end

    @testset "every semantics declares how it is placed on the clock" begin
        kinds = map(Time.time_support_kind, Time.time_semantics())
        @test all(k -> k in (:none, :instant, :interval), kinds)
        @test Time.time_support_kind(Time.Static()) === :none
        @test Time.time_support_kind(Time.Instantaneous()) === :instant
        @test Time.time_support_kind(Time.IntervalMean()) === :interval
        @test Time.time_support_kind(Time.IntervalAccumulation()) === :interval
        @test Time.time_support_kind(Time.EndpointState()) === :interval
    end
end
