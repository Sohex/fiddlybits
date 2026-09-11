# lint_front_matter: decision 0036, every record header is TOML between +++ fences.
# Refuses a record whose header does not parse or lacks a key its directory requires.

using TOML
function lint_front_matter(root::AbstractString)
    cfg = LintSupport.list("front_matter.toml")
    not_records = Set(String[cfg["not_records"]...])
    found = LintSupport.Site[]
    for (dir, keys) in cfg["required"]
        d = joinpath(root, basename(dir))
        isdir(d) || continue
        for path in LintSupport.prose(d)
            basename(path) in not_records && continue
            full = joinpath(d, path)
            text = read(full, String)
            rel = joinpath(basename(dir), path)
            if !startswith(text, "+++")
                push!(found, LintSupport.Site(rel, 1, "no +++ front matter"))
                continue
            end
            stop = findnext("+++", text, 4)
            if stop === nothing
                push!(found, LintSupport.Site(rel, 1, "unclosed +++ front matter"))
                continue
            end
            header = try
                TOML.parse(text[4:first(stop)-1])
            catch e
                push!(found, LintSupport.Site(rel, 1, "front matter is not TOML"))
                continue
            end
            for k in keys
                haskey(header, k) || push!(found, LintSupport.Site(rel, 1, "missing key " * k))
            end
        end
    end
    return found
end
