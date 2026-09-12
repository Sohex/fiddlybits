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

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
include(joinpath(ROOT, "test", "suites.jl"))

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

`--check-bounds=yes`, which `Pkg.test()` also sets, is not here. It is the one flag
that changes what is compiled rather than what is reported, and it costs the gate a
factor of 2.2 against a wall time decision 0049 bounds
(notes/findings/2026-09-12-what-the-gate-pays-for-each-of-pkg-test-s-flags.md).
"""
const SUITE_FLAGS = `--warn-overwrite=yes --depwarn=yes`

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

`extra` is what a caller adds to `SUITE_FLAGS` for its own door. The nightly bed
passes `--check-bounds=yes` there (`tools/nightly/run.jl`), which decision 0050 keeps
off the gate.
"""
suite_command(root::AbstractString, name::AbstractString, threads::Int;
              extra::Cmd = ``) =
    `julia --startup-file=no $(SUITE_FLAGS) $(extra) --project=$(root) -t $(threads) -e $("include(raw\"" * joinpath(root, "test", name, "runtests.jl") * "\")")`

"""
    warm_precompile(root)

Load the package once before any worker starts. Workers that start together on a
stale cache otherwise each begin precompiling and wait on each other's pidfile,
which costs more than the one load it saves.
"""
function warm_precompile(root::AbstractString)
    cmd = `julia --startup-file=no $(SUITE_FLAGS) --project=$(root) -e "using Fiddlybits"`
    seconds = @elapsed success(pipeline(cmd; stdout = devnull, stderr = devnull)) ||
        error("the package did not load; every suite would fail the same way")
    return seconds
end

"""
    in_process(root, logdir)

The runner `run_suites` uses in earnest: one suite, in its own `julia`, with its
whole output in `logdir`. Returns whether the suite passed.

A suite is a process and not a task, so nothing it defines, allocates or leaves
behind can reach another suite. That is what makes the partition unable to change
a suite's result, and it is also worth 2.4 on `certify` by itself, because a
suite's collection cost stops being a function of what ran before it
(notes/findings/2026-09-12-the-gate-in-parallel.md).
"""
in_process(root::AbstractString, logdir::AbstractString, threads::Int;
           extra::Cmd = ``) =
    name -> open(joinpath(logdir, name * ".log"), "w") do io
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

function main(args::Vector{String})
    workers = worker_count(args)
    found, missing = suites(joinpath(ROOT, "test"))
    isempty(missing) ||
        error("every directory under test/ must hold a runtests.jl; these do not: " *
              join(missing, ", "))
    isempty(found) && error("no suite was found under test/")

    logdir = mktempdir(; cleanup = false)
    println("gate: ", length(found), " suites, ", workers, " at once, logs in ", logdir)
    warmed = warm_precompile(ROOT)
    println("gate: package warm in ", round(warmed; digits = 1), " s")

    wall = time()
    results = run_suites(found, workers, in_process(ROOT, logdir, workers))
    return report(results, logdir, time() - wall)
end

(abspath(PROGRAM_FILE) == @__FILE__) && exit(main(ARGS))
