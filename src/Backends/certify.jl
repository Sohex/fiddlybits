# The ulp-ensemble envelope and the single-precision certification: docs/plans/
# fiddlybits-52v.7-kernels.md, section "Certification", and decision 0029. The
# member count, the bracket it sits in, the miss rate it detects, the measured
# amplification distribution it is sized against and the smallest injected error
# the certification catches are in
# notes/findings/2026-09-11-ulp-ensemble-member-count.md.

using ..Verdicts: FAIL, OracleVerdict, PASS, refuse

"""
    ENSEMBLE_MISS_RATE_RECIPROCAL

The reciprocal of the sub-population fraction the ensemble is sized to find: one
site in `ENSEMBLE_MISS_RATE_RECIPROCAL` of a case's usable sites. Bracketed in
`[16, 4096]`, pushed down by the envelope a short ensemble measures, which
refuses a correct kernel, and pushed up by a cost linear in the member count.
Swept over the bracket in
notes/findings/2026-09-11-ulp-ensemble-member-count.md.
"""
const ENSEMBLE_MISS_RATE_RECIPROCAL = 256

"""
    ENSEMBLE_CONFIDENCE_RECIPROCAL

The reciprocal of the probability `ENSEMBLE_MEMBERS` is allowed to miss a
sub-population of relative size `1 / ENSEMBLE_MISS_RATE_RECIPROCAL`. Bracketed
in `[5, 1000]`, pushed down by the same mechanism
`ENSEMBLE_MISS_RATE_RECIPROCAL` carries and pushed up by a cost the member count
carries only as the logarithm of this reciprocal. Swept over the bracket in
notes/findings/2026-09-11-ulp-ensemble-member-count.md.
"""
const ENSEMBLE_CONFIDENCE_RECIPROCAL = 20

"""
    ensemble_members(miss_rate_reciprocal, confidence_reciprocal)

The smallest member count `m` with `(1 - p)^m <= alpha` for
`p = 1 / miss_rate_reciprocal` and `alpha = 1 / confidence_reciprocal`, counted
by multiplying `1 - p` in until it is at or below `alpha`. `(1 - p)^m` is the
probability that `m` sites drawn with replacement from the site population all
miss a sub-population of relative size `p`; the ensemble draws without
replacement, for which that probability is smaller, so the count this rule
returns is an upper bound on the count the without-replacement draw needs.
"""
function ensemble_members(miss_rate_reciprocal::Integer, confidence_reciprocal::Integer)
    survives = 1 - 1 / miss_rate_reciprocal
    alpha = 1 / confidence_reciprocal
    missed = one(Float64)
    m = 0
    while missed > alpha
        missed *= survives
        m += 1
    end
    return m
end

"""
    ENSEMBLE_MEMBERS

The declared ensemble member count. Derived: `ensemble_members` of
`ENSEMBLE_MISS_RATE_RECIPROCAL` and `ENSEMBLE_CONFIDENCE_RECIPROCAL`, and of
nothing else. A case with fewer usable sites than this is run exhaustively and
`Envelope.exhaustive` says so.
"""
const ENSEMBLE_MEMBERS = ensemble_members(ENSEMBLE_MISS_RATE_RECIPROCAL,
                                          ENSEMBLE_CONFIDENCE_RECIPROCAL)

"""
    detectable_miss_rate(members, confidence_reciprocal)

`1 - alpha^(1 / members)` for `alpha = 1 / confidence_reciprocal`: the smallest
sub-population fraction an ensemble of `members` sites holds at least one site
of with probability at least `1 - alpha`. The inverse of `ensemble_members`, and
the number the registry rows this envelope serves state.
"""
detectable_miss_rate(members::Integer, confidence_reciprocal::Integer) =
    1 - (1 / confidence_reciprocal)^(1 / members)

"""
    ENSEMBLE_MISS_RATE

`detectable_miss_rate` at `ENSEMBLE_MEMBERS` and
`ENSEMBLE_CONFIDENCE_RECIPROCAL`. Derived.
"""
const ENSEMBLE_MISS_RATE = detectable_miss_rate(ENSEMBLE_MEMBERS,
                                                ENSEMBLE_CONFIDENCE_RECIPROCAL)

