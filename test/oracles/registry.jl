# oracles.registry_wellformed, its loader and anchor clauses, and oracles.registration_rule:
# docs/oracles/registry.toml, src/Oracles/registry.jl.
#
# Each clause is run on a fixture it must refuse and on the accepted twin beside it, then
# on the tree, whose verdicts are printed. A registry fixture is the clean fixture below
# with one field changed. A history fixture is a repository this file creates in a
# temporary directory and commits into. The admission controls and the history controls
# are each also run against a predicate or check that refuses nothing and one that
# refuses everything, which must fail them.

module RegistryRule

using Test
using TOML
using Fiddlybits: Oracles, Verdicts

const PROJECT = normpath(joinpath(@__DIR__, "..", ".."))
const TREE = joinpath(PROJECT, Oracles.REGISTRY_PATH)
const INDEX = joinpath(PROJECT, "docs", "references", "INDEX.md")

"The references index reader of test/lint."
module IndexReading
include(joinpath(@__DIR__, "..", "lint", "support.jl"))
include(joinpath(@__DIR__, "..", "lint", "lint_sourced.jl"))
end

"The references index of the fixtures: a title to its status."
const FIXTURE_INDEX = Dict("A read work" => "read", "A second read work" => "read", "A held work" => "held")

"A tier-1 entry."
tier1() = Dict{String,Any}(
    "id" => "mesh.fixture_identity", "tier" => 1, "subsystem" => "mesh", "dataset_or_reference" => "identity",
    "source_kind" => "identity", "statistic" => "sum of fixture cell areas against the sphere",
    "verdict_kind" => "fail_bar", "threshold" => "roundoff", "provisional" => true, "registered_at" => "",
    "holdout" => false, "anchors" => String[])

"A tier-1 system.* entry."
system1() = merge(tier1(), Dict{String,Any}("id" => "system.fixture_identity", "subsystem" => "system",
                                            "instances" => ["Earth()", "SyntheticNonEarth()"]))

"A tier-2 fail_bar entry with a bar wider than its observation's uncertainty, carrying neither form nor pattern_entry."
tier2() = Dict{String,Any}(
    "id" => "earth.fixture_mean", "tier" => 2, "subsystem" => "atmosphere", "dataset_or_reference" => "a fixture product",
    "source_kind" => "known quantity", "statistic" => "global-mean fixture flux against the product",
    "verdict_kind" => "fail_bar", "threshold" => "the published residual of the fixture model", "provisional" => true,
    "registered_at" => "", "holdout" => false, "anchors" => ["A read work"], "datasets" => String[],
    "bar_half_width" => 2.0, "observation_uncertainty" => 1.0)

"A tier-2 fail_bar entry of form pattern, carrying no pattern_entry."
tier2_pattern() = Dict{String,Any}(
    "id" => "earth.fixture_pattern", "tier" => 2, "subsystem" => "atmosphere",
    "dataset_or_reference" => "a fixture zonal product", "source_kind" => "known quantity",
    "statistic" => "zonal-mean fixture flux against the product", "verdict_kind" => "fail_bar",
    "threshold" => "the published zonal residual of the fixture model", "provisional" => true,
    "registered_at" => "", "holdout" => false, "anchors" => ["A read work"], "datasets" => String[],
    "bar_half_width" => 2.0, "observation_uncertainty" => 1.0, "form" => "pattern")

"A tier-2 fail_bar entry of form scalar, naming tier2_pattern's id in pattern_entry."
tier2_scalar() = Dict{String,Any}(
    "id" => "earth.fixture_scalar", "tier" => 2, "subsystem" => "atmosphere",
    "dataset_or_reference" => "a fixture global product", "source_kind" => "known quantity",
    "statistic" => "global-mean fixture flux against the product, second", "verdict_kind" => "fail_bar",
    "threshold" => "the published residual of the fixture model, second", "provisional" => true,
    "registered_at" => "", "holdout" => false, "anchors" => ["A read work"], "datasets" => String[],
    "bar_half_width" => 2.0, "observation_uncertainty" => 1.0, "form" => "scalar",
    "pattern_entry" => "earth.fixture_pattern")

"A tier-3 report entry."
tier3() = Dict{String,Any}(
    "id" => "sweep.fixture_rotation", "tier" => 3, "subsystem" => "dynamics", "dataset_or_reference" => "a fixture sweep",
    "source_kind" => "published spread", "statistic" => "fixture cell edge against rotation rate swept",
    "verdict_kind" => "report", "threshold" => "the published studies are the reference", "provisional" => true,
    "registered_at" => "", "holdout" => false, "anchors" => ["A read work"], "datasets" => String[],
    "protocol" => "fixture_protocol")

"The protocol the tier-3 entry names."
fixture_protocol() = Dict{String,Any}("id" => "fixture_protocol", "system" => "FixtureProtocol()",
                                      "normalisation" => "column mass")

"A registry document holding `entries` and `protocols`."
registry_doc(entries; protocols = [fixture_protocol()]) = Dict{String,Any}("oracle" => entries, "protocol" => protocols)

"The clean registry document."
clean_doc() = registry_doc([tier1(), system1(), tier2(), tier2_scalar(), tier2_pattern(), tier3()])

