#!/usr/bin/env julia
# The suites of `test/suites.jl`, each in its own process, up to a stated number at
# once. Decision 0043 says what the gate runs and where;
# notes/findings/2026-09-12-a-pre-push-gate-longer-than-the-idle-timeout.md says why
# its wall time is a correctness question and not a convenience one.
#
#   julia --project tools/gate/run.jl <workers>
#
# `test/runtests.jl` runs the same suites in one process in order, and is what
# `Pkg.test()` calls. Both read `suites` from `test/suites.jl`, so a suite cannot
# exist for one door and not the other.
#
# When the working tree changes a Julia file that elides a bounds check against its
# merge base with `main`, every suite also runs a second time under `BOUNDS_FLAGS`, in
# the same pool (decision 0055).

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
include(joinpath(ROOT, "test", "suites.jl"))
include(joinpath(ROOT, "tools", "gate", "depot.jl"))

import TOML

"""
    worker_count(args)

The number of suites to run at once, from `args`. No default: the caller states it,
and `tools/gate/gate.sh` passes `\$SLURM_CPUS_PER_TASK`, because a job is given whole
physical cores and `nproc` counts both SMT siblings of each
(`~/.claude/CLAUDE.md`). Refuses on a missing, unparseable or non-positive count
rather than guessing one.
"""
function worker_count(args::Vector{String})
    length(args) == 1 ||
        error("tools/gate/run.jl takes one argument, the number of suites to run at " *
              "once; it has no default because sizing it from this process's view of " *
              "the machine is what \$SLURM_CPUS_PER_TASK exists to replace")
    n = tryparse(Int, args[1])
    (n === nothing || n < 1) &&
        error("worker count $(args[1]) is not a positive integer")
    return n
end

"""
The flags every suite process carries beyond the defaults, so that the gate and
`Pkg.test()` report the same things. `Pkg.test()` sets both, and a suite run without
them says nothing when a method is overwritten or a deprecated binding is used
(notes/findings/2026-09-12-the-overwrite-warning-reaches-one-door-of-two.md).

`--check-bounds=yes`, which `Pkg.test()` also sets, is not here: it changes what is
compiled rather than what is reported. It is `BOUNDS_FLAGS`, which the checked pass
and the nightly bed add (decisions 0050 and 0055).
"""
const SUITE_FLAGS = `--warn-overwrite=yes --depwarn=yes`

"""
The flags a checked pass adds to `SUITE_FLAGS`: the gate's second pass over a change
that elides a bounds check, and every night's run (`tools/nightly/run.jl`).
"""
const BOUNDS_FLAGS = `--check-bounds=yes`

"The suffix a suite's label carries in the checked pass, in the report and its log name."
const CHECKED_SUFFIX = "+bounds"

"""
    checkout_depot(root)

The depot the checkout at `root` compiles into: `DEPOT_NAME` under the checkout's own git
directory, `git rev-parse --absolute-git-dir`, which is `.git/worktrees/<name>` for a
worktree and `.git` for the main checkout. Refuses when git finds no checkout at `root`.
"""
function checkout_depot(root::AbstractString)
    gitdir = try
        strip(read(pipeline(git_at(root, `rev-parse --absolute-git-dir`); stderr = devnull), String))
    catch
        error("the gate compiles into a depot under the checkout's git directory, and " *
              "git found no checkout at $(root)")
    end
    return joinpath(gitdir, DEPOT_NAME)
end

"""
    in_checkout(cmd, root; inherited)

`cmd` compiling into `checkout_depot(root)` ahead of `inherited`: `in_depot` on that
depot. Every command this driver builds for a `julia` passes through here.
"""
in_checkout(cmd::Cmd, root::AbstractString; inherited::Vector{String} = DEPOT_PATH) =
    in_depot(cmd, checkout_depot(root); inherited = inherited)

