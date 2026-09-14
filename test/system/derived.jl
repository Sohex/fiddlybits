using Test
using Fiddlybits: Systems, Dispositions, Dimensions, Reductions, Verdicts
import .SystemFixtures as SF

# The Derived fields of System: enumerated from the struct, recomputed by rederive,
# each rule within its declared rounding of a 256-bit evaluation, and a supplied
# value checked against it. docs/plans/fiddlybits-52v.4-system.md, section "Oracles".

@testset "system Derived fields" begin
    value = Dispositions.value
    one_ = Dimensions.DIMENSIONLESS
    figure(T, c) = Systems.HydrostaticFigure(moment_of_inertia_factor = SF.irreducible(T(c), one_))
    hydrostatic(T; kw...) = SF.system(T; planet = SF.planet(T; figure = figure(T, T(33) / 100), kw...))
    hydrostatics() = Tuple(s for T in (Float64, Float32)
                           for s in (hydrostatic(T), hydrostatic(T; rotation = Systems.SynchronousRotation())))
    flattening_path = (:planet, :figure, :flattening)

    @testset "derived_fields enumerates every Derived value from the struct" begin
        paths(s) = [p for (p, _) in Systems.derived_fields(s)]
        @test paths(SF.system()) == [(:stars, 1, :effective_temperature),
                                     (:orbits, :planet, :mean_longitude_at_epoch)]
        @test paths(hydrostatic(Float64)) == [(:stars, 1, :effective_temperature), flattening_path,
                                              (:orbits, :planet, :mean_longitude_at_epoch)]
        @test flattening_path in paths(hydrostatic(Float32; rotation = Systems.SynchronousRotation()))
        @test (:orbits, :planet, :mean_longitude_at_epoch) in paths(SF.flux_system())
        @test !((:orbits, :moons, 1, :mean_longitude_at_epoch) in paths(SF.system()))
        @test (:planet, :rotation, :period) in paths(SF.synchronous_system())
        @test (:orbits, :planet, :semi_major_axis) in paths(SF.flux_system())
        modelled = SF.system(stars = (SF.star(structure = SF.linear_model(), spectrum = SF.grid()),))
        @test Set(paths(modelled)) == Set([(:stars, 1, :luminosity), (:stars, 1, :radius),
                                           (:stars, 1, :effective_temperature),
                                           (:stars, 1, :spectrum, :surface_flux_density),
                                           (:orbits, :planet, :mean_longitude_at_epoch)])
    end

    @testset "rederive reproduces every Derived field" begin
        instances = (SF.system(), SF.system(Float32), SF.two_star_system(),
                     SF.synchronous_system(), SF.flux_system(), SF.circumbinary_system(),
                     SF.system(stars = (SF.star(structure = SF.linear_model(), spectrum = SF.grid()),)),
                     hydrostatics()...)
        for s in instances, (path, d) in Systems.derived_fields(s)
            @test Systems.rederive(s, path) == value(d)
        end
        @test SF.refused(SF.caught(() -> Systems.rederive(SF.system(), (:planet, :mass))),
                         "path", "no Derived value")
    end

    # `s` holding `flattening` as its planet's figure, through the inner constructors.
    function holding(s, flattening)
        p = Systems.with_figure(s.planet, flattening)
        FT = typeof(value(p.mass))
        return Systems.System{FT,typeof(s.stars),typeof(p),typeof(s.orbits),typeof(s.moons),
                              typeof(s.inventories),typeof(s.numerics)}(
            Systems.Checked(), s.stars, p, s.orbits, s.moons, s.inventories, s.numerics, s.root_seed)
    end

    @testset "rederive reproduces the flattening within flattening_rounding" begin
        for s in hydrostatics()
            T = typeof(value(s.planet.mass))
            f = value(Systems.at_path(s, flattening_path))
            @test abs(Systems.rederive(s, flattening_path) - f) <= Systems.flattening_rounding(T, f)
        end

        @testset "control: a held flattening its declared factor does not give disagrees with rederive" begin
            for s in hydrostatics()
                T = typeof(value(s.planet.mass))
                uniform = Systems.hydrostatic_flattening(figure(T, T(2) / 5), s.planet).flattening
                mismatched = holding(s, Systems.HydrostaticFlattening{T,4}(
                    Systems.Checked(), s.planet.figure.moment_of_inertia_factor, uniform))
                f = value(Systems.at_path(mismatched, flattening_path))
                @test abs(Systems.rederive(mismatched, flattening_path) - f) >
                      Systems.flattening_rounding(T, f)
            end
        end

        @testset "control: a rule renamed is refused" begin
            s = hydrostatic(Float64)
            d = s.planet.figure.flattening
            renamed = Dispositions.Derived(value = value(d), dim = one_, from = d.from,
                                           rule = :darwin_radau, fields = Systems.PLANET_FIELDS)
            r = holding(s, Systems.HydrostaticFlattening{Float64,4}(
                Systems.Checked(), s.planet.figure.moment_of_inertia_factor, renamed))
            @test flattening_path in [p for (p, _) in Systems.derived_fields(r)]
            @test SF.refused(SF.caught(() -> Systems.rederive(r, flattening_path)),
                             "rule", "no rule named darwin_radau")
        end
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

    @testset "rotation_sense is Derived from the obliquity" begin
        one_ = Dimensions.DIMENSIONLESS
        prograde = SF.planet(obliquity = SF.irreducible(0.1, one_))
        retrograde = SF.planet(obliquity = SF.irreducible(pi - 0.1, one_))
        in_plane = SF.planet(obliquity = SF.irreducible(Float64(pi) / 2, one_))
        @test Systems.rotation_sense(prograde) === :prograde
        @test Systems.rotation_sense(retrograde) === :retrograde
        @test Systems.rotation_sense(in_plane) === Verdicts.NotEvaluable()
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
