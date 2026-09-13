# The figure of the planet: a Derived hydrostatic figure, or a declared absence with
# the equator-pole gravity difference Bracketed. docs/plans/fiddlybits-52v.4-system.md,
# section "The struct"; decision 0004, the planet's bulk.

using ..Verdicts: refuse
using ..Dimensions: DIMENSIONLESS
using ..Dispositions: Bracketed, Disposition, value

"""
    AbsentFigure(; equator_pole_gravity_difference)

The figure of the planet declared absent: the planet is read as a sphere of its
volumetric mean radius, and the difference between polar and equatorial surface
gravity the absent figure would add is a `Bracketed` acceleration, zero or above,
reported beside every result that reads gravity.
"""
struct AbsentFigure{FT}
    equator_pole_gravity_difference::Bracketed{FT,typeof(ACCELERATION)}

    AbsentFigure{FT}(::Checked, d) where {FT} = new{FT}(d)
end

function AbsentFigure(; kwargs...)
    site = "Systems.AbsentFigure"
    k, _ = read_keywords(site, values(kwargs), (:equator_pole_gravity_difference,), ())
    FT = float_type("equator_pole_gravity_difference", site,
                    k.equator_pole_gravity_difference)
    d = require_interval("equator_pole_gravity_difference", site,
        require_disposition("equator_pole_gravity_difference", site,
                            k.equator_pole_gravity_difference, FT, ACCELERATION,
                            (Bracketed,)),
        zero(FT), true, typemax(FT), true)
    return AbsentFigure{FT}(Checked(), d)
end

"""
    HydrostaticFigure(; moment_of_inertia_factor)

The hydrostatic figure of the planet, its flattening `Derived` from the rotation and
the interior's moment-of-inertia factor. The rule is not carried: the constructor
reads its keyword and refuses, naming fiddlybits-52v.4.11, which carries the rule
and the source it is read from.
"""
struct HydrostaticFigure{FT}
    moment_of_inertia_factor::Disposition{FT,typeof(DIMENSIONLESS)}
end

function HydrostaticFigure(; kwargs...)
    site = "Systems.HydrostaticFigure"
    read_keywords(site, values(kwargs), (:moment_of_inertia_factor,), ())
    refuse("figure", site,
           "the hydrostatic figure's flattening rule is not carried; it is " *
           "fiddlybits-52v.4.11, and until then the figure is an AbsentFigure")
end
