# The registry loader and the registration rule: docs/plans/fiddlybits-52v.8-oracles.md,
# sections "The loader" and "The registration rule as a build check"; decision 0025
# (amendment of 2026-09-13); docs/oracles/README.md, Registration.

using TOML
using ..Verdicts: refuse

"The registry file, relative to a repository root."
const REGISTRY_PATH = "docs/oracles/registry.toml"

"The decision record whose amendment the history check reads from, relative to a repository root."
const DECISION_PATH = "docs/decisions/0025-three-oracle-tiers.md"

"The opening words of the amendment line of `DECISION_PATH` whose commit the history check reads from."
const AMENDMENT = "2026-09-13: the registration rule states the invariant it protects"

"The tables a registry file may hold."
const TABLES = ("oracle", "protocol", "instrument")

"The keys every `[[oracle]]` entry carries."
const REQUIRED_KEYS = ("id", "tier", "subsystem", "dataset_or_reference", "source_kind", "statistic",
                       "verdict_kind", "threshold", "provisional", "registered_at", "holdout", "anchors")

"The keys an `[[oracle]]` entry may carry besides `REQUIRED_KEYS`."
const OPTIONAL_KEYS = ("instances", "protocol", "datasets", "depends_on", "instrument",
                       "bar_half_width", "observation_uncertainty")

"The keys every `[[protocol]]` entry carries, and no other."
const PROTOCOL_KEYS = ("id", "system", "normalisation")

"The tiers an entry may carry."
const TIERS = (1, 2, 3)

"The source kinds an entry may carry."
const SOURCE_KINDS = ("identity", "conservation", "analytic", "known quantity", "published spread")

"The verdict kinds an entry may carry."
const VERDICT_KINDS = ("fail_bar", "report")

"The fields a registration fixes: an entry is registered when its `registered_at` commit holds these as loaded."
const REGISTERED_FIELDS = ("statistic", "verdict_kind", "threshold", "holdout")

"The path prefixes a commit re-registering a tier-2 or tier-3 entry touches none of."
const REREGISTRATION_BARRED = ("src/", "notes/findings/")

"A registered_at value naming a commit: forty lowercase hexadecimal digits."
const COMMIT_ID = r"^[0-9a-f]{40}$"

"""
    Malformed(site, reason)

A place a registry, its history or a source tree breaks a clause of the loader or of the
registration rule: the entry, commit or file it is at, and what is wrong.
"""
struct Malformed
    site::String
    reason::String
end

Base.show(io::IO, m::Malformed) = print(io, m.site, ": ", m.reason)

"""
    Protocol

A `[[protocol]]` entry: its id, its system as `Sourced` constructor calls, and the
normalisation the protocol held fixed.
"""
struct Protocol
    id::String
    system::String
    normalisation::String
end

"""
    Entry

An `[[oracle]]` entry as loaded from the registry file at `registry`. `instances`,
`protocol`, `datasets`, `depends_on`, `instrument`, `bar_half_width` and
`observation_uncertainty` are `nothing` where the entry does not carry the key.
`bar_half_width` and `observation_uncertainty` are the half-width of the bar and the
observation's own uncertainty, in the unit of the statistic.
"""
struct Entry
    id::String
    tier::Int
    subsystem::String
    dataset_or_reference::String
    source_kind::String
    statistic::String
    verdict_kind::String
    threshold::String
    provisional::Bool
    registered_at::String
    holdout::Bool
    anchors::Vector{String}
    instances::Union{Nothing,Vector{String}}
    protocol::Union{Nothing,String}
    datasets::Union{Nothing,Vector{String}}
    depends_on::Union{Nothing,Vector{String}}
    instrument::Union{Nothing,String}
    bar_half_width::Union{Nothing,Float64}
    observation_uncertainty::Union{Nothing,Float64}
    registry::String
end

"""
    Registry

Every entry and protocol of the registry file at `path`, in file order.
"""
struct Registry
    path::String
    entries::Vector{Entry}
    protocols::Vector{Protocol}
end

"Whether `v` is a TOML string."
is_text(v) = v isa String

"Whether `v` is a TOML integer."
is_integer(v) = v isa Int64

"Whether `v` is a TOML boolean."
is_flag(v) = v isa Bool

"Whether `v` is a TOML array of strings."
is_texts(v) = v isa AbstractVector && all(is_text, v)

"Whether `v` is a TOML number: an integer or a float."
is_number(v) = v isa Int64 || v isa Float64

"""
    read_key(row, key, accepts, shape, site, found)

The value of `key` in `row` when `accepts` holds for it; otherwise `nothing`, with a
problem added to `found` naming the key and the `shape` it should have. A key the row
does not carry reads `nothing` and adds nothing.
"""
function read_key(row::AbstractDict, key::AbstractString, accepts::Function, shape::AbstractString,
                  site::AbstractString, found::Vector{Malformed})
    haskey(row, key) || return nothing
    v = row[key]
    accepts(v) && return v
    push!(found, Malformed(site, key * " is not " * shape))
    return nothing
