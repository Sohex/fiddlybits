# lint_effort: docs/practice.md, no effort or schedule framing.
# Refuses a phrase from the list in prose under root, outside the records that
# state the rule.

function lint_effort(root::AbstractString)
    cfg = LintSupport.list("effort.toml")
    exempt = Set(String[e["path"] for e in cfg["exemption"]])
    pat = Regex("(?:" * join((replace(w, " " => "\\s+") for w in cfg["words"]), "|") * ")", "i")
    found = LintSupport.Site[]
    for path in LintSupport.prose(root)
        joinpath(basename(root), path) in exempt && continue
        for (i, line) in enumerate(eachline(joinpath(root, path)))
            for m in eachmatch(pat, line)
                push!(found, LintSupport.Site(path, i, m.match))
            end
        end
    end
    return found
end
