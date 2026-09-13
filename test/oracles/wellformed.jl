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

Every place the registry file at `registry` breaks the verdict shape of decision 0053,
sorted. These are the verdict-shape clauses of oracles.registry_wellformed:

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
  and every protocol is named by at least one row.
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

    seen = Set{String}()
    for row in rows
        id = get(row, "id", nothing)
        if !(id isa AbstractString)
            push!(found, Problem(registry, "a row with no id"))
            continue
        end
        id in seen && push!(found, Problem(id, "row id is used more than once"))
        push!(seen, id)

        kind = get(row, "verdict_kind", nothing)
        kind in VERDICT_KINDS ||
            push!(found, Problem(id, "verdict_kind " * repr(kind) * " is not one of " *
                                     join(VERDICT_KINDS, ", ")))
        prose(row, id, kind, found)

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