"""
    EnsembleCase(name, fields, step)

A certification case: a name, the initial state as one `Float64` vector per
field, and `step`, the naive serial reference path of decision 0027, called as
`step(state)` to advance `state` one step in place. `state` is a
`Vector{Vector{T}}` shaped like `fields`, and `step` must accept `T` of
`Float32` and of `Float64`, because `envelope` runs it at `Float64` and
`certify` compares a candidate at both.
"""
struct EnsembleCase{S}
    name::String
    fields::Vector{Vector{Float64}}
    step::S
end

"""
    Envelope(case, steps, members, sites, exhaustive, miss_rate, amplification)

The measured ulp-ensemble divergence envelope of one case. `amplification[s]`
is the largest divergence any member reached at step `s` divided by the
perturbation that member was given, so it is the growth of one unit of
perturbation over `s` steps and carries no precision of its own. `sites` is the
number of usable perturbation sites the case has, `members` the number the
ensemble used, `exhaustive` whether those are all of them, and `miss_rate` the
sub-population fraction `members` detects, which is zero when `exhaustive`.
"""
struct Envelope
    case::String
    steps::Int
    members::Int
    sites::Int
    exhaustive::Bool
    miss_rate::Float64
    amplification::Vector{Float64}
end

"""
    Certification(case, steps, initial, roundoff, observed, bound, verdict)

The per-step numbers behind one certification verdict. `observed[s]` is the
divergence between the candidate's single-precision and double-precision runs at
step `s`, `bound[s]` the envelope's admissible divergence at that step,
`initial` the divergence the initial state already carries from being rounded to
the candidate precision, and `roundoff` the per-step injection the caller
declared.
"""
struct Certification
    case::String
    steps::Int
    initial::Float64
    roundoff::Float64
    observed::Vector{Float64}
    bound::Vector{Float64}
    verdict::OracleVerdict
end

"""
    divergence(a, b)

The sum over every field and every cell of `abs(a - b)`, at `Float64`. The one
norm rather than the largest element, because the quantity the envelope stands
for is the operator one norm of the case's propagator, whose value is the
largest over single-cell perturbations of exactly this sum.
"""
function divergence(a::Vector{Vector{S}}, b::Vector{Vector{T}}) where {S<:AbstractFloat,T<:AbstractFloat}
    total = zero(Float64)
    for f in eachindex(a, b), i in eachindex(a[f], b[f])
        total += abs(Float64(a[f][i]) - Float64(b[f][i]))
    end
    return total
end

"""
    field_ulp(field)

One ulp of `field`'s own scale: `nextfloat(m) - m` for `m` the largest absolute
value in `field`. Zero when that scale is zero, not finite or subnormal, which
is how `usable_sites` finds a field no member can perturb.

This is the size every member's perturbation has, rather than one ulp of the
value in the cell the member perturbs. The two readings of decision 0029's
phrase were measured against each other in
notes/findings/2026-09-11-ulp-ensemble-member-count.md.
"""
function field_ulp(field::Vector{Float64})
    isempty(field) && return zero(Float64)
    m = maximum(abs, field)
    (isfinite(m) && !iszero(m) && !issubnormal(m)) || return zero(Float64)
    return nextfloat(m) - m
end

"""
    usable_sites(case)

Every `(field, cell)` of `case` that a member can perturb, in field-then-cell
order: every cell holding a finite value in a field whose `field_ulp` is
positive.
"""
function usable_sites(case::EnsembleCase)
    sites = Tuple{Int,Int}[]
    for f in eachindex(case.fields)
        iszero(field_ulp(case.fields[f])) && continue
        for i in eachindex(case.fields[f])
            isfinite(case.fields[f][i]) && push!(sites, (f, i))
        end
    end
    return sites
end