"Writes `content`, a document or text, to `path`, creating its directory."
function put(path::AbstractString, content)
    mkpath(dirname(path))
    content isa AbstractDict ? open(io -> TOML.print(io, content), path, "w") : write(path, content)
    return path
end

"Sets `key` of the entry of `doc` with id `id` to `value`, or deletes it when `value` is `nothing`."
function set_field!(doc::AbstractDict, id::AbstractString, key::AbstractString, value)
    row = only(filter(r -> r["id"] == id, doc["oracle"]))
    value === nothing ? delete!(row, key) : (row[key] = value)
    return doc
end

"Each registry fixture: the change to the clean document, and the phrase of each problem it raises, one problem per phrase."
const LOADER_CONTROLS = (
    (case = "a row with no threshold", change = d -> set_field!(d, "mesh.fixture_identity", "threshold", nothing),
     phrases = ("carries no threshold",)),
    (case = "a tier 1 system.* row with no instances", change = d -> set_field!(d, "system.fixture_identity", "instances", nothing),
     phrases = ("a tier 1 system.* entry names no instances",)),
    (case = "a tier 1 system.* row with empty instances", change = d -> set_field!(d, "system.fixture_identity", "instances", String[]),
     phrases = ("a tier 1 system.* entry names no instances",)),
    (case = "a row with no source_kind", change = d -> set_field!(d, "mesh.fixture_identity", "source_kind", nothing),
     phrases = ("carries no source_kind",)),
    (case = "a source_kind outside the closed set", change = d -> set_field!(d, "earth.fixture_mean", "source_kind", "tuned"),
     phrases = ("source_kind \"tuned\" is not one of",)),
    (case = "a tier outside the closed set", change = d -> set_field!(d, "mesh.fixture_identity", "tier", 4),
     phrases = ("tier 4 is not one of",)),
    (case = "a tier that is not an integer", change = d -> set_field!(d, "mesh.fixture_identity", "tier", "1"),
     phrases = ("tier is not an integer",)),
    (case = "a verdict_kind outside the closed set", change = d -> set_field!(d, "mesh.fixture_identity", "verdict_kind", "pass_bar"),
     phrases = ("verdict_kind \"pass_bar\" is not one of",)),
    (case = "a key that is not a registry field", change = d -> set_field!(d, "system.fixture_identity", "instance", ["Earth()"]),
     phrases = ("carries instance, which is not a registry field",)),
    (case = "a registered_at that is not a commit id", change = d -> set_field!(d, "mesh.fixture_identity", "registered_at", "abc123"),
     phrases = ("is neither empty nor a forty-digit commit id",)),
    (case = "a tier 3 row with no protocol", change = d -> set_field!(d, "sweep.fixture_rotation", "protocol", nothing),
     phrases = ("a tier 3 entry names no protocol",)),
    (case = "a protocol that is not declared", change = d -> set_field!(d, "sweep.fixture_rotation", "protocol", "absent_protocol"),
     phrases = ("names protocol absent_protocol, which is not declared",)),
    (case = "a tier 2 row with empty anchors", change = d -> set_field!(d, "earth.fixture_mean", "anchors", String[]),
     phrases = ("a tier 2 entry with no anchors",)),
    (case = "a bar with no uncertainty", change = d -> set_field!(d, "earth.fixture_mean", "observation_uncertainty", nothing),
     phrases = ("states bar_half_width with no observation_uncertainty",)),
    (case = "an uncertainty that is not positive", change = d -> set_field!(d, "earth.fixture_mean", "observation_uncertainty", -1.0),
     phrases = ("observation_uncertainty -1.0 is not positive",)),
    (case = "a bar set below a stated observational uncertainty", change = d -> set_field!(d, "earth.fixture_mean", "bar_half_width", 0.5),
     phrases = ("a bar narrower than its observation's uncertainty",)),
    (case = "a row id used twice", change = d -> push!(d["oracle"], tier1()),
     phrases = ("entry id is used more than once",)),
    (case = "a protocol with no normalisation", change = d -> delete!(only(d["protocol"]), "normalisation"),
     phrases = ("protocol carries no normalisation", "names protocol fixture_protocol, which is not declared")),
    (case = "an anchor that resolves to no index row", change = d -> set_field!(d, "sweep.fixture_rotation", "anchors", ["An unindexed work"]),
     phrases = ("anchor \"An unindexed work\" resolves to no row of the references index",)),
    (case = "a key spelt forms, which is not a registry field", change = d -> set_field!(d, "earth.fixture_scalar", "forms", "scalar"),
     phrases = ("carries forms, which is not a registry field",)),
    (case = "a form that is not a string", change = d -> set_field!(d, "earth.fixture_scalar", "form", 3),
     phrases = ("form is not a string",)),
    (case = "a pattern_entry that is not a string", change = d -> set_field!(d, "earth.fixture_scalar", "pattern_entry", ["x"]),
     phrases = ("pattern_entry is not a string",)),
)