"""
    suite_command(root, name)

The command that runs one suite in its own process: the suite's own entry point,
included by a fresh `julia` on the same project, with `threads` threads. A suite
that fails throws out of `include`, so the process exits non-zero and
`run_suites` reads that as the suite's verdict.

Every suite is given the whole thread budget rather than a share of it. A thread
a suite does not use costs a stack and nothing else, and the one suite that does
use them, `certify`, is the last to finish and has the machine to itself for most
of its run (notes/findings/2026-09-12-the-gate-in-parallel.md).

`extra` is what a caller adds to `SUITE_FLAGS` for its own door: `BOUNDS_FLAGS` for
the checked pass and the nightly bed.
"""
suite_command(root::AbstractString, name::AbstractString, threads::Int;
              extra::Cmd = ``) =
    in_checkout(`julia --startup-file=no $(SUITE_FLAGS) $(extra) --project=$(root) -t $(threads) -e $("include(raw\"" * joinpath(root, "test", name, "runtests.jl") * "\")")`, root)

"""
    warm_code(package)

The Julia a warm-up runs: load `package`, then, when the image it loaded is not in the
process's first depot, compile one there with `Base.compilecache`.
"""
warm_code(package::AbstractString) = """
    using $(package)
    id = Base.PkgId($(package))
    startswith(Base.pkgorigins[id].cachepath, joinpath(DEPOT_PATH[1], "")) ||
        Base.compilecache(id)
    """

"""
    warm_command(root; extra)

Load the package once before any worker starts. Workers that start together on a
stale cache otherwise each begin precompiling and wait on each other's pidfile,
which costs more than the one load it saves.

`extra` is the caller's own flags and must be the same ones its suites will carry.
Julia caches per configuration, so a warm-up under different flags warms a cache
nothing then reads, and every worker precompiles after all. `warm_command` is split
out so a test can read the two commands against each other rather than waiting for a
suite to fail on a missing image.
"""
warm_command(root::AbstractString; extra::Cmd = ``) =
    in_checkout(`julia --startup-file=no $(SUITE_FLAGS) $(extra) --project=$(root) -e $(warm_code("Fiddlybits"))`, root)

"""
    warm_precompile(root; extra)

Run `warm_command` and return how long it took.
"""
function warm_precompile(root::AbstractString; extra::Cmd = ``)
    cmd = warm_command(root; extra = extra)
    seconds = @elapsed success(pipeline(cmd; stdout = devnull, stderr = devnull)) ||
        error("the package did not load; every suite would fail the same way")
    return seconds
end

"""
    warm_both(root)

Warm the default configuration and the `BOUNDS_FLAGS` one at once, and return their
times as `(default, bounds)`. Both are warmed on every run: `test/backends` starts a
probe process under each, whichever pass it is in.
"""
function warm_both(root::AbstractString)
    bounds = Threads.@spawn warm_precompile(root; extra = BOUNDS_FLAGS)
    default = warm_precompile(root)
    return (default, fetch(bounds))
end

"""
    in_process(root, logdir, threads; extra, suffix)

The runner `run_suites` uses in earnest: one suite, in its own `julia`, with its
whole output in `logdir` under the suite's name followed by `suffix`. Returns whether
the suite passed.

A suite is a process and not a task, so nothing it defines, allocates or leaves
behind can reach another suite. That is what makes the partition unable to change
a suite's result, and it is also worth 2.4 on `certify` by itself, because a
suite's collection cost stops being a function of what ran before it
(notes/findings/2026-09-12-the-gate-in-parallel.md).
"""
in_process(root::AbstractString, logdir::AbstractString, threads::Int;
           extra::Cmd = ``, suffix::AbstractString = "") =
    name -> open(joinpath(logdir, name * suffix * ".log"), "w") do io
        success(pipeline(suite_command(root, name, threads; extra = extra);
                         stdout = io, stderr = io))
    end

"""
    run_suites(names, workers, runner)

Call `runner(name)` once for each of `names`, at most `workers` at once, and return
one `(name, ok, seconds)` per suite in the order `names` gave, whatever order they
ran in.

Which suites run, and how many times each runs, is a function of `names` alone and
never of `workers`: the worker count decides only how many wait. `runner` is an
argument so a test can check that without running a suite
(`test/gate/parallel_gate.jl`).
"""
function run_suites(names::Vector{String}, workers::Int, runner)
    results = Vector{Tuple{String,Bool,Float64}}(undef, length(names))
    slots = Base.Semaphore(workers)
    @sync for (i, name) in enumerate(names)
        @async begin
            Base.acquire(slots)
            try
                started = time()
                ok = runner(name)::Bool
                seconds = time() - started
                results[i] = (name, ok, seconds)
                # One string and one write, because tasks finish while other tasks
                # are printing.
                println(string(ok ? "  pass  " : "  FAIL  ", rpad(name, 12),
                               lpad(round(seconds; digits = 1), 7), " s"))
                flush(stdout)
            finally
                Base.release(slots)
            end
        end
    end
    return results
