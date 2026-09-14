# The static pass of decision 0006: JET's report_call over every method of the package and
# report_opt over the operator calls test/fields/inference.jl walks, held to the accepted
# findings of test/fields/static_pass.toml. docs/plans/fiddlybits-52v.3-fields.md, section
# "Inference, and what it costs", states the pass and the rule for that list;
# docs/imports/jet-jl.md is JET's import record; tools/nightly/run.jl runs it.
#
#   julia --project=<environment> test/fields/static_pass.jl <subject> <accepted> <result>
#
# <subject> is `tree` or `fixture`, <accepted> an accepted-findings TOML, <result> the TOML
# file the run writes. The environment is the one `build_environment` writes. This file is
# not included by test/fields/runtests.jl.

module StaticPass

import TOML

"The accepted-findings list of the tree."
const ACCEPTED = joinpath(@__DIR__, "static_pass.toml")

"The package the pass loads JET as."
const JET_ID = Base.PkgId(Base.UUID("c3a54625-cd67-489e-a8e7-0a5a0ff4e31b"), "JET")

"The analyses a finding comes from."
const ANALYSES = ("report_call", "report_opt")

"The fields naming a finding, and those an accepted entry carries besides."
const FINDING_FIELDS = ("analysis", "kind", "file", "method", "message")
const ENTRY_FIELDS = (FINDING_FIELDS..., "reason", "row")

"The shape of a row id in the tracker."
const ROW_ID = r"^fiddlybits-[0-9a-z]+(\.[0-9]+)*$"

const Finding = NamedTuple{(:analysis, :kind, :file, :method, :message), NTuple{5,String}}

finding(analysis, kind, file, method, message) =
    Finding((String(analysis), String(kind), String(file), String(method), String(message)))

"One line naming finding `f`."
describe(f::Finding) = string(f.analysis, " ", f.kind, " in ", f.method, " (", f.file, "): ",
                              f.message)

"""
    accepted_entries(parsed, source)

The `(finding, reason, row)` of every `[[accepted]]` entry of `parsed`, a TOML document
read from `source`. Refuses a document holding any key but `accepted`, an entry lacking
any of `ENTRY_FIELDS` as a non-empty string or carrying another key, an `analysis` outside
`ANALYSES`, a `row` that is not a tracker id, and two entries naming one finding.
"""
function accepted_entries(parsed::AbstractDict, source::AbstractString)
    other = sort([k for k in keys(parsed) if k != "accepted"])
    isempty(other) ||
        error("$(source) holds $(join(other, ", ")); it holds only [[accepted]] entries")
    entries = get(parsed, "accepted", Any[])
    entries isa AbstractVector ||
        error("accepted in $(source) is not a list of [[accepted]] entries")
    out = Tuple{Finding,String,String}[]
    seen = Set{Finding}()
    for (i, e) in enumerate(entries)
        e isa AbstractDict || error("entry $(i) of $(source) is not a table")
        lacking = [k for k in ENTRY_FIELDS if !(get(e, k, nothing) isa String && !isempty(e[k]))]
        isempty(lacking) ||
            error("entry $(i) of $(source) has no $(join(lacking, ", ")); an accepted " *
                  "finding names the finding, the reason it stands and the row that removes it")
        unknown = sort([k for k in keys(e) if !(k in ENTRY_FIELDS)])
        isempty(unknown) ||
            error("entry $(i) of $(source) carries $(join(unknown, ", ")), which is not a " *
                  "field of an accepted finding")
        e["analysis"] in ANALYSES ||
            error("entry $(i) of $(source) names analysis \"$(e["analysis"])\", which is " *
                  "none of $(join(ANALYSES, ", "))")
        occursin(ROW_ID, e["row"]) ||
            error("entry $(i) of $(source) names row \"$(e["row"])\", which is not a tracker id")
        f = finding(e["analysis"], e["kind"], e["file"], e["method"], e["message"])
        f in seen && error("two entries of $(source) name one finding: $(describe(f))")
        push!(seen, f)
        push!(out, (f, e["reason"], e["row"]))
    end
    return out
