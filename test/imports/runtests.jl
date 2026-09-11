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