"""
    bit_reversed_order(n)

`1:n` ordered by the reversal of the bit pattern of the zero-based index, the
radix-2 van der Corput order. The first `m` entries are spread over `1:n` for
every `m`, which is what lets an ensemble that stops at `ENSEMBLE_MEMBERS` cover
the site list rather than its first several hundred entries. The order is a
function of `n` alone, so an envelope measured twice on one case is the same
envelope, and the miss rate `detectable_miss_rate` reports is a statement about
a sub-population whose position in the site list is not correlated with this
order.
"""
bit_reversed_order(n::Integer) = sortperm([bitreverse(UInt64(j)) for j in 0:(n - 1)])

"""
    advance(step, state, steps, name, what)

`state` advanced `steps` steps by `step`, returning one copy of the state per
step. Refuses at the step and the field and cell where a value leaves the finite
range, naming `what` and the case `name`, because a trajectory that leaves the
finite range has no divergence to measure.
"""
function advance(step, state::Vector{Vector{T}}, steps::Integer,
                 name::AbstractString, what::AbstractString) where {T<:AbstractFloat}
    trace = Vector{Vector{Vector{T}}}(undef, steps)
    for s in 1:steps
        step(state)
        check_finite(state, s, name, what)
        trace[s] = [copy(v) for v in state]
    end
    return trace
end

"""
    check_finite(state, s, name, what)

Refuses naming the field, the cell and the step at which `state` holds a value
that is not finite.
"""
function check_finite(state::Vector{Vector{T}}, s::Integer,
                      name::AbstractString, what::AbstractString) where {T<:AbstractFloat}
    for f in eachindex(state), i in eachindex(state[f])
        isfinite(state[f][i]) ||
            refuse("ulp-ensemble divergence",
                   "Backends.advance",
                   "case $(name): the $(what) holds $(state[f][i]) at field $f cell $i " *
                   "after step $s, so the divergence at step $s and after it cannot be measured")
    end
    return nothing
end

"""
    envelope(case, steps)

The ulp-ensemble divergence envelope of `case` over `steps` steps: a CPU
ensemble at `Float64` whose members each add one `field_ulp` to one cell of one
field, run against the unperturbed reference trajectory, with `amplification[s]`
the largest divergence any member reached at step `s` divided by the
perturbation it was given (decision 0029).

The members are `min(ENSEMBLE_MEMBERS, length(usable_sites(case)))` sites taken
in `bit_reversed_order`, and the envelope carries the miss rate that count
detects.

Refuses, naming what could not be measured, when `steps` is not positive, when
the case has no usable perturbation site, when a member's perturbation leaves
its cell unchanged, when the reference or a member trajectory leaves the finite
range, and when every member stayed at zero divergence at every step, which is a
case that does not propagate a one-ulp perturbation and so has no envelope. A
case that cannot be measured is a `Refusal` and never a verdict: `NotEvaluable`
belongs to the loop vocabulary of decision 0009, and a certification that could
not be evaluated must not be readable as a pass.
"""
function envelope(case::EnsembleCase, steps::Integer)
    steps > 0 ||
        refuse("ulp-ensemble envelope", "Backends.envelope",
               "case $(case.name): step count $(steps) is not positive, and an envelope is " *
               "a divergence as a function of step count")
    sites = usable_sites(case)
    isempty(sites) &&
        refuse("ulp-ensemble perturbation site", "Backends.envelope",
               "case $(case.name): no field holds a finite nonzero normal scale, so no member " *
               "can be given one ulp of a field to perturb a cell with")

    base = advance(case.step, [copy(v) for v in case.fields], steps,
                   case.name, "reference trajectory")

    members = min(ENSEMBLE_MEMBERS, length(sites))
    exhaustive = members == length(sites)
    order = bit_reversed_order(length(sites))
    amplification = zeros(Float64, steps)

    ulps = [field_ulp(v) for v in case.fields]

    for t in 1:members
        f, i = sites[order[t]]
        state = [copy(v) for v in case.fields]
        v = state[f][i]
        state[f][i] = v + ulps[f]
        delta = state[f][i] - v
        delta > 0 ||
            refuse("ulp-ensemble perturbation", "Backends.envelope",
                   "case $(case.name): adding one ulp of field $f, $(ulps[f]), to the " *
                   "$(v) at cell $i left the value unchanged, so that member has no " *
                   "perturbation to divide its divergence by")
        for s in 1:steps
            case.step(state)
            check_finite(state, s, case.name, "member trajectory at field $f cell $i")
            amplification[s] = max(amplification[s], divergence(state, base[s]) / delta)
        end
    end

    all(iszero, amplification) &&
        refuse("ulp-ensemble envelope", "Backends.envelope",
               "case $(case.name): $(members) members over $(length(sites)) usable sites left " *
               "the state identical to the reference at every one of $(steps) steps, so the " *
               "case does not propagate a one-ulp perturbation and its envelope is not measurable")

    return Envelope(case.name, Int(steps), members, length(sites), exhaustive,
                    exhaustive ? zero(Float64) : ENSEMBLE_MISS_RATE, amplification)
