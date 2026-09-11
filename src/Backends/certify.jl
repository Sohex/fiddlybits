# The ulp-ensemble envelope and the single-precision certification: docs/plans/
# fiddlybits-52v.7-kernels.md, section "Certification", and decision 0029. The
# member count, the bracket it sits in, the miss rate it detects, the measured
# amplification distribution it is sized against, the smallest injected error
# the certification catches, and why the sampled ensemble cannot see a
# sub-population the size of decision 0005's twelve degree-five vertices, are in
# notes/findings/2026-09-11-ulp-ensemble-member-count.md.
#
# A case declares those sub-populations as its `Obligation` list; `certify`
# refuses a verdict that left one uncovered and `case_certification` runs the
# sampled arm and every obligation.

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
    Obligation(name, sites)

A named list of `(field, cell)` pairs of one case that a certification of that
case must cover exhaustively, beside the sampled ensemble rather than inside it.
`ENSEMBLE_MISS_RATE` is a relative size, so what it corresponds to in cells
grows with the case, and a sub-population fixed in count rather than in share
falls below it as the case refines: the twelve degree-five vertices decision
0005 puts at every level of an icosahedral mesh are the instance measured in
notes/findings/2026-09-11-ulp-ensemble-member-count.md, section "What the
ensemble cannot see".

`EnsembleCase` carries the obligations of a case, `certification` names the ones
a given scope leaves out, `certify` refuses to return a verdict while any is
left out, and `case_certification` runs every one of them.
"""
struct Obligation
    name::String
    sites::Vector{Tuple{Int,Int}}
end

"""
    EnsembleCase(name, fields, step, obligations)

A certification case: a name, the initial state as one `Float64` vector per
field, `step`, the naive serial reference path of decision 0027, called as
`step(state)` to advance `state` one step in place, and `obligations`, the named
sub-populations of the case's sites a certification must cover exhaustively.
`state` is a `Vector{Vector{T}}` shaped like `fields`, and `step` must accept
`T` of `Float32` and of `Float64`, because `envelope` runs it at `Float64` and
`certify` compares a candidate at both.

`obligations` has no default. A case whose support has no sub-population the
sampled draw is too coarse to reach declares `Obligation[]` at its construction
site, and the emptiness is then a statement the case makes rather than a value
this module supplied on its behalf.

Refuses at construction on an obligation that names no site, that names one of
its own sites twice, that repeats another obligation's name, or that names a
field or a cell the case does not have. Two different obligations naming the
same site is not refused: `exhaustive_envelope` and `divergence` run on one
obligation's site list at a time, so an overlap between two obligations never
sums or perturbs a site twice the way a repeat within one obligation's own
list does.
"""
struct EnsembleCase{S}
    name::String
    fields::Vector{Vector{Float64}}
    step::S
    obligations::Vector{Obligation}

    function EnsembleCase(name::AbstractString, fields::Vector{Vector{Float64}}, step::S,
                          obligations::Vector{Obligation}) where {S}
        check_obligations(name, fields, obligations)
        return new{S}(String(name), fields, step, obligations)
    end
end

"""
    check_obligations(name, fields, obligations)

Refuses, naming the case and the obligation, when an obligation names no site,
names one of its own sites twice, repeats an earlier obligation's name, or
names a field or a cell outside `fields`. Two different obligations naming the
same site is not refused.
"""
function check_obligations(name::AbstractString, fields::Vector{Vector{Float64}},
                           obligations::Vector{Obligation})
    seen = Set{String}()
    for ob in obligations
        isempty(ob.sites) &&
            refuse("certification obligation", "Backends.EnsembleCase",
                   "case $(name): obligation $(ob.name) names no site, and an obligation is " *
                   "the site list a certification of this case must cover exhaustively")
        ob.name in seen &&
            refuse("certification obligation", "Backends.EnsembleCase",
                   "case $(name): obligation $(ob.name) is declared twice, so naming it in a " *
                   "result would not say which of the two was covered")
        push!(seen, ob.name)
        own_sites = Set{Tuple{Int,Int}}()
        for (f, i) in ob.sites
            (f, i) in own_sites &&
                refuse("certification obligation", "Backends.EnsembleCase",
                       "case $(name): obligation $(ob.name) names field $f cell $i twice, so " *
                       "divergence would sum it twice and the exhaustive envelope would " *
                       "perturb it twice")
            push!(own_sites, (f, i))
            (1 <= f <= length(fields) && 1 <= i <= length(fields[f])) ||
                refuse("certification obligation", "Backends.EnsembleCase",
                       "case $(name): obligation $(ob.name) names field $f cell $i, which the " *
                       "case does not have")
        end
    end
    return nothing
end

"""
    Envelope(case, steps, members, sites, exhaustive, miss_rate, amplification,
             perturbed, scope)

