# The project's own polynomial transcendentals: docs/plans/
# fiddlybits-52v.7-kernels.md, section "The device layer", and decision 0029's
# bitwise mode. The coefficient dispositions, the measured error bounds, the
# argument for them and the cost of the fusion barrier are in
# notes/findings/2026-09-11-polynomial-transcendentals-for-bitwise-mode.md.

"""
    horner(z, coefficients)

The polynomial with `coefficients` in ascending degree evaluated at `z` by
Horner's rule, every multiply-and-add a single `fma`. `coefficients` is a
`Tuple` of `Float64`, read leading coefficient last.
"""
@inline horner(z::Float64, c::Tuple{Float64}) = c[1]
@inline horner(z::Float64, c::Tuple{Float64,Float64,Vararg{Float64}}) =
    fma(horner(z, Base.tail(c)), z, c[1])

"""
    two_power(k)

`2.0^k` for `k` in `-1022:1023`, built from the exponent field. `k` outside
that range is clamped to it, so a caller splitting a large exponent across
two factors gets each factor as a normal number.
"""
@inline function two_power(k::Int32)
    kk = clamp(k, Int32(-1022), Int32(1023))
    return reinterpret(Float64, UInt64(kk + Int32(1023)) << 52)
end

"""
    scale_two(v, k)

`v * 2.0^k` for `k` in `-2000:2000`, as two multiplications by normal powers
of two. Overflows to `Inf` and underflows through the subnormals the way a
multiplication does.
"""
@inline function scale_two(v::Float64, k::Int32)
    a = clamp(k, Int32(-1000), Int32(1000))
    b = clamp(k - a, Int32(-1000), Int32(1000))
    return v * two_power(a) * two_power(b)
end

"""
    split_exponent(x)

`(e, m)` with `x == m * 2.0^e` and `m` in `[1, 2)`, for finite positive `x`
including the subnormals. Reads the exponent and significand fields directly
rather than through `exponent` and `significand`, which carry throwing
branches.
"""
@inline function split_exponent(x::Float64)
    sub = (reinterpret(UInt64, x) & 0x7ff0000000000000) == 0x0000000000000000
    xs = ifelse(sub, x * 1.8014398509481984e16, x)
    shift = ifelse(sub, Int32(-54), Int32(0))
    u = reinterpret(UInt64, xs)
    e = Int32((u >> 52) & 0x00000000000007ff) - Int32(1023) + shift
    m = reinterpret(Float64, (u & 0x000fffffffffffff) | 0x3ff0000000000000)
    return e, m
end

# pi/2 in three parts, the first two carrying 33 significant bits each so that
# their products with the quadrant index are exact over the declared argument
# range. Disposition Derived: pi/2 at 300 bits, split by clearing the low 20
# mantissa bits of each part in turn.
const PIO2_A = 1.5707963267341256
const PIO2_B = 6.077100506303966e-11
const PIO2_C = 2.0222662487959506e-21
const TWO_OVER_PI = 0.6366197723675814

"""
    TRIG_ARGUMENT_LIMIT

The largest `abs(x)` `sine`, `cosine` and `sine_cosine` reduce. Above it they
return `NaN` rather than a reduced argument the three-part split cannot carry.
"""
const TRIG_ARGUMENT_LIMIT = 262144.0

# sin(r) = r + r^3 * SIN_SERIES(r^2) and
# cos(r) = 1 - r^2/2 + r^4 * COS_SERIES(r^2), coefficients (-1)^k/(2k+3)! and
# (-1)^k/(2k+4)!. Disposition Derived: the Taylor series of the function at
# zero, evaluated at 300 bits and rounded once, truncated where the next term
# is below 1e-19 in absolute value over abs(r) <= pi/4.
const SIN_SERIES = (-0.16666666666666666, 0.008333333333333333,
                    -0.0001984126984126984, 2.7557319223985893e-6,
                    -2.505210838544172e-8, 1.6059043836821613e-10,
                    -7.647163731819816e-13, 2.8114572543455206e-15)
