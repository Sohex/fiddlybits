# lint_earth: REQ-SYS-101, docs/imports/dynamicquantities.md.
# Refuses the unit registry's door, a quarantined ratio read outside its readers,
# and any Earth literal of item A3 in docs/imports/README.md, in source under root.

function lint_earth(root::AbstractString)
    cfg = LintSupport.list("earth.toml")
    found = LintSupport.Site[]

    doors = Regex(join(("(?:using|import)\\s+" * replace(m, "." => "\\.") for m in cfg["registry_modules"]), "|"))
    qualified = Regex("\\b(?:" * join((replace(m, "." => "\\.") for m in cfg["registry_modules"]), "|") * ")\\.[A-Za-z_]")
    quarantine = Regex("\\b" * cfg["quarantine_module"] * "\\b")
    literals = Regex("(?<![0-9A-Za-z_.])(?:" * join((replace(l, "." => "\\.") for l in cfg["literals"]), "|") * ")(?![0-9A-Za-z_])")

    for path in LintSupport.sources(root)
        exempt = any(e -> startswith(path, e * "/") || startswith(path, e), cfg["exempt"])
        reader = any(r -> startswith(path, r * "/") || startswith(path, r), cfg["quarantine_readers"])
        LintSupport.each_line(root, path) do i, line
            for m in eachmatch(doors, line)
                push!(found, LintSupport.Site(path, i, m.match))
            end
            for m in eachmatch(qualified, line)
                push!(found, LintSupport.Site(path, i, m.match))
            end
            if !reader
                for m in eachmatch(quarantine, line)
                    push!(found, LintSupport.Site(path, i, m.match))
                end
            end
            if !exempt
                for m in eachmatch(literals, line)
                    push!(found, LintSupport.Site(path, i, m.match))
                end
            end
        end
    end
    return found
end