The measured ulp-ensemble divergence envelope of one case. `amplification[s]`
is the largest divergence any member reached at step `s` divided by the
perturbation that member was given, so it is the growth of one unit of
perturbation over `s` steps and carries no precision of its own. `sites` is the
number of usable perturbation sites the case has, `members` the number the
ensemble used, `exhaustive` whether those are all of them, and `miss_rate` the
sub-population fraction `members` detects, which is zero when `exhaustive`.

`perturbed` is the `(field, cell)` pair each member perturbed, in the order the
members ran, and `scope` the pairs each member's divergence was scored over, or
`nothing` for every cell of the case. `covers` reads the two to decide whether
an envelope stands for an `Obligation`.
"""
struct Envelope
    case::String
    steps::Int
    members::Int
    sites::Int
    exhaustive::Bool
    miss_rate::Float64
    amplification::Vector{Float64}
    perturbed::Vector{Tuple{Int,Int}}
    scope::Union{Nothing,Vector{Tuple{Int,Int}}}
end

"""
    Certification(case, steps, initial, roundoff, observed, bound, verdict, omitted)

The per-step numbers behind one certification verdict. `observed[s]` is the
divergence between the candidate's single-precision and double-precision runs at
step `s`, `bound[s]` the envelope's admissible divergence at that step,
`initial` the divergence the initial state already carries from being rounded to
the candidate precision, and `roundoff` the per-step injection the caller
declared.

`omitted` names every `Obligation` of the case this certification's envelope and
scope do not cover. A `Certification` whose `omitted` is not empty carries a
`verdict` for the scope it ran on and not for the case, and `certify` refuses
rather than returning that verdict alone.
"""
struct Certification
    case::String
    steps::Int
    initial::Float64
    roundoff::Float64
    observed::Vector{Float64}
    bound::Vector{Float64}
    verdict::OracleVerdict
    omitted::Vector{String}
end

"""
    divergence(a, b; sites = nothing)

The sum over every field and every cell of `abs(a - b)`, at `Float64`. The one
norm rather than the largest element, because the quantity the envelope stands
for is the operator one norm of the case's propagator, whose value is the
largest over single-cell perturbations of exactly this sum.