end

"The strings of TOML array `v`, or `nothing`."
texts(v) = v === nothing ? nothing : String[String(x) for x in v]

"""
    read_protocols(doc, path, found)

Every `[[protocol]]` entry of `doc` that carries exactly `PROTOCOL_KEYS`, each a
string; a protocol missing one, carrying another key, or reusing an id adds a problem
to `found` and is not returned.
"""
function read_protocols(doc::AbstractDict, path::AbstractString, found::Vector{Malformed})
    out = Protocol[]
    tables = get(doc, "protocol", Any[])
    if !(tables isa AbstractVector && all(t -> t isa AbstractDict, tables))
        push!(found, Malformed(path, "protocol is not an array of tables"))
        return out
    end
    for (k, p) in enumerate(tables)
        site = let id = get(p, "id", nothing); is_text(id) ? id : path * " protocol " * string(k) end
        bad = length(found)
        for key in sort!(collect(keys(p)))
            key in PROTOCOL_KEYS || push!(found, Malformed(site, "protocol carries " * key * ", which is not a protocol field"))
        end
        values = String[]
        for key in PROTOCOL_KEYS
            if !haskey(p, key)
                push!(found, Malformed(site, "protocol carries no " * key))
            elseif is_text(p[key])
                push!(values, p[key])
            else
                push!(found, Malformed(site, "protocol " * key * " is not a string"))
            end
        end
        if length(found) == bad
            if any(q -> q.id == values[1], out)
                push!(found, Malformed(site, "protocol id is used more than once"))
            else
                push!(out, Protocol(values[1], values[2], values[3]))
            end
        end
    end
    return out
end

