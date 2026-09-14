# SyntheticComposition2(): a hydrogen-helium bulk with a different condensable
# declared absent. docs/plans/fiddlybits-52v.4-system.md, section "The instances";
# decision 0034.

"""
    SyntheticComposition2(::Type{FT} = Float64)

None of its fields is a real body's. `bulk` is a `DeclaredBulk`: no `InteriorModel`
implementation carries a `Sourced` mass-radius law in this tree yet
(`fiddlybits-52v.4.22`), so the hydrogen-helium composition is carried at the
inventory level instead, in `atmosphere` and `volatiles`. `condensable` is a
`NoCondensable`, the different condensable declared absent. The planet's orbit is a
`FluxOrbit`, admissible because the system declares one star; `System` holds its
semi-major axis as `Derived` by `Systems.semi_major_axis_from_flux`.
"""
function SyntheticComposition2(::Type{FT} = Float64) where {FT}
    star = S.Star(
        mass = bracket(FT(1.8e30), FT(1.4e30), FT(2.2e30), D.MASS,
            "the low end of the declared mass", "the high end of the declared mass",
            :synthetic_composition2),
        age = irreducible(FT(2.5e17), D.TIME, "a declared instance; no body is real",
            "none: a declared instance"),
        metal_mass_fraction = bracket(FT(0.018), FT(0.01), FT(0.025), ONE,
            "the low end of the declared fraction", "the high end of the declared fraction",
            :synthetic_composition2),
        structure = S.DeclaredStructure(
            luminosity = bracket(FT(3e26), FT(1.5e26), FT(6e26), S.POWER,
                "the low end of the declared luminosity",
                "the high end of the declared luminosity", :synthetic_composition2),
            radius = bracket(FT(6.5e8), FT(3.25e8), FT(1.3e9), D.LENGTH,
                "the low end of the declared radius", "the high end of the declared radius",
                :synthetic_composition2));
        star_extras(FT)...)

    planet = S.Planet(
        mass = bracket(FT(6e24), FT(4e24), FT(8e24), D.MASS,
            "the low end of the declared mass", "the high end of the declared mass",
            :synthetic_composition2),
        bulk = S.DeclaredBulk(volumetric_mean_radius = bracket(FT(1e7), FT(8e6), FT(1.2e7),
            D.LENGTH, "the low end of the declared radius",
            "the high end of the declared radius", :synthetic_composition2)),
        rotation = S.SiderealRotation(period = bracket(FT(1.1e5), FT(9e4), FT(1.3e5), D.TIME,
            "the low end of the declared period", "the high end of the declared period",
            :synthetic_composition2)),
        obliquity = bracket(FT(0.3), FT(0.1), FT(0.5), ONE,
            "the low end of the declared obliquity", "the high end of the declared obliquity",
            :synthetic_composition2),
        equator_ascending_node_longitude = irreducible(FT(0.4), ONE,
            "a declared instance; no body is real", "none: a declared instance"),
        sub_primary_longitude_at_epoch = irreducible(FT(0.1), ONE,
            "a declared instance; no body is real", "none: a declared instance"),
        figure = S.AbsentFigure(equator_pole_gravity_difference =
            bracket(FT(0.04), zero(FT), FT(0.1), S.ACCELERATION,
                "slower rotation and a denser core",
                "faster rotation and a less centrally condensed interior",
                :synthetic_composition2)),
        lithosphere = lithosphere(FT;
            potential_temperature = 1650, diffusivity = 1e-6, expansivity = 3e-5,
            density = 3300, radiogenic = 5e-12, crustal_density = (2950, 2750),
            crustal_thickness = (6e3, 3.6e4),
            pushes_down = "secular cooling with age and a smaller mass",
            pushes_up = "the radiogenic inventory of the bulk composition and a larger mass",
            sweep = :synthetic_composition2))

    orbit = S.FluxOrbit(
        primary = S.StarBody(1), secondary = S.PlanetBody(),
        reference_plane = :invariable_plane,
        flux_at_semi_major_axis = bracket(FT(3000), FT(2000), FT(4000), S.IRRADIANCE,
            "the low end of the declared flux", "the high end of the declared flux",
            :synthetic_composition2),
        eccentricity = bracket(FT(0.2), FT(0.1), FT(0.3), ONE,
            "the low end of the declared eccentricity",
            "the high end of the declared eccentricity", :synthetic_composition2),
        inclination = irreducible(zero(FT), ONE,
            "one planet and no companion star reads the invariable plane's tilt in this " *
            "instance", "none: a declared instance"),
        longitude_of_ascending_node = irreducible(zero(FT), ONE,
            "the node does not exist at zero inclination (decision 0004); nothing reads it",
            "none: the degenerate case of decision 0004"),
        longitude_of_periapsis = irreducible(FT(0.5), ONE,
            "a declared instance; no body is real", "none: a declared instance"))

    return S.System(
        stars = (star,), planet = planet,
        orbits = S.OrbitHierarchy(planet = orbit, moons = (), companions = ()),
        moons = (),
        inventories = S.Inventories(
            volatiles = S.SpeciesAmounts(species = (:H2, :He, :CH4),
                amounts = (bracket(FT(3e23), FT(2e23), FT(4e23), D.MASS,
                                   "the low end of the declared inventory",
                                   "the high end of the declared inventory",
                                   :synthetic_composition2),
                          bracket(FT(1e23), FT(6e22), FT(1.4e23), D.MASS,
                                  "the low end of the declared inventory",
                                  "the high end of the declared inventory",
                                  :synthetic_composition2),
                          bracket(FT(2e19), FT(1e19), FT(3e19), D.MASS,
                                  "the low end of the declared inventory",
                                  "the high end of the declared inventory",
                                  :synthetic_composition2))),
            crust = S.Fractions(basis = :mass, members = (:Fe, :other),
                fractions = (bracket(FT(0.3), FT(0.2), FT(0.4), ONE,
                                     "the low end of the declared fraction",
                                     "the high end of the declared fraction",
                                     :synthetic_composition2),
                            bracket(FT(0.7), FT(0.6), FT(0.8), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_composition2))),
            ocean_solutes = S.Fractions(basis = :mass, members = (:Cl, :other),
                fractions = (bracket(FT(0.5), FT(0.4), FT(0.6), ONE,
                                     "the low end of the declared fraction",
                                     "the high end of the declared fraction",
                                     :synthetic_composition2),
                            bracket(FT(0.5), FT(0.4), FT(0.6), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_composition2))),
            atmosphere = S.Fractions(basis = :mole, members = (:H2, :He),
                fractions = (bracket(FT(0.86), FT(0.8), FT(0.9), ONE,
                                     "the low end of the declared fraction",
                                     "the high end of the declared fraction",
                                     :synthetic_composition2),
                            bracket(FT(0.14), FT(0.1), FT(0.2), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_composition2))),
            condensable = S.NoCondensable(
                argument = "a hydrogen-helium envelope carries no tracked species that " *
                          "condenses at this system's declared temperatures")),
        numerics = S.Numerics(
            exner_reference_pressure = bracket(FT(1e5), FT(7e4), FT(1.3e5), S.PRESSURE,
                "the low end of the declared reference pressure",
                "the high end of the declared reference pressure", :synthetic_composition2),
            geometry_precision = Float64),
        root_seed = seed(4))
end
