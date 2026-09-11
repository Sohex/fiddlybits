# lint_literals: REQ-NUM-001, docs/imports/julia-1.12.md.
# Refuses a float literal that is not the argument of a typed constructor, in
# source under root outside the exempt submodules.

"`line` with every `FT(...)` span blanked, so a typed literal is not seen."
function blank_typed(line::AbstractString, constructors)
    out = collect(line)
    for ctor in constructors
        pat = Regex("\\b" * ctor * "\\(")
        for m in eachmatch(pat, String(out))
            depth = 0
            k = m.offset + length(m.match) - 1
            while k <= length(out)
                out[k] === '(' && (depth += 1)
                out[k] === ')' && (depth -= 1)
                depth == 0 && break
                k += 1
            end
            for j in m.offset:min(k, length(out))
                out[j] = ' '
            end
        end
    end
    return String(out)
end

const FLOAT = r"(?<![0-9A-Za-z_.])[0-9]+\.[0-9]*(?:[eEf][-+]?[0-9]+)?(?![0-9A-Za-z_])|(?<![0-9A-Za-z_.])[0-9]+[eE][-+]?[0-9]+(?![0-9A-Za-z_])"

function lint_literals(root::AbstractString)
    cfg = LintSupport.list("literals.toml")
    found = LintSupport.Site[]
    for path in LintSupport.sources(root)
        any(e -> startswith(path, e), cfg["exempt"]) && continue
        LintSupport.each_line(root, path) do i, line
            for m in eachmatch(FLOAT, blank_typed(line, cfg["typed_constructors"]))
                push!(found, LintSupport.Site(path, i, m.match))
            end
        end
    end
    return found
end