"""
    read_entry(row, k, path, protocols, index, found)

The `Entry` row `row` (the `k`th of the file at `path`) describes, or `nothing` with
every problem that stops it added to `found`. The problems are: a required key absent
or of the wrong type, a key that is not a registry field, a tier, source kind or
verdict kind outside its closed set, a registered_at that is neither empty nor a
commit id, a tier-1 `system.*` entry naming no instances, a tier-3 entry naming no
protocol, a protocol that is not declared, a tier-2 or tier-3 entry with no anchors, a
bar or uncertainty stated without the other or not positive, a bar narrower than its
observation's uncertainty, and, when `index` is not `nothing`, an anchor that is not a
key of `index`.
"""
function read_entry(row, k::Integer, path::AbstractString, protocols::Vector{Protocol},
                    index::Union{Nothing,AbstractDict}, found::Vector{Malformed})
    if !(row isa AbstractDict)
        push!(found, Malformed(path * " oracle " * string(k), "is not a table"))
        return nothing
    end
    site = let id = get(row, "id", nothing); is_text(id) ? id : path * " oracle " * string(k) end
    bad = length(found)

    for key in sort!(collect(keys(row)))
        key in REQUIRED_KEYS || key in OPTIONAL_KEYS ||
            push!(found, Malformed(site, "carries " * key * ", which is not a registry field"))
    end
    for key in REQUIRED_KEYS
        haskey(row, key) || push!(found, Malformed(site, "carries no " * key))
    end

    id = read_key(row, "id", is_text, "a string", site, found)
    tier = read_key(row, "tier", is_integer, "an integer", site, found)
    subsystem = read_key(row, "subsystem", is_text, "a string", site, found)
    reference = read_key(row, "dataset_or_reference", is_text, "a string", site, found)
    source_kind = read_key(row, "source_kind", is_text, "a string", site, found)
    statistic = read_key(row, "statistic", is_text, "a string", site, found)
    verdict_kind = read_key(row, "verdict_kind", is_text, "a string", site, found)
    threshold = read_key(row, "threshold", is_text, "a string", site, found)
    provisional = read_key(row, "provisional", is_flag, "a boolean", site, found)
    registered_at = read_key(row, "registered_at", is_text, "a string", site, found)
    holdout = read_key(row, "holdout", is_flag, "a boolean", site, found)
    anchors = texts(read_key(row, "anchors", is_texts, "an array of strings", site, found))
    instances = texts(read_key(row, "instances", is_texts, "an array of strings", site, found))
    protocol = read_key(row, "protocol", is_text, "a string", site, found)
    datasets = texts(read_key(row, "datasets", is_texts, "an array of strings", site, found))
    depends_on = texts(read_key(row, "depends_on", is_texts, "an array of strings", site, found))
    instrument = read_key(row, "instrument", is_text, "a string", site, found)
    bar = read_key(row, "bar_half_width", is_number, "a number", site, found)
    uncertainty = read_key(row, "observation_uncertainty", is_number, "a number", site, found)

    tier === nothing || tier in TIERS ||
        push!(found, Malformed(site, "tier " * string(tier) * " is not one of " * join(TIERS, ", ")))
    source_kind === nothing || source_kind in SOURCE_KINDS ||
        push!(found, Malformed(site, "source_kind " * repr(source_kind) * " is not one of " * join(SOURCE_KINDS, ", ")))
    verdict_kind === nothing || verdict_kind in VERDICT_KINDS ||
        push!(found, Malformed(site, "verdict_kind " * repr(verdict_kind) * " is not one of " * join(VERDICT_KINDS, ", ")))
    registered_at === nothing || isempty(registered_at) || occursin(COMMIT_ID, registered_at) ||
        push!(found, Malformed(site, "registered_at " * repr(registered_at) * " is neither empty nor a forty-digit commit id"))

    if tier == 1 && id !== nothing && startswith(id, "system.") && (instances === nothing || isempty(instances))
        push!(found, Malformed(site, "a tier 1 system.* entry names no instances"))
    end
    if tier == 3 && protocol === nothing && !haskey(row, "protocol")
        push!(found, Malformed(site, "a tier 3 entry names no protocol"))
    end
    if protocol !== nothing && !any(p -> p.id == protocol, protocols)
        push!(found, Malformed(site, "names protocol " * protocol * ", which is not declared"))
    end
    if (tier == 2 || tier == 3) && anchors !== nothing && isempty(anchors)
        push!(found, Malformed(site, "a tier " * string(tier) * " entry with no anchors"))
    end
    if index !== nothing && anchors !== nothing
        for a in anchors
            haskey(index, a) ||
                push!(found, Malformed(site, "anchor " * repr(a) * " resolves to no row of the references index"))
        end
    end

    if haskey(row, "bar_half_width") != haskey(row, "observation_uncertainty")
        push!(found, Malformed(site, haskey(row, "bar_half_width") ?
                                     "states bar_half_width with no observation_uncertainty" :
                                     "states observation_uncertainty with no bar_half_width"))
    end
    for (key, v) in (("bar_half_width", bar), ("observation_uncertainty", uncertainty))
        v === nothing || v > 0 || push!(found, Malformed(site, key * " " * string(v) * " is not positive"))
    end
    if bar !== nothing && uncertainty !== nothing && bar < uncertainty
        push!(found, Malformed(site, "a bar narrower than its observation's uncertainty: bar_half_width " *
                                     string(bar) * " below observation_uncertainty " * string(uncertainty)))
    end

    length(found) == bad || return nothing
    return Entry(id, tier, subsystem, reference, source_kind, statistic, verdict_kind, threshold, provisional,
                 registered_at, holdout, anchors, instances, protocol, datasets, depends_on, instrument,
                 bar === nothing ? nothing : Float64(bar),
                 uncertainty === nothing ? nothing : Float64(uncertainty), String(path))
end

"""
    read_registry(path, index)

`(registry, found)`: the `Registry` the file at `path` holds and every problem that
stops an entry or protocol loading. When `index` is not `nothing` it maps each row of the
references index to its status, and `found` also carries every anchor that is not a key
of `index` and every anchor of a `registered` entry whose status is not `read`.
`registry` is `nothing` when `found` is not empty.
"""
function read_registry(path::AbstractString, index::Union{Nothing,AbstractDict})
    found = Malformed[]
    doc = try
        TOML.parsefile(path)
    catch err
        err isa TOML.ParserError || rethrow()
        push!(found, Malformed(path, "does not parse as TOML: " * sprint(showerror, err)))
        return nothing, found
    end
    for key in sort!(collect(keys(doc)))
        key in TABLES || push!(found, Malformed(path, "carries " * key * ", which is not a registry table"))
    end
    protocols = read_protocols(doc, path, found)
    rows = get(doc, "oracle", nothing)
    entries = Entry[]
    if !(rows isa AbstractVector)
        push!(found, Malformed(path, "carries no [[oracle]] entries"))
    else
        for (k, row) in enumerate(rows)
            e = read_entry(row, k, path, protocols, index, found)
            e === nothing && continue
            if any(x -> x.id == e.id, entries)
                push!(found, Malformed(e.id, "entry id is used more than once"))
            else
                push!(entries, e)
            end
        end
    end
    if index !== nothing
        for e in entries
            isempty(e.registered_at) && continue
            registered(e) || continue
            for a in e.anchors
                haskey(index, a) || continue
                status = index[a]
                status == "read" ||
                    push!(found, Malformed(e.id, "registered on anchor " * repr(a) * ", whose references index row is " * status))
            end
        end
    end
    isempty(found) || return nothing, sort(found; by = m -> (m.site, m.reason))
    return Registry(String(path), entries, protocols), found
