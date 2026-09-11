# lint_static_arrays: docs/imports/staticarrays-jl.md.
# Refuses MVector and MMatrix (bare and as the macros @MVector and @MMatrix),
# `mul!` applied to a static operand, and the random constructors that reach
# Random.GLOBAL_RNG, in source under root.

function lint_static_arrays(root::AbstractString)
    cfg = LintSupport.list("static_arrays.toml")
    found = LintSupport.Site[]

    static_alt = join(cfg["static_types"], "|")
    mutable_pat = Regex("\\b(?:" * join(cfg["mutable_types"], "|") * ")\\b")
    mul_pat = Regex("\\bmul!\\s*\\(")
    static_on_line = Regex("\\b(?:" * static_alt * ")\\b")
    macro_rand_pat = Regex("@S(?:Vector|Matrix)\\s+rand\\b")
    call_rand_pat = Regex("\\b(?:rand|randn)\\s*\\(\\s*(?:" * static_alt * ")\\b")

    for path in LintSupport.sources(root)
        any(e -> startswith(path, e * "/") || startswith(path, e), cfg["exempt"]) && continue
        LintSupport.each_line(root, path) do i, line
            for m in eachmatch(mutable_pat, line)
                push!(found, LintSupport.Site(path, i, m.match))
            end
            for m in eachmatch(mul_pat, line)
                occursin(static_on_line, line) && push!(found, LintSupport.Site(path, i, m.match))
            end
            for m in eachmatch(macro_rand_pat, line)
                push!(found, LintSupport.Site(path, i, m.match))
            end
            for m in eachmatch(call_rand_pat, line)
                push!(found, LintSupport.Site(path, i, m.match))
            end
        end
    end
    return found
end
