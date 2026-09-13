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
# counts below too low rather than too high. The sink a move goes to is the
# one Events.move_sink! installs, not the one Events.sink! installs for
# journal events: decision 0046.

"The Events.Moved records `f` produces."
function move_log(f)
    log = Events.Moved[]
    Events.move_sink!(rec -> push!(log, rec))
    try
        f()
    finally
        Events.move_sink!(Events.noop_sink)
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

        # area_fraction_above is two block-sum arrays joined on the device
        # and read back together, so it is one read and not one per sum.
        @test moves(() -> Reductions.area_fraction_above(xs_gpu, areas_gpu, 0.0, gpu)) == 1
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

    @testset "the bitonic network's copy to the card is not a recorded move" begin
        # The copy is a constant of k alone, built once per process and never
        # read back, so it is outside the recorded path:
        # docs/decisions/0047-a-kernels-own-constant-table-is-not-a-device-move.md.
        AT = Backends.array_type(gpu)
        k = Reductions.QUANTILE_K_MIN
        key = (AT, k)

        # The cache is process-lifetime, so the call that builds the copy is
        # reached by emptying this key rather than by running first.
        lock(Reductions.QUANTILE_BITONIC_NETWORK_DEVICE_LOCK) do
            delete!(Reductions.QUANTILE_BITONIC_NETWORK_DEVICE, key)
        end
        @test !haskey(Reductions.QUANTILE_BITONIC_NETWORK_DEVICE, key)

        @test moves(() -> Reductions.device_bitonic_network(gpu, k)) == 0
        @test haskey(Reductions.QUANTILE_BITONIC_NETWORK_DEVICE, key)
        @test moves(() -> Reductions.device_bitonic_network(gpu, k)) == 0

        @testset "positive control: the same table through the door is counted" begin
            # Both counts above are zero, so they say nothing unless the same
            # bytes handed to Backends.on do record a move.
            partner, _ = Reductions.QUANTILE_BITONIC_NETWORK[k]
            @test moves(() -> Backends.on(partner, gpu)) == 1
        end

        @testset "the other half of the network is a BitMatrix the door cannot take" begin
            # The third of decision 0047's three points. Which exception is
            # raised here is fiddlybits-52v.7.55; that it cannot be handed to
            # the door at all is the point.
            _, ascending = Reductions.QUANTILE_BITONIC_NETWORK[k]
            @test ascending isa BitMatrix
            @test_throws Exception Backends.on(ascending, gpu)
        end
    end

    @testset "the reduction is the same one either way" begin
        segmentation = Reductions.Segmentation(xs_gpu, starts_gpu)
        quartered_segmentation = Reductions.Segmentation(xs_gpu, quartered_gpu)

        @test Backends.on(Reductions.segmented_sum(Float64, xs_gpu, segmentation, gpu), cpu) ==
              Reductions.segmented_sum_reference(Float64, xs, starts)
        @test Backends.on(Reductions.segmented_mean(Float64, xs_gpu, segmentation,
                                                    weights_gpu, gpu), cpu) ==
              Reductions.segmented_mean(Float64, xs, starts, weights, cpu)
        @test Backends.on(Reductions.segmented_quantile(xs_gpu, quartered_segmentation,
                                                         0.5, gpu), cpu) ==
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

    # Every entry point in Reductions that can reach a device, its per-call
    # host-read count in one table. The counts above are the same numbers
    # reached one at a time; this testset is the restatement
    # fiddlybits-52v.7.47 asks for, and it is where a new reduction is added
    # or a changed one shows up. Whether pairwise_sum's own read is inherent
    # to its contract is settled in
    # notes/findings/2026-09-11-device-scalar-reduction-contract.md.
    @testset "every reduction in Reductions, its per-call host reads restated" begin
        segmentation = Reductions.Segmentation(xs_gpu, starts_gpu)
        quartered_segmentation = Reductions.Segmentation(xs_gpu, quartered_gpu)
        quartered_nseg = length(quartered) - 1
        host_partials = Reductions.pairwise_block_sums(Float64, xs, cpu)

        device_calls = [
            ("pairwise_block_sums", 0,
             () -> Reductions.pairwise_block_sums(Float64, xs_gpu, gpu)),
            ("pairwise_sum", 1,
             () -> Reductions.pairwise_sum(Float64, xs_gpu, gpu)),
            ("segment_extent", 1,
             () -> Reductions.segment_extent(xs_gpu, starts_gpu)),
            ("segment_depth", 1,
             () -> Reductions.segment_depth(quartered_gpu, quartered_nseg)),
            ("Segmentation", 1,
             () -> Reductions.Segmentation(xs_gpu, starts_gpu)),
            ("segmented_sum, boundary array", 1,
             () -> Reductions.segmented_sum(Float64, xs_gpu, starts_gpu, gpu)),
            ("segmented_sum, Segmentation", 0,
             () -> Reductions.segmented_sum(Float64, xs_gpu, segmentation, gpu)),
            ("segmented_mean, boundary array", 2,
             () -> Reductions.segmented_mean(Float64, xs_gpu, starts_gpu, weights_gpu, gpu)),
            ("segmented_mean, Segmentation", 1,
             () -> Reductions.segmented_mean(Float64, xs_gpu, segmentation, weights_gpu, gpu)),
            ("segmented_quantile, boundary array", 1,
             () -> Reductions.segmented_quantile(xs_gpu, quartered_gpu, 0.5, gpu)),
            ("segmented_quantile, Segmentation", 0,
             () -> Reductions.segmented_quantile(xs_gpu, quartered_segmentation, 0.5, gpu)),
            ("area_fraction_above", 1,
             () -> Reductions.area_fraction_above(xs_gpu, areas_gpu, 0.0, gpu)),
        ]

        for (name, expected, call) in device_calls
            @testset "$name reads the host $expected times per call" begin
                @test moves(call) == expected
                @test moves() do
                    for _ in 1:repeats
                        call()
                    end
                end == expected * repeats
            end
        end

        host_calls = [
            ("pairwise_block_sums", () -> Reductions.pairwise_block_sums(Float64, xs, cpu)),
            ("pairwise_sum", () -> Reductions.pairwise_sum(Float64, xs, cpu)),
            ("pairwise_sum_reference", () -> Reductions.pairwise_sum_reference(Float64, xs)),
            ("combine_fixed_order", () -> Reductions.combine_fixed_order(host_partials)),
            ("compensated_sum", () -> Reductions.compensated_sum(xs)),
            ("compensated_sum_reference", () -> Reductions.compensated_sum_reference(xs)),
            ("segment_extent", () -> Reductions.segment_extent(xs, starts)),
            ("segment_depth", () -> Reductions.segment_depth(quartered, quartered_nseg)),
            ("Segmentation", () -> Reductions.Segmentation(xs, starts)),
            ("segmented_sum", () -> Reductions.segmented_sum(Float64, xs, starts, cpu)),
            ("segmented_sum_reference",
             () -> Reductions.segmented_sum_reference(Float64, xs, starts)),
            ("segmented_weighted_sum_reference",
             () -> Reductions.segmented_weighted_sum_reference(Float64, xs, weights, starts)),
            ("segmented_mean",() -> Reductions.segmented_mean(Float64, xs, starts, weights, cpu)),
            ("segmented_mean_reference",
             () -> Reductions.segmented_mean_reference(Float64, xs, starts, weights)),
            ("segmented_quantile", () -> Reductions.segmented_quantile(xs, quartered, 0.5, cpu)),
            ("segmented_quantile_reference",
             () -> Reductions.segmented_quantile_reference(xs, quartered, 0.5)),
            ("area_fraction_above", () -> Reductions.area_fraction_above(xs, areas, 0.0, cpu)),
            ("area_fraction_above_reference",
             () -> Reductions.area_fraction_above_reference(xs, areas, 0.0)),
        ]

        for (name, call) in host_calls
            @testset "$name reads the host no times per call on host-resident input" begin
                @test moves(call) == 0
            end
        end

        @testset "positive control: the counter is live across the table's own calls" begin
            # Every count above is zero or small, so the table would read the
            # same way if the sink had been detached: one extra read of a
            # device array inside the same measured call must raise the count
            # by exactly one.
            for (name, expected, call) in device_calls
                @test moves(() -> (call(); Backends.on(xs_gpu, Backends.CPU(1)))) == expected + 1
            end
            for (name, call) in host_calls
                @test moves(() -> (call(); Backends.on(xs_gpu, Backends.CPU(1)))) == 1
            end
        end
    end
end
