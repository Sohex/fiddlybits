using Test
using TOML: TOML
using CUDA: CUDA
using Fiddlybits: Fiddlybits, Provenance, Events, Verdicts, Coupling, Backends, Mesh, Time

# provenance.run_opens_through_one_door and the run door of
# docs/plans/fiddlybits-52v.6-provenance.md, sections "The store" and "The journal";
# decisions 0010, 0042 and 0046; the ordering rule fiddlybits-52v.6.17's notes carry.

isdefined(@__MODULE__, :StoreFixtures) || include(joinpath(@__DIR__, "..", "io", "store_fixtures.jl"))
import .StoreFixtures as ST
import .SystemFixtures as SF

"A component whose declaration is `declaration`, and nothing else."
struct Orphan
    declaration::Coupling.Declaration
end

Coupling.declare(o::Orphan) = o.declaration

"An `Orphan` reading `:ghost` at `ST.level()` through `AtLevel`, over no measure, which
nothing writes and no initial condition places, so `Coupling.assemble` refuses it."
orphan() = Orphan(Coupling.Declaration(
    name = :orphan, level = ST.level(),
    reads = (Coupling.Read(quantity = :ghost, level = ST.level(),
                           operator = Coupling.AtLevel(measure = Coupling.NoMeasure()),
                           lagged = false, move = false),),
    writes = (), stocks = (), system_fields = (), profile_fields = (), backend = Backends.CPU()))

"Refuses assembling `orphan()` alone, numbered `sequence`."
refuse_orphan(sequence) = Coupling.assemble(orphan(); initial_conditions = (), sequence = sequence,
                                            instant = 0.0, tier = :fast)

"What calling `f` raises, or `nothing`."
caught(f) = try
    f()
    nothing
catch err
    err
end

@testset "provenance.run_opens_through_one_door" begin
    mktempdir() do root
        store = Provenance.Store(root = root)
        run = Provenance.mint_run_id()
        code = ST.code()
        system = SF.system()
        file() = joinpath(Provenance.run_directory(store, run), Provenance.JOURNAL_PATH)

        @testset "positive control: a refusal raised before the door opens the run leaves no journal to hold it" begin
            Events.sink!(Events.noop_sink)
            pre = caught(() -> refuse_orphan(1))
            @test pre isa Verdicts.Refusal
            @test !ispath(file())
        end

        @testset "the door writes the run record, then installs the journal, and returns what the run needs" begin
            ctx = Provenance.start_run!(store; run = run, code = code, system = system)
            @test ctx isa Provenance.RunContext
            @test ctx.run === run && ctx.code === code
            @test Events.SINK[] === ctx.journal
            @test isfile(file()) && isempty(Provenance.read_journal(file()))
            record = TOML.parsefile(joinpath(Provenance.run_directory(store, run), Provenance.RUN_RECORD))
            @test record["run"] == string(run.uuid)
        end

        @testset "a refusal raised after the door opens the run is journalled" begin
            post = caught(() -> refuse_orphan(2))
            @test post isa Verdicts.Refusal
            records = Provenance.read_journal(file())
            @test length(records) == 1
            @test only(records)["kind"] == "refusal"
        end

        @testset "a second open of the same run refuses, and the first run's record and journal are left intact" begin
            record_before = TOML.parsefile(joinpath(Provenance.run_directory(store, run), Provenance.RUN_RECORD))
            journal_before = Provenance.read_journal(file())

            e = caught(() -> Provenance.start_run!(store; run = run, code = code, system = system))
            @test e isa Verdicts.Refusal && e.quantity == "run"

            @test TOML.parsefile(joinpath(Provenance.run_directory(store, run), Provenance.RUN_RECORD)) == record_before
            @test Provenance.read_journal(file()) == journal_before

            @testset "positive control: a fresh run under the same store is admitted" begin
                other = Provenance.mint_run_id()
                ctx = Provenance.start_run!(store; run = other, code = code, system = system)
                @test ctx isa Provenance.RunContext
            end
        end

        Events.sink!(Events.noop_sink)
    end
end

# provenance.run_record_carries_move_tally: the run door of
# docs/plans/fiddlybits-52v.6-provenance.md, sections "The writer" and "The journal";
# decisions 0010, 0042 and 0046; fiddlybits-52v.6.11.

"The record of `run` in `store`, parsed."
run_record(store, run) = TOML.parsefile(joinpath(Provenance.run_directory(store, run), Provenance.RUN_RECORD))

"The tally a parsed run record holds under `Provenance.MOVES_KEY`, as `Events.move_counts` returns one."
recorded_moves(record) = Dict{Tuple{Symbol,Symbol},Int}(
    (Symbol(from), Symbol(to)) => n for (from, tos) in record[Provenance.MOVES_KEY] for (to, n) in tos)

"A store at `root` holding the fixture support at chunk level one."
function supported(root)
    store = Provenance.Store(root = root)
    m = ST.mesh()
    Provenance.put_support!(store; support = m.support, level = m.level, geometry = m.geometry, chunk_level = 1)
    return store, m