"""
    admission_failures(admits, e, registered)

Each admission control predicate `admits` fails on entry `e`, which is `registered` or
not: an unregistered entry's value admitted on a model result, or any other use refused
where the rule admits it.
"""
function admission_failures(admits, e::Oracles.Entry, registered::Bool)
    failures = String[]
    model_result = 3.5
    fixture = Oracles.Fixture(3.5)
    (admits(e, model_result, Oracles.StatisticValue()) == registered) ||
        push!(failures, registered ? "refused a registered entry's value on a model result" :
                                     "admitted an unregistered entry's value on a model result")
    for (x, where) in ((model_result, "a model result"), (fixture, "a Fixture")),
        use in (Oracles.StatisticValue(), Oracles.Evaluates(), Oracles.ArmDifference())
        x === model_result && use isa Oracles.StatisticValue && continue
        admits(e, x, use) || push!(failures, "refused " * string(nameof(typeof(use))) * " on " * where)
    end
    return failures
end

"Runs `args` as git in `dir` with a fixture identity and no hooks or signing, returning its output."
fixture_git(dir::AbstractString, args::Cmd) =
    Oracles.git_read(dir, `-c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false
                           -c core.hooksPath=/dev/null $(args)`)

"The id of the commit at HEAD of the repository in `dir`."
head(dir::AbstractString) = strip(fixture_git(dir, `rev-parse HEAD`))

"Writes each path of `files` under `dir` and commits the tree with `message`; returns the commit id."
function commit!(dir::AbstractString, files::AbstractDict, message::AbstractString)
    for (path, content) in files
        put(joinpath(dir, path), content)
    end
    fixture_git(dir, `add -A`)
    fixture_git(dir, `commit -q --allow-empty -m $(message)`)
    return head(dir)
end

"The decision record text carrying the amendment line."
const DECISION_TEXT = "## Amendments\n\n- " * Oracles.AMENDMENT * ".\n"

"The files every history fixture opens with: a model source file and the testset named by each entry id."
function model_files(ids)
    return Dict{String,Any}(
        "src/Model.jl" => "module Model\nend\n",
        "test/model/runtests.jl" => join(("@testset \"" * id * "\" begin\nend\n" for id in ids), ""))
end

"""
    new_history(dir, entry; amended, branch)

A repository in `dir`, its only branch named `branch`, whose first commit holds a
registry with `entry`, the model files, an exceptions list with no entry, and, when
`amended`, the decision record carrying the amendment; returns the registry document.
"""
function new_history(dir::AbstractString, entry::AbstractDict; amended::Bool = true, branch::AbstractString = "main")
    mkpath(dir)
    fixture_git(dir, `init -q -b $(branch)`)
    doc = registry_doc([entry]; protocols = Any[])
    files = merge(model_files([entry["id"]]), Dict{String,Any}(Oracles.REGISTRY_PATH => doc, Oracles.EXCEPTIONS_PATH => ""))
    amended && (files[Oracles.DECISION_PATH] = DECISION_TEXT)
    commit!(dir, files, "first")
    return doc
end

"Sets the entry's registered_at to HEAD and commits the registry with `extra`; returns the commit id."
function register!(dir::AbstractString, doc::AbstractDict, extra::AbstractDict = Dict{String,Any}())
    only(doc["oracle"])["registered_at"] = head(dir)
    return commit!(dir, merge(Dict{String,Any}(Oracles.REGISTRY_PATH => doc), extra), "register")
end

"Sets `pairs` on the entry and commits the registry with `extra`; returns the commit id."
function edit!(dir::AbstractString, doc::AbstractDict, pairs::AbstractDict, extra::AbstractDict = Dict{String,Any}())
    merge!(only(doc["oracle"]), pairs)
    return commit!(dir, merge(Dict{String,Any}(Oracles.REGISTRY_PATH => doc), extra), "edit")
end

"A history: a tier-2 entry registered, its threshold changed with `change`, and registered again with `extra`."
function reregistration(dir, change::AbstractDict; extra = Dict{String,Any}(), at_change = Dict{String,Any}())
    doc = new_history(dir, tier2())
    register!(dir, doc)
    edit!(dir, doc, merge(Dict{String,Any}("threshold" => "the revised published residual"), change), at_change)
    register!(dir, doc, extra)
end

"A history: a tier-1 entry registered as `first_kind`, then edited to fail_bar and registered again."
function kind_change(dir, first_kind::AbstractString)
    doc = new_history(dir, merge(tier1(), Dict{String,Any}("verdict_kind" => first_kind, "threshold" => "roundoff, first")))
    register!(dir, doc)
    edit!(dir, doc, Dict{String,Any}("verdict_kind" => "fail_bar", "threshold" => "roundoff, second"))
    register!(dir, doc)
end

"""
A history: a branch changing the tier-1 entry's threshold, then committing `extra` on the
branch, merged into main with a merge commit.
"""
function merge_history(dir, extra::AbstractDict)
    doc = new_history(dir, tier1())
    fixture_git(dir, `checkout -q -b branch`)
    edit!(dir, doc, Dict{String,Any}("threshold" => "roundoff at every level"))
    isempty(extra) || commit!(dir, extra, "branch work")
    fixture_git(dir, `checkout -q main`)
    commit!(dir, Dict{String,Any}("notes/main.md" => "main moves on\n"), "main")
    fixture_git(dir, `merge -q --no-ff -m merge branch`)
end

"An exceptions list entry naming `merge` and `oracle`, with every field filled."
exception(merge::AbstractString, oracle::AbstractString) = Dict{String,Any}(
    "merge" => merge, "oracle" => oracle, "reason" => "a fixture merge", "row" => "fiddlybits-fixture",
    "date" => TOML.Dates.Date(2026, 9, 14), "permitted_by" => "the fixture user's permission")