end

"""
    accepted_warnings(root)

The `(pattern, reason)` pairs of `tools/gate/warnings.toml`: the warning lines a
suite may write without refusing the run. A missing record, or an entry with an empty
pattern or an empty reason, refuses: the gate cannot decide what to pass over from a
record it cannot read, and an accepted warning that says nothing about why it stands
is an exclusion nobody can review.
"""
function accepted_warnings(root::AbstractString)
    path = joinpath(root, "tools", "gate", "warnings.toml")
    isfile(path) ||
        error("the gate reads the warnings it accepts from $(path), which does not " *
              "exist; an empty [[accepted]] list there accepts none, which is a " *
              "different thing from having no record")
    entries = get(TOML.parsefile(path), "accepted", Dict{String,Any}[])
    pairs = Tuple{String,String}[]
    for e in entries
        pattern, reason = get(e, "pattern", ""), get(e, "reason", "")
        (isempty(pattern) || isempty(reason)) &&
            error("every entry of $(path) needs a pattern and a reason; one has " *
                  "pattern \"$(pattern)\" and reason \"$(reason)\"")
        push!(pairs, (pattern, reason))
    end
    return pairs
end

"""
    unaccepted_warnings(text, accepted)

The warning lines in `text` that no entry of `accepted` covers. A warning is a line
opening `WARNING:`, which is how the runtime writes one, or `\u250c Warning:`, which
is the top of a `@warn` box; the rest of a box is its detail and is not scanned.
"""
function unaccepted_warnings(text::AbstractString, accepted)
    found = String[]
    for line in eachline(IOBuffer(text))
        startswith(line, "WARNING:") || startswith(line, "\u250c Warning:") || continue
        any(p -> occursin(first(p), line), accepted) && continue
        push!(found, line)
    end
    return found
end

"""
    report(results, logdir, wall)

Print the per-suite wall times longest first, then the total of them and the wall
time the run actually took, then every warning no entry of `tools/gate/warnings.toml`
accepts, then the whole output of every suite that failed. Returns the process
status: zero when every suite passed and wrote no unaccepted warning.

A warning refuses the run rather than being printed and passed over. The gate is the
door every commit and every push goes through, and a suite that passes while writing
a warning into a log file is the shape this reporting exists to end
(notes/findings/2026-09-12-the-overwrite-warning-reaches-one-door-of-two.md).

`logdir` is not cleaned up, so a run that passed still has each suite's whole
output on disk to read afterwards; the path is printed when the run starts.
"""
function report(results::Vector{Tuple{String,Bool,Float64}}, logdir::AbstractString,
                wall::Float64; accepted = accepted_warnings(ROOT))
    width = maximum(length(r[1]) for r in results)
    serial = sum(r[3] for r in results)
    println()
    println("suite wall time, longest first")
    for (name, ok, seconds) in sort(results; by = r -> r[3], rev = true)
        println("  ", rpad(name, width), "  ", lpad(round(seconds; digits = 1), 7), " s",
                "  ", ok ? "pass" : "FAIL")
    end
    println("  ", rpad("sum of suites", width), "  ", lpad(round(serial; digits = 1), 7), " s")
    println("  ", rpad("wall", width), "  ", lpad(round(wall; digits = 1), 7), " s",
            "  speedup ", round(serial / wall; digits = 2))

    warned = Tuple{String,String}[]
    for (name, _, _) in results
        log = joinpath(logdir, name * ".log")
        isfile(log) || continue
        for line in unaccepted_warnings(read(log, String), accepted)
            push!(warned, (name, line))
        end
    end
    if !isempty(warned)
        println()
        println("=== warnings no entry of tools/gate/warnings.toml accepts ===")
        for (name, line) in warned
            println("  ", rpad(name, width), "  ", line)
        end
        println("  fix it, or add it to tools/gate/warnings.toml with the reason it stands")
    end

    failed = [r[1] for r in results if !r[2]]
    for name in failed
        println()
        println("=== ", name, " failed; its whole output follows ===")
        println(read(joinpath(logdir, name * ".log"), String))
    end
    return (isempty(failed) && isempty(warned)) ? 0 : 1
