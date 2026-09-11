using Test
using CUDA
using KernelAbstractions: @kernel, @index, @Const
using Fiddlybits: Backends

# The project's own polynomial transcendentals (decision 0029's bitwise mode).
# The declared grids below are this row's sample: the bitwise claim and the
# accuracy bound are both stated over them. The measurements, the argument for
# the bounds and the cost of the fusion barrier are in
# notes/findings/2026-09-11-polynomial-transcendentals-for-bitwise-mode.md.

module TranscendentalGrids

"`n` points evenly spaced from `lo` to `hi` inclusive."
uniform(lo, hi, n) = [lo + (hi - lo) * (i - 1) / (n - 1) for i in 1:n]

"`n` points in geometric progression from `lo` to `hi` inclusive."
geometric(lo, hi, n) = [lo * (hi / lo)^((i - 1) / (n - 1)) for i in 1:n]

"`v` followed by its negation."
signed(v) = vcat(v, -v)

# The declared argument grids, one per function, fixed formulas rather than
# draws. TRIG spans the whole reduced argument range at every quadrant index
# the reduction admits; EXP spans the whole finite range of the exponential;
# LOG and CBRT span the whole binade range including the subnormals.
const TRIG = vcat(signed(geometric(2.0^-40, 2.0^18, 2048)), uniform(-4pi, 4pi, 2048))
const EXP = vcat(uniform(-745.0, 709.0, 2048), signed(geometric(2.0^-40, 1.0, 1024)))
const LOG = vcat(geometric(2.0^-1070, 2.0^1020, 2048), uniform(0.5, 2.0, 2048))
const CBRT = vcat(signed(geometric(2.0^-1070, 2.0^1020, 1024)), signed(uniform(1.0, 8.0, 1024)))

# The reduced range of each function: the interval the polynomial itself is
# evaluated over once the argument reduction has run.
const REDUCED_TRIG = uniform(-pi / 4, pi / 4, 2001)
const REDUCED_EXP = uniform(-log(2) / 2, log(2) / 2, 2001)
const REDUCED_LOG = uniform(sqrt(2) / 2, sqrt(2), 2001)
const REDUCED_CBRT = uniform(1.0, 8.0, 2001)

# The Float32 grids. The same shape as the Float64 ones at the Float32 range,
# with one more: NEAR_HALF_PI32 is the Float32 nearest each multiple of pi/2 in
# range, which is the hardest argument the reduction meets, and the point at
# which a reduction that carried too few bits shows it.
const HALF_PI_300 = setprecision(() -> big(pi) / 2, BigFloat, 300)

const TRIG32 = Float32.(vcat(signed(geometric(2.0^-40, 2.0^12, 1024)),
                             uniform(-4pi, 4pi, 1024)))
const NEAR_HALF_PI32 = setprecision(BigFloat, 300) do
    v = Float32[Float32(n * HALF_PI_300) for n in 1:2607]
    signed(filter(x -> x <= 4096.0f0, v))
end
const EXP32 = Float32.(vcat(uniform(-104.0, 88.0, 1024),
                            signed(geometric(2.0^-40, 1.0, 512))))
const LOG32 = Float32.(vcat(geometric(2.0^-149, 2.0^127, 1024), uniform(0.5, 2.0, 1024)))
const CBRT32 = Float32.(vcat(signed(geometric(2.0^-149, 2.0^127, 512)),
                             signed(uniform(1.0, 8.0, 512))))

const REDUCED_TRIG32 = Float32.(uniform(-pi / 4, pi / 4, 2001))
const REDUCED_EXP32 = Float32.(uniform(-log(2) / 2, log(2) / 2, 2001))
const REDUCED_LOG32 = Float32.(uniform(sqrt(2) / 2, sqrt(2), 2001))
const REDUCED_CBRT32 = Float32.(uniform(1.0, 8.0, 2001))

"Every quadrant index the declared range admits."
const QUADRANT_INDICES = Float32[n for n in 0:2607]

# The mean anomalies and eccentricities the Kepler control runs over.
const KEPLER_M = uniform(-pi, pi, 4096)
const KEPLER_E = (0.5, 0.99, 1 - 1e-12)

end # module TranscendentalGrids

const TG = TranscendentalGrids

