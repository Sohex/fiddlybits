module Events

using ..Verdicts

"""
    Kind

The closed vocabulary of run-journal event kinds (decision 0042). `kinds()`
enumerates it.
"""
abstract type Kind end

struct Verdict <: Kind end
struct Refusal <: Kind end
struct LedgerOpen <: Kind end
struct Refresh <: Kind end
struct TopologyChange <: Kind end
struct LevelChange <: Kind end
struct Artifact <: Kind end
struct Checkpoint <: Kind end
struct Oracle <: Kind end
struct Budget <: Kind end

"Every `Kind` singleton, in the order decision 0042 declares them."
kinds() = (Verdict(), Refusal(), LedgerOpen(), Refresh(), TopologyChange(),
           LevelChange(), Artifact(), Checkpoint(), Oracle(), Budget())

"""
    name(kind::Kind)

The vocabulary word decision 0042 gives `kind`, as a `Symbol`.
"""
name(::Verdict) = :verdict
name(::Refusal) = :refusal
name(::LedgerOpen) = :ledger_open
name(::Refresh) = :refresh
name(::TopologyChange) = :topology_change
name(::LevelChange) = :level_change
name(::Artifact) = :artifact
name(::Checkpoint) = :checkpoint
name(::Oracle) = :oracle
name(::Budget) = :budget

"""
    Header

The header every event carries (decision 0042): the sequence number, the
simulated instant in SI seconds, the tier that was advancing, the emitting
component, and the kind.
"""
struct Header
    sequence::Int
    instant::Float64
    tier::Symbol
    component::String
    kind::Kind
end

"""
    build_payload(T, site; kwargs...)

`T` built from `kwargs`, one entry per field of `T` in field order. Refuses,
naming it, the first keyword in `kwargs` that is not a field of `T`; refuses,
naming it, the first field of `T` that `kwargs` omits.
"""
function build_payload(::Type{T}, site::AbstractString; kwargs...) where {T}
    provided = Dict{Symbol,Any}(kwargs)
    known = fieldnames(T)
    for key in keys(provided)
        key in known || Verdicts.refuse(String(key), site, "not a field of $(T)")
    end
    values = Any[]
    for field in known
        haskey(provided, field) || Verdicts.refuse(String(field), site, "missing required field")
        push!(values, provided[field])
    end
    return T(values...)
end

"""
    VerdictPayload(; predicate, verdict, statistic, bracket)

The payload of a `verdict` event: the loop or predicate by name, its
`Verdicts.LoopVerdict`, the statistic, and the bracket it was judged against
as `(lo, hi)`.
"""
struct VerdictPayload
    predicate::String
    verdict::Verdicts.LoopVerdict
    statistic::Float64
    bracket::Tuple{Float64,Float64}
end
VerdictPayload(; kwargs...) = build_payload(VerdictPayload, "VerdictPayload"; kwargs...)

"""
    RefusalPayload(; quantity, site, reason)

The payload of a `refusal` event, which is the `Verdicts.Refusal` that was
raised: what was refused, where it was refused, and why. `RefusalPayload` is
`Verdicts.Refusal` under the name the other payloads follow, so a caught
refusal is handed to `Event` as it is (decision 0042, Amendments).
"""
const RefusalPayload = Verdicts.Refusal
Verdicts.Refusal(; kwargs...) = build_payload(Verdicts.Refusal, "RefusalPayload"; kwargs...)

"""
    LedgerOpenPayload(; ledger, imbalance, tolerance, exchange)

The payload of a `ledger_open` event: the ledger, the imbalance, the derived
tolerance, and the exchange it closed over.
"""
struct LedgerOpenPayload
    ledger::String
    imbalance::Float64
    tolerance::Float64
    exchange::String
end
LedgerOpenPayload(; kwargs...) = build_payload(LedgerOpenPayload, "LedgerOpenPayload"; kwargs...)

"""
    RefreshPayload(; trigger, field, change, restart_seconds, restart_orbits)

The payload of a `refresh` event: the trigger that fired, the boundary field
that changed and by how much, and the restart length in seconds and in
orbits.
"""
struct RefreshPayload
    trigger::String
    field::String
    change::Float64
    restart_seconds::Float64
    restart_orbits::Float64
