using Test
using Fiddlybits: Events, Verdicts, Reductions, Mesh

# The event vocabulary is closed by this check rather than by the language: a
# subtype added anywhere fails the suite until the enumeration and decision
# 0042 move together.
#
# `closed_set` and its fixture come from `test/closure.jl`, which Verdicts and Time
# read through the same guarded include.

isdefined(@__MODULE__, :VocabularyClosure) ||
    include(joinpath(@__DIR__, "..", "closure.jl"))
using .VocabularyClosure: closed_set, Fixture

# A separate hierarchy, not a subtype of Events.Kind, so exercising
# payload_type here cannot widen Events.kinds() and break its closure test.
module PayloadTypeFixture
    struct WithPayload end
    struct Missing end
end
Events.payload_type(::PayloadTypeFixture.WithPayload) = Int

# The refusal payload shape decision 0042 carried at its founding, the fixture the
# field comparison below must report as fabricating and losing fields.
module FoundingRefusalFixture
    struct RefusalPayload
        component::String
        refused::String
        quantity::Float64
        bound::Float64
    end
end

"""
    field_difference(P, R)

`(fabricated, lost)`: the `(name, type)` fields of `P` that `R` does not carry,
and the `(name, type)` fields of `R` that `P` does not carry.
"""
function field_difference(P::DataType, R::DataType)
    p = collect(zip(fieldnames(P), fieldtypes(P)))
    r = collect(zip(fieldnames(R), fieldtypes(R)))
    return (setdiff(p, r), setdiff(r, p))
end

"The `Verdicts.Refusal` that calling `f` raises."
function raised_refusal(f)
    try
        f()
    catch err
        err isa Verdicts.Refusal && return err
        rethrow()
    end
    error("no refusal was raised")
end

"A complete, valid keyword set for each payload, used where a test needs one
that constructs without refusing."
const VALID_PAYLOAD_ARGS = Dict(
    Events.VerdictPayload => (predicate = "FixedPointLoop", verdict = Verdicts.Converged(),
                               statistic = 0.5, bracket = (0.0, 1.0)),
    Events.RefusalPayload => (quantity = "eccentricity", site = "Systems.System",
                               reason = "outside the elliptic range [0, 1): 1.5"),
    Events.LedgerOpenPayload => (ledger = "heat", imbalance = 1.0e-3,
                                  tolerance = 1.0e-6, exchange = "surface flux"),
    Events.RefreshPayload => (trigger = "sea ice extent", field = "albedo",
                               change = 0.2, restart_seconds = 3600.0, restart_orbits = 0.1),
    Events.TopologyChangePayload => (edit = "seaway_closed", level = 1,
                                      cells = [Mesh.CellId(0), Mesh.CellId(1)], quantity = 4.0),
    Events.LevelChangePayload => (from = 3, to = 4, window = 86400.0),
    Events.ArtifactPayload => (key = "abc123", kind = "field", support = "L4"),
    Events.CheckpointPayload => (key = "abc123", precision = Float64),
    Events.OraclePayload => (registry_id = "mesh.area_closure", verdict = Verdicts.PASS(),
                              statistic = 1.0e-9, threshold = 1.0e-8),
    Events.BudgetPayload => (cap = 1.0e9, which = "memory"),
)

