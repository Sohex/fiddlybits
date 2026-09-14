module Wellformed

using TOML
using Fiddlybits: Oracles

"A place the registry's verdict shape is wrong: the row, protocol or instrument it is on, and what is wrong."
struct Problem
    site::String
    reason::String
end

Base.show(io::IO, p::Problem) = print(io, p.site, ": ", p.reason)

"""
    shares_loader_clause(reason)

Whether `reason` is one of the clauses `src/Oracles/registry.jl`'s loader already
decides: verdict_kind membership, a tier 3 row naming no protocol, a protocol named but
not declared, a row id used more than once, or a `[[protocol]]` entry's own shape (an id
present and used once, a system and a normalisation, no other key).
"""
function shares_loader_clause(reason::AbstractString)
    occursin(r"^verdict_kind .* is not one of ", reason) && return true
    reason == "a tier 3 entry names no protocol" && return true
    occursin(r"^names protocol .*, which is not declared$", reason) && return true
    reason == "entry id is used more than once" && return true
    startswith(reason, "protocol ") && return true
    return false
end

"""
    loader_problems(registry)

Every problem `Oracles.problems` finds in the registry file at `registry`, restricted
to `shares_loader_clause`. No references index is passed: none of the shared clauses
resolve an anchor, and the anchor clauses stay the loader's own test suite's alone.
"""
function loader_problems(registry::AbstractString)
    found = Oracles.problems(registry, Dict{String,String}())
    return Problem[Problem(m.site, m.reason) for m in found if shares_loader_clause(m.reason)]
end

"A verdict named in capitals."
const VERDICT_NAME = r"\b(?:FAIL|PASS|REPORT)(?:S|ES|ED|ING)?\b"

"A constituent called a report, given no bar, or marked n/a."
const WITHOUT_BAR = r"\b[Rr]eport\b|\b[Nn]o bar\b|\b[Nn]/[Aa]\b"

"A constituent given a failing or passing edge."
const WITH_BAR = r"\b[Ff]ail(?:s|ed)?\b|\b[Pp]ass(?:es|ed)?\b"

"A constant qualified from a module: dotted identifiers, with at least one dot."
const CONSTANT_NAME = r"^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+$"

"Every distinct match of `pattern` in `text`, in order of first appearance."
matches(pattern::Regex, text::AbstractString) = unique(String[m.match for m in eachmatch(pattern, text)])

"A token shaped like a registry row id: dotted lowercase words not inside a path or a longer name."
const ROW_ID_TOKEN = r"(?<![A-Za-z0-9_./-])[a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+"

"""
    clauses(text)

The clauses of a statistic or threshold: `text` lowercased, split at semicolons and at
sentence ends, whitespace collapsed, a leading `provisional` marker removed, and empty
clauses dropped.
"""
function clauses(text::AbstractString)
    found = Set{String}()
    for part in split(lowercase(text), r";|\.(?:\s|$)")
        c = replace(strip(part), r"\s+" => " ")
        c = replace(c, r"^provisional\b[:;,]?\s*" => "")
        c = strip(c, [' ', ',', ':'])
        isempty(c) || push!(found, String(c))
    end
    return found
end

"The clauses of a row's statistic and threshold together."
function row_clauses(row::AbstractDict)
    own = Set{String}()
    for key in ("statistic", "threshold")
        value = get(row, key, nothing)
        value isa AbstractString && union!(own, clauses(value))
    end
    return own
end

"Whether `value` is a number a parameter may state: a real that is not a boolean."
stated_number(value) = value isa Real && !(value isa Bool)

"""
    named_rows(row, id, ids, found)

Adds a problem to `found` for each row id in `ids`, other than the row's own `id`, that
the row's statistic or threshold names.
"""
function named_rows(row::AbstractDict, id::AbstractString, ids::AbstractSet, found::Vector{Problem})
    for key in ("statistic", "threshold")
        value = get(row, key, nothing)
        value isa AbstractString || continue
        for other in matches(ROW_ID_TOKEN, value)
            other != id && other in ids &&
                push!(found, Problem(id, key * " names row " * other * "; a row names another row only in depends_on"))
        end
    end
    return nothing
end

