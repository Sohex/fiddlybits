# The figure of the planet: a hydrostatic figure whose flattening is Derived from the
# rotation and the interior's moment-of-inertia factor, or a declared absence with the
# equator-pole gravity difference Bracketed. docs/plans/fiddlybits-52v.4-system.md,
# section "The struct"; decision 0004, the planet's bulk. The relations are read from
# Murray and Dermott (1999), Solar System Dynamics, 10.1017/CBO9781139174817, at the
# locators each docstring names.

using ..Verdicts: refuse
using ..Dimensions: DIMENSIONLESS
using ..Dispositions: Bracketed, Derived, Disposition, value
using ..Reductions: error_bound

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
    MOMENT_OF_INERTIA_FACTOR_RANGE

`(2, 15, 2, 5)`: the moment-of-inertia factor `C / (m R^2)` of Eq. (4.113) that
`HydrostaticFigure` admits lies in `[2 / 15, 2 / 5]`, the range over which Murray and
Dermott (1999), Fig. 4.9, p. 154, draws the Darwin-Radau relation: from the zero of
`J2 / f` in Eq. (4.119), p. 154, at `2 / 15`, to `2 / 5`, where it meets the
point-core model of Eq. (4.118). Numerators and denominators, over `Integer`.
"""
const MOMENT_OF_INERTIA_FACTOR_RANGE = (2, 15, 2, 5)

"""
    HydrostaticFigure(; moment_of_inertia_factor)

The hydrostatic figure of the planet as declared: the interior's moment-of-inertia
factor `C / (m R^2)` of Murray and Dermott (1999), Eq. (4.113), p. 153, dimensionless,
`Sourced`, `Bracketed` or `Irreducible`, with every value it declares in the range
`MOMENT_OF_INERTIA_FACTOR_RANGE` names. Its flattening is `Derived` on a planet by
`hydrostatic_flattening`, which reads the planet's rotation.
"""
struct HydrostaticFigure{FT}
    moment_of_inertia_factor::Disposition{FT,typeof(DIMENSIONLESS)}

    HydrostaticFigure{FT}(::Checked, c) where {FT} = new{FT}(c)
end

function HydrostaticFigure(; kwargs...)
    site = "Systems.HydrostaticFigure"
    k, _ = read_keywords(site, values(kwargs), (:moment_of_inertia_factor,), ())
    FT = float_type("moment_of_inertia_factor", site, k.moment_of_inertia_factor)
    low_n, low_d, high_n, high_d = MOMENT_OF_INERTIA_FACTOR_RANGE
    c = require_interval("moment_of_inertia_factor", site,
        require_disposition("moment_of_inertia_factor", site, k.moment_of_inertia_factor,
                            FT, DIMENSIONLESS, DECLARED),
        FT(low_n) / low_d, true, FT(high_n) / high_d, true)
    return HydrostaticFigure{FT}(Checked(), c)
end

"""
    HydrostaticFlattening

A `HydrostaticFigure` resolved on its planet by `hydrostatic_flattening`: the declared
moment-of-inertia factor, and the flattening `(r_equatorial - r_pole) / r_equatorial`
of Murray and Dermott (1999), Eq. (4.101), p. 150, `Derived` by the rule
`:darwin_radau_flattening` from the planet's mass, volumetric mean radius, rotation
and figure.
"""
struct HydrostaticFlattening{FT,N}
    moment_of_inertia_factor::Disposition{FT,typeof(DIMENSIONLESS)}
    flattening::Derived{FT,typeof(DIMENSIONLESS),N}

    HydrostaticFlattening{FT,N}(::Checked, c, f) where {FT,N} = new{FT,N}(c, f)
end

"""
    rotation_parameter(FT, mass, radius, period)

`q = omega^2 a^3 / (G m)`, Murray and Dermott (1999), Eq. (4.102), p. 150: the ratio
of the centrifugal acceleration at the equator to the gravitational acceleration, at
`omega = rotation_rate(FT, period)` and `G m = gravitational_parameter(FT, mass)`,
with `radius` read as `a`.
"""
function rotation_parameter(::Type{FT}, mass::FT, radius::FT,
                            period::FT) where {FT<:AbstractFloat}
    omega = rotation_rate(FT, period)
    return (omega * omega * radius) * (radius * radius) / gravitational_parameter(FT, mass)
end

"""
The rounded operations of `rotation_parameter`: the rounding of `pi`, the divide
giving the rotation rate, the two multiplies of the centrifugal term, the multiply of
the square of the radius and the multiply combining the two, the rounding of `G`, the
multiply by the mass, and the divide.
"""
const ROTATION_PARAMETER_TERMS = 9

"""
    darwin_radau_flattening(FT, moment_of_inertia_factor, rotation_parameter)

