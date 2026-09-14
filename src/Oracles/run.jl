# The runner: docs/plans/fiddlybits-52v.8-oracles.md, section "The runner"; decision
# 0025 (amendment of 2026-09-13, the registration rule's door); decision 0042 (the one
# emitter, the closed event vocabulary); fiddlybits-3vq's row notes (a row's payload
# resolved through its datasets manifests).

using TOML
using ..Verdicts: refuse, OracleVerdict, FAIL, REPORT, PASS
using ..Events: Events
using ..Systems: read_keywords, require_type

"""
    Payload(; value, reference, pattern = nothing, pattern_reference = nothing, hashes = String[])

A model result the runner reads for one entry: `value`, the entry's statistic on the
run, and `reference`, the value it is judged against; `pattern` and
`pattern_reference`, the entry's pattern statistic beside its global mean, both
`nothing` where the entry carries none; `hashes`, the sha256 digest of every dataset
file the statistic was read from, checked against the manifests `entry.datasets`
names. Refuses one of `pattern` and `pattern_reference` given without the other.
"""
struct Payload
    value::Float64
    reference::Float64
    pattern::Union{Nothing,Float64}
    pattern_reference::Union{Nothing,Float64}
    hashes::Vector{String}
end

function Payload(; value, reference, pattern = nothing, pattern_reference = nothing, hashes = String[])
    (pattern === nothing) == (pattern_reference === nothing) ||
        refuse("payload", "Oracles.Payload", pattern === nothing ?
                                             "states pattern_reference with no pattern" :
                                             "states pattern with no pattern_reference")
    return Payload(Float64(value), Float64(reference),
                  pattern === nothing ? nothing : Float64(pattern),
                  pattern_reference === nothing ? nothing : Float64(pattern_reference),
                  String[String(h) for h in hashes])
end

"""
    Result

One entry's oracle result, held for `report`: the registry `id`; the model `value`
and the `reference` it was judged against; the pattern statistic and its reference,
`nothing` where the entry carries none; the reference's own `uncertainty` in the
statistic's unit, `nothing` where the entry states no bar; and the `verdict`.
"""
struct Result
    id::String
    value::Float64
    reference::Float64
    pattern::Union{Nothing,Float64}
    pattern_reference::Union{Nothing,Float64}
    uncertainty::Union{Nothing,Float64}
    verdict::OracleVerdict
end

"The distance of `r`'s value from its reference."
distance(r::Result) = abs(r.value - r.reference)

"""
    in_uncertainty(r)

The distance of `r` in units of its `uncertainty`, or `nothing` where `r` carries
none.
"""
in_uncertainty(r::Result) = r.uncertainty === nothing ? nothing : distance(r) / r.uncertainty

"""
    manifest_hashes(path)

Every sha256 digest the manifest TOML document at `path` carries, wherever a table
nested in it, at any depth, holds a key `sha256` mapped to a string.
"""
function manifest_hashes(path::AbstractString)
    found = Set{String}()
    collect_hashes!(found, TOML.parsefile(path))
    return found
end

function collect_hashes!(found::Set{String}, node::AbstractDict)
    for (key, v) in node
        if key == "sha256" && v isa AbstractString
            push!(found, v)
        else
            collect_hashes!(found, v)
        end
    end
    return found
end

function collect_hashes!(found::Set{String}, node::AbstractVector)
    for v in node
        collect_hashes!(found, v)
    end
    return found
end

collect_hashes!(found::Set{String}, node) = found

"""
    dataset_manifest(id, oracle_data, input_data)

The path of the manifest `id * ".toml"` under `oracle_data` or `input_data`,
whichever holds it, or `nothing` when neither does.
"""
function dataset_manifest(id::AbstractString, oracle_data::AbstractString, input_data::AbstractString)
    for dir in (oracle_data, input_data)
        path = joinpath(dir, id * ".toml")
        isfile(path) && return path
    end
    return nothing
end

"""
    resolve_payload(entry, payload, oracle_data, input_data)

`payload` when every hash of `payload.hashes` is a hash carried by a manifest of
`entry.datasets`, read from `oracle_data` or `input_data` (fiddlybits-3vq). Refuses,
naming `entry.id`, a dataset id resolving to no manifest under either directory, and a
hash that is not among the hashes of `entry`'s manifests.
"""
function resolve_payload(entry::Entry, payload::Payload, oracle_data::AbstractString, input_data::AbstractString)
    isempty(payload.hashes) && return payload
    ids = entry.datasets === nothing ? String[] : entry.datasets
    known = Set{String}()
    for id in ids
        path = dataset_manifest(id, oracle_data, input_data)
        path === nothing && refuse("dataset", entry.id,
                                   "names manifest " * id * ", found under neither " * oracle_data *
                                   " nor " * input_data)
        union!(known, manifest_hashes(path))
    end
    for h in payload.hashes
        h in known ||
            refuse("payload", entry.id, "a hash " * h * " that is not among the hashes of its datasets manifests")
    end
    return payload
