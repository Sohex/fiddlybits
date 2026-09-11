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

    @testset "moved records through the same sink" begin
        log = Any[]
        Events.sink!(rec -> push!(log, rec))
        Events.moved([1.0, 2.0], :cpu, :gpu)
        @test length(log) == 1
        @test log[1] isa Events.Moved
        @test log[1].from == :cpu
        @test log[1].to == :gpu
        Events.sink!(Events.noop_sink)
    end
end