"The bar every function's maximum error must stay under, in ulps of the
returned value, over its reduced range and over its declared grid."
const ULP_BAR = 1.0

"`abs(computed - exact)` in ulps of `exact`, with the subnormal spacing as the
floor so a subnormal result is measured in its own spacing."
function ulp_error(computed::Float64, exact::BigFloat)
    ex = Float64(exact)
    (isnan(computed) || isinf(computed) || ex == 0.0) && return 0.0
    u = max(big(2.0)^(exponent(ex) - 52), big(2.0)^-1074)
    return Float64(abs(big(computed) - exact) / u)
end

"The largest `ulp_error` of `f` against `reference` over `xs`, and where."
function worst_ulps(f, reference, xs)
    m, at = 0.0, first(xs)
    for x in xs
        e = ulp_error(f(x), reference(big(x)))
        if e > m
            m, at = e, x
        end
    end
    return m, at
end

@kernel function transcendental_kernel!(out, @Const(xs), f, backend)
    i = @index(Global)
    out[i] = f(xs[i], backend)
end

"`f` applied to every element of `xs` through one kernel launch on `backend`,
returned on the host."
function on_backend(f, xs, backend)
    x = Backends.on(copy(xs), backend)
    out = Backends.on(similar(xs), backend)
    Backends.launch!(transcendental_kernel!, backend, length(xs), out, x, f, backend)
    return Array(out)
end

"Whether `a` and `b` agree bit for bit, counting two `NaN`s as agreeing."
bit_identical(a, b) = all(((x, y),) -> (isnan(x) && isnan(y)) || x === y, zip(a, b))

# exponential_poly before fiddlybits-52v.7.38's sanitiser: clamp fed x
# directly, so a NaN x reached unsafe_trunc as clamp(NaN, ...) is NaN. Kept
# here, never called on a NaN, to assert the sanitiser moves no returned
# value at a finite or infinite argument.
@inline function exponential_poly_unsanitised(x::Float64)
    xc = clamp(x, Backends.EXPONENTIAL_MIN, Backends.EXPONENTIAL_MAX)
    k = round(xc * Backends.LOG2_E)
    r = fma(-k, Backends.LN2_A, xc)
    r = fma(-k, Backends.LN2_B, r)
    y = fma(r * r, Backends.horner(r, Backends.EXP_SERIES), r)
    v = Backends.scale_two(1.0 + y, unsafe_trunc(Int32, k))
    v = ifelse(x > Backends.EXPONENTIAL_MAX, Inf, v)
    v = ifelse(x < Backends.EXPONENTIAL_MIN, 0.0, v)
    return v
end

@inline function exponential_poly_unsanitised(x::Float32)
    xc = clamp(x, Backends.EXPONENTIAL_MIN_F32, Backends.EXPONENTIAL_MAX_F32)
    k = round(xc * Backends.LOG2_E_F32)
    r = fma(-k, Backends.LN2_A_F32, xc)
    r = fma(-k, Backends.LN2_B_F32, r)
    y = fma(r * r, Backends.horner(r, Backends.EXP_SERIES_F32), r)
    v = Backends.scale_two(1.0f0 + y, unsafe_trunc(Int32, k))
    v = ifelse(x > Backends.EXPONENTIAL_MAX_F32, Inf32, v)
    v = ifelse(x < Backends.EXPONENTIAL_MIN_F32, 0.0f0, v)
    return v
end

# The Kepler solve of src/Orbit/kepler.jl with every multiply that feeds an
# add taking arith through fma_add and every transcendental through trans,
# so that the arithmetic and the transcendentals can be switched separately.
# fma_add is fma in bitwise mode and muladd otherwise (decision 0044).
# barrier_mul routes a product read by more than one later expression
# through the bitwise-mode barrier. The mean anomaly arrives in [-pi, pi],
# so rem2pi is not reached.
@inline fma_add(a, b, c, arith) =
    Backends.bitwise(arith) ? fma(a, b, c) : muladd(a, b, c)

@inline barrier_mul(a, b, backend) =
    Backends.bitwise(backend) ? Backends.nofuse_mul(a, b) : a * b

@inline kepler_poly(z, c::Tuple{Any}, arith) = c[1]
@inline kepler_poly(z, c::Tuple{Any,Any,Vararg{Any}}, arith) =
    fma_add(kepler_poly(z, Base.tail(c), arith), z, c[1], arith)

