# The oracle runner: src/Oracles/run.jl, docs/plans/fiddlybits-52v.8-oracles.md,
# section "The runner".
#
# Every control is run against the accepted twin beside it: an unregistered fixture
# entry handed a model result and the same entry handed a Fixture; a payload
# representing every named manifest and one that does not; a payload hash a manifest
# carries and one that differs by one byte.

module Runner

using Test
using Fiddlybits: Oracles, Verdicts, Events

"A tier 2 entry: `verdict_kind`, its bar and uncertainty (`nothing` for a report
entry), the manifest ids it names in `datasets`, and whether it is registered."
function tier2_entry(; verdict_kind::AbstractString = "fail_bar", datasets = String[],
                     bar = 2.0, uncertainty = 1.0, registered_at = "")
    barred = verdict_kind == "report"
    return Oracles.Entry("earth.fixture_mean", 2, "atmosphere", "a fixture product", "known quantity",
                        "global-mean fixture flux against the product", verdict_kind,
                        "the published residual of the fixture model", true, registered_at, false,
                        ["A read work"], nothing, nothing, datasets, nothing, nothing,
                        barred ? nothing : bar, barred ? nothing : uncertainty, "fixture.toml")
end

"A tier 3 report entry naming no bar, reading no dataset unless `datasets` is given."
tier3_entry(; datasets = String[]) = Oracles.Entry(
    "sweep.fixture_rotation", 3, "dynamics", "a fixture sweep", "published spread",
    "fixture cell edge against rotation rate swept", "report", "the published studies are the reference",
    true, "", false, ["A read work"], nothing, nothing, datasets, nothing, nothing, nothing, nothing,
    "fixture.toml")

"A tier 1 identity entry naming no dataset and no numeric bar."
tier1_entry() = Oracles.Entry(
    "mesh.fixture_identity", 1, "mesh", "identity", "identity",
    "sum of fixture cell areas against the sphere", "fail_bar", "roundoff", true, "", false, String[],
    nothing, nothing, nothing, nothing, nothing, nothing, nothing, "fixture.toml")

"A `Payload` with `value`, `reference`, and `hashes`, empty by default."
payload(; value, reference, hashes = String[]) = Oracles.Payload(value = value, reference = reference, hashes = hashes)

"Writes a manifest at `dir/<id>.toml` naming `hashes` in `[[file]]` tables, and returns its directory."
function write_manifest(dir::AbstractString, id::AbstractString, hashes::Vector{String})
    mkpath(dir)
    open(joinpath(dir, id * ".toml"), "w") do io
        println(io, "id = \"", id, "\"")
        println(io, "oracles = [\"earth.fixture_mean\"]")
        for h in hashes
            println(io, "\n[[file]]")
            println(io, "sha256 = \"", h, "\"")
        end
    end
    return dir
end

"`run` on `entry` and `artifact`, with `oracle_data` and `input_data` defaulting to
directories holding no manifest."
function run_it(entry, artifact, dir; oracle_data = dir, input_data = dir, sequence = 1, instant = 0.0,
                tier = :test)
    return Oracles.run(entry, artifact; sequence = sequence, instant = instant, tier = tier,
                      oracle_data = oracle_data, input_data = input_data)
end

"The `Verdicts.Refusal` `f()` raises, or `nothing` when it returns."
function refusal(f)
    try
        f()
        return nothing
    catch e
        e isa Verdicts.Refusal || rethrow()
        return e
    end
end

@testset "run: a verdict is one of FAIL, REPORT and PASS; a boolean return is a type error" begin
    typed()::Verdicts.OracleVerdict = Verdicts.PASS()
    @test typed() isa Verdicts.OracleVerdict

    boolean()::Verdicts.OracleVerdict = true
    @test_throws MethodError boolean()

    mktempdir() do dir
        e = tier2_entry()
        for (case, p, expect) in (
            ("within the bar", payload(value = 1.0, reference = 0.0), Verdicts.PASS),
            ("outside the bar", payload(value = 10.0, reference = 0.0), Verdicts.FAIL),
        )
            v = run_it(e, Oracles.Fixture(p), dir)
            @test v isa Verdicts.OracleVerdict
            @test !(v isa Bool)
            @test v isa expect
        end
        report_v = run_it(tier3_entry(), Oracles.Fixture(payload(value = 1.0, reference = 0.9)), dir)
        @test report_v isa Verdicts.REPORT
    end
end

@testset "run: admits at its door" begin
    mktempdir() do dir
        e = tier2_entry()
        model_result = 3.5
        good = payload(value = 1.0, reference = 0.0)

        @testset "positive control: an unregistered entry handed a model result is refused its value and emits nothing" begin
            sink = Events.Collector{Events.Event}()
            Events.sink!(sink)
            @test_throws Verdicts.Refusal run_it(e, model_result, dir)
            @test_throws Verdicts.Refusal run_it(e, good, dir)
            @test isempty(Events.collected(sink))
            Events.sink!(Events.noop_sink)
        end

        @testset "the same entry handed a Fixture returns its verdict" begin
            v = run_it(e, Oracles.Fixture(good), dir)
            @test v isa Verdicts.PASS
        end
    end
end

