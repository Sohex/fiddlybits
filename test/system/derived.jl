using Test
using Fiddlybits: Systems, Dispositions, Dimensions, Reductions
import .SystemFixtures as SF

# The Derived fields of System: enumerated from the struct, recomputed by rederive,
# each rule within its declared rounding of a 256-bit evaluation, and a supplied
# value checked against it. docs/plans/fiddlybits-52v.4-system.md, section "Oracles".

@testset "system Derived fields" begin
    value = Dispositions.value

    @testset "derived_fields enumerates every Derived value from the struct" begin
        paths(s) = [p for (p, _) in Systems.derived_fields(s)]
        @test paths(SF.system()) == [(:stars, 1, :effective_temperature)]
        @test (:planet, :rotation, :period) in paths(SF.synchronous_system())
        @test (:orbits, :planet, :semi_major_axis) in paths(SF.flux_system())
        modelled = SF.system(stars = (SF.star(structure = SF.linear_model(), spectrum = SF.grid()),))
        @test Set(paths(modelled)) == Set([(:stars, 1, :luminosity), (:stars, 1, :radius),
                                           (:stars, 1, :effective_temperature),
                                           (:stars, 1, :spectrum, :surface_flux_density)])
    end

    @testset "rederive reproduces every Derived field" begin
        instances = (SF.system(), SF.system(Float32), SF.two_star_system(),
                     SF.synchronous_system(), SF.flux_system(),
                     SF.system(stars = (SF.star(structure = SF.linear_model(), spectrum = SF.grid()),)))
        for s in instances, (path, d) in Systems.derived_fields(s)
            @test Systems.rederive(s, path) == value(d)
        end
        @test SF.refused(SF.caught(() -> Systems.rederive(SF.system(), (:planet, :mass))),
                         "path", "no Derived value")
    end

    @testset "each rule lies within its rounding of a 256-bit evaluation" begin
        for T in (Float64, Float32), l in (1e24, 3e25, 2.5e26, 8e27), r in (1e8, 6e8, 2e9)
            t = Systems.effective_temperature(T, T(l), T(r))
            @test abs(big(t) - SF.effective_temperature_256(T(l), T(r))) <=
                  Reductions.error_bound(T, Systems.EFFECTIVE_TEMPERATURE_TERMS, t)
        end
        for T in (Float64, Float32), a in (4e8, 1.8e11, 3e12), m in ((1.6e30, 8e24), (1e30, 9e29, 5e22))
            masses = T.(m)
            period = Systems.orbital_period(T, T(a), masses)
            @test abs(big(period) - SF.orbital_period_256(T(a), masses)) <=
                  Reductions.error_bound(T, Systems.orbital_period_terms(length(masses)), period)
        end
        for T in (Float64, Float32), l in (1e24, 2.5e26), f in (10.0, 900.0, 2e4)
            a = Systems.semi_major_axis_from_flux(T, T(l), T(f))
            @test abs(big(a) - SF.flux_axis_256(T(l), T(f))) <=
                  Reductions.error_bound(T, Systems.FLUX_SEMI_MAJOR_AXIS_TERMS, a)
        end
    end

    @testset "a supplied Derived value is checked against the computed one" begin
        s = SF.synchronous_system()
        period = value(s.planet.rotation.period)
        masses = Systems.orbit_masses(s.stars, s.planet, s.moons, s.orbits.planet)
        bound = Systems.rounding_bound(Float64, Systems.orbital_period_terms(length(masses)), period)
        exact = Float64(SF.orbital_period_256(value(s.orbits.planet.semi_major_axis), masses))
        @test SF.synchronous_system(sidereal_rotation_period = exact) isa Systems.System
        @test SF.refused(SF.caught(() -> SF.synchronous_system(sidereal_rotation_period = period + 2 * bound)),
                         "sidereal_rotation_period", "disagrees")

        f = SF.flux_system()
        a = value(f.orbits.planet.semi_major_axis)
        bound = Systems.rounding_bound(Float64, Systems.FLUX_SEMI_MAJOR_AXIS_TERMS, a)
        @test SF.flux_system(semi_major_axis = a) isa Systems.System
        @test SF.refused(SF.caught(() -> SF.flux_system(semi_major_axis = a + 2 * bound)),
                         "semi_major_axis", "disagrees")

        star = SF.star()
        t = value(star.effective_temperature)
        bound = Systems.rounding_bound(Float64, Systems.EFFECTIVE_TEMPERATURE_TERMS, t)
        @test SF.star(effective_temperature = t) isa Systems.Star
        @test SF.refused(SF.caught(() -> SF.star(effective_temperature = t + 2 * bound)),
                         "effective_temperature", "disagrees")

        modelled = SF.star(structure = SF.linear_model(), spectrum = SF.grid())
        l = value(modelled.luminosity)
        @test SF.star(structure = SF.linear_model(), luminosity = l) isa Systems.Star
        @test SF.refused(SF.caught(() -> SF.star(structure = SF.linear_model(), luminosity = 2 * l)),
                         "luminosity", "disagrees")
        @test SF.refused(SF.caught(() -> SF.star(luminosity = l)), "luminosity", "second value")
    end
end