end

"""
    git_at(root, args)

`git -C root` with `args`, in this process's environment less every variable `git
rev-parse --local-env-vars` names (`GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE` and the
rest), so the repository it acts on is the one at `root` and not one the calling
process was pointed at, as a git hook's process is.
"""
function git_at(root::AbstractString, args::Cmd)
    located = Set(split(read(`git rev-parse --local-env-vars`, String)))
    env = Dict(k => v for (k, v) in ENV if !(k in located))
    return setenv(`git -C $(root) $(args)`, env)
end

is_macro_named(head, name::Symbol) =
    head === name || (head isa Expr && head.head === :. && length(head.args) == 2 &&
                      head.args[2] isa QuoteNode && head.args[2].value === name)

"""
    elision_sites(text)

Every place Julia source `text` elides a bounds check, as `(line, form, in_kernel)`:
an `@inbounds` (or `Base.@inbounds`) call, an `Expr(:inbounds, ...)` built in code,
or a KernelAbstractions `@kernel` given `inbounds=true`. `in_kernel` is whether the
site sits inside the arguments of a `@kernel` call. Read from the parsed syntax, so a
string or a comment naming the macro is not a site.

Source that does not parse is one site, `(0, "unparseable", false)`.
"""
function elision_sites(text::AbstractString)
    parsed = try
        Meta.parseall(text)
    catch
        return [(0, "unparseable", false)]
    end
    sites = Tuple{Int,String,Bool}[]
    line = Ref(0)
    function walk(node, in_kernel::Bool)
        if node isa LineNumberNode
            line[] = node.line
        elseif node isa Expr
            if node.head === :error || node.head === :incomplete
                push!(sites, (line[], "unparseable", in_kernel))
                return
            end
            if node.head === :macrocall && !isempty(node.args)
                name = node.args[1]
                length(node.args) >= 2 && node.args[2] isa LineNumberNode &&
                    (line[] = node.args[2].line)
                if is_macro_named(name, Symbol("@inbounds"))
                    push!(sites, (line[], "@inbounds", in_kernel))
                elseif is_macro_named(name, Symbol("@kernel"))
                    for a in node.args
                        a isa Expr && a.head === :(=) && a.args[1] === :inbounds &&
                            a.args[2] === true &&
                            push!(sites, (line[], "@kernel inbounds=true", true))
                    end
                    foreach(a -> walk(a, true), node.args[2:end])
                    return
                end
            elseif node.head === :call && length(node.args) >= 2 && node.args[1] === :Expr &&
                   node.args[2] isa QuoteNode && node.args[2].value === :inbounds
                push!(sites, (line[], "Expr(:inbounds)", in_kernel))
            end
            foreach(a -> walk(a, in_kernel), node.args)
        end
    end
    walk(parsed, false)
    return sites
end

"""
    split_lines(text)

The non-empty lines of `text`.
"""
split_lines(text::AbstractString) = String[l for l in split(text, '\n') if !isempty(l)]

"""
    changed_paths(root; base_ref)

`(base, paths)`: the merge base of `base_ref` and `HEAD` in the repository at `root`,
and every path, relative to `root`, that the working tree changes against it: tracked
changes whether committed, staged or not, and untracked files not ignored. A rename is
its two paths. Refuses when `base_ref` does not resolve, naming it.
"""
function changed_paths(root::AbstractString; base_ref::AbstractString = "main")
    base = try
        strip(read(git_at(root, `merge-base $(base_ref) HEAD`), String))
    catch
        error("the bounds door diffs against the merge base of $(base_ref) and HEAD, " *
              "and git found none in $(root); a checkout without $(base_ref) cannot " *
              "say which of its files a change touches")
    end
    tracked = split_lines(read(git_at(root, `diff --name-only --no-renames $(base)`), String))
    untracked = split_lines(read(git_at(root, `ls-files --others --exclude-standard`), String))
    return String(base), sort(unique(vcat(tracked, untracked)))