const COS_SERIES = (0.041666666666666664, -0.001388888888888889,
                    2.48015873015873e-5, -2.755731922398589e-7,
                    2.08767569878681e-9, -1.1470745597729725e-11,
                    4.779477332387385e-14, -1.5619206968586225e-16)

"""
    two_sum(a, b)

`(s, e)` with `s == a + b` rounded and `e` the rounding error, so that
`a + b == s + e` exactly. Six operations, no ordering condition on `a` and
`b`.
"""
@inline function two_sum(a::Float64, b::Float64)
    s = a + b
    bb = s - a
    return s, (a - (s - bb)) + (b - bb)
end

"""
    sin_core(r, rlo)

The sine of `r + rlo` for `abs(r) <= pi/4` and `abs(rlo)` below the ulp of
`r`, as `r + r^3 * SIN_SERIES(r^2)` with the first-order term in `rlo`.
"""
@inline function sin_core(r::Float64, rlo::Float64)
    z = r * r
    v = z * r
    t = fma(0.5, rlo, -(v * horner(z, Base.tail(SIN_SERIES))))
    return r - fma(-v, SIN_SERIES[1], fma(z, t, -rlo))
end

"""
    cos_core(r, rlo)

The cosine of `r + rlo` for `abs(r) <= pi/4` and `abs(rlo)` below the ulp of
`r`, as `1 - r^2/2 + r^4 * COS_SERIES(r^2)` with the leading `1 - r^2/2`
carried in two parts and the first-order term in `rlo`.
"""
@inline function cos_core(r::Float64, rlo::Float64)
    z = r * r
    hz = 0.5 * z
    w = 1.0 - hz
    return w + (((1.0 - w) - hz) + fma(-r, rlo, z * z * horner(z, COS_SERIES)))
end

"""
    quadrant_reduce(x)

`(q, r, rlo)` with `q` the quadrant index `mod(round(x * 2/pi), 4)` and
`r + rlo` the reduced argument in `[-pi/4, pi/4]`, by subtracting the three
parts of `pi/2` in turn with the second subtraction's rounding error carried.
Valid for `abs(x) <= TRIG_ARGUMENT_LIMIT`.
"""
@inline function quadrant_reduce(x::Float64)
    n = round(x * TWO_OVER_PI)
    r0 = fma(-n, PIO2_A, x)
    r, e = two_sum(r0, -(n * PIO2_B))
    return unsafe_trunc(Int32, n) & Int32(3), r, fma(-n, PIO2_C, e)
end

"""
    sine_cosine_poly(x)

`(sine, cosine)` of `x` from the project's own polynomials. The sine of a
signed zero carries the sign of `x`. Returns `(NaN, NaN)` for
`abs(x) > TRIG_ARGUMENT_LIMIT` and for a non-finite `x`.
"""
@inline function sine_cosine_poly(x::Float64)
    inrange = abs(x) <= TRIG_ARGUMENT_LIMIT
    xr = ifelse(inrange, x, 0.0)
    q, r, rlo = quadrant_reduce(xr)
    s = sin_core(r, rlo)
    c = cos_core(r, rlo)
    sn = ifelse(q == Int32(0), s, ifelse(q == Int32(1), c, ifelse(q == Int32(2), -s, -c)))
    cs = ifelse(q == Int32(0), c, ifelse(q == Int32(1), -s, ifelse(q == Int32(2), -c, s)))
    sn = ifelse(x == 0.0, x, sn)
    return ifelse(inrange, sn, NaN), ifelse(inrange, cs, NaN)
end

"""
    sine_poly(x)

The sine of `x` from the project's own polynomials, with the range and the
non-finite behaviour of `sine_cosine_poly`.
"""
@inline sine_poly(x::Float64) = sine_cosine_poly(x)[1]

"""
    cosine_poly(x)

The cosine of `x` from the project's own polynomials, with the range and the
non-finite behaviour of `sine_cosine_poly`.
"""
@inline cosine_poly(x::Float64) = sine_cosine_poly(x)[2]

