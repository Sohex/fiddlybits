using Test
using Fiddlybits: Systems, Dispositions, Dimensions, Reductions, Verdicts

include("Planets.jl")
import .Planets as P

# The five M0 test instances of decision 0034, and system.derived_fields_reproduce run
# on all five: Systems.derived_fields and Systems.rederive, the same mechanism the
# registry's identity carries, and this row's own closed forms, written independently
# of the rules they check. docs/plans/fiddlybits-52v.4-system.md, section
# "The instances"; docs/oracles/registry.toml, system.derived_fields_reproduce.

const value = Dispositions.value

@testset "planets" begin
    instances = (P.Earth(), P.SyntheticNonEarth(), P.SyntheticSynchronous(),
                P.SyntheticRetrograde(), P.SyntheticComposition2())

    @testset "all five instances construct with no refusal" begin
        @test P.Earth() isa Systems.System
        @test P.SyntheticNonEarth() isa Systems.System
        @test P.SyntheticSynchronous() isa Systems.System
        @test P.SyntheticRetrograde() isa Systems.System
        @test P.SyntheticComposition2() isa Systems.System
    end

    @testset "each instance declares what decision 0034 names" begin
        non_earth = P.SyntheticNonEarth()
        @test length(non_earth.stars) == 1
        @test length(non_earth.moons) == 1
        @test non_earth.planet.figure isa Systems.HydrostaticFlattening

        synchronous = P.SyntheticSynchronous()
        @test synchronous.planet.rotation isa Systems.SynchronousPeriod
        @test value(synchronous.planet.obliquity) == 0.0
        @test isempty(synchronous.moons)

        retrograde = P.SyntheticRetrograde()
        @test length(retrograde.stars) == 2
        @test Systems.rotation_sense(retrograde.planet) === :retrograde
        @test value(retrograde.orbits.planet.longitude_of_periapsis) == 0.0

        composition2 = P.SyntheticComposition2()
        @test composition2.inventories.condensable isa Systems.NoCondensable
        @test composition2.orbits.planet.flux_at_semi_major_axis !== nothing
    end

    @testset "system.derived_fields_reproduce passes on all five instances" begin
        for s in instances, (path, d) in Systems.derived_fields(s)
            @test Systems.rederive(s, path) == value(d)
        end
    end

    @testset "closed forms, written here and not by calling the rule they check" begin
        @testset "the root origin: the planet's mean longitude at the epoch is zero" begin
            for s in instances
                @test value(s.orbits.planet.mean_longitude_at_epoch) == 0.0
            end
        end

        @testset "Stefan-Boltzmann: T = (L / (4 pi R^2 sigma))^(1/4)" begin
            sigma = value(Systems.stefan_boltzmann_constant(Float64))
            for s in instances, star in s.stars
                l, r = value(star.luminosity), value(star.radius)
                teff = (l / (4 * Float64(pi) * r * r * sigma))^(1 / 4)
                @test abs(teff - value(star.effective_temperature)) <=
                      Reductions.error_bound(Float64, Systems.EFFECTIVE_TEMPERATURE_TERMS,
                                             teff)
            end
        end

        @testset "Kepler's third law: the synchronous period is 2 pi sqrt(a^3 / (G M))" begin
            s = P.SyntheticSynchronous()
            G = value(Systems.gravitational_constant(Float64))
            a = value(s.orbits.planet.semi_major_axis)
            masses = Systems.orbit_masses(s.stars, s.planet, s.moons, s.orbits.planet)
            period = 2 * Float64(pi) * sqrt(a^3 / (G * sum(masses)))
            @test abs(period - value(s.planet.rotation.period)) <=
                  Reductions.error_bound(Float64, Systems.orbital_period_terms(length(masses)),
                                         period)
        end

        @testset "Darwin-Radau: f = (5q/2) / (1 + (25/4)(1 - 3C/2)^2), q = omega^2 R^3 / (G M)" begin
            s = P.SyntheticNonEarth()
            G = value(Systems.gravitational_constant(Float64))
            mass = value(s.planet.mass)
            radius = value(s.planet.volumetric_mean_radius)
            period = value(s.planet.rotation.period)
            c = value(s.planet.figure.moment_of_inertia_factor)
            omega = 2 * Float64(pi) / period
            q = omega * omega * radius^3 / (G * mass)
            u = 1 - 3 * c / 2
            flattening = (5 * q / 2) / (1 + (25 / 4) * u * u)
            @test abs(flattening - value(s.planet.figure.flattening)) <=
                  Systems.flattening_rounding(Float64, flattening)
        end

        @testset "flux semi-major axis: a = sqrt(L / (4 pi F))" begin
            s = P.SyntheticComposition2()
            l = value(s.stars[s.orbits.planet.primary.index].luminosity)
            f = value(s.orbits.planet.flux_at_semi_major_axis)
            a = sqrt(l / (4 * Float64(pi) * f))
            @test abs(a - value(s.orbits.planet.semi_major_axis)) <=
                  Reductions.error_bound(Float64, Systems.FLUX_SEMI_MAJOR_AXIS_TERMS, a)
        end
    end

    include("mutation_control.jl")
end