`sites`, when given, restricts the sum to that list of `(field, cell)` pairs
rather than every cell: the same one norm, read over a named subset instead of
the whole case, for a certification scoped to that subset
(`Backends.exhaustive_envelope`, `Backends.certification`).
"""
function divergence(a::Vector{Vector{S}}, b::Vector{Vector{T}};
                    sites::Union{Nothing,Vector{Tuple{Int,Int}}} = nothing) where {S<:AbstractFloat,T<:AbstractFloat}
    total = zero(Float64)
    if sites === nothing
        for f in eachindex(a, b), i in eachindex(a[f], b[f])
            total += abs(Float64(a[f][i]) - Float64(b[f][i]))
        end
    else
        for (f, i) in sites
            total += abs(Float64(a[f][i]) - Float64(b[f][i]))
        end
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
    measure_envelope(case, steps, sites, all_sites, exhaustive, miss_rate, scope)

The machinery `envelope` and `exhaustive_envelope` share: `sites` is perturbed
in order, one member each, and `amplification[s]` is the largest of
`divergence(state, base[s]; sites = scope) / delta` any member reaches at step
`s`. `scope = nothing` scores divergence over every cell of `case`; `scope =
sites` restricts it to the sites named. The result is packaged as an
`Envelope` carrying `all_sites`, `exhaustive` and `miss_rate` as given, so the
two callers state what their own count and rate mean rather than this function
guessing.

Refuses, naming `case.name`, when a member's perturbation leaves its cell
unchanged, when the reference or a member trajectory leaves the finite range,
and when every member stayed at zero divergence at every step, which is a case
that does not propagate a one-ulp perturbation and so has no envelope.
"""
function measure_envelope(case::EnsembleCase, steps::Integer, sites::Vector{Tuple{Int,Int}},
                          all_sites::Int, exhaustive::Bool, miss_rate::Float64,
                          scope::Union{Nothing,Vector{Tuple{Int,Int}}})
    base = advance(case.step, [copy(v) for v in case.fields], steps,
                   case.name, "reference trajectory")
    amplification = zeros(Float64, steps)
    ulps = [field_ulp(v) for v in case.fields]

    for (f, i) in sites
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
            amplification[s] = max(amplification[s], divergence(state, base[s]; sites = scope) / delta)
        end
    end

    all(iszero, amplification) &&
        refuse("ulp-ensemble envelope", "Backends.envelope",
               "case $(case.name): $(length(sites)) members over $(all_sites) usable sites left " *
               "the state identical to the reference at every one of $(steps) steps, so the " *
               "case does not propagate a one-ulp perturbation and its envelope is not measurable")

    return Envelope(case.name, Int(steps), length(sites), all_sites, exhaustive, miss_rate,
                    amplification, copy(sites), scope === nothing ? nothing : copy(scope))
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

    members = min(ENSEMBLE_MEMBERS, length(sites))
    exhaustive = members == length(sites)
    order = bit_reversed_order(length(sites))
    chosen = [sites[order[t]] for t in 1:members]

    return measure_envelope(case, steps, chosen, length(sites), exhaustive,
                            exhaustive ? zero(Float64) : ENSEMBLE_MISS_RATE, nothing)
end

"""
    exhaustive_envelope(case, steps, sites)

The ulp-ensemble divergence envelope of `case` over `steps` steps, measured by
perturbing every one of `sites` rather than a sampled subset, and by scoring
each member's divergence over `sites` alone rather than every cell of `case`.
`members == sites == length(sites)` in the returned `Envelope`, `exhaustive` is
true, and `miss_rate` is zero, because `sites` is checked in full rather than
sampled.

Sits beside `envelope` rather than folding into it: `ENSEMBLE_MEMBERS` and the
miss rate `envelope` declares describe the sampled draw over every usable site
of `case`, and this function's own count is never added to them, so the
declared miss rate keeps meaning what it says. It exists for a named
sub-population the sampled draw is too coarse to reach, such as the twelve
degree-five vertices decision 0005 puts at every level of an icosahedral mesh,
whose relative share falls below the declared miss rate as the mesh refines
(notes/findings/2026-09-11-ulp-ensemble-member-count.md, section "What the
ensemble cannot see", whose noun for the twelve is corrected by
fiddlybits-52v.7.20).

Refuses when `steps` is not positive, when `sites` is empty, when a member's
perturbation leaves its cell unchanged, when the reference or a member
trajectory leaves the finite range, and when every member stayed at zero
divergence at every step.
"""
function exhaustive_envelope(case::EnsembleCase, steps::Integer, sites::Vector{Tuple{Int,Int}})
    steps > 0 ||
        refuse("ulp-ensemble envelope", "Backends.exhaustive_envelope",
               "case $(case.name): step count $(steps) is not positive, and an envelope is " *
               "a divergence as a function of step count")
    isempty(sites) &&
        refuse("ulp-ensemble perturbation site", "Backends.exhaustive_envelope",
               "case $(case.name): no site was named to check exhaustively")

    return measure_envelope(case, steps, sites, length(sites), true, zero(Float64), sites)
end

"""
    admissible(env, initial, roundoff)

The envelope's admissible divergence at each step: `amplification[s] * initial`
for the state the candidate precision already rounded before the first step,
plus `amplification[s - j] * roundoff` summed over the steps `j` at which the
candidate injects another roundoff, with an amplification of one at zero steps.
`roundoff` is the divergence one step of the candidate injects, in the same one
norm `divergence` returns.

The injected sum is one running accumulation over the step count, carried from
`s` to `s + 1` rather than re-summed at every step, in fixed ascending order:
`gain(0)` first, `gain(env.steps - 1)` last.
"""
function admissible(env::Envelope, initial::Real, roundoff::Real)
    gain(k::Int) = k == 0 ? one(Float64) : env.amplification[k]
    bound = zeros(Float64, env.steps)
    injected = zero(Float64)
    for s in 1:env.steps
        injected += gain(s - 1)
        carried = gain(s) * Float64(initial)
        bound[s] = fma(injected, Float64(roundoff), carried)
    end
    return bound