@inline function kepler_e_minus_sin(E, arith, trans)
    if abs(E) < 0.5
        E2 = E * E
        return E * E2 * kepler_poly(E2, (1 / 6, -1 / 120, 1 / 5040, -1 / 362880,
                                    1 / 39916800, -1 / 6227020800, 1 / 1307674368000), arith)
    else
        return E - Backends.sine(E, trans)
    end
end

@inline kepler_residual(E, e, M, arith, trans) =
    fma_add(1.0 - e, E, e * kepler_e_minus_sin(E, arith, trans), arith) - M

@inline kepler_derivative(E, e, arith, trans) =
    fma_add(2 * e, abs2(Backends.sine(E / 2, trans)), 1.0 - e, arith)

@inline function markley_start(M, e, arith, trans)
    pi2 = abs2(pi)
    alpha = fma_add(3.0, pi2,
             8 * fma_add(-pi, abs(M), pi2, arith) / (5 * (1 + e)), arith) / (pi2 - 6)
    d = fma_add(3.0, 1 - e, alpha * e, arith)
    q = fma_add(2 * alpha * d, 1 - e, -(M * M), arith)
    r = fma_add(3 * alpha * d * (d - 1 + e), M, M * M * M, arith)
    w = Backends.cube_root(abs2(abs(r) + sqrt(fma_add(q * q, q, r * r, arith))), trans)
    E1 = (2 * r * w / kepler_poly(w, (q * q, q, 1.0), arith) + M) / d
    s, c = Backends.sine_cosine(E1, trans)
    f2 = barrier_mul(e, s, arith)
    f3 = barrier_mul(e, c, arith)
    f0 = E1 - f2 - M
    f1 = 1.0 - f3
    d3 = -f0 / (f1 - f0 * f2 / (2 * f1))
    d4 = -f0 / kepler_poly(d3, (f1, f2 / 2, f3 / 6), arith)
    d5 = -f0 / kepler_poly(d4, (f1, f2 / 2, f3 / 6, -f2 / 24), arith)
    return E1 + d5
end

@inline function eccentric_anomaly(M, e, arith, trans)
    iszero(M) && return zero(M)
    E = markley_start(M, e, arith, trans)
    E -= kepler_residual(E, e, M, arith, trans) / kepler_derivative(E, e, arith, trans)
    E -= kepler_residual(E, e, M, arith, trans) / kepler_derivative(E, e, arith, trans)
    return E
end

@kernel function kepler_kernel!(out, @Const(Ms), e, arith, trans)
    i = @index(Global)
    out[i] = eccentric_anomaly(Ms[i], e, arith, trans)
end

"The eccentric anomaly for every mean anomaly in `Ms`, on `backend`, with
`arith` selecting the arithmetic and `trans` the transcendentals."
function kepler_on(Ms, e, backend, arith, trans)
    x = Backends.on(copy(Ms), backend)
    out = Backends.on(similar(Ms), backend)
    Backends.launch!(kepler_kernel!, backend, length(Ms), out, x, e, arith, trans)
    return Array(out)
end

