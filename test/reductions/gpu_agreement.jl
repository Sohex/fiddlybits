using Test
using CUDA
using Fiddlybits: Reductions, Backends

# GPU-first (decision 0011): every reduction with a backend argument runs
# through the same Backends.launch! path on CPU and GPU. Pure addition has
# no fused-multiply-add ambiguity (unlike Backends.axpy!'s a*x+y), so CPU
# and GPU agree bitwise here, not only to backend_agreement.jl's fast-mode
# tolerance. Every array a kernel touches is moved to its backend
# explicitly through Backends.on first (test/backends/backend_agreement.jl's
# convention).
#
# compensated_sum takes no backend argument (it is a sequential host
# accumulator, decision 0029's compensation state threaded one term at a
# time) and is not exercised here.

@testset "CPU and GPU agree bitwise for pairwise_sum and segmented_sum" begin
    @test CUDA.functional()

    xs = ReductionFixtures.seeded_vector(Float64, ReductionFixtures.N)
    starts = ReductionFixtures.segment_starts(ReductionFixtures.N, ReductionFixtures.NSEG)
    weights = abs.(xs) .+ 0.1

    @testset "pairwise_sum" begin
        cpu_result = Reductions.pairwise_sum(Float64, xs, Backends.CPU(8))

        gpu = Backends.GPU(8)
        xs_gpu = Backends.on(xs, gpu)
        gpu_result = Reductions.pairwise_sum(Float64, xs_gpu, gpu)

        @test gpu_result == cpu_result
    end

    @testset "segmented_sum" begin
        cpu_result = Reductions.segmented_sum(Float64, xs, starts, Backends.CPU(8))

        gpu = Backends.GPU(8)
        xs_gpu = Backends.on(xs, gpu)
        starts_gpu = Backends.on(starts, gpu)
        gpu_result = Reductions.segmented_sum(Float64, xs_gpu, starts_gpu, gpu)

        @test Array(gpu_result) == cpu_result
    end

    @testset "segmented_mean" begin
        cpu_result = Reductions.segmented_mean(Float64, xs, starts, weights, Backends.CPU(8))

        gpu = Backends.GPU(8)
        xs_gpu = Backends.on(xs, gpu)
        starts_gpu = Backends.on(starts, gpu)
        weights_gpu = Backends.on(weights, gpu)
        gpu_result = Reductions.segmented_mean(Float64, xs_gpu, starts_gpu, weights_gpu, gpu)

        @test Array(gpu_result) == cpu_result
    end

    @testset "positive control: a difference between the two arrays is caught" begin
        cpu_result = Reductions.pairwise_sum(Float64, xs, Backends.CPU(8))

        gpu = Backends.GPU(8)
        mutated = copy(xs)
        mutated[1] += 1.0
        mutated_gpu = Backends.on(mutated, gpu)
        gpu_result = Reductions.pairwise_sum(Float64, mutated_gpu, gpu)

        @test gpu_result != cpu_result
    end
end