@testset "run: every admitted run emits exactly one oracle journal event, counted with a Collector" begin
    mktempdir() do dir
        sink = Events.Collector{Events.Event}()
        Events.sink!(sink)
        e = tier2_entry()
        good = payload(value = 1.0, reference = 0.0)

        n = 3
        for i in 1:n
            run_it(e, Oracles.Fixture(good), dir; sequence = i)
        end
        log = Events.collected(sink)
        @test length(log) == n
        for (i, ev) in enumerate(log)
            @test ev.header.kind isa Events.Oracle
            @test ev.header.sequence == i
            @test ev.payload.registry_id == e.id
            @test ev.payload.verdict isa Verdicts.PASS
        end
        Events.sink!(Events.noop_sink)
    end
end

@testset "run: the distance report carries the reference's own uncertainty and the distance in units of it" begin
    e = tier2_entry(bar = 2.0, uncertainty = 0.5)
    p = payload(value = 1.5, reference = 1.0)
    result = Oracles.judge(e, p)
    @test result.uncertainty == 0.5
    @test Oracles.distance(result) == 0.5
    @test Oracles.in_uncertainty(result) == 1.0
    text = Oracles.report([result])
    @test occursin("0.5", text)
    @test occursin("1.0", text)
    @test occursin("PASS", text)

    @testset "a Result with no uncertainty prints n/a" begin
        no_bar = Oracles.judge(tier3_entry(), payload(value = 1.0, reference = 0.9))
        @test no_bar.uncertainty === nothing
        @test Oracles.in_uncertainty(no_bar) === nothing
        @test occursin("n/a", Oracles.report([no_bar]))
    end
end

@testset "run: a payload's hashes are resolved through its datasets manifests" begin
    mktempdir() do dir
        good_hash = "a" ^ 64
        other_hash = "c" ^ 64
        write_manifest(dir, "fixture-manifest", [good_hash])
        write_manifest(dir, "fixture-manifest-2", [other_hash])
        e = tier2_entry(datasets = ["fixture-manifest"])
        two = tier2_entry(datasets = ["fixture-manifest", "fixture-manifest-2"])

        @testset "the accepted twin: a payload hash the manifest carries is admitted" begin
            p = payload(value = 1.0, reference = 0.0, hashes = [good_hash])
            @test run_it(e, Oracles.Fixture(p), dir; oracle_data = dir, input_data = dir) isa Verdicts.OracleVerdict
        end

        @testset "the accepted twin: a payload representing every named manifest is admitted" begin
            p = payload(value = 1.0, reference = 0.0, hashes = [good_hash, other_hash])
            @test run_it(two, Oracles.Fixture(p), dir; oracle_data = dir, input_data = dir) isa Verdicts.OracleVerdict
        end

        @testset "positive control: a payload with one byte changed is refused" begin
            changed = "b" * good_hash[2:end]
            p = payload(value = 1.0, reference = 0.0, hashes = [changed])
            err = refusal(() -> run_it(e, Oracles.Fixture(p), dir; oracle_data = dir, input_data = dir))
            @test err isa Verdicts.Refusal && occursin("not among the hashes of its datasets manifests", err.reason)
        end

        @testset "positive control: a dataset id resolving to no manifest is refused" begin
            absent = tier2_entry(datasets = ["absent-manifest"])
            p = payload(value = 1.0, reference = 0.0, hashes = [good_hash])
            err = refusal(() -> run_it(absent, Oracles.Fixture(p), dir; oracle_data = dir, input_data = dir))
            @test err isa Verdicts.Refusal && occursin("found under neither", err.reason)
        end

        @testset "positive control: an entry naming datasets and a payload with no hashes is refused" begin
            p = payload(value = 1.0, reference = 0.0)
            err = refusal(() -> run_it(e, Oracles.Fixture(p), dir; oracle_data = dir, input_data = dir))
            @test err isa Verdicts.Refusal && occursin("names datasets and carries no hash", err.reason)
        end

        @testset "positive control: a named manifest none of whose hashes appear in the payload is refused" begin
            p = payload(value = 1.0, reference = 0.0, hashes = [good_hash])
            err = refusal(() -> run_it(two, Oracles.Fixture(p), dir; oracle_data = dir, input_data = dir))
            @test err isa Verdicts.Refusal && occursin("none of whose hashes appear in the payload", err.reason)
        end

        @testset "positive control: an entry naming no dataset and a payload carrying a hash is refused" begin
            no_datasets = tier2_entry(datasets = String[])
            p = payload(value = 1.0, reference = 0.0, hashes = [good_hash])
            err = refusal(() -> run_it(no_datasets, Oracles.Fixture(p), dir; oracle_data = dir, input_data = dir))
            @test err isa Verdicts.Refusal && occursin("this entry names no manifest in datasets", err.reason)
        end
    end
end

@testset "run: an entry with no numeric bar is REPORT regardless of verdict_kind" begin
    mktempdir() do dir
        v = run_it(tier1_entry(), Oracles.Fixture(payload(value = 0.0, reference = 0.0)), dir)
        @test v isa Verdicts.REPORT
    end
end

@testset "run: an artifact that is neither a Fixture nor a Payload is refused" begin
    mktempdir() do dir
        e = tier2_entry(registered_at = "")
        @test_throws Verdicts.Refusal run_it(e, Oracles.Fixture("not a payload"), dir)
    end
end

@testset "run: every Payload keyword is required" begin
    @test_throws UndefKeywordError Oracles.Payload(reference = 0.0, hashes = String[])
    @test_throws UndefKeywordError Oracles.Payload(value = 0.0, hashes = String[])
    @test_throws UndefKeywordError Oracles.Payload(value = 0.0, reference = 0.0)
end

end # module Runner