end

"""
    fixture_run(store, run; reads)

A run `run` opened through `Provenance.start_run!` in `store`: a refusal journalled, one
array staged on `Backends.GPU`, `reads` reads of it back through `Backends.on`, a second
refusal journalled, then `Provenance.close_run!`. Returns `(counted, record, lines)`:
`Events.move_counts()` before the close, the parsed run record after it, and the count
of journal records.
"""
function fixture_run(store, run; reads)
    ctx = Provenance.start_run!(store; run = run, code = ST.code(), system = SF.system())
    caught(() -> refuse_orphan(1))
    staged = Backends.on(collect(1.0:8.0), Backends.GPU())
    for _ in 1:reads
        Backends.on(staged, Backends.CPU())
    end
    caught(() -> refuse_orphan(2))
    counted = Events.move_counts()
    Provenance.close_run!(ctx)
    lines = length(Provenance.read_journal(joinpath(Provenance.run_directory(store, run), Provenance.JOURNAL_PATH)))
    Events.sink!(Events.noop_sink)
    return counted, run_record(store, run), lines
end

"The `.jl` files under `root` naming `reset_move_counts!(` or `move_counts(`, relative to `root`, other than `Events/Events.jl`, sorted."
function tally_callers(root::AbstractString)
    found = String[]
    pattern = r"(?<![A-Za-z0-9_])(?:reset_move_counts!|move_counts)\("
    for (dir, _, files) in walkdir(root), f in files
        endswith(f, ".jl") || continue
        path = relpath(joinpath(dir, f), root)
        path == joinpath("Events", "Events.jl") && continue
        occursin(pattern, read(joinpath(dir, f), String)) && push!(found, path)
    end
    return sort!(found)
end

