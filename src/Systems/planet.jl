# The planet: its bulk, rotation, obliquity, figure and lithosphere block.
# docs/plans/fiddlybits-52v.4-system.md, section "The struct"; decision 0004, the
# planet's bulk and the lithosphere block.

using ..Verdicts: refuse
using ..Dimensions: Dim, MASS, LENGTH, TIME, TEMPERATURE, DIMENSIONLESS
using ..Dispositions: Disposition, Derived, Bracketed, value

"""
    InteriorModel

A carried interior model: a `Sourced` law with a declared domain. A subtype answers
`model_locator(m)`; `interior_domain(m)`, a `NamedTuple` with the fields `mass` and
each of `BULK_COMPONENTS`, each a `(low, high)` pair; and
`interior_radius(m, mass, fractions)`, `fractions` a `NamedTuple` over
`BULK_COMPONENTS`, returning a `NamedTuple` with `radius` and `radius_rounding`.
"""
abstract type InteriorModel end

function interior_domain end
function interior_radius end

"The mass fractions a composition bulk declares, by name."
const BULK_COMPONENTS = (:iron, :silicate, :water, :envelope)

"""
    DeclaredBulk(; volumetric_mean_radius)

A planet's bulk declared by its volumetric mean radius, above zero.
"""
struct DeclaredBulk{FT}
    volumetric_mean_radius::Disposition{FT,typeof(LENGTH)}

    DeclaredBulk{FT}(::Checked, r) where {FT} = new{FT}(r)
end

function DeclaredBulk(; kwargs...)
    site = "Systems.DeclaredBulk"
    k, _ = read_keywords(site, values(kwargs), (:volumetric_mean_radius,), ())
    FT = float_type("volumetric_mean_radius", site, k.volumetric_mean_radius)
    r = require_positive("volumetric_mean_radius", site,
        require_disposition("volumetric_mean_radius", site, k.volumetric_mean_radius,
                            FT, LENGTH, DECLARED))
    return DeclaredBulk{FT}(Checked(), r)
end

"""
    CompositionBulk(; iron, silicate, water, envelope, model)

A planet's bulk declared by its four mass fractions, each in `[0, 1]` and together
summing to one within rounding, and the `InteriorModel` its radius is `Derived` from.
"""
struct CompositionBulk{FT,M<:InteriorModel}
    iron::Disposition{FT,typeof(DIMENSIONLESS)}
    silicate::Disposition{FT,typeof(DIMENSIONLESS)}
    water::Disposition{FT,typeof(DIMENSIONLESS)}
    envelope::Disposition{FT,typeof(DIMENSIONLESS)}
    model::M

    CompositionBulk{FT,M}(::Checked, i, s, w, e, m) where {FT,M} = new{FT,M}(i, s, w, e, m)
end

function CompositionBulk(; kwargs...)
    site = "Systems.CompositionBulk"
    k, _ = read_keywords(site, values(kwargs), (BULK_COMPONENTS..., :model), ())
    FT = float_type("iron", site, k.iron)
    fractions = Tuple(require_interval(String(c), site,
                          require_disposition(String(c), site, k[c], FT, DIMENSIONLESS,
                                              DECLARED),
                          zero(FT), true, one(FT), true) for c in BULK_COMPONENTS)
    require_unit_sum("bulk composition", site, fractions)
    model = require_type("model", site, k.model, InteriorModel)
    return CompositionBulk{FT,typeof(model)}(Checked(), fractions..., model)
end

"""
    SiderealRotation(; period, sense)

A planet's rotation declared by its sidereal rotation period, above zero, and its
`sense`, `:prograde` or `:retrograde`, relative to the normal of the planet's orbit.
"""
struct SiderealRotation{FT}
    period::Disposition{FT,typeof(TIME)}
    sense::Symbol

    SiderealRotation{FT}(::Checked, p, s) where {FT} = new{FT}(p, s)
end

"The senses a sidereal rotation is declared with."
const ROTATION_SENSES = (:prograde, :retrograde)

function SiderealRotation(; kwargs...)
    site = "Systems.SiderealRotation"
    k, _ = read_keywords(site, values(kwargs), (:period, :sense), ())
    FT = float_type("period", site, k.period)
    period = require_positive("period", site,
        require_disposition("period", site, k.period, FT, TIME, DECLARED))
    k.sense in ROTATION_SENSES || refuse(
        "sense", site, "$(k.sense) is not one of $(join(ROTATION_SENSES, ", "))")
    return SiderealRotation{FT}(Checked(), period, k.sense)
end

"""
    SynchronousRotation()

A planet's rotation declared synchronous with its orbit, its sidereal rotation period
`Derived` by `System` from the planet's orbit as a `SynchronousPeriod`.
"""
struct SynchronousRotation
    SynchronousRotation(::Checked) = new()
end

function SynchronousRotation(; kwargs...)
    read_keywords("Systems.SynchronousRotation", values(kwargs), (), ())
    return SynchronousRotation(Checked())