end

"""
    admissible(env, initial, roundoff)

The envelope's admissible divergence at each step: `amplification[s] * initial`
for the state the candidate precision already rounded before the first step,
plus `amplification[s - j] * roundoff` summed over the steps `j` at which the
candidate injects another roundoff, with an amplification of one at zero steps.
`roundoff` is the divergence one step of the candidate injects, in the same one
norm `divergence` returns.
"""
function admissible(env::Envelope, initial::Real, roundoff::Real)
    gain(k::Int) = k == 0 ? one(Float64) : env.amplification[k]
    bound = zeros(Float64, env.steps)
    for s in 1:env.steps
        carried = gain(s) * Float64(initial)
        injected = zero(Float64)
        for j in 1:s
            injected += gain(s - j)
        end
        bound[s] = carried + injected * Float64(roundoff)
    end
    return bound
end

"""
    certification(kernel, case, envelope; roundoff)

The per-step numbers and the verdict of certifying `kernel` at `Float32` against
its own `Float64` run on `case`, over the envelope's step count.

`kernel` advances a `Vector{Vector{T}}` one step in place at `T` of `Float32`
and of `Float64`. `roundoff` is the divergence one step of `kernel` at `Float32`
injects, in the one norm `divergence` returns; it has no default, because the
term count and the magnitude it is built from are the caller's and the bound it
comes from has one definition in this tree, `Reductions.error_bound`, which sits
above this module and is read there rather than restated here.

Refuses when `envelope` was measured on another case, when `roundoff` is
negative, and when either trajectory leaves the finite range.
"""
function certification(kernel, case::EnsembleCase, env::Envelope; roundoff::Real)
    env.case == case.name ||
        refuse("certification envelope", "Backends.certification",
               "the envelope was measured on case $(env.case) and the certification is on " *
               "case $(case.name)")
    roundoff >= 0 ||
        refuse("certification roundoff", "Backends.certification",
               "case $(case.name): the declared per-step roundoff $(roundoff) is negative")

    wide = [copy(v) for v in case.fields]
    narrow = [Float32.(v) for v in case.fields]
    initial = divergence(narrow, wide)

    observed = zeros(Float64, env.steps)
    for s in 1:env.steps
        kernel(wide)
        check_finite(wide, s, case.name, "double-precision candidate trajectory")
        kernel(narrow)
        check_finite(narrow, s, case.name, "single-precision candidate trajectory")
        observed[s] = divergence(narrow, wide)
    end

    bound = admissible(env, initial, roundoff)
    verdict = all(observed .<= bound) ? PASS() : FAIL()
    return Certification(case.name, env.steps, initial, Float64(roundoff), observed, bound, verdict)
end

"""
    certify(kernel, case, envelope; roundoff)

`PASS` when `kernel` at `Float32` stays inside `envelope` at every step of
`case` against its own `Float64` run, `FAIL` otherwise (decision 0029: a kernel
enters a production profile at `Float32` only when it does). An `OracleVerdict`
of decision 0025 and never a boolean; the per-step numbers behind it are
`certification`. A case whose envelope could not be measured never reaches here,
because `envelope` refuses.
"""
certify(kernel, case::EnsembleCase, env::Envelope; roundoff::Real) =
    certification(kernel, case, env; roundoff = roundoff).verdict