end

"""
    read_accepted(path)

`accepted_entries` of the TOML file at `path`. Refuses when there is no file.
"""
function read_accepted(path::AbstractString)
    isfile(path) ||
        error("the static pass reads its accepted findings from $(path), which does not " *
              "exist; a file with no [[accepted]] entry accepts none")
    return accepted_entries(TOML.parsefile(path), path)
end

"""
    verdict(found, accepted)

`(new, stale)`: the distinct findings of `found` that no entry of `accepted` names, and
the findings entries of `accepted` name that `found` does not hold, each sorted by
`describe`.
"""
function verdict(found, accepted)
    present = Set{Finding}(found)
    listed = Set{Finding}(first.(accepted))
    new = sort([f for f in present if !(f in listed)]; by = describe)
    stale = sort([f for f in listed if !(f in present)]; by = describe)
    return new, stale
end

"""
    source_file(m, root)

The file method `m` is defined in, relative to `root` when it lies under `root`.
"""
function source_file(m::Method, root::AbstractString)
    path = string(m.file)
    isabspath(path) || return path
    path = normpath(path)
    return startswith(path, joinpath(normpath(root), "")) ? relpath(path, root) : path
end

"The module and name of method `m`, with the counters of generated names removed."
method_name(m::Method) = replace(string(m.module, ".", m.name), r"#\d+" => "#")

"Where the innermost frame of JET `report` lies, as `file:line`."
location(report) = string(report.vst[end].file, ":", report.vst[end].line)

"""
    report_finding(jet, analysis, report, root)

The finding JET `report` is, from `analysis`: the report's type; the method of its
innermost frame, by `method_name`, and that method's `source_file`; and the message JET
prints for it, with the counters of generated names removed and an ellipsis written as
three full stops. The line is not part of a finding.
"""
function report_finding(jet::Module, analysis::AbstractString, report, root::AbstractString)
    def = report.vst[end].linfo.def
    file, method = def isa Method ? (source_file(def, root), method_name(def)) :
        ("toplevel", string(def))
    message = replace(sprint(jet.print_report_message, report), r"#\d+" => "#",
                      Char(0x2026) => "...")
    return finding(analysis, string(nameof(typeof(report))), file, method, message)
end

"Whether module `m` is `root` or lies inside it."
within(m::Module, root::Module) =
    m === root || (parentmodule(m) !== m && within(parentmodule(m), root))

"""
    component_methods(root)

Every method of the method table defined in module `root` or a module inside it, sorted by
file, line and name.
"""
function component_methods(root::Module)
    found = Method[]
    Base.visit(Core.methodtable) do m
        m isa Method && within(m.module, root) && push!(found, m)
    end
    return sort(found; by = m -> (string(m.file), m.line, string(m.name)))
end

"""
    device_kernel(m)

Whether method `m` belongs to the device function `KernelAbstractions.@kernel` generates:
named `gpu_<name>`, in a module that also binds the kernel `<name>` and its constructor
`_<name>`.
"""
function device_kernel(m::Method)
    name = string(m.name)
    startswith(name, "gpu_") || return false
    kernel = name[5:end]
    return isdefined(m.module, Symbol(kernel)) && isdefined(m.module, Symbol("_", kernel))
end