end

"""
    covers(env, sites, obligation)

Whether a certification run against `env` over the scope `sites` stands for
`obligation`: `env` perturbed exactly the obligation's sites, scored every
member over exactly those sites, and the certification is scoped to exactly
those sites. A sampled envelope perturbs a draw over the whole case and scores
over every cell, so it covers no obligation; an envelope scoped to a superset
scores the obligation's divergence diluted by the rest of that superset, so it
covers no obligation either.
"""
function covers(env::Envelope, sites::Union{Nothing,Vector{Tuple{Int,Int}}}, ob::Obligation)
    sites === nothing && return false
    env.scope === nothing && return false
    named = Set(ob.sites)
    return Set(env.perturbed) == named && Set(env.scope) == named && Set(sites) == named
end

"""
    omitted_obligations(case, env, sites)

The `name` of every `Obligation` of `case` that `covers` rejects for `env` and
`sites`, in the order the case declares them.
"""
omitted_obligations(case::EnsembleCase, env::Envelope,
                    sites::Union{Nothing,Vector{Tuple{Int,Int}}}) =
    String[ob.name for ob in case.obligations if !covers(env, sites, ob)]

"""
    certification(kernel, case, envelope; roundoff, sites = nothing)

The per-step numbers and the verdict of certifying `kernel` at `Float32` against
its own `Float64` run on `case`, over the envelope's step count.

`kernel` advances a `Vector{Vector{T}}` one step in place at `T` of `Float32`
and of `Float64`. `roundoff` is the divergence one step of `kernel` at `Float32`
injects, in the one norm `divergence` returns; it has no default, because the
term count and the magnitude it is built from are the caller's and the bound it
comes from has one definition in this tree, `Reductions.error_bound`, which sits
above this module and is read there rather than restated here.

`sites`, when given, scopes `initial` and every `observed[s]` to that list of
`(field, cell)` pairs (`divergence`'s own `sites` door) rather than every cell
of `case`: `roundoff` and `envelope` must then be the caller's own, measured or
declared over the same sites, or the comparison mixes two scopes. This is how
a certification is scoped to a named sub-population, such as the sites
`Backends.exhaustive_envelope` was measured over, rather than the whole case.

The result names, in `omitted`, every `Obligation` of `case` this envelope and
scope do not cover, so a record produced over the sampled sites alone says which
sub-populations it did not reach rather than reading as a certification of the
whole case.

Refuses when `envelope` was measured on another case, when `roundoff` is
negative, and when either trajectory leaves the finite range.
"""
function certification(kernel, case::EnsembleCase, env::Envelope; roundoff::Real,
                       sites::Union{Nothing,Vector{Tuple{Int,Int}}} = nothing)
    env.case == case.name ||
        refuse("certification envelope", "Backends.certification",
               "the envelope was measured on case $(env.case) and the certification is on " *
               "case $(case.name)")
    roundoff >= 0 ||
        refuse("certification roundoff", "Backends.certification",
               "case $(case.name): the declared per-step roundoff $(roundoff) is negative")

    wide = [copy(v) for v in case.fields]
    narrow = [Float32.(v) for v in case.fields]
    initial = divergence(narrow, wide; sites = sites)

    observed = zeros(Float64, env.steps)
    for s in 1:env.steps
        kernel(wide)
        check_finite(wide, s, case.name, "double-precision candidate trajectory")
        kernel(narrow)
        check_finite(narrow, s, case.name, "single-precision candidate trajectory")
        observed[s] = divergence(narrow, wide; sites = sites)
    end

    bound = admissible(env, initial, roundoff)
    verdict = all(observed .<= bound) ? PASS() : FAIL()
    return Certification(case.name, env.steps, initial, Float64(roundoff), observed, bound,
                         verdict, omitted_obligations(case, env, sites))
end

