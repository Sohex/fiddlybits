# Gravity as the canonical Derived field g(r, phi), and the two-body orbital period,
# at the Newtonian constant of gravitation. docs/plans/fiddlybits-52v.4-system.md,
# section "The struct"; decision 0004, the planet's bulk. The relations are read from
# Murray and Dermott (1999), Solar System Dynamics, 10.1017/CBO9781139174817, at the
# locators each docstring names.

using ..Verdicts: refuse
using ..Dispositions: value
using ..Reductions: error_bound

"""
    gravitational_parameter(FT, mass)

`G mass` at the constant of `gravitational_constant(FT)`: the `mu = G (m1 + m2)` of
Murray and Dermott (1999), p. 24, below Eq. (2.5), for `mass` the masses summed.
"""
gravitational_parameter(::Type{FT}, mass::FT) where {FT<:AbstractFloat} =
    value(gravitational_constant(FT)) * mass

"""
    rotation_rate(FT, period)

`2 pi / period`: the magnitude of the angular velocity of a rotation of `period`, the
`n = 2 pi / T` of Murray and Dermott (1999), Eq. (2.25), p. 29, for an angle covering
`2 pi` in one period.
"""
rotation_rate(::Type{FT}, period::FT) where {FT<:AbstractFloat} = 2 * FT(pi) / period

"""
    gravity(planet, radial_distance, geocentric_latitude)

The magnitude of the effective gravity at `radial_distance` from the planet's centre
and at `geocentric_latitude` in radians: the point-mass attraction `G M / r^2` of
the planet's mass and the centrifugal acceleration `omega^2 r cos(phi)` of its
rotation, combined as a radial and a tangential component. The total potential
`-G m / r + V_cf` of Murray and Dermott (1999), Eq. (4.97), p. 150, with the
centrifugal potential `V_cf = -(1 / 2) omega^2 r^2 sin^2(theta)` of Eq. (4.96) and its
acceleration `omega^2 (x, y)` of Eq. (4.95), p. 149, at the colatitude
`theta = pi / 2 - phi`. Refuses a planet whose rotation is a `SynchronousRotation`
not yet resolved by `System`.
"""
function gravity(p::Planet{FT,B,R}, r::FT, phi::FT) where
        {FT<:AbstractFloat,B,R<:Union{SiderealRotation,SynchronousPeriod}}
    gm = gravitational_parameter(FT, value(p.mass))
    omega = rotation_rate(FT, value(rotation_period(p.rotation)))
    c = cos(phi)
    s = sin(phi)
    centrifugal = omega * omega * r
    radial = fma(-centrifugal, c * c, gm / (r * r))
    tangential = centrifugal * c * s
    return hypot(radial, tangential)
end

gravity(p::Planet, r, phi) = refuse(
    "gravity", "Systems.gravity",
    "the planet's rotation is a $(nameof(typeof(p.rotation))); gravity is read from " *
    "the planet a System holds, whose rotation is resolved")

"""
The rounded operations of the longest path through `gravity`, the tangential
component and the centrifugal part of the radial one alike: four for the centrifugal
term (the rounding of `pi`, the divide giving the rotation rate, two multiplies), two
for each of the two library transcendentals it is multiplied by, being within one
ulp, two for the two rounded products or the product and the fused add that combine
them, and one for `hypot`.
"""
const GRAVITY_TERMS = 11

"""
    gravity_magnitude(planet, radial_distance, geocentric_latitude)

`G M / r^2 + omega^2 r (cos^2 phi + |cos phi sin phi|)`: the sum of the absolute
values of the terms `gravity` combines, the magnitude `Reductions.error_bound` takes.
"""
function gravity_magnitude(p::Planet{FT}, r::FT, phi::FT) where {FT<:AbstractFloat}
    gm = gravitational_parameter(FT, value(p.mass))
    omega = rotation_rate(FT, value(rotation_period(p.rotation)))
    c = cos(phi)
    return fma(omega * omega * r, fma(c, c, abs(c * sin(phi))), gm / (r * r))
end

"""
    gravity_rounding(planet, radial_distance, geocentric_latitude)

`Reductions.error_bound(FT, GRAVITY_TERMS, gravity_magnitude(...))`: the bound on the
rounding of one evaluation of `gravity` at these arguments.
"""
gravity_rounding(p::Planet{FT}, r::FT, phi::FT) where {FT<:AbstractFloat} =
    error_bound(FT, GRAVITY_TERMS, gravity_magnitude(p, r, phi))

"""
    orbital_period(FT, semi_major_axis, masses)

`2 pi sqrt(a^3 / (G sum(masses)))`: the period of a two-body orbit of semi-major
axis `a` whose two bodies hold `masses` together, `T^2 = 4 pi^2 a^3 / mu` of Murray
and Dermott (1999), Eq. (2.22), p. 28, with `mu = G (m1 + m2)` of p. 24.
"""
orbital_period(::Type{FT}, a::FT, masses::Tuple) where {FT<:AbstractFloat} =
    2 * FT(pi) * sqrt((a * a * a) / (value(gravitational_constant(FT)) * sum(masses)))

"""
    orbital_period_terms(n)

The rounded operations of `orbital_period` over `n` masses: the rounding of `pi` and
of `G`, the two multiplies of the cube, the `n - 1` additions of the masses, the
multiply by `G`, the divide, the square root and the final multiply. The multiply by
two is exact. Over `Integer`.
"""
orbital_period_terms(n::Integer) = n + 7
