using Test
using CUDA
using Fiddlybits: Backends

# CPU and GPU agree elementwise for pure arithmetic, to the tolerance of
# decision 0029's fast mode: a fused kernel on the default (non-bitwise)
# backend may round a multiply and the add that follows it in one step on
# the GPU and in two on the CPU, one rounding-step difference per term. The
# exact-equality claim of bitwise mode is test/backends/bitwise_mode.jl's.
# Every array a kernel touches is moved to its backend explicitly through
# Backends.on first.

@testset "CPU and GPU agree for pure arithmetic and stencils" begin
    @test CUDA.functional()

    for FT in (Float64, Float32)
        @testset "axpy! ($FT)" begin
            n = BackendFixtures.N_CELLS
            x = BackendFixtures.seeded_vector(FT, n)
            a = FT(1.3)
            y0 = BackendFixtures.seeded_vector(FT, n) .* FT(2)

            y_cpu = copy(y0)
            Backends.axpy!(y_cpu, a, x, Backends.CPU(8))

            y_gpu = Backends.on(copy(y0), Backends.GPU(8))
            x_gpu = Backends.on(x, Backends.GPU(8))
            Backends.axpy!(y_gpu, a, x_gpu, Backends.GPU(8))

            tol = BackendFixtures.fp_tolerance(FT, 2, maximum(abs.(a .* x) .+ abs.(y0)))
            @test maximum(abs.(Backends.on(y_gpu, Backends.CPU(1)) .- y_cpu)) <= tol
        end

        @testset "stencil_gather! ($FT)" begin
            n, nk = BackendFixtures.N_CELLS, BackendFixtures.NK
            neighbour, weight = BackendFixtures.stencil_tables(FT, n, nk)
            input = BackendFixtures.seeded_vector(FT, n)

            out_cpu = Vector{FT}(undef, n)
            Backends.stencil_gather!(out_cpu, input, neighbour, weight, Backends.CPU(8))

            gpu = Backends.GPU(8)
            out_gpu = Backends.on(Vector{FT}(undef, n), gpu)
            input_gpu = Backends.on(input, gpu)
            neighbour_gpu = Backends.on(neighbour, gpu)
            weight_gpu = Backends.on(weight, gpu)
            Backends.stencil_gather!(out_gpu, input_gpu, neighbour_gpu, weight_gpu, gpu)

            per_element_sums = [sum(abs.(input[neighbour[:, i]] .* weight[:, i])) for i in 1:n]
            tol = BackendFixtures.fp_tolerance(FT, nk, maximum(per_element_sums))
            @test maximum(abs.(Backends.on(out_gpu, Backends.CPU(1)) .- out_cpu)) <= tol
        end
    end

    @testset "positive control: a difference far past the tolerance is caught" begin
        n = BackendFixtures.N_CELLS
        x = BackendFixtures.seeded_vector(Float64, n)
        y0 = BackendFixtures.seeded_vector(Float64, n) .* 2.0

        y_cpu = copy(y0)
        Backends.axpy!(y_cpu, 1.3, x, Backends.CPU(8))

        gpu = Backends.GPU(8)
        y_gpu = Backends.on(copy(y0), gpu)
        x_gpu = Backends.on(x, gpu)
        Backends.axpy!(y_gpu, 1.3 + 1.0e-3, x_gpu, gpu)

        tol = BackendFixtures.fp_tolerance(Float64, 2, maximum(abs.(1.3 .* x) .+ abs.(y0)))
        @test maximum(abs.(Backends.on(y_gpu, Backends.CPU(1)) .- y_cpu)) > tol
    end
end