`f = (5 q / 2) / (1 + (25 / 4) (1 - 3 C / 2)^2)`: the Darwin-Radau relation of Murray
and Dermott (1999), Eq. (4.112), p. 153,
`C / (m R^2) = (2 / 3) (1 - (2 / 5) sqrt(5 q / (2 f) - 1))`, solved for the
flattening `f` of Eq. (4.101) at the moment-of-inertia factor `C` of Eq. (4.113) and
the rotation parameter `q` of Eq. (4.102), for `1 - 3 C / 2` not negative. The book
states the relation as approximate and resting on hydrostatic equilibrium (p. 153),
and its derivation drops the last term of Eq. (4.99) for `omega^2 a` much below
`G m / a^2` (p. 150) and `J4` and above in Eq. (4.109) (p. 152).
"""
function darwin_radau_flattening(::Type{FT}, c::FT, q::FT) where {FT<:AbstractFloat}
    u = fma(-FT(3) / 2, c, one(FT))
    return (FT(5) / 2 * q) / fma(FT(25) / 4, u * u, one(FT))
end

"""
The rounded operations of `darwin_radau_flattening` over exact arguments: the fused
`1 - 3 C / 2`, its square, the fused `1 + (25 / 4) u^2`, the multiply of `q`, and the
divide. The constants `3 / 2`, `25 / 4` and `5 / 2` are exact.
"""
const DARWIN_RADAU_TERMS = 5

"""
    flattening_rounding(FT, flattening)

`Reductions.error_bound(FT, ROTATION_PARAMETER_TERMS + DARWIN_RADAU_TERMS,
flattening)`: the bound on the rounding of one evaluation of `darwin_radau_flattening`
at the `rotation_parameter` of a planet's stored values.
"""
flattening_rounding(::Type{FT}, f::FT) where {FT<:AbstractFloat} =
    error_bound(FT, ROTATION_PARAMETER_TERMS + DARWIN_RADAU_TERMS, f)

"""
    hydrostatic_flattening(figure, planet)

The `HydrostaticFlattening` of `figure` on `planet`, a `Planet` of the figure's float
type whose rotation is a `SiderealRotation` or a `SynchronousPeriod`: the flattening
`darwin_radau_flattening` gives at the figure's moment-of-inertia factor and the
`rotation_parameter` of the planet's mass, volumetric mean radius and rotation
period. Refuses a rotation parameter at or above one, the extreme case `q -> 1` of
Murray and Dermott (1999), Eq. (4.103), p. 150, and a planet whose rotation is a
`SynchronousRotation` not yet resolved by `System`.
"""
function hydrostatic_flattening(figure::HydrostaticFigure{FT}, p) where {FT}
    site = "Systems.hydrostatic_flattening"
    p isa Planet{FT} || refuse(
        "planet", site, "a $(typeof(p)) where a Planet{$(FT)} is required")
    (p.rotation isa SiderealRotation || p.rotation isa SynchronousPeriod) || refuse(
        "rotation", site,
        "the planet's rotation is a $(nameof(typeof(p.rotation))); the flattening is " *
        "read from the planet a System holds, whose rotation is resolved")
    q = rotation_parameter(FT, value(p.mass), value(p.volumetric_mean_radius),
                           value(rotation_period(p.rotation)))
    q < one(FT) || refuse(
        "rotation", site,
        "the rotation parameter $(q) is not below one, the extreme case of Murray and " *
        "Dermott (1999), Eq. (4.103)")
    f = darwin_radau_flattening(FT, value(figure.moment_of_inertia_factor), q)
    flattening = Derived(value = f, dim = DIMENSIONLESS,
                         from = (:mass, :volumetric_mean_radius, :rotation, :figure),
                         rule = :darwin_radau_flattening, fields = PLANET_FIELDS)
    return HydrostaticFlattening{FT,4}(Checked(), figure.moment_of_inertia_factor,
                                       flattening)
end
