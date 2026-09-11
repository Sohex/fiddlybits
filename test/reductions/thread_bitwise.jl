using Test

# Decision 0029: one-thread and sixteen-thread CPU runs are bitwise
# identical. Julia's own thread count is fixed for the life of a process,
# so each configuration is a fresh process started with `-t`, and the two
# runs are compared as raw bytes so the parent process makes no floating
# point comparison of its own. The same technique as
# test/backends/thread_bitwise.jl.

const REDUCTIONS_PROJECT = normpath(joinpath(@__DIR__, "..", ".."))
const REDUCTIONS_FIXTURES_FILE = joinpath(@__DIR__, "fixtures.jl")

"""
    run_reductions_at(nthreads)

The raw bytes `pairwise_sum`, `compensated_sum` and `segmented_sum` write
to `stdout`, run on `Backends.CPU` in a fresh process started with
`nthreads` Julia threads.
"""
function run_reductions_at(nthreads::Integer)
    code = """
        using Fiddlybits: Reductions, Backends
        include("$REDUCTIONS_FIXTURES_FILE")
        xs = ReductionFixtures.seeded_vector(Float64, ReductionFixtures.N)
        starts = ReductionFixtures.segment_starts(ReductionFixtures.N, ReductionFixtures.NSEG)
        backend = Backends.CPU(4)
        p = Reductions.pairwise_sum(Float64, xs, backend)
        c = Reductions.compensated_sum(xs)
        s = Reductions.segmented_sum(Float64, xs, starts, backend)
        write(stdout, [p])
        write(stdout, [c])
        write(stdout, s)
    """
    return read(`julia --startup-file=no --project=$REDUCTIONS_PROJECT -t $nthreads -e $code`)
end

@testset "thread-count bitwise identity (decision 0029)" begin
    one = run_reductions_at(1)
    sixteen = run_reductions_at(16)

    @test !isempty(one)
    @test one == sixteen

    @testset "positive control: a genuinely different run is detected" begin
        # Not a thread-count variation: the fixture itself must differ for
        # the byte comparison above to be a real check and not a
        # tautology, so a different NSEG (and so a different starts array)
        # is compared against the same one-thread bytes.
        code = """
            using Fiddlybits: Reductions, Backends
            include("$REDUCTIONS_FIXTURES_FILE")
            xs = ReductionFixtures.seeded_vector(Float64, ReductionFixtures.N)
            starts = ReductionFixtures.segment_starts(ReductionFixtures.N, ReductionFixtures.NSEG + 1)
            backend = Backends.CPU(4)
            p = Reductions.pairwise_sum(Float64, xs, backend)
            c = Reductions.compensated_sum(xs)
            s = Reductions.segmented_sum(Float64, xs, starts, backend)
            write(stdout, [p])
            write(stdout, [c])
            write(stdout, s)
        """
        mutated = read(`julia --startup-file=no --project=$REDUCTIONS_PROJECT -t 1 -e $code`)
        @test one != mutated
    end
end