end
RefreshPayload(; kwargs...) = build_payload(RefreshPayload, "RefreshPayload"; kwargs...)

"""
    TopologyChangePayload(; edit, level, cells, quantity)

The payload of a `topology_change` event: the connectivity-graph edit, the
level of the hierarchy whose numbering the cells are in, the cells involved as
`Mesh.CellId` values at that level, and the quantity that crossed (decision
0042, Amendments). The element type of `cells` is the type parameter `C`.

Refuses, naming the field, a negative `level`, and `cells` whose element type
is not concrete or is a `Number`.
"""
struct TopologyChangePayload{C}
    edit::String
    level::Int
    cells::Vector{C}
    quantity::Float64

    function TopologyChangePayload(edit::AbstractString, level::Integer,
                                   cells::AbstractVector, quantity::Real)
        site = "TopologyChangePayload"
        level >= 0 ||
            Verdicts.refuse("level", site, "level $(level) is not a level of the hierarchy")
        C = eltype(cells)
        (isconcretetype(C) && !(C <: Number)) ||
            Verdicts.refuse("cells", site,
                            "element type $(C) is not Mesh.CellId; a cell crosses to the journal as a CellId, never as a number")
        return new{C}(String(edit), Int(level), Vector{C}(cells), Float64(quantity))
    end
end
TopologyChangePayload(; kwargs...) = build_payload(TopologyChangePayload, "TopologyChangePayload"; kwargs...)

"""
    LevelChangePayload(; from, to, window)

The payload of a `level_change` event: the level moved from and to, and the
reconvergence window.
"""
struct LevelChangePayload
    from::Int
    to::Int
    window::Float64
end
LevelChangePayload(; kwargs...) = build_payload(LevelChangePayload, "LevelChangePayload"; kwargs...)

"""
    ArtifactPayload(; key, kind, support)

The payload of an `artifact` event: the content key written, its kind, and
its support id.
"""
struct ArtifactPayload
    key::String
    kind::String
    support::String
end
ArtifactPayload(; kwargs...) = build_payload(ArtifactPayload, "ArtifactPayload"; kwargs...)

"""
    CheckpointPayload(; key, precision)

The payload of a `checkpoint` event: the key, and the working precision it
was written at.
"""
struct CheckpointPayload
    key::String
    precision::DataType
end
CheckpointPayload(; kwargs...) = build_payload(CheckpointPayload, "CheckpointPayload"; kwargs...)

"""
    OraclePayload(; registry_id, verdict, statistic, threshold)

The payload of an `oracle` event: the registry id, its
`Verdicts.OracleVerdict`, the statistic, and the threshold.
"""
struct OraclePayload
    registry_id::String
    verdict::Verdicts.OracleVerdict
    statistic::Float64
    threshold::Float64
end
OraclePayload(; kwargs...) = build_payload(OraclePayload, "OraclePayload"; kwargs...)

"""
    BudgetPayload(; cap, which)

The payload of a `budget` event: the cap reached, and which cap it was.
"""
struct BudgetPayload
    cap::Float64
    which::String
end
BudgetPayload(; kwargs...) = build_payload(BudgetPayload, "BudgetPayload"; kwargs...)

"""
    payload_type(kind::Kind)

The payload type decision 0042 fixes for `kind`.
"""
payload_type(::Verdict) = VerdictPayload
payload_type(::Refusal) = RefusalPayload
payload_type(::LedgerOpen) = LedgerOpenPayload
payload_type(::Refresh) = RefreshPayload
payload_type(::TopologyChange) = TopologyChangePayload
payload_type(::LevelChange) = LevelChangePayload
payload_type(::Artifact) = ArtifactPayload
payload_type(::Checkpoint) = CheckpointPayload
payload_type(::Oracle) = OraclePayload
payload_type(::Budget) = BudgetPayload

"""
    has_payload_type(kind)

Whether `payload_type` is declared for `kind`. Lets a kind be walked against
`payload_type` the same way `kinds()` is walked against `subtypes(Kind)`.
"""
has_payload_type(kind) = hasmethod(payload_type, Tuple{typeof(kind)})

