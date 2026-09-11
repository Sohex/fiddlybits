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

# The Kepler solve of src/Orbit/kepler.jl with every multiply that feeds an add
# routed through the bitwise-mode barrier and every transcendental through
# Backends, so that the arithmetic and the transcendentals can be switched
# separately. The mean anomaly arrives in [-pi, pi], so rem2pi is not reached.
@inline barrier_mul(a, b, backend) =
    Backends.bitwise(backend) ? Backends.nofuse_mul(a, b) : a * b

@inline function kepler_e_minus_sin(E, trans)
    if abs(E) < 0.5
        E2 = E * E
        return E * E2 * @evalpoly(E2, 1 / 6, -1 / 120, 1 / 5040, -1 / 362880,
                                  1 / 39916800, -1 / 6227020800, 1 / 1307674368000)
    else
        return E - Backends.sine(E, trans)
    end
end

@inline kepler_residual(E, e, M, arith, trans) =
    barrier_mul(1.0 - e, E, arith) + barrier_mul(e, kepler_e_minus_sin(E, trans), arith) - M

@inline kepler_derivative(E, e, arith, trans) =
    (1.0 - e) + barrier_mul(2 * e, abs2(Backends.sine(E / 2, trans)), arith)

@inline function markley_start(M, e, arith, trans)
    pi2 = abs2(pi)
    alpha = (barrier_mul(3.0, pi2, arith) +
             8 * (pi2 - barrier_mul(pi, abs(M), arith)) / (5 * (1 + e))) / (pi2 - 6)
    d = barrier_mul(3.0, 1 - e, arith) + barrier_mul(alpha, e, arith)
    q = barrier_mul(2 * alpha * d, 1 - e, arith) - barrier_mul(M, M, arith)
    r = barrier_mul(3 * alpha * d * (d - 1 + e), M, arith) + barrier_mul(M * M, M, arith)
    w = Backends.cube_root(abs2(abs(r) + sqrt(barrier_mul(q * q, q, arith) +
                                              barrier_mul(r, r, arith))), trans)
    E1 = (2 * r * w / @evalpoly(w, q * q, q, 1.0) + M) / d
    s, c = Backends.sine_cosine(E1, trans)
    f2 = barrier_mul(e, s, arith)
    f3 = barrier_mul(e, c, arith)
    f0 = E1 - f2 - M
    f1 = 1.0 - f3
    d3 = -f0 / (f1 - f0 * f2 / (2 * f1))
    d4 = -f0 / @evalpoly(d3, f1, f2 / 2, f3 / 6)
    d5 = -f0 / @evalpoly(d4, f1, f2 / 2, f3 / 6, -f2 / 24)
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
