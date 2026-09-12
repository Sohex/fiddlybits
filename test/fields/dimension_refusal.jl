using Test
using Fiddlybits: Fields, Dimensions
using Fiddlybits.Verdicts: Refusal

# fields.dimension_refusal: docs/oracles/registry.toml. The leak test
# docs/imports/dynamicquantities.md names, and the acceptance of row 52v.3.2.
#
# Two arms: the algebra's products and quotients against their SI exponent signatures,
# and a binary operation between two fields whose signatures differ, which must refuse
# naming both rather than promote one to the other.

const FD = Fields
const DQ = Dimensions
const FXD = FieldFixtures

"The SI exponent signature of each quantity, in BASE_DIMENSIONS order."
const SIGNATURES = (
    ("velocity", DQ.LENGTH / DQ.TIME, (0, 1, -1, 0, 0)),
    ("acceleration", DQ.LENGTH / DQ.TIME^Val(2), (0, 1, -2, 0, 0)),
    ("force", DQ.MASS * DQ.LENGTH / DQ.TIME^Val(2), (1, 1, -2, 0, 0)),
    ("energy", DQ.MASS * DQ.LENGTH^Val(2) / DQ.TIME^Val(2), (1, 2, -2, 0, 0)),
    ("power", DQ.MASS * DQ.LENGTH^Val(2) / DQ.TIME^Val(3), (1, 2, -3, 0, 0)),
    ("pressure", DQ.MASS / (DQ.LENGTH * DQ.TIME^Val(2)), (1, -1, -2, 0, 0)),
    ("density", DQ.MASS / DQ.LENGTH^Val(3), (1, -3, 0, 0, 0)),
    ("flux density", DQ.MASS / DQ.TIME^Val(3), (1, 0, -3, 0, 0)),
    ("specific heat", DQ.LENGTH^Val(2) / (DQ.TIME^Val(2) * DQ.TEMPERATURE),
     (0, 2, -2, -1, 0)),
    ("molar mass", DQ.MASS / DQ.AMOUNT, (1, 0, 0, 0, -1)),
)

@testset "fields.dimension_refusal" begin
    @testset "the algebra reaches the published SI signature" begin
        for (name, dim, expected) in SIGNATURES
            @test DQ.exponents(dim) == expected
            @test DQ.from_dynamic(DQ.to_dynamic(dim)) === dim
        end
    end

    @testset "a length added to a time refuses rather than promoting" begin
        err = try
            DQ.LENGTH + DQ.TIME
        catch e
            e
        end
        @test err isa Refusal
        @test occursin("length", err.reason)
        @test occursin("time", err.reason)
    end

    @testset "two fields whose signatures differ refuse, naming both" begin
        a = FXD.field(dimension = DQ.LENGTH)
        b = FXD.field(dimension = DQ.TIME)
        for (op, site) in ((+, "Fields.+"), (-, "Fields.-"))
            err = try
                op(a, b)
            catch e
                e
            end
            @test err isa Refusal
            @test err.site == site
            @test occursin("length", err.reason)
            @test occursin("time", err.reason)
        end
    end

    @testset "two fields of one signature combine" begin
        a = FXD.field(dimension = DQ.LENGTH)
        b = FXD.field(dimension = DQ.LENGTH)
        @test FD.dimension(a + b) === DQ.LENGTH
    end

    @testset "the refusal is the dimension algebra's, not a second check here" begin
        err = try
            DQ.require_same_dim(DQ.LENGTH, DQ.TIME, "Fields.+")
        catch e
            e
        end
        @test err isa Refusal
        @test err.quantity == "dimension signature"
    end
end
