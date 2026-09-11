# lint_calendar: REQ-SYS-102, docs/imports/ncdatasets.md.
# Refuses the calendar module in source under root outside Render.

function lint_calendar(root::AbstractString)
    cfg = LintSupport.list("calendar.toml")
    name = cfg["module_name"]
    pat = Regex("(?:using|import)\\s+(?:[A-Za-z_.]*\\.)?" * name * "\\b|\\b" * name * "\\.[A-Za-z_]")
    found = LintSupport.Site[]
    for path in LintSupport.sources(root)
        any(e -> startswith(path, e), cfg["exempt"]) && continue
        LintSupport.each_line(root, path) do i, line
            for m in eachmatch(pat, line)
                push!(found, LintSupport.Site(path, i, m.match))
            end
        end
    end
    return found
end
