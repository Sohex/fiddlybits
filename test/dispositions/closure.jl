using Test
using Fiddlybits: Dispositions, Dimensions

# The disposition vocabulary is closed by this check rather than by the language:
# docs/plans/fiddlybits-52v.4-system.md, section "The five dispositions", and
# decision 0007. dispositions() enumerates the five, and this file asserts the
# subtypes of Disposition are exactly that enumeration.
#
# `closed_type_set` comes from test/closure.jl, read through the same guarded
# include the other suites use.

isdefined(@__MODULE__, :VocabularyClosure) ||
    include(joinpath(@__DIR__, "..", "closure.jl"))
using .VocabularyClosure: closed_type_set

@testset "Dispositions.dispositions" begin
    @testset "the enumeration is complete" begin
        undeclared, unreachable = closed_type_set(Dispositions.Disposition,
                                                  Dispositions.dispositions())
        @test isempty(undeclared)
        @test isempty(unreachable)
        @test length(Dispositions.dispositions()) == 5
    end

    @testset "the enumeration is the set decision 0007 declares" begin
        @test Dispositions.dispositions() == (Dispositions.Sourced, Dispositions.Derived,
                                              Dispositions.Bracketed,
                                              Dispositions.Irreducible,
                                              Dispositions.Closure)
    end
end

"A subtype of Disposition that dispositions() does not enumerate, defined only after
the closure test above has run, so it never hides an omission from that test."
module SixthDisposition
    using Fiddlybits: Dispositions, Dimensions
    struct Tuned{T,D<:Dimensions.Dim} <: Dispositions.Disposition{T,D} end
end

@testset "positive control: a sixth subtype is reported by the enumeration" begin
    undeclared, _ = closed_type_set(Dispositions.Disposition, Dispositions.dispositions())
    @test undeclared == [SixthDisposition.Tuned]
end
