using Test

# One entry point per test directory, discovered rather than listed, so that a row
# adding a suite touches only its own directory. A directory with no entry point
# fails the run; fixtures directories hold inputs and not tests.

const TEST_ROOT = @__DIR__
const NOT_A_SUITE = ("fixtures",)

function suites(root::AbstractString)
    found = String[]
    missing = String[]
    for name in sort(readdir(root))
        name in NOT_A_SUITE && continue
        dir = joinpath(root, name)
        isdir(dir) || continue
        entry = joinpath(dir, "runtests.jl")
        push!(isfile(entry) ? found : missing, name)
    end
    return found, missing
end

const FOUND, MISSING = suites(TEST_ROOT)

@testset "Fiddlybits" begin
    @testset "every test directory is a suite" begin
        @test isempty(MISSING)
    end
    for name in FOUND
        include(joinpath(TEST_ROOT, name, "runtests.jl"))
    end
end
