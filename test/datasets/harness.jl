module DatasetHarness

using TOML

"A place a dataset link is wrong: the registry row or manifest file it is on, and what is wrong."
struct Problem
    site::String
    reason::String
end

Base.show(io::IO, p::Problem) = print(io, p.site, ": ", p.reason)

"""
A hashed manifest as the link check reads it: its id, its file, whether it sits under
the oracle datasets rather than the input datasets, the registry rows its `oracles` key
names, and its free-text anchors.
"""
struct Manifest
    id::String
    path::String
    oracle_data::Bool
    oracles::Vector{String}
    anchors::Vector{String}
end

"`value` as a list of strings, or `nothing` when it is not one."
function id_list(value)
    value isa AbstractVector || return nothing
    all(v -> v isa AbstractString, value) || return nothing
    return String[value...]
end

"""
    manifests(dir, oracle_data, found)

Every `.toml` manifest in `dir`, in `sort` order. A manifest whose id is not its file
name, or whose `oracles` key is not a list of strings, adds a problem to `found`.
"""
function manifests(dir::AbstractString, oracle_data::Bool, found::Vector{Problem})
    out = Manifest[]
    isdir(dir) || return out
    for name in sort(readdir(dir))
        endswith(name, ".toml") || continue
        path = joinpath(dir, name)
        header = TOML.parsefile(path)
        id = string(get(header, "id", ""))
        stem = name[1:end-length(".toml")]
        id == stem || push!(found, Problem(path, "id \"" * id * "\" is not its file name " * stem))
        oracles = id_list(get(header, "oracles", String[]))
        if oracles === nothing
            push!(found, Problem(path, "oracles is not a list of registry ids"))
            oracles = String[]
        end
        anchors = something(id_list(get(header, "anchors", String[])), String[])
        push!(out, Manifest(id, path, oracle_data, oracles, anchors))
    end
    return out
end

"""
    problems(; registry, oracle_data, input_data)

Every broken link between the `datasets` field of the registry's rows and the `oracles`
key of the manifests under `oracle_data` and `input_data`, sorted. This is the whole of
oracles.dataset_links:

- a manifest id is its file name and is used once across both directories;
- every tier 2 and tier 3 row carries `datasets`, and `datasets` and `oracles` are lists;
- every manifest a row names exists and names the row back;
- every row a manifest names exists and names the manifest back;
- every manifest under `oracle_data` names at least one row;
- no manifest anchor carries an oracle id.
"""
function problems(; registry::AbstractString, oracle_data::AbstractString,
                    input_data::AbstractString)
    found = Problem[]
    every = vcat(manifests(oracle_data, true, found), manifests(input_data, false, found))
    by_id = Dict{String,Manifest}()
    for m in every
        if haskey(by_id, m.id)
            push!(found, Problem(m.path, "id " * m.id * " is also used by " * by_id[m.id].path))
        else
            by_id[m.id] = m
        end
    end

    named = Dict{String,Vector{String}}()
    for row in TOML.parsefile(registry)["oracle"]
        id = row["id"]
        named[id] = String[]
        if !haskey(row, "datasets")
            tier = get(row, "tier", nothing)
            tier in (2, 3) &&
                push!(found, Problem(id, "a tier " * string(tier) * " row with no datasets field"))
            continue
        end
        datasets = id_list(row["datasets"])
        if datasets === nothing
            push!(found, Problem(id, "datasets is not a list of manifest ids"))
            continue
        end
        named[id] = datasets
        for d in datasets
            m = get(by_id, d, nothing)
            if m === nothing
                push!(found, Problem(id, "names manifest " * d * ", which does not exist"))
            elseif !(id in m.oracles)
                push!(found, Problem(id, "names manifest " * d * ", whose oracles key does not name it back"))
            end
        end
    end

    prefixes = Set(first(split(id, '.')) for id in keys(named))
    for m in every
        m.oracle_data && isempty(m.oracles) &&
            push!(found, Problem(m.path, "an oracle dataset whose oracles key names no registry row"))
        for o in m.oracles
            if !haskey(named, o)
                push!(found, Problem(m.path, "names oracle " * o * ", which is not a registry row"))
            elseif !(m.id in named[o])
                push!(found, Problem(m.path, "names oracle " * o * ", whose datasets field does not name it back"))
            end
        end
        for anchor in m.anchors, hit in eachmatch(r"\b([a-z][a-z0-9]*)\.[a-z][a-z0-9_]*", anchor)
            hit.captures[1] in prefixes &&
                push!(found, Problem(m.path, "anchor carries the oracle id " * hit.match *
                                             "; a row is named in the oracles key"))
        end
    end
    return sort(found, by = p -> (p.site, p.reason))
end

end # module DatasetHarness
