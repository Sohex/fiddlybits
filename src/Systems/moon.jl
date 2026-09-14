# One moon: mass, radius and a Sourced reflectance spectrum.
# docs/plans/fiddlybits-52v.4-system.md, section "The struct"; decisions 0004 (moons)
# and 0032.

using ..Verdicts: refuse
using ..Dimensions: MASS, LENGTH, DIMENSIONLESS
using ..Dispositions: Disposition, Sourced, value

"""
    ReflectanceTable(; wavelengths, reflectance)

A reflectance spectrum: strictly increasing positive `wavelengths` in metres and one
reflectance in `[0, 1]` per wavelength.
"""
struct ReflectanceTable{FT}
    wavelengths::Vector{FT}
    reflectance::Vector{FT}

    ReflectanceTable{FT}(::Checked, w, r) where {FT} = new{FT}(w, r)
end

function ReflectanceTable(; kwargs...)
    site = "Systems.ReflectanceTable"
    k, _ = read_keywords(site, values(kwargs), (:wavelengths, :reflectance), ())
    w = require_type("wavelengths", site, k.wavelengths, Vector{<:AbstractFloat})
    FT = eltype(w)
    (strictly_increasing(w) && w[1] > zero(FT)) || refuse(
        "wavelengths", site, "the wavelengths are not positive and strictly increasing")
    r = require_type("reflectance", site, k.reflectance, Vector{FT})
    length(r) == length(w) || refuse(
        "reflectance", site,
        "$(length(r)) values where $(length(w)), one per wavelength, are required")
    all(x -> zero(FT) <= x <= one(FT), r) || refuse(
        "reflectance", site, "a reflectance lies outside [0, 1]")
    return ReflectanceTable{FT}(Checked(), w, r)
end

"""
    Moon

One moon of a system. Build it with the keyword constructor, which has no defaults:

    Moon(; mass, radius, reflectance)

`mass` and `radius` are above zero; `reflectance` is a `Sourced` `ReflectanceTable`,
dimensionless, whose locator names the input it is read from.
"""
struct Moon{FT}
    mass::Disposition{FT,typeof(MASS)}
    radius::Disposition{FT,typeof(LENGTH)}
    reflectance::Sourced{ReflectanceTable{FT},typeof(DIMENSIONLESS)}

    Moon{FT}(::Checked, m, r, s) where {FT} = new{FT}(m, r, s)
end

function Moon(; kwargs...)
    site = "Systems.Moon"
    k, _ = read_keywords(site, values(kwargs), (:mass, :radius, :reflectance), ())
    FT = float_type("mass", site, k.mass)
    mass = require_positive("mass", site,
        require_disposition("mass", site, k.mass, FT, MASS, DECLARED))
    radius = require_positive("radius", site,
        require_disposition("radius", site, k.radius, FT, LENGTH, DECLARED))
    reflectance = require_type("reflectance", site, k.reflectance,
                               Sourced{ReflectanceTable{FT},typeof(DIMENSIONLESS)})
    return Moon{FT}(Checked(), mass, radius, reflectance)
end
