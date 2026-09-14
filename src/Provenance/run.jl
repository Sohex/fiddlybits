# The run door: docs/plans/fiddlybits-52v.6-provenance.md, sections "The store", "The writer"
# and "The journal"; decisions 0010, 0042 and 0046. `start_run!` writes the run record
# through `open_run!`, empties the device-move tally, then installs the journal under the
# directory that write named. `close_run!` appends the tally the run ended with to that record.

using ..Systems: read_keywords, require_type

"""
    RunContext

What a run needs once `start_run!` has opened it: `store`, the `Store` its record is in;
`run`, its `RunID`; `code`, the `CodeVersion` it ran under; and `journal`, the `Journal`
`install_journal!` installed as the event sink.
"""
struct RunContext
    store::Store
    run::RunID
    code::CodeVersion
    journal::Journal
end

"The key of the run record's table of device moves."
const MOVES_KEY = "moves"

"The run whose device moves `Events` is counting: the last one `start_run!` opened and `close_run!` has not closed, or `nothing`."
const TALLIED_RUN = Ref{Union{Nothing,RunID}}(nothing)

"""
    start_run!(store; run, code, system)

The one door that opens a run in `store`: writes the record of `run` through
`open_run!`, empties the device-move tally through `Events.reset_move_counts!` and names
`run` as the run it counts for, then installs its journal under the directory `open_run!`
wrote that record into, through `install_journal!`. Returns the `RunContext` holding
`store`, `run`, `code` and the installed `Journal`, so a refusal raised by anything
assembled afterwards (`Events.emit`'s installed sink is now this journal) is journalled.

Every keyword is required. Refuses whatever `open_run!` refuses, before the tally is
emptied or a journal is installed: a run `store` already records is refused with the
tally and the installed journal as they were, and its existing record and journal, if it
has one, are left untouched.
"""
function start_run!(store::Store; kwargs...)
    site = "Provenance.start_run!"
    k, _ = read_keywords(site, values(kwargs), (:run, :code, :system), ())
    run = require_type("run", site, k.run, RunID)
    code = require_type("code", site, k.code, CodeVersion)
    system = require_type("system", site, k.system, System)
    dir = open_run!(store; run = run, code = code, system = system)
    Events.reset_move_counts!()
    TALLIED_RUN[] = run
    journal = install_journal!(runs = dirname(dir), run = run)
    return RunContext(store, run, code, journal)
end

"""
    moves_text(counts)

The TOML text of the device-move tally `counts`, a `Dict` from `(from, to)` to a count as
`Events.move_counts` returns it: one table under `MOVES_KEY` holding, for each `from`, a
table from each `to` to its count, keys sorted. An empty tally is the empty table.
"""
function moves_text(counts::Dict{Tuple{Symbol,Symbol},Int})
    table = Dict{String,Any}()
    for ((from, to), n) in counts
        get!(Dict{String,Any}, table, String(from))[String(to)] = n
    end
    io = IOBuffer()
    TOML.print(io, Dict{String,Any}(MOVES_KEY => table); sorted = true)
    return String(take!(io))
end

"""
    close_run!(ctx::RunContext)

The door that closes the run `ctx` names: appends `moves_text(Events.move_counts())` to
its run record, so the record holds under `MOVES_KEY` the moves counted since
`start_run!` opened it, `moves.<from>.<to>` the count from backend `from` to backend
`to`. Leaves every other key of the record as `open_run!` wrote it, and the installed
journal and the tally in place. Names no run as the one the tally counts for.

Refuses, before appending anything: a run the store does not record under `ctx.code`; a
record that already holds `MOVES_KEY`, which is a run already closed; and a run other
than the last one `start_run!` opened, whose moves the tally no longer holds.
"""
function close_run!(ctx::RunContext)
    site = "Provenance.close_run!"
    require_run(ctx.store, ctx.run, ctx.code, site)
    path = joinpath(run_directory(ctx.store, ctx.run), RUN_RECORD)
    haskey(TOML.parsefile(path), MOVES_KEY) &&
        refuse("run", site, "the run $(ctx.run.uuid) is already closed: $(path) holds $(MOVES_KEY)")
    TALLIED_RUN[] == ctx.run || refuse(
        "run", site,
        "the device-move tally counts for $(TALLIED_RUN[] === nothing ? "no run" : TALLIED_RUN[].uuid), " *
        "not the run $(ctx.run.uuid)")
    text = moves_text(Events.move_counts())
    open(io -> write(io, text), path, "a")
    TALLIED_RUN[] = nothing
    return nothing
end
