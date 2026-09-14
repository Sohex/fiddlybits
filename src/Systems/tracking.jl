# The measured dependency graph: TrackingSystem and TrackingProfile record the fields a
# reader reads, dependency_subset checks the recorded reads against a declared graph, and
# affected answers what a changed field reaches in that graph.
# docs/plans/fiddlybits-52v.4-system.md, section "The graph";
# docs/plans/fiddlybits-52v.6-provenance.md, section "The key"; decisions 0007 and 0010;
# REQ-SYS-008.
#
# A path is a tuple of steps from a System or a Profile: a field name (Symbol) of a
# struct or a named tuple, a tuple position (Int, from 1), or `:` (Colon). In a
# declaration or a change, `:` stands for every position of a tuple. In a recorded read,
# `:` as the last step is a read of a tuple's length, and a read of a named tuple's
# names is recorded as the named tuple's own path. The field names and positions are the
# ones `derived_fields` reports, and a component's entry of a profile's components is the
# step of its name.

using ..Verdicts: refuse, PASS, FAIL
using ..Dispositions: Disposition

"""
    holds_declaration(x)

`true` when a `Disposition` is reachable from `x` through tuples, named tuples, arrays
and the fields of this module's structs.
"""
holds_declaration(::Disposition) = true
holds_declaration(::AbstractArray{<:Number}) = false
holds_declaration(x::Union{Tuple,NamedTuple,AbstractArray}) = any(holds_declaration, x)
holds_declaration(x) = parentmodule(typeof(x)) === (@__MODULE__) &&
    any(name -> holds_declaration(getfield(x, name)), fieldnames(typeof(x)))

"""
    interior(x)

`true` when a path steps into `x` rather than ending at it: `x` is a tuple, a named
tuple, or a struct of this module, that is not a `Disposition` and holds one. An array
is never interior, whatever it holds.
"""
interior(::Disposition) = false
interior(::AbstractArray) = false
interior(x) = holds_declaration(x)

"The reads one tracked run records, as a set of paths, guarded for concurrent readers."
struct ReadLog
    lock::ReentrantLock
    paths::Set{Tuple}
end

ReadLog() = ReadLog(ReentrantLock(), Set{Tuple}())

record!(log::ReadLog, path::Tuple) = @lock log.lock push!(log.paths, path)

"""
    Tracked

A `System` or a `Profile`, or an interior value within one, reached at `path` under a
`TrackingSystem` or a `TrackingProfile`. Built by those two, never directly.

A reader reaches values through it by property access; by indexing, iterating and
`map` over a tuple, and by `length`, `keys`, `eachindex`, `firstindex` and `lastindex`
of a tuple; and by indexing with a name, iterating and `map` over a named tuple, and
by `length`, `keys` and `propertynames` of a named tuple. `map` returns a tuple over a
tuple and a named tuple over a named tuple, as it does over the value itself.
A step that reaches an interior value returns another `Tracked`; a step that reaches
any other value records its path and returns the value itself, and a step that reaches
the empty tuple records its path followed by `:`. `length`, `keys`,
`eachindex`, `lastindex` and the end of an iteration record the tuple's path followed
by `:`; over a named tuple, `length`, `keys`, `propertynames`, iteration and `map`
record the named tuple's own path. A named tuple is stepped by name only. Any other
operation on a `Tracked`, a type test or a method typed on a block among them, sees
the wrapper and not the block.
"""
struct Tracked{T}
    target::T
    path::Tuple
    log::ReadLog
end

"""
    TrackingSystem(system)

`system` wrapped so that every read through it is recorded in a fresh log;
`recorded_reads` returns what has been recorded.
"""
TrackingSystem(system::System) = Tracked(system, (), ReadLog())

"""
    TrackingProfile(profile)

`profile` wrapped so that every read through it is recorded in a fresh log;
`recorded_reads` returns what has been recorded.
"""
TrackingProfile(profile::Profile) = Tracked(profile, (), ReadLog())

