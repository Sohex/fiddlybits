using Test
using TOML

# build.lint_positive_controls and build.manifest_exclusions.
#
# Every lint is one function taking a root path and returning the sites it refuses,
# so the same function is called on a fixture and on the tree. Each entry of the
# table carries a dirty fixture it must flag and a clean fixture it must pass; an
# entry with either fixture missing fails rather than passing vacuously.

module Lints

include("support.jl")
include("lint_earth.jl")
include("lint_literals.jl")
include("lint_index_base.jl")
include("lint_calendar.jl")
include("lint_journal_emitter.jl")
include("lint_effort.jl")
include("lint_front_matter.jl")
include("lint_manifest.jl")
include("lint_static_arrays.jl")
include("lint_fused_multiply_add.jl")
include("lint_sourced.jl")

end # module Lints

const LINT_DIR = @__DIR__
const PROJECT = normpath(joinpath(LINT_DIR, "..", ".."))
const FIXTURES = joinpath(LINT_DIR, "fixtures")

"name, the function, the subpath of the tree it reads, and the subpath inside a fixture."
const TABLE = (
    (name = "lint_earth",            f = Lints.lint_earth,            tree = "src",  inside = ""),
    (name = "lint_literals",         f = Lints.lint_literals,         tree = "src",  inside = ""),
    (name = "lint_index_base",       f = Lints.lint_index_base,       tree = "src",  inside = ""),
    (name = "lint_calendar",         f = Lints.lint_calendar,         tree = "src",  inside = ""),
    (name = "lint_journal_emitter",  f = Lints.lint_journal_emitter,  tree = "src",  inside = ""),
    (name = "lint_effort",           f = Lints.lint_effort,           tree = "docs", inside = "docs"),
    (name = "lint_front_matter",     f = Lints.lint_front_matter,     tree = "docs", inside = "docs"),
    (name = "lint_manifest",         f = Lints.lint_manifest,         tree = ".",    inside = ""),
    (name = "lint_static_arrays",    f = Lints.lint_static_arrays,    tree = "src",  inside = ""),
    (name = "lint_fused_multiply_add", f = Lints.lint_fused_multiply_add, tree = "src", inside = ""),
    (name = "lint_sourced",           f = Lints.lint_sourced,           tree = ".",    inside = ""),
)

fixture(entry, kind) = joinpath(FIXTURES, entry.name, kind, entry.inside)

