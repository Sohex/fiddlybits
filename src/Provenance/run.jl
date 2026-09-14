# The run door: docs/plans/fiddlybits-52v.6-provenance.md, sections "The store" and
# "The journal"; decisions 0010, 0042 and 0046. One door opens a run: it writes the run
# record through the store's `open_run!` before it installs the journal under the
# directory that write named, so the runs layout is declared once, by the store, and a
# run `open_run!` refuses never gets a journal installed beside it.

using ..Systems: Checked, read_keywords, require_type

"""
    RunContext

What a run needs once `start_run!` has opened it: `run`, its `RunID`; `code`, the
`CodeVersion` it ran under; and `journal`, the `Journal` `install_journal!` installed as
the event sink.
"""
struct RunContext
    run::RunID
    code::CodeVersion
    journal::Journal
end

"""
    start_run!(store; run, code, system)

The one door that opens a run in `store`: writes the record of `run` through
`open_run!`, then installs its journal under the directory `open_run!` wrote that
record into, through `install_journal!`. Returns the `RunContext` holding `run`, `code`
and the installed `Journal`, so a refusal raised by anything assembled afterwards
(`Events.emit`'s installed sink is now this journal) is journalled.

Every keyword is required. Refuses whatever `open_run!` refuses, before a journal is
installed: a run `store` already records is refused with no journal installed, and its
existing record and journal, if it has one, are left untouched.
"""
function start_run!(store::Store; kwargs...)
    site = "Provenance.start_run!"
    k, _ = read_keywords(site, values(kwargs), (:run, :code, :system), ())
    run = require_type("run", site, k.run, RunID)
    code = require_type("code", site, k.code, CodeVersion)
    system = require_type("system", site, k.system, System)
    dir = open_run!(store; run = run, code = code, system = system)
    journal = install_journal!(runs = dirname(dir), run = run)
    return RunContext(run, code, journal)
end