end

"""
    eliding_changes(root; base_ref)

`(base, eliding)`: the merge base `changed_paths` found, and every changed `.jl` file
present in the working tree whose `elision_sites` are not empty, as `path => sites`.
"""
function eliding_changes(root::AbstractString; base_ref::AbstractString = "main")
    base, paths = changed_paths(root; base_ref = base_ref)
    eliding = Pair{String,Vector{Tuple{Int,String,Bool}}}[]
    for p in paths
        endswith(p, ".jl") || continue
        file = joinpath(root, p)
        isfile(file) || continue
        sites = elision_sites(read(file, String))
        isempty(sites) || push!(eliding, p => sites)
    end
    return base, eliding
end

"""
    door_controls()

Run `eliding_changes` on scratch repositories where the answer is known, and refuse
unless every one comes out as stated: a change to a file carrying `@inbounds`, an
untracked file carrying one and a `@kernel inbounds=true` each trigger; a change to a
file without one, a docstring naming the macro, and a clean branch do not. Returns the
number of controls run.
"""
function door_controls()
    git(dir, args) = run(pipeline(git_at(dir, `-c user.email=gate@fiddlybits -c user.name=gate $(args)`);
                                  stdout = devnull, stderr = devnull))
    eliding = "function f(v)\n    @inbounds return v[1]\nend\n"
    plain = "function g(v)\n    return v[1]\nend\n"
    named = "\"\"\"\n    h(v)\n\nReads under `@inbounds`.\n\"\"\"\nh(v) = v[1]\n"
    forced = "using KernelAbstractions\n@kernel inbounds=true function k!(o)\n    i = @index(Global)\n    o[i] = 1\nend\n"
    cases = (
        ("a clean branch", (d) -> nothing, String[]),
        ("a change to a file without an elision", (d) -> write(joinpath(d, "plain.jl"), plain * "# changed\n"), String[]),
        ("a change to a file carrying @inbounds", (d) -> write(joinpath(d, "kernel.jl"), eliding * "# changed\n"), ["kernel.jl"]),
        ("an untracked file carrying @inbounds", (d) -> write(joinpath(d, "new.jl"), eliding), ["new.jl"]),
        ("a docstring naming the macro", (d) -> write(joinpath(d, "named.jl"), named), String[]),
        ("a @kernel given inbounds=true", (d) -> write(joinpath(d, "forced.jl"), forced), ["forced.jl"]),
        ("a committed change on the branch", (d) -> begin
             write(joinpath(d, "kernel.jl"), eliding * "# committed\n")
             git(d, `commit -q -am change`)
         end, ["kernel.jl"]),
    )
    for (what, change, expected) in cases
        dir = mktempdir()
        git(dir, `init -q -b main`)
        write(joinpath(dir, "kernel.jl"), eliding)
        write(joinpath(dir, "plain.jl"), plain)
        git(dir, `add -A`)
        git(dir, `commit -q -m base`)
        git(dir, `checkout -q -b change`)
        change(dir)
        _, found = eliding_changes(dir)
        got = first.(found)
        got == expected ||
            error("the bounds door's control \"$(what)\" found $(got) where it must find " *
                  "$(expected); the door cannot be trusted to say which changes elide a check")
        rm(dir; recursive = true)
    end
    return length(cases)
end

"""
    probe_command(root, flags, arms)

The command that runs `tools/gate/bounds_probe.jl` over `arms` in a fresh `julia` on
`root`'s project, carrying `SUITE_FLAGS` and `flags`.
"""
probe_command(root::AbstractString, flags::Cmd, arms::Vector{String}) =
    in_checkout(`julia --startup-file=no $(SUITE_FLAGS) $(flags) --project=$(root) $(joinpath(root, "tools", "gate", "bounds_probe.jl")) $(arms)`, root)

"""
    probe_verdicts(text)

The TOML lines of a probe's stdout, parsed: every line opening with a lower-case key
and ` = `. The card's own kernel exception report shares the stream and is not read.
"""
probe_verdicts(text::AbstractString) =
    TOML.parse(join(filter(l -> occursin(r"^[a-z_]+ = ", l), split(text, '\n')), "\n"))

