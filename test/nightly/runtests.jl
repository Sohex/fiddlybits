using Test

# nightly.subject_is_main and nightly.bounds_are_checked: the bed of decision 0043,
# which runs what is too slow per commit. Decision 0050 says why --check-bounds=yes is
# here and not on the gate.
#
# The driver is loaded into a module of its own rather than into Main. It includes
# tools/gate/run.jl, which includes test/suites.jl, and so does test/runtests.jl:
# loading them into one namespace would define suites twice.

const NIGHTLY_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

module NightlyDriver
include(joinpath(normpath(joinpath(@__DIR__, "..", "..")), "tools", "nightly", "run.jl"))
end

using .NightlyDriver: subject, write_record

"""
    run_fixture(flags)

`(ok, stderr)` for the out-of-range fixture under `flags`, in a fresh copy of the
`julia` running this suite.
"""
function run_fixture(flags::Cmd)
    fixture = joinpath(@__DIR__, "fixtures", "unchecked_read.jl")
    errfile = tempname()
    ok = try
        run(pipeline(`$(Base.julia_cmd()) --startup-file=no $(flags) -e $("include(raw\"" * fixture * "\")")`;
                     stdout = devnull, stderr = errfile))
        true
    catch
        false
    end
    text = isfile(errfile) ? read(errfile, String) : ""
    isfile(errfile) && rm(errfile)
    return ok, text
end

@testset "nightly" begin
    @testset "the flag catches a fault the gate's configuration does not" begin
        @testset "under the gate's configuration the read stands" begin
            ok, _ = run_fixture(`--check-bounds=auto`)
            @test ok
        end

        @testset "under the nightly's it raises, naming the bound" begin
            ok, err = run_fixture(`--check-bounds=yes`)
            @test !ok
            @test occursin("BoundsError", err)
        end
    end

    @testset "the tree no longer elides a check of its own" begin
        # The seven annotations in src/Mesh bought nothing measurable
        # (notes/findings/2026-09-12-what-seven-inbounds-annotations-buy.md), so the
        # shipped form is checked and the flag now only reaches dependencies.
        sources = String[]
        for (dir, _, names) in walkdir(joinpath(NIGHTLY_ROOT, "src")), name in names
            endswith(name, ".jl") && push!(sources, joinpath(dir, name))
        end
        @test !isempty(sources)
        elided = [f for f in sources if occursin("@inbounds", read(f, String))]
        @test isempty(elided)
    end

    @testset "the subject is main with a clean tree, or it refuses" begin
        @testset "positive control: a checkout that is not main is refused" begin
            scratch = mktempdir()
            run(pipeline(`git -C $(scratch) init -q -b elsewhere`; stdout = devnull))
            run(pipeline(`git -C $(scratch) -c user.email=t@t -c user.name=t commit -q --allow-empty -m x`;
                         stdout = devnull))
            caught = try
                subject(scratch)
            catch e
                e
            end
            @test caught isa ErrorException
            @test occursin("elsewhere", caught.msg)
        end

        @testset "positive control: a tree with changes in it is refused" begin
            scratch = mktempdir()
            run(pipeline(`git -C $(scratch) init -q -b main`; stdout = devnull))
            run(pipeline(`git -C $(scratch) -c user.email=t@t -c user.name=t commit -q --allow-empty -m x`;
                         stdout = devnull))
            write(joinpath(scratch, "untracked.txt"), "a change nobody committed")
            caught = try
                subject(scratch)
            catch e
                e
            end
            @test caught isa ErrorException
            @test occursin("untracked.txt", caught.msg)
        end

        @testset "clean control: main with nothing outstanding is the subject" begin
            scratch = mktempdir()
            run(pipeline(`git -C $(scratch) init -q -b main`; stdout = devnull))
            run(pipeline(`git -C $(scratch) -c user.email=t@t -c user.name=t commit -q --allow-empty -m x`;
                         stdout = devnull))
            branch, sha = subject(scratch)
            @test branch == "main"
            @test length(sha) == 40
        end
    end

    @testset "a night's record names its commit and every suite" begin
        dir = mktempdir()
        results = [("alpha", true, 1.5), ("beta", false, 2.25)]
        path = write_record(dir, "0" ^ 40, results, 3.0, 1)
        @test isfile(path)

        record = NightlyDriver.TOML.parsefile(path)
        @test record["commit"] == "0" ^ 40
        @test record["status"] == 1
        @test record["check_bounds"] == true
        @test [s["name"] for s in record["suite"]] == ["alpha", "beta"]
        @test [s["passed"] for s in record["suite"]] == [true, false]

        @testset "the name says which commit, and a rerun of it takes a counter" begin
            @test occursin("0" ^ 12, basename(path))

            again = write_record(dir, "0" ^ 40, results, 3.0, 0)
            @test again != path
            other = write_record(dir, "1" ^ 40, results, 3.0, 0)
            @test occursin("1" ^ 12, basename(other))
            @test length(filter(endswith(".toml"), readdir(dir))) == 3
        end
    end
end
