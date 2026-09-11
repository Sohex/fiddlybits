module ImportHarness

using TOML

"A dependency and what is wrong with its import review."
struct Problem
    package::String
    reason::String
end

Base.show(io::IO, p::Problem) = print(io, p.package, ": ", p.reason)

"""
    dependencies(project, manifest)

The names in `[deps]` and `[extras]` of the project file that the resolved
manifest records with a tree hash. A package Julia ships carries no tree hash and
carries no import review either. Extras are dependencies of the test target and
carry the same review as the rest.

The manifest is read rather than a list of shipped names, because the manifest is
what the environment actually resolved.
"""
function dependencies(project::AbstractString, manifest::AbstractString)
    p = TOML.parsefile(project)
    named = union(keys(get(p, "deps", Dict())), keys(get(p, "extras", Dict())))
    resolved = get(TOML.parsefile(manifest), "deps", Dict{String,Any}())
    external = filter(named) do name
        entries = get(resolved, name, ())
        any(e -> haskey(e, "git-tree-sha1"), entries)
    end
    return sort(collect(external))
end

"""
    records(dir)

Package name to record path, read from each record's first-line heading with a
trailing `.jl` dropped. A heading naming several packages contributes each.
"""
function records(dir::AbstractString)
    out = Dict{String,String}()
    isdir(dir) || return out
    for name in sort(readdir(dir))
        endswith(name, ".md") || continue
        path = joinpath(dir, name)
        heading = first(eachline(path))
        startswith(heading, "# ") || continue
        for word in eachmatch(r"[A-Za-z][A-Za-z0-9_]*(?:\.jl)?", heading[3:end])
            out[replace(word.match, r"\.jl$" => "")] = path
        end
    end
    return out
end

"Every backticked test path and oracle id in a record."
function named_checks(path::AbstractString)
    text = read(path, String)
    tests = [m.captures[1] for m in eachmatch(r"`(test/[A-Za-z0-9_/.-]+\.jl)`", text)]
    oracles = [m.captures[1] for m in eachmatch(r"`([a-z][a-z0-9_]*\.[a-z][a-z0-9_]+)`", text)]
    return unique(vcat(tests, oracles))
end

"The ids the oracle registry declares."
function oracle_ids(registry::AbstractString)
    isfile(registry) || return Set{String}()
    return Set{String}(o["id"] for o in TOML.parsefile(registry)["oracle"])
end

"""
    structural_problems(; project, imports)

Every dependency without a record, and every record that names no leak check at
all. These are defects of the review itself and hold whatever the board's state.
Reads the dependency list and looks for records, never the reverse: `imports`
also holds records of packages that were surveyed and refused.
"""
function structural_problems(; project::AbstractString, manifest::AbstractString,
                               imports::AbstractString)
    found = Problem[]
    by_name = records(imports)
    for pkg in dependencies(project, manifest)
        path = get(by_name, pkg, nothing)
        if path === nothing
            push!(found, Problem(pkg, "no record in " * imports))
        elseif isempty(named_checks(path))
            push!(found, Problem(pkg, "record " * path * " names no leak check"))
        end
    end
    return found
end

"""
    problems(; project, imports, registry, root)

`structural_problems` and, in addition, every named check that does not resolve:
a test path with no file under `root`, or an oracle id absent from the registry.
This is the whole of build.import_record_completeness.
"""
function problems(; project::AbstractString, manifest::AbstractString,
                    imports::AbstractString, registry::AbstractString,
                    root::AbstractString)
    found = structural_problems(; project, manifest, imports)
    for (pkg, checks) in unresolved(; project, manifest, imports, registry, root)
        for check in checks
            push!(found, Problem(pkg, "record names " * check * ", which does not resolve"))
        end
    end
    return sort(found, by = p -> (p.package, p.reason))
end

"""
    unresolved(; project, imports, registry, root)

The named checks that do not resolve yet, by package. A check written by an area
row is absent until that row merges, which is a state of the board and not a
defect, so it is reported separately from `problems`.
"""
function unresolved(; project::AbstractString, manifest::AbstractString,
                      imports::AbstractString, registry::AbstractString,
                      root::AbstractString)
    out = Dict{String,Vector{String}}()
    by_name = records(imports)
    ids = oracle_ids(registry)
    for pkg in dependencies(project, manifest)
        path = get(by_name, pkg, nothing)
        path === nothing && continue
        missing = String[]
        for check in named_checks(path)
            ok = startswith(check, "test/") ? isfile(joinpath(root, check)) : (check in ids)
            ok || push!(missing, check)
        end
        isempty(missing) || (out[pkg] = missing)
    end
    return out
end

end # module ImportHarness