end

"""
    problems(path, index)

Every problem the registry file at `path` carries, sorted: each one `load` refuses it
for, each anchor that is not a key of `index`, and each anchor of a `registered` entry
whose status in `index` is not `read`. `index` maps each row of the references index to
its status.
"""
problems(path::AbstractString, index::AbstractDict) = last(read_registry(path, index))

"""
    load(path)

The `Registry` the file at `path` holds. Refuses, naming every problem, when any entry or
protocol does not load; no entry is skipped. Anchors are not resolved here; `problems`
resolves them against the references index.
"""
function load(path::AbstractString)
    registry, found = read_registry(path, nothing)
    isempty(found) || refuse("registry", path, string(length(found), " problems: ", join(string.(found), "; ")))
    return registry
end

"""
    entry(registry, id)

The entry of `registry` with id `id`. Refuses an id the registry does not hold.
"""
function entry(registry::Registry, id::AbstractString)
    k = findfirst(e -> e.id == id, registry.entries)
    k === nothing && refuse("oracle entry", registry.path, id * " is not an entry of the registry")
    return registry.entries[k]
end

"""
    protocol(registry, e)

The `Protocol` entry `e` names, or `nothing` when `e` names none.
"""
function protocol(registry::Registry, e::Entry)
    e.protocol === nothing && return nothing
    k = findfirst(p -> p.id == e.protocol, registry.protocols)
    k === nothing && refuse("protocol", e.id, e.protocol * " is not a protocol of " * registry.path)
    return registry.protocols[k]
end

"""
    dependencies(registry, e)

The entries `e` names in `depends_on`, in order; empty when it names none. Refuses an id
the registry does not hold.
"""
dependencies(registry::Registry, e::Entry) =
    e.depends_on === nothing ? Entry[] : Entry[entry(registry, d) for d in e.depends_on]

"The variables `git rev-parse --local-env-vars` names, read once per process."
const LOCAL_ENV_VARS = Ref{Union{Nothing,Set{String}}}(nothing)

"The set `LOCAL_ENV_VARS` holds, reading it from git on first use."
function local_env_vars()
    held = LOCAL_ENV_VARS[]
    held === nothing || return held
    read_now = Set{String}(split(read(`git rev-parse --local-env-vars`, String)))
    LOCAL_ENV_VARS[] = read_now
    return read_now
end

"""
    git_command(repo, args)

`git -C repo` with `args`, run with `LC_ALL=C` and `LANGUAGE` cleared, in this process's
environment less every variable `local_env_vars` names, so the repository it acts on is
the one at `repo`.
"""
function git_command(repo::AbstractString, args::Cmd)
    located = local_env_vars()
    env = Dict{String,String}(k => v for (k, v) in ENV if !(k in located))
    env["LC_ALL"] = "C"
    env["LANGUAGE"] = ""
    return setenv(`git -C $(repo) $(args)`, env)
end

"""
    git_run(repo, args; accept)

`(status, stdout)` of `git_command(repo, args)`. Refuses, with git's stderr, when the
exit status is not in `accept`.
"""
function git_run(repo::AbstractString, args::Cmd; accept = (0,))
    out = IOBuffer()
    err = IOBuffer()
    p = run(pipeline(ignorestatus(git_command(repo, args)); stdout = out, stderr = err))
    p.exitcode in accept ||
        refuse("git", repo, "git " * join(args.exec, " ") * " exited " * string(p.exitcode) * ": " * String(take!(err)))
    return p.exitcode, String(take!(out))
end

"The standard output of `git_command(repo, args)`; refuses a non-zero exit."
git_read(repo::AbstractString, args::Cmd) = last(git_run(repo, args))

"Whether commit `a` is `b` or an ancestor of it in `repo`."
is_ancestor(repo::AbstractString, a::AbstractString, b::AbstractString) =
    first(git_run(repo, `merge-base --is-ancestor $(a) $(b)`; accept = (0, 1))) == 0

"Whether `rev` names a commit of `repo`."
is_commit(repo::AbstractString, rev::AbstractString) =
    first(git_run(repo, `cat-file -e $(rev)^\{commit\}`; accept = (0, 1, 128))) == 0

"The first eight digits of commit id `sha`."
short(sha::AbstractString) = first(sha, 8)

"""
    RowCache(repo, path)

The `[[oracle]]` rows of the registry file at `path` (relative to `repo`) at each commit
read, by id, cached by the blob the commit holds there.
"""
struct RowCache
    repo::String
    path::String
    blobs::Dict{String,Dict{String,Any}}
end

RowCache(repo::AbstractString, path::AbstractString) = RowCache(String(repo), String(path), Dict{String,Dict{String,Any}}())