end

"""
    SynchronousPeriod

A synchronous rotation as `System` holds it: the sidereal rotation period `Derived`
from the orbital period of the planet's orbit.
"""
struct SynchronousPeriod{FT,N}
    period::Derived{FT,typeof(TIME),N}
end

"The sidereal rotation period of a declared or resolved rotation."
rotation_period(r::SiderealRotation) = r.period
rotation_period(r::SynchronousPeriod) = r.period

"The sense of a rotation relative to the planet's orbit normal."
rotation_sense(r::SiderealRotation) = r.sense
rotation_sense(::SynchronousPeriod) = :synchronous

"The dimension of a thermal diffusivity: length^2 time^-1."
const DIFFUSIVITY = Dim{0,2,-1,0,0}()

"The dimension of a thermal expansivity: temperature^-1."
const EXPANSIVITY = Dim{0,0,0,-1,0}()

"The dimension of a density: mass length^-3."
const DENSITY = Dim{1,-3,0,0,0}()

"The dimension of a heat production per unit mass: length^2 time^-3."
const SPECIFIC_POWER = Dim{0,2,-3,0,0}()

"The scalar members of the lithosphere block and their dimensions, by name."
const LITHOSPHERE_SCALARS = (mantle_potential_temperature = TEMPERATURE,
                             mantle_thermal_diffusivity = DIFFUSIVITY,
                             mantle_thermal_expansivity = EXPANSIVITY,
                             mantle_density = DENSITY,
                             radiogenic_heat_production = SPECIFIC_POWER)

"The per-province-class members of the lithosphere block and their dimensions."
const LITHOSPHERE_PER_CLASS = (crustal_density = DENSITY, crustal_thickness = LENGTH)

"""
    Lithosphere(; province_classes, mantle_potential_temperature,
                  mantle_thermal_diffusivity, mantle_thermal_expansivity,
                  mantle_density, crustal_density, crustal_thickness,
                  radiogenic_heat_production)

The lithosphere block: the named `province_classes`, and every member `Bracketed`
and above zero, `crustal_density` and `crustal_thickness` each a tuple of one value
per province class.
"""
struct Lithosphere{FT,K}
    province_classes::NTuple{K,Symbol}
    mantle_potential_temperature::Bracketed{FT,typeof(TEMPERATURE)}
    mantle_thermal_diffusivity::Bracketed{FT,typeof(DIFFUSIVITY)}
    mantle_thermal_expansivity::Bracketed{FT,typeof(EXPANSIVITY)}
    mantle_density::Bracketed{FT,typeof(DENSITY)}
    radiogenic_heat_production::Bracketed{FT,typeof(SPECIFIC_POWER)}
    crustal_density::NTuple{K,Bracketed{FT,typeof(DENSITY)}}
    crustal_thickness::NTuple{K,Bracketed{FT,typeof(LENGTH)}}

    Lithosphere{FT,K}(::Checked, fields...) where {FT,K} = new{FT,K}(fields...)
end

function Lithosphere(; kwargs...)
    site = "Systems.Lithosphere"
    k, _ = read_keywords(site, values(kwargs),
                         (:province_classes, keys(LITHOSPHERE_SCALARS)...,
                          keys(LITHOSPHERE_PER_CLASS)...), ())
    classes = require_names("province_classes", site, k.province_classes)
    FT = float_type("mantle_potential_temperature", site, k.mantle_potential_temperature)
    member(name, d, dim) = require_positive(String(name), site,
        require_disposition(String(name), site, d, FT, dim, (Bracketed,)))
    scalars = Tuple(member(name, k[name], dim) for (name, dim) in pairs(LITHOSPHERE_SCALARS))
    per_class = Tuple(
        Tuple(member(name, d, dim)
              for d in require_length(String(name), site, k[name], length(classes),
                                      "province class"))
        for (name, dim) in pairs(LITHOSPHERE_PER_CLASS))
    return Lithosphere{FT,length(classes)}(Checked(), classes, scalars..., per_class...)
end

"The keywords of `Planet`."
const PLANET_KEYWORDS = (:mass, :bulk, :rotation, :obliquity, :figure, :lithosphere)

"The Derived values `Planet` checks when a caller supplies them."
const PLANET_CHECKED = (:volumetric_mean_radius,)

