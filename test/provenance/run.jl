using Test
using TOML: TOML
using Fiddlybits: Fiddlybits, Provenance, Events, Verdicts, Coupling, Backends

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
