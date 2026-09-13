using Test
using Fiddlybits: Systems, Dispositions
import .SystemFixtures as SF

# strip(system): an isbits struct of plain FT for every instance, a function of the
# system alone, reading its members by name. docs/plans/fiddlybits-52v.4-system.md,
# section "The struct".

@testset "system strip" begin
    value = Dispositions.value
    instances = (SF.system(), SF.system(Float32), SF.two_star_system(), SF.synchronous_system(),
                 SF.flux_system(),
                 SF.system(stars = (SF.star(structure = SF.linear_model(), spectrum = SF.grid()),)),
                 SF.system(inventories = SF.inventories(condensable =
                     Systems.NoCondensable(argument = "the fixture's volatiles do not condense"))))

    @testset "isbits(strip(system)) holds for every instance" begin
        for s in instances
            @test isbits(Systems.strip(s))
        end
    end

    @testset "two strips of one system are identical" begin
        for s in instances
            @test Systems.strip(s) === Systems.strip(s)
        end
    end

    @testset "every value is the system's own, of its FT" begin
        s = SF.two_star_system(Float32)
        st = Systems.strip(s)
        @test st isa Systems.StrippedSystem{Float32}
        @test st.stars[2].effective_temperature === value(s.stars[2].effective_temperature)
        @test st.planet.gravitational_parameter ===
              Systems.gravitational_parameter(Float32, value(s.planet.mass))
        @test st.orbits.companions[1].primary_mass === value(s.stars[1].mass)
        @test st.numerics.exner_reference_pressure === value(s.numerics.exner_reference_pressure)
        @test st.planet.sub_primary_longitude_at_epoch ===
              value(s.planet.sub_primary_longitude_at_epoch)
    end

    @testset "members are read by name" begin
        s = SF.system()
        st = Systems.strip(s)
        @test Systems.province_value(st.planet.lithosphere, :crustal_thickness, :thick) ===
              value(s.planet.lithosphere.crustal_thickness[2])
        @test SF.refused(SF.caught(() -> Systems.province_value(st.planet.lithosphere,
                                                               :crustal_density, :absent)),
                         "province class", "absent")
        @test Systems.named_value(st.inventories.atmosphere, :CO2) ===
              value(s.inventories.atmosphere.fractions[2])
        @test typeof(st.orbits.planet).parameters[2] === Systems.StarBody(1)
        @test typeof(st.orbits.moons[1]).parameters[4] === :planet_equator
        @test typeof(st.planet).parameters[2] === :prograde
        @test typeof(Systems.strip(SF.synchronous_system()).planet).parameters[2] === :prograde
    end
end