"""
    rows_at(cache, commit)

The rows of the registry at `commit`, by id; empty when the commit holds no registry.
Refuses a registry that does not parse, and one using an id twice.
"""
function rows_at(cache::RowCache, commit::AbstractString)
    status, out = git_run(cache.repo, `rev-parse --verify --quiet $(commit):$(cache.path)`; accept = (0, 1))
    status == 0 || return Dict{String,Any}()
    blob = strip(out)
    return get!(cache.blobs, blob) do
        text = git_read(cache.repo, `cat-file blob $(blob)`)
        doc = try
            TOML.parse(text)
        catch err
            err isa TOML.ParserError || rethrow()
            refuse("registry", short(commit) * ":" * cache.path, "does not parse as TOML: " * sprint(showerror, err))
        end
        rows = Dict{String,Any}()
        for row in get(doc, "oracle", Any[])
            id = get(row, "id", nothing)
            is_text(id) || continue
            haskey(rows, id) && refuse("registry", short(commit) * ":" * cache.path, id * " is used more than once")
            rows[id] = row
        end
        rows
    end
end

"The values of `REGISTERED_FIELDS` in a registry row."
registered_fields(row::AbstractDict) = Tuple(get(row, k, nothing) for k in REGISTERED_FIELDS)

"The values of `REGISTERED_FIELDS` in an entry."
registered_fields(e::Entry) = Tuple(getfield(e, Symbol(k)) for k in REGISTERED_FIELDS)

"""
    registered(e)

Whether `e` is registered: its `registered_at` names a commit, an ancestor of the
repository's HEAD, at which the registry file `e` was loaded from holds an entry of the
same id whose statistic, verdict_kind, threshold and holdout equal `e`'s. An empty
`registered_at` reads false without git. Refuses a `registered_at` that names no commit
of the repository or one that is not an ancestor of HEAD.
"""
function registered(e::Entry)
    isempty(e.registered_at) && return false
    file = realpath(e.registry)
    repo = realpath(strip(git_read(dirname(file), `rev-parse --show-toplevel`)))
    is_commit(repo, e.registered_at) ||
        refuse("registered_at", e.id, e.registered_at * " names no commit of " * repo)
    is_ancestor(repo, e.registered_at, "HEAD") ||
        refuse("registered_at", e.id, e.registered_at * " is not an ancestor of HEAD in " * repo)
    row = get(rows_at(RowCache(repo, relpath(file, repo)), e.registered_at), e.id, nothing)
    return row !== nothing && registered_fields(row) == registered_fields(e)
end

"""
    Use

What a caller reads from an entry's statistic: `StatisticValue`, `Evaluates` or
`ArmDifference`.
"""
abstract type Use end

"The statistic's value, with any distance, verdict or threshold comparison made from it."
struct StatisticValue <: Use end

"Whether the statistic evaluates."
struct Evaluates <: Use end

"The difference between two arms of one configuration."
struct ArmDifference <: Use end

"""
    Fixture(value)

A value a test constructs with its answer known. `fixture_constructions` refuses a
construction of it under `src/`.
"""
struct Fixture{T}
    value::T
end

"""
    admits(e, x, use)

Whether the runner may read `use` from `e`'s statistic evaluated on `x`. The value is
admitted on a `Fixture`, and on anything else only when `e` is `registered`;
evaluability and the arm difference are admitted on either.
"""
admits(e::Entry, x, use::StatisticValue) = x isa Fixture || registered(e)
admits(e::Entry, x, use::Evaluates) = true
admits(e::Entry, x, use::ArmDifference) = true

"Whether `f`, the callee of a call, names `Fixture`: bare, qualified, or with type parameters."
function names_fixture(f)
    f === :Fixture && return true
    f isa Expr || return false
    f.head === :. && length(f.args) == 2 && f.args[2] isa QuoteNode && return f.args[2].value === :Fixture
    f.head === :curly && return names_fixture(f.args[1])
    return false
end

"""
    constructions!(found, ex, site, line)

Adds a problem to `found` for each call of `Fixture`, plain or broadcast, in expression
`ex` of file `site`, and one for each part of `ex` that did not parse. Returns the last
line number seen, starting from `line`.
"""
function constructions!(found::Vector{Malformed}, ex, site::AbstractString, line::Integer)
    ex isa LineNumberNode && return ex.line
    ex isa Expr || return line
    if ex.head === :error || ex.head === :incomplete
        push!(found, Malformed(site * ":" * string(line), "does not parse"))
    elseif ex.head === :call && names_fixture(ex.args[1])
        push!(found, Malformed(site * ":" * string(line), "constructs Fixture; only test/ constructs a Fixture"))
    elseif ex.head === :. && length(ex.args) == 2 && ex.args[2] isa Expr && ex.args[2].head === :tuple &&
           names_fixture(ex.args[1])
        push!(found, Malformed(site * ":" * string(line), "constructs Fixture; only test/ constructs a Fixture"))
    end
    for a in ex.args
        line = constructions!(found, a, site, line)
    end
    return line
