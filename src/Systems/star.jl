# One star: mass, age and metal mass fraction declared; luminosity and radius Derived
# from a carried stellar model or Bracketed; effective temperature Derived; spectrum,
# variability, ultraviolet and activity output. docs/plans/fiddlybits-52v.4-system.md,
# section "The struct"; decision 0004, the stars.

using ..Verdicts: refuse
using ..Dimensions: Dim, MASS, LENGTH, TIME, TEMPERATURE, DIMENSIONLESS
using ..Dispositions: Disposition, Derived, Bracketed, Locator, value

"The dimension of a power: mass length^2 time^-3."
const POWER = Dim{1,2,-3,0,0}()

"The dimension of an acceleration: length time^-2."
const ACCELERATION = Dim{0,1,-2,0,0}()

"""
    StellarModel

A carried stellar model: a `Sourced` law with a declared domain. A subtype answers
`model_locator(m)`, the `Locator` of its source; `model_domain(m)`, a `NamedTuple`
with the fields `mass`, `age` and `metal_mass_fraction`, each a `(low, high)` pair in
SI; and `stellar_structure(m, mass, age, metal_mass_fraction)`, a `NamedTuple` with
`luminosity` and `radius` and the rounding bounds of their evaluation,
`luminosity_rounding` and `radius_rounding`.
"""
abstract type StellarModel end

function model_locator end
function model_domain end
function stellar_structure end

"""
    evaluate_stellar_model(model, mass, age, metal_mass_fraction, site)

`stellar_structure` of `model` at the values of the three dispositions. Refuses at
`site` when any value they declare, a `Bracketed`'s ends included, lies below or
above `model_domain(model)` on its axis, naming the axis, the side and the model.
"""
function evaluate_stellar_model(model::StellarModel, mass::Disposition, age::Disposition,
                                metal_mass_fraction::Disposition, site::AbstractString)
    domain = model_domain(model)
    source = model_locator(model).identifier
    for (name, d) in ((:mass, mass), (:age, age), (:metal_mass_fraction, metal_mass_fraction))
        low, high = domain[name]
        for x in declared_values(d)
            x < low && refuse(String(name), site,
                "$(x) is below the domain [$(low), $(high)] of the stellar model $(source)")
            x > high && refuse(String(name), site,
                "$(x) is above the domain [$(low), $(high)] of the stellar model $(source)")
        end
    end
    return stellar_structure(model, value(mass), value(age), value(metal_mass_fraction))
end

"""
    DeclaredStructure(; luminosity, radius)

A star's luminosity and radius where no stellar model is carried, each `Bracketed`
and above zero.
"""
struct DeclaredStructure{FT}
    luminosity::Bracketed{FT,typeof(POWER)}
    radius::Bracketed{FT,typeof(LENGTH)}

    DeclaredStructure{FT}(::Checked, luminosity, radius) where {FT} = new{FT}(luminosity, radius)
end

function DeclaredStructure(; kwargs...)
    site = "Systems.DeclaredStructure"
    k, _ = read_keywords(site, values(kwargs), (:luminosity, :radius), ())
    FT = float_type("luminosity", site, k.luminosity)
    luminosity = require_positive("luminosity", site,
        require_disposition("luminosity", site, k.luminosity, FT, POWER, (Bracketed,)))
    radius = require_positive("radius", site,
        require_disposition("radius", site, k.radius, FT, LENGTH, (Bracketed,)))
    return DeclaredStructure{FT}(Checked(), luminosity, radius)
end

"""
    CycleComponent(; amplitude, period, phase)

One periodic component of a star's variability: the relative luminosity `amplitude`,
zero or above; the `period`, above zero; and the `phase` at the epoch in `[0, 2 pi)`.
An amplitude of zero is admitted.
"""
struct CycleComponent{FT}
    amplitude::Disposition{FT,typeof(DIMENSIONLESS)}
    period::Disposition{FT,typeof(TIME)}
    phase::Disposition{FT,typeof(DIMENSIONLESS)}

    CycleComponent{FT}(::Checked, a, p, f) where {FT} = new{FT}(a, p, f)
end

function CycleComponent(; kwargs...)
    site = "Systems.CycleComponent"
    k, _ = read_keywords(site, values(kwargs), (:amplitude, :period, :phase), ())
    FT = float_type("amplitude", site, k.amplitude)
    amplitude = require_interval("amplitude", site,
        require_disposition("amplitude", site, k.amplitude, FT, DIMENSIONLESS, DECLARED),
        zero(FT), true, typemax(FT), true)
    period = require_positive("period", site,
        require_disposition("period", site, k.period, FT, TIME, DECLARED))
    phase = require_interval("phase", site,
        require_disposition("phase", site, k.phase, FT, DIMENSIONLESS, DECLARED),
        zero(FT), true, 2 * FT(pi), false)
    return CycleComponent{FT}(Checked(), amplitude, period, phase)
