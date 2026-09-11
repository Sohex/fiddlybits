# Kepler's equation solved to rounding for any eccentricity below one (decision
# 0008). The form is measured in
# notes/findings/2026-09-10-kepler-in-a-portable-kernel.md; the residual and the
# derivative are Markley equations 30 to 35. Every transcendental call and every
# multiply that feeds an add takes a `Backend` (decision 0029), per
# notes/findings/2026-09-11-polynomial-transcendentals-for-bitwise-mode.md. The
# multiply is `fma` in bitwise mode and a plain multiply otherwise (decision 0044).

using ..Backends: Backend, bitwise, sine, sine_cosine, cube_root, nofuse_mul

"""
    fma_add(a, b, c, backend)

`fma(a, b, c)` when `backend` runs in bitwise mode and `a * b + c` otherwise
(decision 0044).
"""
@inline fma_add(a, b, c, backend::Backend) = bitwise(backend) ? fma(a, b, c) : a * b + c

"""
    barrier_mul(a, b, backend)

`a * b`, through `Backends.nofuse_mul` when `backend` runs in bitwise mode and
as a plain multiply otherwise (decision 0044). Used where the product is read
by more than one later expression, so it must be rounded once before any of
them sees it.
"""
@inline barrier_mul(a, b, backend::Backend) = bitwise(backend) ? nofuse_mul(a, b) : a * b

"""
    kepler_poly(z, c, backend)

The Horner evaluation at `z` of the polynomial with coefficients `c`, the
constant term first, through `fma_add`.
"""
@inline kepler_poly(z::T, c::Tuple{T}, backend::Backend) where {T<:AbstractFloat} = c[1]
@inline kepler_poly(z::T, c::Tuple{T,T,Vararg{T}}, backend::Backend) where {T<:AbstractFloat} =
    fma_add(kepler_poly(z, Base.tail(c), backend), z, c[1], backend)

"""
    e_minus_sin(E, backend)

`E - sin(E)`, evaluated without the cancellation of the direct subtraction.
Below half a radian the series through `E^15` is used, above it the subtraction
against `Backends.sine`.
"""
@inline function e_minus_sin(E::T, backend::Backend) where {T<:AbstractFloat}
    if abs(E) < T(0.5)
        E2 = E * E
        return E * E2 * kepler_poly(E2,
            (T(1//6), T(-1//120), T(1//5040), T(-1//362880),
             T(1//39916800), T(-1//6227020800), T(1//1307674368000)), backend)
    else
        return E - sine(E, backend)
    end
end

"""
    kepler_residual(E, e, M, backend)

`(1 - e) E + e (E - sin E) - M`, which is Kepler's equation with its two leading
terms kept positive and of comparable size.
"""
@inline kepler_residual(E::T, e::T, M::T, backend::Backend) where {T} =
    fma_add(one(T) - e, E, e * e_minus_sin(E, backend), backend) - M

"""
    kepler_derivative(E, e, backend)

`1 - e + 2 e sin^2(E/2)`, Markley equation 30.
"""
@inline kepler_derivative(E::T, e::T, backend::Backend) where {T} =
    fma_add(2 * e, abs2(sine(E / 2, backend)), one(T) - e, backend)

"""
    naive_kepler_residual(E, e, M)

`E - e sin E - M`. The positive control of `system.kepler_period`: it must fail
the oracle, and a solve built on it must not be used.
"""
@inline naive_kepler_residual(E::T, e::T, M::T) where {T} = E - e * sin(E) - M

"""
    markley_start(M, e, backend)

Markley's closed-form solution, equations 20, 5, 9, 10, 14, 15 for the cubic's
root and 21 to 29 for its three corrections. Not iterative: four transcendental
evaluations and a fixed sequence of arithmetic, through `backend`.
"""
@inline function markley_start(M::T, e::T, backend::Backend) where {T<:AbstractFloat}
    pi2 = abs2(T(pi))
    alpha = fma_add(T(3), pi2,
             8 * fma_add(-T(pi), abs(M), pi2, backend) / (5 * (1 + e)), backend) / (pi2 - 6)
    d = fma_add(T(3), 1 - e, alpha * e, backend)
    q = fma_add(2 * alpha * d, 1 - e, -(M * M), backend)
    r = fma_add(3 * alpha * d * (d - 1 + e), M, M * M * M, backend)
    w = cube_root(abs2(abs(r) + sqrt(fma_add(q * q, q, r * r, backend))), backend)
    E1 = (2 * r * w / kepler_poly(w, (q * q, q, one(T)), backend) + M) / d
    s, c = sine_cosine(E1, backend)
    f2 = barrier_mul(e, s, backend)
    f3 = barrier_mul(e, c, backend)
    f0 = E1 - f2 - M
    f1 = one(T) - f3
    d3 = -f0 / (f1 - f0 * f2 / (2 * f1))
    d4 = -f0 / kepler_poly(d3, (f1, f2 / 2, f3 / 6), backend)
    d5 = -f0 / kepler_poly(d4, (f1, f2 / 2, f3 / 6, -f2 / 24), backend)
    return E1 + d5
end

"""
    eccentric_anomaly(M, e, backend)

The eccentric anomaly in `[-pi, pi]` from the mean anomaly and the eccentricity,
by Markley's closed form followed by two Newton steps on the stable residual.
The iteration count is fixed, so every lane does the same work. Every
transcendental call and every multiply that feeds an add routes through
`backend` (decision 0029); `rem2pi` does not and is called directly.

The eccentricity is not checked here. An eccentricity outside the elliptic range
is refused once by the `System` constructor, where a refusal has somewhere to go.
"""
@inline function eccentric_anomaly(M::T, e::T, backend::Backend) where {T<:AbstractFloat}
    Mr = rem2pi(M, RoundNearest)
    iszero(Mr) && return zero(T)
    E = markley_start(Mr, e, backend)
    E -= kepler_residual(E, e, Mr, backend) / kepler_derivative(E, e, backend)
    E -= kepler_residual(E, e, Mr, backend) / kepler_derivative(E, e, backend)
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