end

"""
    fixture_constructions(root)

Every construction of `Fixture`, and every file that does not parse, among the `.jl`
files under directory `root`, sorted. Refuses a `root` that is not a directory.
"""
function fixture_constructions(root::AbstractString)
    isdir(root) || refuse("source tree", root, "is not a directory")
    found = Malformed[]
    for (dir, _, names) in walkdir(root), name in names
        endswith(name, ".jl") || continue
        path = joinpath(dir, name)
        site = relpath(path, root)
        constructions!(found, Meta.parseall(read(path, String); filename = site), site, 0)
    end
    return sort(found; by = m -> (m.site, m.reason))
end

"A commit of the history check: its id, its parents, and the paths it changes against its first parent."
struct Commit
    sha::String
    parents::Vector{String}
    touched::Vector{String}
end

"A registration: the entry, the commit recording it, and the verdict kind, anchors and datasets it fixed."
struct Registration
    id::String
    commit::String
    verdict_kind::Any
    anchors::Any
    datasets::Any
end

"""
    amendment_commit(repo)

The first commit, in HEAD's history, whose change to `DECISION_PATH` adds `AMENDMENT`.
Refuses a shallow repository and a history with no such commit.
"""
function amendment_commit(repo::AbstractString)
    strip(git_read(repo, `rev-parse --is-shallow-repository`)) == "false" ||
        refuse("registration history", repo, "is a shallow clone, and the history check reads from the commit carrying " *
                                             "the amendment of " * DECISION_PATH)
    hits = split(strip(git_read(repo, `log --reverse --format=%H -S$(AMENDMENT) HEAD -- $(DECISION_PATH)`)))
    isempty(hits) &&
        refuse("registration history", repo, "no commit of HEAD's history adds " * repr(AMENDMENT) * " to " * DECISION_PATH)
    return String(first(hits))
end

"""
    commits_from(repo, anchor)

Every commit of HEAD's history that is not an ancestor of a parent of `anchor`, parents
before children, each with the paths it changes against its first parent.
"""
function commits_from(repo::AbstractString, anchor::AbstractString)
    text = git_read(repo, `-c core.quotePath=false log --reverse --topo-order --no-renames --diff-merges=first-parent
                            --name-only --format=%x01%H%x20%P HEAD --not $(anchor)^@`)
    out = Commit[]
    for block in split(text, '\x01'; keepempty = false)
        lines = split(block, '\n'; keepempty = false)
        isempty(lines) && continue
        ids = split(lines[1])
        push!(out, Commit(String(ids[1]), String.(ids[2:end]), String.(strip.(lines[2:end]))))
    end
    return out
end

"The paths commit `sha` of `repo` changes against its first parent."
touched(repo::AbstractString, sha::AbstractString) =
    String.(split(git_read(repo, `-c core.quotePath=false log -1 --no-renames --diff-merges=first-parent
                                   --name-only --format= $(sha)`); keepempty = false))

"""
    testset_files(repo, sha, id)

The paths under `test/` at commit `sha` holding a testset named `id`: a `@testset` whose
name is `id` or opens with `id` and a colon.
"""
function testset_files(repo::AbstractString, sha::AbstractString, id::AbstractString)
    pattern = "@testset \"" * replace(id, "." => "\\.") * "[\":]"
    _, out = git_run(repo, `grep -l -E $(pattern) $(sha) -- test/`; accept = (0, 1))
    return String[String(split(l, ':'; limit = 2)[2]) for l in split(out, '\n'; keepempty = false)]
end

