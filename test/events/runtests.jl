using Test
using InteractiveUtils: subtypes
using Fiddlybits: Events, Verdicts

# The event vocabulary is closed by this check rather than by the language: a
# subtype added anywhere fails the suite until the enumeration and decision
# 0042 move together.

"""
    closed_set(T, enumeration)

`(undeclared, unreachable)`: the subtypes of `T` that `enumeration` omits, and
the entries of `enumeration` that are not subtypes of `T`.
"""
function closed_set(T::Type, enumeration)
    declared = Set(typeof(v) for v in enumeration)
    present = Set(subtypes(T))
    return (sort(collect(setdiff(present, declared)), by = string),
            sort(collect(setdiff(declared, present)), by = string))
end

module ClosedSetFixture
    abstract type Colour end
    struct Red <: Colour end
    struct Blue <: Colour end
    partial() = (Red(),)
    whole() = (Red(), Blue())
end

# A separate hierarchy, not a subtype of Events.Kind, so exercising
# payload_type here cannot widen Events.kinds() and break its closure test.
module PayloadTypeFixture
    struct WithPayload end
    struct Missing end
end
Events.payload_type(::PayloadTypeFixture.WithPayload) = Int

"A complete, valid keyword set for each payload, used where a test needs one
that constructs without refusing."
const VALID_PAYLOAD_ARGS = Dict(
    Events.VerdictPayload => (predicate = "FixedPointLoop", verdict = Verdicts.Converged(),
                               statistic = 0.5, bracket = (0.0, 1.0)),
    Events.RefusalPayload => (component = "Mesh", refused = "radius",
                               quantity = 2.0, bound = 1.0),
    Events.LedgerOpenPayload => (ledger = "heat", imbalance = 1.0e-3,
                                  tolerance = 1.0e-6, exchange = "surface flux"),
    Events.RefreshPayload => (trigger = "sea ice extent", field = "albedo",
                               change = 0.2, restart_seconds = 3600.0, restart_orbits = 0.1),
    Events.TopologyChangePayload => (edit = "strait closed", cells = [1, 2],
                                      quantity = 4.0),
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
        undeclared, unreachable = closed_set(ClosedSetFixture.Colour, ClosedSetFixture.partial())
        @test undeclared == [ClosedSetFixture.Blue]
        @test isempty(unreachable)
        @test closed_set(ClosedSetFixture.Colour, ClosedSetFixture.whole()) == (Any[], Any[])
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
        count = Ref(0)
        Events.sink!(ev -> (count[] += 1; nothing))
        Events.sink!(Events.noop_sink)
        for i in 1:5
            Events.emit(Events.Event(Events.Verdict(), i, Float64(i), :fast, "Test",
                                      Events.VerdictPayload(; VALID_PAYLOAD_ARGS[Events.VerdictPayload]...)))
        end
        @test count[] == 0
        Events.moved([1, 2, 3], :cpu, :gpu)
        @test count[] == 0
    end

    @testset "emit with a fixture sink delivers one event per call" begin
        log = Events.Event[]
        Events.sink!(ev -> push!(log, ev))
        n = 4
        for i in 1:n
            Events.emit(Events.Event(Events.Oracle(), i, i * 0.5, :slow, "Oracles",
                                      Events.OraclePayload(; VALID_PAYLOAD_ARGS[Events.OraclePayload]...)))
        end
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
        log = Any[]
        Events.move_sink!(rec -> push!(log, rec))
        Events.moved([1.0, 2.0], :cpu, :gpu)
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
        seen = Any[]
        Events.sink!(rec -> push!(seen, rec))
        n = 7
        for i in 1:n
            Events.moved([Float64(i)], :gpu, :cpu)
        end
        @test isempty(seen)
        @test Events.move_counts() == Dict((:gpu, :cpu) => n)
        @test Events.move_total() == n

        @testset "positive control: the same installed sink does receive an event" begin
            Events.emit(Events.Event(Events.Budget(), 1, 0.0, :fast, "Test",
                                      Events.BudgetPayload(; VALID_PAYLOAD_ARGS[Events.BudgetPayload]...)))
            @test length(seen) == 1
        end

        Events.sink!(Events.noop_sink)
        Events.reset_move_counts!()
    end

    @testset "an event never reaches the move sink" begin
        moves = Any[]
        events = Any[]
        Events.move_sink!(rec -> push!(moves, rec))
        Events.sink!(ev -> push!(events, ev))
        for i in 1:3
            Events.emit(Events.Event(Events.Oracle(), i, 0.0, :fast, "Test",
                                      Events.OraclePayload(; VALID_PAYLOAD_ARGS[Events.OraclePayload]...)))
        end
        @test isempty(moves)
        @test length(events) == 3

        @testset "positive control: the same installed move sink does receive a move" begin
            Events.moved([1.0], :cpu, :gpu)
            @test length(moves) == 1
            @test length(events) == 3
        end

        Events.sink!(Events.noop_sink)
        Events.move_sink!(Events.noop_sink)
        Events.reset_move_counts!()
    end

    @testset "a run's journal length is its event count, whatever its move count" begin
        journal = Events.Event[]
        Events.sink!(ev -> push!(journal, ev))

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
            empty!(journal)
            Events.reset_move_counts!()
            fixture_run(reductions)
            @test length(journal) == 2
            @test Events.move_total() == reductions
        end

        Events.sink!(Events.noop_sink)
        Events.reset_move_counts!()
    end

    @testset "moved with no move sink installed counts the move all the same" begin
        count = Ref(0)
        Events.move_sink!(rec -> (count[] += 1; nothing))
        Events.move_sink!(Events.noop_sink)
        Events.reset_move_counts!()
        Events.moved([1.0], :cpu, :gpu)
        @test count[] == 0
        @test Events.move_total() == 1
        Events.reset_move_counts!()
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
