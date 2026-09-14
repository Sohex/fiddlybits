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
        @test SF.circumbinary_system() isa Systems.System
    end

    @testset "each block omitted in turn" begin
        full = SF.system_keywords()
        for key in keys(full)
            without = Base.structdiff(full, NamedTuple{(key,)})
            @test SF.refused(SF.caught(() -> Systems.System(; without...)),
                             String(key), "missing")
        end
    end

    @testset "a root seed omitted, and a root seed of another type" begin
        one_ = Dimensions.DIMENSIONLESS
        without = Base.structdiff(SF.system_keywords(), NamedTuple{(:root_seed,)})
        @test SF.refused(SF.caught(() -> Systems.System(; without...)), "root_seed", "missing")
        @test SF.refused(SF.caught(() -> SF.system(root_seed = UInt64(7))),
                         "root_seed", "disposition is required")
        @test SF.refused(SF.caught(() -> SF.system(root_seed = SF.irreducible(7, one_))),
                         "root_seed", "not a UInt64")
        @test SF.refused(SF.caught(() -> SF.system(root_seed = SF.irreducible(7.0, one_))),
                         "root_seed", "not a UInt64")
        @test SF.refused(SF.caught(() -> SF.system(root_seed = SF.irreducible(UInt64(7), Dimensions.TIME))),
                         "root_seed", "dimension")
        @test SF.refused(SF.caught(() -> SF.system(root_seed = SF.bracket(UInt64(7), UInt64(0), UInt64(9), one_))),
                         "root_seed", "Bracketed is not admitted")
        sourced = Dispositions.Sourced(value = UInt64(7), dim = one_,
                                       locator = Dispositions.Locator(identifier = "fixture", table = "fixture table"))
        @test SF.refused(SF.caught(() -> SF.system(root_seed = sourced)), "root_seed", "Sourced is not admitted")

        @testset "positive control: an Irreducible UInt64 seed at each end of its range constructs and carries its argument" begin
            for v in (typemin(UInt64), typemax(UInt64))
                s = SF.system(root_seed = SF.seed(v))
                @test s.root_seed isa Dispositions.Irreducible{UInt64}
                @test Dispositions.value(s.root_seed) === v
                @test !isempty(s.root_seed.argument)
                @test Systems.ROOT_SEED_DISPOSITIONS == (Dispositions.Irreducible,)
            end
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

    @testset "a mean_longitude_at_epoch on the planet's orbit" begin
        one_ = Dimensions.DIMENSIONLESS
        l0 = SF.irreducible(0.5, one_)
        @test SF.refused(SF.caught(() -> SF.planet_orbit(mean_longitude_at_epoch = l0)),
                         "mean_longitude_at_epoch", "second declaration")
        @test SF.refused(SF.caught(() -> SF.flux_orbit(mean_longitude_at_epoch = l0)),
                         "mean_longitude_at_epoch", "second declaration")

        @testset "control: the planet's is the zero of the root origin, and every other orbit declares its own" begin
            for l in (SF.planet_orbit().mean_longitude_at_epoch, SF.flux_orbit().elements[5],
                      SF.flux_system().orbits.planet.mean_longitude_at_epoch)
                @test l isa Dispositions.Derived
                @test l.rule === :root_origin
                @test Dispositions.value(l) === 0.0
            end
            @test Dispositions.value(SF.planet_orbit(Float32).mean_longitude_at_epoch) === 0.0f0
            @test SF.moon_orbit(mean_longitude_at_epoch = l0).mean_longitude_at_epoch === l0
            for form in (SF.moon_orbit, SF.companion_orbit)
                without = (; primary = form().primary, secondary = form().secondary)
                keywords = Base.structdiff(
                    merge(SF.elements(Float64), without,
                          (reference_plane = form().reference_plane,
                           semi_major_axis = form().semi_major_axis)),
                    NamedTuple{(:mean_longitude_at_epoch,)})
                @test SF.refused(SF.caught(() -> Systems.Orbit(; keywords...)),
                                 "mean_longitude_at_epoch", "missing")
            end
        end
    end

    @testset "the replaced orbit keywords" begin
        one_ = Dimensions.DIMENSIONLESS
        for name in (:argument_of_periapsis, :mean_anomaly_at_epoch)
            @test SF.refused(SF.caught(() -> SF.planet_orbit(; name => SF.irreducible(1.0, one_))),
                             String(name), "not a keyword")
            @test SF.refused(SF.caught(() -> SF.moon_orbit(; name => SF.irreducible(1.0, one_))),
                             String(name), "not a keyword")
        end
        without = Base.structdiff(
            merge(SF.elements(Float64), (primary = Systems.StarBody(1), secondary = Systems.PlanetBody(),
                                         reference_plane = :invariable_plane,
                                         semi_major_axis = SF.wide(1.8e11, Dimensions.LENGTH))),
            NamedTuple{(:longitude_of_periapsis,)})
        @test SF.refused(SF.caught(() -> Systems.Orbit(; without...)), "longitude_of_periapsis", "missing")
    end

    @testset "a longitude outside [0, 2 pi)" begin
        one_ = Dimensions.DIMENSIONLESS
        for x in (2 * pi, -0.1)
            d = SF.irreducible(x, one_)
            @test SF.refused(SF.caught(() -> SF.planet(equator_ascending_node_longitude = d)),
                             "equator_ascending_node_longitude", "lies outside")
            @test SF.refused(SF.caught(() -> SF.planet_orbit(longitude_of_ascending_node = d)),
                             "longitude_of_ascending_node", "lies outside")
            @test SF.refused(SF.caught(() -> SF.planet_orbit(longitude_of_periapsis = d)),
                             "longitude_of_periapsis", "lies outside")
            @test SF.refused(SF.caught(() -> SF.moon_orbit(mean_longitude_at_epoch = d)),
                             "mean_longitude_at_epoch", "lies outside")
        end
        @test SF.refused(SF.caught(() -> SF.planet(
                             equator_ascending_node_longitude = SF.bracket(1.0, 0.5, 2 * pi, one_))),
                         "equator_ascending_node_longitude", "lies outside")
        without = Base.structdiff(SF.planet_keywords(), NamedTuple{(:equator_ascending_node_longitude,)})
        @test SF.refused(SF.caught(() -> Systems.Planet(; without...)),
                         "equator_ascending_node_longitude", "missing")
        @test SF.refused(SF.caught(() -> SF.planet(
                             equator_ascending_node_longitude = SF.irreducible(1.0f0, one_))),
                         "equator_ascending_node_longitude", "not a Float64")

        @testset "control: zero and the float below 2 pi construct, in every admitted disposition" begin
            for x in (0.0, prevfloat(2 * pi))
                d = SF.irreducible(x, one_)
                @test Dispositions.value(SF.planet(equator_ascending_node_longitude = d).equator_ascending_node_longitude) === x
                @test SF.planet_orbit(longitude_of_ascending_node = d) isa Systems.Orbit
                @test SF.planet_orbit(longitude_of_periapsis = d) isa Systems.Orbit
                @test SF.moon_orbit(mean_longitude_at_epoch = d) isa Systems.Orbit
            end
            sourced = Dispositions.Sourced(value = 1.0, dim = one_,
                locator = Dispositions.Locator(identifier = "fixture", table = "fixture table"))
            @test SF.planet(equator_ascending_node_longitude = sourced) isa Systems.Planet
            @test SF.planet(equator_ascending_node_longitude = SF.bracket(1.0, 0.5, 1.5, one_)) isa Systems.Planet
            derived = Dispositions.Derived(value = 1.0, dim = one_, from = (:obliquity,),
                                           rule = :fixture, fields = Systems.PLANET_FIELDS)
            @test SF.refused(SF.caught(() -> SF.planet(equator_ascending_node_longitude = derived)),
                             "equator_ascending_node_longitude", "Derived is not admitted")
            @test SF.refused(SF.caught(() -> SF.planet(obliquity = derived)),
                             "obliquity", "Derived is not admitted")
        end
    end

    @testset "primary_equator named by a planet orbit about StarBarycentre(1, 2)" begin
        barycentre = Systems.StarBarycentre(1, 2)
        @test SF.refused(SF.caught(() -> SF.planet_orbit(primary = barycentre,
                                                         reference_plane = :primary_equator)),
                         "reference_plane", "barycentre has no equator")

        @testset "control: primary_equator about a star, and invariable_plane about the barycentre, construct" begin
            @test SF.planet_orbit(reference_plane = :primary_equator).reference_plane === :primary_equator
            @test SF.planet_orbit(primary = barycentre).primary === barycentre
            @test SF.circumbinary_system() isa Systems.System
        end
    end

    @testset "a companion on invariable_plane beside a planet orbit on primary_equator" begin
        on_equator = SF.planet_orbit(reference_plane = :primary_equator)
        e = SF.caught(() -> Systems.OrbitHierarchy(planet = on_equator, moons = (SF.moon_orbit(),),
                                                   companions = (SF.companion_orbit(),)))
        @test SF.refused(e, "companions", "names primary_equator")

        @testset "control: the companion on planet_orbit beside it, and on invariable_plane beside a planet orbit on invariable_plane, construct" begin
            beside = Systems.OrbitHierarchy(
                planet = on_equator, moons = (SF.moon_orbit(),),
                companions = (SF.companion_orbit(reference_plane = :planet_orbit),))
            @test SF.two_star_system(orbits = beside) isa Systems.System
            @test SF.two_star_system().orbits.companions[1].reference_plane === :invariable_plane
            @test SF.two_star_system().orbits.planet.reference_plane === :invariable_plane
        end
    end

    @testset "an orbit hierarchy that does not name every body once" begin
        @test SF.refused(SF.caught(() -> SF.system(stars = (SF.star(), SF.star()))),
                         "orbits", "every star but one")
        @test SF.refused(SF.caught(() -> SF.system(moons = ())), "orbits", "moon")
        @test SF.refused(SF.caught(() -> SF.moon_orbit(primary = Systems.StarBody(1))),
                         "primary", "not a primary")
    end
end