"""
    run_probe(root, flags, arms)

`probe_verdicts` of `probe_command(root, flags, arms)`. Refuses, carrying what the
process wrote, when any arm has no verdict.
"""
function run_probe(root::AbstractString, flags::Cmd, arms::Vector{String})
    buffer = IOBuffer()
    run(pipeline(ignorestatus(probe_command(root, flags, arms)); stdout = buffer, stderr = buffer))
    text = String(take!(buffer))
    verdicts = probe_verdicts(text)
    all(a -> haskey(verdicts, a), arms) ||
        error("the bounds probe under $(flags) gave no verdict for every arm of " *
              "$(join(arms, ", ")); it wrote:\n$(text)")
    return verdicts
end

"""
    bounds_reach(root, flags)

Run the probe's two marker arms under `flags` and return its verdicts, refusing unless
both read `"checked"`: a pass under `flags` that did not compile bounds checks into
the kernels it launches on both backends would report a pass it did not earn.
"""
function bounds_reach(root::AbstractString, flags::Cmd)
    verdicts = run_probe(root, flags, ["marker_cpu", "marker_gpu"])
    for arm in ("marker_cpu", "marker_gpu")
        verdicts[arm] == "checked" ||
            error("under $(flags) the kernels launched on $(arm[end-2:end]) under " *
                  "@inbounds read \"$(verdicts[arm])\" and not \"checked\" " *
                  "($(get(verdicts, arm * "_detail", ""))); a pass under these flags " *
                  "would not check what it claims to")
    end
    return verdicts
end

"""
    door_summary(base, eliding)

The lines the gate prints about the bounds door: the merge base, and either every
changed file that elides a check with the lines of its sites, or that there is none.
"""
function door_summary(base::AbstractString, eliding)
    head = "gate: bounds door against main at $(base[1:min(end, 12)]): "
    isempty(eliding) &&
        return [head * "no changed .jl file elides a bounds check; no checked pass"]
    lines = [head * "$(length(eliding)) changed .jl file(s) elide a bounds check; every " *
             "suite also runs under $(join(BOUNDS_FLAGS.exec, " "))"]
    for (path, sites) in eliding
        push!(lines, "gate:   " * path * " at line(s) " *
                     join(unique(string(s[1]) for s in sites), ", "))
    end
    return lines
end

function main(args::Vector{String})
    workers = worker_count(args)
    found, missing = suites(joinpath(ROOT, "test"))
    isempty(missing) ||
        error("every directory under test/ must hold a runtests.jl; these do not: " *
              join(missing, ", "))
    isempty(found) && error("no suite was found under test/")

    controls = door_controls()
    base, eliding = eliding_changes(ROOT)
    summary = door_summary(base, eliding)
    foreach(println, summary)
    println("gate: the door's ", controls, " controls came out as stated")

    logdir = mktempdir(; cleanup = false)
    println("gate: ", length(found), " suites, ", workers, " at once, logs in ", logdir)
    default_warm, bounds_warm = warm_both(ROOT)
    println("gate: package warm in ", round(default_warm; digits = 1), " s, and in ",
            round(bounds_warm; digits = 1), " s under ", join(BOUNDS_FLAGS.exec, " "))

    plain = in_process(ROOT, logdir, workers)
    names = copy(found)
    runner = plain
    if !isempty(eliding)
        reach = bounds_reach(ROOT, BOUNDS_FLAGS)
        println("gate: under ", join(BOUNDS_FLAGS.exec, " "), " kernels under @inbounds read ",
                reach["marker_cpu"], " on cpu and ", reach["marker_gpu"], " on gpu")
        checked = in_process(ROOT, logdir, workers; extra = BOUNDS_FLAGS, suffix = CHECKED_SUFFIX)
        names = collect(Iterators.flatten((n, n * CHECKED_SUFFIX) for n in found))
        runner = label -> endswith(label, CHECKED_SUFFIX) ?
            checked(label[1:end-length(CHECKED_SUFFIX)]) : plain(label)
    end

    wall = time()
    results = run_suites(names, workers, runner)
    status = report(results, logdir, time() - wall)
    println()
    foreach(println, summary)
    return status
end

(abspath(PROGRAM_FILE) == @__FILE__) && exit(main(ARGS))