"Writes the exceptions list under `dir` holding `entries`."
list!(dir::AbstractString, entries) =
    put(joinpath(dir, Oracles.EXCEPTIONS_PATH), Dict{String,Any}("exception" => entries))

"A history: a branch changing the tier-1 entry's threshold together with `extra`, merged, and the merge listed for `oracle`."
function listed_merge(dir, extra::AbstractDict, oracle::AbstractString)
    merge_history(dir, extra)
    list!(dir, [exception(head(dir), oracle)])
end

"""
A history: a feature branch diverges from main; main merges a registry-only change to the
tier-1 entry's threshold, then a change to the testset named by it; the feature branch
merges main into itself, commits more work, and merges into main with no threshold change
of its own.
"""
function sync_history(dir)
    doc = new_history(dir, tier1())
    fixture_git(dir, `checkout -q -b feature`)
    commit!(dir, Dict{String,Any}("notes/feature.md" => "feature work\n"), "feature work")
    fixture_git(dir, `checkout -q -b threshold main`)
    edit!(dir, doc, Dict{String,Any}("threshold" => "roundoff at every level"))
    fixture_git(dir, `checkout -q main`)
    fixture_git(dir, `merge -q --no-ff -m "merge threshold" threshold`)
    fixture_git(dir, `checkout -q -b testset main`)
    commit!(dir, Dict{String,Any}("test/model/runtests.jl" => "@testset \"mesh.fixture_identity\" begin\n    @test true\nend\n"), "testset")
    fixture_git(dir, `checkout -q main`)
    fixture_git(dir, `merge -q --no-ff -m "merge testset" testset`)
    fixture_git(dir, `checkout -q feature`)
    fixture_git(dir, `merge -q --no-ff -m "merge main into feature" main`)
    commit!(dir, Dict{String,Any}("notes/feature.md" => "feature work, continued\n"), "more feature work")
    fixture_git(dir, `checkout -q main`)
    fixture_git(dir, `merge -q --no-ff -m "merge feature" feature`)
end

"""
A history: a feature branch forks from main; main commits `extra` together with the
tier-1 entry's threshold directly, not through a merge; the feature branch merges main
into itself. Left checked out on the feature branch.
"""
function branch_after_plain_main_change(dir, extra::AbstractDict)
    doc = new_history(dir, tier1())
    fixture_git(dir, `checkout -q -b feature`)
    commit!(dir, Dict{String,Any}("notes/feature.md" => "feature work\n"), "feature work")
    fixture_git(dir, `checkout -q main`)
    edit!(dir, doc, Dict{String,Any}("threshold" => "roundoff at every level"), extra)
    fixture_git(dir, `checkout -q feature`)
    fixture_git(dir, `merge -q --no-ff -m "merge main into feature" main`)
end

"""
A history: a feature branch forks from main and changes the tier-1 entry's threshold
together with `extra` itself; main commits unrelated work; the feature branch merges main
into itself. Left checked out on the feature branch.
"""
function branch_own_threshold_change(dir, extra::AbstractDict)
    doc = new_history(dir, tier1())
    fixture_git(dir, `checkout -q -b feature`)
    edit!(dir, doc, Dict{String,Any}("threshold" => "roundoff at every level"))
    isempty(extra) || commit!(dir, extra, "branch work")
    fixture_git(dir, `checkout -q main`)
    commit!(dir, Dict{String,Any}("notes/main.md" => "main moves on\n"), "main")
    fixture_git(dir, `checkout -q feature`)
    fixture_git(dir, `merge -q --no-ff -m "merge main into feature" main`)
end

"""
A history: `merge_history`'s branch changing the threshold together with `extra`, merged
into main and listed for `oracle`; a feature branch, forked before that merge, merges main
into itself afterward. Left checked out on the feature branch.
"""
function listed_merge_seen_from_branch(dir, extra::AbstractDict, oracle::AbstractString)
    doc = new_history(dir, tier1())
    fixture_git(dir, `checkout -q -b feature`)
    commit!(dir, Dict{String,Any}("notes/feature.md" => "feature work\n"), "feature work")
    fixture_git(dir, `checkout -q -b threshold main`)
    edit!(dir, doc, Dict{String,Any}("threshold" => "roundoff at every level"))
    isempty(extra) || commit!(dir, extra, "branch work")
    fixture_git(dir, `checkout -q main`)
    fixture_git(dir, `merge -q --no-ff -m merge threshold`)
    merge_sha = head(dir)
    fixture_git(dir, `checkout -q feature`)
    fixture_git(dir, `merge -q --no-ff -m "merge main into feature" main`)
    list!(dir, [exception(merge_sha, oracle)])
end

"A history: the tier-2 reregistration refused below, made before the amendment commit."
function before_amendment(dir)
    doc = new_history(dir, tier2(); amended = false)
    register!(dir, doc)
    edit!(dir, doc, Dict{String,Any}("threshold" => "the revised published residual"))
    register!(dir, doc)
    commit!(dir, Dict{String,Any}(Oracles.DECISION_PATH => DECISION_TEXT), "amend")
end

"The refusal `f()` raises, or `nothing` when it returns."
function refusal(f)
    try
        f()
        return nothing
    catch e
        e isa Verdicts.Refusal || rethrow()
        return e
    end