@testset "polynomial transcendentals (decision 0029)" begin
    setprecision(BigFloat, 300)

    @testset "fma is the single-rounding operation the polynomials are built on" begin
        # Every multiply that feeds an add in src/Backends/transcendentals.jl is
        # an explicit fma or goes through Backends.nofuse_mul; the accuracy bound
        # and the cross-backend identity both rest on fma being correctly
        # rounded, which IEEE 754 requires of fusedMultiplyAdd.
        exact = true
        differs = false
        for i in 1:2000
            a = 1.0 + i / 2000.0
            b = 1.0 + mod(i * 7, 2000) / 2000.0
            c = -(a * b)
            exact &= fma(a, b, c) == Float64(big(a) * big(b) + big(c))
            differs |= fma(a, b, c) != a * b + c
        end
        @test exact
        @testset "positive control: fma is not a*b+c on this set" begin
            @test differs
        end
    end

    @testset "accuracy against a 300-bit reference" begin
        for (name, own, reference, reduced, grid) in (
                ("sine", Backends.sine_poly, sin, TG.REDUCED_TRIG, TG.TRIG),
                ("cosine", Backends.cosine_poly, cos, TG.REDUCED_TRIG, TG.TRIG),
                ("exponential", Backends.exponential_poly, exp, TG.REDUCED_EXP, TG.EXP),
                ("logarithm", Backends.logarithm_poly, log, TG.REDUCED_LOG, TG.LOG),
                ("cube_root", Backends.cube_root_poly, cbrt, TG.REDUCED_CBRT, TG.CBRT))
            @testset "$name" begin
                reduced_ulps, _ = worst_ulps(own, reference, reduced)
                grid_ulps, _ = worst_ulps(own, reference, grid)
                @test reduced_ulps <= ULP_BAR
                @test grid_ulps <= ULP_BAR
            end
        end

        @testset "positive control: a series three terms short fails the bar" begin
            short(x) = begin
                z = x * x
                fma(x * z, Backends.horner(z, Backends.SIN_SERIES[1:5]), x)
            end
            short_ulps, _ = worst_ulps(short, sin, TG.REDUCED_TRIG)
            @test short_ulps > ULP_BAR
        end
    end

    @testset "sine_cosine returns what sine and cosine return" begin
        @test all(TG.TRIG) do x
            s, c = Backends.sine_cosine_poly(x)
            s === Backends.sine_poly(x) && c === Backends.cosine_poly(x)
        end
    end

    @testset "the declared refusals fire" begin
        over = nextfloat(Backends.TRIG_ARGUMENT_LIMIT)
        @test isnan(Backends.sine_poly(over))
        @test isnan(Backends.cosine_poly(-over))
        @test isnan(Backends.sine_poly(Inf))
        @test isnan(Backends.sine_poly(NaN))
        @test Backends.sine_poly(0.0) === 0.0
        @test Backends.sine_poly(-0.0) === -0.0
        @test Backends.cosine_poly(0.0) === 1.0
        @test Backends.exponential_poly(0.0) === 1.0
        @test Backends.exponential_poly(800.0) === Inf
        @test Backends.exponential_poly(-800.0) === 0.0
        @test Backends.exponential_poly(Inf) === Inf
        @test Backends.exponential_poly(-Inf) === 0.0
        @test isnan(Backends.exponential_poly(NaN))
        @test Backends.logarithm_poly(1.0) === 0.0
        @test Backends.logarithm_poly(0.0) === -Inf
        @test isnan(Backends.logarithm_poly(-1.0))
        @test Backends.logarithm_poly(Inf) === Inf
        @test Backends.cube_root_poly(0.0) === 0.0
        @test Backends.cube_root_poly(-0.0) === -0.0
        @test Backends.cube_root_poly(8.0) === 2.0
        @test Backends.cube_root_poly(-8.0) === -2.0
        @test Backends.cube_root_poly(-Inf) === -Inf
        @test isnan(Backends.cube_root_poly(NaN))
    end

    @testset "exponential_poly's NaN sanitiser (fiddlybits-52v.7.38)" begin
        @testset "the danger the sanitiser removes" begin
            # clamp itself still returns NaN for a NaN argument; the
            # sanitiser is what keeps that NaN from reaching unsafe_trunc.
            @test isnan(clamp(NaN, Backends.EXPONENTIAL_MIN, Backends.EXPONENTIAL_MAX))
        end
        @testset "the integer argument reaching unsafe_trunc is never NaN" begin
            for x in (NaN, Inf, -Inf, 0.0, Backends.EXPONENTIAL_MIN, Backends.EXPONENTIAL_MAX)
                xs = ifelse(isnan(x), 0.0, x)
                xc = clamp(xs, Backends.EXPONENTIAL_MIN, Backends.EXPONENTIAL_MAX)
                @test !isnan(round(xc * Backends.LOG2_E))
            end
        end
        @testset "every returned value over the declared grid is unchanged" begin
            @test all(x -> Backends.exponential_poly(x) === exponential_poly_unsanitised(x),
                      vcat(TG.REDUCED_EXP, TG.EXP))
        end
        @testset "the clamp boundaries and their neighbours are unchanged" begin
            boundary = (Backends.EXPONENTIAL_MIN, prevfloat(Backends.EXPONENTIAL_MIN),
                        nextfloat(Backends.EXPONENTIAL_MIN), Backends.EXPONENTIAL_MAX,
                        prevfloat(Backends.EXPONENTIAL_MAX), nextfloat(Backends.EXPONENTIAL_MAX))
            @test all(x -> Backends.exponential_poly(x) === exponential_poly_unsanitised(x),
                      boundary)
        end
    end

    @testset "bitwise between the processor and the CUDA backend" begin
        @test CUDA.functional()
        cases = (("sine", Backends.sine, TG.TRIG), ("cosine", Backends.cosine, TG.TRIG),
                 ("cube_root", Backends.cube_root, TG.CBRT),
                 ("exponential", Backends.exponential, TG.EXP),
                 ("logarithm", Backends.logarithm, TG.LOG))
        for (name, f, grid) in cases
            @testset "$name" begin
                cpu = on_backend(f, grid, Backends.CPU(64; bitwise = true))
                gpu = on_backend(f, grid, Backends.GPU(64; bitwise = true))
                @test bit_identical(cpu, gpu)
            end
        end

        @testset "positive control: fast mode is not bitwise" begin
            for (name, f, grid) in cases
                @testset "$name" begin
                    cpu = on_backend(f, grid, Backends.CPU(64))
                    gpu = on_backend(f, grid, Backends.GPU(64))
                    @test !bit_identical(cpu, gpu)
                end
            end
        end
    end

    @testset "the Kepler solve in bitwise mode" begin
        arith_on = Backends.CPU(1; bitwise = true)
        arith_off = Backends.CPU(1; bitwise = false)
        ulp_pi = eps(Float64(pi))
        for e in TG.KEPLER_E
            @testset "eccentricity $e" begin
                cpu = kepler_on(TG.KEPLER_M, e, Backends.CPU(64; bitwise = true), arith_on, arith_on)
                gpu = kepler_on(TG.KEPLER_M, e, Backends.GPU(64; bitwise = true), arith_on, arith_on)
                @test cpu == gpu

                @testset "positive control: fast mode is not bitwise" begin
                    fast_cpu = kepler_on(TG.KEPLER_M, e, Backends.CPU(64), arith_off, arith_off)
                    fast_gpu = kepler_on(TG.KEPLER_M, e, Backends.GPU(64), arith_off, arith_off)
                    @test fast_cpu != fast_gpu
                    @test maximum(abs.(fast_cpu .- fast_gpu)) / ulp_pi <= 1.5
                end

                @testset "positive control: the library alone breaks it" begin
                    # Bitwise arithmetic throughout, the library transcendentals
                    # only, which is what this row replaced.
                    mixed_cpu = kepler_on(TG.KEPLER_M, e, Backends.CPU(64; bitwise = true),
                                          arith_on, arith_off)
                    mixed_gpu = kepler_on(TG.KEPLER_M, e, Backends.GPU(64; bitwise = true),
                                          arith_on, arith_off)
                    @test mixed_cpu != mixed_gpu
                end
            end
        end
    end