"The tracked root of `root`: `TrackingSystem` of a `System`, `TrackingProfile` of a `Profile`."
tracking(root::System) = TrackingSystem(root)
tracking(root::Profile) = TrackingProfile(root)

"The text a refusal names `root` by."
root_text(::System) = "the system"
root_text(::Profile) = "the profile"

"The paths recorded under the tracked value `t`'s log, as a new `Set`."
recorded_reads(t::Tracked) = (log = getfield(t, :log); @lock log.lock copy(log.paths))

function reached(t::Tracked, step, child)
    path = (getfield(t, :path)..., step)
    log = getfield(t, :log)
    interior(child) && return Tracked(child, path, log)
    record!(log, child === () ? (path..., :) : path)
    return child
end

function record_length!(t::Tracked{<:Tuple})
    record!(getfield(t, :log), (getfield(t, :path)..., :))
    return length(getfield(t, :target))
end

function record_names!(t::Tracked{<:NamedTuple})
    record!(getfield(t, :log), getfield(t, :path))
    return keys(getfield(t, :target))
end

Base.getproperty(t::Tracked, name::Symbol) = reached(t, name, getfield(getfield(t, :target), name))
Base.propertynames(t::Tracked) = propertynames(getfield(t, :target))
Base.getindex(t::Tracked{<:Tuple}, i::Int) = reached(t, i, getfield(t, :target)[i])
Base.length(t::Tracked{<:Tuple}) = record_length!(t)
Base.firstindex(t::Tracked{<:Tuple}) = 1
Base.lastindex(t::Tracked{<:Tuple}) = record_length!(t)
Base.keys(t::Tracked{<:Tuple}) = Base.OneTo(record_length!(t))
Base.eachindex(t::Tracked{<:Tuple}) = keys(t)
Base.iterate(t::Tracked{<:Tuple}, i::Int = 1) = i > record_length!(t) ? nothing : (t[i], i + 1)
Base.map(f, t::Tracked{<:Tuple}) = ntuple(i -> f(t[i]), record_length!(t))
Base.getindex(t::Tracked{<:NamedTuple}, name::Symbol) = getproperty(t, name)
Base.length(t::Tracked{<:NamedTuple}) = length(record_names!(t))
Base.keys(t::Tracked{<:NamedTuple}) = record_names!(t)
Base.propertynames(t::Tracked{<:NamedTuple}) = record_names!(t)
function Base.iterate(t::Tracked{<:NamedTuple}, i::Int = 1)
    names = record_names!(t)
    return i > length(names) ? nothing : (getproperty(t, names[i]), i + 1)
end
function Base.map(f, t::Tracked{<:NamedTuple})
    names = record_names!(t)
    return NamedTuple{names}(ntuple(i -> f(getproperty(t, names[i])), length(names)))
end

"`step` when it is a field name, a position from 1, or `:`; refuses at `site` otherwise."
function require_step(site::AbstractString, name, step)
    step isa Symbol || step isa Colon || (step isa Int && step >= 1) || refuse(
        "path", site, "$(name) holds a step $(repr(step)); a step is a field name, a " *
        "position from 1, or :")
    return step
end

"`path` when it is a tuple of steps; refuses at `site` naming `name` otherwise."
function require_path(site::AbstractString, name, path)
    path isa Tuple || refuse("path", site, "$(name) holds $(repr(path)), which is not a tuple of steps")
    foreach(step -> require_step(site, name, step), path)
    return path
end

"""
    require_graph(site, graph)

`graph`, a dictionary from a reader's name to a collection of paths, as a
`Dict` from each name to a `Set` of its paths. Refuses at `site` a graph that is not a
dictionary, an entry that is not a collection, and a path that is not a tuple of steps.
"""
function require_graph(site::AbstractString, graph)
    graph isa AbstractDict || refuse("graph", site, "$(typeof(graph)) is not a dictionary from a name to its paths")
    checked = Dict{Any,Set{Tuple}}()
    for (name, paths) in graph
        paths isa Union{AbstractSet,AbstractVector,Tuple} || refuse(
            "graph", site, "the entry for $(name) is a $(typeof(paths)), not a collection of paths")
        checked[name] = Set{Tuple}(require_path(site, name, p) for p in paths)
    end
    return checked