end

"Each history fixture: how it is built, how many problems it raises, and the phrase each carries."
const HISTORY_CONTROLS = (
    (case = "a tier-2 entry registered again with anchors and datasets unchanged",
     build = dir -> reregistration(dir, Dict{String,Any}()), count = 1,
     phrase = "registered again with its anchors and datasets unchanged"),
    (case = "the same registration beside a changed anchor (accepted)",
     build = dir -> reregistration(dir, Dict{String,Any}("anchors" => ["A second read work"])), count = 0, phrase = ""),
    (case = "the same registration beside a changed dataset (accepted)",
     build = dir -> reregistration(dir, Dict{String,Any}("datasets" => ["fixture_product"])), count = 0, phrase = ""),
    (case = "a changed anchor registered in a commit touching src/",
     build = dir -> reregistration(dir, Dict{String,Any}("anchors" => ["A second read work"]);
                                   extra = Dict{String,Any}("src/Model.jl" => "module Model\nf() = 1\nend\n")),
     count = 1, phrase = "registered again in a commit touching src/Model.jl"),
    (case = "a changed anchor registered in a commit touching notes/findings/",
     build = dir -> reregistration(dir, Dict{String,Any}("anchors" => ["A second read work"]);
                                   extra = Dict{String,Any}("notes/findings/fixture.md" => "a value\n")),
     count = 1, phrase = "registered again in a commit touching notes/findings/fixture.md"),
    (case = "a changed anchor whose registered commit touches src/",
     build = dir -> reregistration(dir, Dict{String,Any}("anchors" => ["A second read work"]);
                                   at_change = Dict{String,Any}("src/Model.jl" => "module Model\nf() = 2\nend\n")),
     count = 1, phrase = "registered again in a commit touching src/Model.jl"),
    (case = "an entry registered as report and then as fail_bar",
     build = dir -> kind_change(dir, "report"), count = 1, phrase = "registered as fail_bar, and registered as report"),
    (case = "an entry registered as fail_bar and again as fail_bar (accepted)",
     build = dir -> kind_change(dir, "fail_bar"), count = 0, phrase = ""),
    (case = "a merge changing a threshold and the testset named by it",
     build = dir -> merge_history(dir, Dict{String,Any}("test/model/runtests.jl" => "@testset \"mesh.fixture_identity\" begin\n    @test true\nend\n")),
     count = 1, phrase = "a merge whose branch changes the threshold together with test/model/runtests.jl"),
    (case = "a merge changing a threshold and src/",
     build = dir -> merge_history(dir, Dict{String,Any}("src/Model.jl" => "module Model\ng() = 1\nend\n")),
     count = 1, phrase = "a merge whose branch changes the threshold together with src/Model.jl"),
    (case = "the threshold change merged alone (accepted)",
     build = dir -> merge_history(dir, Dict{String,Any}()), count = 0, phrase = ""),
    (case = "a feature branch that merged main's threshold and testset merges into itself, merged into main with no threshold change of its own (accepted)",
     build = sync_history, count = 0, phrase = ""),
    (case = "a merge changing a threshold and src/, listed as an exception with permitted_by (accepted)",
     build = dir -> listed_merge(dir, Dict{String,Any}("src/Model.jl" => "module Model\ng() = 1\nend\n"), "mesh.fixture_identity"),
     count = 0, phrase = ""),
    (case = "a listed exception whose merge changes the threshold alone, which is stale",
     build = dir -> listed_merge(dir, Dict{String,Any}(), "mesh.fixture_identity"),
     count = 1, phrase = "a stale exception of " * Oracles.EXCEPTIONS_PATH),
    (case = "a branch that merged main in, where main's own plain commit changed the threshold beside src/ (accepted)",
     build = dir -> branch_after_plain_main_change(dir, Dict{String,Any}("src/Model.jl" => "module Model\ng() = 1\nend\n")),
     count = 0, phrase = ""),
    (case = "the same branch changing the threshold beside src/ itself, seen from its own tip",
     build = dir -> branch_own_threshold_change(dir, Dict{String,Any}("src/Model.jl" => "module Model\ng() = 1\nend\n")),
     count = 1, phrase = "a branch whose diff against main changes the threshold together with src/Model.jl"),
    (case = "a feature branch that merged a listed mainline merge in, whose exception is not stale from the branch (accepted)",
     build = dir -> listed_merge_seen_from_branch(dir, Dict{String,Any}("src/Model.jl" => "module Model\ng() = 1\nend\n"),
                                                  "mesh.fixture_identity"),
     count = 0, phrase = ""),
    (case = "a registration refused below, made before the amendment commit (accepted)",
     build = before_amendment, count = 0, phrase = ""),
    (case = "a tier-2 fail_bar entry registered with a bar below its uncertainty",
     build = dir -> begin
         doc = new_history(dir, merge(tier2(), Dict{String,Any}("bar_half_width" => 0.5)))
         register!(dir, doc)
     end, count = 1, phrase = "registered with a bar narrower than its observation's uncertainty"),
    (case = "a tier-2 fail_bar entry registered with no bar",
     build = dir -> begin
         entry = tier2()
         delete!(entry, "bar_half_width")
         delete!(entry, "observation_uncertainty")
         doc = new_history(dir, entry)
         register!(dir, doc)
     end, count = 1, phrase = "registered with no bar_half_width and observation_uncertainty"),
)