# ln(2) in two parts, the first carrying 33 significant bits so that its
# product with the power-of-two index is exact over the declared range.
# Disposition Derived: ln(2) at 300 bits, split by clearing the low 20 mantissa
# bits of the first part.
const LN2_A = 0.6931471804855391
const LN2_B = 7.440617110012397e-11
const LOG2_E = 1.4426950408889634

"""
    EXPONENTIAL_MAX
    EXPONENTIAL_MIN

The arguments beyond which `exponential` returns `Inf` and `0.0`: the largest
`x` whose exponential is finite in `Float64`, and an `x` below every one whose
exponential rounds to a nonzero subnormal.
"""
const EXPONENTIAL_MAX = 709.782712893384
const EXPONENTIAL_MIN = -746.0

# exp(r) = 1 + r + r^2 * EXP_SERIES(r), coefficients 1/(k+2)!. Disposition
# Derived: the Taylor series of the function at zero, evaluated at 300 bits and
# rounded once, truncated where the next term is below 5e-18 in absolute value
# over abs(r) <= ln(2)/2.
const EXP_SERIES = (0.5, 0.16666666666666666, 0.041666666666666664,
                    0.008333333333333333, 0.001388888888888889,
                    0.0001984126984126984, 2.48015873015873e-5,
                    2.7557319223985893e-6, 2.755731922398589e-7,
                    2.505210838544172e-8, 2.08767569878681e-9,
                    1.6059043836821613e-10)

"""
    exponential_poly(x)

The exponential of `x` from the project's own polynomial: `x` reduced to
`k * ln(2) + r` with `abs(r) <= ln(2)/2`, the series in `r`, and the power of
two applied by `scale_two`. Returns `Inf` above `EXPONENTIAL_MAX`, `0.0` below
`EXPONENTIAL_MIN`, and `x` itself for `NaN`.
"""
@inline function exponential_poly(x::Float64)
    xc = clamp(x, EXPONENTIAL_MIN, EXPONENTIAL_MAX)
    k = round(xc * LOG2_E)
    r = fma(-k, LN2_A, xc)
    r = fma(-k, LN2_B, r)
    y = fma(r * r, horner(r, EXP_SERIES), r)
    v = scale_two(1.0 + y, unsafe_trunc(Int32, k))
    v = ifelse(x > EXPONENTIAL_MAX, Inf, v)
    v = ifelse(x < EXPONENTIAL_MIN, 0.0, v)
    return ifelse(isnan(x), x, v)
end

# R(z) = z * LOG_SERIES(z) with z = s^2 and s = f/(2+f), coefficients
# 2/(2j+3). Disposition Derived: the series of 2*atanh(s) - 2s divided by s,
# evaluated at 300 bits and rounded once, truncated where the next term
# contributes below 2e-19 in absolute value over abs(s) <= sqrt(2) - 1 over
# (sqrt(2) + 1).
const LOG_SERIES = (0.6666666666666666, 0.4, 0.2857142857142857,
                    0.2222222222222222, 0.18181818181818182,
                    0.15384615384615385, 0.13333333333333333,
                    0.11764705882352941, 0.10526315789473684,
                    0.09523809523809523, 0.08695652173913043)

# sqrt(2), the crossover that puts the reduced significand in
# [sqrt(2)/2, sqrt(2)). Disposition Derived: sqrt(2) at 300 bits, rounded once.
const SQRT_TWO = 1.4142135623730951

"""
    logarithm_poly(x)

The natural logarithm of `x` from the project's own polynomial: `x` reduced to
`2^k * m` with `m` in `[sqrt(2)/2, sqrt(2))`, then
`log(1+f) = f - (f^2/2 - s*(f^2/2 + R))` with `f = m - 1` and `s = f/(2+f)`.
Returns `-Inf` at zero, `NaN` below zero, `Inf` at `Inf`, and `x` itself for
`NaN`.
"""
@inline function logarithm_poly(x::Float64)
    xc = ifelse(x > 0.0, x, 1.0)
    e, m = split_exponent(xc)
    halve = m > SQRT_TWO
    mr = ifelse(halve, 0.5 * m, m)
    k = Float64(e + ifelse(halve, Int32(1), Int32(0)))
    f = mr - 1.0
    s = f / (2.0 + f)
    z = s * s
    hf = 0.5 * f
    rr = fma(z, horner(z, LOG_SERIES), hf * f)
    v = fma(k, LN2_A, f - fma(hf, f, -fma(s, rr, k * LN2_B)))
    v = ifelse(x == 0.0, -Inf, v)
    v = ifelse(x < 0.0, NaN, v)
    v = ifelse(x == Inf, Inf, v)
    return ifelse(isnan(x), x, v)
