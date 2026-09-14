# SyntheticSynchronous(): synchronous rotation, zero obliquity, an M-dwarf spectrum,
# no moon. docs/plans/fiddlybits-52v.4-system.md, section "The instances";
# decision 0034.

"""
    SyntheticSynchronous(::Type{FT} = Float64)

None of its fields is a real body's. The planet's sidereal rotation period is
`Derived` as the `SynchronousPeriod` of its orbit (decision 0004, System); zero
obliquity makes the rotation prograde, admitting the synchronous form.
"""
function SyntheticSynchronous(::Type{FT} = Float64) where {FT}
    spectrum = S.BracketedSpectrum(
        wavelengths = FT[6e-7, 1e-6, 1.6e-6],
        surface_flux_density = [bracket(FT(v), FT(v) / 2, FT(v) * 2, S.SPECTRAL_FLUX,
                                        "the low end of the declared band",
                                        "the high end of the declared band",
                                        :synthetic_synchronous)
                                for v in (1e9, 8e9, 2e10)])
    band(edge, fraction) = S.BandOutput(
        upper_wavelength = irreducible(FT(edge), D.LENGTH,
            "a declared band edge; no Derived rule of this instance reads it",
            "none: a declared instance"),
        luminosity_fraction = bracket(FT(fraction), zero(FT), FT(2 * fraction), ONE,
                                      "a quiet star", "an active star",
                                      :synthetic_synchronous))

    star = S.Star(
        mass = bracket(FT(3e29), FT(2e29), FT(4e29), D.MASS,
            "the low end of the declared mass", "the high end of the declared mass",
            :synthetic_synchronous),
        age = irreducible(FT(3e17), D.TIME, "a declared instance; no body is real",
            "none: a declared instance"),
        metal_mass_fraction = bracket(FT(0.01), FT(0.005), FT(0.02), ONE,
            "the low end of the declared fraction", "the high end of the declared fraction",
            :synthetic_synchronous),
        structure = S.DeclaredStructure(
            luminosity = bracket(FT(1e24), FT(5e23), FT(2e24), S.POWER,
                "the low end of the declared luminosity",
                "the high end of the declared luminosity", :synthetic_synchronous),
            radius = bracket(FT(1.5e8), FT(1e8), FT(2e8), D.LENGTH,
                "the low end of the declared radius", "the high end of the declared radius",
                :synthetic_synchronous)),
        spectrum = spectrum, variability = (), ultraviolet = band(4e-7, 0.001),
        activity = band(1e-8, 0.0001))

    planet = S.Planet(
        mass = bracket(FT(4e24), FT(3e24), FT(5e24), D.MASS,
            "the low end of the declared mass", "the high end of the declared mass",
            :synthetic_synchronous),
        bulk = S.DeclaredBulk(volumetric_mean_radius = bracket(FT(6e6), FT(5e6), FT(7e6),
            D.LENGTH, "the low end of the declared radius",
            "the high end of the declared radius", :synthetic_synchronous)),
        rotation = S.SynchronousRotation(),
        obliquity = irreducible(zero(FT), ONE,
            "declared zero; a synchronous rotation is admissible only where the sense of " *
            "rotation is prograde (decision 0004)", "none: a declared instance"),
        equator_ascending_node_longitude = irreducible(zero(FT), ONE,
            "nothing reads the pole's azimuth at zero obliquity (decision 0004)",
            "none: the degenerate case of decision 0004"),
        sub_primary_longitude_at_epoch = irreducible(zero(FT), ONE,
            "the permanent sub-stellar longitude of a synchronous rotator, a generated " *
            "body with no accurately observable fixed surface feature (decision 0004)",
            "which body-fixed longitudes face the primary for the whole run (decision 0004)"),
        figure = S.AbsentFigure(equator_pole_gravity_difference =
            bracket(FT(0.03), zero(FT), FT(0.1), S.ACCELERATION,
                "slower rotation and a denser core",
                "faster rotation and a less centrally condensed interior",
                :synthetic_synchronous)),
        lithosphere = lithosphere(FT;
            potential_temperature = 1500, diffusivity = 9e-7, expansivity = 2.5e-5,
            density = 3200, radiogenic = 4e-12, crustal_density = (2950, 2750),
            crustal_thickness = (6e3, 3.5e4),
            pushes_down = "secular cooling with age and a smaller mass",
            pushes_up = "the radiogenic inventory of the bulk composition and a larger mass",
            sweep = :synthetic_synchronous))

    orbit = S.Orbit(
        primary = S.StarBody(1), secondary = S.PlanetBody(),
        reference_plane = :invariable_plane,
        semi_major_axis = bracket(FT(5e9), FT(3e9), FT(7e9), D.LENGTH,
            "the low end of the declared semi-major axis",
            "the high end of the declared semi-major axis", :synthetic_synchronous),
        eccentricity = bracket(FT(0.05), FT(0.02), FT(0.1), ONE,
            "the low end of the declared eccentricity",
            "the high end of the declared eccentricity", :synthetic_synchronous),
        inclination = irreducible(zero(FT), ONE,
            "one planet and no companion star reads the invariable plane's tilt in this " *
            "instance", "none: a declared instance"),
        longitude_of_ascending_node = irreducible(zero(FT), ONE,
            "the node does not exist at zero inclination (decision 0004); nothing reads it",
            "none: the degenerate case of decision 0004"),
        longitude_of_periapsis = irreducible(FT(0.3), ONE,
            "a declared instance; no body is real", "none: a declared instance"))

    return S.System(
        stars = (star,), planet = planet,
        orbits = S.OrbitHierarchy(planet = orbit, moons = (), companions = ()),
        moons = (),
        inventories = S.Inventories(
            volatiles = S.SpeciesAmounts(species = (:H2O, :N2, :CO2),
                amounts = (bracket(FT(5e20), FT(2e20), FT(8e20), D.MASS,
                                   "the low end of the declared inventory",
                                   "the high end of the declared inventory",
                                   :synthetic_synchronous),
                          bracket(FT(3e18), FT(1e18), FT(5e18), D.MASS,
                                  "the low end of the declared inventory",
                                  "the high end of the declared inventory",
                                  :synthetic_synchronous),
                          bracket(FT(1e17), FT(5e16), FT(2e17), D.MASS,
                                  "the low end of the declared inventory",
                                  "the high end of the declared inventory",
                                  :synthetic_synchronous))),
            crust = S.Fractions(basis = :mass, members = (:SiO2, :Al2O3, :other),
                fractions = (bracket(FT(0.55), FT(0.45), FT(0.65), ONE,
                                     "the low end of the declared fraction",
                                     "the high end of the declared fraction",
                                     :synthetic_synchronous),
                            bracket(FT(0.2), FT(0.1), FT(0.3), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_synchronous),
                            bracket(FT(0.25), FT(0.15), FT(0.35), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_synchronous))),
            ocean_solutes = S.Fractions(basis = :mass, members = (:Cl, :other),
                fractions = (bracket(FT(0.5), FT(0.4), FT(0.6), ONE,
                                     "the low end of the declared fraction",
                                     "the high end of the declared fraction",
                                     :synthetic_synchronous),
                            bracket(FT(0.5), FT(0.4), FT(0.6), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_synchronous))),
            atmosphere = S.Fractions(basis = :mole, members = (:N2, :CO2),
                fractions = (bracket(FT(0.9), FT(0.8), FT(0.95), ONE,
                                     "the low end of the declared fraction",
                                     "the high end of the declared fraction",
                                     :synthetic_synchronous),
                            bracket(FT(0.1), FT(0.05), FT(0.2), ONE,
                                    "the low end of the declared fraction",
                                    "the high end of the declared fraction",
                                    :synthetic_synchronous))),
            condensable = :H2O),
        numerics = S.Numerics(
            exner_reference_pressure = exner_reference_pressure(FT(8e4)),
            geometry_precision = Float64),
        root_seed = seed(2))
end
