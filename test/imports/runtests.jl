using Test

# build.import_record_completeness.
#
# The check reads the dependency list and looks for records, never the reverse,
# because docs/imports also holds records of packages that were surveyed and
# refused, and those have nothing to test.

include("harness.jl")

const PROJECT = normpath(joinpath(@__DIR__, "..", ".."))
const FIXTURES = joinpath(@__DIR__, "fixtures")

tree(; root = PROJECT) = (project = joinpath(root, "Project.toml"),
                          manifest = joinpath(root, "Manifest.toml"),
                          imports = joinpath(root, "docs", "imports"),
                          registry = joinpath(root, "docs", "oracles", "registry.toml"),
                          root = root)

"The checks the plan's owner table accounts for."
function owned_checks(plan::AbstractString)
    text = read(plan, String)
    marker = "The named tests and their owners:"
    i = findfirst(marker, text)
    i === nothing && return Set{String}()
    table = text[last(i):end]
    stop = findfirst("\n## ", table)
    stop === nothing || (table = table[1:first(stop)])
    return Set{String}(m.captures[1] for m in eachmatch(r"`([a-z][A-Za-z0-9_/.-]*)`", table))
end

"""
    walk_without_shipped_arm(; project, manifest, imports, registry, root)

The walk fiddlybits-52v.1.20 replaced: every named check of every record
whose package is in `ImportHarness.dependencies(project, manifest)`. A
package Julia ships is never visited, so a record naming it, absent or not,
never surfaces here.
"""
function walk_without_shipped_arm(; project::AbstractString, manifest::AbstractString,
                                     imports::AbstractString, registry::AbstractString,
                                     root::AbstractString)
    found = ImportHarness.Problem[]
    by_name = ImportHarness.records(imports)
    ids = ImportHarness.oracle_ids(registry)
    for pkg in ImportHarness.dependencies(project, manifest)
        path = get(by_name, pkg, nothing)
        if path === nothing
            push!(found, ImportHarness.Problem(pkg, "no record in " * imports))
            continue
        end
        checks = ImportHarness.named_checks(path)
        if isempty(checks)
            push!(found, ImportHarness.Problem(pkg, "record " * path * " names no leak check"))
            continue
        end
        for check in checks
            ok = startswith(check, "test/") ? isfile(joinpath(root, check)) : (check in ids)
            ok || push!(found, ImportHarness.Problem(pkg, "record names " * check * ", which does not resolve"))
        end
    end
    return found
end

"""
    structural_problems_without_stdlib_set(; project, manifest, imports)

The split fiddlybits-52v.1.22 replaced: a name absent from
`ImportHarness.dependencies(project, manifest)` reads as shipped, the same
test `dependencies` itself applies to `[deps]`. A registered `[extras]` name
carries no manifest entry either, so it reads as shipped too and is never
required to carry a record.
"""
function structural_problems_without_stdlib_set(; project::AbstractString,
                                                   manifest::AbstractString,
                                                   imports::AbstractString)
    found = ImportHarness.Problem[]
    by_name = ImportHarness.records(imports)
    shipped = setdiff(Set(ImportHarness.named(project)), Set(ImportHarness.dependencies(project, manifest)))
    for pkg in ImportHarness.named(project)
        path = get(by_name, pkg, nothing)
        if path === nothing
            pkg in shipped && continue
            push!(found, ImportHarness.Problem(pkg, "no record in " * imports))
        elseif isempty(ImportHarness.named_checks(path))
            push!(found, ImportHarness.Problem(pkg, "record " * path * " names no leak check"))
        end
    end
    return found
end

@testset "imports" begin
    @testset "the dependency list is read, not the record directory" begin
        t = tree()
        deps = ImportHarness.dependencies(t.project, t.manifest)
        @test !isempty(deps)
        @test "CUDA" in deps
        @test !("SHA" in deps)
        @test !("Test" in deps)
        @test length(readdir(joinpath(PROJECT, "docs", "imports"))) > length(deps)
    end

    @testset "a registered extra is read from the stdlib set, not the manifest" begin
        t = tree()
        reg = ImportHarness.registered(t.project, t.manifest)
        @test "JET" in reg
        @test !("Test" in reg)
        @test !("Dates" in reg)
        @test !("InteractiveUtils" in reg)
        @test "CUDA" in reg
        @test !("SHA" in reg)
    end

    @testset "every dependency has a record naming a leak check" begin
        t = tree()
        found = ImportHarness.structural_problems(project = t.project, manifest = t.manifest,
                                                  imports = t.imports)
        isempty(found) || @info "structural problems" found
        @test isempty(found)
    end

    @testset "positive control: a dependency with no record is refused" begin
        t = tree(root = joinpath(FIXTURES, "no_record"))
        found = ImportHarness.structural_problems(project = t.project, manifest = t.manifest,
                                                  imports = t.imports)
        @test length(found) == 1
        @test found[1].package == "Adapt"
        @test occursin("no record", found[1].reason)
    end

    @testset "positive control: a record naming an absent test is refused" begin
        t = tree(root = joinpath(FIXTURES, "absent_test"))
        found = ImportHarness.problems(; t...)
        @test length(found) == 1
        @test found[1].package == "Adapt"
        @test occursin("test/nowhere/absent.jl", found[1].reason)
    end

    @testset "positive control: a record for a package Julia ships naming an absent test is refused" begin
        t = tree(root = joinpath(FIXTURES, "stdlib_absent_test"))
        broken = walk_without_shipped_arm(; t...)
        @test isempty(broken)
        found = ImportHarness.problems(; t...)
        @test length(found) == 1
        @test found[1].package == "Random"
        @test occursin("test/nowhere/absent.jl", found[1].reason)
    end

    @testset "positive control: a registered extra with no record is refused" begin
        t = tree(root = joinpath(FIXTURES, "extra_no_record"))
        broken = structural_problems_without_stdlib_set(project = t.project, manifest = t.manifest,
                                                         imports = t.imports)
        @test isempty(broken)
        found = ImportHarness.structural_problems(project = t.project, manifest = t.manifest,
                                                   imports = t.imports)
        @test length(found) == 1
        @test found[1].package == "FakeExtra"
        @test occursin("no record", found[1].reason)
    end

    @testset "every unresolved check is owned by a row" begin
        open = ImportHarness.unresolved(; tree()...)
        owned = owned_checks(joinpath(PROJECT, "docs", "plans", "fiddlybits-52v.1-skeleton.md"))
        @test !isempty(owned)
        for (pkg, checks) in open, check in checks
            @test check in owned
        end
        isempty(open) || @info "named checks awaiting their area row" open
    end
end