end

"The bar every Float32 function's maximum error must stay under, in ulps of
the returned value, over its reduced range and over its declared grid."
const ULP_BAR_F32 = 1.0

"`abs(computed - exact)` in ulps of `exact` at `Float32`, with the subnormal
spacing as the floor."
function ulp_error(computed::Float32, exact::BigFloat)
    ex = Float32(exact)
    (isnan(computed) || isinf(computed) || ex == 0.0f0) && return 0.0
    u = max(big(2.0)^(exponent(ex) - 23), big(2.0)^-149)
    return Float64(abs(big(computed) - exact) / u)
end

"`prod(big(1):big(n))`, for the factorials the Float64 series are read from."
bfactorial(n) = prod(big(1):big(max(n, 1)))

"`v` rounded to `Float64` with the low `drop` mantissa bits cleared."
clear_low(v::BigFloat, drop::Int) =
    reinterpret(Float64, reinterpret(UInt64, Float64(v)) & ~UInt64((1 << drop) - 1))

"The degree `n-1` interpolant of `m^(1/3)` at the `n` Chebyshev nodes of
`u = 2*(m - 1.5)` on `[-1, 1]`, in the monomial basis, rounded once."
function chebyshev_cube_root(n::Int)
    u = [cos(big(pi) * (2i - 1) / (2n)) for i in 1:n]
    V = [u[i]^(j - 1) for i in 1:n, j in 1:n]
    y = [(big(3) / 2 + ui / 2)^(big(1) / 3) for ui in u]
    c = V \ y
    return ntuple(j -> Float64(c[j]), n)