"""
    history_failures(check, repos)

Each history control `check` fails on the built repositories `repos`: a count of problems
other than its fixture's, or a problem without its fixture's phrase.
"""
function history_failures(check, repos)
    failures = String[]
    for (c, dir) in zip(HISTORY_CONTROLS, repos)
        found = check(dir)
        (length(found) == c.count && all(m -> occursin(c.phrase, m.reason), found)) ||
            push!(failures, c.case * " raised " * string(length(found)) * ": " * join(string.(found), "; "))
    end
    return failures
end

"The references index of the tree, each row's title keyed to its status, read by test/lint's reader."
tree_index() = last(IndexReading.read_index(INDEX))

"The count of `found` by reason, with each anchor title and entry number dropped from the reason."
function by_clause(found)
    counts = Dict{String,Int}()
    for m in found
        clause = replace(m.reason, r"\"[^\"]*\"" => "<>")
        counts[clause] = get(counts, clause, 0) + 1
    end
    return sort!(collect(counts); by = last, rev = true)
end

@testset "oracles.registry_wellformed: the loader" begin
    mktempdir() do dir
        @testset "the clean fixture loads and every entry, protocol and dependency resolves" begin
            path = put(joinpath(dir, "clean.toml"), clean_doc())
            @test isempty(Oracles.problems(path, FIXTURE_INDEX))
            registry = Oracles.load(path)
            @test length(registry.entries) == 6
            rotation = Oracles.entry(registry, "sweep.fixture_rotation")
            @test Oracles.protocol(registry, rotation).normalisation == "column mass"
            @test Oracles.protocol(registry, Oracles.entry(registry, "mesh.fixture_identity")) === nothing
            @test Oracles.entry(registry, "earth.fixture_mean").bar_half_width == 2.0
            @test Oracles.entry(registry, "mesh.fixture_identity").instances === nothing
            @test_throws Verdicts.Refusal Oracles.entry(registry, "mesh.absent")
            @test isempty(Oracles.dependencies(registry, rotation))

            @test Oracles.entry(registry, "earth.fixture_mean").form === nothing
            @test Oracles.entry(registry, "earth.fixture_mean").pattern_entry === nothing
            @test Oracles.entry(registry, "earth.fixture_pattern").form == "pattern"
            @test Oracles.entry(registry, "earth.fixture_pattern").pattern_entry === nothing
            @test Oracles.entry(registry, "earth.fixture_scalar").form == "scalar"
            @test Oracles.entry(registry, "earth.fixture_scalar").pattern_entry == "earth.fixture_pattern"
        end

        @testset "positive control: $(c.case) is refused" for c in LOADER_CONTROLS
            doc = clean_doc()
            c.change(doc)
            path = put(joinpath(dir, "dirty.toml"), doc)
            found = Oracles.problems(path, FIXTURE_INDEX)
            @test length(found) == length(c.phrases)
            @test all(p -> any(m -> occursin(p, m.reason), found), c.phrases)
            length(found) == length(c.phrases) || @info "$(c.case) raised" found
            any(p -> occursin("references index", p), c.phrases) || @test_throws Verdicts.Refusal Oracles.load(path)
        end

        @testset "a malformed entry among good ones refuses the whole registry rather than being skipped" begin
            doc = clean_doc()
            set_field!(doc, "mesh.fixture_identity", "threshold", nothing)
            path = put(joinpath(dir, "one_bad.toml"), doc)
            err = try
                Oracles.load(path)
                nothing
            catch e
                e
            end
            @test err isa Verdicts.Refusal
            @test err isa Verdicts.Refusal && occursin("mesh.fixture_identity: carries no threshold", err.reason)
        end

        @testset "a file that does not parse as TOML is refused" begin
            path = put(joinpath(dir, "not_toml.toml"), "[[oracle]]\nid = \n")
            @test length(Oracles.problems(path, FIXTURE_INDEX)) == 1
            @test_throws Verdicts.Refusal Oracles.load(path)
        end
    end
end

@testset "oracles.registry_wellformed: the tree's verdict is recorded" begin
    index = tree_index()
    found = Oracles.problems(TREE, index)
    verdict = isempty(found) ? Verdicts.PASS() : Verdicts.FAIL()
    println("oracles.registry_wellformed, loader and anchor clauses, on the tree: ", nameof(typeof(verdict)), ", ",
            length(found), " problems")
    for (clause, n) in by_clause(found)
        println("    ", lpad(n, 4), "  ", clause)
    end
    isempty(found) || @info "problems on the tree" found
    @test isempty(found)

    @testset "positive control: a scratch copy of the tree missing one entry's source_kind is not empty" begin
        mktempdir() do dir
            doc = TOML.parsefile(TREE)
            delete!(first(doc["oracle"]), "source_kind")
            path = put(joinpath(dir, "dirty_tree.toml"), doc)
            dirty = Oracles.problems(path, index)
            @test any(m -> occursin("carries no source_kind", m.reason), dirty)
        end
    end
end

