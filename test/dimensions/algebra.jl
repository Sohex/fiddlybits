using Test
using Fiddlybits: Dimensions
using Fiddlybits.Verdicts: Refusal

# The identities of the dimension algebra, and the refusal that a mismatched addition
# raises rather than promoting. docs/plans/fiddlybits-52v.3-fields.md, section
# "Types and functions".

const D = Dimensions

"The five base signatures, in BASE_DIMENSIONS order."
const BASES = (D.MASS, D.LENGTH, D.TIME, D.TEMPERATURE, D.AMOUNT)

@testset "Dimensions.algebra" begin
    @testset "a base signature carries one exponent of one" begin
        for (i, base) in enumerate(BASES)
            e = D.exponents(base)
            @test e[i] == 1
            @test sum(e) == 1
            @test length(e) == length(D.BASE_DIMENSIONS)
        end
        @test D.exponents(D.DIMENSIONLESS) == (0, 0, 0, 0, 0)
    end

    @testset "multiplication adds exponents and division subtracts them" begin
        a = D.MASS * D.LENGTH^Val(2) / D.TIME^Val(3)
        @test D.exponents(a) == (1, 2, -3, 0, 0)
        @test a * D.TIME^Val(3) === D.MASS * D.LENGTH^Val(2)
        @test a / a === D.DIMENSIONLESS
    end

    @testset "the identities hold" begin
        for base in BASES
            @test base * D.DIMENSIONLESS === base
            @test base * inv(base) === D.DIMENSIONLESS
            @test inv(inv(base)) === base
            @test base^Val(0) === D.DIMENSIONLESS
            @test base^Val(1) === base
            @test base^Val(2) === base * base
            @test base^Val(-1) === inv(base)
            @test one(base) === D.DIMENSIONLESS
            @test one(typeof(base)) === D.DIMENSIONLESS
        end
        @test D.MASS * D.LENGTH === D.LENGTH * D.MASS
        @test (D.MASS * D.LENGTH) * D.TIME === D.MASS * (D.LENGTH * D.TIME)
    end

    @testset "a literal power reaches the Val form" begin
        @test D.LENGTH^2 === D.LENGTH^Val(2)
        @test D.LENGTH^-1 === inv(D.LENGTH)
    end

    @testset "addition refuses a mismatch rather than promoting" begin
        @test D.MASS + D.MASS === D.MASS
        @test D.MASS - D.MASS === D.MASS
        err = try
            D.LENGTH + D.TIME
        catch e
            e
        end
        @test err isa Refusal
        @test err.site == "Dimensions.+"
        @test occursin("length", err.reason)
        @test occursin("time", err.reason)
    end

    @testset "require_same_dim passes a match and names both signatures otherwise" begin
        @test D.require_same_dim(D.MASS, D.MASS, "test") === nothing
        err = try
            D.require_same_dim(D.MASS * D.LENGTH, D.TIME, "test.site")
        catch e
            e
        end
        @test err isa Refusal
        @test err.site == "test.site"
        @test occursin("mass length", err.reason)
        @test occursin("time", err.reason)
    end

    @testset "a signature prints its exponents" begin
        @test D.signature(D.DIMENSIONLESS) == "dimensionless"
        @test D.signature(D.MASS) == "mass"
        @test D.signature(D.MASS * D.LENGTH^Val(2) / D.TIME^Val(3)) ==
              "mass length^2 time^-3"
        @test occursin("mass", sprint(show, D.MASS))
    end

    @testset "an exponent that is not an Int is refused" begin
        err = try
            D.Dim{1.5,0,0,0,0}()
        catch e
            e
        end
        @test err isa Refusal
        @test err.site == "Dimensions.Dim"
        @test occursin("must be Int", err.reason)
    end

    @testset "every operation of the algebra is inferrable" begin
        a, b = D.MASS, D.LENGTH
        @test @inferred(a * b) === D.MASS * D.LENGTH
        @test @inferred(a / b) === D.MASS / D.LENGTH
        @test @inferred(inv(a)) === inv(D.MASS)
        @test @inferred(a^Val(3)) === D.MASS^Val(3)
        @test @inferred(a + a) === D.MASS
        @test @inferred(a - a) === D.MASS
        @test @inferred(one(a)) === D.DIMENSIONLESS
        @test @inferred(D.exponents(a)) == (1, 0, 0, 0, 0)
        @test @inferred(D.require_same_dim(a, a, "test")) === nothing
    end
end
