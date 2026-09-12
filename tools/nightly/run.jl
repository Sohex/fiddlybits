#!/usr/bin/env julia
# The nightly bed of decision 0043: what is too slow to run per commit, on the machine
# that holds the data and the card, against `main`.
#
#   julia --project tools/nightly/run.jl <workers>
#
# It runs the same suites as the gate, through the same driver, with
# `--check-bounds=yes` added. Decision 0050 keeps that flag off the gate because it
# costs a factor of 2.2 against a wall time the remote's idle timeout bounds; nothing
# bounds a nightly, so the coverage lands here rather than nowhere.
#
# The subject is `main` with a clean tree. A nightly whose subject moves with whatever
# was last pushed cannot be compared with the one before it, and comparison is the
# whole of what a nightly is for, so this refuses rather than running on something
# else.

const NIGHTLY_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

"""
What the nightly adds to the gate's `SUITE_FLAGS`. Read by the warm-up and by every
suite from this one binding: Julia caches per configuration, so a warm-up under
different flags warms a cache nothing reads and every worker precompiles after all.
`nightly` asserts the two commands carry it.
"""
const EXTRA_FLAGS = `--check-bounds=yes`

# The gate's driver, in a module of its own: it includes `test/suites.jl`, and loading
# it into this namespace would define `suites` twice, which is the one thing the
# shared file exists to prevent (test/closure.jl for the same shape on the test side).
module Gate
include(joinpath(normpath(joinpath(@__DIR__, "..", "..")), "tools", "gate", "run.jl"))
end

import TOML
using Dates: now, format

"""
    subject(root)

The commit the nightly is about, as `(branch, sha)`, or a refusal. `main` with nothing
uncommitted and nothing untracked: a run against a working tree is a run nobody can
reproduce or compare, and guessing which of the two the caller meant is worse than
saying so.
"""
function subject(root::AbstractString)
    branch = strip(read(`git -C $(root) rev-parse --abbrev-ref HEAD`, String))
    branch == "main" ||
        error("the nightly runs against main and this checkout is on $(branch); " *
              "check main out, or run tools/gate/gate.sh, which is the door for a branch")
    dirty = strip(read(`git -C $(root) status --porcelain`, String))
    isempty(dirty) ||
        error("the nightly runs against a clean tree and this one has changes:\n" *
              dirty * "\ncommit them or stash them; a run against a working tree " *
              "is not one the next night can be compared with")
    return (branch, strip(read(`git -C $(root) rev-parse HEAD`, String)))
end

"""
    record_dir()

Where a night's result is written: `\$XDG_STATE_HOME/fiddlybits/nightly`, outside the
tree. It is outside because this driver refuses to run against a tree with changes in
it, and a result written into that tree would be the change that refuses the next
night.
"""
function record_dir()
    state = get(ENV, "XDG_STATE_HOME", joinpath(homedir(), ".local", "state"))
    dir = joinpath(state, "fiddlybits", "nightly")
    mkpath(dir)
    return dir
end

"""
    write_record(dir, sha, results, wall, status)

One TOML record per night, named by the time it started and the commit it was about,
so the series reads in order and says what each night was. A name already taken takes
a counter rather than the file: a rerun of one commit is a second reading of it, not a
correction of the first.

Holds the commit, the status, the wall time and every suite's own, which is what the
next night is compared against.
"""
function write_record(dir::AbstractString, sha::AbstractString,
                      results::Vector{Tuple{String,Bool,Float64}}, wall::Float64,
                      status::Int)
    stamp = format(now(), "yyyy-mm-ddTHH-MM-SS")
    base = stamp * "-" * sha[1:min(end, 12)]
    path = joinpath(dir, base * ".toml")
    n = 1
    while isfile(path)
        n += 1
        path = joinpath(dir, base * "-" * string(n) * ".toml")
    end
    open(path, "w") do io
        println(io, "# tools/nightly/run.jl. One file per run; nothing here is edited.")
        println(io, "commit = ", repr(sha))
        println(io, "started = ", repr(stamp))
        println(io, "status = ", status)
        println(io, "wall_seconds = ", round(wall; digits = 1))
        println(io, "check_bounds = true")
        for (name, ok, seconds) in results
            println(io)
            println(io, "[[suite]]")
            println(io, "name = ", repr(name))
            println(io, "passed = ", ok)
            println(io, "seconds = ", round(seconds; digits = 1))
        end
    end
    return path
end

function main(args::Vector{String})
    workers = Gate.worker_count(args)
    branch, sha = subject(NIGHTLY_ROOT)
    found, missing = Gate.suites(joinpath(NIGHTLY_ROOT, "test"))
    isempty(missing) ||
        error("every directory under test/ must hold a runtests.jl; these do not: " *
              join(missing, ", "))

    logdir = mktempdir(; cleanup = false)
    println("nightly: ", branch, " at ", sha[1:min(end, 12)], ", ", length(found),
            " suites, ", workers, " at once, logs in ", logdir)
    println("nightly: --check-bounds=yes, which the gate does not carry (decision 0050)")
    println("nightly: package warm in ",
            round(Gate.warm_precompile(NIGHTLY_ROOT; extra = EXTRA_FLAGS); digits = 1), " s")

    started = time()
    runner = Gate.in_process(NIGHTLY_ROOT, logdir, workers; extra = EXTRA_FLAGS)
    results = Gate.run_suites(found, workers, runner)
    wall = time() - started
    status = Gate.report(results, logdir, wall)

    record = write_record(record_dir(), sha, results, wall, status)
    println()
    println("nightly: recorded in ", record)
    return status
end

(abspath(PROGRAM_FILE) == @__FILE__) && exit(main(ARGS))