"""
    dependency_edges(rows, by_id, found)

Each row id mapped to the row ids its `depends_on` names that resolve. A `depends_on`
that is not a list of strings, an id named twice, an id that is no row, and a row on a
tier less trusted than the depending row each add a problem to `found`.
"""
function dependency_edges(rows::AbstractVector, by_id::AbstractDict, found::Vector{Problem})
    edges = Dict{String,Vector{String}}()
    for row in rows
        id = get(row, "id", nothing)
        (id isa AbstractString && haskey(row, "depends_on")) || continue
        deps = row["depends_on"]
        if !(deps isa AbstractVector && all(d -> d isa AbstractString, deps))
            push!(found, Problem(id, "depends_on is not a list of row ids"))
            continue
        end
        resolved = String[]
        for d in unique(deps)
            count(==(d), deps) > 1 &&
                push!(found, Problem(id, "names " * d * " in depends_on more than once"))
            if !haskey(by_id, d)
                push!(found, Problem(id, "depends on " * d * ", which is not a row"))
                continue
            end
            tier, other = get(row, "tier", nothing), get(by_id[d], "tier", nothing)
            tier isa Integer && other isa Integer && other > tier &&
                push!(found, Problem(id, "a tier " * string(tier) * " row depends on " * d * ", a tier " *
                                         string(other) * " row; a row depends only on rows of its own tier or a lower one"))
            push!(resolved, d)
        end
        edges[id] = resolved
    end
    return edges
end

"Every row id reachable from `id` through one or more edges."
function reachable(edges::AbstractDict, id::AbstractString)
    seen = Set{String}()
    stack = copy(get(edges, id, String[]))
    while !isempty(stack)
        d = pop!(stack)
        d in seen && continue
        push!(seen, d)
        append!(stack, get(edges, d, String[]))
    end
    return seen
end

"""
    restatements(row, id, edges, by_id, found)

Adds a problem to `found` for each row the row depends on, directly or through other
rows, that is a fail_bar row sharing a clause of its threshold with the row's statistic
or threshold; and one if the row depends on itself.
"""
function restatements(row::AbstractDict, id::AbstractString, edges::AbstractDict, by_id::AbstractDict,
                      found::Vector{Problem})
    deps = reachable(edges, id)
    id in deps && push!(found, Problem(id, "depends on itself, directly or through the rows it depends on"))
    own = row_clauses(row)
    for d in sort!(collect(deps))
        d == id && continue
        dep = by_id[d]
        get(dep, "verdict_kind", nothing) == "fail_bar" || continue
        threshold = get(dep, "threshold", nothing)
        threshold isa AbstractString || continue
        shared = sort!(collect(intersect(own, clauses(threshold))))
        isempty(shared) ||
            push!(found, Problem(id, "carries " * join(repr.(shared), ", ") * " from the threshold of " * d *
                                     ", which it depends on; a row states no bar of a row it depends on"))
    end
    return nothing
end

"""
    protocol_ids(doc)

The ids `doc`'s `[[protocol]]` entries declare, each mapped to `false` (named by no row
yet), one entry per distinct id. A protocol with no id, or shaped wrongly, is not this
module's clause: `Oracles.problems`, read through `loader_problems`, decides that shape.
"""
function protocol_ids(doc::AbstractDict)
    named = Dict{String,Bool}()
    for p in get(doc, "protocol", Any[])
        id = get(p, "id", nothing)
        id isa AbstractString || continue
        haskey(named, id) || (named[id] = false)
    end
    return named
end

"""
    parameter_shape(parameters, id, found)

Adds a problem to `found` when the `parameters` of instrument `id` is not a table, and
one for each of its entries whose key is not a qualified constant name or whose value
is not a number.
"""
function parameter_shape(parameters, id::AbstractString, found::Vector{Problem})
    if !(parameters isa AbstractDict)
        push!(found, Problem(id, "parameters is not a table of constant names each stating a number"))
        return nothing
    end
    for name in sort!(collect(keys(parameters)))
        (occursin(CONSTANT_NAME, name) && stated_number(parameters[name])) ||
            push!(found, Problem(id, "parameter " * name * " is not a qualified constant name stating a number"))
    end
    return nothing
end

