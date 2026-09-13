# The benchmark bed. Decision 0029 makes a benchmark a failing test, and a bar is
# applied only after the bed's own A/A scatter is measured, so the bed measures
# before it judges. No registered case carries a bar; the A/A scatter of this bed is
# notes/findings/2026-09-12-reduction-bench-scatter.md.
#
# Every case is GPU-resident. The inputs are built on the host and moved to the
# device once, outside the timing, and each segmented case calls the `Segmentation`
# form, which reads no boundary array back to the host.
#
# The rows that optimise these kernels report their before and after against these
# cases on this bed: fiddlybits-zgh, fiddlybits-2tg, fiddlybits-3jt, fiddlybits-ool,
# fiddlybits-9j7, fiddlybits-dn6.
#
# Every run reads its own scheduler allocation once, at the start: a job holding all
# four shares needs no further reading to know it is the sole holder, since no other
# job can reach the card. A job holding fewer shares takes one occupancy reading
# before the first case and one more between every case and the next; those readings
# are point samples, and a neighbour that starts and ends inside one case's own
# measurement is invisible to them. What a reading licenses is
# notes/findings/2026-09-12-reduction-bench-occupancy.md.

const LOAD_SECONDS = @elapsed using Fiddlybits

using Fiddlybits: Backends, Mesh, Reductions, Verdicts
using TOML

# The suite's synthetic inputs, read rather than restated: one definition of the
# filling formula and of the boundary array, in test/reductions/fixtures.jl.
include(joinpath(@__DIR__, "..", "test", "reductions", "fixtures.jl"))

"""
    WORKGROUP

The workgroup size every case launches at. `segmented_quantile` replaces it with
the segment length on its own (`Reductions.at_workgroup`) and is unaffected.
"""
const WORKGROUP = 256

"""
    FINE, COARSE

The levels the segmented cases cross. `FINE` holds the elements and each `COARSE`
level holds the segments, so a segment is one coarse cell's `4^k` descendants at
depth `k = FINE - COARSE` (decision 0005). `COARSE` names two crossings at one
element count, so the bed separates the segment count from the element count.

No profile exists to read these from: decision 0014 makes the level a profile
field and fixes no number, and no `Profile` value exists yet. fiddlybits-2pn
checks these against a profile once one does.
"""
const FINE = 7
const COARSE = (5, 4)

"""
    SIZES

The element counts the unsegmented cases run at, as levels of the same hierarchy.
"""
const SIZES = (5, 7)

"""
    THRESHOLD

The value `area_fraction_above` counts from. The fixture's filling spans both
signs, so zero puts a little under half the elements above it.
"""
const THRESHOLD = 0.0

"""
    QUANTILE

The quantile `segmented_quantile` selects.
"""
const QUANTILE = 0.5

"""
    CALLS, BATCHES

The calls in one batch and the batches sampled, the same on every case so that
two runs of the bed queue the same work in the same order. `CALLS` is bounded by
what one batch leaves outstanding on the device rather than by how long the batch
takes: every call allocates its own result and nothing is read back until the
batch closes, so the batch's device footprint grows with it.

`BATCHES` is what carries the bed past the floor `STARTUP_MULTIPLE` sets, and the
fast cases and the slow ones therefore take unequal shares of the bed's time and
equal numbers of samples.
"""
const CALLS = 400
const BATCHES = 200

"""
    WARMUP_BATCHES

Batches run and discarded before the first sample of a case, so no sample carries
the first launch's compilation.
"""
const WARMUP_BATCHES = 2

"""
    STARTUP_MULTIPLE

The multiple of its own startup the bed must spend measuring, which decision 0029
requires it to declare and refuse below. Startup is this process's whole age when
the first case begins: the interpreter, `using Fiddlybits`, and the case tables.
Measuring for four times that puts the bed's startup under a fifth of the job it
asks the scheduler for. The warm-up batches are outside both sides of the
comparison.
"""
const STARTUP_MULTIPLE = 4

"""
    Case(id, sizes, calls, batches, prepare)

One registered benchmark case. `prepare(backend)` builds the case's inputs on
`backend` and returns the zero-argument call under test. `calls` is the number of
calls in one batch and `batches` the number of batches sampled; the statistic is
the minimum over batches of the mean seconds per call, which is what `CONTROLS`
judges and what a bar would judge.

`bar` is `nothing` on every registered case: decision 0029 refuses a bar narrower
than its instrument's scatter, and this bed's scatter is the finding named at the
top of this file.
"""
struct Case
    id::String
    sizes::String
    calls::Int
    batches::Int
    bar::Union{Nothing, Float64}
    prepare::Function
