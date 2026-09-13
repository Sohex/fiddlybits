module Wellformed

using TOML

"A place the registry's verdict shape is wrong: the row or protocol it is on, and what is wrong."
struct Problem
    site::String
    reason::String
end

Base.show(io::IO, p::Problem) = print(io, p.site, ": ", p.reason)

"The verdict kinds a row may carry."
const VERDICT_KINDS = ("fail_bar", "report")

"A verdict named in capitals."
const VERDICT_NAME = r"\b(?:FAIL|PASS|REPORT)(?:S|ES|ED|ING)?\b"

"A constituent called a report, given no bar, or marked n/a."
const WITHOUT_BAR = r"\b[Rr]eport\b|\b[Nn]o bar\b|\b[Nn]/[Aa]\b"

"A constituent given a failing or passing edge."
const WITH_BAR = r"\b[Ff]ail(?:s|ed)?\b|\b[Pp]ass(?:es|ed)?\b"

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
    own = Set{String}()
    for key in ("statistic", "threshold")
        value = get(row, key, nothing)
        value isa AbstractString && union!(own, clauses(value))
    end
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
    protocol_table(doc, registry, found)

The protocol ids declared in `doc`, each mapped to `false` (named by no row yet). A
protocol with no id, an id used twice, or a missing or empty `system` or
`normalisation` adds a problem to `found`.
"""
function protocol_table(doc::AbstractDict, registry::AbstractString, found::Vector{Problem})
    named = Dict{String,Bool}()
    for p in get(doc, "protocol", Any[])
        id = get(p, "id", nothing)
        if !(id isa AbstractString)
            push!(found, Problem(registry, "a protocol with no id"))
            continue
        end
        if haskey(named, id)
            push!(found, Problem(id, "protocol id is used more than once"))
            continue
        end
        named[id] = false
        for key in ("system", "normalisation")
            value = get(p, key, nothing)
            (value isa AbstractString && !isempty(strip(value))) ||
                push!(found, Problem(id, "a protocol with no " * key))
        end
    end
    return named
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

Every place the registry file at `registry` breaks the verdict shape of decision 0053 or
the dependency shape of decision 0054, sorted. These are the verdict-shape and dependency
clauses of oracles.registry_wellformed:

- a row id is used once;
- every row carries a `verdict_kind` from `VERDICT_KINDS`, a statistic and a threshold;
- no statistic or threshold names a verdict in capitals;
- no statistic or threshold of a fail_bar row calls a constituent a report, gives it no
  bar or marks it n/a;
- no statistic or threshold of a report row gives a constituent a failing or passing edge;
- no row carries `protocol_system`;
- every tier 3 row names a protocol, no tier 2 row names one, and every protocol a row
  names is declared;
- a protocol id is used once, every protocol carries a `system` and a `normalisation`,
  and every protocol is named by at least one row;
- `depends_on`, where present, is a list of row ids, each named once, each a row of the
  registry, and each on the depending row's tier or a lower one;
- no row depends on itself, directly or through the rows it depends on;
- no statistic or threshold names another row's id;
- no statistic or threshold carries a clause of the threshold of a fail_bar row the row
  depends on, directly or through other rows (decision 0054).
"""
function problems(registry::AbstractString)
    found = Problem[]
    doc = TOML.parsefile(registry)
    rows = get(doc, "oracle", nothing)
    if !(rows isa AbstractVector)
        push!(found, Problem(registry, "no [[oracle]] rows"))
        return found
    end
    named = protocol_table(doc, registry, found)

    by_id = Dict{String,Any}()
    for row in rows
        id = get(row, "id", nothing)
        id isa AbstractString && !haskey(by_id, id) && (by_id[id] = row)
    end
    ids = Set(keys(by_id))
    edges = dependency_edges(rows, by_id, found)

    seen = Set{String}()
    for row in rows
        id = get(row, "id", nothing)
        if !(id isa AbstractString)
            push!(found, Problem(registry, "a row with no id"))
            continue
        end
        repeated = id in seen
        repeated && push!(found, Problem(id, "row id is used more than once"))
        push!(seen, id)

        kind = get(row, "verdict_kind", nothing)
        kind in VERDICT_KINDS ||
            push!(found, Problem(id, "verdict_kind " * repr(kind) * " is not one of " *
                                     join(VERDICT_KINDS, ", ")))
        prose(row, id, kind, found)
        named_rows(row, id, ids, found)
        repeated || restatements(row, id, edges, by_id, found)

        haskey(row, "protocol_system") &&
            push!(found, Problem(id, "carries protocol_system; a row names a [[protocol]] entry in protocol"))
        tier = get(row, "tier", nothing)
        if haskey(row, "protocol")
            p = row["protocol"]
            if !(p isa AbstractString)
                push!(found, Problem(id, "protocol is not a protocol id"))
            elseif tier == 2
                push!(found, Problem(id, "a tier 2 row names protocol " * p * "; a tier 2 bar applies to Earth()"))
                haskey(named, p) && (named[p] = true)
            elseif !haskey(named, p)
                push!(found, Problem(id, "names protocol " * p * ", which is not declared"))
            else
                named[p] = true
            end
        elseif tier == 3
            push!(found, Problem(id, "a tier 3 row with no protocol"))
        end
    end

    for (p, used) in named
        used || push!(found, Problem(p, "a protocol no row names"))
    end
    return sort(found, by = q -> (q.site, q.reason))
end

end # module Wellformed