end

"""
    BandOutput(; upper_wavelength, luminosity_fraction)

A star's output shortward of `upper_wavelength`, a positive length, as the
`Bracketed` fraction of its luminosity in `[0, 1]`. A star carries two: its
ultraviolet output and its activity output.
"""
struct BandOutput{FT}
    upper_wavelength::Disposition{FT,typeof(LENGTH)}
    luminosity_fraction::Bracketed{FT,typeof(DIMENSIONLESS)}

    BandOutput{FT}(::Checked, w, f) where {FT} = new{FT}(w, f)
end

function BandOutput(; kwargs...)
    site = "Systems.BandOutput"
    k, _ = read_keywords(site, values(kwargs), (:upper_wavelength, :luminosity_fraction), ())
    FT = float_type("upper_wavelength", site, k.upper_wavelength)
    wavelength = require_positive("upper_wavelength", site,
        require_disposition("upper_wavelength", site, k.upper_wavelength, FT, LENGTH, DECLARED))
    fraction = require_interval("luminosity_fraction", site,
        require_disposition("luminosity_fraction", site, k.luminosity_fraction, FT,
                            DIMENSIONLESS, (Bracketed,)),
        zero(FT), true, one(FT), true)
    return BandOutput{FT}(Checked(), wavelength, fraction)
end

"""
    effective_temperature(FT, luminosity, radius)

`(luminosity / (4 pi radius^2 sigma))^(1/4)` at the Stefan-Boltzmann constant of
`stefan_boltzmann_constant(FT)`, as two square roots.
"""
function effective_temperature(::Type{FT}, luminosity::FT, radius::FT) where {FT<:AbstractFloat}
    sigma = value(stefan_boltzmann_constant(FT))
    return sqrt(sqrt(luminosity / (4 * FT(pi) * (radius * radius) * sigma)))
end

"""
The rounded operations of `effective_temperature`: the rounding of `pi` and of
`sigma` into `FT`, the square of the radius, two multiplies, one divide and two
square roots. The multiply by four is exact.
"""
const EFFECTIVE_TEMPERATURE_TERMS = 8

"""
    surface_gravity(FT, mass, radius)

`gravitational_parameter(FT, mass) / radius^2`: the Newtonian acceleration at the
surface of a spherical body, with no rotation.
"""
function surface_gravity(::Type{FT}, mass::FT, radius::FT) where {FT<:AbstractFloat}
    return gravitational_parameter(FT, mass) / (radius * radius)
end

"""
    spectrum_axes(FT, mass, radius, effective_temperature, metal_mass_fraction)

A star's values of every quantity in `GRID_AXES`, by name: its effective
temperature, its `surface_gravity` and its metal mass fraction.
"""
spectrum_axes(::Type{FT}, mass::FT, radius::FT, teff::FT, z::FT) where {FT} =
    (effective_temperature = teff, surface_gravity = surface_gravity(FT, mass, radius),
     metal_mass_fraction = z)

"The keywords of `Star`."
const STAR_KEYWORDS = (:mass, :age, :metal_mass_fraction, :structure, :spectrum,
                       :variability, :ultraviolet, :activity)

"The Derived values `Star` checks when a caller supplies them."
const STAR_CHECKED = (:luminosity, :radius, :effective_temperature)

"""
    Star

One star of a system. Build it with the keyword constructor, which has no defaults:

    Star(; mass, age, metal_mass_fraction, structure, spectrum, variability,
           ultraviolet, activity)

`mass` (above zero), `age` (zero or above) and `metal_mass_fraction` (in `[0, 1]`)
are `Sourced`, `Bracketed` or `Irreducible`. `structure` is a `StellarModel`,
evaluated inside its domain to give a `Derived` luminosity and radius, or a
`DeclaredStructure`. The effective temperature is `Derived` from the luminosity and
radius. `spectrum` is a `SpectrumGrid`, interpolated at the star's effective
temperature, surface gravity and metal mass fraction, or a `BracketedSpectrum`.
`variability` is a tuple of zero or more `CycleComponent`s; `ultraviolet` and
`activity` are `BandOutput`s.

A caller may also pass `luminosity` and `radius` where a model derives them, and
`effective_temperature`; each is refused when it disagrees with the Derived value
beyond its rounding bound, and `luminosity` or `radius` given beside a
`DeclaredStructure` is refused as a second declaration.
"""
struct Star{FT,S,P,K}
    mass::Disposition{FT,typeof(MASS)}
    age::Disposition{FT,typeof(TIME)}
    metal_mass_fraction::Disposition{FT,typeof(DIMENSIONLESS)}
    structure::S
    luminosity::Disposition{FT,typeof(POWER)}
    radius::Disposition{FT,typeof(LENGTH)}
    effective_temperature::Derived{FT,typeof(TEMPERATURE),2}
    spectrum::P
    variability::NTuple{K,CycleComponent{FT}}
    ultraviolet::BandOutput{FT}
    activity::BandOutput{FT}

    function Star{FT,S,P,K}(::Checked, fields...) where {FT,S,P,K}
        return new{FT,S,P,K}(fields...)
    end