"""
    instrument_table(doc, registry, ids, found)

The instruments declared in `doc`, as `(named, definitions)`: each id mapped to `false`
(named by no row yet), and each id with a definition mapped to that definition's
clauses. An instrument with no id, an id used twice, a missing or empty `definition`, a
definition naming a verdict in capitals or a row id in `ids`, and a `parameters` of the
wrong shape add a problem to `found`.
"""
function instrument_table(doc::AbstractDict, registry::AbstractString, ids::AbstractSet, found::Vector{Problem})
    named = Dict{String,Bool}()
    definitions = Dict{String,Set{String}}()
    for instrument in get(doc, "instrument", Any[])
        id = get(instrument, "id", nothing)
        if !(id isa AbstractString)
            push!(found, Problem(registry, "an instrument with no id"))
            continue
        end
        if haskey(named, id)
            push!(found, Problem(id, "instrument id is used more than once"))
            continue
        end
        named[id] = false
        definition = get(instrument, "definition", nothing)
        if definition isa AbstractString && !isempty(strip(definition))
            definitions[id] = clauses(definition)
            names = matches(VERDICT_NAME, definition)
            isempty(names) ||
                push!(found, Problem(id, "definition names the verdict " * join(names, ", ") *
                                         "; only verdict_kind names a verdict"))
            for other in matches(ROW_ID_TOKEN, definition)
                other in ids &&
                    push!(found, Problem(id, "definition names row " * other *
                                             "; a row names an instrument in instrument, and an instrument names no row"))
            end
        else
            push!(found, Problem(id, "an instrument with no definition"))
        end
        haskey(instrument, "parameters") && parameter_shape(instrument["parameters"], id, found)
    end
    return named, definitions
end

"""
    instrument_restatements(row, id, definitions, found)

Adds a problem to `found` for each declared instrument whose definition shares a clause
with the row's statistic or threshold.
"""
function instrument_restatements(row::AbstractDict, id::AbstractString, definitions::AbstractDict,
                                 found::Vector{Problem})
    own = row_clauses(row)
    for instrument in sort!(collect(keys(definitions)))
        shared = sort!(collect(intersect(own, definitions[instrument])))
        isempty(shared) ||
            push!(found, Problem(id, "carries " * join(repr.(shared), ", ") * " from the definition of instrument " *
                                     instrument * "; an instrument is defined once, in its [[instrument]] entry, " *
                                     "and a row names it in instrument"))
    end
    return nothing
end

"""
    prose(row, id, kind, found)

Adds a problem to `found` for each of the row's statistic and threshold that is absent,
names a verdict in capitals, or carries a constituent its `kind` does not judge.
"""
function prose(row::AbstractDict, id::AbstractString, kind, found::Vector{Problem})
    for key in ("statistic", "threshold")
        value = get(row, key, nothing)
        if !(value isa AbstractString)
            push!(found, Problem(id, "no " * key * " to read its verdict shape from"))
            continue
        end
        names = matches(VERDICT_NAME, value)
        isempty(names) ||
            push!(found, Problem(id, key * " names the verdict " * join(names, ", ") *
                                     "; only verdict_kind names a verdict"))
        if kind == "fail_bar"
            words = matches(WITHOUT_BAR, value)
            isempty(words) ||
                push!(found, Problem(id, key * " of a fail_bar row gives a constituent no bar (" *
                                         join(words, ", ") * "); that constituent is a report row of its own"))
        elseif kind == "report"
            words = matches(WITH_BAR, value)
            isempty(words) ||
                push!(found, Problem(id, key * " of a report row gives a constituent a bar (" *
                                         join(words, ", ") * "); that constituent is a fail_bar row of its own"))
        end
    end
    return nothing
end