"""
    Planet

The planet of a system. Build it with the keyword constructor, which has no defaults:

    Planet(; mass, bulk, rotation, obliquity, figure, lithosphere)

`mass` is above zero. `bulk` is a `DeclaredBulk` or a `CompositionBulk`, whose model
gives the volumetric mean radius as `Derived` inside its domain; a caller may pass
`volumetric_mean_radius` beside a composition bulk to have it checked, and is refused
a second declaration beside a declared one. `rotation` is a `SiderealRotation` or a
`SynchronousRotation`. `obliquity` is an angle in `[0, pi]` measured from the
planet's orbit normal (decision 0004); how the obliquity and the sense place the
rotation pole is fiddlybits-52v.5.7's, and this constructor refuses only an angle
outside that range. `figure` is an
`AbsentFigure` or a `HydrostaticFigure`; `lithosphere` is a `Lithosphere`.
"""
struct Planet{FT,B,R,F,K}
    mass::Disposition{FT,typeof(MASS)}
    bulk::B
    volumetric_mean_radius::Disposition{FT,typeof(LENGTH)}
    rotation::R
    obliquity::Disposition{FT,typeof(DIMENSIONLESS)}
    figure::F
    lithosphere::Lithosphere{FT,K}

    Planet{FT,B,R,F,K}(::Checked, fields...) where {FT,B,R,F,K} = new{FT,B,R,F,K}(fields...)
end

"The field names of `Planet`."
const PLANET_FIELDS = fieldnames(Planet)

"""
    resolve_radius(bulk, mass, supplied, site)

The volumetric mean radius of a bulk: a `DeclaredBulk`'s own, refusing a supplied
second value; or a `CompositionBulk`'s model evaluated inside its domain, `Derived`
and checked against a supplied value within the rounding the model states.
"""
function resolve_radius(bulk::DeclaredBulk, mass, supplied::NamedTuple, site::AbstractString)
    haskey(supplied, :volumetric_mean_radius) && refuse(
        "volumetric_mean_radius", site,
        "declared in the DeclaredBulk already; a second value is refused")
    return bulk.volumetric_mean_radius
end

function resolve_radius(bulk::CompositionBulk{FT}, mass, supplied::NamedTuple,
                        site::AbstractString) where {FT}
    domain = interior_domain(bulk.model)
    source = model_locator(bulk.model).identifier
    for name in (:mass, BULK_COMPONENTS...)
        d = name === :mass ? mass : getfield(bulk, name)
        low, high = domain[name]
        for x in declared_values(d)
            x < low && refuse(String(name), site,
                "$(x) is below the domain [$(low), $(high)] of the interior model $(source)")
            x > high && refuse(String(name), site,
                "$(x) is above the domain [$(low), $(high)] of the interior model $(source)")
        end
    end
    fractions = NamedTuple{BULK_COMPONENTS}(Tuple(value(getfield(bulk, c)) for c in BULK_COMPONENTS))
    result = interior_radius(bulk.model, value(mass), fractions)
    radius = require_type("volumetric_mean_radius", site, result.radius, FT)
    haskey(supplied, :volumetric_mean_radius) && check_supplied_within(
        "volumetric_mean_radius", site, supplied.volumetric_mean_radius, radius,
        result.radius_rounding)
    return Derived(value = radius, dim = LENGTH, from = (:mass, :bulk),
                   rule = :interior_model_radius, fields = PLANET_FIELDS)
end

resolve_radius(bulk, mass, supplied::NamedTuple, site::AbstractString) = refuse(
    "bulk", site, "a $(typeof(bulk)) where a DeclaredBulk or a CompositionBulk is required")

function Planet(; kwargs...)
    site = "Systems.Planet"
    k, supplied = read_keywords(site, values(kwargs), PLANET_KEYWORDS, PLANET_CHECKED)
    FT = float_type("mass", site, k.mass)
    mass = require_positive("mass", site,
        require_disposition("mass", site, k.mass, FT, MASS, DECLARED))
    radius = resolve_radius(k.bulk, mass, supplied, site)
    typeof(value(radius)) === FT || refuse("bulk", site, "the bulk's type differs from the mass's")
    rotation = k.rotation
    (rotation isa SiderealRotation{FT} || rotation isa SynchronousRotation) || refuse(
        "rotation", site,
        "a $(typeof(rotation)) where a SiderealRotation{$(FT)} or a SynchronousRotation " *
        "is required")
    obliquity = require_interval("obliquity", site,
        require_disposition("obliquity", site, k.obliquity, FT, DIMENSIONLESS, DECLARED),
        zero(FT), true, FT(pi), true)
    figure = k.figure
    figure isa AbsentFigure{FT} || refuse(
        "figure", site, "a $(typeof(figure)) where an AbsentFigure{$(FT)} is required")
    lithosphere = require_type("lithosphere", site, k.lithosphere, Lithosphere{FT})
    return Planet{FT,typeof(k.bulk),typeof(rotation),typeof(figure),
                  length(lithosphere.province_classes)}(
        Checked(), mass, k.bulk, radius, rotation, obliquity, figure, lithosphere)
end

"""
    with_rotation(planet, rotation)

`planet` with its rotation replaced by `rotation`, the step by which `System` holds a
synchronous rotation as its `SynchronousPeriod`.
"""
function with_rotation(p::Planet{FT,B,R,F,K}, rotation) where {FT,B,R,F,K}
    return Planet{FT,B,typeof(rotation),F,K}(
        Checked(), p.mass, p.bulk, p.volumetric_mean_radius, rotation, p.obliquity,
        p.figure, p.lithosphere)
end
