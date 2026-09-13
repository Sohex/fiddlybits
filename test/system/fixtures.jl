# One recipe for the systems the suites in this directory build, so a test overrides
# the one part it is checking and states nothing else. Every number is a synthetic
# declaration; none is a real body's.

module SystemFixtures

using Fiddlybits: Systems, Dispositions, Dimensions, Reductions, Verdicts

const S = Systems
const D = Dimensions

"A `Bracketed` of `value` in `[low, high]` over `dim`."
bracket(value, low, high, dim) = Dispositions.Bracketed(
    value = value, dim = dim, low = low, high = high,
    pushes_down = "the fixture's low mechanism", pushes_up = "the fixture's high mechanism",
    sweep = :fixture)

"An `Irreducible` of `value` over `dim`."
irreducible(value, dim) = Dispositions.Irreducible(
    value = value, dim = dim, argument = "a convention of the fixture",
    sensitivity = "none: a fixture")

"`bracket` at `value` with ends a factor of two either side, for a positive value."
wide(value, dim) = bracket(value, value / 2, 2 * value, dim)

const LENGTH = D.LENGTH
const MASS = D.MASS
const TIME = D.TIME
const ONE = D.DIMENSIONLESS

"A Bracketed spectrum over three wavelengths."
spectrum(T = Float64) = S.BracketedSpectrum(
    wavelengths = T[1e-7, 1e-6, 1e-5],
    surface_flux_density = [wide(T(v), S.SPECTRAL_FLUX) for v in (1e12, 3e13, 2e11)])

"A band output shortward of `edge`."
band(T, edge) = S.BandOutput(upper_wavelength = irreducible(T(edge), LENGTH),
                             luminosity_fraction = bracket(T(0.01), T(0), T(0.05), ONE))

"A star with a declared structure; `kw` replaces any keyword."
function star(T = Float64; kw...)
    base = (mass = wide(T(1.6e30), MASS), age = wide(T(3e17), TIME),
            metal_mass_fraction = bracket(T(0.015), T(0.005), T(0.03), ONE),
            structure = S.DeclaredStructure(luminosity = wide(T(2.5e26), S.POWER),
                                            radius = wide(T(6e8), LENGTH)),
            spectrum = spectrum(T),
            variability = (S.CycleComponent(amplitude = bracket(T(0), T(0), T(1e-3), ONE),
                                            period = wide(T(3e8), TIME),
                                            phase = irreducible(T(1), ONE)),),
            ultraviolet = band(T, 4e-7), activity = band(T, 1e-8))
    return S.Star(; merge(base, values(kw))...)
end

"A lithosphere over two province classes; `kw` replaces any keyword."
function lithosphere(T = Float64; kw...)
    base = (province_classes = (:thin, :thick),
            mantle_potential_temperature = wide(T(1700), D.TEMPERATURE),
            mantle_thermal_diffusivity = wide(T(8e-7), S.DIFFUSIVITY),
            mantle_thermal_expansivity = wide(T(3e-5), S.EXPANSIVITY),
            mantle_density = wide(T(3400), S.DENSITY),
            radiogenic_heat_production = wide(T(6e-12), S.SPECIFIC_POWER),
            crustal_density = (wide(T(2900), S.DENSITY), wide(T(2700), S.DENSITY)),
            crustal_thickness = (wide(T(7e3), LENGTH), wide(T(4e4), LENGTH)))
    return S.Lithosphere(; merge(base, values(kw))...)
end

"The keywords of a planet with a declared bulk and a sidereal rotation, over `T`;
`kw` replaces any of them."
planet_keywords(T = Float64; kw...) = merge(
    (mass = wide(T(8e24), MASS),
     bulk = S.DeclaredBulk(volumetric_mean_radius = wide(T(7e6), LENGTH)),
     rotation = S.SiderealRotation(period = wide(T(1e5), TIME)),
     obliquity = bracket(T(0.4), T(0.2), T(0.6), ONE),
     sub_primary_longitude_at_epoch = irreducible(T(0.3), ONE),
     figure = S.AbsentFigure(equator_pole_gravity_difference =
                                 bracket(T(0.02), T(0), T(0.1), S.ACCELERATION)),
     lithosphere = lithosphere(T)),
    values(kw))

"A planet with a declared bulk and a sidereal rotation; `kw` replaces any keyword."
planet(T = Float64; kw...) = S.Planet(; planet_keywords(T; kw...)...)

"The elements every orbit shares, over `T`; `kw` replaces any of them."
elements(T; kw...) = merge((eccentricity = bracket(T(0.1), T(0.05), T(0.2), ONE),
                            inclination = irreducible(T(0), ONE),
                            longitude_of_ascending_node = irreducible(T(0), ONE),
                            argument_of_periapsis = irreducible(T(1), ONE),
                            mean_anomaly_at_epoch = irreducible(T(0.5), ONE)), values(kw))