end

"The field names of `Star`, the set a `Derived` value of a star names its inputs in."
const STAR_FIELDS = fieldnames(Star)

"""
    resolve_structure(structure, mass, age, metal_mass_fraction, supplied, site)

The luminosity and radius dispositions of a star, as a pair. A `StellarModel` gives
`Derived` values, each checked against a supplied value within the rounding the
model states; a `DeclaredStructure` gives its two `Bracketed` values and refuses a
supplied value for either.
"""
function resolve_structure(model::StellarModel, mass, age, z, supplied::NamedTuple,
                           site::AbstractString)
    FT = typeof(value(mass))
    s = evaluate_stellar_model(model, mass, age, z, site)
    from = (:mass, :age, :metal_mass_fraction)
    luminosity = require_type("luminosity", site, s.luminosity, FT)
    radius = require_type("radius", site, s.radius, FT)
    haskey(supplied, :luminosity) && check_supplied_within(
        "luminosity", site, supplied.luminosity, luminosity, s.luminosity_rounding)
    haskey(supplied, :radius) && check_supplied_within(
        "radius", site, supplied.radius, radius, s.radius_rounding)
    return (Derived(value = luminosity, dim = POWER, from = from,
                    rule = :stellar_model_luminosity, fields = STAR_FIELDS),
            Derived(value = radius, dim = LENGTH, from = from,
                    rule = :stellar_model_radius, fields = STAR_FIELDS))
end

function resolve_structure(declared::DeclaredStructure, mass, age, z, supplied::NamedTuple,
                           site::AbstractString)
    for name in (:luminosity, :radius)
        haskey(supplied, name) && refuse(
            String(name), site,
            "declared in the DeclaredStructure already; a second value is refused")
    end
    typeof(value(declared.luminosity)) === typeof(value(mass)) || refuse(
        "structure", site, "the structure's type differs from the mass's")
    return (declared.luminosity, declared.radius)
end

resolve_structure(structure, mass, age, z, supplied::NamedTuple, site::AbstractString) =
    refuse("structure", site,
           "a $(typeof(structure)) where a StellarModel or a DeclaredStructure is required")

function Star(; kwargs...)
    site = "Systems.Star"
    k, supplied = read_keywords(site, values(kwargs), STAR_KEYWORDS, STAR_CHECKED)
    FT = float_type("mass", site, k.mass)
    mass = require_positive("mass", site,
        require_disposition("mass", site, k.mass, FT, MASS, DECLARED))
    age = require_interval("age", site,
        require_disposition("age", site, k.age, FT, TIME, DECLARED),
        zero(FT), true, typemax(FT), true)
    z = require_interval("metal_mass_fraction", site,
        require_disposition("metal_mass_fraction", site, k.metal_mass_fraction, FT,
                            DIMENSIONLESS, DECLARED),
        zero(FT), true, one(FT), true)
    luminosity, radius = resolve_structure(k.structure, mass, age, z, supplied, site)

    teff = effective_temperature(FT, value(luminosity), value(radius))
    haskey(supplied, :effective_temperature) && check_supplied(
        "effective_temperature", site, supplied.effective_temperature, teff,
        EFFECTIVE_TEMPERATURE_TERMS, teff)
    temperature = Derived(value = teff, dim = TEMPERATURE, from = (:luminosity, :radius),
                          rule = :stefan_boltzmann_effective_temperature,
                          fields = STAR_FIELDS)

    axes = spectrum_axes(FT, value(mass), value(radius), teff, value(z))
    spectrum = resolve_spectrum(k.spectrum, axes, STAR_FIELDS, site)
    eltype(spectrum.wavelengths) === FT || refuse(
        "spectrum", site, "the spectrum's type differs from the mass's")

    variability = require_type("variability", site, k.variability, Tuple)
    for c in variability
        require_type("variability", site, c, CycleComponent{FT})
    end
    ultraviolet = require_type("ultraviolet", site, k.ultraviolet, BandOutput{FT})
    activity = require_type("activity", site, k.activity, BandOutput{FT})

    return Star{FT,typeof(k.structure),typeof(spectrum),length(variability)}(
        Checked(), mass, age, z, k.structure, luminosity, radius, temperature, spectrum,
        variability, ultraviolet, activity)
end
