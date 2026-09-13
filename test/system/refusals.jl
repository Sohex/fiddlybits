using Test
using Fiddlybits: Systems, Dispositions, Dimensions
import .SystemFixtures as SF

# The System constructor's refusals: docs/plans/fiddlybits-52v.4-system.md, section
# "The struct", the refusal table. Each testset is one control, named as the row's
# acceptance names it.

@testset "system refusals" begin
    @testset "every fixture constructs" begin
        @test SF.system() isa Systems.System
        @test SF.system(Float32) isa Systems.System{Float32}
        @test SF.two_star_system() isa Systems.System
        @test SF.synchronous_system() isa Systems.System
        @test SF.flux_system() isa Systems.System
    end

    @testset "each block omitted in turn" begin
        full = SF.system_keywords()
        for key in keys(full)
            without = Base.structdiff(full, NamedTuple{(key,)})
            @test SF.refused(SF.caught(() -> Systems.System(; without...)),
                             String(key), "missing")
        end
    end

    @testset "a keyword spelled day" begin
        @test SF.refused(SF.caught(() -> SF.system(day = 1.0)), "day", "field named day")
        @test SF.refused(SF.caught(() -> SF.system(mean_solar_day = 1.0)),
                         "mean_solar_day", "field named day")
        @test SF.refused(SF.caught(() -> SF.planet(day = 1.0)), "day", "field named day")
        @test SF.refused(SF.caught(() -> SF.system(daylight = 1.0)), "daylight", "not a keyword")
    end

    @testset "a supplied surface gravity disagreeing with the computed value" begin
        s = SF.system()
        p = s.planet
        r = Dispositions.value(p.volumetric_mean_radius)
        for (name, phi) in ((:equatorial_surface_gravity, 0.0), (:polar_surface_gravity, pi / 2))
            g = Systems.gravity(p, r, phi)
            bound = Systems.rounding_bound(Float64, Systems.GRAVITY_TERMS,
                                           Systems.gravity_magnitude(p, r, phi))
            exact = Float64(SF.gravity_256(p, r, phi))
            @test SF.system(; name => g) isa Systems.System
            @test SF.system(; name => exact) isa Systems.System
            @test SF.refused(SF.caught(() -> SF.system(; name => g + 2 * bound)),
                             String(name), "disagrees")
            @test SF.refused(SF.caught(() -> SF.system(; name => Float32(g))),
                             String(name), "not a Float64")
        end
    end

    @testset "a Derived value supplied beside its declaration" begin
        @test SF.refused(SF.caught(() -> SF.system(sidereal_rotation_period = 1e5)),
                         "sidereal_rotation_period", "second value")
        @test SF.refused(SF.caught(() -> SF.system(semi_major_axis = 1.8e11)),
                         "semi_major_axis", "second value")
    end

    @testset "the flux-form planet orbit with two stars declared" begin
        orbits = Systems.OrbitHierarchy(planet = SF.flux_orbit(), moons = (SF.moon_orbit(),),
                                        companions = (SF.companion_orbit(),))
        e = SF.caught(() -> SF.two_star_system(orbits = orbits))
        @test SF.refused(e, "flux_at_semi_major_axis", "2 stars")
        @test SF.flux_system() isa Systems.System
    end

    @testset "a stellar model evaluated above its domain" begin
        model = SF.linear_model()
        inside = SF.star(structure = model, spectrum = SF.grid())
        @test inside.luminosity isa Dispositions.Derived
        above = SF.bracket(5e30, 4.5e30, 5.5e30, Dimensions.MASS)
        @test SF.refused(SF.caught(() -> SF.star(structure = model, mass = above)),
                         "mass", "above the domain")
        reaching = SF.bracket(3.5e30, 3e30, 4.5e30, Dimensions.MASS)
        @test SF.refused(SF.caught(() -> SF.star(structure = model, mass = reaching)),
                         "mass", "above the domain")
        below = SF.bracket(3e29, 2e29, 4e29, Dimensions.MASS)
        @test SF.refused(SF.caught(() -> SF.star(structure = model, mass = below)),
                         "mass", "below the domain")
    end

    @testset "a spectrum interpolated outside the grid hull" begin
        structure(l) = Systems.DeclaredStructure(luminosity = SF.wide(l, Systems.POWER),
                                                 radius = SF.wide(6e8, Dimensions.LENGTH))
        hot = SF.star(spectrum = SF.grid())
        @test hot.spectrum isa Systems.GridSpectrum
        @test SF.refused(SF.caught(() -> SF.star(structure = structure(1e25), spectrum = SF.grid())),
                         "spectrum", "outside its convex hull")
        @test SF.refused(SF.caught(() -> SF.star(spectrum = SF.grid(hole = true))),
                         "spectrum", "absent from the grid")
        @test SF.star(structure = structure(6.6e25), spectrum = SF.grid(hole = true)).spectrum isa
              Systems.GridSpectrum
    end

    @testset "a scalar where one value per province class is required" begin
        scalar = SF.wide(2900.0, Systems.DENSITY)
        @test SF.refused(SF.caught(() -> SF.lithosphere(crustal_density = scalar)),
                         "crustal_density", "REQ-SYS-103")
        @test SF.refused(SF.caught(() -> SF.lithosphere(crustal_density = (scalar,))),
                         "crustal_density", "where 2")
    end

    @testset "an eccentricity of one and of one and a half" begin
        one_ = Dimensions.DIMENSIONLESS
        for e in (1.0, 1.5)
            @test SF.refused(SF.caught(() -> SF.planet_orbit(eccentricity = SF.irreducible(e, one_))),
                             "eccentricity", "elliptic range")
        end
        @test SF.refused(SF.caught(() -> SF.planet_orbit(eccentricity = SF.bracket(0.5, 0.1, 1.0, one_))),
                         "eccentricity", "elliptic range")
        @test SF.refused(SF.caught(() -> SF.planet_orbit(eccentricity = SF.irreducible(-0.1, one_))),
                         "eccentricity", "elliptic range")
        @test SF.planet_orbit(eccentricity = SF.irreducible(prevfloat(1.0), one_)) isa Systems.Orbit
        @test SF.planet_orbit(eccentricity = SF.irreducible(0.0, one_)) isa Systems.Orbit
    end

    @testset "a sense keyword on a rotation" begin
        @test SF.refused(SF.caught(() -> Systems.SiderealRotation(
                             period = SF.wide(1e5, Dimensions.TIME), sense = :prograde)),
                         "sense", "not a keyword")
    end

    @testset "an obliquity outside [0, pi]" begin
        one_ = Dimensions.DIMENSIONLESS
        @test SF.refused(SF.caught(() -> SF.planet(obliquity = SF.irreducible(-0.1, one_))),
                         "obliquity", "lies outside")
        @test SF.refused(SF.caught(() -> SF.planet(obliquity = SF.irreducible(3.2, one_))),
                         "obliquity", "lies outside")
        @test SF.planet(obliquity = SF.irreducible(0.0, one_)) isa Systems.Planet
        @test SF.planet(obliquity = SF.irreducible(Float64(pi), one_)) isa Systems.Planet
    end

    @testset "a sub-primary longitude at the epoch omitted, and outside (-pi, pi]" begin
        one_ = Dimensions.DIMENSIONLESS
        without = Base.structdiff(SF.planet_keywords(),
                                  NamedTuple{(:sub_primary_longitude_at_epoch,)})
        @test SF.refused(SF.caught(() -> Systems.Planet(; without...)),
                         "sub_primary_longitude_at_epoch", "missing")
        @test SF.refused(SF.caught(() -> SF.planet(
                             sub_primary_longitude_at_epoch = SF.irreducible(3.5, one_))),
                         "sub_primary_longitude_at_epoch", "lies outside")
        @test SF.refused(SF.caught(() -> SF.planet(
                             sub_primary_longitude_at_epoch = SF.irreducible(-pi, one_))),
                         "sub_primary_longitude_at_epoch", "lies outside")
        @test SF.planet(sub_primary_longitude_at_epoch = SF.irreducible(Float64(pi), one_)) isa
              Systems.Planet
    end

    @testset "a synchronous rotation whose Derived sense is not prograde" begin
        one_ = Dimensions.DIMENSIONLESS
        retrograde = SF.planet(rotation = Systems.SynchronousRotation(),
                               obliquity = SF.irreducible(3 * pi / 4, one_))
        in_plane = SF.planet(rotation = Systems.SynchronousRotation(),
                             obliquity = SF.irreducible(Float64(pi) / 2, one_))
        @test SF.refused(SF.caught(() -> SF.system(planet = retrograde)), "rotation", "prograde")
        @test SF.refused(SF.caught(() -> SF.system(planet = in_plane)), "rotation", "prograde")
        @test SF.synchronous_system() isa Systems.System
    end

    @testset "the equinox kind at zero obliquity" begin
        one_ = Dimensions.DIMENSIONLESS
        @test SF.refused(SF.caught(() -> SF.flux_system(planet = SF.planet(obliquity = SF.irreducible(0.0, one_)))),
                         "obliquity", "vernal equinox")
        @test SF.refused(SF.caught(() -> SF.flux_system(planet = SF.planet(obliquity = SF.bracket(0.4, 0.0, 0.6, one_)))),
                         "obliquity", "vernal equinox")
        @test SF.flux_system(planet = SF.planet(obliquity = SF.irreducible(1e-10, one_))) isa Systems.System
    end

    @testset "the equinox kind with no single primary" begin
        epoch(i) = SF.numerics(epoch = Systems.EpochReference(
            kind = :vernal_equinox, source = Systems.StarBody(i),
            offset = SF.irreducible(0.0, Dimensions.TIME)))
        circumbinary = Systems.OrbitHierarchy(
            planet = SF.planet_orbit(primary = Systems.StarBarycentre(1, 2)),
            moons = (SF.moon_orbit(),), companions = (SF.companion_orbit(),))
        @test SF.refused(SF.caught(() -> SF.two_star_system(orbits = circumbinary, numerics = epoch(1))),
                         "epoch", "single primary")
        @test SF.refused(SF.caught(() -> SF.two_star_system(numerics = epoch(2))),
                         "epoch", "single primary")
        @test SF.two_star_system(numerics = epoch(1)) isa Systems.System
    end

    @testset "an orbit hierarchy that does not name every body once" begin
        @test SF.refused(SF.caught(() -> SF.system(stars = (SF.star(), SF.star()))),
                         "orbits", "every star but one")
        @test SF.refused(SF.caught(() -> SF.system(moons = ())), "orbits", "moon")
        @test SF.refused(SF.caught(() -> SF.moon_orbit(primary = Systems.StarBody(1))),
                         "primary", "not a primary")
    end
end
