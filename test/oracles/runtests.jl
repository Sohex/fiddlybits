using Test
using TOML
using Fiddlybits

# oracles.registry_wellformed, its verdict-shape clauses: docs/oracles/registry.toml.
#
# Reads every row, protocol and instrument of the registry and refuses a row carrying
# more than one verdict semantics, a verdict named in prose, a protocol that is not
# declared once and named, a depends_on that does not resolve to a row of its tier or a
# lower one or that cycles, a row id named in prose, a clause of a dependency's threshold
# carried by the row that depends on it, an instrument that is not declared once and
# named, a clause of an instrument's definition carried by a row, and an instrument
# parameter that does not equal the constant it names. One dirty fixture per clause,
# each raising exactly the problems its entry states, and one clean fixture raising none.
# Verdict_kind membership, a tier 3 row naming no protocol, a protocol named but not
# declared, a row id used twice, and a [[protocol]] entry's own shape are src/Oracles/
# registry.jl's loader's clauses; Wellformed.problems reads them through
# Wellformed.loader_problems rather than deciding them again.

include("wellformed.jl")

const WELLFORMED_REGISTRY = normpath(joinpath(@__DIR__, "..", "..", "docs", "oracles", "registry.toml"))
const WELLFORMED_FIXTURES = joinpath(@__DIR__, "fixtures")

wellformed_path(case) = joinpath(WELLFORMED_FIXTURES, case * ".toml")
wellformed_found(case) = Wellformed.problems(wellformed_path(case))

"The constants the instrument parameters of the fixtures name."
module InstrumentCode
module Backends
const ENSEMBLE_MEMBERS = 766
end
end

"Each dirty fixture, how many problems it raises, and a phrase every one of them carries."
const WELLFORMED_CONTROLS = (
    (case = "identity_and_report_under_one_bar", count = 2, phrase = "of a fail_bar row gives a constituent no bar"),
    (case = "verdict_named_in_threshold",        count = 1, phrase = "only verdict_kind names a verdict"),
    (case = "bar_in_report_row",                 count = 1, phrase = "of a report row gives a constituent a bar"),
    (case = "undefined_verdict_kind",            count = 1, phrase = "is not one of fail_bar, report"),
    (case = "no_threshold",                      count = 1, phrase = "no threshold to read its verdict shape from"),
    (case = "protocol_system_field",             count = 1, phrase = "carries protocol_system"),
    (case = "tier3_without_protocol",            count = 1, phrase = "a tier 3 entry names no protocol"),
    (case = "tier2_with_protocol",               count = 1, phrase = "a tier 2 row names protocol"),
    (case = "absent_protocol",                   count = 1, phrase = "which is not declared"),
    (case = "unnamed_protocol",                  count = 1, phrase = "a protocol no row names"),
    (case = "duplicate_protocol",                count = 1, phrase = "protocol id is used more than once"),
    (case = "duplicate_row_id",                  count = 1, phrase = "entry id is used more than once"),
    (case = "absent_dependency",                 count = 1, phrase = "which is not a row"),
    (case = "restated_dependency_threshold",     count = 1, phrase = "a row states no bar of a row it depends on"),
    (case = "dependency_named_in_prose",         count = 1, phrase = "a row names another row only in depends_on"),
    (case = "dependency_cycle",                  count = 2, phrase = "depends on itself"),
    (case = "dependency_on_higher_tier",         count = 1, phrase = "rows of its own tier or a lower one"),
    (case = "depends_on_not_a_list",             count = 1, phrase = "depends_on is not a list of row ids"),
    (case = "dependency_named_twice",            count = 1, phrase = "in depends_on more than once"),
    (case = "instrument_definition_in_row",      count = 1, phrase = "an instrument is defined once"),
    (case = "absent_instrument",                 count = 1, phrase = "names instrument ulp_ensemble, which is not declared"),
    (case = "unnamed_instrument",                count = 1, phrase = "an instrument no row names"),
    (case = "duplicate_instrument",              count = 1, phrase = "instrument id is used more than once"),
    (case = "instrument_without_definition",     count = 1, phrase = "an instrument with no definition"),
    (case = "instrument_not_an_id",              count = 1, phrase = "instrument is not an instrument id"),
    (case = "instrument_parameters_not_numbers", count = 2, phrase = "stating a number"),
    (case = "row_named_in_instrument_definition", count = 1, phrase = "an instrument names no row"),
    (case = "verdict_named_in_instrument_definition", count = 1, phrase = "definition names the verdict PASS"),
)