@testset "lint" begin
    @testset "$(entry.name)" for entry in TABLE
        dirty, clean = fixture(entry, "dirty"), fixture(entry, "clean")

        @testset "both fixtures exist" begin
            @test isdir(dirty)
            @test isdir(clean)
        end

        if isdir(dirty) && isdir(clean)
            flagged = entry.f(dirty)
            passed = entry.f(clean)
            @test !isempty(flagged)
            @test isempty(passed)
            isempty(passed) || @info "$(entry.name) flagged its clean fixture" passed
        end
    end

    @testset "the tree" begin
        @testset "the roots hold what the lints read" begin
            @test length(Lints.LintSupport.sources(joinpath(PROJECT, "src"))) >= 16
            @test length(Lints.LintSupport.prose(joinpath(PROJECT, "docs"))) >= 150
            @test isfile(joinpath(PROJECT, "Manifest.toml"))
        end

        @testset "$(entry.name)" for entry in TABLE
            found = entry.f(normpath(joinpath(PROJECT, entry.tree)))
            isempty(found) || @info "$(entry.name) on the tree" found
            @test isempty(found)
        end
    end

    @testset "the tree run is not vacuous" begin
        @testset "lint_effort reads the records it exempts" begin
            exempt = Lints.LintSupport.list("effort.toml")["exemption"]
            words = Lints.LintSupport.list("effort.toml")["words"]
            for e in exempt
                text = read(joinpath(PROJECT, e["path"]), String)
                @test any(w -> occursin(lowercase(w), lowercase(text)), words)
            end
        end

        @testset "lint_front_matter reads every record" begin
            records = 0
            not_records = Set(String[Lints.LintSupport.list("front_matter.toml")["not_records"]...])
            for dir in keys(Lints.LintSupport.list("front_matter.toml")["required"])
                d = joinpath(PROJECT, dir)
                records += count(p -> !(basename(p) in not_records), Lints.LintSupport.prose(d))
            end
            @test records >= 170
        end
    end

    @testset "the Earth literal list is the one the review method declares" begin
        readme = read(joinpath(PROJECT, "docs", "imports", "README.md"), String)
        row = only(filter(l -> startswith(l, "| A3 "), split(readme, '\n')))
        declared = Set(String[m.captures[1] for m in eachmatch(r"`([0-9][0-9.e+-]*)`", row)])
        copied = Set(String[Lints.LintSupport.list("earth.toml")["literals"]...])
        @test copied == declared
    end

    @testset "every exclusion names a record that exists" begin
        for entry in Lints.LintSupport.list("manifest_exclusions.toml")["exclusion"]
            @test isfile(joinpath(PROJECT, entry["record"]))
        end
    end

    @testset "every effort exemption names a record that exists, with a reason" begin
        for e in Lints.LintSupport.list("effort.toml")["exemption"]
            @test isfile(joinpath(PROJECT, e["path"]))
            @test !isempty(e["reason"])
        end
    end

    @testset "lint_sourced places every row of docs/references/INDEX.md" begin
        _, unplaced = Lints.read_index(joinpath(PROJECT, "docs", "references", "INDEX.md"))
        isempty(unplaced) || @info "lint_sourced: rows it could not place" unplaced
        @test isempty(unplaced)
    end

    @testset "EarthRatios.rotation_rate_unit's locator resolves to a read row" begin
        status, _ = Lints.read_index(joinpath(PROJECT, "docs", "references", "INDEX.md"))
        @test get(status, "10.1007/s001900050278", "missing") == "read"
    end

    @testset "a fixture index row's title reads its status through read_index" begin
        _, _, titles = Lints.read_index(joinpath(FIXTURES, "lint_sourced", "clean", "docs", "references", "INDEX.md"))
        @test get(titles, "A read row with a bare DOI", "missing") == "read"
        @test get(titles, "A held row with a bare DOI", "missing") == "held"
    end

    @testset "the title of EarthRatios.rotation_rate_unit's row resolves to the same status" begin
        _, _, titles = Lints.read_index(joinpath(PROJECT, "docs", "references", "INDEX.md"))
        @test get(titles, "Geodetic Reference System 1980", "missing") == "read"
    end

    @testset "positive control: an altered title does not resolve" begin
        _, _, titles = Lints.read_index(joinpath(PROJECT, "docs", "references", "INDEX.md"))
        @test haskey(titles, "Geodetic Reference System 1980")
        @test !haskey(titles, "Geodetic Reference System 1981")
    end

    @testset "positive control: two rows sharing a title are refused" begin
        # thum2019-quincy.pdf (held) and thum2019-quincy-supplement.pdf (read) carry this title.
        _, _, titles = Lints.read_index(joinpath(PROJECT, "docs", "references", "INDEX.md"))
        shared = "A new model of the coupled carbon, nitrogen, and phosphorus cycles in the terrestrial biosphere (QUINCY v1.0; revision 1996)"
        @test !haskey(titles, shared)
    end

    @testset "positive control: the same locator against a held row is refused" begin
        mktempdir() do dir
            srcdir = joinpath(dir, "src", "EarthRatios")
            mkpath(srcdir)
            cp(joinpath(PROJECT, "src", "EarthRatios", "EarthRatios.jl"),
               joinpath(srcdir, "EarthRatios.jl"))
            docsdir = joinpath(dir, "docs", "references")
            mkpath(docsdir)
            index_text = read(joinpath(PROJECT, "docs", "references", "INDEX.md"), String)
            held_text = replace(index_text,
                "`10.1007/s001900050278` | read |" => "`10.1007/s001900050278` | held |")
            @test held_text != index_text
            write(joinpath(docsdir, "INDEX.md"), held_text)

            flagged = Lints.lint_sourced(dir)
            @test any(flagged) do s
                s.found == "10.1007/s001900050278" &&
                    s.file == joinpath("src", "EarthRatios", "EarthRatios.jl")
            end
        end
    end

    @testset "positive control: a title does not satisfy lint_sourced as a locator" begin
        mktempdir() do dir
            srcdir = joinpath(dir, "src", "EarthRatios")
            mkpath(srcdir)
            text = read(joinpath(PROJECT, "src", "EarthRatios", "EarthRatios.jl"), String)
            titled = replace(text, "\"10.1007/s001900050278\"" => "\"Geodetic Reference System 1980\"")
            @test titled != text
            write(joinpath(srcdir, "EarthRatios.jl"), titled)
            docsdir = joinpath(dir, "docs", "references")
            mkpath(docsdir)
            cp(joinpath(PROJECT, "docs", "references", "INDEX.md"), joinpath(docsdir, "INDEX.md"))

            flagged = Lints.lint_sourced(dir)
            @test any(flagged) do s
                s.found == "Geodetic Reference System 1980" &&
                    s.file == joinpath("src", "EarthRatios", "EarthRatios.jl")
            end
        end
    end
end
