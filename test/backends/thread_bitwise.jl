using Test

# Decision 0029: one-thread and sixteen-thread CPU runs are bitwise identical.
# Julia's own thread count is fixed for the life of a process, so each
# configuration is a fresh process started with `-t`, and the two runs are
# compared as raw bytes so the parent process makes no floating point
# comparison of its own.

const BACKENDS_PROJECT = normpath(joinpath(@__DIR__, "..", ".."))
const FIXTURES_FILE = joinpath(@__DIR__, "fixtures.jl")

"""
    run_at(nthreads; a)

The raw bytes `axpy!` and `stencil_gather!` write to `stdout`, run on
`Backends.CPU` in a fresh process started with `nthreads` Julia threads and
axpy coefficient `a`.
"""
function run_at(nthreads::Integer; a::Real = 1.3)
    code = """
        using Fiddlybits: Backends
        include("$FIXTURES_FILE")
        n, nk = BackendFixtures.N_CELLS, BackendFixtures.NK
        x = BackendFixtures.seeded_vector(Float64, n)
        y = BackendFixtures.seeded_vector(Float64, n) .* 2.0
        neighbour, weight = BackendFixtures.stencil_tables(Float64, n, nk)
        input = BackendFixtures.seeded_vector(Float64, n)
        out = Vector{Float64}(undef, n)
        backend = Backends.CPU(4)
        Backends.axpy!(y, $(repr(Float64(a))), x, backend)
        Backends.stencil_gather!(out, input, neighbour, weight, backend)
        write(stdout, y)
        write(stdout, out)
    """
    return read(`julia --startup-file=no --project=$BACKENDS_PROJECT -t $nthreads -e $code`)
end

@testset "thread-count bitwise identity (decision 0029)" begin
    one = run_at(1)
    sixteen = run_at(16)

    @test !isempty(one)
    @test one == sixteen

    @testset "positive control: a genuinely different run is detected" begin
        mutated = run_at(1; a = 1.3 + 1.0e-6)
        @test one != mutated
    end
end
