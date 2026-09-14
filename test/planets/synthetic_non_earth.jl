# SyntheticNonEarth(): a carbon-dioxide bulk atmosphere, higher gravity, prograde spin,
# high eccentricity, non-zero obliquity, one star, one moon.
# docs/plans/fiddlybits-52v.4-system.md, section "The instances"; decision 0034.

"""
    SyntheticNonEarth(::Type{FT} = Float64)

None of its fields is a real body's. The moon's reflectance table is the
normal-incidence Fresnel reflectance of water at six wavelengths, from the read
optical constants of Hale and Querry (1973), a real measured spectrum carried by a
fictional moon; every other field is a declared `Bracketed` or `Irreducible` value.
`figure` is a `HydrostaticFigure`, so the planet's flattening is `Derived` by
`Systems.hydrostatic_flattening` as `System` holds it.
"""
function SyntheticNonEarth(::Type{FT} = Float64) where {FT}
    star = S.Star(
        mass = bracket(FT(2.5e30), FT(2e30), FT(3e30), D.MASS,
            "the low end of the declared mass", "the high end of the declared mass",
            :synthetic_non_earth),
        age = irreducible(FT(2e17), D.TIME, "a declared instance; no body is real",
            "none: a declared instance"),
        metal_mass_fraction = bracket(FT(0.02), FT(0.01), FT(0.03), ONE,
            "the low end of the declared fraction", "the high end of the declared fraction",
            :synthetic_non_earth),
        structure = S.DeclaredStructure(
            luminosity = bracket(FT(5e26), FT(2.5e26), FT(1e27), S.POWER,
                "the low end of the declared luminosity",
                "the high end of the declared luminosity", :synthetic_non_earth),
            radius = bracket(FT(7e8), FT(3.5e8), FT(1.4e9), D.LENGTH,
                "the low end of the declared radius", "the high end of the declared radius",
                :synthetic_non_earth));
        star_extras(FT)...)

    planet = S.Planet(
        mass = bracket(FT(1.5e25), FT(1e25), FT(2e25), D.MASS,
            "the low end of the declared mass", "the high end of the declared mass",
            :synthetic_non_earth),
        bulk = S.DeclaredBulk(volumetric_mean_radius = bracket(FT(6.5e6), FT(6e6), FT(7e6),
            D.LENGTH, "the low end of the declared radius",
            "the high end of the declared radius", :synthetic_non_earth)),
        rotation = S.SiderealRotation(period = bracket(FT(8e4), FT(6e4), FT(1e5), D.TIME,
            "the low end of the declared period", "the high end of the declared period",
            :synthetic_non_earth)),
        obliquity = bracket(FT(0.5), FT(0.3), FT(0.7), ONE,
            "the low end of the declared obliquity", "the high end of the declared obliquity",
            :synthetic_non_earth),
        equator_ascending_node_longitude = irreducible(FT(1.0), ONE,
            "a declared instance; no body is real", "none: a declared instance"),
        sub_primary_longitude_at_epoch = irreducible(FT(0.2), ONE,
            "a declared instance; no body is real", "none: a declared instance"),
        figure = S.HydrostaticFigure(moment_of_inertia_factor =
            bracket(FT(0.3), FT(0.28), FT(0.32), ONE,
                "a more centrally condensed interior",
                "a less centrally condensed interior, closer to uniform density",
                :synthetic_non_earth)),
        lithosphere = lithosphere(FT;
            potential_temperature = 1800, diffusivity = 1.2e-6, expansivity = 3.5e-5,
            density = 3600, radiogenic = 8e-12, crustal_density = (3100, 2900),
            crustal_thickness = (5e3, 3e4),
            pushes_down = "secular cooling with age and a smaller mass",
            pushes_up = "the radiogenic inventory of the bulk composition and a larger mass",
            sweep = :synthetic_non_earth))

    orbit = S.Orbit(
        primary = S.StarBody(1), secondary = S.PlanetBody(),
        reference_plane = :invariable_plane,
        semi_major_axis = bracket(FT(2.5e11), FT(1.5e11), FT(3.5e11), D.LENGTH,
            "the low end of the declared semi-major axis",
            "the high end of the declared semi-major axis", :synthetic_non_earth),
        eccentricity = bracket(FT(0.5), FT(0.3), FT(0.7), ONE,
            "the low end of the declared eccentricity",
            "the high end of the declared eccentricity", :synthetic_non_earth),
        inclination = irreducible(zero(FT), ONE,
            "one planet and no companion star reads the invariable plane's tilt in this " *
            "instance", "none: a declared instance"),
        longitude_of_ascending_node = irreducible(zero(FT), ONE,
            "the node does not exist at zero inclination (decision 0004); nothing reads it",
            "none: the degenerate case of decision 0004"),
        longitude_of_periapsis = irreducible(FT(0.8), ONE,
            "a declared instance; no body is real", "none: a declared instance"))

    # Water's optical constants n(lambda), k(lambda) at six wavelengths, Hale and
    # Querry (1973), Table 1, p. 557: (0.500, 1.00e-9, 1.335), (0.600, 1.09e-8, 1.332),
    # (0.700, 3.35e-8, 1.331), (1.0, 2.89e-6, 1.327), (1.6, 8.55e-5, 1.317),
    # (2.0, 1.1e-3, 1.306), wavelengths in micrometres. The normal-incidence
    # reflectance R = ((n - 1)^2 + k^2) / ((n + 1)^2 + k^2) is computed here.
    water_optical_constants = ((5.0e-7, FT(1.00e-9), FT(1.335)), (6.0e-7, FT(1.09e-8), FT(1.332)),
                               (7.0e-7, FT(3.35e-8), FT(1.331)), (1.0e-6, FT(2.89e-6), FT(1.327)),
                               (1.6e-6, FT(8.55e-5), FT(1.317)), (2.0e-6, FT(1.1e-3), FT(1.306)))
    fresnel_reflectance(n, k) = ((n - 1)^2 + k^2) / ((n + 1)^2 + k^2)

    moon = S.Moon(
        mass = bracket(FT(6e22), FT(3e22), FT(9e22), D.MASS,
            "the low end of the declared mass", "the high end of the declared mass",
            :synthetic_non_earth),
        radius = bracket(FT(1.6e6), FT(1.2e6), FT(2e6), D.LENGTH,
            "the low end of the declared radius", "the high end of the declared radius",
            :synthetic_non_earth),
        reflectance = Dispositions.Sourced(
            value = S.ReflectanceTable(
                wavelengths = FT[w for (w, k, n) in water_optical_constants],
                reflectance = FT[fresnel_reflectance(n, k) for (w, k, n) in water_optical_constants]),
            dim = ONE,
            locator = Dispositions.Locator(identifier = "10.1364/AO.12.000555",
                table = "Table 1, optical constants of water n(lambda) and k(lambda) at " *
                        "0.5, 0.6, 0.7, 1.0, 1.6 and 2.0 micrometres; the normal-incidence " *
                        "reflectance is computed from them here")))

    moon_orbit = S.Orbit(
        primary = S.PlanetBody(), secondary = S.MoonBody(1),
        reference_plane = :planet_equator,
        semi_major_axis = bracket(FT(5e8), FT(3e8), FT(7e8), D.LENGTH,
            "the low end of the declared semi-major axis",
            "the high end of the declared semi-major axis", :synthetic_non_earth),
        eccentricity = bracket(FT(0.1), FT(0.05), FT(0.2), ONE,
            "the low end of the declared eccentricity",
            "the high end of the declared eccentricity", :synthetic_non_earth),
        inclination = irreducible(zero(FT), ONE,
            "a declared instance; no body is real", "none: a declared instance"),
        longitude_of_ascending_node = irreducible(zero(FT), ONE,
            "the node does not exist at zero inclination (decision 0004); nothing reads it",
            "none: the degenerate case of decision 0004"),
        longitude_of_periapsis = irreducible(FT(0.4), ONE,
            "a declared instance; no body is real", "none: a declared instance"),
        mean_longitude_at_epoch = irreducible(FT(1.1), ONE,
            "a declared instance; no body is real", "none: a declared instance"))

    return S.System(
        stars = (star,), planet = planet,
        orbits = S.OrbitHierarchy(planet = orbit, moons = (moon_orbit,), companions = ()),
        moons = (moon,),
        inventories = S.Inventories(
            volatiles = S.SpeciesAmounts(species = (:CO2, :N2, :H2O),
                amounts = (bracket(FT(1e20), FT(5e19), FT(2e20), D.MASS,
                                   "the low end of the declared inventory",
                                   "the high end of the declared inventory",
                                   :synthetic_non_earth),
                          bracket(FT(2e18), FT(1e18), FT(3e18), D.MASS,
                                  "the low end of the declared inventory",
                                  "the high end of the declared inventory",
                                  :synthetic_non_earth),
                          bracket(FT(5e19), FT(2e19), FT(8e19), D.MASS,
                                  "the low end of the declared inventory",
                                  "the high end of the declared inventory",
                                  :synthetic_non_earth))),
            crust = S.Fractions(basis = :mass, members = (:SiO2, :FeO, :other),
                fractions = (bracket(FT(0.5), FT(0.4), FT(0.6), ONE,
                                     "the low end of the declared fraction",
                                     "the high end of the declared fraction",
                                     :synthetic_non_earth),
                            bracket(FT(0.3), FT(0.2), FT(0.4), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_non_earth),
                            bracket(FT(0.2), FT(0.1), FT(0.3), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_non_earth))),
            ocean_solutes = S.Fractions(basis = :mass, members = (:Cl, :other),
                fractions = (bracket(FT(0.6), FT(0.5), FT(0.7), ONE,
                                     "the low end of the declared fraction",
                                     "the high end of the declared fraction",
                                     :synthetic_non_earth),
                            bracket(FT(0.4), FT(0.3), FT(0.5), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_non_earth))),
            atmosphere = S.Fractions(basis = :mole, members = (:CO2, :N2),
                fractions = (bracket(FT(0.95), FT(0.9), FT(0.98), ONE,
                                     "the low end of the declared fraction",
                                     "the high end of the declared fraction",
                                     :synthetic_non_earth),
                            bracket(FT(0.05), FT(0.02), FT(0.1), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_non_earth))),
            condensable = :CO2),
        numerics = S.Numerics(
            exner_reference_pressure = bracket(FT(9e6), FT(7e6), FT(1.1e7), S.PRESSURE,
                "the low end of the declared reference pressure",
                "the high end of the declared reference pressure", :synthetic_non_earth),
            geometry_precision = Float64),
        root_seed = seed(1))
end