"""
    problems(registry)

Every place the registry file at `registry` breaks the verdict shape of decision 0053,
the dependency shape of decision 0054 or the instrument shape of decision 0057, sorted.
Five clauses are `src/Oracles/registry.jl`'s loader's own, read here through
`loader_problems` so each is decided in one place: a row's `verdict_kind` is one of
`fail_bar` or `report`; a tier 3 row names a protocol; a protocol a row names is
declared; a row id is used once; and a `[[protocol]]` entry's own shape (an id present
and used once, a system and a normalisation). The rest are this module's own:

- no statistic or threshold names a verdict in capitals;
- no statistic or threshold of a fail_bar row calls a constituent a report, gives it no
  bar or marks it n/a;
- no statistic or threshold of a report row gives a constituent a failing or passing edge;
- no row carries `protocol_system`;
- no tier 2 row names a protocol, since a tier 2 bar applies to `Earth()`;
- every protocol is named by at least one row;
- `depends_on`, where present, is a list of row ids, each named once, each a row of the
  registry, and each on the depending row's tier or a lower one;
- no row depends on itself, directly or through the rows it depends on;
- no statistic or threshold names another row's id;
- no statistic or threshold carries a clause of the threshold of a fail_bar row the row
  depends on, directly or through other rows;
- a row's `instrument`, where present, is an instrument id and is declared;
- an instrument id is used once, every instrument carries a definition, and every
  instrument is named by at least one row;
- no instrument's definition names a verdict in capitals or a row id;
- an instrument's `parameters`, where present, is a table of qualified constant names
  each stating a number;
- no statistic or threshold carries a clause of an instrument's definition.

`parameter_problems` is the clause that reads the code as well.
"""
function problems(registry::AbstractString)
    found = Problem[]
    doc = TOML.parsefile(registry)
    rows = get(doc, "oracle", nothing)
    if !(rows isa AbstractVector)
        push!(found, Problem(registry, "no [[oracle]] rows"))
        return found
    end
    named = protocol_ids(doc)

    by_id = Dict{String,Any}()
    for row in rows
        id = get(row, "id", nothing)
        id isa AbstractString && !haskey(by_id, id) && (by_id[id] = row)
    end
    ids = Set(keys(by_id))
    edges = dependency_edges(rows, by_id, found)
    instruments, definitions = instrument_table(doc, registry, ids, found)

    seen = Set{String}()
    for row in rows
        id = get(row, "id", nothing)
        if !(id isa AbstractString)
            push!(found, Problem(registry, "a row with no id"))
            continue
        end
        repeated = id in seen
        push!(seen, id)

        kind = get(row, "verdict_kind", nothing)
        prose(row, id, kind, found)
        named_rows(row, id, ids, found)
        repeated || restatements(row, id, edges, by_id, found)
        instrument_restatements(row, id, definitions, found)

        haskey(row, "protocol_system") &&
            push!(found, Problem(id, "carries protocol_system; a row names a [[protocol]] entry in protocol"))
        tier = get(row, "tier", nothing)
        if haskey(row, "protocol")
            p = row["protocol"]
            if p isa AbstractString
                tier == 2 &&
                    push!(found, Problem(id, "a tier 2 row names protocol " * p * "; a tier 2 bar applies to Earth()"))
                haskey(named, p) && (named[p] = true)
            end
        end

        if haskey(row, "instrument")
            i = row["instrument"]
            if !(i isa AbstractString)
                push!(found, Problem(id, "instrument is not an instrument id"))
            elseif !haskey(instruments, i)
                push!(found, Problem(id, "names instrument " * i * ", which is not declared"))
            else
                instruments[i] = true
            end
        end
    end

    for (p, used) in named
        used || push!(found, Problem(p, "a protocol no row names"))
    end
    for (i, used) in instruments
        used || push!(found, Problem(i, "an instrument no row names"))
    end
    append!(found, loader_problems(registry))
    return sort(found, by = q -> (q.site, q.reason))
end

"""
    resolve(root, name)

`Some(value)` of the constant the qualified `name` names under module `root`, following
every dotted segment but the last into a submodule; `nothing` when a segment is not
defined, a segment but the last is not a module, or the last is not a constant binding.
"""
function resolve(root::Module, name::AbstractString)
    segments = Symbol.(split(name, '.'))
    mod = root
    for s in segments[1:end-1]
        isdefined(mod, s) || return nothing
        inner = getfield(mod, s)
        inner isa Module || return nothing
        mod = inner
    end
    s = segments[end]
    (isdefined(mod, s) && isconst(mod, s)) || return nothing
    return Some(getfield(mod, s))
end

"""
    parameter_problems(registry, root)

Every parameter of an instrument in the registry file at `registry` that does not state
the constant it names under module `root`, sorted: a name that resolves to no constant,
and a constant that is not a number equal to the one the parameter states. A parameter
whose shape `problems` refuses is skipped here.
"""
function parameter_problems(registry::AbstractString, root::Module)
    found = Problem[]
    for instrument in get(TOML.parsefile(registry), "instrument", Any[])
        id = get(instrument, "id", nothing)
        parameters = get(instrument, "parameters", nothing)
        (id isa AbstractString && parameters isa AbstractDict) || continue
        for name in sort!(collect(keys(parameters)))
            stated = parameters[name]
            (occursin(CONSTANT_NAME, name) && stated_number(stated)) || continue
            held = resolve(root, name)
            if held === nothing
                push!(found, Problem(id, "parameter " * name * " names no constant of " * string(nameof(root))))
                continue
            end
            value = something(held)
            (stated_number(value) && value == stated) ||
                push!(found, Problem(id, "parameter " * name * " states " * repr(stated) *
                                         ", and the constant it names is " * repr(value)))
        end
    end
    return sort(found, by = q -> (q.site, q.reason))
end

end # module Wellformed
