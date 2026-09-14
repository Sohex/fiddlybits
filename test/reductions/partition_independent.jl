using Test
using Fiddlybits: Reductions, Backends

# The named registry oracle: docs/oracles/registry.toml,
# kernels.reduction_partition_independent. Every reduction is bitwise
# identical across thread counts and block partitions, its residual
# against an exact sum on adversarial inputs is within the declared bound,
# and both of the oracle's positive controls fire: an accumulation whose
# blocks follow the thread count or the workgroup, substituted for the
# fixed-order tree, differs across thread counts and across workgroups, and
# a sequence that breaks a naive sum is passed by the compensated one.

@testset "kernels.reduction_partition_independent" begin
    @testset "residual on adversarial (mixed-sign, non-monotone) input is within k*N*eps*M" begin
        xs = ReductionFixtures.seeded_vector(Float64, ReductionFixtures.N)
        exact = ReductionFixtures.exact_sum(xs)
        tol = Reductions.error_bound(Float64, length(xs), ReductionFixtures.term_magnitude(xs))

        @test abs(Reductions.pairwise_sum(Float64, xs) - exact) <= tol
        @test abs(Reductions.pairwise_sum_reference(Float64, xs) - exact) <= tol
        @test abs(Reductions.compensated_sum(xs) - exact) <= tol
    end

    @testset "positive control: a naive sum fails on alternating magnitudes, a compensated sum passes" begin
        # increment_scale is the magnitude of the million deposits, not of
        # the sequence including the stock (Reductions.error_bound's
        # documented magnitude): a narrower, problem-specific tolerance for
        # whether the deposits were captured, not the general k*N*eps*M
        # guarantee.
        n = 1_000_000
        xs = ReductionFixtures.stock_and_increments(Float32, n)
        exact = 1.0e8 + n
        increment_scale = 1.0

        naive = 0.0f0
        for x in xs
            naive += x
        end
        tight_tol = Reductions.error_bound(Float64, n, increment_scale)

        @test abs(Float64(naive) - exact) > tight_tol
        @test abs(Reductions.compensated_sum(xs) - exact) <= tight_tol
    end

    @testset "every reduction is bitwise identical across thread counts and block partitions" begin
        xs = ReductionFixtures.seeded_vector(Float64, ReductionFixtures.N)
        starts = ReductionFixtures.segment_starts(ReductionFixtures.N, ReductionFixtures.NSEG)

        @testset "block partitions: same blocksize, different workgroup" begin
            wg4 = Reductions.pairwise_sum(Float64, xs, Backends.CPU(4))
            wg16 = Reductions.pairwise_sum(Float64, xs, Backends.CPU(16))
            @test wg4 == wg16

            seg_wg4 = Reductions.segmented_sum(Float64, xs, starts, Backends.CPU(4))
            seg_wg16 = Reductions.segmented_sum(Float64, xs, starts, Backends.CPU(16))
            @test seg_wg4 == seg_wg16
        end

        @testset "the launch rule against pinned workgroups, on both backends" begin
            # Backends.launch_workgroup chooses the workgroup of an unpinned backend per
            # launch; each reduction below runs unpinned and pinned at 1 and 256, and the
            # launches are read back from Backends.queued_launches so the comparison is
            # between launches that differ.
            gpu = Backends.GPU()
            for nseg in (100, 200, 5000)
                n = 16 * nseg
                xs = ReductionFixtures.seeded_vector(Float64, n)
                weights = abs.(xs) .+ 0.1
                starts = collect(1:16:n+1)
                results(backend) = begin
                    xs_b, w_b = Backends.on(xs, backend), Backends.on(weights, backend)
                    seg = Reductions.Segmentation(xs_b, Backends.on(starts, backend))
                    [collect(reinterpret(UInt8, Backends.on(r, Backends.CPU(1))))
                     for r in (Reductions.segmented_sum(Float64, xs_b, seg, backend),
                               Reductions.segmented_weighted_sum(Float64, xs_b, w_b, seg, backend),
                               Reductions.segmented_mean(Float64, xs_b, seg, w_b, backend))]
                end
                @test results(gpu) == results(Backends.GPU(1)) == results(Backends.GPU(256))
                @test results(Backends.CPU()) == results(Backends.CPU(16)) == results(gpu)

                xs_g = Backends.on(xs, gpu)
                seg_g = Reductions.Segmentation(xs_g, Backends.on(starts, gpu))
                launched(backend) = begin
                    Backends.complete!(gpu)
                    Reductions.segmented_sum(Float64, xs_g, seg_g, backend)
                    shape = [launch.workgroup for launch in Backends.queued_launches(gpu)]
                    Backends.complete!(gpu)
                    shape
                end
                @testset "positive control: the unpinned launch of $nseg segments ran at its rule, not at a pin" begin
                    @test launched(gpu) == [Backends.launch_workgroup(gpu, nseg)]
                    @test launched(Backends.GPU(256)) == [256]
                    @test Backends.launch_workgroup(gpu, nseg) != 256
                end
            end
        end

        @testset "the column forms against pinned workgroups, on both backends" begin
            # Each column form runs unpinned and pinned at 1 and 256 over one column and
            # over three, and the unpinned launch's workgroup is read back from
            # Backends.queued_launches.
            gpu = Backends.GPU()
            for nseg in (100, 200, 5000), trailing in ((1,), (3,))
                n = 16 * nseg
                ncol = prod(trailing)
                field = reshape(ReductionFixtures.seeded_vector(Float64, n * ncol), n, trailing...)
                weights = abs.(ReductionFixtures.seeded_vector(Float64, n)) .+ 0.1
                starts = collect(1:16:n+1)
                legend = (:first, :second, :third)
                labels = ReductionFixtures.seeded_labels(n, trailing, legend)
                column_results(backend) = begin
                    field_b, w_b = Backends.on(field, backend), Backends.on(weights, backend)
                    seg = Reductions.Segmentation(field_b, Backends.on(starts, backend))
                    bytes = [collect(reinterpret(UInt8, vec(Backends.on(r, Backends.CPU(1)))))
                             for r in (Reductions.segmented_sum(Float64, field_b, seg, backend),
                                       Reductions.segmented_weighted_sum(Float64, field_b, w_b, seg, backend),
                                       Reductions.segmented_mean(Float64, field_b, seg, w_b, backend),
                                       Reductions.segmented_quantile(field_b, seg, 0.5, backend),
                                       Reductions.pairwise_block_sums(Float64, field_b, backend))]
                    push!(bytes, collect(reinterpret(UInt8, Reductions.pairwise_sum(Float64, field_b, backend))))
                    indicator = Reductions.ClassIndicator{Float64}(labels, legend, backend)
                    class_seg = Reductions.Segmentation(indicator, Backends.on(starts, backend))
                    for r in (Reductions.segmented_mean(Float64, indicator, class_seg, w_b, backend),
                              Reductions.segmented_weighted_sum(Float64, indicator, w_b, class_seg, backend))
                        push!(bytes, collect(reinterpret(UInt8, vec(Backends.on(r, Backends.CPU(1))))))
                    end
                    bytes
                end
                @test column_results(gpu) == column_results(Backends.GPU(1)) == column_results(Backends.GPU(256))
                @test column_results(Backends.CPU()) == column_results(Backends.CPU(16)) == column_results(gpu)

                field_g = Backends.on(field, gpu)
                seg_g = Reductions.Segmentation(field_g, Backends.on(starts, gpu))
                column_launched(backend) = begin
                    Backends.complete!(gpu)
                    Reductions.segmented_sum(Float64, field_g, seg_g, backend)
                    shape = [launch.workgroup for launch in Backends.queued_launches(gpu)]
                    Backends.complete!(gpu)
                    shape
                end
                @testset "positive control: the unpinned launch of $nseg segments of $ncol column(s) ran at its rule, not at a pin" begin
                    @test column_launched(gpu) == [Backends.launch_workgroup(gpu, nseg * ncol)]
                    @test column_launched(Backends.GPU(256)) == [256]
                    @test Backends.launch_workgroup(gpu, nseg * ncol) != 256
                end

                indicator_g = Reductions.ClassIndicator{Float64}(labels, legend, gpu)
                class_seg_g = Reductions.Segmentation(indicator_g, Backends.on(starts, gpu))
                weights_g = Backends.on(weights, gpu)
                class_launched = backend -> begin
                    Backends.complete!(gpu)
                    Reductions.segmented_weighted_sum(Float64, indicator_g, weights_g, class_seg_g, backend)
                    shape = [launch.workgroup for launch in Backends.queued_launches(gpu)]
                    Backends.complete!(gpu)
                    shape
                end
                @testset "positive control: the unpinned class launch of $nseg segments of $ncol column(s) and 3 classes ran at its rule, not at a pin" begin
                    items = nseg * ncol * length(legend)
                    @test class_launched(gpu) == [Backends.launch_workgroup(gpu, items)]
                    @test class_launched(Backends.GPU(256)) == [256]
                    trailing == (1,) && @test Backends.launch_workgroup(gpu, items) != 256
                end
            end
        end

        @testset "thread counts: 1, 4 and 16 Julia threads, separate processes" begin
            one = run_reductions_at(1)
            four = run_reductions_at(4)
            sixteen = run_reductions_at(16)
            @test !isempty(one)
            @test one == four == sixteen
        end
    end

    @testset "positive control: an accumulation whose blocks follow the thread count or the workgroup, substituted for the fixed-order tree, differs across both" begin
        # The substituted accumulation is Reductions.pairwise_block_sums
        # with its block length read from the partition (the thread count
        # of the process, or the backend's workgroup) in place of
        # Reductions.BLOCKSIZE, over ReductionFixtures.cancelling_quadruples,
        # each block summed left to right from 0.0 and the block sums
        # combined by Reductions.combine_fixed_order. Every block length
        # used is a whole number of quadruples, each block sums to -1.0, and
        # the total is minus the number of blocks: -1, -4 and -16 at 1, 4
        # and 16 threads, -1024 and -256 at workgroups 4 and 16. The
        # arithmetic is in
        # notes/findings/2026-09-13-the-partition-control-fires-by-construction.md.
        # Reductions.pairwise_sum runs beside it on the same sequence and
        # partitions and is compared the same way.
        nquad = 1024

        @testset "blocks of length(xs) / nthreads at 1, 4 and 16 Julia threads, separate processes" begin
            code = """
                using Fiddlybits: Reductions, Backends
                include("$REDUCTIONS_FIXTURES_FILE")
                xs = ReductionFixtures.cancelling_quadruples($nquad)
                backend = Backends.CPU(4)
                rem(length(xs), 4 * Threads.nthreads()) == 0 ||
                    error("\$(length(xs)) terms are not whole quadruples per block at \$(Threads.nthreads()) threads")
                by_threads = Reductions.combine_fixed_order(
                    Reductions.pairwise_block_sums(Float64, xs, backend;
                                                   blocksize = length(xs) ÷ Threads.nthreads()))
                fixed = Reductions.pairwise_sum(Float64, xs, backend)
                write(stdout, [by_threads, fixed])
            """
            run_partitioned_at(nthreads::Integer) =
                read(`julia --startup-file=no --project=$REDUCTIONS_PROJECT -t $nthreads -e $code`)

            bytes = Dict(t => run_partitioned_at(t) for t in (1, 4, 16))
            partitioned(t) = bytes[t][1:8]
            fixed(t) = bytes[t][9:16]
            bytes_of(value::Float64) = collect(reinterpret(UInt8, [value]))

            @test all(t -> length(bytes[t]) == 16, (1, 4, 16))
            @test !(partitioned(1) == partitioned(4) == partitioned(16))
            @test fixed(1) == fixed(4) == fixed(16)
            @test partitioned(1) == bytes_of(-1.0)
            @test partitioned(4) == bytes_of(-4.0)
            @test partitioned(16) == bytes_of(-16.0)
        end

        @testset "blocks of the workgroup length on CPU(4) and CPU(16), one process" begin
            xs = ReductionFixtures.cancelling_quadruples(nquad)
            by_workgroup(backend) = Reductions.combine_fixed_order(
                Reductions.pairwise_block_sums(Float64, xs, backend;
                                               blocksize = Backends.workgroup(backend)))
            wg4 = by_workgroup(Backends.CPU(4))
            wg16 = by_workgroup(Backends.CPU(16))

            @test wg4 != wg16
            @test Reductions.pairwise_sum(Float64, xs, Backends.CPU(4)) ==
                  Reductions.pairwise_sum(Float64, xs, Backends.CPU(16))
            @test wg4 == -1024.0
            @test wg16 == -256.0
        end
    end
end
