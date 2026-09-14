# SyntheticRetrograde(): retrograde spin, two stars, t = 0 at the planet's periapsis,
# its longitude of periapsis zero. docs/plans/fiddlybits-52v.4-system.md, section
# "The instances"; decision 0034.

"""
    SyntheticRetrograde(::Type{FT} = Float64)

None of its fields is a real body's. The planet's orbit declares
`longitude_of_periapsis = 0`; since the planet's mean longitude at the epoch is zero
by the root origin of decision 0004, its mean anomaly at `t = 0` is `-longitude_of_periapsis
= 0`, the periapsis passage. The obliquity lies past `pi / 2` from the orbit normal, so
`Systems.rotation_sense` is retrograde.
"""
function SyntheticRetrograde(::Type{FT} = Float64) where {FT}
    star(mass, luminosity, radius, seed_sweep) = S.Star(
        mass = bracket(FT(mass), FT(mass) / 2, FT(mass) * 2, D.MASS,
            "the low end of the declared mass", "the high end of the declared mass",
            seed_sweep),
        age = irreducible(FT(1e17), D.TIME, "a declared instance; no body is real",
            "none: a declared instance"),
        metal_mass_fraction = bracket(FT(0.015), FT(0.01), FT(0.02), ONE,
            "the low end of the declared fraction", "the high end of the declared fraction",
            seed_sweep),
        structure = S.DeclaredStructure(
            luminosity = bracket(FT(luminosity), FT(luminosity) / 2, FT(luminosity) * 2,
                S.POWER, "the low end of the declared luminosity",
                "the high end of the declared luminosity", seed_sweep),
            radius = bracket(FT(radius), FT(radius) / 2, FT(radius) * 2, D.LENGTH,
                "the low end of the declared radius", "the high end of the declared radius",
                seed_sweep));
        star_extras(FT)...)

    star1 = star(1.6e30, 2.5e26, 6e8, :synthetic_retrograde)
    star2 = star(8e29, 4e25, 4e8, :synthetic_retrograde)

    planet = S.Planet(
        mass = bracket(FT(9e24), FT(6e24), FT(1.2e25), D.MASS,
            "the low end of the declared mass", "the high end of the declared mass",
            :synthetic_retrograde),
        bulk = S.DeclaredBulk(volumetric_mean_radius = bracket(FT(6.8e6), FT(6e6), FT(7.6e6),
            D.LENGTH, "the low end of the declared radius",
            "the high end of the declared radius", :synthetic_retrograde)),
        rotation = S.SiderealRotation(period = bracket(FT(9e4), FT(7e4), FT(1.1e5), D.TIME,
            "the low end of the declared period", "the high end of the declared period",
            :synthetic_retrograde)),
        obliquity = bracket(FT(2.8), FT(2.6), FT(3.0), ONE,
            "the low end of the declared obliquity", "the high end of the declared obliquity",
            :synthetic_retrograde),
        equator_ascending_node_longitude = irreducible(FT(0.9), ONE,
            "a declared instance; no body is real", "none: a declared instance"),
        sub_primary_longitude_at_epoch = irreducible(FT(-0.5), ONE,
            "a declared instance; no body is real", "none: a declared instance"),
        figure = S.AbsentFigure(equator_pole_gravity_difference =
            bracket(FT(0.06), zero(FT), FT(0.15), S.ACCELERATION,
                "slower rotation and a denser core",
                "faster rotation and a less centrally condensed interior",
                :synthetic_retrograde)),
        lithosphere = lithosphere(FT;
            potential_temperature = 1700, diffusivity = 1.1e-6, expansivity = 3.2e-5,
            density = 3450, radiogenic = 6e-12, crustal_density = (3000, 2800),
            crustal_thickness = (6.5e3, 3.8e4),
            pushes_down = "secular cooling with age and a smaller mass",
            pushes_up = "the radiogenic inventory of the bulk composition and a larger mass",
            sweep = :synthetic_retrograde))

    planet_orbit = S.Orbit(
        primary = S.StarBody(1), secondary = S.PlanetBody(),
        reference_plane = :invariable_plane,
        semi_major_axis = bracket(FT(2.2e11), FT(1.5e11), FT(3e11), D.LENGTH,
            "the low end of the declared semi-major axis",
            "the high end of the declared semi-major axis", :synthetic_retrograde),
        eccentricity = bracket(FT(0.3), FT(0.2), FT(0.4), ONE,
            "the low end of the declared eccentricity",
            "the high end of the declared eccentricity", :synthetic_retrograde),
        inclination = irreducible(zero(FT), ONE,
            "the planet's orbit names the root plane its own normal defines in this " *
            "instance", "none: a declared instance"),
        longitude_of_ascending_node = irreducible(zero(FT), ONE,
            "the node does not exist at zero inclination (decision 0004); nothing reads it",
            "none: the degenerate case of decision 0004"),
        longitude_of_periapsis = irreducible(zero(FT), ONE,
            "declared so that t = 0, the epoch, is the planet's periapsis passage " *
            "(decision 0004, section The reference directions of the orbit hierarchy)",
            "the planet's phase in its orbit at t = 0"))

    companion_orbit = S.Orbit(
        primary = S.StarBody(1), secondary = S.StarBody(2),
        reference_plane = :invariable_plane,
        semi_major_axis = bracket(FT(4e12), FT(3e12), FT(5e12), D.LENGTH,
            "the low end of the declared semi-major axis",
            "the high end of the declared semi-major axis", :synthetic_retrograde),
        eccentricity = bracket(FT(0.15), FT(0.05), FT(0.25), ONE,
            "the low end of the declared eccentricity",
            "the high end of the declared eccentricity", :synthetic_retrograde),
        inclination = irreducible(zero(FT), ONE,
            "a declared instance; no body is real", "none: a declared instance"),
        longitude_of_ascending_node = irreducible(zero(FT), ONE,
            "the node does not exist at zero inclination (decision 0004); nothing reads it",
            "none: the degenerate case of decision 0004"),
        longitude_of_periapsis = irreducible(FT(1.4), ONE,
            "a declared instance; no body is real", "none: a declared instance"),
        mean_longitude_at_epoch = irreducible(FT(0.6), ONE,
            "a declared instance; no body is real", "none: a declared instance"))

    return S.System(
        stars = (star1, star2), planet = planet,
        orbits = S.OrbitHierarchy(planet = planet_orbit, moons = (),
                                  companions = (companion_orbit,)),
        moons = (),
        inventories = S.Inventories(
            volatiles = S.SpeciesAmounts(species = (:H2O, :N2, :CO2),
                amounts = (bracket(FT(8e20), FT(4e20), FT(1.2e21), D.MASS,
                                   "the low end of the declared inventory",
                                   "the high end of the declared inventory",
                                   :synthetic_retrograde),
                          bracket(FT(4e18), FT(2e18), FT(6e18), D.MASS,
                                  "the low end of the declared inventory",
                                  "the high end of the declared inventory",
                                  :synthetic_retrograde),
                          bracket(FT(9e19), FT(4e19), FT(1.4e20), D.MASS,
                                  "the low end of the declared inventory",
                                  "the high end of the declared inventory",
                                  :synthetic_retrograde))),
            crust = S.Fractions(basis = :mass, members = (:SiO2, :Al2O3, :other),
                fractions = (bracket(FT(0.58), FT(0.48), FT(0.68), ONE,
                                     "the low end of the declared fraction",
                                     "the high end of the declared fraction",
                                     :synthetic_retrograde),
                            bracket(FT(0.22), FT(0.12), FT(0.32), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_retrograde),
                            bracket(FT(0.2), FT(0.1), FT(0.3), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_retrograde))),
            ocean_solutes = S.Fractions(basis = :mass, members = (:Cl, :other),
                fractions = (bracket(FT(0.52), FT(0.42), FT(0.62), ONE,
                                     "the low end of the declared fraction",
                                     "the high end of the declared fraction",
                                     :synthetic_retrograde),
                            bracket(FT(0.48), FT(0.38), FT(0.58), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_retrograde))),
            atmosphere = S.Fractions(basis = :mole, members = (:N2, :CO2),
                fractions = (bracket(FT(0.85), FT(0.75), FT(0.92), ONE,
                                     "the low end of the declared fraction",
                                     "the high end of the declared fraction",
                                     :synthetic_retrograde),
                            bracket(FT(0.15), FT(0.08), FT(0.25), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_retrograde))),
            condensable = :H2O),
        numerics = S.Numerics(
            exner_reference_pressure = exner_reference_pressure(FT(1.1e5)),
            geometry_precision = Float64),
        root_seed = seed(3))
end