@testset "oracles.registration_rule: admits" begin
    mktempdir() do dir
        registry = Oracles.load(put(joinpath(dir, "clean.toml"), clean_doc()))
        barred = Oracles.entry(registry, "earth.fixture_mean")
        unbarred = Oracles.entry(registry, "sweep.fixture_rotation")

        @testset "positive control: an unregistered $(e.verdict_kind) entry's value is refused on a model result and admitted on a Fixture" for e in (barred, unbarred)
            @test !Oracles.registered(e)
            @test !Oracles.admits(e, 3.5, Oracles.StatisticValue())
            @test Oracles.admits(e, Oracles.Fixture(3.5), Oracles.StatisticValue())
            @test isempty(admission_failures(Oracles.admits, e, false))
        end

        @testset "the controls fail for a predicate that admits everything and for one that admits only fixtures" begin
            @test "admitted an unregistered entry's value on a model result" in
                  admission_failures((e, x, use) -> true, barred, false)
            @test "refused Evaluates on a model result" in
                  admission_failures((e, x, use) -> x isa Oracles.Fixture, barred, false)
        end
    end
end

@testset "oracles.registration_rule: registered" begin
    mktempdir() do dir
        repo = joinpath(dir, "repo")
        doc = new_history(repo, tier2())
        register!(repo, doc)
        path = joinpath(repo, Oracles.REGISTRY_PATH)
        registered_entry = only(Oracles.load(path).entries)

        @testset "an entry equal to its registered_at commit is registered, and admits every use on either" begin
            @test Oracles.registered(registered_entry)
            @test isempty(admission_failures(Oracles.admits, registered_entry, true))
        end

        @testset "positive control: an entry whose $(key) differs from its registered_at commit is unregistered" for
                (key, value) in (("threshold", "a threshold chosen later"), ("statistic", "a statistic chosen later"),
                                 ("verdict_kind", "report"), ("holdout", true))
            edited = deepcopy(doc)
            only(edited["oracle"])[key] = value
            put(path, edited)
            e = only(Oracles.load(path).entries)
            @test !Oracles.registered(e)
            @test !Oracles.admits(e, 3.5, Oracles.StatisticValue())
            @test Oracles.admits(e, Oracles.Fixture(3.5), Oracles.StatisticValue())
            put(path, doc)
        end

        @testset "the control fails for a registered that reads registered_at without git" begin
            edited = deepcopy(doc)
            only(edited["oracle"])["threshold"] = "a threshold chosen later"
            put(path, edited)
            e = only(Oracles.load(path).entries)
            @test !Oracles.registered(e)
            @test (e -> !isempty(e.registered_at))(e)
            put(path, doc)
        end

        @testset "a registered_at naming no commit of the repository is refused" begin
            edited = deepcopy(doc)
            only(edited["oracle"])["registered_at"] = repeat("0", 40)
            put(path, edited)
            @test_throws Verdicts.Refusal Oracles.registered(only(Oracles.load(path).entries))
            put(path, doc)
        end

        @testset "positive control: a registered entry on an anchor whose index row is held is refused" begin
            @test isempty(Oracles.problems(path, FIXTURE_INDEX))
            found = Oracles.problems(path, merge(FIXTURE_INDEX, Dict("A read work" => "held")))
            @test length(found) == 1
            @test all(m -> occursin("registered on anchor \"A read work\", whose references index row is held", m.reason), found)
        end
    end
end

@testset "oracles.registration_rule: the history check" begin
    mktempdir() do dir
        repos = String[]
        for (k, c) in enumerate(HISTORY_CONTROLS)
            repo = joinpath(dir, "history_" * string(k))
            c.build(repo)
            push!(repos, repo)
        end

        @testset "positive control: $(c.case)" for (c, repo) in zip(HISTORY_CONTROLS, repos)
            found = Oracles.history_problems(repo)
            @test length(found) == c.count
            @test all(m -> occursin(c.phrase, m.reason), found)
            length(found) == c.count || @info "$(c.case) raised" found
        end

        @testset "the controls fail for a check that refuses nothing and for one that refuses everything" begin
            nothing_refused = history_failures(repo -> Oracles.Malformed[], repos)
            everything_refused = history_failures(repo -> [Oracles.Malformed("x", "refused")], repos)
            @test length(nothing_refused) == count(c -> c.count > 0, HISTORY_CONTROLS)
            @test length(everything_refused) == length(HISTORY_CONTROLS)
            @test isempty(history_failures(Oracles.history_problems, repos))
        end

        @testset "positive control: a violating merge listed for another oracle is refused, and its exception is stale" begin
            repo = joinpath(dir, "other_oracle")
            listed_merge(repo, Dict{String,Any}("src/Model.jl" => "module Model\ng() = 1\nend\n"), "mesh.another_identity")
            found = Oracles.history_problems(repo)
            @test length(found) == 2
            @test count(m -> occursin("a merge whose branch changes the threshold together with src/Model.jl", m.reason), found) == 1
            @test count(m -> m.site == "mesh.another_identity at " * Oracles.short(head(repo)) &&
                             occursin("a stale exception", m.reason), found) == 1
        end

        @testset "a shallow clone is refused" begin
            clone = joinpath(dir, "shallow")
            fixture_git(dir, `clone -q --depth 1 file://$(repos[1]) $(clone)`)
            @test_throws Verdicts.Refusal Oracles.history_problems(clone)
        end

        @testset "a history with no amendment commit is refused" begin
            repo = joinpath(dir, "unamended")
            new_history(repo, tier1(); amended = false)
            @test_throws Verdicts.Refusal Oracles.history_problems(repo)
        end

        @testset "a repository with no declared mainline ref is refused by name" begin
            repo = joinpath(dir, "no_mainline")
            new_history(repo, tier1(); branch = "trunk")
            r = refusal(() -> Oracles.history_problems(repo))
            @test r isa Verdicts.Refusal && r.quantity == "registration history" &&
                  occursin("refs/heads/main", r.reason) && occursin("refs/remotes/origin/main", r.reason)
        end
    end
