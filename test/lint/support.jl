module LintSupport

using TOML

"One offending place: the file it is in, the line number, and the text that offends."
struct Site
    file::String
    line::Int
    found::String
end

Base.show(io::IO, s::Site) = print(io, s.file, ":", s.line, ": ", s.found)

"The directory the lists live in."
lists_dir() = joinpath(@__DIR__, "lists")

"Read one TOML list beside the suite."
list(name::AbstractString) = TOML.parsefile(joinpath(lists_dir(), name))

"Every file under `root` whose name ends in one of `exts`, relative paths, sorted."
function files(root::AbstractString, exts::NTuple{N,String}) where {N}
    out = String[]
    isdir(root) || return out
    for (dir, _, names) in walkdir(root), name in names
        any(e -> endswith(name, e), exts) || continue
        push!(out, relpath(joinpath(dir, name), root))
    end
    return sort(out)
end

sources(root::AbstractString) = files(root, (".jl",))
prose(root::AbstractString) = files(root, (".md",))

"""
    strip_comments_and_strings(text)

`text` with every comment, string literal and docstring replaced by spaces of the
same length, so that line numbers and column positions are unchanged.
"""
function strip_comments_and_strings(text::AbstractString)
    out = collect(text)
    n = length(out)
    i = 1
    blank(a, b) = for k in a:b
        out[k] === '\n' || (out[k] = ' ')
    end
    while i <= n
        c = out[i]
        if c === '#'
            j = i
            while j <= n && out[j] !== '\n'
                j += 1
            end
            blank(i, j - 1)
            i = j + 1
        elseif c === '"' && i + 2 <= n && out[i+1] === '"' && out[i+2] === '"'
            j = i + 3
            while j + 2 <= n && !(out[j] === '"' && out[j+1] === '"' && out[j+2] === '"')
                j += 1
            end
            stop = min(j + 2, n)
            blank(i, stop)
            i = stop + 1
        elseif c === '"'
            j = i + 1
            while j <= n && out[j] !== '"'
                out[j] === '\\' ? (j += 2) : (j += 1)
            end
            blank(i, min(j, n))
            i = min(j, n) + 1
        else
            i += 1
        end
    end
    return String(out)
end

"""
    each_line(f, root, path)

Call `f(lineno, line)` for every line of `path` under `root`, with comments and
string literals blanked.
"""
function each_line(f, root::AbstractString, path::AbstractString)
    text = strip_comments_and_strings(read(joinpath(root, path), String))
    for (i, line) in enumerate(split(text, '\n'))
        f(i, line)
    end
end

"Sites for every match of `pattern` in the source files under `root`, skipping `exempt` paths."
function grep_sources(root::AbstractString, pattern::Regex; exempt = String[])
    found = Site[]
    for path in sources(root)
        any(e -> startswith(path, e), exempt) && continue
        each_line(root, path) do i, line
            for m in eachmatch(pattern, line)
                push!(found, Site(path, i, m.match))
            end
        end
    end
    return found
end

end # module LintSupport
