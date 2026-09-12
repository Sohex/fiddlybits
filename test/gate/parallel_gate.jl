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

using .GateDriver: worker_count, run_suites, report, suite_command,
                   accepted_warnings, unaccepted_warnings, SUITE_FLAGS

# `suites` stays qualified. `test/runtests.jl` has its own binding for it when it is
# the door running this file, and importing a second one would be shadowed in silence.

"""
    quiet(f)

Run `f` with stdout discarded. `report` prints, and what it prints here includes a
warning line built for the test; under the gate that would land in this suite's own
log, where the gate's warning scan reads it.
"""
quiet(f) = redirect_stdout(f, devnull)

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
        @test quiet(() -> report(allpass, logdir, 2.0)) == 0
        @test quiet(() -> report(onefails, logdir, 2.0)) == 1
    end

    @testset "a suite process carries the flags that make it report" begin
        cmd = suite_command(GATE_ROOT, "events", 4)
        for flag in ("--warn-overwrite=yes", "--depwarn=yes")
            @test flag in cmd.exec
            @test flag in SUITE_FLAGS.exec
        end

        @testset "and not the one that changes what is compiled" begin
            @test !any(startswith(a, "--check-bounds") for a in cmd.exec)
        end
    end

    @testset "a warning the record does not accept refuses the run" begin
        accepted = accepted_warnings(GATE_ROOT)
        # A neutral name, not the one the row was raised by: this file would then be
        # a caller of it as far as build.one_definition_per_helper's text scan can
        # tell, and a quotation is not a call.
        overwritten = "WARNING: Method definition answer() in module " *
                      "Main at a.jl:15 overwritten at b.jl:15."
        official = "\u250c Warning: You are using a non-official build of Julia. " *
                   "This may cause issues with CUDA.jl."

        @testset "every accepted entry says what it accepts and why" begin
            @test !isempty(accepted)
            for (pattern, reason) in accepted
                @test !isempty(pattern)
                @test !isempty(reason)
            end

            @testset "positive control: an entry with no reason is refused" begin
                bare = joinpath(GATE_ROOT, "test", "gate", "fixtures", "warnings_no_reason")
                @test_throws ErrorException accepted_warnings(bare)
            end

            @testset "positive control: no record at all is refused, naming the path" begin
                caught = try
                    accepted_warnings(mktempdir())
                catch e
                    e
                end
                @test caught isa ErrorException
                @test occursin("warnings.toml", caught.msg)
            end
        end

        @testset "the scan reads the head of a warning and not its detail" begin
            text = join(["a passing line", overwritten, official,
                         "\u2502 detail nobody scans", "\u2514 @ CUDACore x.jl:1"], "\n")
            @test unaccepted_warnings(text, accepted) == [overwritten]
        end

        @testset "clean control: an accepted warning alone is not a refusal" begin
            @test isempty(unaccepted_warnings(official, accepted))
        end

        @testset "a run whose suites all pass still refuses on the warning" begin
            logdir = mktempdir()
            passed = [("a", true, 1.0), ("b", true, 2.0)]
            write(joinpath(logdir, "a.log"), official * "\nall good\n")
            write(joinpath(logdir, "b.log"), official * "\n" * overwritten * "\n")
            @test quiet(() -> report(passed, logdir, 2.0; accepted = accepted)) == 1

            @testset "positive control: the same run without the warning passes" begin
                write(joinpath(logdir, "b.log"), official * "\nall good\n")
                @test quiet(() -> report(passed, logdir, 2.0; accepted = accepted)) == 0
            end
        end
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
