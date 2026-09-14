# Earth(): IAU and CODATA values with Sourced locators, a comparison to report the
# distance from, never a target. docs/plans/fiddlybits-52v.4-system.md, section
# "The instances"; decision 0034.

"""
    Earth(::Type{FT} = Float64)

The Sun-Earth system: the Sun's mass and the Earth's mass from the IAU 2015 nominal
mass parameters of Prsa et al. (2016), Table 1, divided by the CODATA 2018 constant of
gravitation `Systems.gravitational_constant`; the Earth's volumetric mean radius, the
volume-equivalent radius `(a^2 b)^(1/3)`, from the equatorial and polar radii of
Archinal et al. (2018), Table 4 (distinct from that table's own arithmetic mean
radius); the Earth's sidereal rotation period from the GRS80 defining angular
velocity of Moritz (2000), p. 131; the orbit's semi-major axis, eccentricity and
longitude of periapsis from the Earth/Moon barycentre row of Standish and Williams,
Table 1, the semi-major axis converted by the IAU 2012 astronomical unit of Prsa et
al. (2016). Every other field is `Bracketed` or `Irreducible`, argued in place; no
stellar or interior model is carried, and no moon is declared.
"""
function Earth(::Type{FT} = Float64) where {FT}
    G = Dispositions.value(S.gravitational_constant(FT))
    au = FT(149_597_870_700)

    sun = S.Star(
        mass = Dispositions.Sourced(value = FT(1.3271244e20) / G, dim = D.MASS,
            locator = Dispositions.Locator(identifier = "10.3847/0004-6256/152/2/41",
                table = "Table 1, nominal solar mass parameter (GM)^N_sun = " *
                        "1.3271244e20 m^3 s^-2, divided here by the CODATA 2018 " *
                        "constant of gravitation")),
        age = bracket(FT(4.5e9 * 365.25 * 86400), FT(4.4e9 * 365.25 * 86400),
            FT(4.6e9 * 365.25 * 86400), D.TIME,
            "the youngest radiometric solar-system age estimates",
            "the oldest radiometric solar-system age estimates", :earth),
        metal_mass_fraction = bracket(FT(0.0142), FT(0.012), FT(0.02), ONE,
            "a lower photospheric metal-abundance determination",
            "a higher photospheric metal-abundance determination", :earth),
        structure = S.DeclaredStructure(
            luminosity = bracket(FT(3.828e26), FT(3.8261e26), FT(3.8289e26), S.POWER,
                "the lower end of the solar-cycle-23-averaged total solar irradiance " *
                "measurement (Prsa et al. 2016)",
                "the upper end of the same measurement", :earth),
            radius = bracket(FT(6.957e8), FT(6.95518e8), FT(6.95798e8), D.LENGTH,
                "the lower end of the Haberreiter et al. (2008) photospheric radius " *
                "measurement (Prsa et al. 2016)",
                "the upper end of the same measurement", :earth));
        star_extras(FT)...)

    earth_planet = S.Planet(
        mass = Dispositions.Sourced(value = FT(3.986004e14) / G, dim = D.MASS,
            locator = Dispositions.Locator(identifier = "10.3847/0004-6256/152/2/41",
                table = "Table 1, nominal terrestrial mass parameter (GM)^N_E = " *
                        "3.986004e14 m^3 s^-2, divided here by the CODATA 2018 " *
                        "constant of gravitation")),
        bulk = S.DeclaredBulk(volumetric_mean_radius = Dispositions.Sourced(
            value = (FT(6_378_136.6)^2 * FT(6_356_751.9))^(FT(1) / FT(3)), dim = D.LENGTH,
            locator = Dispositions.Locator(identifier = "10.1007/s10569-017-9805-5",
                table = "Table 4, Earth equatorial radius 6378.1366 km and polar " *
                        "radius 6356.7519 km, combined here as the volume-equivalent " *
                        "radius (a^2 b)^(1/3), distinct from the table's own " *
                        "arithmetic mean radius (2a + b) / 3 = 6371.0084 km"))),
        rotation = S.SiderealRotation(period = Dispositions.Sourced(
            value = FT(2) * FT(pi) / FT(7.292115e-5), dim = D.TIME,
            locator = Dispositions.Locator(identifier = "10.1007/s001900050278",
                table = "p. 131, Defining Constants (exact): angular velocity of the " *
                        "Earth 7.292115e-5 rad/s, inverted to the sidereal rotation " *
                        "period 2 pi / omega"))),
        obliquity = bracket(FT(23.44 * pi / 180), FT(22.1 * pi / 180), FT(24.5 * pi / 180),
            ONE, "an obliquity minimum of the Milankovitch obliquity cycle",
            "an obliquity maximum of the same cycle", :earth),
        equator_ascending_node_longitude = irreducible(zero(FT), ONE,
            "the root origin of decision 0004 is the planet's mean position at t = 0, a " *
            "convention with no counterpart in a published catalogue; declaring the node " *
            "at zero places the vernal equinox there",
            "the azimuth convention only; no reader depends on it at zero obliquity"),
        sub_primary_longitude_at_epoch = irreducible(zero(FT), ONE,
            "Archinal et al. (2018) excludes a prime-meridian expression for Earth, " *
            "directing users to IERS Earth-orientation models this system does not carry " *
            "(p. 9, footnote 2)",
            "the local time at each longitude at a given t (decision 0004)"),
        figure = S.AbsentFigure(equator_pole_gravity_difference =
            bracket(FT(0.05), zero(FT), FT(0.1), S.ACCELERATION,
                "slower rotation and a denser core",
                "faster rotation and a less centrally condensed interior", :earth)),
        lithosphere = lithosphere(FT;
            potential_temperature = 1623, diffusivity = 1e-6, expansivity = 3e-5,
            density = 3300, radiogenic = 5e-12, crustal_density = (2900, 2700),
            crustal_thickness = (7e3, 4e4),
            pushes_down = "secular cooling with age and a smaller mass",
            pushes_up = "the radiogenic inventory of the bulk composition and a larger mass",
            sweep = :earth))

    earth_orbit = S.Orbit(
        primary = S.StarBody(1), secondary = S.PlanetBody(),
        reference_plane = :invariable_plane,
        semi_major_axis = Dispositions.Sourced(value = FT(1.00000261) * au, dim = D.LENGTH,
            locator = Dispositions.Locator(
                identifier = "standish1992-approximate-positions-of-the-planets.html",
                table = "Table 1, EM Bary row, a = 1.00000261 au, converted here by " *
                        "the IAU 2012 astronomical unit au = 149597870700 m of Prsa " *
                        "et al. (2016)")),
        eccentricity = Dispositions.Sourced(value = FT(0.01671123), dim = ONE,
            locator = Dispositions.Locator(
                identifier = "standish1992-approximate-positions-of-the-planets.html",
                table = "Table 1, EM Bary row, e = 0.01671123")),
        inclination = irreducible(zero(FT), ONE,
            "this system declares one planet with no moon; the invariable plane is taken " *
            "as the planet's own orbital plane, the case of zero inclination decision " *
            "0004 names, so the node does not exist and nothing reads it",
            "none: the degenerate case of decision 0004"),
        longitude_of_ascending_node = irreducible(zero(FT), ONE,
            "the node does not exist at zero inclination (decision 0004); nothing reads it",
            "none: the degenerate case of decision 0004"),
        longitude_of_periapsis = Dispositions.Sourced(
            value = FT(102.93768193 * pi / 180), dim = ONE,
            locator = Dispositions.Locator(
                identifier = "standish1992-approximate-positions-of-the-planets.html",
                table = "Table 1, EM Bary row, long.peri. = 102.93768193 degrees")))

    return S.System(
        stars = (sun,), planet = earth_planet,
        orbits = S.OrbitHierarchy(planet = earth_orbit, moons = (), companions = ()),
        moons = (),
        inventories = S.Inventories(
            volatiles = S.SpeciesAmounts(species = (:H2O, :N2, :CO2),
                amounts = (bracket(FT(1.4e21), FT(1.3e21), FT(1.5e21), D.MASS,
                                   "the lower end of estimated present-day ocean mass",
                                   "the upper end of estimated present-day ocean mass",
                                   :earth),
                          bracket(FT(3.9e18), FT(3.8e18), FT(4.0e18), D.MASS,
                                  "the lower end of estimated atmospheric nitrogen mass",
                                  "the upper end of the same estimate", :earth),
                          bracket(FT(3.0e15), FT(2.9e15), FT(3.1e15), D.MASS,
                                  "the lower end of estimated atmospheric carbon dioxide " *
                                  "mass", "the upper end of the same estimate", :earth))),
            crust = S.Fractions(basis = :mass, members = (:SiO2, :Al2O3, :other),
                fractions = (bracket(FT(0.60), FT(0.55), FT(0.65), ONE,
                                     "a mafic-poor continental crust average",
                                     "a mafic-rich continental crust average", :earth),
                            bracket(FT(0.15), FT(0.10), FT(0.20), ONE,
                                    "a mafic-poor continental crust average",
                                    "a mafic-rich continental crust average", :earth),
                            bracket(FT(0.25), FT(0.20), FT(0.30), ONE,
                                    "a mafic-poor continental crust average",
                                    "a mafic-rich continental crust average", :earth))),
            ocean_solutes = S.Fractions(basis = :mass, members = (:Cl, :other),
                fractions = (bracket(FT(0.55), FT(0.50), FT(0.60), ONE,
                                     "a fresher dissolved load", "a saltier dissolved load",
                                     :earth),
                            bracket(FT(0.45), FT(0.40), FT(0.50), ONE,
                                    "a fresher dissolved load", "a saltier dissolved load",
                                    :earth))),
            atmosphere = S.Fractions(basis = :mole, members = (:N2, :O2, :Ar, :CO2),
                fractions = (bracket(FT(0.7808), FT(0.7803), FT(0.7813), ONE,
                                     "a lower nitrogen mole fraction",
                                     "a higher nitrogen mole fraction", :earth),
                            bracket(FT(0.2095), FT(0.2090), FT(0.2100), ONE,
                                    "a lower oxygen mole fraction",
                                    "a higher oxygen mole fraction", :earth),
                            bracket(FT(0.0093), FT(0.0090), FT(0.0096), ONE,
                                    "a lower argon mole fraction",
                                    "a higher argon mole fraction", :earth),
                            bracket(FT(0.0004), FT(0.0003), FT(0.0005), ONE,
                                    "a lower carbon dioxide mole fraction",
                                    "a higher carbon dioxide mole fraction", :earth))),
            condensable = :H2O),
        numerics = S.Numerics(
            exner_reference_pressure = exner_reference_pressure(FT(101325.0)),
            geometry_precision = Float64),
        root_seed = seed(20260914))
end
