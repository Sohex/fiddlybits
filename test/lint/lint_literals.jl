# lint_literals: REQ-NUM-001, docs/imports/julia-1.12.md.
# Refuses a float literal that is not the argument of a typed constructor, in
# source under root outside the exempt submodules. In a file the list declares
# precision-pinned, a literal is refused unless it stands in the right-hand side
# of one of the constants that entry names, or its value is returned unchanged
# by a round trip through Float32. The scope is the record the entry names.

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

"""
    blank_constants(text, names)

`text` with the right-hand side of every `const NAME = ...` for `NAME` in
`names` replaced by spaces, from the `=` to the end of the line the value's
brackets close on. Newlines are kept, so line numbers do not move. A name that
is not declared in `text` blanks nothing.
"""
function blank_constants(text::AbstractString, names)
    out = collect(text)
    for name in names
        pat = Regex("(?m)^[ \\t]*const[ \\t]+" * name * "[ \\t]*=")
        for m in eachmatch(pat, String(out))
            depth = 0
            k = m.offset + length(m.match)
            while k <= length(out)
                c = out[k]
                (c === '(' || c === '[') && (depth += 1)
                (c === ')' || c === ']') && (depth -= 1)
                c === '\n' && depth <= 0 && break
                c === '\n' || (out[k] = ' ')
                k += 1
            end
        end
    end
    return String(out)
end

const FLOAT = r"(?<![0-9A-Za-z_.])[0-9]+\.[0-9]*(?:[eEf][-+]?[0-9]+)?(?![0-9A-Za-z_])|(?<![0-9A-Za-z_.])[0-9]+[eE][-+]?[0-9]+(?![0-9A-Za-z_])"

"""
    precision_free(text)

`true` when the float literal `text` denotes a value a round trip through
`Float32` returns unchanged, so it is the same number at either precision. An
exponent marker of `f` is read as `e`. Text that does not parse is `false`.
"""
function precision_free(text::AbstractString)
    v = tryparse(Float64, replace(text, 'f' => 'e'))
    v === nothing && return false
    return Float64(Float32(v)) == v
end

"The project root, three levels above the directory the lists sit in."
literals_project() = normpath(joinpath(LintSupport.lists_dir(), "..", "..", ".."))

"The sites `path` offers under `root`, with the literals of `entry`'s constants blanked."
function pinned_sites(root::AbstractString, path::AbstractString, entry, constructors)
    found = LintSupport.Site[]
    text = LintSupport.strip_comments_and_strings(read(joinpath(root, path), String))
    for (i, line) in enumerate(split(blank_constants(text, entry["constants"]), '\n'))
        for m in eachmatch(FLOAT, blank_typed(line, constructors))
            precision_free(m.match) || push!(found, LintSupport.Site(path, i, m.match))
        end
    end
    return found
end

function lint_literals(root::AbstractString)
    cfg = LintSupport.list("literals.toml")
    pinned = Dict{String,Any}(e["path"] => e for e in cfg["precision_pinned"])
    found = LintSupport.Site[]
    for e in cfg["precision_pinned"]
        isfile(joinpath(literals_project(), e["record"])) && continue
        push!(found, LintSupport.Site("test/lint/lists/literals.toml", 0, e["record"]))
    end
    for path in LintSupport.sources(root)
        any(e -> startswith(path, e), cfg["exempt"]) && continue
        if haskey(pinned, path)
            append!(found, pinned_sites(root, path, pinned[path], cfg["typed_constructors"]))
        else
            LintSupport.each_line(root, path) do i, line
                for m in eachmatch(FLOAT, blank_typed(line, cfg["typed_constructors"]))
                    push!(found, LintSupport.Site(path, i, m.match))
                end
            end
        end
    end
    return found
end
