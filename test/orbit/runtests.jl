using Test
using KernelAbstractions
using CUDA
using Fiddlybits: Orbit, Backends

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

"The backend the accuracy-only controls below run on: the platform library, plain arithmetic."
const LIBRARY = Backends.CPU(1)

"Markley's closed form with no refinement: Markley equations 20 to 29."
closed_form(M, e) = (Mr = rem2pi(M, RoundNearest); iszero(Mr) ? zero(M) : Orbit.markley_start(Mr, e, LIBRARY))

"Two Newton steps on the naive residual and the naive derivative."
function naive_refined(M, e)
    Mr = rem2pi(M, RoundNearest)
    E = iszero(Mr) ? zero(M) : Orbit.markley_start(Mr, e, LIBRARY)
    for _ in 1:2
        E -= Orbit.naive_kepler_residual(E, e, Mr) / (one(E) - e * cos(E))
    end
    return E
end

"The stable residual with the series truncated at five terms instead of seven."
function five_term(M, e)
    Mr = rem2pi(M, RoundNearest)
    E = iszero(Mr) ? zero(M) : Orbit.markley_start(Mr, e, LIBRARY)
    ems(x) = abs(x) < 0.5 ?
        x * x * x * @evalpoly(x * x, 1/6, -1/120, 1/5040, -1/362880, 1/39916800) :
        x - sin(x)
    for _ in 1:2
        E -= ((1 - e) * E + e * ems(E) - Mr) / ((1 - e) + 2 * e * abs2(sin(E / 2)))
    end
    return E
end

worst(f, e, sample) = maximum(abs(Float64(BigFloat(f(M, e)) - Eref)) / ULP for (M, Eref) in sample)

@kernel function kepler_kernel!(out, @Const(Ms), e, backend)
    i = @index(Global)
    @inbounds out[i] = Orbit.eccentric_anomaly(Ms[i], e, backend)
end

@kernel function eccentric_anomaly_kernel!(out, @Const(Ms), e, backend)
    i = @index(Global)
    @inbounds out[i] = Orbit.eccentric_anomaly(Ms[i], e, backend)
end

"`Orbit.eccentric_anomaly` over every mean anomaly in `Ms` at eccentricity `e`, launched
through `Backends.launch!` on `device`, so `device`'s mode (decision 0029) decides both
the arithmetic and the transcendentals."
function eccentric_anomaly_on(Ms, e, device)
    x = Backends.on(copy(Ms), device)
    out = Backends.on(similar(Ms), device)
    Backends.launch!(eccentric_anomaly_kernel!, device, length(Ms), out, x, e, device)
    return Array(out)
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
        for (mode, backend) in (("fast", Backends.CPU(1)), ("bitwise", Backends.CPU(1; bitwise = true)))
            @testset "$mode" begin
                f(M, e) = Orbit.eccentric_anomaly(M, e, backend)
                @test worst(f, e, sample) <= BAR
                @test maximum(abs(Float64((BigFloat(f(M, e)) - Eref) / Eref))
                              for (M, Eref) in sample) < 1e-15
            end
        end
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
        f(M, e) = Orbit.eccentric_anomaly(M, e, LIBRARY)
        @test worst(f, 0.9, sample) <= BAR
    end

    @testset "the solve runs inside a portable kernel" begin
        Ms = collect(range(-3.0, 3.0, length = 64))
        e = 1 - 1e-9
        backend = CPU()
        device = Backends.CPU(16)
        out = similar(Ms)
        kepler_kernel!(backend, 16)(out, Ms, e, device, ndrange = length(Ms))
        KernelAbstractions.synchronize(backend)
        @test out == [Orbit.eccentric_anomaly(M, e, device) for M in Ms]

        if CUDA.functional()
            d_Ms = CuArray(Ms)
            d_out = similar(d_Ms)
            gpu = CUDABackend()
            gpu_device = Backends.GPU(16)
            kepler_kernel!(gpu, 16)(d_out, d_Ms, e, gpu_device, ndrange = length(Ms))
            KernelAbstractions.synchronize(gpu)
            device_out = Array(d_out)
            @test all(isfinite, device_out)
            @test maximum(abs.(device_out .- out)) / ULP <= BAR
        else
            @info "no functional device; the device arm of the kernel launch did not run"
        end
    end

    @testset "the eccentricity guard is not in the kernel" begin
        @test Orbit.eccentric_anomaly(1.0, 1.5, LIBRARY) isa Float64
        @test !isempty(methods(Orbit.check_eccentricity))
        @test_throws Exception Orbit.check_eccentricity(1.5, "test")
        @test Orbit.check_eccentricity(0.5, "test") === 0.5
    end

    @testset "Orbit.eccentric_anomaly in bitwise mode is bitwise between the processor and the CUDA backend" begin
        @test CUDA.functional()
        for e in ECCENTRICITIES
            @testset "eccentricity $e" begin
                Ms = Float64[M for (M, _) in hard_region(e, 256)]
                cpu = eccentric_anomaly_on(Ms, e, Backends.CPU(64; bitwise = true))
                gpu = eccentric_anomaly_on(Ms, e, Backends.GPU(64; bitwise = true))
                @test cpu == gpu

                @testset "positive control: fast mode is not bitwise" begin
                    fast_cpu = eccentric_anomaly_on(Ms, e, Backends.CPU(64))
                    fast_gpu = eccentric_anomaly_on(Ms, e, Backends.GPU(64))
                    @test fast_cpu != fast_gpu
                end
            end
        end
    end

    @testset "rem2pi is exercised, and stays bitwise" begin
        # hard_region's mean anomalies are all inside [-pi, pi], so rem2pi's fast path
        # never reduces them. Shifted by whole turns, they fall outside it.
        e = 1 - 1e-9
        Ms = Float64[M + shift for (M, _) in hard_region(e, 64) for shift in (-6pi, -2pi, 2pi, 6pi)]
        @test any(M -> abs(M) >= pi, Ms)
        cpu = eccentric_anomaly_on(Ms, e, Backends.CPU(64; bitwise = true))
        gpu = eccentric_anomaly_on(Ms, e, Backends.GPU(64; bitwise = true))
        @test cpu == gpu
    end
end