"""
    call_findings(jet, mod, root)

`(found, analysed, device)`. `found` holds a `finding => location` for every report of
`report_call` on each method of `component_methods(mod)` that is not a `device_kernel`,
each analysed at its own signature with `ignore_throws` and `ignore_missing_comparison`
set, the settings `report_package` analyses a package with, and a report kept when its
innermost frame lies in `mod`. A method its own signature does not select is a finding of
kind `UnmatchedSignature`. `analysed` counts the methods analysed and `device` the device
kernels left out.
"""
function call_findings(jet::Module, mod::Module, root::AbstractString)
    found = Pair{Finding,String}[]
    analysed = 0
    device = 0
    for m in component_methods(mod)
        if device_kernel(m)
            device += 1
            continue
        end
        analysed += 1
        match = Base._which(m.sig; raise = false)
        if match === nothing || match.method !== m
            push!(found, finding("report_call", "UnmatchedSignature", source_file(m, root),
                                 method_name(m),
                                 "no single method is selected by this method's own signature") =>
                             string(m.file, ":", m.line))
            continue
        end
        mi = Core.Compiler.specialize_method(match.method, match.spec_types, match.sparams)
        result = jet.report_call(mi; ignore_throws = true, ignore_missing_comparison = true,
                                 target_modules = (mod,))
        for r in jet.get_reports(result)
            push!(found, report_finding(jet, "report_call", r, root) => location(r))
        end
    end
    return found, analysed, device
end

"""
    opt_findings(jet, calls, mod, root)

`(found, entries)`. `found` holds a `finding => location` for every report of `report_opt`
on each zero-argument call of `calls`, a collection of `label => call`, a report kept when
its innermost frame lies in `mod`; and a finding of kind `NonConcreteReturn`, named by the
call's label, for every call whose inferred return type, widened, is not concrete.
`entries` counts the calls analysed.
"""
function opt_findings(jet::Module, calls, mod::Module, root::AbstractString)
    found = Pair{Finding,String}[]
    for (label, call) in calls
        result = jet.report_opt(call, (); target_modules = (mod,))
        for r in jet.get_reports(result)
            push!(found, report_finding(jet, "report_opt", r, root) => location(r))
        end
        returned = Core.Compiler.widenconst(jet.get_result(result))
        if !isconcretetype(returned)
            m = only(methods(call))
            push!(found, finding("report_opt", "NonConcreteReturn", source_file(m, root), label,
                                 "returns $(returned)") => string(m.file, ":", m.line))
        end
    end
    return found, length(calls)
end

"""
    operator_calls(root)

`label => call` for every call of the operator tables `test/fields/inference.jl` walks, read
from its `SHAPES` after including that file, which runs its testset, into a module of its
own.
"""
function operator_calls(root::AbstractString)
    walk = Module(:OperatorCalls)
    Base.include(walk, joinpath(root, "test", "fields", "inference.jl"))
    shapes = Base.invokelatest(getglobal, walk, :SHAPES)
    calls = Pair{String,Any}[]
    for shape in shapes, op in (:coarsen, :refine, :time_reduce)
        table = getfield(shape, op)
        for name in keys(table)
            push!(calls, "$(op) $(name), $(shape.name)" => getfield(table, name))
        end
    end
    return calls
end

"""
The module the pass's controls run on, where every finding is known: a call with no
matching method, the same in a hand-written function named like a device kernel, one
kernel `@kernel` generates, a call that dispatches at runtime and a call whose return is
not concrete. Held as an expression and evaluated by `fixture`, so a process that includes
this file loads KernelAbstractions only when it asks for the fixture.
"""
const FIXTURE = quote
    module Fixture

    using KernelAbstractions: @kernel, @index

    resolved(x::Int) = x
    unresolved(s::String) = resolved(s)
    gpu_lookalike(s::String) = resolved(s)

    @kernel function fixture_fill!(a)
        i = @index(Global)
        a[i] = zero(eltype(a))
    end

    const BOX = Ref{Any}(1.0)
    dispatched(r::Ref{Any}) = sin(r[])::Float64

    const FLAG = Ref(true)
    unsettled() = FLAG[] ? 1 : 1.0

    const CALLS = ["dispatched" => () -> dispatched(BOX), "unsettled" => () -> unsettled()]

    end
end

"The module `FIXTURE` defines, evaluated into this module the first time it is asked for."
function fixture()
    Base.invokelatest(isdefined, @__MODULE__, :Fixture) ||
        Core.eval(@__MODULE__, Expr(:toplevel, FIXTURE.args...))
    return Base.invokelatest(getglobal, @__MODULE__, :Fixture)
end