end

Case(id, sizes, calls, batches, prepare) = Case(id, sizes, calls, batches, nothing, prepare)

"The fixture vector of `n` elements, on `backend`."
elements(n, backend) = Backends.on(ReductionFixtures.seeded_vector(Float64, n), backend)

"A positive weight per element, on `backend`: the fixture vector's magnitudes lifted off zero."
weights(n, backend) = Backends.on(abs.(ReductionFixtures.seeded_vector(Float64, n)) .+ 0.1, backend)

"""
    crossing(fine, coarse, backend)

The elements, the `Segmentation` and the weights of the crossing from level
`fine` to level `coarse`, all on `backend`. The `Segmentation` is built here, so
no case times the boundary check or the copy that checks it.
"""
function crossing(fine::Integer, coarse::Integer, backend::Backends.Backend)
    n, nseg = Mesh.ncells(fine), Mesh.ncells(coarse)
    xs = elements(n, backend)
    starts = Backends.on(ReductionFixtures.segment_starts(n, nseg), backend)
    return xs, Reductions.Segmentation(xs, starts), weights(n, backend)
end

"`level` and the element or segment count it carries, as one word."
at(level::Integer) = "level $level, $(Mesh.ncells(level)) cells"

"The two levels a segmented case crosses, as one word."
across(fine::Integer, coarse::Integer) =
    "$(at(coarse)) over $(at(fine)), segment length $(4^(fine - coarse))"

"""
    CASES

The registered cases. Every reduction the optimisation rows name, at declared
sizes: the two unsegmented reductions at both element counts, and the four
segmented ones at both crossings of one element count.
"""
const CASES = (
    (Case("reduction.pairwise_sum.$l", at(l), CALLS, BATCHES,
          backend -> let xs = elements(Mesh.ncells(l), backend)
              () -> Reductions.pairwise_sum(Float64, xs, backend)
          end) for l in SIZES)...,

    (Case("reduction.area_fraction_above.$l", at(l), CALLS, BATCHES,
          backend -> let n = Mesh.ncells(l), xs = elements(n, backend), as = weights(n, backend)
              () -> Reductions.area_fraction_above(xs, as, THRESHOLD, backend)
          end) for l in SIZES)...,

    (Case("reduction.segmented_sum.$c", across(FINE, c), CALLS, BATCHES,
          backend -> let (xs, seg, _) = crossing(FINE, c, backend)
              () -> Reductions.segmented_sum(Float64, xs, seg, backend)
          end) for c in COARSE)...,

    (Case("reduction.segmented_weighted_sum.$c", across(FINE, c), CALLS, BATCHES,
          backend -> let (xs, seg, ws) = crossing(FINE, c, backend)
              () -> Reductions.segmented_weighted_sum(Float64, xs, ws, seg, backend)
          end) for c in COARSE)...,

    (Case("reduction.segmented_mean.$c", across(FINE, c), CALLS, BATCHES,
          backend -> let (xs, seg, ws) = crossing(FINE, c, backend)
              () -> Reductions.segmented_mean(Float64, xs, seg, ws, backend)
          end) for c in COARSE)...,

    (Case("reduction.segmented_quantile.$c", across(FINE, c), CALLS, BATCHES,
          backend -> let (xs, seg, _) = crossing(FINE, c, backend)
              () -> Reductions.segmented_quantile(xs, seg, QUANTILE, backend)
          end) for c in COARSE)...,
)

"""
    CONTROLS

The bed's positive controls: a registered case's own measured value judged by the
same `verdict` against a bar below it, which must FAIL, and against a bar above
it, which must PASS. The first is the arm that shows a bar can fail at all; the
second is the arm that shows the first is not a mechanism that fails whatever it
is handed. `main` refuses when either verdict is not the one declared here.

The low bar is under one kernel launch and the high bar is over the whole bed, so
neither is a measurement of anything and neither moves with the host.
"""
const CONTROLS = (
    (case = "reduction.pairwise_sum.$(first(SIZES))", bar = 1.0e-9, expect = Verdicts.FAIL()),
    (case = "reduction.pairwise_sum.$(first(SIZES))", bar = 1.0, expect = Verdicts.PASS()),
)