"""
    Event(header, payload)
    Event(kind, sequence, instant, tier, component, payload)

One journal entry: the header decision 0042 fixes and its typed payload. The
second form builds the header from its parts; `kind` must be a `Kind`, which
is what makes a kind outside the vocabulary a type error rather than a
runtime check. Both forms refuse, naming the kind and the declared payload
type, unless `payload isa payload_type(header.kind)`.
"""
struct Event
    header::Header
    payload::Any

    function Event(header::Header, payload)
        kind = header.kind
        expected = payload_type(kind)
        payload isa expected ||
            Verdicts.refuse(string(typeof(payload)), "Event(:$(name(kind)))",
                             "kind :$(name(kind)) declares payload type $(expected)")
        return new(header, payload)
    end
end

Event(kind::Kind, sequence::Integer, instant::Real, tier::Symbol,
      component::AbstractString, payload) =
    Event(Header(Int(sequence), Float64(instant), tier, String(component), kind), payload)

"""
    Moved(array, from, to)

The device-move record of decision 0010: `array` moved from backend `from`
to backend `to`. `from` and `to` are backend names, each a `Symbol`, never a
type this module would have to depend on the backend layer for.
"""
struct Moved
    array::Any
    from::Symbol
    to::Symbol
end

# The sinks: a closed set of concrete types, one method each (decision 0046,
# Amendments).

"""
    NoopSink

The sink that does nothing with the record it is handed. `noop_sink` is its
one value, and the default of both `sink!` and `move_sink!`.
"""
struct NoopSink end

"The one `NoopSink`."
const noop_sink = NoopSink()

"""
    (sink::NoopSink)(record)

Nothing, whatever `record` is.
"""
(::NoopSink)(record) = nothing

"""
    Journal(::Verdicts.Checked, file)

The event sink of one run's journal: `file`, the journal file, and `lock`,
held while one event's text is appended to it. `Provenance.install_journal!`
makes one, passing `Verdicts.Checked()` after its refusals have run, and
installs it; the method that appends an `Event` to `file` is in
`src/Provenance/journal.jl`.
"""
struct Journal
    file::String
    lock::ReentrantLock

    Journal(::Verdicts.Checked, file::String) = new(file, ReentrantLock())
end

"""
    Collector{R}()

A sink that keeps every record of type `R` it is handed, in the order it was
handed them, under a lock. `collected` reads what it holds.
"""
struct Collector{R}
    records::Vector{R}
    lock::ReentrantLock
end

Collector{R}() where {R} = Collector{R}(R[], ReentrantLock())

"""
    (sink::Collector{R})(record::R)

Append `record` to `sink`'s records under its lock.
"""
function (sink::Collector{R})(record::R) where {R}
    lock(() -> push!(sink.records, record), sink.lock)
    return nothing
end

"""
    collected(sink::Collector)

A copy of the records `sink` holds, in the order it was handed them.
"""
collected(sink::Collector) = lock(() -> copy(sink.records), sink.lock)

"""
    MoveTally()

A device-move tally: one count per ordered pair of backend names, under a
lock. Handed a `Moved`, it adds one under `(from, to)`. `MOVE_TALLY` is the
run's tally, which `moved` adds to whatever move sink is installed; a
`MoveTally` installed through `move_sink!` counts the moves made while it is
installed.
"""
struct MoveTally
    counts::Dict{Tuple{Symbol,Symbol},Int}
    lock::ReentrantLock
end

MoveTally() = MoveTally(Dict{Tuple{Symbol,Symbol},Int}(), ReentrantLock())

"""
    (tally::MoveTally)(record::Moved)

Add one to `tally` under `(record.from, record.to)`.
"""
function (tally::MoveTally)(record::Moved)
    pair = (record.from, record.to)
    lock(tally.lock) do
        tally.counts[pair] = get(tally.counts, pair, 0) + 1
    end
    return nothing
end

"""
    EventSink

The sinks `sink!` installs and `emit` hands an `Event` to: `NoopSink`,
`Journal` and `Collector{Event}`.
"""
const EventSink = Union{NoopSink, Journal, Collector{Event}}