@testset "Events" begin
    @testset "the vocabulary is closed" begin
        @test closed_set(Events.Kind, Events.kinds()) == (Any[], Any[])
        @test length(Events.kinds()) == 10
    end

    @testset "positive control: an omitted subtype is reported" begin
        undeclared, unreachable = closed_set(Fixture.Colour, Fixture.partial())
        @test undeclared == [Fixture.Blue]
        @test isempty(unreachable)
        @test closed_set(Fixture.Colour, Fixture.whole()) == (Any[], Any[])
    end

    @testset "every kind has a payload struct" begin
        for kind in Events.kinds()
            payload_name = Symbol(string(nameof(typeof(kind))), "Payload")
            @test isdefined(Events, payload_name)
        end
        @test length(VALID_PAYLOAD_ARGS) == length(Events.kinds())
    end

    @testset "payload_type is declared for every kind, walked like kinds() against subtypes(Kind)" begin
        for kind in Events.kinds()
            @test Events.has_payload_type(kind)
            expected = Symbol(string(nameof(typeof(kind))), "Payload")
            @test Events.payload_type(kind) === getfield(Events, expected)
        end
    end

    @testset "positive control: a kind lacking payload_type is reported" begin
        @test Events.has_payload_type(PayloadTypeFixture.WithPayload())
        @test !Events.has_payload_type(PayloadTypeFixture.Missing())
    end

    @testset "a complete payload constructs" begin
        for (T, args) in VALID_PAYLOAD_ARGS
            @test T(; args...) isa T
        end
    end

    @testset "a payload missing a field refuses naming it" begin
        for (T, args) in VALID_PAYLOAD_ARGS
            for field in fieldnames(T)
                short = NamedTuple(p for p in pairs(args) if p.first != field)
                e = try
                    T(; short...)
                catch err
                    err
                end
                @test e isa Verdicts.Refusal
                @test e.quantity == String(field)
            end
        end
    end

    @testset "a refusal event is built from a raised refusal, no field fabricated or lost" begin
        sites = (
            () -> Reductions.error_bound(Float64, -1, 1.0),
            () -> Events.moved([1.0], "cpu", :gpu),
        )
        for site in sites
            raised = raised_refusal(site)
            @test field_difference(Events.payload_type(Events.Refusal()), typeof(raised)) ==
                  (Tuple{Symbol,DataType}[], Tuple{Symbol,DataType}[])
            event = Events.Event(Events.Refusal(), 1, 0.0, :slow, "Systems", raised)
            @test event.payload === raised
            for field in fieldnames(typeof(raised))
                @test getfield(event.payload, field) == getfield(raised, field)
            end
        end

        @testset "positive control: the founding payload shape is reported, and refused as a payload" begin
            fabricated, lost = field_difference(FoundingRefusalFixture.RefusalPayload,
                                                Verdicts.Refusal)
            @test Set(fabricated) == Set([(:component, String), (:refused, String),
                                          (:quantity, Float64), (:bound, Float64)])
            @test Set(lost) == Set([(:quantity, String), (:site, String), (:reason, String)])
            founding = FoundingRefusalFixture.RefusalPayload("Orbit", "eccentricity", 1.5, 1.0)
            e = raised_refusal(() -> Events.Event(Events.Refusal(), 1, 0.0, :slow, "Systems", founding))
            @test occursin("refusal", e.site)
        end
    end

    @testset "a topology_change payload names the level and the CellId base of its cells" begin
        args = VALID_PAYLOAD_ARGS[Events.TopologyChangePayload]
        payload = Events.TopologyChangePayload(; args...)
        @test payload.level == args.level
        @test eltype(payload.cells) === Mesh.CellId
        @test Events.Event(Events.TopologyChange(), 1, 0.0, :slow, "Connectivity", payload) isa Events.Event

        @testset "positive control: cells of no named base, and a level that is not one, refuse naming the field" begin
            for (field, value) in ((:cells, [1, 2]), (:cells, Int32[0, 1]), (:cells, [1.0, 2.0]),
                                   (:cells, Any[Mesh.CellId(0), Mesh.CellId(1)]), (:level, -1))
                e = raised_refusal(() -> Events.TopologyChangePayload(;
                    merge(args, NamedTuple{(field,)}((value,)))...))
                @test e.quantity == String(field)
            end
        end
    end

    @testset "a kind outside the vocabulary is a type error" begin
        @test_throws MethodError Events.Event("not-a-kind", 1, 0.0, :fast, "Test", nothing)
    end

    @testset "a payload type mismatch refuses, naming both the kind and the payload type" begin
        mismatched = Events.BudgetPayload(; VALID_PAYLOAD_ARGS[Events.BudgetPayload]...)
        e = try
            Events.Event(Events.Verdict(), 1, 0.0, :fast, "Mesh", mismatched)
        catch err
            err
        end
        @test e isa Verdicts.Refusal
        message = sprint(showerror, e)
        @test occursin("verdict", message)
        @test occursin(string(nameof(Events.VerdictPayload)), message)
        @test occursin(string(nameof(Events.BudgetPayload)), message)

        matching = Events.VerdictPayload(; VALID_PAYLOAD_ARGS[Events.VerdictPayload]...)
        @test Events.Event(Events.Verdict(), 1, 0.0, :fast, "Mesh", matching) isa Events.Event
    end

    @testset "the header form refuses a payload type mismatch the same way" begin
        header = Events.Header(1, 0.0, :fast, "Mesh", Events.Verdict())
        mismatched = Events.BudgetPayload(; VALID_PAYLOAD_ARGS[Events.BudgetPayload]...)
        e = try
            Events.Event(header, mismatched)
        catch err
            err
        end
        @test e isa Verdicts.Refusal
        message = sprint(showerror, e)
        @test occursin("verdict", message)
        @test occursin(string(nameof(Events.VerdictPayload)), message)
        @test occursin(string(nameof(Events.BudgetPayload)), message)

        matching = Events.VerdictPayload(; VALID_PAYLOAD_ARGS[Events.VerdictPayload]...)
        @test Events.Event(header, matching) isa Events.Event
    end

    @testset "an unrecognised keyword refuses, naming the keyword" begin
        args = VALID_PAYLOAD_ARGS[Events.VerdictPayload]
        e = try
            Events.VerdictPayload(; args..., typo = 99)
        catch err
            err
        end
        @test e isa Verdicts.Refusal
        @test e.quantity == "typo"

        @test Events.VerdictPayload(; args...) isa Events.VerdictPayload
    end

    @testset "emit with no sink installed is a no-op, asserted by counting" begin
        replaced = Events.Collector{Events.Event}()
        Events.sink!(replaced)
        Events.sink!(Events.noop_sink)
        for i in 1:5
            Events.emit(Events.Event(Events.Verdict(), i, Float64(i), :fast, "Test",
                                      Events.VerdictPayload(; VALID_PAYLOAD_ARGS[Events.VerdictPayload]...)))
        end
        @test isempty(Events.collected(replaced))
        Events.moved([1, 2, 3], :cpu, :gpu)
        @test isempty(Events.collected(replaced))
    end

    @testset "emit with a fixture sink delivers one event per call" begin
        sink = Events.Collector{Events.Event}()
        Events.sink!(sink)
        n = 4
        for i in 1:n
            Events.emit(Events.Event(Events.Oracle(), i, i * 0.5, :slow, "Oracles",
                                      Events.OraclePayload(; VALID_PAYLOAD_ARGS[Events.OraclePayload]...)))
        end
        log = Events.collected(sink)
        @test length(log) == n
        for (i, ev) in enumerate(log)
            @test ev.header.sequence == i
            @test ev.header.instant == i * 0.5
            @test ev.header.tier == :slow
            @test ev.header.component == "Oracles"
            @test ev.header.kind isa Events.Oracle
        end
        Events.sink!(Events.noop_sink)
    end

    @testset "moved records through the move sink, which is not the event sink" begin
        sink = Events.Collector{Events.Moved}()
        Events.move_sink!(sink)
        Events.moved([1.0, 2.0], :cpu, :gpu)
        log = Events.collected(sink)
        @test length(log) == 1
        @test log[1] isa Events.Moved
        @test log[1].from == :cpu
        @test log[1].to == :gpu
        Events.move_sink!(Events.noop_sink)
    end

    # Decision 0046: a move is counted, never journalled, and the two sinks are
    # installed separately so a journal writer cannot be handed a Moved.

    @testset "a move is counted and never reaches the event sink" begin
        Events.reset_move_counts!()
        seen = Events.Collector{Events.Event}()
        Events.sink!(seen)
        n = 7
        for i in 1:n
            Events.moved([Float64(i)], :gpu, :cpu)
        end
        @test isempty(Events.collected(seen))
        @test Events.move_counts() == Dict((:gpu, :cpu) => n)
        @test Events.move_total() == n

        @testset "positive control: the same installed sink does receive an event" begin
            Events.emit(Events.Event(Events.Budget(), 1, 0.0, :fast, "Test",
                                      Events.BudgetPayload(; VALID_PAYLOAD_ARGS[Events.BudgetPayload]...)))
            @test length(Events.collected(seen)) == 1
        end

        Events.sink!(Events.noop_sink)
        Events.reset_move_counts!()
    end

    @testset "an event never reaches the move sink" begin
        moves = Events.Collector{Events.Moved}()
        events = Events.Collector{Events.Event}()
        Events.move_sink!(moves)
        Events.sink!(events)
        for i in 1:3
            Events.emit(Events.Event(Events.Oracle(), i, 0.0, :fast, "Test",
                                      Events.OraclePayload(; VALID_PAYLOAD_ARGS[Events.OraclePayload]...)))
        end
        @test isempty(Events.collected(moves))
        @test length(Events.collected(events)) == 3

        @testset "positive control: the same installed move sink does receive a move" begin
            Events.moved([1.0], :cpu, :gpu)
            @test length(Events.collected(moves)) == 1
            @test length(Events.collected(events)) == 3
        end

        Events.sink!(Events.noop_sink)
        Events.move_sink!(Events.noop_sink)
        Events.reset_move_counts!()
    end

    @testset "a run's journal length is its event count, whatever its move count" begin
        "One fixture run: two events, and `reductions` device reads between them."
        function fixture_run(reductions)
            Events.emit(Events.Event(Events.LedgerOpen(), 1, 0.0, :fast, "Test",
                                      Events.LedgerOpenPayload(; VALID_PAYLOAD_ARGS[Events.LedgerOpenPayload]...)))
            for _ in 1:reductions
                Events.moved([1.0], :gpu, :cpu)
            end
            Events.emit(Events.Event(Events.Verdict(), 2, 1.0, :fast, "Test",
                                      Events.VerdictPayload(; VALID_PAYLOAD_ARGS[Events.VerdictPayload]...)))
        end

        for reductions in (0, 1, 10, 100)
            journal = Events.Collector{Events.Event}()
            Events.sink!(journal)
            Events.reset_move_counts!()
            fixture_run(reductions)
            @test length(Events.collected(journal)) == 2
            @test Events.move_total() == reductions
        end

        Events.sink!(Events.noop_sink)
        Events.reset_move_counts!()
    end

    @testset "moved with no move sink installed counts the move all the same" begin
        replaced = Events.MoveTally()
        Events.move_sink!(replaced)
        Events.move_sink!(Events.noop_sink)
        Events.reset_move_counts!()
        Events.moved([1.0], :cpu, :gpu)
        @test Events.move_total(replaced) == 0
        @test Events.move_total() == 1
        Events.reset_move_counts!()
    end

    @testset "an installed MoveTally counts the moves made while it is installed, beside the run's tally" begin
        Events.reset_move_counts!()
        Events.moved([1.0], :cpu, :gpu)
        scoped = Events.MoveTally()
        Events.move_sink!(scoped)
        Events.moved([2.0], :cpu, :gpu)
        Events.moved([3.0], :gpu, :cpu)
        Events.move_sink!(Events.noop_sink)
        Events.moved([4.0], :gpu, :cpu)
        @test Events.move_counts(scoped) == Dict((:cpu, :gpu) => 1, (:gpu, :cpu) => 1)
        @test Events.move_total(scoped) == 2
        @test Events.move_counts() == Dict((:cpu, :gpu) => 2, (:gpu, :cpu) => 2)
        @test Events.reset_move_counts!(scoped) == Dict((:cpu, :gpu) => 1, (:gpu, :cpu) => 1)
        @test Events.move_total(scoped) == 0
        @test Events.move_total() == 4
        Events.reset_move_counts!()
    end

    # Decision 0046, Amendments: the sinks are a closed set of concrete types.

    @testset "the installed sinks have a declared concrete type, and each member of its set is concrete" begin
        @test fieldtype(typeof(Events.SINK), :x) === Events.EventSink
        @test fieldtype(typeof(Events.MOVE_SINK), :x) === Events.MoveSink
        @test Set(Base.uniontypes(Events.EventSink)) ==
              Set([Events.NoopSink, Events.Journal, Events.Collector{Events.Event}])
        @test Set(Base.uniontypes(Events.MoveSink)) ==
              Set([Events.NoopSink, Events.MoveTally, Events.Collector{Events.Moved}])
        @test all(isconcretetype, Base.uniontypes(Events.EventSink))
        @test all(isconcretetype, Base.uniontypes(Events.MoveSink))
    end

    @testset "a sink outside the closed set is refused by name, and the installed sink stays" begin
        events = Events.Collector{Events.Event}()
        moves = Events.Collector{Events.Moved}()
        Events.sink!(events)
        Events.move_sink!(moves)
        outside_event = (ev -> nothing, println, Events.MoveTally(), Events.Collector{Events.Moved}(),
                         Events.Collector{Any}())
        outside_move = (rec -> nothing, println, Events.Journal(tempname()),
                        Events.Collector{Events.Event}(), Events.Collector{Any}())
        for (install, site, outside) in ((Events.sink!, "Events.sink!", outside_event),
                                         (Events.move_sink!, "Events.move_sink!", outside_move))
            for sink in outside
                e = raised_refusal(() -> install(sink))
                @test e.quantity == "sink"
                @test e.site == site
                @test occursin(string(typeof(sink)), e.reason)
            end
        end
        @test Events.SINK[] === events
        @test Events.MOVE_SINK[] === moves

        @testset "positive control: every member of each set installs" begin
            for sink in (Events.noop_sink, Events.Journal(tempname()), Events.Collector{Events.Event}())
                @test Events.sink!(sink) === nothing
                @test Events.SINK[] === sink
            end
            for sink in (Events.noop_sink, Events.MoveTally(), Events.Collector{Events.Moved}())
                @test Events.move_sink!(sink) === nothing
                @test Events.MOVE_SINK[] === sink
            end
        end

        Events.sink!(Events.noop_sink)
        Events.move_sink!(Events.noop_sink)
    end

    @testset "the tally counts each direction on its own and resets to empty" begin
        Events.reset_move_counts!()
        Events.moved([1.0], :cpu, :gpu)
        Events.moved([2.0], :cpu, :gpu)
        Events.moved([3.0], :gpu, :cpu)
        @test Events.move_counts() == Dict((:cpu, :gpu) => 2, (:gpu, :cpu) => 1)
        @test Events.move_total() == 3

        held = Events.reset_move_counts!()
        @test held == Dict((:cpu, :gpu) => 2, (:gpu, :cpu) => 1)
        @test isempty(Events.move_counts())
        @test Events.move_total() == 0
    end

    @testset "moved refuses a backend that is not a name, and counts nothing" begin
        Events.reset_move_counts!()
        for (from, to, named) in (("cpu", :gpu, "from"), (:cpu, 3, "to"))
            e = try
                Events.moved([1.0], from, to)
            catch err
                err
            end
            @test e isa Verdicts.Refusal
            @test e.quantity == named
        end
        @test isempty(Events.move_counts())

        @testset "positive control: two names go through and are counted" begin
            @test Events.moved([1.0], :cpu, :gpu) === nothing
            @test Events.move_total() == 1
        end

        Events.reset_move_counts!()
    end
end
