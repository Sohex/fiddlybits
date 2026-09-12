using Test
using Fiddlybits: Time

# The TimeSemantics vocabulary is closed by this check rather than by the language.
# Fields runs the other half of the closure: every semantics here has a time_reduce
# method or a declared refusal (docs/plans/fiddlybits-52v.3-fields.md).
#
# `closed_set` and its fixture come from `test/closure.jl`, which Events and Verdicts
# read through the same guarded include.

isdefined(@__MODULE__, :VocabularyClosure) ||
    include(joinpath(@__DIR__, "..", "closure.jl"))
using .VocabularyClosure: closed_set, Fixture

@testset "Time.semantics" begin
    @testset "the enumeration is complete" begin
        undeclared, unreachable = closed_set(Time.TimeSemantics, Time.time_semantics())
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
        undeclared, _ = closed_set(Fixture.Colour, Fixture.partial())
        @test undeclared == [Fixture.Blue]

        whole, unreachable = closed_set(Fixture.Colour, Fixture.whole())
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