"""
Each dirty fixture raising more than one distinct phrase, once per problem it must
raise (`Oracles.problems`, read through `Wellformed.loader_problems`, raises the shape
of the protocol table and the row's undeclared reference to it together).
"""
const WELLFORMED_MULTI_PHRASE_CONTROLS = (
    (case = "protocol_without_normalisation",
     phrases = ("protocol carries no normalisation", "names protocol ape, which is not declared")),
)

"Each fixture whose instrument parameters disagree with `InstrumentCode`, how many problems it raises, and their phrase."
const PARAMETER_CONTROLS = (
    (case = "parameter_disagrees_with_code", count = 1, phrase = "states 765, and the constant it names is 766"),
    (case = "parameter_names_no_constant",   count = 1, phrase = "names no constant of InstrumentCode"),
)

@testset "oracles" begin
    @testset "registry_wellformed: the tree" begin
        problems = Wellformed.problems(WELLFORMED_REGISTRY)
        isempty(problems) || @info "verdict shape problems on the tree" problems
        @test isempty(problems)
    end

    @testset "registry_wellformed: the tree's instrument parameters state the constants they name" begin
        problems = Wellformed.parameter_problems(WELLFORMED_REGISTRY, Fiddlybits)
        isempty(problems) || @info "instrument parameter problems on the tree" problems
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
        ensemble = only(filter(i -> i["id"] == "ulp_ensemble", doc["instrument"]))
        @test length(ensemble["parameters"]) >= 4
        for id in ("repro.backend_ulp_envelope", "repro.fp32_kernel_certification")
            @test only(filter(r -> r["id"] == id, rows))["instrument"] == "ulp_ensemble"
        end
    end

    @testset "registry_wellformed: the clean fixture is accepted" begin
        problems = wellformed_found("clean")
        isempty(problems) || @info "the clean fixture raised" problems
        @test isempty(problems)
        parameters = Wellformed.parameter_problems(wellformed_path("clean"), InstrumentCode)
        isempty(parameters) || @info "the clean fixture's parameters raised" parameters
        @test isempty(parameters)
    end

    @testset "registry_wellformed: positive control $(c.case) is refused" for c in WELLFORMED_CONTROLS
        problems = wellformed_found(c.case)
        @test length(problems) == c.count
        @test all(p -> occursin(c.phrase, p.reason), problems)
        length(problems) == c.count || @info "$(c.case) raised" problems
    end

    @testset "registry_wellformed: positive control $(c.case) is refused" for c in WELLFORMED_MULTI_PHRASE_CONTROLS
        problems = wellformed_found(c.case)
        @test length(problems) == length(c.phrases)
        @test all(p -> any(m -> occursin(p, m.reason), problems), c.phrases)
        length(problems) == length(c.phrases) || @info "$(c.case) raised" problems
    end

    @testset "registry_wellformed: positive control $(c.case) is refused" for c in PARAMETER_CONTROLS
        @test isempty(wellformed_found(c.case))
        problems = Wellformed.parameter_problems(wellformed_path(c.case), InstrumentCode)
        @test length(problems) == c.count
        @test all(p -> occursin(c.phrase, p.reason), problems)
        length(problems) == c.count || @info "$(c.case) raised" problems
    end
end

# oracles.registry_wellformed (the loader and anchor clauses) and oracles.registration_rule.
include("registry.jl")