end

"Whether `n * p` is exactly representable at `Float32`."
exact_product(p::Float32, n::Float32) =
    (v = Float64(p) * Float64(n); Float64(Float32(v)) == v)

"Whether the first subtraction of the reduction is exact at `x`."
function first_step_exact(x::Float32, a::Float32)
    n = round(x * Backends.TWO_OVER_PI_F32)
    return Float64(fma(-n, a, x)) == fma(-Float64(n), Float64(a), Float64(x))
end

"""
    reduced_argument_error(x, parts)

The relative error of the reduced argument `quadrant_reduce`'s assembly
produces at `x` from `parts`, against `x - n * pi/2` at 300 bits. `parts` is
read as the leading part, the two the assembly subtracts with their rounding
errors carried, and the one folded into the low word; a `parts` one shorter
drops the last.
"""
function reduced_argument_error(x::Float32, parts)
    n = round(x * Backends.TWO_OVER_PI_F32)
    r0 = fma(-n, parts[1], x)
    r1, e1 = Backends.two_sum(r0, -(n * parts[2]))
    r, e2 = Backends.two_sum(r1, -(n * parts[3]))
    rlo = length(parts) > 3 ? fma(-n, parts[4], e1 + e2) : e1 + e2
    exact = big(x) - big(n) * (big(pi) / 2)
    exact == 0 && return 0.0
    return Float64(abs((big(r) + big(rlo)) - exact) / abs(exact))
end

