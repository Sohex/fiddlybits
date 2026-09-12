using Test

# One entry point per test directory, discovered rather than listed, so that a row
# adding a suite touches only its own directory. A directory with no entry point
# fails the run; fixtures directories hold inputs and not tests.
#
# This door runs every suite in one process, in order. `tools/gate/run.jl` runs the
# same suites as concurrent processes and is what the gate calls; both read
# `suites` from `test/suites.jl`.
#
# Each suite's wall time is printed as a table at the end, so the cost of one arm
# stays visible in every run rather than having to be measured from outside.

const TEST_ROOT = @__DIR__
include(joinpath(TEST_ROOT, "suites.jl"))

const FOUND, MISSING = suites(TEST_ROOT)
const ELAPSED = Tuple{String,Float64}[]

"""
    report_elapsed(elapsed)

Print one line per suite, longest first, with its share of the total, then the
total. Printed whether the run passed or failed, because the table is the input to
every decision about what the gate runs and where.
"""
function report_elapsed(elapsed::Vector{Tuple{String,Float64}})
    isempty(elapsed) && return nothing
    total = sum(last, elapsed)
    width = maximum(length(first(e)) for e in elapsed)
    println()
    println("suite wall time, longest first")
    for (name, seconds) in sort(elapsed; by = last, rev = true)
        println("  ", rpad(name, width), "  ", lpad(round(seconds; digits = 1), 7), " s",
                "  ", lpad(round(100 * seconds / total; digits = 1), 5), " %")
    end
    println("  ", rpad("total", width), "  ", lpad(round(total; digits = 1), 7), " s")
    return nothing
end

atexit(() -> report_elapsed(ELAPSED))

@testset "Fiddlybits" begin
    @testset "every test directory is a suite" begin
        @test isempty(MISSING)
    end
    for name in FOUND
        seconds = @elapsed include(joinpath(TEST_ROOT, name, "runtests.jl"))
        push!(ELAPSED, (name, seconds))
    end
end
