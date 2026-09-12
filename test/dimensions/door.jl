using Test
using Fiddlybits: Dimensions
using Fiddlybits.Verdicts: Refusal
import DynamicQuantities

# The DynamicQuantities door and what it refuses: docs/imports/dynamicquantities.md.

const DD = Dimensions

@testset "Dimensions.door" begin
    @testset "a signature survives the round trip through DynamicQuantities" begin
        for d in (DD.DIMENSIONLESS, DD.MASS, DD.LENGTH, DD.TIME, DD.TEMPERATURE,
                  DD.AMOUNT, DD.MASS * DD.LENGTH^Val(2) / DD.TIME^Val(3),
                  inv(DD.TEMPERATURE) * DD.AMOUNT^Val(-2))
            @test DD.from_dynamic(DD.to_dynamic(d)) === d
        end
    end

    @testset "the door writes the exponents DynamicQuantities reads" begin
        d = DD.to_dynamic(DD.MASS * DD.LENGTH^Val(2) / DD.TIME^Val(3))
        @test d.mass == 1
        @test d.length == 2
        @test d.time == -3
        @test d.temperature == 0
        @test d.amount == 0
        @test d.current == 0
        @test d.luminosity == 0
    end

    @testset "a dimension this project does not carry is refused" begin
        for name in DD.UNCARRIED_DIMENSIONS
            err = try
                DD.from_dynamic(DynamicQuantities.Dimensions(; name => 1))
            catch e
                e
            end
            @test err isa Refusal
            @test err.site == "Dimensions.from_dynamic"
            @test occursin(String(name), err.reason)
        end
    end

    @testset "a fractional exponent is refused rather than rounded" begin
        half = DynamicQuantities.Dimensions(length = 1) ^ (1 // 2)
        err = try
            DD.from_dynamic(half)
        catch e
            e
        end
        @test err isa Refusal
        @test err.site == "Dimensions.from_dynamic"
        @test occursin("not a whole number", err.reason)
    end

    @testset "the outward door is inferrable" begin
        @test @inferred(DD.to_dynamic(DD.MASS)) == DD.to_dynamic(DD.MASS)
    end
end