end

"""
    judge(entry, payload)

The `Result` of `entry`'s statistic on `payload`. Refuses, naming `entry.id`, a tier 2
entry whose payload carries no pattern statistic (every Earth metric is scored on
pattern as well as a global mean). The verdict is `REPORT()` for a `report` entry or
one carrying no numeric bar; otherwise `PASS()` when the value, and the pattern
statistic where the payload carries one, are each within `entry.bar_half_width` of
their reference, and `FAIL()` otherwise.
"""
function judge(entry::Entry, payload::Payload)
    entry.tier == 2 && payload.pattern === nothing &&
        refuse("payload", entry.id,
              "a tier 2 entry is scored on pattern as well as a global mean, and this payload " *
              "states no pattern statistic")
    bar = entry.verdict_kind == "report" ? nothing : entry.bar_half_width
    verdict = if bar === nothing
        REPORT()
    else
        within_value = abs(payload.value - payload.reference) <= bar
        within_pattern = payload.pattern === nothing || abs(payload.pattern - payload.pattern_reference) <= bar
        (within_value && within_pattern) ? PASS() : FAIL()
    end
    return Result(entry.id, payload.value, payload.reference, payload.pattern, payload.pattern_reference,
                 entry.observation_uncertainty, verdict)
end

"""
    run(entry, artifact; sequence, instant, tier, oracle_data, input_data)

A method of `Base.run`. The verdict `entry`'s statistic reads on `artifact`, one of
`FAIL()`, `REPORT()` or `PASS()`, never a boolean.

Calls `admits(entry, artifact, StatisticValue())` first and raises when it refuses, so
a refused call returns, emits and reports nothing (decision 0025, amendment of
2026-09-13): an unregistered entry's value is refused on anything but a `Fixture`.
`artifact` is a `Fixture` wrapping a `Payload`, or a `Payload` model result; refuses
one that is neither. Resolves the payload's dataset hashes against the manifests
`entry.datasets` names, under `oracle_data` and `input_data`, and refuses a tier 2
entry with no pattern statistic (`resolve_payload`, `judge`).

Emits exactly one `oracle` journal event through `Events.emit`, the one emitter
(decision 0042), carrying `entry.id`, the verdict, the judged distance and the
threshold (`entry.bar_half_width`, or `NaN` where the entry states no numeric bar), at
`sequence`, `instant` and `tier`, from component "Oracles".
"""
function Base.run(entry::Entry, artifact; kwargs...)::OracleVerdict
    site = "Oracles.run"
    k, _ = read_keywords(site, values(kwargs), (:sequence, :instant, :tier, :oracle_data, :input_data), ())
    sequence = require_type("sequence", site, k.sequence, Integer)
    instant = require_type("instant", site, k.instant, Real)
    tier = require_type("tier", site, k.tier, Symbol)
    oracle_data = require_type("oracle_data", site, k.oracle_data, AbstractString)
    input_data = require_type("input_data", site, k.input_data, AbstractString)

    admits(entry, artifact, StatisticValue()) ||
        refuse("statistic value", entry.id, "an unregistered entry's value is refused on anything but a Fixture")
    unwrapped = artifact isa Fixture ? artifact.value : artifact
    payload = require_type("artifact", entry.id, unwrapped, Payload)
    resolve_payload(entry, payload, oracle_data, input_data)
    result = judge(entry, payload)

    Events.emit(Events.Event(Events.Oracle(), sequence, instant, tier, "Oracles",
                             Events.OraclePayload(registry_id = entry.id, verdict = result.verdict,
                                                  statistic = distance(result),
                                                  threshold = entry.bar_half_width === nothing ?
                                                              NaN : entry.bar_half_width)))
    return result.verdict
end

"""
    report(results)

The distance report of `results`, one line per `Result` in the order given: the
entry id, the model value, the reference, the reference's own uncertainty, the
distance from it in units of that uncertainty, and the verdict. The last two columns
print "n/a" for a `Result` carrying no uncertainty.
"""
function report(results::AbstractVector{Result})
    lines = String[]
    for r in results
        d = in_uncertainty(r)
        push!(lines, join((r.id, string(r.value), string(r.reference),
                          r.uncertainty === nothing ? "n/a" : string(r.uncertainty),
                          d === nothing ? "n/a" : string(d),
                          String(nameof(typeof(r.verdict)))), "  "))
    end
    return join(lines, "\n")
end
