using Test

# oracles.dataset_links: docs/oracles/registry.toml.
#
# Reads the datasets field of every registry row and the oracles key of every manifest
# under docs/oracles/data and docs/inputs/data, and refuses a link that does not
# resolve or is written on one side only. One dirty fixture per clause, each raising
# exactly the problems its entry states, and one clean fixture raising none.

include("harness.jl")

const PROJECT = normpath(joinpath(@__DIR__, "..", ".."))
const FIXTURES = joinpath(@__DIR__, "fixtures")

tree(root) = (registry = joinpath(root, "docs", "oracles", "registry.toml"),
              oracle_data = joinpath(root, "docs", "oracles", "data"),
              input_data = joinpath(root, "docs", "inputs", "data"))

found(case) = DatasetHarness.problems(; tree(joinpath(FIXTURES, case))...)

"Each dirty fixture, how many problems it raises, and a phrase every one of them carries."
const CONTROLS = (
    (case = "absent_manifest",    count = 1, phrase = "names manifest nowhere, which does not exist"),
    (case = "absent_oracle",      count = 1, phrase = "names oracle earth.sea_ice_extent_cycle, which is not a registry row"),
    (case = "one_sided_row",      count = 1, phrase = "whose oracles key does not name it back"),
    (case = "one_sided_manifest", count = 1, phrase = "whose datasets field does not name it back"),
    (case = "unread_manifest",    count = 1, phrase = "names no registry row"),
    (case = "no_datasets_field",  count = 1, phrase = "a tier 2 row with no datasets field"),
    (case = "not_a_list",         count = 2, phrase = "is not a list"),
    (case = "id_in_anchors",      count = 1, phrase = "anchor carries the oracle id earth.sea_ice_extent_cycle"),
    (case = "id_not_filename",    count = 1, phrase = "is not its file name"),
    (case = "duplicate_id",       count = 1, phrase = "is also used by"),
)

@testset "datasets" begin
    @testset "the tree" begin
        problems = DatasetHarness.problems(; tree(PROJECT)...)
        isempty(problems) || @info "dataset link problems on the tree" problems
        @test isempty(problems)
    end

    @testset "the tree run is not vacuous" begin
        t = tree(PROJECT)
        scratch = DatasetHarness.Problem[]
        oracle_data = DatasetHarness.manifests(t.oracle_data, true, scratch)
        input_data = DatasetHarness.manifests(t.input_data, false, scratch)
        @test length(oracle_data) == count(n -> endswith(n, ".toml"), readdir(t.oracle_data))
        @test length(oracle_data) >= 7
        @test length(input_data) >= 4
        @test all(m -> !isempty(m.oracles), oracle_data)
    end

    @testset "the clean fixture passes" begin
        problems = found("clean")
        isempty(problems) || @info "the clean fixture raised" problems
        @test isempty(problems)
    end

    @testset "positive control: $(c.case) is refused" for c in CONTROLS
        problems = found(c.case)
        @test length(problems) == c.count
        @test all(p -> occursin(c.phrase, p.reason), problems)
        length(problems) == c.count || @info "$(c.case) raised" problems
    end
end