"""
    MoveSink

The sinks `move_sink!` installs and `moved` hands a `Moved` to: `NoopSink`,
`MoveTally` and `Collector{Moved}`.
"""
const MoveSink = Union{NoopSink, MoveTally, Collector{Moved}}

"""
    refuse_sink(sink, site, set)

Refuse, at `site`, naming the quantity `sink`, a `sink` whose type is not a
member of the `Union` `set`, listing the members.
"""
refuse_sink(sink, site::String, set::Type) =
    Verdicts.refuse("sink", site,
                    "a $(typeof(sink)) is not a sink $(site) installs; the sinks it installs are " *
                    join(string.(Base.uniontypes(set)), ", "))

const SINK = Ref{EventSink}(noop_sink)

"""
    sink!(sink)

Install `sink` as the sink `emit` hands every event to, replacing whatever was
installed before. The default sink is `noop_sink`. A `Moved` record never
reaches this sink; `move_sink!` installs the one it does reach (decision
0046). Refuses, naming `sink`, a value that is not an `EventSink`, leaving the
installed sink in place.
"""
sink!(sink::EventSink) = (SINK[] = sink; nothing)
sink!(sink) = refuse_sink(sink, "Events.sink!", EventSink)

"""
    emit(event::Event)

Hand `event` to the installed event sink. With no sink installed, the default
sink is a no-op and `event` has no effect.
"""
emit(event::Event) = (SINK[](event); nothing)

const MOVE_SINK = Ref{MoveSink}(noop_sink)

"""
    move_sink!(sink)

Install `sink` as the sink `moved` hands every `Moved` record to, replacing
whatever was installed before. The default sink is `noop_sink`. An `Event`
never reaches this sink; `sink!` installs the one it does reach (decision
0046). Refuses, naming `sink`, a value that is not a `MoveSink`, leaving the
installed sink in place.
"""
move_sink!(sink::MoveSink) = (MOVE_SINK[] = sink; nothing)
move_sink!(sink) = refuse_sink(sink, "Events.move_sink!", MoveSink)

"The run's device-move tally, which `move_counts` reads."
const MOVE_TALLY = MoveTally()

"""
    backend_name(name, argument)

`name` as the `Symbol` it is. Refuses, naming `argument`, anything that is not
a `Symbol`.
"""
backend_name(name::Symbol, argument) = name
backend_name(name, argument) =
    Verdicts.refuse(argument, "Events.moved",
                     "a backend is read by name, and a name is a Symbol, not $(typeof(name))")

"""
    moved(array, from, to)

Record that `array` moved from backend `from` to backend `to`: hand a `Moved`
record to `MOVE_TALLY`, which adds one under the pair `(from, to)`, then to the
installed move sink. With no move sink installed, the default sink is a no-op
and the tally is the whole record. Refuses, naming the argument, a `from` or a
`to` that is not a `Symbol`, before counting anything.
"""
function moved(array, from, to)
    record = Moved(array, backend_name(from, "from"), backend_name(to, "to"))
    MOVE_TALLY(record)
    MOVE_SINK[](record)
    return nothing
end

"""
    move_counts(tally = MOVE_TALLY)

A copy of `tally`: how many moves it has counted between each ordered pair of
backend names since it was made or last emptied by `reset_move_counts!`.
"""
move_counts(tally::MoveTally = MOVE_TALLY) = lock(() -> copy(tally.counts), tally.lock)

"""
    move_total(tally = MOVE_TALLY)

How many moves `tally` has counted since it was made or last emptied by
`reset_move_counts!`, over every pair of backend names.
"""
move_total(tally::MoveTally = MOVE_TALLY) =
    lock(() -> sum(values(tally.counts); init = 0), tally.lock)

"""
    reset_move_counts!(tally = MOVE_TALLY)

Empty `tally` and return what it held.
"""
function reset_move_counts!(tally::MoveTally = MOVE_TALLY)
    lock(tally.lock) do
        held = copy(tally.counts)
        empty!(tally.counts)
        return held
    end
end

end # module Events
