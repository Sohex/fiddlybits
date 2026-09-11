# lint_manifest: docs/imports/fastpower-jl.md. A dependency hazard arrives through
# the graph, so it is caught in the resolved manifest rather than at a call site.
# Refuses an excluded package anywhere in the manifest, and an exclusion whose
# import record is missing.

using TOML
function lint_manifest(root::AbstractString)
    cfg = LintSupport.list("manifest_exclusions.toml")
    found = LintSupport.Site[]
    manifest = joinpath(root, "Manifest.toml")
    if !isfile(manifest)
        push!(found, LintSupport.Site("Manifest.toml", 1, "no resolved manifest"))
        return found
    end
    resolved = TOML.parsefile(manifest)
    present = Set(keys(get(resolved, "deps", Dict{String,Any}())))
    for entry in cfg["exclusion"]
        pkg, record = entry["package"], entry["record"]
        isfile(joinpath(root, record)) ||
            push!(found, LintSupport.Site(record, 1, "exclusion of " * pkg * " names no record"))
        pkg in present && push!(found, LintSupport.Site("Manifest.toml", 1, pkg))
    end
    return found
end
