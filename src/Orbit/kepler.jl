# Kepler's equation solved to rounding for any eccentricity below one (decision
# 0008). The form is measured in
# notes/findings/2026-09-10-kepler-in-a-portable-kernel.md; the residual and the
# derivative are Markley equations 30 to 35.

"""
    e_minus_sin(E)

`E - sin(E)`, evaluated without the cancellation of the direct subtraction.
Below half a radian the series through `E^15` is used, above it the subtraction.
"""
@inline function e_minus_sin(E::T) where {T<:AbstractFloat}
    if abs(E) < T(0.5)
        E2 = E * E
        return E * E2 * @evalpoly(E2,
            T(1//6), T(-1//120), T(1//5040), T(-1//362880),
            T(1//39916800), T(-1//6227020800), T(1//1307674368000))
    else
        return E - sin(E)
    end
end

"""
    kepler_residual(E, e, M)

`(1 - e) E + e (E - sin E) - M`, which is Kepler's equation with its two leading
terms kept positive and of comparable size.
"""
@inline kepler_residual(E::T, e::T, M::T) where {T} =
    (one(T) - e) * E + e * e_minus_sin(E) - M

"""
    kepler_derivative(E, e)

`1 - e + 2 e sin^2(E/2)`, Markley equation 30.
"""
@inline kepler_derivative(E::T, e::T) where {T} =
    (one(T) - e) + 2 * e * abs2(sin(E / 2))

"""
    naive_kepler_residual(E, e, M)

`E - e sin E - M`. The positive control of `system.kepler_period`: it must fail
the oracle, and a solve built on it must not be used.
"""
@inline naive_kepler_residual(E::T, e::T, M::T) where {T} = E - e * sin(E) - M

"""
    markley_start(M, e)

Markley's closed-form solution, equations 20, 5, 9, 10, 14, 15 for the cubic's
root and 21 to 29 for its three corrections. Not iterative: four transcendental
evaluations and a fixed sequence of arithmetic.
"""
@inline function markley_start(M::T, e::T) where {T<:AbstractFloat}
    pi2 = abs2(T(pi))
    alpha = (3 * pi2 + 8 * (pi2 - T(pi) * abs(M)) / (5 * (1 + e))) / (pi2 - 6)
    d = 3 * (1 - e) + alpha * e
    q = 2 * alpha * d * (1 - e) - M * M
    r = 3 * alpha * d * (d - 1 + e) * M + M * M * M
    w = cbrt(abs2(abs(r) + sqrt(q * q * q + r * r)))
    E1 = (2 * r * w / @evalpoly(w, q * q, q, one(T)) + M) / d
    s, c = sincos(E1)
    f2 = e * s
    f3 = e * c
    f0 = E1 - f2 - M
    f1 = one(T) - f3
    d3 = -f0 / (f1 - f0 * f2 / (2 * f1))
    d4 = -f0 / @evalpoly(d3, f1, f2 / 2, f3 / 6)
    d5 = -f0 / @evalpoly(d4, f1, f2 / 2, f3 / 6, -f2 / 24)
    return E1 + d5
end

"""
    eccentric_anomaly(M, e)

The eccentric anomaly in `[-pi, pi]` from the mean anomaly and the eccentricity,
by Markley's closed form followed by two Newton steps on the stable residual.
The iteration count is fixed, so every lane does the same work.

The eccentricity is not checked here. An eccentricity outside the elliptic range
is refused once by the `System` constructor, where a refusal has somewhere to go.
"""
@inline function eccentric_anomaly(M::T, e::T) where {T<:AbstractFloat}
    Mr = rem2pi(M, RoundNearest)
    iszero(Mr) && return zero(T)
    E = markley_start(Mr, e)
    E -= kepler_residual(E, e, Mr) / kepler_derivative(E, e)
    E -= kepler_residual(E, e, Mr) / kepler_derivative(E, e)
    return E
end

"""
    true_anomaly(E, e)

The true anomaly from the eccentric anomaly, by the half-angle form.
"""
@inline true_anomaly(E::T, e::T) where {T} =
    2 * atan(sqrt((one(T) + e) / (one(T) - e)) * tan(E / 2))

"""
    check_eccentricity(e, site)

`e` if it is in the elliptic range, a `Refusal` naming `site` otherwise. Called
once by the `System` constructor. `eccentric_anomaly` does not call it: a refusal
raised in a per-cell kernel has nowhere to go.
"""
function check_eccentricity(e, site)
    (zero(e) <= e < one(e)) && return e
    Verdicts.refuse("eccentricity", site,
                    "outside the elliptic range [0, 1): " * string(e))
end