"""
    analyse(jet, subject, root)

`(found, counts)` for `subject`: `call_findings` and `opt_findings` over the package
`root`'s `Project.toml` names and the operator calls of `operator_calls` for `"tree"`, and
over `fixture()` and its `CALLS` for `"fixture"`. `counts` holds the methods analysed, the
device kernels left out and the calls analysed.
"""
function analyse(jet::Module, subject::AbstractString, root::AbstractString)
    if subject == "tree"
        project = TOML.parsefile(joinpath(root, "Project.toml"))
        mod = Base.require(Base.PkgId(Base.UUID(project["uuid"]), project["name"]))
        calls = operator_calls(root)
    elseif subject == "fixture"
        mod = fixture()
        calls = Base.invokelatest(getglobal, mod, :CALLS)
    else
        error("the static pass runs on \"tree\" or \"fixture\", not \"$(subject)\"")
    end
    call, analysed, device = Base.invokelatest(call_findings, jet, mod, root)
    opt, entries = Base.invokelatest(opt_findings, jet, calls, mod, root)
    counts = Dict("methods_analysed" => analysed, "device_kernels_left_out" => device,
                  "operator_calls" => entries)
    return vcat(call, opt), counts
end

"""
    accepted_text(entries)

The TOML text of an accepted-findings list holding `entries`, each a `Dict` of its fields.
"""
accepted_text(entries) = sprint(io -> TOML.print(io, Dict("accepted" => entries); sorted = true))

"The fields of finding `f` as the `Dict` of an accepted entry, with `extra` added."
entry(f::Finding; extra...) =
    merge(Dict(k => getfield(f, Symbol(k)) for k in FINDING_FIELDS),
          Dict(string(k) => v for (k, v) in extra))

"""
    controls(jet, root)

Run the pass on `fixture()`, where the answer is known, and refuse unless each control comes
out as stated: with no accepted entry, the findings are exactly the four the fixture holds
and its one generated device kernel is left out; with those four accepted with a reason
and a row, nothing is new or stale; with a fifth accepted finding the fixture does not
produce, that one is stale and nothing is new; and an entry with no reason and no row is
refused. Returns the number of controls run.
"""
function controls(jet::Module, root::AbstractString)
    found, counts = analyse(jet, "fixture", root)
    findings = first.(found)
    prefix = string(fixture())
    expected = Set([("report_call", "MethodErrorReport", prefix * ".unresolved"),
                    ("report_call", "MethodErrorReport", prefix * ".gpu_lookalike"),
                    ("report_opt", "RuntimeDispatchReport", prefix * ".dispatched"),
                    ("report_opt", "NonConcreteReturn", "unsettled")])
    new, stale = verdict(findings, Tuple{Finding,String,String}[])
    got = Set((f.analysis, f.kind, f.method) for f in new)
    (got == expected && length(new) == length(expected) && isempty(stale)) ||
        error("the static pass's control \"no accepted entry\" found " *
              "$(join(describe.(new), "; ")) where it must find exactly $(expected); " *
              "the pass cannot be trusted to report what it analyses")
    counts["device_kernels_left_out"] == 1 ||
        error("the static pass's control \"one generated device kernel\" left out " *
              "$(counts["device_kernels_left_out"]) methods where it must leave out one")

    reason = (reason = "a finding the fixture holds by construction", row = "fiddlybits-52v.3.8")
    listed = [entry(f; reason...) for f in new]
    all_accepted = accepted_entries(TOML.parse(accepted_text(listed)), "the fixture's list")
    new, stale = verdict(findings, all_accepted)
    (isempty(new) && isempty(stale)) ||
        error("the static pass's control \"every finding accepted\" left " *
              "$(length(new)) new and $(length(stale)) stale")

    removed = merge(first(listed), Dict("method" => prefix * ".removed"))
    with_removed = accepted_entries(TOML.parse(accepted_text(vcat(listed, [removed]))),
                                    "the fixture's list")
    new, stale = verdict(findings, with_removed)
    (isempty(new) && length(stale) == 1 && stale[1].method == prefix * ".removed") ||
        error("the static pass's control \"an accepted finding no longer produced\" left " *
              "$(length(new)) new and stale $(describe.(stale))")

    bare = [delete!(delete!(copy(first(listed)), "reason"), "row")]
    refused = try
        accepted_entries(TOML.parse(accepted_text(bare)), "the fixture's list")
        nothing
    catch e
        e
    end
    (refused isa ErrorException && occursin("reason", refused.msg) &&
     occursin("row", refused.msg)) ||
        error("the static pass's control \"an entry with no reason and no row\" was not " *
              "refused naming both")
    return 4
