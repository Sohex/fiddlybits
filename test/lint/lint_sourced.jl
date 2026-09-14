# lint_sourced: REQ-SYS-001, decision 0007, docs/plans/fiddlybits-52v.4-system.md,
# section "The five dispositions".
# Refuses a Sourced locator whose identifier is not a string literal, and one whose
# identifier is a string literal not marked read in docs/references/INDEX.md, in
# src/ and test/planets/ under root.

"Whether `line` is a Markdown table separator row."
is_separator(line::AbstractString) = !isempty(line) &&
    all(c -> c in "-:| \t", line) && occursin('-', line)

"`line` split on its unescaped '|' characters, the boundary empties of a well-formed
'|...|' row dropped and each cell stripped; '\\|' is kept as a literal '|' inside a
cell rather than read as a delimiter. `nothing` when `line` does not open with '|'."
function row_cells(line::AbstractString)
    s = strip(line)
    startswith(s, "|") || return nothing
    cells = String[]
    buf = IOBuffer()
    chars = collect(s)
    i, n = 1, length(chars)
    while i <= n
        c = chars[i]
        if c == '\\' && i < n && chars[i + 1] == '|'
            print(buf, '|')
            i += 2
        elseif c == '|'
            push!(cells, String(take!(buf)))
            buf = IOBuffer()
            i += 1
        else
            print(buf, c)
            i += 1
        end
    end
    push!(cells, String(take!(buf)))
    popfirst!(cells)
    endswith(s, "|") && pop!(cells)
    return [strip(c) for c in cells]
end

"The DOI inside `cell`, or `nothing` when it carries none."
function extract_doi(cell::AbstractString)
    m = match(r"10\.\d{4,9}/\S+", cell)
    return m === nothing ? nothing : m.match
end

"`cell` with backticks and surrounding space stripped, and one trailing period dropped."
function normalize_title(cell::AbstractString)
    t = strip(cell, ['`', ' '])
    return endswith(t, ".") ? t[1:end-1] : t
end

"""
    read_index(path)

`(status, unplaced, titles)`: every row of `path` under a table whose header names
`filename`, `identifier` and `status` columns, keyed by its file key and, where its
identifier cell carries one, its DOI, to its status column; and every row under such
a header whose cell count does not match the header's, or whose status cell is none
of read/held/requested, as `(line, text)`. A table whose header does not name all
three columns is not a references table and its rows are not read. `titles` keys
every placed row's normalised title cell, read from a header column naming `title`,
to its status column; a normalised title two placed rows share is a key of neither.
"""
function read_index(path::AbstractString)
    status = Dict{String,String}()
    unplaced = Tuple{Int,String}[]
    title_status = Dict{String,String}()
    title_count = Dict{String,Int}()
    valid = ("read", "held", "requested")
    ncols = nothing
    filename_col = identifier_col = status_col = 0
    title_col = nothing

    lines = readlines(path)
    i = 1
    while i <= length(lines)
        line = lines[i]
        cells = row_cells(line)
        if cells === nothing
            i += 1
            continue
        end
        if i < length(lines) && is_separator(lines[i + 1])
            names = [lowercase(c) for c in cells]
            filename_col = findfirst(==("filename"), names)
            identifier_col = findfirst(==("identifier"), names)
            status_col = findfirst(==("status"), names)
            title_col = findfirst(n -> occursin("title", n), names)
            ncols = (filename_col !== nothing && identifier_col !== nothing &&
                    status_col !== nothing) ? length(cells) : nothing
            i += 2
            continue
        end
        if ncols !== nothing
            if length(cells) == ncols && cells[status_col] in valid
                s = cells[status_col]
                status[strip(cells[filename_col], ['`', ' '])] = s
                doi = extract_doi(strip(cells[identifier_col], ['`', ' ']))
                doi === nothing || (status[doi] = s)
                if title_col !== nothing
                    t = normalize_title(cells[title_col])
                    title_status[t] = s
                    title_count[t] = get(title_count, t, 0) + 1
                end
            else
                push!(unplaced, (i, line))
            end
        end
        i += 1
    end
    titles = Dict(t => s for (t, s) in title_status if title_count[t] == 1)
    return status, unplaced, titles
end

function lint_sourced(root::AbstractString)
    cfg = LintSupport.list("sourced.toml")
    status, _ = read_index(joinpath(root, cfg["index"]))
    found = LintSupport.Site[]
    citation = r"identifier\s*=\s*([^,\)]*)"
    literal = r"^\"([^\"$\\]*)\"$"

    for area in cfg["areas"]
        dir = joinpath(root, area)
        isdir(dir) || continue
        for path in LintSupport.sources(dir)
            text = read(joinpath(dir, path), String)
            for (i, line) in enumerate(split(text, '\n'))
                for m in eachmatch(citation, line)
                    raw = strip(m.captures[1])
                    lit = match(literal, raw)
                    if lit === nothing
                        push!(found, LintSupport.Site(joinpath(area, path), i, raw))
                        continue
                    end
                    identifier = lit.captures[1]
                    get(status, identifier, "missing") == "read" ||
                        push!(found, LintSupport.Site(joinpath(area, path), i, identifier))
                end
            end
        end
    end
    return found
end
