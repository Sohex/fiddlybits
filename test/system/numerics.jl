using Test
using Fiddlybits: Systems, Dimensions
import .SystemFixtures as SF

# Numerics: the epoch reference, the Exner reference pressure and the geometry
# precision, and no field a profile may vary. docs/plans/fiddlybits-52v.4-system.md,
# section "The struct".

"A struct naming fields a profile holds, one of which Numerics holds too."
struct OverlappingProfileFixture
    levels::Int
    exner_reference_pressure::Float64
end

@testset "system numerics" begin
    shared(a, b) = intersect(fieldnames(a), fieldnames(b))

    @testset "the epoch reference lives in Numerics" begin
        @test :epoch in fieldnames(Systems.Numerics)
        @test !(:epoch in fieldnames(Systems.System))
        @test SF.system().numerics.epoch isa Systems.EpochReference
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

    @testset "the epoch's source and kind" begin
        epoch(kind, source) = SF.numerics(epoch = Systems.EpochReference(
            kind = kind, source = source, offset = SF.irreducible(0.0, Dimensions.TIME)))
        @test SF.refused(SF.caught(() -> SF.system(numerics = epoch(:superior_conjunction, Systems.StarBody(1)))),
                         "epoch", "synchronous")
        @test SF.refused(SF.caught(() -> SF.system(numerics = epoch(:periapsis, Systems.StarBody(1)))),
                         "epoch", "no orbit")
        @test SF.two_star_system(numerics = epoch(:periapsis, Systems.StarBody(2))) isa Systems.System
        @test SF.refused(SF.caught(() -> epoch(:vernal_equinox, Systems.PlanetBody())),
                         "source", "names none")
        @test SF.refused(SF.caught(() -> epoch(:solstice, Systems.StarBody(1))), "kind", "not one of")
    end
end