end

"""
    run_subject(jet, subject, accepted, result, root)

Run `controls`, then the pass on `subject` against the accepted entries `accepted`; print
every new finding with where it lies and every stale one; write the result to the TOML
file `result`; and return the status, zero when nothing is new. The result holds the
subject, the Julia and JET versions, the status, the counts, and the new and stale
findings.
"""
function run_subject(jet::Module, subject::AbstractString, accepted, result::AbstractString,
                     root::AbstractString)
    jet.JET_AVAILABLE ||
        error("JET $(pkgversion(jet)) loaded without its analyses on Julia $(VERSION)")
    jet.JET_DEV_MODE &&
        error("JET $(pkgversion(jet)) loaded in development mode, which a LocalPreferences.toml " *
              "on the load path sets; the pass runs on JET as released")
    ran = controls(jet, root)
    println("static pass: the ", ran, " controls on the fixture came out as stated")
    found, counts = analyse(jet, subject, root)
    new, stale = verdict(first.(found), accepted)
    where_found = Dict{Finding,Vector{String}}()
    for (f, at) in found
        push!(get!(where_found, f, String[]), at)
    end
    for f in new
        println("static pass: NEW   ", describe(f), " at ", join(unique(where_found[f]), ", "))
    end
    for f in stale
        println("static pass: STALE ", describe(f))
    end
    status = isempty(new) ? 0 : 1
    println("static pass: ", subject, " on julia ", VERSION, " with JET ", pkgversion(jet), ": ",
            length(where_found), " findings, ", length(new), " new, ", length(stale), " stale, ",
            counts["methods_analysed"], " methods and ", counts["operator_calls"],
            " operator calls analysed, ", counts["device_kernels_left_out"],
            " device kernels left out")
    record = merge(Dict{String,Any}("subject" => subject, "julia_version" => string(VERSION),
                                    "jet_version" => string(pkgversion(jet)),
                                    "status" => status, "controls" => ran,
                                    "findings" => length(where_found),
                                    "accepted" => length(accepted),
                                    "new" => describe.(new), "stale" => describe.(stale)),
                   counts)
    open(io -> TOML.print(io, record; sorted = true), result, "w")
    return status
end

"""
    main(args)

`args` is `subject accepted result`. Reads the accepted list, which refuses before JET
loads, then loads JET and returns `run_subject`'s status.
"""
function main(args::Vector{String})
    length(args) == 3 ||
        error("test/fields/static_pass.jl takes a subject, an accepted-findings file and a " *
              "result file")
    subject, accepted_path, result = args
    accepted = read_accepted(accepted_path)
    jet = Base.require(JET_ID)
    root = normpath(joinpath(@__DIR__, "..", ".."))
    return Base.invokelatest(run_subject, jet, subject, accepted, result, root)
end

"""
    manifest_versions(path)

Package name to version for every entry of the manifest at `path` that records a version.
"""
manifest_versions(path::AbstractString) =
    Dict(name => e[1]["version"] for (name, e) in TOML.parsefile(path)["deps"]
         if haskey(e[1], "version"))

