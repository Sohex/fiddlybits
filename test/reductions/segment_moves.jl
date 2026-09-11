using Test
using CUDA
using Fiddlybits: Reductions, Backends, Events, Verdicts

# What a segmented reduction reads back to the host on device-resident
# inputs: docs/plans/fiddlybits-52v.7-kernels.md, section "The reductions",
# and decision 0011 (the GPU-first path). A device-to-host copy is a
# synchronisation point, so the count that matters is how many of them a
# repeated reduction takes, counted through a fixture Events sink over
# Backends.on.

"The number of Events.Moved records `f` produces."
function moves(f)
    log = Events.Moved[]
    Events.sink!(rec -> push!(log, rec))
    try
        f()
    finally
        Events.sink!(Events.noop_sink)
    end
    return length(log)
end

@testset "host reads of the boundary array on device-resident inputs" begin
    @test CUDA.functional()

    xs = ReductionFixtures.seeded_vector(Float64, ReductionFixtures.N)
    starts = ReductionFixtures.segment_starts(ReductionFixtures.N, ReductionFixtures.NSEG)
    quartered = ReductionFixtures.segment_starts(ReductionFixtures.N, ReductionFixtures.N ÷ 4^3)
    weights = abs.(xs) .+ 0.1

    gpu = Backends.GPU(8)
    xs_gpu = Backends.on(xs, gpu)
    starts_gpu = Backends.on(starts, gpu)
    quartered_gpu = Backends.on(quartered, gpu)
    weights_gpu = Backends.on(weights, gpu)

    repeats = 10

    @testset "a boundary array is read back once per call" begin
        @test moves(() -> Reductions.segmented_sum(Float64, xs_gpu, starts_gpu, gpu)) == 1
        @test moves(() -> Reductions.segmented_mean(Float64, xs_gpu, starts_gpu, weights_gpu, gpu)) == 1
        @test moves(() -> Reductions.segmented_quantile(xs_gpu, quartered_gpu, 0.5, gpu)) == 1

        @test moves() do
            for _ in 1:repeats
                Reductions.segmented_sum(Float64, xs_gpu, starts_gpu, gpu)
            end
        end == repeats
    end

    @testset "a Segmentation is read back once and no times after that" begin
        @test moves(() -> Reductions.Segmentation(xs_gpu, starts_gpu)) == 1

        segmentation = Reductions.Segmentation(xs_gpu, starts_gpu)
        @test moves(() -> Reductions.segmented_sum(Float64, xs_gpu, segmentation, gpu)) == 0
        @test moves(() -> Reductions.segmented_mean(Float64, xs_gpu, segmentation, weights_gpu, gpu)) == 0

        quartered_segmentation = Reductions.Segmentation(xs_gpu, quartered_gpu)
        @test moves(() -> Reductions.segmented_quantile(xs_gpu, quartered_segmentation, 0.5, gpu)) == 0

        @test moves() do
            built = Reductions.Segmentation(xs_gpu, starts_gpu)
            for _ in 1:repeats
                Reductions.segmented_sum(Float64, xs_gpu, built, gpu)
            end
        end == 1
    end

    @testset "the reduction is the same one either way" begin
        segmentation = Reductions.Segmentation(xs_gpu, starts_gpu)
        quartered_segmentation = Reductions.Segmentation(xs_gpu, quartered_gpu)

        @test Array(Reductions.segmented_sum(Float64, xs_gpu, segmentation, gpu)) ==
              Reductions.segmented_sum_reference(Float64, xs, starts)
        @test Array(Reductions.segmented_mean(Float64, xs_gpu, segmentation, weights_gpu, gpu)) ==
              Reductions.segmented_mean(Float64, xs, starts, weights, Backends.CPU(8))
        @test Array(Reductions.segmented_quantile(xs_gpu, quartered_segmentation, 0.5, gpu)) ==
              Reductions.segmented_quantile_reference(xs, quartered, 0.5)
    end

    @testset "a malformed boundary array on the device is refused on its first use" begin
        for bad in ([2, ReductionFixtures.N + 1], [1, ReductionFixtures.N],
                    [1, 10, 5, ReductionFixtures.N + 1])
            bad_gpu = Backends.on(bad, gpu)
            @test_throws Verdicts.Refusal Reductions.Segmentation(xs_gpu, bad_gpu)
            @test_throws Verdicts.Refusal Reductions.segmented_sum(Float64, xs_gpu, bad_gpu, gpu)

            @testset "and the refusal costs the read that finds it" begin
                @test moves() do
                    try
                        Reductions.segmented_sum(Float64, xs_gpu, bad_gpu, gpu)
                    catch e
                        e isa Verdicts.Refusal || rethrow()
                    end
                end == 1
            end
        end

        @testset "positive control: the fixture's own boundaries are not refused" begin
            @test Reductions.Segmentation(xs_gpu, starts_gpu) isa Reductions.Segmentation
        end
    end
end
