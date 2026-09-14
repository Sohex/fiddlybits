# The five M0 test instances of decision 0034: Earth() and the four synthetic
# constructors. docs/plans/fiddlybits-52v.4-system.md, section "The instances".
# Each constructor's float type is its first positional argument, defaulting to
# Float64, the convention test/system/fixtures.jl's own builders use throughout.

module Planets

using Fiddlybits: Systems, Dispositions, Dimensions, Verdicts

const S = Systems
const D = Dimensions
const ONE = D.DIMENSIONLESS

"A `Bracketed` of `value` in `[low, high]` over `dim`, both mechanisms named."
bracket(value, low, high, dim, pushes_down, pushes_up, sweep) = Dispositions.Bracketed(
    value = value, dim = dim, low = low, high = high,
    pushes_down = pushes_down, pushes_up = pushes_up, sweep = sweep)

"An `Irreducible` of `value` over `dim`, with its argument and sensitivity."
irreducible(value, dim, argument, sensitivity) = Dispositions.Irreducible(
    value = value, dim = dim, argument = argument, sensitivity = sensitivity)

"`f()` run for its side effect; the `Verdicts.Refusal` it raises, or what it returns."
caught(f) = try
    f()
catch err
    err
end

"`true` when `e` is a `Verdicts.Refusal` of `quantity` whose reason contains `text`."
refused(e, quantity, text) =
    e isa Verdicts.Refusal && e.quantity == quantity && occursin(text, e.reason)

"A star's spectrum, ultraviolet and activity bands, and empty variability: declared
values no Derived rule of these instances reads."
function star_extras(::Type{FT}) where {FT}
    spectrum = S.BracketedSpectrum(
        wavelengths = FT[2e-7, 5e-7, 1e-6],
        surface_flux_density = [bracket(FT(v), FT(v) / 2, FT(v) * 2, S.SPECTRAL_FLUX,
                                        "the low end of the declared band",
                                        "the high end of the declared band", :spectrum)
                                for v in (1e12, 3e13, 2e11)])
    band(edge, fraction) = S.BandOutput(
        upper_wavelength = irreducible(FT(edge), D.LENGTH,
            "a declared band edge; no Derived rule of these instances reads it",
            "none: a declared instance"),
        luminosity_fraction = bracket(FT(fraction), zero(FT), FT(2 * fraction), ONE,
                                      "a quiet star", "an active star", :activity))
    return (spectrum = spectrum, variability = (),
            ultraviolet = band(4e-7, 0.02), activity = band(1e-8, 0.001))
end

"A `Lithosphere` over two province classes: `oceanic` and `continental`, each scalar
member bracketed at half to twice its value under one mechanism pair (decision 0004,
the planet's bulk)."
function lithosphere(::Type{FT}; potential_temperature, diffusivity, expansivity, density,
                     radiogenic, crustal_density, crustal_thickness, pushes_down, pushes_up,
                     sweep) where {FT}
    wide(v, dim) = bracket(FT(v), FT(v) / 2, FT(v) * 2, dim, pushes_down, pushes_up, sweep)
    return S.Lithosphere(
        province_classes = (:oceanic, :continental),
        mantle_potential_temperature = wide(potential_temperature, D.TEMPERATURE),
        mantle_thermal_diffusivity = wide(diffusivity, S.DIFFUSIVITY),
        mantle_thermal_expansivity = wide(expansivity, S.EXPANSIVITY),
        mantle_density = wide(density, S.DENSITY),
        radiogenic_heat_production = wide(radiogenic, S.SPECIFIC_POWER),
        crustal_density = Tuple(wide(v, S.DENSITY) for v in crustal_density),
        crustal_thickness = Tuple(wide(v, D.LENGTH) for v in crustal_thickness))
end

"A root seed: an `Irreducible` over the `UInt64` of `value`."
seed(value) = irreducible(UInt64(value), ONE, "an arbitrary run seed for this instance",
                          "none: a declared instance")

"An `Irreducible` Exner reference pressure at `value`."
exner_reference_pressure(value) = irreducible(value, S.PRESSURE,
    "the Exner reference pressure sets the constant p0 in the potential temperature " *
    "theta = T (p0 / p)^(R / cp); a fixed choice of p0 changes no physical prediction",
    "the reported numeric value of potential temperature at every level, by the " *
    "factor (p0' / p0)^(R / cp); no dynamical or physical quantity depends on the " *
    "choice")

include("earth.jl")
include("synthetic_non_earth.jl")
include("synthetic_synchronous.jl")
include("synthetic_retrograde.jl")
include("synthetic_composition2.jl")

end # module Planets
