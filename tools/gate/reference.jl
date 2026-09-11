#!/usr/bin/env julia
# The reference case of decision 0029: a deterministic artifact whose hash is tracked,
# and which a commit may not move without a mechanism line.
#
#   julia --project tools/gate/reference.jl          print the hash the code produces
#   julia --project tools/gate/reference.jl --check   compare it with bench/reference.toml

using SHA
using TOML
using Fiddlybits: Orbit, Backends

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const RECORD = joinpath(ROOT, "bench", "reference.toml")

"""
    kepler_sweep()

The eccentric anomaly over a fixed grid of mean anomalies and eccentricities. A fixed
grid, a fixed order and no reduction, so the value is a function of the arithmetic and
nothing else.
"""
function kepler_sweep()
    backend = Backends.CPU(1)
    out = Float64[]
    for e in (0.0, 0.5, 0.9, 0.99, 0.999, 1 - 1e-6, 1 - 1e-9, 1 - 1e-12)
        for i in 0:255
            M = -pi + 2pi * i / 256
            push!(out, Orbit.eccentric_anomaly(M, e, backend))
        end
    end
    return out
end

const CASES = Dict("kepler_sweep" => kepler_sweep)

"The hash over the IEEE bit patterns of the case's output, as the artifact keys are taken."
function state_hash(case::AbstractString)
    haskey(CASES, case) || error("no such reference case: " * case)
    values = CASES[case]()
    ctx = SHA2_256_CTX()
    for v in values
        update!(ctx, reinterpret(UInt8, [v]))
    end
    return bytes2hex(digest!(ctx))
end

record() = TOML.parsefile(RECORD)

function main(args)
    rec = record()
    case = rec["case"]["name"]
    computed = state_hash(case)
    if "--check" in args
        recorded = rec["case"]["hash"]
        if computed == recorded
            println("reference: ", case, " matches")
            return 0
        end
        println(stderr, "reference: ", case, " does not match its record")
        println(stderr, "  recorded: ", recorded)
        println(stderr, "  computed: ", computed)
        println(stderr, "The record is stale. Recompute it, and carry an answers: line ",
                        "in the commit message saying what moved the answer.")
        return 1
    end
    println(computed)
    return 0
end

(abspath(PROGRAM_FILE) == @__FILE__) && exit(main(ARGS))