end

step_covers(declared, read) = declared === read || (declared isa Colon && read isa Int)

"""
    covers(declared, read)

`true` when the declared path `declared` covers the recorded path `read`: its steps
cover the leading steps of `read` and it is no longer, or `read` is a length read and
`declared` continues past it.
"""
covers(declared::Tuple, read::Tuple) =
    (length(declared) <= length(read) || last(read) isa Colon) &&
    all(i -> step_covers(declared[i], read[i]), 1:min(length(declared), length(read)))

steps_overlap(a, b) = a === b || (a isa Colon && b isa Int) || (a isa Int && b isa Colon)

"`true` when the paths `a` and `b` agree on every step they share, so one reaches into the other."
overlaps(a::Tuple, b::Tuple) = all(i -> steps_overlap(a[i], b[i]), 1:min(length(a), length(b)))

"""
    affected(change, graph)

The names in `graph` with a declared path that overlaps the path `change`, as a `Set`.
`graph` is a dictionary from a name to a collection of paths and is read as data
only. Refuses a malformed `change` or `graph`.
"""
function affected(change::Tuple, graph)
    site = "Systems.affected"
    require_path(site, "the change", change)
    return Set(name for (name, paths) in require_graph(site, graph)
               if any(p -> overlaps(p, change), paths))
end

"""
    reaches(x, path)

`true` when `path` steps from `x` through interior values and the empty tuple only: a
field name of an interior struct or named tuple, a position of an interior tuple, or `:`
over every position of an interior or empty tuple.
"""
function reaches(x, path::Tuple)
    isempty(path) && return true
    step, rest = first(path), Base.tail(path)
    interior(x) || x === () || return false
    if x isa Tuple
        step isa Colon && return all(y -> reaches(y, rest), x)
        return step isa Int && step <= length(x) && reaches(x[step], rest)
    end
    return step isa Symbol && hasfield(typeof(x), step) && reaches(getfield(x, step), rest)
end

"""
    dependency_subset(readers, declared, root)

Runs each reader in `readers`, a dictionary from a name to a function of one `root`,
once on its own `tracking(root)`, and checks its recorded reads against the paths
`declared` gives the same name. `root` is a `System`, whose paths are a declaration's
`system_fields`, or a `Profile`, whose paths are its `profile_fields`. Returns a named
tuple:

- `verdict`: `PASS` when every recorded read is covered by a declared path of its
  reader, `FAIL` otherwise;
- `recorded`: each name's recorded reads;
- `undeclared`: each name's recorded reads no declared path covers;
- `unread`: each name's declared paths that cover no recorded read, reported and never
  failed.

Refuses when the names of `readers` and `declared` differ, and a declared path that
does not reach through `root`.
"""
function dependency_subset(readers::AbstractDict, declared, root::Union{System,Profile})
    site = "Systems.dependency_subset"
    graph = require_graph(site, declared)
    Set(keys(readers)) == Set(keys(graph)) || refuse(
        "graph", site, "readers $(sort!([string(k) for k in keys(readers)])) and " *
        "declarations $(sort!([string(k) for k in keys(graph)])) name different sets")
    for (name, paths) in graph, p in paths
        reaches(root, p) || refuse("path", site, "$(name) declares $(p), which does not reach through $(root_text(root))")
    end
    recorded = Dict{Any,Set{Tuple}}()
    for (name, reader) in readers
        tracked = tracking(root)
        reader(tracked)
        recorded[name] = recorded_reads(tracked)
    end
    undeclared = Dict(name => Set(r for r in reads if !any(d -> covers(d, r), graph[name]))
                      for (name, reads) in recorded)
    unread = Dict(name => Set(d for d in graph[name]
                              if !any(r -> length(d) <= length(r) && covers(d, r), recorded[name]))
                  for name in keys(graph))
    verdict = all(isempty, values(undeclared)) ? PASS() : FAIL()
    return (verdict = verdict, recorded = recorded, undeclared = undeclared, unread = unread)
end
