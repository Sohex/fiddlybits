using Test
using Fiddlybits: Reductions, Backends

# The named registry oracle: docs/oracles/registry.toml,
# kernels.reduction_partition_independent. Every reduction is bitwise
# identical across thread counts and block partitions, its residual
# against an exact sum on adversarial inputs is within the declared bound,
# and both of the oracle's positive controls fire: an atomic accumulation
# substituted for the fixed-order tree differs across thread counts, and a
# sequence that breaks a naive sum is passed by the compensated one.

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

        @testset "thread counts: 1, 4 and 16 Julia threads, separate processes" begin
            one = run_reductions_at(1)
            four = run_reductions_at(4)
            sixteen = run_reductions_at(16)
            @test !isempty(one)
            @test one == four == sixteen
        end
    end

    @testset "positive control: an atomic accumulation substituted for the fixed-order tree differs across thread counts" begin
        # A deliberately partition-dependent reduction, kept in the test
        # only (decision 0029 forbids atomics in the physics path): each
        # thread races an atomic add against a sequence whose exact sum is
        # 0.0 and whose single-accumulator sequential sum is -1.0
        # (ReductionFixtures.cancelling_quadruples), so a different arrival
        # order among threads gives a different, and generally wrong,
        # total.
        n = 20_000
        code = """
            n = $(4n)
            xs = Vector{Float64}(undef, n)
            for b in 0:(n ÷ 4 - 1)
                xs[4b+1] = 1.0e16
                xs[4b+2] = 1.0
                xs[4b+3] = -1.0e16
                xs[4b+4] = -1.0
            end
            mutable struct AtomicAcc
                @atomic value::Float64
            end
            acc = AtomicAcc(0.0)
            Threads.@threads for i in eachindex(xs)
                @atomic acc.value += xs[i]
            end
            write(stdout, [acc.value])
        """
        run_atomic_at(nthreads::Integer) =
            read(`julia --startup-file=no -t $nthreads -e $code`)

        baseline = run_atomic_at(1)
        repeats = [run_atomic_at(16) for _ in 1:5]
        @test any(r -> r != baseline, repeats)
    end
end
