using Test
using TOML

# oracles.registry_wellformed, its verdict-shape clauses: docs/oracles/registry.toml.
#
# Reads every row and protocol of the registry and refuses a row carrying more than one
# verdict semantics, a verdict named in prose, a protocol that is not declared once
# and named, a depends_on that does not resolve to a row of its tier or a lower one or
# that cycles, a row id named in prose, or a clause of a dependency's threshold carried
# by the row that depends on it. One dirty fixture per clause, each raising exactly the problems its entry
# states, and one clean fixture raising none.

include("wellformed.jl")

const WELLFORMED_REGISTRY = normpath(joinpath(@__DIR__, "..", "..", "docs", "oracles", "registry.toml"))
const WELLFORMED_FIXTURES = joinpath(@__DIR__, "fixtures")

wellformed_found(case) = Wellformed.problems(joinpath(WELLFORMED_FIXTURES, case * ".toml"))

"Each dirty fixture, how many problems it raises, and a phrase every one of them carries."
const WELLFORMED_CONTROLS = (
    (case = "identity_and_report_under_one_bar", count = 2, phrase = "of a fail_bar row gives a constituent no bar"),
    (case = "verdict_named_in_threshold",        count = 1, phrase = "only verdict_kind names a verdict"),
    (case = "bar_in_report_row",                 count = 1, phrase = "of a report row gives a constituent a bar"),
    (case = "undefined_verdict_kind",            count = 1, phrase = "is not one of fail_bar, report"),
    (case = "no_threshold",                      count = 1, phrase = "no threshold to read its verdict shape from"),
    (case = "protocol_system_field",             count = 1, phrase = "carries protocol_system"),
    (case = "tier3_without_protocol",            count = 1, phrase = "a tier 3 row with no protocol"),
    (case = "tier2_with_protocol",               count = 1, phrase = "a tier 2 row names protocol"),
    (case = "absent_protocol",                   count = 1, phrase = "which is not declared"),
    (case = "unnamed_protocol",                  count = 1, phrase = "a protocol no row names"),
    (case = "duplicate_protocol",                count = 1, phrase = "protocol id is used more than once"),
    (case = "protocol_without_normalisation",    count = 1, phrase = "a protocol with no normalisation"),
    (case = "duplicate_row_id",                  count = 1, phrase = "row id is used more than once"),
    (case = "absent_dependency",                 count = 1, phrase = "which is not a row"),
    (case = "restated_dependency_threshold",     count = 1, phrase = "a row states no bar of a row it depends on"),
    (case = "dependency_named_in_prose",         count = 1, phrase = "a row names another row only in depends_on"),
    (case = "dependency_cycle",                  count = 2, phrase = "depends on itself"),
    (case = "dependency_on_higher_tier",         count = 1, phrase = "rows of its own tier or a lower one"),
    (case = "depends_on_not_a_list",             count = 1, phrase = "depends_on is not a list of row ids"),
    (case = "dependency_named_twice",            count = 1, phrase = "in depends_on more than once"),
)

@testset "oracles" begin
    @testset "registry_wellformed: the tree" begin
        problems = Wellformed.problems(WELLFORMED_REGISTRY)
        isempty(problems) || @info "verdict shape problems on the tree" problems
        @test isempty(problems)
    end

    @testset "registry_wellformed: the tree run is not vacuous" begin
        doc = TOML.parsefile(WELLFORMED_REGISTRY)
        rows = doc["oracle"]
        @test length(rows) >= 150
        @test count(r -> r["verdict_kind"] == "report", rows) >= 20
        @test count(r -> r["tier"] == 3, rows) >= 9
        @test count(r -> haskey(r, "depends_on"), rows) >= 10
        obliquity = only(filter(r -> r["id"] == "sweep.obliquity", rows))
        @test "system.orbit_mean_insolation" in obliquity["depends_on"]
        @test all(r -> haskey(r, "protocol"), filter(r -> r["tier"] == 3, rows))
        @test length(doc["protocol"]) >= 9
        @test count(r -> r["tier"] == 1 && haskey(r, "protocol"), rows) >= 1
    end

    @testset "registry_wellformed: the clean fixture is accepted" begin
        problems = wellformed_found("clean")
        isempty(problems) || @info "the clean fixture raised" problems
        @test isempty(problems)
    end

    @testset "registry_wellformed: positive control $(c.case) is refused" for c in WELLFORMED_CONTROLS
        problems = wellformed_found(c.case)
        @test length(problems) == c.count
        @test all(p -> occursin(c.phrase, p.reason), problems)
        length(problems) == c.count || @info "$(c.case) raised" problems
    end
end
