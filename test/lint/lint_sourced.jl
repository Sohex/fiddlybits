# lint_sourced: REQ-SYS-001, decision 0007, docs/plans/fiddlybits-52v.4-system.md,
# section "The five dispositions".
# Refuses a Sourced locator whose identifier is not marked read in
# docs/references/INDEX.md, in src/ and test/planets/ under root.

"The identifier column and the status column of every table row of the references
index, keyed by identifier."
function read_index_status(path::AbstractString)
    status = Dict{String,String}()
    valid = ("read", "held", "requested")
    for line in eachline(path)
        startswith(strip(line), "|") || continue
        cells = strip.(split(line, "|"))
        cells = filter(!isempty, cells)
        length(cells) == 5 || continue
        cells[4] in valid || continue
        status[strip(cells[3], ['`', ' '])] = cells[4]
    end
    return status
end

function lint_sourced(root::AbstractString)
    cfg = LintSupport.list("sourced.toml")
    project = normpath(joinpath(@__DIR__, "..", ".."))
    status = read_index_status(joinpath(project, cfg["index"]))
    found = LintSupport.Site[]
    citation = r"identifier\s*=\s*\"([^\"]*)\""

    for area in cfg["areas"]
        dir = joinpath(root, area)
        isdir(dir) || continue
        for path in LintSupport.sources(dir)
            text = read(joinpath(dir, path), String)
            for (i, line) in enumerate(split(text, '\n'))
                for m in eachmatch(citation, line)
                    identifier = m.captures[1]
                    get(status, identifier, "missing") == "read" ||
                        push!(found, LintSupport.Site(joinpath(area, path), i, identifier))
                end
            end
        end
    end
    return found
end