"""
    verdict(bar, seconds)

`REPORT` when `bar` is `nothing`, `PASS` when `seconds` is at or under it, and
`FAIL` otherwise (decision 0025's vocabulary).
"""
verdict(bar::Nothing, seconds::Real) = Verdicts.REPORT()
verdict(bar::Real, seconds::Real) = seconds <= bar ? Verdicts.PASS() : Verdicts.FAIL()

name(v::Verdicts.OracleVerdict) = string(nameof(typeof(v)))

"""
    batch_seconds(call, backend, calls)

Mean seconds per call over one batch of `calls` calls, the batch closed by one
`Backends.complete!` so a call that queues without reading anything back is
inside the number. A single call timed on its own does not reproduce; the batch
and why it is one are in notes/findings/2026-09-11-area-fraction-in-one-read.md.
"""
function batch_seconds(call, backend::Backends.Backend, calls::Integer)
    t0 = time_ns()
    for _ in 1:calls
        call()
    end
    Backends.complete!(backend)
    return (time_ns() - t0) / 1.0e9 / calls
end

"""
    measure(case, backend)

`case.batches` samples of `batch_seconds`, after `WARMUP_BATCHES` discarded ones.
"""
function measure(case::Case, backend::Backends.Backend)
    call = case.prepare(backend)
    for _ in 1:WARMUP_BATCHES
        batch_seconds(call, backend, case.calls)
    end
    return [batch_seconds(call, backend, case.calls) for _ in 1:case.batches]
end

median(v::AbstractVector) = (s = sort(v); n = length(s);
                             isodd(n) ? s[(n + 1) ÷ 2] : (s[n ÷ 2] + s[n ÷ 2 + 1]) / 2)

"""
    Occupancy

What held the card at one instant: the scheduler's count of allocated shares out
of the node's total, and the card's own report of its utilisation, the memory in
use and how many compute processes it carried, this one among them once it has
touched the card and not before. A field reads `-1` where its source did not
answer, the way `load1` reads `NaN`.

`utilisation_pc` is what the card reported at the instant of the reading, not an
average over the run.
"""
struct Occupancy
    shards_in_use::Int
    shards_total::Int
    utilisation_pc::Int
    memory_used_mib::Int
    processes::Int
    processes_other::Int
end

"""
    sole_holder(o, held)

`true` when the shares in use at reading `o` are exactly the `held` shares this
job was itself allocated, so no other job was sharing the card at that instant.
The card carries processes that never asked the scheduler for anything, so
`processes_other` is not zero on a quiet card and is not the test.
"""
sole_holder(o::Occupancy, held::Integer) = o.shards_in_use == held

"The scheduler's allocated and total share counts, from `qrun free`."
function shard_counts()
    try
        m = match(r"GPU shares:\s*(\d+)/(\d+)\s+in use", read(`qrun free`, String))
        m === nothing || return (parse(Int, m[1]), parse(Int, m[2]))
    catch
    end
    return (-1, -1)
end

"""
    held_shards()

The number of the card's shares this job was allocated, from `scontrol show job`
on `\$SLURM_JOB_ID`'s `TresPerNode=gres/shard:N` field. `-1` where `SLURM_JOB_ID`
is unset or the field does not parse, the way `shard_counts` reads `-1`.
"""
function held_shards()
    id = get(ENV, "SLURM_JOB_ID", "")
    isempty(id) && return -1
    try
        out = read(`scontrol show job $id`, String)
        m = match(r"TresPerNode=gres/shard:(\d+)", out)
        m === nothing || return parse(Int, m[1])
    catch
    end
    return -1
end

"""
    held_all_shards(held, total)

`true` when `held` and `total` are both positive and equal: this job was
allocated every share the node has. `false` when either is not positive, the
way `held_shards` and `shard_counts` read `-1` on failure; a failed reading of
one is not the same as a successful reading that found less than the other.
"""
held_all_shards(held::Integer, total::Integer) = held > 0 && held == total

"The card's utilisation in per cent, its memory in use in MiB, and the compute processes it carries."
function card_counts()
    try
        gpu = split(chomp(read(`nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader,nounits`, String)), ",")
        apps = filter(!isempty, split(chomp(read(`nvidia-smi --query-compute-apps=pid --format=csv,noheader`, String)), "\n"))
        mine = string(Base.Libc.getpid())
        return (parse(Int, strip(gpu[1])), parse(Int, strip(gpu[2])),
                length(apps), count(a -> strip(a) != mine, apps))
    catch
    end
    return (-1, -1, -1, -1)
