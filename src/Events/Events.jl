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
naming the field, the first field of `T` that `kwargs` omits.
"""
function build_payload(::Type{T}, site::AbstractString; kwargs...) where {T}
    provided = Dict{Symbol,Any}(kwargs)
    values = Any[]
    for field in fieldnames(T)
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
    RefusalPayload(; component, refused, quantity, bound)

The payload of a `refusal` event: the component, what was refused, the
quantity, and the bound it violated.
"""
struct RefusalPayload
    component::String
    refused::String
    quantity::Float64
    bound::Float64
end
RefusalPayload(; kwargs...) = build_payload(RefusalPayload, "RefusalPayload"; kwargs...)

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
    TopologyChangePayload(; edit, cells, quantity)

The payload of a `topology_change` event: the connectivity-graph edit, the
cells involved, and the quantity that crossed.
"""
struct TopologyChangePayload
    edit::String
    cells::Vector{Int}
    quantity::Float64
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
    Event(header, payload)
    Event(kind, sequence, instant, tier, component, payload)

One journal entry: the header decision 0042 fixes and its typed payload. The
second form builds the header from its parts; `kind` must be a `Kind`, which
is what makes a kind outside the vocabulary a type error rather than a
runtime check.
"""
struct Event
    header::Header
    payload::Any
end

Event(kind::Kind, sequence::Integer, instant::Real, tier::Symbol,
      component::AbstractString, payload) =
    Event(Header(Int(sequence), Float64(instant), tier, String(component), kind), payload)

"A sink that does nothing with the record it is handed."
noop_sink(record) = nothing

const SINK = Ref{Any}(noop_sink)

"""
    sink!(f)

Install `f` as the callback `emit` and `moved` hand every record to,
replacing whatever was installed before. The default sink is `noop_sink`.
"""
sink!(f) = (SINK[] = f; nothing)

"""
    emit(event::Event)

Hand `event` to the installed sink. With no sink installed, the default sink
is a no-op and `event` has no effect.
"""
emit(event::Event) = (SINK[](event); nothing)

"""
    Moved(array, from, to)

The device-move record of decision 0010: `array` moved from backend `from`
to backend `to`. `from` and `to` are read by name, never by a type this
module would have to depend on the backend layer for.
"""
struct Moved
    array::Any
    from::Any
    to::Any
end

"""
    moved(array, from, to)

Record that `array` moved from backend `from` to backend `to`, handing a
`Moved` record to the installed sink. With no sink installed, the default
sink is a no-op.
"""
moved(array, from, to) = (SINK[](Moved(array, from, to)); nothing)

end # module Events