"""
    judge_registration!(found, r, row, earlier, paths)

Adds a problem to `found` for each clause registration `r` of `row` breaks, given the
entry's `earlier` registrations and the `paths` changed by the commits recording and
naming it: a tier-2 or tier-3 entry registered again with its anchors and datasets as
at its last registration, or beside a change under `REREGISTRATION_BARRED`; a fail_bar
registration of an entry once registered as report; and a tier-2 or tier-3 fail_bar
registration stating no bar and uncertainty, or a bar narrower than its uncertainty.
"""
function judge_registration!(found::Vector{Malformed}, r::Registration, row::AbstractDict,
                             earlier::Vector{Registration}, paths::Vector{String})
    site = r.id * " at " * short(r.commit)
    tier = get(row, "tier", nothing)
    if (tier == 2 || tier == 3) && !isempty(earlier)
        last_one = earlier[end]
        r.anchors == last_one.anchors && r.datasets == last_one.datasets &&
            push!(found, Malformed(site, "a tier " * string(tier) * " entry registered again with its anchors and datasets " *
                                         "unchanged since its registration at " * short(last_one.commit)))
        barred = sort!(unique(filter(p -> any(b -> startswith(p, b), REREGISTRATION_BARRED), paths)))
        isempty(barred) ||
            push!(found, Malformed(site, "a tier " * string(tier) * " entry registered again in a commit touching " *
                                         join(barred, ", ")))
    end
    if r.verdict_kind == "fail_bar"
        k = findfirst(e -> e.verdict_kind == "report", earlier)
        k === nothing ||
            push!(found, Malformed(site, "registered as fail_bar, and registered as report at " * short(earlier[k].commit)))
    end
    if (tier == 2 || tier == 3) && r.verdict_kind == "fail_bar"
        bar = get(row, "bar_half_width", nothing)
        uncertainty = get(row, "observation_uncertainty", nothing)
        if !(is_number(bar) && is_number(uncertainty))
            push!(found, Malformed(site, "a tier " * string(tier) * " fail_bar entry registered with no bar_half_width " *
                                         "and observation_uncertainty"))
        elseif bar < uncertainty
            push!(found, Malformed(site, "registered with a bar narrower than its observation's uncertainty: " *
                                         "bar_half_width " * string(bar) * " below observation_uncertainty " *
                                         string(uncertainty)))
        end
    end
    return nothing
end

"The reviewed exceptions list of the history check, relative to a repository root."
const EXCEPTIONS_PATH = "docs/oracles/registration_exceptions.toml"

"The keys every `[[exception]]` entry carries, and no other."
const EXCEPTION_KEYS = ("merge", "oracle", "reason", "row", "date", "permitted_by")

"""
    ListedException

An `[[exception]]` entry of `EXCEPTIONS_PATH`: the merge commit and the oracle id whose
threshold change the history check accepts, with the reason, the tracker row, the date
added and the user's permission the entry records.
"""
struct ListedException
    merge::String
    oracle::String
    reason::String
    row::String
    date::String
    permitted_by::String
end