end

"One `Occupancy` reading, taken now."
function occupancy()
    in_use, total = shard_counts()
    util, mem, procs, others = card_counts()
    return Occupancy(in_use, total, util, mem, procs, others)
end

table(o::Occupancy, held::Integer) = Dict{String, Any}(
    "shards_in_use" => o.shards_in_use,
    "shards_total" => o.shards_total,
    "utilisation_pc" => o.utilisation_pc,
    "memory_used_mib" => o.memory_used_mib,
    "processes" => o.processes,
    "processes_other" => o.processes_other,
    "sole_holder" => sole_holder(o, held),
)

host() = try chomp(read(`hostname`, String)) catch; "unknown" end
load1() = try parse(Float64, split(read("/proc/loadavg", String))[1]) catch; NaN end
card() = try chomp(read(`nvidia-smi --query-gpu=name --format=csv,noheader`, String)) catch; "unknown" end

"""
    process_age()

Seconds from this process's start to now, from `/proc/self/stat` and
`/proc/uptime`. Falls back to the load time this file timed, which is the part of
startup visible from inside, where `/proc` does not read.
"""
function process_age()
    try
        stat = read("/proc/self/stat", String)
        fields = split(stat[findlast(==(')'), stat) + 2:end])
        started = parse(Float64, fields[20]) / parse(Float64, chomp(read(`getconf CLK_TCK`, String)))
        return parse(Float64, split(read("/proc/uptime", String))[1]) - started
    catch
        return LOAD_SECONDS
    end
end

function main()
    isempty(CASES) && return println("no benchmark case is registered")

    backend = Backends.GPU(WORKGROUP)
    startup = process_age()
    held = held_shards()
    before = occupancy()

    held_all_shards(held, before.shards_total) ||
        Verdicts.refuse("benchmark occupancy", "bench/runbench.jl",
                        "the bed measured holding $held of $(before.shards_total) shares; " *
                        "a counted timing holds all four")

    readings = Occupancy[before]

    measured = Dict{String, Float64}()
    rows = Dict{String, Any}[]
    spent = 0.0
    for case in CASES
        samples = measure(case, backend)
        occ = occupancy()
        push!(readings, occ)
        spent += sum(samples) * case.calls
        measured[case.id] = minimum(samples)
        push!(rows, Dict{String, Any}(
            "id" => case.id,
            "sizes" => case.sizes,
            "calls" => case.calls,
            "batches" => case.batches,
            "min_us" => minimum(samples) * 1.0e6,
            "median_us" => median(samples) * 1.0e6,
            "max_us" => maximum(samples) * 1.0e6,
            "verdict" => name(verdict(case.bar, minimum(samples))),
            "occupancy" => table(occ, held),
        ))
    end

    TOML.print(stdout, Dict("bed" => Dict{String, Any}(
        "host" => host(),
        "card" => card(),
        "load" => load1(),
        "held_shards" => held,
        "held_all_shards" => held_all_shards(held, before.shards_total),
        "occupancy_before" => table(before, held),
        "julia" => string(VERSION),
        "startup_s" => startup,
        "load_s" => LOAD_SECONDS,
        "measuring_s" => spent,
        "workgroup" => WORKGROUP,
    ), "case" => rows); sorted = true)

    for control in CONTROLS
        got = verdict(control.bar, measured[control.case])
        got === control.expect ||
            Verdicts.refuse("benchmark control", "bench/runbench.jl",
                            "$(control.case) judged against a bar of $(control.bar) s per call " *
                            "read $(name(got)), not the declared $(name(control.expect))")
    end

    spent >= STARTUP_MULTIPLE * startup ||
        Verdicts.refuse("benchmark duration", "bench/runbench.jl",
                        "the bed measured for $(round(spent, digits = 2)) s, under the declared " *
                        "$STARTUP_MULTIPLE times its startup of $(round(startup, digits = 2)) s")

    failed = [r["id"] for r in rows if r["verdict"] == "FAIL"]
    if !isempty(failed)
        println(stderr, "over bar: ", join(failed, ", "))
        exit(1)
    end
    return nothing
end

(abspath(PROGRAM_FILE) == @__FILE__) && main()
