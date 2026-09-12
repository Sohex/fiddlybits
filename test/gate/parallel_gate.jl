using Test

# The driver that runs the suites as concurrent processes: tools/gate/run.jl, and
# the discovery it shares with test/runtests.jl. What is checked here is the
# schedule, not the suites: a stub runner stands in for the process, so the claims
# below cost nothing to assert and do not depend on what any suite does.
#
# notes/findings/2026-09-12-the-gate-in-parallel.md carries the wall times.

const GATE_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

# The driver is loaded into a module of its own rather than into `Main`. It includes
# `test/suites.jl`, and so does `test/runtests.jl`, which runs this file: loading both
# into one namespace would define `suites` twice, which is the one thing the shared
# file exists to prevent.
module GateDriver
include(joinpath(normpath(joinpath(@__DIR__, "..", "..")), "tools", "gate", "run.jl"))
end

using .GateDriver: worker_count, run_suites, report

# `suites` stays qualified. `test/runtests.jl` has its own binding for it when it is
# the door running this file, and importing a second one would be shadowed in silence.

@testset "gate.parallel_driver" begin
    @testset "the worker count is stated, never inferred" begin
        @test worker_count(["8"]) == 8
        @test worker_count(["1"]) == 1
        @test_throws ErrorException worker_count(String[])
        @test_throws ErrorException worker_count(["8", "9"])
        @test_throws ErrorException worker_count(["0"])
        @test_throws ErrorException worker_count(["-2"])
        @test_throws ErrorException worker_count(["eight"])

        @testset "the refusal says what to pass instead" begin
            caught = try
                worker_count(String[])
            catch e
                e
            end
            @test occursin("SLURM_CPUS_PER_TASK", caught.msg)
        end
    end

    @testset "the suite set is what the worker count cannot change" begin
        names = ["alpha", "beta", "gamma", "delta", "epsilon"]
        for workers in (1, 2, 5, 97)
            seen = String[]
            guard = ReentrantLock()
            results = run_suites(names, workers, function (name)
                lock(guard) do
                    push!(seen, name)
                end
                return true
            end)
            @test sort(seen) == sort(names)
            @test length(seen) == length(names)
            @test [r[1] for r in results] == names
            @test all(r[2] for r in results)
        end
    end

    @testset "a suite's verdict is its own, whatever order they finish in" begin
        names = ["slow", "quick", "alsoslow"]
        # The failing suite is the one that finishes first, so a driver that read the
        # first result as the run's result would call this run a failure early and a
        # driver that read the last would miss it.
        results = run_suites(names, 3, function (name)
            name == "quick" && return false
            sleep(0.2)
            return true
        end)
        @test [r[1] for r in results] == names
        @test [r[2] for r in results] == [true, false, true]
    end

    @testset "the run's status is the worst of its suites" begin
        logdir = mktempdir()
        allpass = [("a", true, 1.0), ("b", true, 2.0)]
        onefails = [("a", true, 1.0), ("b", false, 2.0)]
        write(joinpath(logdir, "b.log"), "what b printed")
        @test report(allpass, logdir, 2.0) == 0
        @test report(onefails, logdir, 2.0) == 1
    end

    @testset "both doors discover the same suites" begin
        found, missing = GateDriver.suites(joinpath(GATE_ROOT, "test"))
        @test isempty(missing)
        @test "certify" in found
        @test "gate" in found
        @test !("fixtures" in found)
        @test found == sort(found)

        @testset "positive control: a directory without an entry point is named" begin
            scratch = mktempdir()
            mkdir(joinpath(scratch, "withentry"))
            touch(joinpath(scratch, "withentry", "runtests.jl"))
            mkdir(joinpath(scratch, "without"))
            f, m = GateDriver.suites(scratch)
            @test f == ["withentry"]
            @test m == ["without"]
        end
    end
end