"Whether `v` is a TOML local date: a value that is not a string and prints as a year, month and day."
is_date(v) = !is_text(v) && occursin(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$", string(v))

"""
    read_exceptions(path)

Every `[[exception]]` entry of the TOML file at `path`, in file order. Refuses, naming
every problem, a missing file, a file that does not parse, a key other than `exception`,
an entry that is not a table, missing any of `EXCEPTION_KEYS` or carrying another key, a
`date` that is not a TOML date, any other field that is not a non-empty string (an empty
`permitted_by` named as such), a `merge` that is not a forty-digit commit id, and two
entries naming one merge and oracle.
"""
function read_exceptions(path::AbstractString)
    isfile(path) || refuse("registration exceptions", path, "does not exist; a file with no [[exception]] entry lists none")
    found = Malformed[]
    doc = try
        TOML.parsefile(path)
    catch err
        err isa TOML.ParserError || rethrow()
        refuse("registration exceptions", path, "does not parse as TOML: " * sprint(showerror, err))
    end
    for key in sort!(collect(keys(doc)))
        key == "exception" || push!(found, Malformed(path, "carries " * key * ", which is not exception"))
    end
    rows = get(doc, "exception", Any[])
    rows isa AbstractVector || (rows = Any[]; push!(found, Malformed(path, "exception is not an array of tables")))
    out = ListedException[]
    for (k, row) in enumerate(rows)
        site = path * " exception " * string(k)
        if !(row isa AbstractDict)
            push!(found, Malformed(site, "is not a table"))
            continue
        end
        bad = length(found)
        for key in sort!(collect(keys(row)))
            key in EXCEPTION_KEYS || push!(found, Malformed(site, "carries " * key * ", which is not an exception field"))
        end
        for key in EXCEPTION_KEYS
            if !haskey(row, key)
                push!(found, Malformed(site, "carries no " * key))
            elseif key == "date"
                is_date(row[key]) || push!(found, Malformed(site, "date is not a TOML date"))
            elseif !is_text(row[key])
                push!(found, Malformed(site, key * " is not a string"))
            elseif isempty(strip(row[key]))
                push!(found, Malformed(site, key == "permitted_by" ?
                                             "permitted_by is empty; an entry records the user's explicit permission for it" :
                                             key * " is empty"))
            end
        end
        merge = get(row, "merge", nothing)
        is_text(merge) && !isempty(merge) && !occursin(COMMIT_ID, merge) &&
            push!(found, Malformed(site, "merge " * repr(merge) * " is not a forty-digit commit id"))
        length(found) == bad || continue
        x = ListedException(row["merge"], row["oracle"], row["reason"], row["row"], string(row["date"]), row["permitted_by"])
        if any(y -> y.merge == x.merge && y.oracle == x.oracle, out)
            push!(found, Malformed(site, "names merge " * short(x.merge) * " and oracle " * x.oracle * ", as an earlier entry does"))
        else
            push!(out, x)
        end
    end
    isempty(found) ||
        refuse("registration exceptions", path, string(length(found), " problems: ", join(string.(found), "; ")))
    return out
end

"""
    history_problems(repo)

Every place the history of `repo`, from `amendment_commit(repo)` to HEAD, breaks the
registration rule and is not excepted, sorted. `read_exceptions` reads
`EXCEPTIONS_PATH` under `repo` before git is read. A registration is a commit at which an entry's
`registered_at` differs from its value at every parent and names an ancestor commit
holding the entry's `REGISTERED_FIELDS` as they are at the registering commit;
registrations are judged by `judge_registration!` against the registrations before
them, starting from the entries carrying a registered_at at the first parent of the
amendment commit. A `registered_at` set to a commit that is not an ancestor is a
problem. The mainline is the first-parent chain from HEAD through the commits walked. A
merge on the mainline is a problem when, against its first parent, it changes an entry's
threshold together with a path under `src/` or a file holding the testset named by
that entry at the merge or at its first parent, unless an entry of the exceptions list
names that merge and that entry's id; a merge off the mainline is not judged by this
clause, and its changes are read in the mainline merge that brings them in. An exception
naming no such merge and id is a problem, reported as stale.
"""
function history_problems(repo::AbstractString)
    exceptions = read_exceptions(joinpath(repo, EXCEPTIONS_PATH))
    matched = falses(length(exceptions))
    anchor = amendment_commit(repo)
    commits = commits_from(repo, anchor)
    by_sha = Dict(c.sha => c for c in commits)
    mainline = Set{String}()
    tip = get(by_sha, strip(git_read(repo, `rev-parse HEAD`)), nothing)
    while tip !== nothing
        push!(mainline, tip.sha)
        tip = isempty(tip.parents) ? nothing : get(by_sha, tip.parents[1], nothing)
    end
    cache = RowCache(repo, REGISTRY_PATH)
    found = Malformed[]
    history = Dict{String,Vector{Registration}}()

    anchor_parents = split(strip(git_read(repo, `log -1 --format=%P $(anchor)`)))
    if !isempty(anchor_parents)
        for (id, row) in rows_at(cache, anchor_parents[1])
            at = get(row, "registered_at", "")
            is_text(at) && !isempty(at) || continue
            history[id] = [Registration(id, String(anchor_parents[1]), get(row, "verdict_kind", nothing),
                                        get(row, "anchors", nothing), get(row, "datasets", nothing))]
        end
    end

    for c in commits
        REGISTRY_PATH in c.touched || continue
        rows = rows_at(cache, c.sha)
        parent_rows = [rows_at(cache, p) for p in c.parents]
        for id in sort!(collect(keys(rows)))
            row = rows[id]
            at = get(row, "registered_at", "")
            is_text(at) && !isempty(at) || continue
            all(pr -> get(get(pr, id, Dict{String,Any}()), "registered_at", "") != at, parent_rows) || continue
            if !(is_commit(repo, at) && is_ancestor(repo, at, c.sha))
                push!(found, Malformed(id * " at " * short(c.sha), "registered_at " * at * " names no ancestor commit"))
                continue
            end
            named = get(rows_at(cache, at), id, nothing)
            named !== nothing && registered_fields(named) == registered_fields(row) || continue
            r = Registration(id, c.sha, get(row, "verdict_kind", nothing), get(row, "anchors", nothing),
                             get(row, "datasets", nothing))
            earlier = get!(history, id, Registration[])
            judge_registration!(found, r, row, earlier, vcat(c.touched, touched(repo, at)))
            push!(earlier, r)
        end

        length(c.parents) >= 2 && c.sha in mainline || continue
        before = parent_rows[1]
        for id in sort!(collect(keys(rows)))
            haskey(before, id) || continue
            get(before[id], "threshold", nothing) == get(rows[id], "threshold", nothing) && continue
            held = union(testset_files(repo, c.sha, id), testset_files(repo, c.parents[1], id))
            with = sort!(unique(vcat(filter(p -> startswith(p, "src/"), c.touched), filter(in(held), c.touched))))
            isempty(with) && continue
            k = findfirst(x -> x.merge == c.sha && x.oracle == id, exceptions)
            if k === nothing
                push!(found, Malformed(id * " at " * short(c.sha), "a merge whose branch changes the threshold together with " *
                                                                   join(with, ", ")))
            else
                matched[k] = true
            end
        end
    end
    for (k, x) in enumerate(exceptions)
        matched[k] ||
            push!(found, Malformed(x.oracle * " at " * short(x.merge), "a stale exception of " * EXCEPTIONS_PATH *
                                                                        ": no merge of the history changes this entry's threshold " *
                                                                        "together with src/ or its testset"))
    end
    return sort(found; by = m -> (m.site, m.reason))
end
