using Test
using Fiddlybits: Systems, Dimensions
import .SystemFixtures as SF

# Numerics: the Exner reference pressure and the geometry precision, no epoch, and no
# field a profile may vary. docs/plans/fiddlybits-52v.4-system.md, section "The struct".

"A struct naming fields a profile holds, one of which Numerics holds too."
struct OverlappingProfileFixture
    levels::Int
    exner_reference_pressure::Float64
end

@testset "system numerics" begin
    shared(a, b) = intersect(fieldnames(a), fieldnames(b))

    @testset "Numerics carries no epoch" begin
        @test fieldnames(Systems.Numerics) == (:exner_reference_pressure, :geometry_precision)
        @test fieldnames(Systems.StrippedNumerics) == (:exner_reference_pressure,)
        @test SF.refused(SF.caught(() -> SF.numerics(epoch = SF.irreducible(0.0, Dimensions.TIME))),
                         "epoch", "not a keyword")
        for name in (:EpochReference, :EPOCH_KINDS, :require_epoch)
            @test !isdefined(Systems, name)
        end

        @testset "control: a keyword Numerics takes omitted is refused, and a name Systems defines is found" begin
            without = Base.structdiff((exner_reference_pressure = SF.irreducible(1e5, Systems.PRESSURE),
                                       geometry_precision = Float64),
                                      NamedTuple{(:geometry_precision,)})
            @test SF.refused(SF.caught(() -> Systems.Numerics(; without...)),
                             "geometry_precision", "missing")
            @test isdefined(Systems, :DECLINATION_TERMS)
        end
    end

    @testset "the field names of Numerics and Profile are disjoint" begin
        @test shared(Systems.Numerics, OverlappingProfileFixture) == [:exner_reference_pressure]
        @test isempty(shared(Systems.Numerics, Systems.Profile))
    end

    @testset "the geometry is formed in double precision" begin
        @test SF.refused(SF.caught(() -> SF.numerics(geometry_precision = Float32)),
                         "geometry_precision", "Float64")
        @test SF.refused(SF.caught(() -> SF.numerics(exner_reference_pressure =
                                                         SF.irreducible(0.0, Systems.PRESSURE))),
                         "exner_reference_pressure", "outside")
    end
end
