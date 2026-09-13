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

using .NightlyDriver: subject, write_record, EXTRA_FLAGS

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
    @testset "the warm-up and the suites are precompiled the same way" begin
        # Julia caches per configuration. A warm-up under different flags warms a
        # cache nothing reads, every worker precompiles after all, and the suite that
        # asserts an image exists fails on the configuration it is running in. That
        # is what the bed's own first run against main found.
        gate = NightlyDriver.Gate
        warm = gate.warm_command(NIGHTLY_ROOT; extra = EXTRA_FLAGS)
        suite = gate.suite_command(NIGHTLY_ROOT, "events", 4; extra = EXTRA_FLAGS)

        @test !isempty(EXTRA_FLAGS.exec)
        for flag in EXTRA_FLAGS.exec
            @test flag in warm.exec
            @test flag in suite.exec
        end

        @testset "positive control: the flags are absent when they are not passed" begin
            bare = gate.warm_command(NIGHTLY_ROOT)
            @test !any(f in bare.exec for f in EXTRA_FLAGS.exec)
        end
    end

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

    @testset "every elision in src/ is an @inbounds inside a @kernel body (decision 0055)" begin
        # Gate.elision_sites reads the parsed source; a site is admitted when it is an
        # @inbounds and sits inside a @kernel call, and refused otherwise, which
        # includes @kernel inbounds=true and Expr(:inbounds) built in code.
        refused(text) = [s for s in NightlyDriver.Gate.elision_sites(text)
                         if !(s[2] == "@inbounds" && s[3])]
        fixture(name) = read(joinpath(@__DIR__, "fixtures", name), String)

        sources = String[]
        for (dir, _, names) in walkdir(joinpath(NIGHTLY_ROOT, "src")), name in names
            endswith(name, ".jl") && push!(sources, joinpath(dir, name))
        end
        @test !isempty(sources)
        outside = [(relpath(f, NIGHTLY_ROOT), s) for f in sources for s in refused(read(f, String))]
        @test isempty(outside)

        @testset "positive control: an @inbounds in host code is refused" begin
            sites = refused(fixture("inbounds_outside_kernel.jl"))
            @test length(sites) == 1
            @test sites[1][2] == "@inbounds"
            @test !sites[1][3]
        end

        @testset "positive control: a @kernel given inbounds=true is refused" begin
            sites = refused(fixture("kernel_inbounds_true.jl"))
            @test length(sites) == 1
            @test sites[1][2] == "@kernel inbounds=true"
        end

        @testset "clean control: an @inbounds inside a kernel body, plain and through @eval, is admitted" begin
            text = fixture("inbounds_inside_kernel.jl")
            @test length(NightlyDriver.Gate.elision_sites(text)) == 2
            @test isempty(refused(text))
        end
    end

    @testset "the subject is main with a clean tree, or it refuses" begin
        # Every scratch repository is made through git_at, and every control runs twice:
        # with GIT_DIR unset, and with GIT_DIR naming a second scratch repository, the
        # way a git hook run from a worktree exports it.
        git_at = NightlyDriver.git_at
        make_repo(dir, branch) = run(pipeline(git_at(dir, `init -q -b $(branch)`); stdout = devnull))
        commit_empty(dir) =
            run(pipeline(git_at(dir, `-c user.email=t@t -c user.name=t commit -q --allow-empty -m x`);
                         stdout = devnull))

        pointed = mktempdir()
        make_repo(pointed, "pushing")
        commit_empty(pointed)
        pointed_head = read(git_at(pointed, `rev-parse HEAD`), String)
        pointed_config = read(joinpath(pointed, ".git", "config"), String)

        for (arm, gitdir) in (("GIT_DIR unset", nothing),
                              ("GIT_DIR naming another repository", joinpath(pointed, ".git")))
            @testset "$arm" begin
                withenv("GIT_DIR" => gitdir) do
                    @testset "positive control: a checkout that is not main is refused" begin
                        scratch = mktempdir()
                        make_repo(scratch, "elsewhere")
                        commit_empty(scratch)
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
                        make_repo(scratch, "main")
                        commit_empty(scratch)
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
                        make_repo(scratch, "main")
                        commit_empty(scratch)
                        branch, sha = subject(scratch)
                        @test branch == "main"
                        @test sha == strip(read(git_at(scratch, `rev-parse HEAD`), String))
                    end
                end
            end
        end

        @testset "the repository GIT_DIR named is where it was" begin
            @test read(git_at(pointed, `rev-parse HEAD`), String) == pointed_head
            @test read(joinpath(pointed, ".git", "config"), String) == pointed_config
        end

        @testset "positive control: git -C alone follows GIT_DIR" begin
            # Without this the second arm above would also pass in an environment where
            # GIT_DIR had no effect on git -C, and would say nothing about git_at.
            scratch = mktempdir()
            make_repo(scratch, "main")
            commit_empty(scratch)
            followed = withenv("GIT_DIR" => joinpath(pointed, ".git")) do
                strip(read(`git -C $(scratch) rev-parse --abbrev-ref HEAD`, String))
            end
            @test followed == "pushing"
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
