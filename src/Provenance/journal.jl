# The run event journal: docs/plans/fiddlybits-52v.6-provenance.md, section "The journal";
# decisions 0042 and 0046. One `Journal` is the event sink `install_journal!` hands to
# `Events.sink!`; it appends each event it is handed to one TOML file under the run's
# `RunID`, as one `[[event]]` table holding the header's fields and a `payload` table.
# The journal assigns nothing: every header field is the emitter's. `read_journal`
# returns the records in the order `journal_order` gives, which reads the record and
# never the position it was appended at.

using TOML: TOML
using ..Events: Events, Journal
using ..Mesh: Mesh
using ..Verdicts: Verdicts, refuse
using ..Systems: read_keywords, require_type

"The name of the journal file inside the directory named by a run's `RunID`."
const JOURNAL_PATH = "journal.toml"

"The site every refusal of the journal writer names."
const JOURNAL_SITE = "Provenance.Journal"

"The key of the payload table inside an `[[event]]` table."
const PAYLOAD_KEY = "payload"

"The key of the array of event tables in a journal file."
const EVENT_KEY = "event"

"""
    journal_file(runs, run)

The journal file of the run `run` under the directory `runs`: `JOURNAL_PATH` inside the
directory named by the text of `run.uuid`.
"""
journal_file(runs::AbstractString, run::RunID) = joinpath(runs, string(run.uuid), JOURNAL_PATH)

"""
    install_journal!(; runs, run)

Creates the directory of `journal_file(runs, run)` and the file, empty, when either is
absent, leaving an existing file's contents in place; installs a `Journal` on that file
as the event sink through `Events.sink!`; and returns it. Installs nothing through
`Events.move_sink!`. Every keyword is required. Refuses a `runs` that is not a `String`
naming an existing directory, and a `run` that is not a `RunID`.
"""
function install_journal!(; kwargs...)
    site = "Provenance.install_journal!"
    k, _ = read_keywords(site, values(kwargs), (:runs, :run), ())
    runs = require_type("runs", site, k.runs, String)
    run = require_type("run", site, k.run, RunID)
    isdir(runs) || refuse("runs", site, "$(runs) is not a directory")
    file = journal_file(runs, run)
    mkpath(dirname(file))
    touch(file)
    journal = Journal(file)
    Events.sink!(journal)
    return journal
end

"""
    disk_value(field, x)

The TOML value `x` is written as in the journal, `field` the name of the field holding
it: a `String`, an `Int` or a `Float64` as itself; a `Symbol` as its text; a `Kind` as
its vocabulary word from `Events.name`; a `Tuple{Float64,Float64}` as an array of its
two values in order; a `Verdicts.LoopVerdict` or a `Verdicts.OracleVerdict` as the name
of its type; a `Base.IEEEFloat` type as its name; a `Vector{Mesh.CellId}` as the array
of the `CellId` values, the 0-based disk integers, in order. Refuses at `JOURNAL_SITE`,
naming `field`, a value of any other type, a vector of any other element type among
them.
"""
disk_value(::Symbol, x::String) = x
disk_value(::Symbol, x::Int) = x
disk_value(::Symbol, x::Float64) = x
disk_value(::Symbol, x::Symbol) = String(x)
disk_value(::Symbol, x::Events.Kind) = String(Events.name(x))
disk_value(::Symbol, x::Tuple{Float64,Float64}) = Float64[first(x), last(x)]
disk_value(::Symbol, x::Verdicts.LoopVerdict) = String(nameof(typeof(x)))
disk_value(::Symbol, x::Verdicts.OracleVerdict) = String(nameof(typeof(x)))
disk_value(::Symbol, x::Type{<:Base.IEEEFloat}) = String(nameof(x))
disk_value(::Symbol, cells::Vector{Mesh.CellId}) = Int[c.value for c in cells]
disk_value(field::Symbol, cells::Vector) = refuse(
    String(field), JOURNAL_SITE,
    "a $(typeof(cells)) has no journal form; cells cross to the journal as Vector{Mesh.CellId}, " *
    "written as their 0-based disk integers")
disk_value(field::Symbol, x) = refuse(
    String(field), JOURNAL_SITE, "a $(typeof(x)) has no journal form")

"""
    table_of(x)

A `Dict` from the name of each field of `x` to `disk_value` of its value.
"""
table_of(x) = Dict{String,Any}(String(f) => disk_value(f, getfield(x, f)) for f in fieldnames(typeof(x)))

"""
    record_text(event)

The TOML text of `event`: one `[[event]]` table holding `table_of(event.header)` and,
under `PAYLOAD_KEY`, `table_of(event.payload)`, every key in sorted order. Refuses what
`disk_value` refuses.
"""
function record_text(event::Events.Event)
    table = table_of(event.header)
    table[PAYLOAD_KEY] = table_of(event.payload)
    io = IOBuffer()
    TOML.print(io, Dict(EVENT_KEY => [table]); sorted = true)
    return String(take!(io))
end

"""
    (journal::Events.Journal)(event::Events.Event)

Appends `record_text(event)` to `journal.file` in one write, the file opened for
appending and closed again while `journal.lock` is held. The text is built before the
lock is taken, so a refused event appends nothing.
"""
function (journal::Events.Journal)(event::Events.Event)
    text = record_text(event)
    lock(journal.lock) do
        open(io -> write(io, text), journal.file, "a")
    end
    return nothing
end

"""
    journal_order(record)

The key `read_journal` sorts a parsed `[[event]]` table by: its instant, tier,
component, sequence number and kind, then its text by `TOML.print` with sorted keys.
"""
function journal_order(record::AbstractDict)
    io = IOBuffer()
    TOML.print(io, record; sorted = true)
    return (record["instant"], record["tier"], record["component"], record["sequence"],
            record["kind"], String(take!(io)))
end

"""
    read_journal(file)

The `[[event]]` tables of the journal `file`, parsed, in `journal_order`. Refuses a
file holding a top-level key other than `EVENT_KEY`.
"""
function read_journal(file::AbstractString)
    parsed = TOML.parsefile(file)
    for key in keys(parsed)
        key == EVENT_KEY || refuse(key, "Provenance.read_journal",
                                   "$(file) holds the key $(key), and a journal holds only $(EVENT_KEY)")
    end
    records = Dict{String,Any}[r for r in get(parsed, EVENT_KEY, Any[])]
    return sort!(records; by = journal_order)
end
