using Test
using TOML
using Base: PkgId, UUID

# build.load_latency. The entry is provisional with no registered threshold, so this
# measures and reports and does not judge. Decision 0029 fixes a bar only once the
# A/A scatter of the measurement is a dated finding, and a bar narrower than its
# instrument's scatter is refused at registration. That scatter is
# notes/findings/2026-09-11-load-latency-instrument.md.
#
# The load is recorded beside the timing because the scheduler gives a job its cores,
# not the memory bandwidth around them.
#
# Three things are asserted rather than reported, because docs/imports/precompiletools.md
# names this entry as the leak check for all three: that no preference turns the
# workload off, that the package image the measurement loads exists, and that the
# workload landed in it.

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const FIXTURES = joinpath(@__DIR__, "fixtures")
const REPEATS = 5

const FIDDLYBITS = PkgId(UUID("67e34d3d-21be-49b5-9b36-49c5a60c5153"), "Fiddlybits")
const NOT_PRECOMPILED = PkgId(UUID("11111111-2222-3333-4444-555555555555"), "NotPrecompiled")

# PrecompileTools reads two switches: `precompile_workloads` under its own name, a
# global off, and `precompile_workload` under the package being precompiled.
const SWITCHES = (("PrecompileTools", "precompile_workloads"), ("Fiddlybits", "precompile_workload"))

"The workload switches `path` turns off, named `package.key`. An absent file turns none off."
function workload_off(path::AbstractString)
    isfile(path) || return String[]
    prefs = TOML.parsefile(path)
    return [string(pkg, ".", key) for (pkg, key) in SWITCHES
            if get(get(prefs, pkg, Dict{String, Any}()), key, true) === false]
end

"Wall time of `using Fiddlybits` in a fresh process, in milliseconds, `REPEATS` times."
function load_times()
    code = "t = @elapsed using Fiddlybits; print(t * 1000)"
    return [parse(Float64, read(`julia --startup-file=no --project=$ROOT -e $code`, String))
            for _ in 1:REPEATS]
end

host() = try chomp(read(`hostname`, String)) catch; "unknown" end
load1() = try parse(Float64, split(read("/proc/loadavg", String))[1]) catch; NaN end

@testset "build.load_latency" begin
    prefs = joinpath(ROOT, "LocalPreferences.toml")

    @testset "no preference turns the workload off" begin
        @test isempty(workload_off(prefs))

        # The dirty arm turns the per-package switch off; the clean arm is a
        # preferences file that exists and turns neither switch off, so the check is
        # shown to refuse the switch and not the file.
        @test workload_off(joinpath(FIXTURES, "prefs_off", "LocalPreferences.toml")) ==
              ["Fiddlybits.precompile_workload"]
        @test isempty(workload_off(joinpath(FIXTURES, "prefs_on", "LocalPreferences.toml")))
    end

    @testset "the package image the measurement loads exists" begin
        @test Base.isprecompiled(FIDDLYBITS)

        # The dirty arm is a package on the load path that nothing ever loads, so
        # nothing ever precompiles it.
        push!(LOAD_PATH, FIXTURES)
        try
            @test !Base.isprecompiled(NOT_PRECOMPILED)
        finally
            pop!(LOAD_PATH)
        end
    end

    @testset "the workload landed in the image" begin
        # A method the workload calls carries a specialization from the cache on a
        # fresh load. Verdicts.refuse is the control: the workload never calls it and
        # it must stay outside the workload for this arm to read both answers. This is
        # the arm that catches a workload which ran and threw, since PrecompileTools
        # reports that as a warning and lets the precompile continue.
        code = """
            using Fiddlybits
            V = Fiddlybits.Verdicts
            n(f) = sum(m -> length(Base.specializations(m)), methods(f))
            print(n(V.loop_verdicts), " ", n(V.oracle_verdicts), " ", n(V.refuse))
        """
        out = read(`julia --startup-file=no --project=$ROOT -e $code`, String)
        in_workload_a, in_workload_b, outside = parse.(Int, split(out))
        @test in_workload_a > 0
        @test in_workload_b > 0
        @test outside == 0
    end

    times = load_times()
    warm = times[2:end]

    @info "build.load_latency" host = host() load = load1() preferences = (isfile(prefs) ? "present" : "absent") first_ms = round(times[1], digits = 1) warm_ms = round.(warm, digits = 1) spread_ms = round(maximum(warm) - minimum(warm), digits = 1)

    # The measurement happened and is a measurement. No bar: the entry is provisional.
    @test length(times) == REPEATS
    @test all(isfinite, times)
    @test all(>(0), times)
end
