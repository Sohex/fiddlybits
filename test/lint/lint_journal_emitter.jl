# lint_journal_emitter: decision 0042, one emitter.
# Refuses any file other than the emitter naming the journal's path constant.

function lint_journal_emitter(root::AbstractString)
    cfg = LintSupport.list("journal.toml")
    pat = Regex("\\b" * cfg["path_constant"] * "\\b")
    found = LintSupport.Site[]
    for path in LintSupport.sources(root)
        path == cfg["emitter"] && continue
        LintSupport.each_line(root, path) do i, line
            for m in eachmatch(pat, line)
                push!(found, LintSupport.Site(path, i, m.match))
            end
        end
    end
    return found
end