@testset "polynomial transcendentals at Float32 (fiddlybits-52v.7.13)" begin
    setprecision(BigFloat, 300)

    @testset "the Float64 set is what its derivation gives, bit for bit" begin
        hp = big(pi) / 2
        a = clear_low(hp, 20)
        b = clear_low(hp - a, 20)
        @test (a, b, Float64(hp - a - b)) ===
              (Backends.PIO2_A, Backends.PIO2_B, Backends.PIO2_C)
        l2 = log(big(2))
        la = clear_low(l2, 20)
        @test (la, Float64(l2 - la)) === (Backends.LN2_A, Backends.LN2_B)
        @test Float64(2 / big(pi)) === Backends.TWO_OVER_PI
        @test Float64(1 / l2) === Backends.LOG2_E
        @test Float64(sqrt(big(2))) === Backends.SQRT_TWO
        @test Float64(big(2)^(big(1) / 3)) === Backends.CBRT_TWO
        @test Float64(big(4)^(big(1) / 3)) === Backends.CBRT_FOUR
        @test ntuple(k -> Float64((-1)^k / bfactorial(2k + 1)), 8) === Backends.SIN_SERIES
        @test ntuple(k -> Float64((-1)^(k + 1) / bfactorial(2k + 2)), 8) === Backends.COS_SERIES
        @test ntuple(k -> Float64(1 / bfactorial(k + 1)), 12) === Backends.EXP_SERIES
        @test ntuple(j -> Float64(2 / big(2j + 1)), 11) === Backends.LOG_SERIES
        @test chebyshev_cube_root(6) === Backends.CBRT_START

        @testset "positive control: a coefficient one ulp away is refused" begin
            moved = Base.setindex(Backends.SIN_SERIES, nextfloat(Backends.SIN_SERIES[1]), 1)
            @test ntuple(k -> Float64((-1)^k / bfactorial(2k + 1)), 8) !== moved
        end
    end

    @testset "the Float32 sets are fits of their own, not the Float64 sets rounded" begin
        for (own, wide) in ((Backends.SIN_SERIES_F32, Backends.SIN_SERIES),
                            (Backends.COS_SERIES_F32, Backends.COS_SERIES),
                            (Backends.EXP_SERIES_F32, Backends.EXP_SERIES),
                            (Backends.LOG_SERIES_F32, Backends.LOG_SERIES),
                            (Backends.CBRT_START_F32, Backends.CBRT_START))
            @test length(own) < length(wide)
            @test own !== map(Float32, wide[1:length(own)])
        end
        @test Backends.PIO2_A_F32 !== Float32(Backends.PIO2_A)
        @test Backends.LN2_A_F32 !== Float32(Backends.LN2_A)
        @test Backends.TRIG_ARGUMENT_LIMIT_F32 !== Float32(Backends.TRIG_ARGUMENT_LIMIT)
    end

    @testset "the four-part split multiplies exactly over the declared range" begin
        @test all(n -> exact_product(Backends.PIO2_A_F32, n), TG.QUADRANT_INDICES)
        @test all(n -> exact_product(Backends.PIO2_B_F32, n), TG.QUADRANT_INDICES)
        @test all(n -> exact_product(Backends.PIO2_C_F32, n), TG.QUADRANT_INDICES)
        @test all(x -> first_step_exact(x, Backends.PIO2_A_F32),
                  vcat(TG.TRIG32, TG.NEAR_HALF_PI32))

        four = (Backends.PIO2_A_F32, Backends.PIO2_B_F32,
                Backends.PIO2_C_F32, Backends.PIO2_D_F32)
        @test maximum(x -> reduced_argument_error(x, four), TG.NEAR_HALF_PI32) <= 1.0e-9

        @testset "positive control: the Float64 leading part carries too many bits" begin
            wide = Float32(Backends.PIO2_A)
            @test !all(n -> exact_product(wide, n), TG.QUADRANT_INDICES)
        end

        @testset "positive control: a shorter split loses the reduced argument" begin
            rounded = map(Float32, (Backends.PIO2_A, Backends.PIO2_B, Backends.PIO2_C))
            @test maximum(x -> reduced_argument_error(x, four[1:3]), TG.NEAR_HALF_PI32) >
                  eps(Float32)
            @test maximum(x -> reduced_argument_error(x, rounded), TG.NEAR_HALF_PI32) >
                  eps(Float32)
        end
    end

    @testset "accuracy against a 300-bit reference" begin
        for (name, own, reference, reduced, grid) in (
                ("sine", Backends.sine_poly, sin, TG.REDUCED_TRIG32,
                 vcat(TG.TRIG32, TG.NEAR_HALF_PI32)),
                ("cosine", Backends.cosine_poly, cos, TG.REDUCED_TRIG32,
                 vcat(TG.TRIG32, TG.NEAR_HALF_PI32)),
                ("exponential", Backends.exponential_poly, exp, TG.REDUCED_EXP32, TG.EXP32),
                ("logarithm", Backends.logarithm_poly, log, TG.REDUCED_LOG32, TG.LOG32),
                ("cube_root", Backends.cube_root_poly, cbrt, TG.REDUCED_CBRT32, TG.CBRT32))
            @testset "$name" begin
                reduced_ulps, _ = worst_ulps(own, reference, reduced)
                grid_ulps, _ = worst_ulps(own, reference, grid)
                @test reduced_ulps <= ULP_BAR_F32
                @test grid_ulps <= ULP_BAR_F32
            end
        end

        @testset "positive control: the series one coefficient short fails the bar" begin
            short(x::Float32) = begin
                z = x * x
                fma(x * z, Backends.horner(z, Backends.SIN_SERIES_F32[1:3]), x)
            end
            short_ulps, _ = worst_ulps(short, sin, TG.REDUCED_TRIG32)
            @test short_ulps > ULP_BAR_F32
        end
    end

    @testset "sine_cosine returns what sine and cosine return" begin
        @test all(vcat(TG.TRIG32, TG.NEAR_HALF_PI32)) do x
            s, c = Backends.sine_cosine_poly(x)
            s === Backends.sine_poly(x) && c === Backends.cosine_poly(x)
        end
    end

    @testset "the declared refusals fire" begin
        over = nextfloat(Backends.TRIG_ARGUMENT_LIMIT_F32)
        @test isnan(Backends.sine_poly(over))
        @test isnan(Backends.cosine_poly(-over))
        @test isnan(Backends.sine_poly(Inf32))
        @test isnan(Backends.sine_poly(NaN32))
        @test Backends.sine_poly(0.0f0) === 0.0f0
        @test Backends.sine_poly(-0.0f0) === -0.0f0
        @test Backends.cosine_poly(0.0f0) === 1.0f0
        @test Backends.exponential_poly(0.0f0) === 1.0f0
        @test Backends.exponential_poly(Backends.EXPONENTIAL_MAX_F32) === 3.4027985f38
        @test Backends.exponential_poly(nextfloat(Backends.EXPONENTIAL_MAX_F32)) === Inf32
        @test Backends.exponential_poly(Backends.EXPONENTIAL_MIN_F32) === 0.0f0
        @test Backends.exponential_poly(Inf32) === Inf32
        @test Backends.exponential_poly(-Inf32) === 0.0f0
        @test isnan(Backends.exponential_poly(NaN32))
        @test Backends.logarithm_poly(1.0f0) === 0.0f0
        @test Backends.logarithm_poly(0.0f0) === -Inf32
        @test isnan(Backends.logarithm_poly(-1.0f0))
        @test Backends.logarithm_poly(Inf32) === Inf32
        @test Backends.cube_root_poly(0.0f0) === 0.0f0
        @test Backends.cube_root_poly(-0.0f0) === -0.0f0
        @test Backends.cube_root_poly(8.0f0) === 2.0f0
        @test Backends.cube_root_poly(-8.0f0) === -2.0f0
        @test Backends.cube_root_poly(-Inf32) === -Inf32
        @test isnan(Backends.cube_root_poly(NaN32))
        # every Float32 method returns a Float32, so no call widens
        @test all(f -> f(1.0f0) isa Float32,
                  (Backends.sine_poly, Backends.cosine_poly, Backends.exponential_poly,
                   Backends.logarithm_poly, Backends.cube_root_poly))
        @test Backends.sine_cosine_poly(1.0f0) isa Tuple{Float32,Float32}
    end

    @testset "exponential_poly's NaN sanitiser (fiddlybits-52v.7.38)" begin
        @testset "the danger the sanitiser removes" begin
            @test isnan(clamp(NaN32, Backends.EXPONENTIAL_MIN_F32, Backends.EXPONENTIAL_MAX_F32))
        end
        @testset "the integer argument reaching unsafe_trunc is never NaN" begin
            for x in (NaN32, Inf32, -Inf32, 0.0f0,
                      Backends.EXPONENTIAL_MIN_F32, Backends.EXPONENTIAL_MAX_F32)
                xs = ifelse(isnan(x), 0.0f0, x)
                xc = clamp(xs, Backends.EXPONENTIAL_MIN_F32, Backends.EXPONENTIAL_MAX_F32)
                @test !isnan(round(xc * Backends.LOG2_E_F32))
            end
        end
        @testset "every returned value over the declared grid is unchanged" begin
            @test all(x -> Backends.exponential_poly(x) === exponential_poly_unsanitised(x),
                      vcat(TG.REDUCED_EXP32, TG.EXP32))
        end
        @testset "the clamp boundaries and their neighbours are unchanged" begin
            boundary = (Backends.EXPONENTIAL_MIN_F32, prevfloat(Backends.EXPONENTIAL_MIN_F32),
                        nextfloat(Backends.EXPONENTIAL_MIN_F32), Backends.EXPONENTIAL_MAX_F32,
                        prevfloat(Backends.EXPONENTIAL_MAX_F32),
                        nextfloat(Backends.EXPONENTIAL_MAX_F32))
            @test all(x -> Backends.exponential_poly(x) === exponential_poly_unsanitised(x),
                      boundary)
        end
    end

    @testset "bitwise between the processor and the CUDA backend" begin
        @test CUDA.functional()
        cases = (("sine", Backends.sine, vcat(TG.TRIG32, TG.NEAR_HALF_PI32)),
                 ("cosine", Backends.cosine, vcat(TG.TRIG32, TG.NEAR_HALF_PI32)),
                 ("cube_root", Backends.cube_root, TG.CBRT32),
                 ("exponential", Backends.exponential, TG.EXP32),
                 ("logarithm", Backends.logarithm, TG.LOG32))
        for (name, f, grid) in cases
            @testset "$name" begin
                cpu = on_backend(f, grid, Backends.CPU(64; bitwise = true))
                gpu = on_backend(f, grid, Backends.GPU(64; bitwise = true))
                @test bit_identical(cpu, gpu)
            end
        end

        @testset "positive control: fast mode is not bitwise" begin
            for (name, f, grid) in cases
                @testset "$name" begin
                    cpu = on_backend(f, grid, Backends.CPU(64))
                    gpu = on_backend(f, grid, Backends.GPU(64))
                    @test !bit_identical(cpu, gpu)
                end
            end
        end
    end
end