"The planet's orbit about star one."
planet_orbit(T = Float64; kw...) = S.Orbit(; merge(
    (primary = S.StarBody(1), secondary = S.PlanetBody(), reference_plane = :invariable_plane,
     semi_major_axis = wide(T(1.8e11), LENGTH)), elements(T), values(kw))...)

"The orbit of moon one about the planet."
moon_orbit(T = Float64; kw...) = S.Orbit(; merge(
    (primary = S.PlanetBody(), secondary = S.MoonBody(1), reference_plane = :planet_equator,
     semi_major_axis = wide(T(4e8), LENGTH)), elements(T), values(kw))...)

"The orbit of star two about star one."
companion_orbit(T = Float64; kw...) = S.Orbit(; merge(
    (primary = S.StarBody(1), secondary = S.StarBody(2), reference_plane = :invariable_plane,
     semi_major_axis = wide(T(3e12), LENGTH)), elements(T), values(kw))...)

"A moon with a Sourced reflectance table."
moon(T = Float64) = S.Moon(
    mass = wide(T(5e22), MASS), radius = wide(T(1.5e6), LENGTH),
    reflectance = Dispositions.Sourced(
        value = S.ReflectanceTable(wavelengths = T[1e-7, 1e-6], reflectance = T[0.1, 0.2]),
        dim = ONE,
        locator = Dispositions.Locator(identifier = "fixture", table = "fixture table")))

"Mass fractions over `members`."
fractions(T, basis, members, values; disposition = wide) = S.Fractions(
    basis = basis, members = members,
    fractions = Tuple(disposition === wide ? bracket(T(v), T(0), T(1), ONE) :
                      irreducible(T(v), ONE) for v in values))

"Inventories with water as the condensable; `kw` replaces any keyword."
function inventories(T = Float64; kw...)
    base = (volatiles = S.SpeciesAmounts(species = (:H2O, :N2, :CO2),
                                         amounts = Tuple(wide(T(v), MASS) for v in (1e21, 4e18, 1e20))),
            crust = fractions(T, :mass, (:SiO2, :Al2O3, :FeO), (0.6, 0.25, 0.15)),
            ocean_solutes = fractions(T, :mass, (:Cl, :Na), (0.55, 0.45)),
            atmosphere = fractions(T, :mole, (:N2, :CO2), (0.8, 0.2)),
            condensable = :H2O)
    return S.Inventories(; merge(base, values(kw))...)
end

"Numerics with the epoch at the planet's periapsis; `kw` replaces any keyword."
function numerics(T = Float64; kw...)
    base = (epoch = S.EpochReference(kind = :periapsis, source = S.PlanetBody(),
                                     offset = irreducible(T(0), TIME)),
            exner_reference_pressure = irreducible(T(1e5), S.PRESSURE),
            geometry_precision = Float64)
    return S.Numerics(; merge(base, values(kw))...)
end

"The keywords of a one-star, one-moon system over `T`; `kw` replaces any."
system_keywords(T = Float64; kw...) = merge(
    (stars = (star(T),), planet = planet(T),
     orbits = S.OrbitHierarchy(planet = planet_orbit(T), moons = (moon_orbit(T),),
                               companions = ()),
     moons = (moon(T),), inventories = inventories(T), numerics = numerics(T)),
    values(kw))

"A one-star, one-moon system over `T`; `kw` replaces any keyword."
system(T = Float64; kw...) = S.System(; system_keywords(T; kw...)...)

"A two-star system, the planet about star one and star two about star one."
two_star_system(T = Float64; kw...) = system(T;
    stars = (star(T), star(T)),
    orbits = S.OrbitHierarchy(planet = planet_orbit(T), moons = (moon_orbit(T),),
                              companions = (companion_orbit(T),)), kw...)

"A system whose planet rotates synchronously, with the epoch on superior conjunction."
synchronous_system(T = Float64; kw...) = system(T;
    planet = planet(T; rotation = S.SynchronousRotation()),
    numerics = numerics(T; epoch = S.EpochReference(kind = :superior_conjunction,
                                                    source = S.StarBody(1),
                                                    offset = irreducible(T(0), TIME))),
    kw...)

"The planet's orbit declared by its flux."
flux_orbit(T = Float64; kw...) = S.FluxOrbit(; merge(
    (primary = S.StarBody(1), secondary = S.PlanetBody(), reference_plane = :invariable_plane,
     flux_at_semi_major_axis = wide(T(900), S.IRRADIANCE)), elements(T), values(kw))...)

