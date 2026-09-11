using Test
using KernelAbstractions
using CUDA
using Fiddlybits: Orbit

# system.kepler_period, the eccentric-anomaly arm. The period arm reads the orbit
# hierarchy of System and is run by fiddlybits-52v.5.3.
#
# The sample is chosen in E and the mean anomaly derived from it, not the other way
# round. At high eccentricity the region the defect lives in, e above 0.75 and E
# below 45 degrees, occupies a vanishing fraction of the mean-anomaly axis, so a
# sample uniform in M does not reach it and the positive control does not fire
# (notes/findings/2026-09-10-sampling-the-kepler-hard-region.md).

setprecision(BigFloat, 300)

const ULP = eps(Float64(pi))
const BAR = 2          # the verdict bar of system.kepler_period, in ulps of pi
const ECCENTRICITIES = (0.9, 0.99, 0.999, 1 - 1e-6, 1 - 1e-9, 1 - 1e-12)

"Mean anomalies derived from eccentric anomalies spaced logarithmically below 45 degrees."
function hard_region(e, n)
    eb = BigFloat(e)
    lo, hi = BigFloat(-8), log10(BigFloat(pi) / 4)
    return [(Float64(Eb - eb * sin(Eb)), Eb) for Eb in (BigFloat(10)^x for x in range(lo, hi, length = n))]
end

"The root at 300 bits, by bisection on a bracket the root is interior to, then Newton."
function bisected(M, e)
    Mb = BigFloat(M); eb = BigFloat(e)
    f(E) = E - eb * sin(E) - Mb
    lo, hi = BigFloat(-pi) - 1, BigFloat(pi) + 1
    for _ in 1:320
        mid = (lo + hi) / 2
        if f(mid) > 0; hi = mid; else; lo = mid; end
    end
    E = (lo + hi) / 2
    for _ in 1:3
        E -= ((1 - eb) * E + eb * (E - sin(E)) - Mb) / ((1 - eb) + 2 * eb * abs2(sin(E / 2)))
    end
    return E, abs(f(E))
end

"Markley's closed form with no refinement: Markley equations 20 to 29."
closed_form(M, e) = (Mr = rem2pi(M, RoundNearest); iszero(Mr) ? zero(M) : Orbit.markley_start(Mr, e))

"Two Newton steps on the naive residual and the naive derivative."
function naive_refined(M, e)
    Mr = rem2pi(M, RoundNearest)
    E = iszero(Mr) ? zero(M) : Orbit.markley_start(Mr, e)
    for _ in 1:2
        E -= Orbit.naive_kepler_residual(E, e, Mr) / (one(E) - e * cos(E))
    end
    return E
end

"The stable residual with the series truncated at five terms instead of seven."
function five_term(M, e)
    Mr = rem2pi(M, RoundNearest)
    E = iszero(Mr) ? zero(M) : Orbit.markley_start(Mr, e)
    ems(x) = abs(x) < 0.5 ?
        x * x * x * @evalpoly(x * x, 1/6, -1/120, 1/5040, -1/362880, 1/39916800) :
        x - sin(x)
    for _ in 1:2
        E -= ((1 - e) * E + e * ems(E) - Mr) / ((1 - e) + 2 * e * abs2(sin(E / 2)))
    end
    return E
end

worst(f, e, sample) = maximum(abs(Float64(BigFloat(f(M, e)) - Eref)) / ULP for (M, Eref) in sample)

@kernel function kepler_kernel!(out, @Const(Ms), e)
    i = @index(Global)
    @inbounds out[i] = Orbit.eccentric_anomaly(Ms[i], e)
end

@testset "Orbit" begin
    @testset "the reference is the root, not an opinion about it" begin
        residuals = [bisected(M, e)[2] for e in ECCENTRICITIES for (M, _) in hard_region(e, 8)]
        @test maximum(residuals) < 1e-80
    end

    @testset "the derived reference is finer than the bar it serves" begin
        shift = maximum(abs(Float64(bisected(M, e)[1] - Eref)) / ULP
                        for e in ECCENTRICITIES for (M, Eref) in hard_region(e, 30))
        @test shift < BAR / 20
    end

    @testset "eccentric anomaly to rounding at e = $e" for e in ECCENTRICITIES
        sample = hard_region(e, 60)
        @test worst(Orbit.eccentric_anomaly, e, sample) <= BAR
        @test maximum(abs(Float64((BigFloat(Orbit.eccentric_anomaly(M, e)) - Eref) / Eref))
                      for (M, Eref) in sample) < 1e-15
    end

    @testset "positive controls fire at e = 1 - 1e-9 and beyond" begin
        for e in (1 - 1e-9, 1 - 1e-12)
            sample = hard_region(e, 60)
            @test worst(closed_form, e, sample) > 100
            @test worst(naive_refined, e, sample) > 100
        end
    end

    @testset "the series needs seven terms" begin
        sample = hard_region(0.9, 200)
        @test worst(five_term, 0.9, sample) > 10
        @test worst(Orbit.eccentric_anomaly, 0.9, sample) <= BAR
    end

    @testset "the solve runs inside a portable kernel" begin
        Ms = collect(range(-3.0, 3.0, length = 64))
        e = 1 - 1e-9
        backend = CPU()
        out = similar(Ms)
        kepler_kernel!(backend, 16)(out, Ms, e, ndrange = length(Ms))
        KernelAbstractions.synchronize(backend)
        @test out == [Orbit.eccentric_anomaly(M, e) for M in Ms]

        if CUDA.functional()
            d_Ms = CuArray(Ms)
            d_out = similar(d_Ms)
            gpu = CUDABackend()
            kepler_kernel!(gpu, 16)(d_out, d_Ms, e, ndrange = length(Ms))
            KernelAbstractions.synchronize(gpu)
            device = Array(d_out)
            @test all(isfinite, device)
            @test maximum(abs.(device .- out)) / ULP <= BAR
        else
            @info "no functional device; the device arm of the kernel launch did not run"
        end
    end

    @testset "the eccentricity guard is not in the kernel" begin
        @test Orbit.eccentric_anomaly(1.0, 1.5) isa Float64
        @test !isempty(methods(Orbit.check_eccentricity))
        @test_throws Exception Orbit.check_eccentricity(1.5, "test")
        @test Orbit.check_eccentricity(0.5, "test") === 0.5
    end
end