"""
    build_environment(pkg, root, dir)

Write into `dir` the environment the pass runs in and resolve it with `pkg`, the loaded
`Pkg`: the `[deps]` of `root`'s `Project.toml`, every name its `test` target lists from
`[extras]`, and the package itself from `root` through `[sources]`, with their `[compat]`,
over a copy of `root`'s `Manifest.toml`. Refuses when the `test` target does not list JET,
and when resolving moved the version of a package that manifest records.
"""
function build_environment(pkg::Module, root::AbstractString, dir::AbstractString)
    project = TOML.parsefile(joinpath(root, "Project.toml"))
    target = get(get(project, "targets", Dict{String,Any}()), "test", String[])
    JET_ID.name in target ||
        error("the static pass loads JET through the test target of $(root)/Project.toml, " *
              "which does not list it")
    deps = Dict{String,Any}(project["deps"])
    for name in target
        deps[name] = project["extras"][name]
    end
    deps[project["name"]] = project["uuid"]
    compat = Dict{String,Any}(k => v for (k, v) in project["compat"]
                              if k == "julia" || haskey(deps, k))
    mkpath(dir)
    open(joinpath(dir, "Project.toml"), "w") do io
        TOML.print(io, Dict("deps" => deps, "compat" => compat,
                            "sources" => Dict(project["name"] => Dict("path" => root)));
                   sorted = true)
    end
    cp(joinpath(root, "Manifest.toml"), joinpath(dir, "Manifest.toml"); force = true)
    pkg.activate(dir)
    pkg.resolve()
    pinned = manifest_versions(joinpath(root, "Manifest.toml"))
    resolved = manifest_versions(joinpath(dir, "Manifest.toml"))
    moved = sort([n for (n, v) in pinned if haskey(resolved, n) && resolved[n] != v])
    isempty(moved) ||
        error("resolving the static pass's environment moved $(join(moved, ", ")) from the " *
              "versions $(root)/Manifest.toml records")
    return dir
end

"The file of the pass under `root`."
pass_file(root::AbstractString) = joinpath(root, "test", "fields", "static_pass.jl")

"""
    environment_command(root, dir)

The `julia` that runs `build_environment` for `root` into `dir`.
"""
environment_command(root::AbstractString, dir::AbstractString) =
    `julia --startup-file=no -e $("using Pkg; include(raw\"" * pass_file(root) * "\"); StaticPass.build_environment(Pkg, raw\"" * root * "\", raw\"" * dir * "\")")`

"""
    pass_command(root, env, subject, accepted, result)

The `julia` on the environment `env` that runs the pass of `root` on `subject` against the
accepted-findings file `accepted`, writing `result`.
"""
pass_command(root::AbstractString, env::AbstractString, subject::AbstractString,
             accepted::AbstractString, result::AbstractString) =
    `julia --startup-file=no --project=$(env) $(pass_file(root)) $(subject) $(accepted) $(result)`

"""
    run_pass(root, logdir; wrap, subject, accepted)

Build the environment into a temporary directory and run the pass of `root` on `subject`
against `accepted`, each `julia` passed through `wrap` first, with the output of both in
`logdir` as `static_pass.log`. Returns the result the pass wrote with `log` added, its
`status` one when either process failed; or, when the pass wrote none, a result with
`status` one, the subject, the log and an `error`.
"""
function run_pass(root::AbstractString, logdir::AbstractString; wrap,
                  subject::AbstractString = "tree", accepted::AbstractString = ACCEPTED)
    env = mktempdir()
    result = joinpath(env, "result.toml")
    log = joinpath(logdir, "static_pass.log")
    ok = open(log, "w") do io
        success(pipeline(wrap(environment_command(root, env)); stdout = io, stderr = io)) &&
            success(pipeline(wrap(pass_command(root, env, subject, accepted, result));
                             stdout = io, stderr = io))
    end
    isfile(result) ||
        return Dict{String,Any}("status" => 1, "subject" => subject, "log" => log,
                                "error" => "the static pass wrote no result")
    out = TOML.parsefile(result)
    out["log"] = log
    ok || (out["status"] = 1)
    return out
end

end # module StaticPass

(abspath(PROGRAM_FILE) == @__FILE__) && exit(StaticPass.main(ARGS))