"""
    certify(kernel, case, envelope; roundoff, sites = nothing)

`PASS` when `kernel` at `Float32` stays inside `envelope` at every step of
`case` against its own `Float64` run, `FAIL` otherwise (decision 0029: a kernel
enters a production profile at `Float32` only when it does). An `OracleVerdict`
of decision 0025 and never a boolean; the per-step numbers behind it are
`certification`, including the `sites` scoping door it takes. A case whose
envelope could not be measured never reaches here, because `envelope` refuses.

Refuses when `envelope` and `sites` leave an `Obligation` of `case` uncovered,
naming each uncovered obligation and `case_certification`. This door returns a
verdict
and nothing else, so a verdict reached over part of a case's sites would be read
as a verdict on the case; a certification that did not cover the case is a
`Refusal` and never a verdict, the way an unmeasurable envelope is
(`NotEvaluable` is the loop vocabulary of decision 0009 and is not an
`OracleVerdict`).
"""
function certify(kernel, case::EnsembleCase, env::Envelope; roundoff::Real,
                 sites::Union{Nothing,Vector{Tuple{Int,Int}}} = nothing)
    omitted = omitted_obligations(case, env, sites)
    isempty(omitted) ||
        refuse("certification coverage", "Backends.certify",
               "case $(case.name): the envelope and the scope given leave " *
               "$(length(omitted)) of this case's obligations uncovered, " *
               "$(join(omitted, ", ")), each declared as a sub-population an ensemble of " *
               "$(ENSEMBLE_MEMBERS) members at a miss rate of $(ENSEMBLE_MISS_RATE) does " *
               "not reach, so this verdict would cover part of the case and be read as " *
               "covering the case; Backends.case_certification runs the sampled arm and " *
               "every obligation")
    return certification(kernel, case, env; roundoff = roundoff, sites = sites).verdict
end

"""
    CaseCertification(case, steps, sampled, obligated, obligations, verdict)

Every arm of one case's certification: `sampled` is the arm against the sampled
`envelope` over the whole case, `obligated` holds one arm against the
`exhaustive_envelope` of each `Obligation` the case declares, `obligations` the
names of those obligations in the order `obligated` holds them, and `verdict` is
`PASS` only when every arm is `PASS`.
"""
struct CaseCertification
    case::String
    steps::Int
    sampled::Certification
    obligated::Vector{Certification}
    obligations::Vector{String}
    verdict::OracleVerdict
end

"""
    case_certification(kernel, case, steps; roundoff)

The certification of `kernel` on every arm `case` declares: the sampled
`envelope` over the whole case, and the `exhaustive_envelope` of each
`Obligation`, each scored over its own sites through `certification`'s `sites`
door.

`roundoff` is called once per arm as `roundoff(scope)`, with `scope` `nothing`
for the sampled arm and the obligation's site list for an obligated arm, and
returns the divergence one step of `kernel` at `Float32` injects over that
scope, in the one norm `divergence` returns. It is a callable rather than a
number because the arms are scoped to different site counts and the bound it
comes from has one definition in this tree, `Reductions.error_bound`, which sits
above this module and is read there.

Taking `steps` rather than an envelope is what makes the arms this function's
own: a caller hands it a case and cannot hand it an envelope that skipped an
obligation.
"""
function case_certification(kernel, case::EnsembleCase, steps::Integer; roundoff)
    sampled_env = envelope(case, steps)
    sampled = certification(kernel, case, sampled_env; roundoff = roundoff(nothing))

    obligated = Certification[]
    for ob in case.obligations
        env = exhaustive_envelope(case, steps, ob.sites)
        push!(obligated, certification(kernel, case, env; roundoff = roundoff(ob.sites),
                                       sites = ob.sites))
    end

    passed = sampled.verdict == PASS() && all(c -> c.verdict == PASS(), obligated)
    return CaseCertification(case.name, Int(steps), sampled, obligated,
                             String[ob.name for ob in case.obligations],
                             passed ? PASS() : FAIL())
end

"""
    certify_case(kernel, case, steps; roundoff)

`PASS` when `kernel` at `Float32` stays inside the envelope of every arm
`case_certification` runs, `FAIL` when any arm is outside. An `OracleVerdict`
of decision 0025 and never a boolean; the per-arm numbers behind it are
`case_certification`.
"""
certify_case(kernel, case::EnsembleCase, steps::Integer; roundoff) =
    case_certification(kernel, case, steps; roundoff = roundoff).verdict
