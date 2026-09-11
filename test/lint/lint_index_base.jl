# lint_index_base: docs/imports/kernelabstractions.md, decision F7.
# Refuses an offset applied to a name the kernel bound with @index, and to the
# type that refuses arithmetic at the host boundary.

function lint_index_base(root::AbstractString)
    cfg = LintSupport.list("index_base.toml")
    bind = Regex("\\b([A-Za-z_][A-Za-z0-9_]*)\\s*=\\s*" * cfg["index_macro"] * "\\b")
    found = LintSupport.Site[]
    for path in LintSupport.sources(root)
        any(e -> startswith(path, e), cfg["exempt"]) && continue
        bound = Set{String}([cfg["refusing_type"]])
        lines = String[]
        LintSupport.each_line(root, path) do i, line
            push!(lines, line)
            for m in eachmatch(bind, line)
                push!(bound, m.captures[1])
            end
        end
        offset = Regex("\\b(?:" * join(sort(collect(bound)), "|") * ")\\s*[-+]\\s*1\\b")
        for (i, line) in enumerate(lines)
            for m in eachmatch(offset, line)
                push!(found, LintSupport.Site(path, i, m.match))
            end
        end
    end
    return found
end