@testset "provenance.run_record_carries_move_tally" begin
    @test CUDA.functional()

    @testset "a run opened through the door starts with an empty tally, whatever was counted before it" begin
        mktempdir() do root
            store, _ = supported(root)
            Backends.on(Backends.on([1.0, 2.0], Backends.GPU()), Backends.CPU())
            @testset "positive control: the moves before the door are counted" begin
                @test Events.move_counts()[(:cpu, :gpu)] >= 1
                @test Events.move_counts()[(:gpu, :cpu)] >= 1
            end
            Provenance.start_run!(store; run = Provenance.mint_run_id(), code = ST.code(), system = SF.system())
            @test isempty(Events.move_counts())
            Events.sink!(Events.noop_sink)
        end
    end

    @testset "a refused open leaves the tally as it was" begin
        mktempdir() do root
            store, _ = supported(root)
            run = Provenance.mint_run_id()
            Provenance.start_run!(store; run = run, code = ST.code(), system = SF.system())
            Backends.on([1.0], Backends.GPU())
            e = caught(() -> Provenance.start_run!(store; run = run, code = ST.code(), system = SF.system()))
            @test e isa Verdicts.Refusal && e.quantity == "run"
            @test Events.move_counts() == Dict((:cpu, :gpu) => 1)
            Events.sink!(Events.noop_sink)
        end
    end

    @testset "the record of a fixture run carries the tally it ended with, keyed by direction" begin
        mktempdir() do root
            store, _ = supported(root)
            few_run, many_run = Provenance.mint_run_id(), Provenance.mint_run_id()
            few, few_record, few_lines = fixture_run(store, few_run; reads = 2)
            many, many_record, many_lines = fixture_run(store, many_run; reads = 9)

            @test few == Dict((:cpu, :gpu) => 1, (:gpu, :cpu) => 2)
            @test many == Dict((:cpu, :gpu) => 1, (:gpu, :cpu) => 9)
            @test recorded_moves(few_record) == few
            @test recorded_moves(many_record) == many
            @test many_record[Provenance.MOVES_KEY]["gpu"]["cpu"] > few_record[Provenance.MOVES_KEY]["gpu"]["cpu"]
            @test many_record[Provenance.MOVES_KEY]["cpu"]["gpu"] == few_record[Provenance.MOVES_KEY]["cpu"]["gpu"]
            @test few_lines == many_lines == 2
            @test all(r -> r["kind"] == "refusal",
                      Provenance.read_journal(joinpath(Provenance.run_directory(store, many_run), Provenance.JOURNAL_PATH)))

            @testset "every other key of the record is the one open_run! wrote" begin
                @test delete!(copy(many_record), Provenance.MOVES_KEY) ==
                      Dict("run" => string(many_run.uuid), "code" => Provenance.code_record(ST.code()),
                           "system" => Provenance.record_value(SF.system()))
            end
        end
    end

    @testset "a run with no moves closes with an empty tally, and an open run holds none" begin
        mktempdir() do root
            store, _ = supported(root)
            run = Provenance.mint_run_id()
            ctx = Provenance.start_run!(store; run = run, code = ST.code(), system = SF.system())
            @test !haskey(run_record(store, run), Provenance.MOVES_KEY)
            Provenance.close_run!(ctx)
            @test run_record(store, run)[Provenance.MOVES_KEY] == Dict{String,Any}()
            Events.sink!(Events.noop_sink)
        end
    end

    @testset "close_run! refuses a run already closed, and one whose tally a later open emptied" begin
        mktempdir() do root
            store, _ = supported(root)
            first_ctx = Provenance.start_run!(store; run = Provenance.mint_run_id(), code = ST.code(), system = SF.system())
            Backends.on([1.0], Backends.GPU())
            later = Provenance.start_run!(store; run = Provenance.mint_run_id(), code = ST.code(), system = SF.system())
            before = run_record(store, first_ctx.run)
            e = caught(() -> Provenance.close_run!(first_ctx))
            @test e isa Verdicts.Refusal && e.quantity == "run" && occursin("tally", e.reason)
            @test run_record(store, first_ctx.run) == before

            @testset "positive control: the later run closes" begin
                @test Provenance.close_run!(later) === nothing
                @test recorded_moves(run_record(store, later.run)) == Dict{Tuple{Symbol,Symbol},Int}()
            end

            closed = run_record(store, later.run)
            e = caught(() -> Provenance.close_run!(later))
            @test e isa Verdicts.Refusal && e.quantity == "run" && occursin("already closed", e.reason)
            @test run_record(store, later.run) == closed
            Events.sink!(Events.noop_sink)
        end
    end

    @testset "the tally is in no content key, and a run's moves change no artifact" begin
        e = caught(() -> Provenance.canonical_bytes(Events.move_counts()))
        @test e isa Verdicts.Refusal && e.quantity == "canonical serialisation"
        m = ST.mesh()
        given = (code = ST.code(), declaration = ST.declaration(), system = SF.system(), profile = ST.profile(),
                 inputs = NamedTuple(), quantity = :surface_mass, support = m.support,
                 interval = Time.interval(ST.interval()), operator_version = 1)
        e = caught(() -> Provenance.ArtifactKey(; given..., moves = Events.move_counts()))
        @test e isa Verdicts.Refusal && e.quantity == "moves"

        @testset "positive control: the same keywords without the tally give a key" begin
            @test Provenance.ArtifactKey(; given...) isa Provenance.ArtifactKey
        end

        run = Provenance.mint_run_id()
        data = [1.0 + 0.5 * sin(0.3 * i) for i in 1:Mesh.ncells(ST.level())]
        "The store at `root` after `run` put the fixture field, `reads` reads of a device array before it."
        function written(root, reads)
            store, sm = supported(root)
            ctx = Provenance.start_run!(store; run = run, code = ST.code(), system = SF.system())
            staged = Backends.on(data, Backends.GPU())
            for _ in 1:reads
                Backends.on(staged, Backends.CPU())
            end
            key, _ = ST.put(store, run, ST.field(sm.support, run, copy(data)))
            Provenance.close_run!(ctx)
            Events.sink!(Events.noop_sink)
            return store, key
        end
        "Every file under `dir`, relative to it, with its bytes."
        tree(dir) = Dict(relpath(joinpath(d, f), dir) => read(joinpath(d, f)) for (d, _, fs) in walkdir(dir) for f in fs)
        mktempdir() do quiet_root
            mktempdir() do busy_root
                quiet, quiet_key = written(quiet_root, 0)
                busy, busy_key = written(busy_root, 5)
                @test quiet_key == busy_key
                @test tree(joinpath(quiet_root, Provenance.OBJECTS)) == tree(joinpath(busy_root, Provenance.OBJECTS))
                @test !isempty(tree(joinpath(quiet_root, Provenance.OBJECTS)))

                @testset "positive control: the two run records differ, and only in their tallies" begin
                    q, b = run_record(quiet, run), run_record(busy, run)
                    @test q != b
                    @test recorded_moves(b)[(:gpu, :cpu)] == 5
                    @test delete!(q, Provenance.MOVES_KEY) == delete!(b, Provenance.MOVES_KEY)
                end
            end
        end
    end

    @testset "src empties and reads the tally only at the run door" begin
        src = joinpath(pkgdir(Fiddlybits), "src")
        @test tally_callers(src) == [joinpath("Provenance", "run.jl")]

        @testset "positive control: a second reader or resetter beside the door is reported" begin
            mktempdir() do root
                for (path, text) in ((joinpath("Provenance", "run.jl"), read(joinpath(src, "Provenance", "run.jl"), String)),
                                     (joinpath("Coupling", "tap.jl"), "tap() = Events.move_counts()\n"),
                                     (joinpath("Fields", "tap.jl"), "tap!() = Events.reset_move_counts!()\n"),
                                     (joinpath("Events", "Events.jl"), "move_counts() = nothing\n"))
                    mkpath(dirname(joinpath(root, path)))
                    write(joinpath(root, path), text)
                end
                @test tally_callers(root) ==
                      sort([joinpath("Coupling", "tap.jl"), joinpath("Fields", "tap.jl"), joinpath("Provenance", "run.jl")])
            end
        end
    end
end