end

# The starting value for the cube root on the reduced significand:
# cbrt(m) for m in [1, 2) as a polynomial in u = 2*(m - 1.5). Disposition
# Derived: the degree-five Chebyshev interpolant of m^(1/3) on [1, 2] at its
# Chebyshev nodes, computed at 300 bits and rounded once; its maximum relative
# error over [1, 2] is 1.78e-6.
const CBRT_START = (1.144712948162971, 0.12719082281226732,
                    -0.01410907367068186, 0.002610790342797188,
                    -0.0006419481713799969, 0.0001585297914149216)

# 2^(1/3) and 2^(2/3), the factors that carry the starting value from the
# reduced significand to the reduced argument. Disposition Derived: the powers
# of two at 300 bits, rounded once.
const CBRT_TWO = 1.2599210498948732
const CBRT_FOUR = 1.5874010519681994

"""
    cube_root_poly(x)

The real cube root of `x` from the project's own polynomial: `x` reduced to
`2^(3q+j) * m` with `m` in `[1, 2)` and `j` in `0:2`, a degree-five starting
value, two Newton steps, and one final step on a residual formed exactly by
`fma`. Returns `x` itself for zero, an infinity and `NaN`.
"""
@inline function cube_root_poly(x::Float64)
    a = abs(x)
    ok = (a > 0.0) & (a < Inf)
    ac = ifelse(ok, a, 1.0)
    e, m = split_exponent(ac)
    q = fld(e, Int32(3))
    j = e - Int32(3) * q
    y = m * two_power(j)
    t = horner(fma(2.0, m, -3.0), CBRT_START)
    t = t * ifelse(j == Int32(0), 1.0, ifelse(j == Int32(1), CBRT_TWO, CBRT_FOUR))
    t = (2.0 * t + y / (t * t)) / 3.0
    t = (2.0 * t + y / (t * t)) / 3.0
    p = t * t
    ep = fma(t, t, -p)
    c = nofuse_mul(p, t)
    ec = fma(p, t, -c)
    res = (c - y) + fma(ep, t, ec)
    t = fma(-t, res / (3.0 * y), t)
    v = copysign(scale_two(t, q), x)
    return ifelse(ok, v, x)
end

"""
    sine(x, backend)
    cosine(x, backend)
    sine_cosine(x, backend)
    cube_root(x, backend)
    exponential(x, backend)
    logarithm(x, backend)

The trigonometric functions, the real cube root, the exponential and the
natural logarithm of `x`, from the project's own polynomials when `backend`
runs in bitwise mode (decision 0029) and from the platform library otherwise.
`Float64` only: `Float32` coefficient sets are fiddlybits-52v.7.13, and a
`Float32` argument is a `MethodError` at the call site rather than a widening
here.
"""
@inline sine(x::Float64, b::Backend) = bitwise(b) ? sine_poly(x) : sin(x)
@inline cosine(x::Float64, b::Backend) = bitwise(b) ? cosine_poly(x) : cos(x)
@inline sine_cosine(x::Float64, b::Backend) = bitwise(b) ? sine_cosine_poly(x) : sincos(x)
@inline cube_root(x::Float64, b::Backend) = bitwise(b) ? cube_root_poly(x) : cbrt(x)
@inline exponential(x::Float64, b::Backend) = bitwise(b) ? exponential_poly(x) : exp(x)
@inline logarithm(x::Float64, b::Backend) = bitwise(b) ? logarithm_poly(x) : log(x)