end

"Each exceptions list fixture: the change to a list of one filled entry, and a phrase of the refusal it raises."
const EXCEPTION_CONTROLS = (
    (case = "an entry with an empty permitted_by", change = d -> (only(d["exception"])["permitted_by"] = ""),
     phrase = "permitted_by is empty"),
    (case = "an entry with no permitted_by", change = d -> delete!(only(d["exception"]), "permitted_by"),
     phrase = "carries no permitted_by"),
    (case = "an entry with no reason", change = d -> delete!(only(d["exception"]), "reason"),
     phrase = "carries no reason"),
    (case = "an entry carrying an unknown key", change = d -> (only(d["exception"])["approved_by"] = "an agent"),
     phrase = "carries approved_by, which is not an exception field"),
    (case = "a merge that is not a full commit id", change = d -> (only(d["exception"])["merge"] = "0d09de52"),
     phrase = "is not a forty-digit commit id"),
    (case = "a date that is not a TOML date", change = d -> (only(d["exception"])["date"] = "2026-09-14"),
     phrase = "date is not a TOML date"),
    (case = "two entries naming one merge and oracle", change = d -> push!(d["exception"], copy(only(d["exception"]))),
     phrase = "as an earlier entry does"),
    (case = "a key other than exception", change = d -> (d["exceptions"] = d["exception"]; delete!(d, "exception")),
     phrase = "carries exceptions, which is not exception"),
    (case = "a missing file", change = d -> nothing, phrase = "does not exist"),
)

@testset "oracles.registration_rule: the exceptions list is refused before git is read" begin
    mktempdir() do dir
        entry = () -> Dict{String,Any}("exception" => [exception(repeat("a", 40), "mesh.fixture_identity")])
        path = joinpath(dir, Oracles.EXCEPTIONS_PATH)

        @testset "the accepted twin: a filled entry is read, and the check goes on to git outside a repository" begin
            put(path, entry())
            listed = Oracles.read_exceptions(path)
            @test length(listed) == 1 && only(listed).permitted_by == "the fixture user's permission"
            r = refusal(() -> Oracles.history_problems(dir))
            @test r isa Verdicts.Refusal && r.quantity == "git"
        end

        @testset "positive control: $(c.case) is refused" for c in EXCEPTION_CONTROLS
            doc = entry()
            c.change(doc)
            c.case == "a missing file" ? rm(path) : put(path, doc)
            r = refusal(() -> Oracles.history_problems(dir))
            @test r isa Verdicts.Refusal && r.quantity == "registration exceptions" && occursin(c.phrase, r.reason)
            r isa Verdicts.Refusal && r.quantity == "registration exceptions" || @info "$(c.case) raised" r
        end
    end
end

@testset "oracles.registration_rule: Fixture is constructed only under test/" begin
    mktempdir() do dir
        src = joinpath(dir, "src")
        put(joinpath(src, "Accepted.jl"), """
            module Accepted
            "A reader of `Fixture(x)` values."
            reads(x) = x isa Oracles.Fixture ? x.value : x
            end
            """)
        @testset "the accepted twin: a src/ file naming Fixture without constructing one" begin
            @test isempty(Oracles.fixture_constructions(src))
        end
        @testset "positive control: a src/ file constructing Fixture ($(form)) is refused" for form in
                ("Oracles.Fixture(1.0)", "Fixture{Float64}(1.0)", "Fixture.(values)")
            put(joinpath(src, "Dirty.jl"), "module Dirty\nmade = " * form * "\nend\n")
            found = Oracles.fixture_constructions(src)
            @test length(found) == 1
            @test all(m -> m.site == "Dirty.jl:2" && occursin("constructs Fixture", m.reason), found)
            rm(joinpath(src, "Dirty.jl"))
        end
    end
end

@testset "oracles.registration_rule: the tree's verdicts are recorded" begin
    history = Oracles.history_problems(PROJECT)
    listed = Oracles.read_exceptions(joinpath(PROJECT, Oracles.EXCEPTIONS_PATH))
    constructions = Oracles.fixture_constructions(joinpath(PROJECT, "src"))
    println("oracles.registration_rule on the tree: history from ", Oracles.short(Oracles.amendment_commit(PROJECT)),
            " to HEAD, ", length(history), " problems, ", length(listed), " listed exceptions (",
            join((Oracles.short(x.merge) * " " * x.oracle for x in listed), ", "), "); Fixture constructions under src/, ",
            length(constructions))
    isempty(history) || @info "history problems on the tree" history
    isempty(constructions) || @info "Fixture constructions under src/" constructions
    @test [(x.merge, x.oracle) for x in listed] == [("0d09de52c917768be851e8205fcad2c5e8e30088", "system.epoch_event")]
    @test isempty(history)
    @test isempty(constructions)
end

end # module RegistryRule