"A system whose planet's orbit is declared by its flux, with the epoch on the equinox."
flux_system(T = Float64; kw...) = system(T;
    orbits = S.OrbitHierarchy(planet = flux_orbit(T), moons = (moon_orbit(T),), companions = ()),
    numerics = numerics(T; epoch = S.EpochReference(kind = :vernal_equinox,
                                                    source = S.StarBody(1),
                                                    offset = irreducible(T(0), TIME))),
    kw...)

"""
    LinearStellarModel(coefficient, domain)

A stellar model fixture: luminosity `coefficient[1] * mass`, radius
`coefficient[2] * mass`, over `domain`. Not a physical relation.
"""
struct LinearStellarModel{T} <: S.StellarModel
    coefficient::NTuple{2,T}
    domain::NamedTuple
end

S.model_locator(::LinearStellarModel) =
    Dispositions.Locator(identifier = "fixture", table = "fixture relation")
S.model_domain(m::LinearStellarModel) = m.domain
function S.stellar_structure(m::LinearStellarModel{T}, mass, age, z) where {T}
    l = m.coefficient[1] * mass
    r = m.coefficient[2] * mass
    return (luminosity = l, radius = r,
            luminosity_rounding = Reductions.error_bound(T, 1, l),
            radius_rounding = Reductions.error_bound(T, 1, r))
end

"A `LinearStellarModel` over masses from 5e29 to 4e30 kg, every age and metal fraction."
linear_model(T = Float64) = LinearStellarModel{T}(
    (T(1.5e-4), T(3.75e-22)),
    (mass = (T(5e29), T(4e30)), age = (T(0), T(1e18)), metal_mass_fraction = (T(0), T(1))))

"A one-axis spectrum grid in effective temperature, its top node absent when `hole`."
function grid(T = Float64; hole = false)
    present = [true, true, !hole]
    flux = T[1e12 2e12; 3e12 4e12; 5e12 6e12]
    return S.SpectrumGrid(identifier = "fixture-grid", axes = (:effective_temperature,),
                          nodes = (T[3000, 5000, 7000],), wavelengths = T[1e-7, 1e-6],
                          flux = flux, present = present)
end

"`f()` run for its side effect; the `Verdicts.Refusal` it raises, or what it returns."
caught(f) = try
    f()
catch err
    err
end

"`true` when `e` is a `Verdicts.Refusal` of `quantity` whose reason contains `text`."
refused(e, quantity, text) =
    e isa Verdicts.Refusal && e.quantity == quantity && occursin(text, e.reason)

"`x` as a 256-bit float."
big256(x) = BigFloat(x; precision = 256)

"""
    gravity_256(planet, r, phi)

The effective gravity of `planet` at `r` and `phi`, the same formula as
`Systems.gravity` at 256 bits from the planet's stored values, the decimal constant
of gravitation and a 256-bit `pi`.
"""
function gravity_256(p, r, phi)
    setprecision(BigFloat, 256) do
        gm = Dispositions.value(Systems.gravitational_constant(BigFloat)) *
             big256(Dispositions.value(p.mass))
        omega = 2 * BigFloat(pi) / big256(Dispositions.value(Systems.rotation_period(p.rotation)))
        rb, c, s = big256(r), cos(big256(phi)), sin(big256(phi))
        radial = gm / rb^2 - omega^2 * rb * c^2
        tangential = omega^2 * rb * c * s
        sqrt(radial^2 + tangential^2)
    end
end

"The effective gravity of `planet` at `r` on the rotation axis, `G M / r^2`, at 256 bits."
polar_gravity_256(p, r) = setprecision(BigFloat, 256) do
    Dispositions.value(Systems.gravitational_constant(BigFloat)) *
        big256(Dispositions.value(p.mass)) / big256(r)^2
end

"The centrifugal closed form `omega^2 r` of `planet` at 256 bits."
centrifugal_256(p, r) = setprecision(BigFloat, 256) do
    (2 * BigFloat(pi) / big256(Dispositions.value(Systems.rotation_period(p.rotation))))^2 * big256(r)
end

"`effective_temperature` at 256 bits from `luminosity` and `radius`."
effective_temperature_256(l, r) = setprecision(BigFloat, 256) do
    sigma = Dispositions.value(Systems.stefan_boltzmann_constant(BigFloat))
    sqrt(sqrt(big256(l) / (4 * BigFloat(pi) * big256(r)^2 * sigma)))
end

"`orbital_period` at 256 bits from `a` and `masses`."
orbital_period_256(a, masses) = setprecision(BigFloat, 256) do
    G = Dispositions.value(Systems.gravitational_constant(BigFloat))
    2 * BigFloat(pi) * sqrt(big256(a)^3 / (G * sum(big256, masses)))
end

"`semi_major_axis_from_flux` at 256 bits."
flux_axis_256(l, f) = setprecision(BigFloat, 256) do
    sqrt(big256(l) / (4 * BigFloat(pi) * big256(f)))
end

end # module SystemFixtures
