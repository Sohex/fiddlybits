using Test
using CUDA
using Fiddlybits: Reductions, Backends, Events, Verdicts

# What a reduction reads back to the host on device-resident inputs:
# docs/plans/fiddlybits-52v.7-kernels.md, section "The reductions", and
# decision 0011 (the GPU-first path). A device-to-host copy is a
# synchronisation point, so the count that matters is how many of them a
# repeated reduction takes, counted through a fixture Events sink over
# Backends.on. Every such copy in Reductions goes through Backends.on, so
# the sink sees all of them; a copy that bypassed it would make one of the
# counts below too low rather than too high.

"The Events.Moved records `f` produces."
function move_log(f)
    log = Events.Moved[]
    Events.sink!(rec -> push!(log, rec))
    try
        f()
    finally
        Events.sink!(Events.noop_sink)
    end
    return log
end

"The number of Events.Moved records `f` produces."
moves(f) = length(move_log(f))

"The number of Events.Moved records `f` produces that moved `array` itself."
moves_of(f, array) = count(rec -> rec.array === array, move_log(f))

@testset "host reads on device-resident inputs" begin
    @test CUDA.functional()

    xs = ReductionFixtures.seeded_vector(Float64, ReductionFixtures.N)
    starts = ReductionFixtures.segment_starts(ReductionFixtures.N, ReductionFixtures.NSEG)
    quartered = ReductionFixtures.segment_starts(ReductionFixtures.N, ReductionFixtures.N ÷ 4^3)
    weights = abs.(xs) .+ 0.1
    areas = abs.(xs) .+ 1.0

    gpu = Backends.GPU(8)
    cpu = Backends.CPU(8)
    xs_gpu = Backends.on(xs, gpu)
    starts_gpu = Backends.on(starts, gpu)
    quartered_gpu = Backends.on(quartered, gpu)
    weights_gpu = Backends.on(weights, gpu)
    areas_gpu = Backends.on(areas, gpu)

    repeats = 10

    @testset "the counter counts a move and does not count a non-move" begin
        @test moves(() -> Backends.on(xs_gpu, Backends.CPU(1))) == 1
        @test moves(() -> Backends.on(xs, Backends.CPU(1))) == 0
        @test moves_of(() -> Backends.on(xs_gpu, Backends.CPU(1)), xs_gpu) == 1
        @test moves_of(() -> Backends.on(xs_gpu, Backends.CPU(1)), starts_gpu) == 0
    end

    @testset "a boundary array is read back once per call" begin
        @test moves_of(() -> Reductions.segmented_sum(Float64, xs_gpu, starts_gpu, gpu),
                       starts_gpu) == 1
        @test moves_of(() -> Reductions.segmented_mean(Float64, xs_gpu, starts_gpu, weights_gpu, gpu),
                       starts_gpu) == 1
        @test moves_of(() -> Reductions.segmented_quantile(xs_gpu, quartered_gpu, 0.5, gpu),
                       quartered_gpu) == 1

        @test moves(() -> Reductions.segmented_sum(Float64, xs_gpu, starts_gpu, gpu)) == 1
        @test moves(() -> Reductions.segmented_quantile(xs_gpu, quartered_gpu, 0.5, gpu)) == 1

        @test moves() do
            for _ in 1:repeats
                Reductions.segmented_sum(Float64, xs_gpu, starts_gpu, gpu)
            end
        end == repeats
    end

    @testset "a Segmentation is read back once and its boundaries no times after that" begin
        @test moves(() -> Reductions.Segmentation(xs_gpu, starts_gpu)) == 1

        segmentation = Reductions.Segmentation(xs_gpu, starts_gpu)
        @test moves_of(() -> Reductions.segmented_sum(Float64, xs_gpu, segmentation, gpu),
                       starts_gpu) == 0
        @test moves_of(() -> Reductions.segmented_mean(Float64, xs_gpu, segmentation, weights_gpu, gpu),
                       starts_gpu) == 0
        @test moves(() -> Reductions.segmented_sum(Float64, xs_gpu, segmentation, gpu)) == 0

        quartered_segmentation = Reductions.Segmentation(xs_gpu, quartered_gpu)
        @test moves_of(() -> Reductions.segmented_quantile(xs_gpu, quartered_segmentation, 0.5, gpu),
                       quartered_gpu) == 0
        @test moves(() -> Reductions.segmented_quantile(xs_gpu, quartered_segmentation, 0.5, gpu)) == 0

        @test moves() do
            built = Reductions.Segmentation(xs_gpu, starts_gpu)
            for _ in 1:repeats
                Reductions.segmented_sum(Float64, xs_gpu, built, gpu)
            end
        end == 1
    end

    @testset "a reduction returning a host scalar reads that scalar back once per sum" begin
        @test moves(() -> Reductions.pairwise_sum(Float64, xs_gpu, gpu)) == 1
        @test moves(() -> Reductions.pairwise_sum(Float64, xs, cpu)) == 0

        @test moves() do
            for _ in 1:repeats
                Reductions.pairwise_sum(Float64, xs_gpu, gpu)
            end
        end == repeats

        # area_fraction_above is two pairwise_sums, each read back on its
        # own: fiddlybits-52v.7.48 carries whether they can share one read.
        @test moves(() -> Reductions.area_fraction_above(xs_gpu, areas_gpu, 0.0, gpu)) == 2
        @test moves(() -> Reductions.area_fraction_above(xs, areas, 0.0, cpu)) == 0
    end

    @testset "the zero-weight refusal reads one indicator back per call" begin
        segmentation = Reductions.Segmentation(xs_gpu, starts_gpu)
        @test moves(() -> Reductions.segmented_mean(Float64, xs_gpu, segmentation, weights_gpu, gpu)) == 1
        @test moves(() -> Reductions.segmented_mean(Float64, xs_gpu, starts_gpu, weights_gpu, gpu)) == 2
        @test moves(() -> Reductions.segmented_mean(Float64, xs, starts, weights, cpu)) == 0

        @test moves() do
            for _ in 1:repeats
                Reductions.segmented_mean(Float64, xs_gpu, segmentation, weights_gpu, gpu)
            end
        end == repeats

        @testset "and it still fires on a device-resident zero weight" begin
            zero_weights_gpu = Backends.on(zeros(length(xs)), gpu)
            @test_throws Verdicts.Refusal Reductions.segmented_mean(Float64, xs_gpu, segmentation,
                                                                    zero_weights_gpu, gpu)

            @testset "positive control: the fixture's own weights are not refused" begin
                @test Reductions.segmented_mean(Float64, xs_gpu, segmentation, weights_gpu, gpu) isa
                      AbstractVector
            end
        end
    end

    @testset "combine_fixed_order refuses a device array rather than reading it elementwise" begin
        partials_gpu = Reductions.pairwise_block_sums(Float64, xs_gpu, gpu)
        @test_throws Verdicts.Refusal Reductions.combine_fixed_order(partials_gpu)

        @testset "positive control: the same block sums on the host combine" begin
            @test Reductions.combine_fixed_order(Backends.on(partials_gpu, Backends.CPU(1))) ==
                  Reductions.pairwise_sum(Float64, xs_gpu, gpu)
        end
    end

    @testset "the reduction is the same one either way" begin
        segmentation = Reductions.Segmentation(xs_gpu, starts_gpu)
        quartered_segmentation = Reductions.Segmentation(xs_gpu, quartered_gpu)

        @test Array(Reductions.segmented_sum(Float64, xs_gpu, segmentation, gpu)) ==
              Reductions.segmented_sum_reference(Float64, xs, starts)
        @test Array(Reductions.segmented_mean(Float64, xs_gpu, segmentation, weights_gpu, gpu)) ==
              Reductions.segmented_mean(Float64, xs, starts, weights, cpu)
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
