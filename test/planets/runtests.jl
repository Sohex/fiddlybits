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

"`system` with its `stars` field replaced by `new_stars`, the step by which the
mutation control below holds a `Derived` value replaced without a second constructor
call."
function with_stars(s::Systems.System{FT}, new_stars) where {FT}
    return Systems.System{FT,typeof(new_stars),typeof(s.planet),typeof(s.orbits),
                          typeof(s.moons),typeof(s.inventories),typeof(s.numerics)}(
        Systems.Checked(), new_stars, s.planet, s.orbits, s.moons, s.inventories,
        s.numerics, s.root_seed)
end

"`star` with its `effective_temperature` field replaced by `mutated`, the rule name kept."
function with_effective_temperature(star::Systems.Star{FT,S,Sp,K}, mutated) where {FT,S,Sp,K}
    return Systems.Star{FT,S,Sp,K}(Systems.Checked(), star.mass, star.age,
        star.metal_mass_fraction, star.structure, star.luminosity, star.radius, mutated,
        star.spectrum, star.variability, star.ultraviolet, star.activity)
end

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
    end

    @testset "mutation control: a Derived rule replaced by the Earth value it happens to equal is caught on the synthetic instances" begin
        earth_teff = value(P.Earth().stars[1].effective_temperature)

        synthetic = P.SyntheticNonEarth()
        path = (:stars, 1, :effective_temperature)
        original = value(Systems.at_path(synthetic, path))
        bound = Reductions.error_bound(Float64, Systems.EFFECTIVE_TEMPERATURE_TERMS,
                                       max(abs(original), abs(earth_teff)))
        @test abs(original - earth_teff) > bound

        star = synthetic.stars[1]
        d = star.effective_temperature
        mutated_d = Dispositions.Derived(value = earth_teff, dim = Dimensions.TEMPERATURE,
                                         from = d.from, rule = d.rule,
                                         fields = Systems.STAR_FIELDS)
        mutated_system = with_stars(synthetic, (with_effective_temperature(star, mutated_d),))

        rederived = Systems.rederive(mutated_system, path)
        @test rederived != value(Systems.at_path(mutated_system, path))
        @test abs(rederived - earth_teff) > bound
    end
end
