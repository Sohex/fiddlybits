# FixedPointLoop, Ladder, the exit verdicts, the finalizer and the drift report:
# docs/plans/fiddlybits-52v.11-coupling.md, section "Loops as values"; decisions 0009,
# 0023 and 0042; REQ-SYS-007. A loop's criteria are held and evaluated in the order of
# their names, a ladder's loops in the order the ladder declares, and a run's records in
# the order of their instants, so the order criteria are given in reaches no result.

using ..Verdicts: LoopVerdict, Converged, Bracketed, Refused, NotEvaluable, BudgetExhausted,
                  REPORT
using ..Systems: Profile, ExitBracket, EXIT_NORMALISATIONS, declared_values
using ..Dispositions: Disposition, dimension
using ..Dimensions: DIMENSIONLESS, signature

# ---------------------------------------------------------------- event numbering

"""
    Numbering(; first, tier)

The sequence number the next event emitted from this file carries, `first` before any
is emitted, and the `tier` every such event's header names.
"""
mutable struct Numbering
    next::Int
    const tier::Symbol

    Numbering(::Checked, n::Int, t::Symbol) = new(n, t)
end

function Numbering(; kwargs...)
    site = "Coupling.Numbering"
    k, _ = read_keywords(site, values(kwargs), (:first, :tier), ())
    start = require_type("first", site, k.first, Int)
    tier = require_type("tier", site, k.tier, Symbol)
    return Numbering(Checked(), start, tier)
end

"""
    emit!(numbering, kind, instant, payload)

Hands an event of `kind` carrying `payload` to `Events.emit`, numbered
`numbering.next`, at `instant` on `numbering.tier`, from `COMPONENT`, then advances
`numbering.next` by one.
"""
function emit!(numbering::Numbering, kind::Events.Kind, instant::Float64, payload)
    Events.emit(Events.Event(kind, numbering.next, instant, numbering.tier, COMPONENT, payload))
    numbering.next += 1
    return nothing
end

"""
    require_instant(quantity, site, instant)

`Float64(instant)` when `instant` is a finite `Real`; refuses at `site` naming
`quantity` otherwise.
"""
function require_instant(quantity::AbstractString, site::AbstractString, instant)
    (instant isa Real && isfinite(instant)) || refuse(
        quantity, site, "$(repr(instant)) is not a finite instant in SI seconds")
    return Float64(instant)
end

# ---------------------------------------------------------------- monotonicity

"""
    Monotonicity

The declared monotonicity of a loop's map: `Isotone`, `Antitone` or `Unordered`.
`monotonicities()` enumerates it.
"""
abstract type Monotonicity end

"A map that preserves order."
struct Isotone <: Monotonicity end

"A map that reverses order; its exit is `Bracketed`, never `Converged`."
struct Antitone <: Monotonicity end

"A map that declares no order."
struct Unordered <: Monotonicity end

"Every `Monotonicity` singleton, in the order this file declares them."
monotonicities() = (Isotone(), Antitone(), Unordered())

"The verdict a loop of `monotonicity` returns when every criterion passes."
passing(::Antitone) = Bracketed()
passing(::Isotone) = Converged()
passing(::Unordered) = Converged()

# ---------------------------------------------------------------- samples and records

"""
    Sample(; value, level)

One scalar a loop's body measures: its `value`, a `Real` held as a `Float64`, and the
`level` of the hierarchy of the artifact it was measured on.
"""
struct Sample
    value::Float64
    level::Int

    Sample(::Checked, v::Float64, l::Int) = new(v, l)
end

function Sample(; kwargs...)
    site = "Coupling.Sample"
    k, _ = read_keywords(site, values(kwargs), (:value, :level), ())
    v = require_type("value", site, k.value, Real)
    level = require_level("level", site, k.level)
    return Sample(Checked(), Float64(v), level)
end

"""
    require_samples(site, samples)

`samples` when it is a `NamedTuple` every value of which is a `Sample`; refuses at
`site` otherwise.
"""
function require_samples(site::AbstractString, samples)
    samples isa NamedTuple || refuse(
        "samples", site, "a $(typeof(samples)) where a NamedTuple of Sample is required")
    for name in sort(collect(keys(samples)))
        samples[name] isa Sample || refuse(
            "samples", site, "$(name) is a $(typeof(samples[name])), not a Sample")
    end
    return samples
end

"""
    Iteration(; state, instant, samples)

What a loop's body returns: the `state` the next iteration starts from, the simulated
`instant` the iteration reached in SI seconds, and `samples`, a `NamedTuple` of
`Sample`s by name.
"""
struct Iteration{S,N<:NamedTuple}
    state::S
    instant::Float64
    samples::N

    Iteration{S,N}(::Checked, s, i, n) where {S,N} = new{S,N}(s, i, n)
end

function Iteration(; kwargs...)
    site = "Coupling.Iteration"
    k, _ = read_keywords(site, values(kwargs), (:state, :instant, :samples), ())
    instant = require_instant("instant", site, k.instant)
    samples = require_samples(site, k.samples)
    return Iteration{typeof(k.state),typeof(samples)}(Checked(), k.state, instant, samples)
end

"""
    Record(; loop, iteration, instant, samples)

One iteration of one loop as a run holds it: the `loop` by name, the `iteration`
counted from one, the `instant` in SI seconds, and the `samples` its body measured.
"""
struct Record{N<:NamedTuple}
    loop::Symbol
    iteration::Int
    instant::Float64
    samples::N

    Record{N}(::Checked, l, i, t, s) where {N} = new{N}(l, i, t, s)
end

function Record(; kwargs...)
    site = "Coupling.Record"
    k, _ = read_keywords(site, values(kwargs), (:loop, :iteration, :instant, :samples), ())
    loop = require_type("loop", site, k.loop, Symbol)
    iteration = require_type("iteration", site, k.iteration, Int)
    iteration >= 1 || refuse("iteration", site, "iteration $(iteration) is below one")
    instant = require_instant("instant", site, k.instant)
    samples = require_samples(site, k.samples)
    return Record{typeof(samples)}(Checked(), loop, iteration, instant, samples)
end

"""
    require_records(site, records)

`records` when it is a vector of `Record`s whose instants strictly increase; refuses
at `site`, naming the first record that does not follow the one before, otherwise.
"""
function require_records(site::AbstractString, records)
    records isa AbstractVector{<:Record} || refuse(
        "records", site, "a $(typeof(records)) where a vector of Record is required")
    for i in 2:length(records)
        a, b = records[i - 1], records[i]
        b.instant > a.instant || refuse(
            "records", site,
            "record $(b.iteration) of the loop $(b.loop) at $(b.instant) s does not follow " *
            "record $(a.iteration) of the loop $(a.loop) at $(a.instant) s")
    end
    return records
end

# ---------------------------------------------------------------- criteria

"""
    Criterion

One exit criterion of a loop: `Drift`, `Balance` or `Straddle`. Each names itself by
`criterion`, against the `ExitBracket` of its loop that holds its tolerance, and names
by `normalisation` the one of `Systems.EXIT_NORMALISATIONS` its statistic is in.
"""
abstract type Criterion end

"""
    require_criterion_names(site, k, names)

The values of the keywords `names` of `k`, each a `Symbol`, and `k.normalisation`, a
name in `Systems.EXIT_NORMALISATIONS`; refuses at `site` naming the keyword otherwise.
"""
function require_criterion_names(site::AbstractString, k::NamedTuple, names)
    for name in names
        require_type(String(name), site, k[name], Symbol)
    end
    k.normalisation in EXIT_NORMALISATIONS || refuse(
        "normalisation", site,
        "$(repr(k.normalisation)) is not one of $(join(EXIT_NORMALISATIONS, ", "))")
    return nothing
end

"""
    Drift(; criterion, quantity, rate, normalisation, span)

The magnitude of the least-squares slope, per second, of the sample `quantity` against
the instants of the last `span` records, divided by the sample `rate` at the last
record, which is the rate the tolerance multiplies in `normalisation`: the reservoir's
stock over its own relaxation time for `:stock_per_relaxation_time`. `span` is an `Int`
of two or more.
"""
struct Drift <: Criterion
    criterion::Symbol
    quantity::Symbol
    rate::Symbol
    normalisation::Symbol
    span::Int

    Drift(::Checked, c, q, r, n, s) = new(c, q, r, n, s)
end

function Drift(; kwargs...)
    site = "Coupling.Drift"
    k, _ = read_keywords(site, values(kwargs), (:criterion, :quantity, :rate, :normalisation, :span), ())
    require_criterion_names(site, k, (:criterion, :quantity, :rate))
    span = require_type("span", site, k.span, Int)
    span >= 2 || refuse("span", site, "a slope over $(span) records is undefined; the span is two or more")
    return Drift(Checked(), k.criterion, k.quantity, k.rate, k.normalisation, span)
end

"""
    Balance(; criterion, quantity, scale, normalisation, span)

The magnitude of the mean of the sample `quantity` over the last `span` records,
divided by the sample `scale` at the last record, which is the quantity the tolerance
is a fraction of in `normalisation`: the global-mean absorbed instellation for
`:absorbed_instellation`. `span` is an `Int` of one or more.
"""
struct Balance <: Criterion
    criterion::Symbol
    quantity::Symbol
    scale::Symbol
    normalisation::Symbol
    span::Int

    Balance(::Checked, c, q, s, n, w) = new(c, q, s, n, w)
end

function Balance(; kwargs...)
    site = "Coupling.Balance"
    k, _ = read_keywords(site, values(kwargs), (:criterion, :quantity, :scale, :normalisation, :span), ())
    require_criterion_names(site, k, (:criterion, :quantity, :scale))
    span = require_type("span", site, k.span, Int)
    span >= 1 || refuse("span", site, "a mean over $(span) records is undefined; the span is one or more")
    return Balance(Checked(), k.criterion, k.quantity, k.scale, k.normalisation, span)
end

"""
    Straddle(; criterion, quantity, overshoot, scale, normalisation)

The exit of an `Antitone` loop. The samples `quantity` at the last two records are the
arms of a bracket: its width is the magnitude of their difference, and its overshoot
the magnitude of the sample `overshoot` at the last record, each divided by the sample
`scale` at the last record. Its span is two.
"""
struct Straddle <: Criterion
    criterion::Symbol
    quantity::Symbol
    overshoot::Symbol
    scale::Symbol
    normalisation::Symbol

    Straddle(::Checked, c, q, o, s, n) = new(c, q, o, s, n)
end

function Straddle(; kwargs...)
    site = "Coupling.Straddle"
    k, _ = read_keywords(site, values(kwargs), (:criterion, :quantity, :overshoot, :scale, :normalisation), ())
    require_criterion_names(site, k, (:criterion, :quantity, :overshoot, :scale))
    return Straddle(Checked(), k.criterion, k.quantity, k.overshoot, k.scale, k.normalisation)
end

"The number of records, counted back from the last, that `c` reads."
span(c::Drift) = c.span
span(c::Balance) = c.span
span(::Straddle) = 2

"The names of the samples `c` reads at the last record, its divisor last."
last_reads(c::Drift) = (c.rate,)
last_reads(c::Balance) = (c.scale,)
last_reads(c::Straddle) = (c.overshoot, c.scale)

# ---------------------------------------------------------------- reports

"""
    CriterionReport

One criterion evaluated: a `DistanceReport`, a `BracketReport` or an
`UnevaluableReport`.
"""
abstract type CriterionReport end

"""
    DistanceReport

A `Drift` or `Balance` criterion evaluated: its `criterion` name; its `verdict`,
`Converged` when the dimensionless `statistic` is at most `tolerance` and `Refused`
otherwise; the statistic; and the tolerance.
"""
struct DistanceReport{V<:Union{Converged,Refused}} <: CriterionReport
    criterion::Symbol
    verdict::V
    statistic::Float64
    tolerance::Float64
end

"""
    BracketReport

A `Straddle` criterion evaluated: its `criterion` name; its `verdict`, `Bracketed` when
the dimensionless `width` and the dimensionless `overshoot` are each at most
`tolerance` and `Refused` otherwise; the width; the overshoot; and the tolerance.
"""
struct BracketReport{V<:Union{Bracketed,Refused}} <: CriterionReport
    criterion::Symbol
    verdict::V
    width::Float64
    overshoot::Float64
    tolerance::Float64
end

"""
    UnevaluableReport

A criterion the records cannot evaluate: its `criterion` name, the verdict
`NotEvaluable`, the `tolerance` it would have been judged against, and the `reason`,
which names what the records lack.
"""
struct UnevaluableReport <: CriterionReport
    criterion::Symbol
    verdict::NotEvaluable
    tolerance::Float64
    reason::String
end

"""
    ExitReport

A loop's exit predicate evaluated: the `loop` by name; its `verdict`; the number of
`records` it was evaluated over; the `CriterionReport` of each criterion in the order
of their names, empty when the records lie below the run floor; and the `reason`, which
names the criteria or the bound that decided the verdict.
"""
struct ExitReport{V<:LoopVerdict}
    loop::Symbol
    verdict::V
    records::Int
    criteria::Vector{CriterionReport}
    reason::String
end

# ---------------------------------------------------------------- the loop

"""
    FixedPointLoop

A loop of decision 0009 as a value. Build it with the keyword constructor, which has no
defaults:

    FixedPointLoop(; name, body, exit, monotonicity, cap, floor, level, profile)

`name` is a `Symbol`. `body(state, iteration)` returns the `Iteration` of that
iteration. `exit` is a tuple of one or more `Criterion`s with distinct names, every one
a `Straddle` when `monotonicity` is `Antitone` and none a `Straddle` otherwise, held in
the order of their names. `floor`, the run floor, is an `Int` of at least one and at
least the span of every criterion. `cap` is an `Int` of at least `floor`. `level` is the
level of the samples the exit reads during the run. `profile` is the `Systems.Profile`
whose `exit_brackets` hold, under the loop's name, one `ExitBracket` for each criterion,
in the criterion's normalisation, and no other.

Refuses, naming the keyword, each clause above; and a `profile` that is not a `Profile`,
naming an absolute tolerance by its dimension and a dimensionless one given beside the
profile as a second declaration.
"""
struct FixedPointLoop{B,M<:Monotonicity,C<:Tuple,E<:Tuple}
    name::Symbol
    body::B
    exit::C
    brackets::E
    monotonicity::M
    cap::Int
    floor::Int
    level::Int

    FixedPointLoop{B,M,C,E}(::Checked, n, b, x, e, m, c, f, l) where {B,M,C,E} =
        new{B,M,C,E}(n, b, x, e, m, c, f, l)
end

"""
    require_profile(site, given)

`given` when it is a `Systems.Profile`. Refuses at `site` otherwise: a disposition with
a dimension as an absolute tolerance, named by its dimension; a dimensionless
disposition, a `Real` or an `ExitBracket` as a tolerance declared beside the profile;
anything else by its type. A tuple is read member by member.
"""
function require_profile(site::AbstractString, given)
    given isa Profile && return given
    for d in (given isa Tuple ? given : (given,))
        d isa Disposition && dimension(d) !== DIMENSIONLESS && refuse(
            "profile", site,
            "an absolute tolerance in $(signature(dimension(d))) is refused; a loop's " *
            "tolerance is the dimensionless ExitBracket its Profile holds (decision 0023)")
        (d isa Disposition || d isa Real || d isa ExitBracket) && refuse(
            "profile", site,
            "a tolerance given as a $(nameof(typeof(d))) beside the Profile is a second " *
            "declaration; a loop's tolerance is the ExitBracket its Profile holds")
    end
    refuse("profile", site, "a $(typeof(given)) where a Systems.Profile is required")
end

"""
    bind_brackets(site, name, criteria, profile)

The `ExitBracket` of each of `criteria` under the loop `name` in `profile`, in the order
of `criteria`. Refuses at `site`: a profile whose exit brackets are absent; a criterion
with no bracket; a criterion whose normalisation differs from its bracket's; a bracket
under `name` that no criterion reads.
"""
function bind_brackets(site::AbstractString, name::Symbol, criteria::Tuple, profile::Profile)
    exits = profile.exit_brackets
    exits isa Tuple || refuse(
        "profile", site,
        "the profile $(profile.label) declares its exit brackets absent: $(exits.argument)")
    own = sort([e for e in exits if e.loop === name]; by = e -> e.criterion)
    bound = map(criteria) do c
        i = findfirst(e -> e.criterion === c.criterion, own)
        i === nothing && refuse(
            String(c.criterion), site,
            "the profile $(profile.label) holds no exit bracket for the criterion " *
            "$(c.criterion) of the loop $(name)")
        own[i].normalisation === c.normalisation || refuse(
            String(c.criterion), site,
            "the criterion $(c.criterion) of the loop $(name) is in $(c.normalisation), and " *
            "its exit bracket in $(own[i].normalisation)")
        own[i]
    end
    for e in own
        any(c -> c.criterion === e.criterion, criteria) || refuse(
            String(e.criterion), site,
            "the profile $(profile.label) holds an exit bracket for $(e.criterion) of the " *
            "loop $(name), which no criterion of the loop reads")
    end
    return bound
end

function FixedPointLoop(; kwargs...)
    site = "Coupling.FixedPointLoop"
    k, _ = read_keywords(site, values(kwargs),
                         (:name, :body, :exit, :monotonicity, :cap, :floor, :level, :profile), ())
    name = require_type("name", site, k.name, Symbol)
    profile = require_profile(site, k.profile)
    monotonicity = require_type("monotonicity", site, k.monotonicity, Monotonicity)
    given = k.exit
    (given isa Tuple && !isempty(given)) || refuse(
        "exit", site, "a $(typeof(given)) where a tuple of one or more criteria is required")
    antitone = monotonicity isa Antitone
    for c in given
        require_type("exit", site, c, Criterion)
        (c isa Straddle) == antitone || refuse(
            "exit", site,
            antitone ?
            "the $(nameof(typeof(c))) criterion $(c.criterion) returns Converged, and the " *
            "Antitone loop $(name) exits on a bracket; its criteria are Straddle" :
            "the Straddle criterion $(c.criterion) reads a bracket from alternate iterates, " *
            "and the $(nameof(typeof(monotonicity))) loop $(name) declares no alternation")
    end
    names = map(c -> c.criterion, given)
    allunique(names) || refuse("exit", site, "$(names) names one criterion twice")
    criteria = Tuple(sort(collect(given); by = c -> c.criterion))
    floor = require_type("floor", site, k.floor, Int)
    least = max(1, maximum(span, criteria))
    floor >= least || refuse(
        "floor", site,
        "the run floor $(floor) of the loop $(name) is below $(least), the most records a " *
        "criterion of it reads")
    cap = require_type("cap", site, k.cap, Int)
    cap >= floor || refuse(
        "cap", site, "the cap $(cap) of the loop $(name) is below its run floor $(floor)")
    level = require_level("level", site, k.level)
    brackets = bind_brackets(site, name, criteria, profile)
    return FixedPointLoop{typeof(k.body),typeof(monotonicity),typeof(criteria),typeof(brackets)}(
        Checked(), name, k.body, criteria, brackets, monotonicity, cap, floor, level)
end

"""
    tolerance(bracket)

The least value the tolerance of `bracket` declares, as a `Float64`.
"""
tolerance(bracket::ExitBracket) = Float64(minimum(declared_values(bracket.tolerance)))

"`true` when `n` records lie below the run floor of `loop`."
below_floor(loop::FixedPointLoop, n::Int) = n < loop.floor

# ---------------------------------------------------------------- evaluation

"""
    sample_value(record, name, level)

The value of the sample `name` of `record` when the record carries it, measured at
`level`, and finite; otherwise the text naming which of the three fails.
"""
function sample_value(record::Record, name::Symbol, level::Int)
    where_ = "record $(record.iteration) of the loop $(record.loop)"
    haskey(record.samples, name) || return "$(where_) carries no sample $(name)"
    s = record.samples[name]
    s.level == level || return "$(where_) carries $(name) measured at level $(s.level), and " *
        "the exit reads it at level $(level); no artifact at another level stands in for it"
    isfinite(s.value) || return "$(where_) carries $(name) as $(s.value), which is not finite"
    return s.value
end

"""
    least_squares_slope(instants, values)

`sum((t - tm) * (x - xm)) / sum((t - tm)^2)` over the pairs of `instants` and
`values`, `tm` and `xm` their means.
"""
function least_squares_slope(instants::AbstractVector{Float64}, values::AbstractVector{Float64})
    n = length(instants)
    tm = sum(instants) / n
    xm = sum(values) / n
    sxy = zero(Float64)
    stt = zero(Float64)
    for i in 1:n
        dt = instants[i] - tm
        dx = values[i] - xm
        p = dt * dx
        q = dt * dt
        sxy += p
        stt += q
    end
    return sxy / stt
end

"""
    distance(c, statistic, tol)

The `DistanceReport` of `c`: `Converged` when `statistic` is at most `tol`, `Refused`
otherwise.
"""
function distance(c::Union{Drift,Balance}, statistic::Float64, tol::Float64)
    statistic <= tol && return DistanceReport(c.criterion, Converged(), statistic, tol)
    return DistanceReport(c.criterion, Refused(), statistic, tol)
end

"""
    evaluate(c, bracket, records, level)

The `CriterionReport` of the criterion `c` against the tolerance of `bracket` over the
last `span(c)` of `records`, reading its samples at `level`: `UnevaluableReport` when
there are fewer records than that, when a record lacks a sample, carries it at another
level or carries a value that is not finite, or when the divisor is not above zero;
otherwise judged by its statistic.
"""
function evaluate(c::Criterion, bracket::ExitBracket, records::AbstractVector{<:Record}, level::Int)
    tol = tolerance(bracket)
    n = span(c)
    unevaluable(reason) = UnevaluableReport(c.criterion, NotEvaluable(), tol, reason)
    length(records) >= n || return unevaluable(
        "the criterion reads $(n) records and the run produced $(length(records))")
    window = records[(end - n + 1):end]
    values = Vector{Float64}(undef, n)
    for (i, r) in enumerate(window)
        v = sample_value(r, c.quantity, level)
        v isa String && return unevaluable(v)
        values[i] = v
    end
    reads = last_reads(c)
    found = Vector{Float64}(undef, length(reads))
    for (i, name) in enumerate(reads)
        v = sample_value(last(window), name, level)
        v isa String && return unevaluable(v)
        found[i] = v
    end
    divisor = last(found)
    divisor > 0 || return unevaluable(
        "the sample $(last(reads)) is $(divisor), and the statistic divides by a value above zero")
    return judge(c, [r.instant for r in window], values, divisor, found, tol)
end

"""
    judge(c, instants, values, divisor, found, tol)

The report of `c` over the `values` of its quantity at `instants`, `found` the values of
its `last_reads` and `divisor` the last of them, against `tol`: for a `Drift`, the
magnitude of `least_squares_slope` over the divisor; for a `Balance`, the magnitude of
the mean over the divisor; for a `Straddle`, the width and the overshoot, `Bracketed`
when each is at most `tol` and `Refused` otherwise.
"""
judge(c::Drift, instants, values, divisor, found, tol) =
    distance(c, abs(least_squares_slope(instants, values)) / divisor, tol)

judge(c::Balance, instants, values, divisor, found, tol) =
    distance(c, abs(sum(values) / length(values)) / divisor, tol)

function judge(c::Straddle, instants, values, divisor, found, tol)
    width = abs(values[2] - values[1]) / divisor
    overshoot = abs(found[1]) / divisor
    width <= tol && overshoot <= tol &&
        return BracketReport(c.criterion, Bracketed(), width, overshoot, tol)
    return BracketReport(c.criterion, Refused(), width, overshoot, tol)
end

"""
    aggregate(loop, n, reports)

The `ExitReport` of `loop` over `n` records from the reports of its criteria:
`NotEvaluable` when any criterion is, naming those; otherwise `Refused` when any
criterion is, naming those; otherwise `passing(loop.monotonicity)`.
"""
function aggregate(loop::FixedPointLoop, n::Int, reports::Vector{CriterionReport})
    unevaluable = [r.criterion for r in reports if r.verdict isa NotEvaluable]
    isempty(unevaluable) || return ExitReport(
        loop.name, NotEvaluable(), n, reports, "not evaluable: $(join(unevaluable, ", "))")
    refused = [r.criterion for r in reports if r.verdict isa Refused]
    isempty(refused) || return ExitReport(
        loop.name, Refused(), n, reports, "refused: $(join(refused, ", "))")
    verdict = passing(loop.monotonicity)
    return ExitReport(loop.name, verdict, n, reports,
                      "$(nameof(typeof(verdict))): $(join((r.criterion for r in reports), ", "))")
end

"The `(lo, hi)` a criterion report is judged against, as a verdict payload carries it."
bracket_of(r::CriterionReport) = (zero(Float64), r.tolerance)

"""
    emit_report!(numbering, instant, loop, report)

Emits `report` as `verdict` events at `instant`: one per `DistanceReport`, predicate
`loop.criterion`, its statistic; two per `BracketReport`, predicates
`loop.criterion.width` and `loop.criterion.overshoot`, each its own statistic; one per
`UnevaluableReport`, statistic `NaN`; each judged against `(0, tolerance)`; then one for
the loop, predicate its name, statistic the number of records, bracket `(floor, cap)`.
"""
function emit_report!(numbering::Numbering, instant::Float64, loop::FixedPointLoop,
                      report::ExitReport)
    verdict(predicate, v, s, b) = emit!(numbering, Events.Verdict(), instant,
        Events.VerdictPayload(predicate = predicate, verdict = v, statistic = s, bracket = b))
    for r in report.criteria
        p = "$(loop.name).$(r.criterion)"
        if r isa DistanceReport
            verdict(p, r.verdict, r.statistic, bracket_of(r))
        elseif r isa BracketReport
            verdict("$(p).width", r.verdict, r.width, bracket_of(r))
            verdict("$(p).overshoot", r.verdict, r.overshoot, bracket_of(r))
        else
            verdict(p, r.verdict, NaN, bracket_of(r))
        end
    end
    verdict(String(loop.name), report.verdict, Float64(report.records),
            (Float64(loop.floor), Float64(loop.cap)))
    return nothing
end

"""
    exit_verdict(loop; records, level, instant, numbering)

The exit predicate of `loop` over `records`, a vector of `Record`s in instant order,
reading its samples at `level`: `Refused` naming the run floor when there are fewer
records than it; otherwise each criterion evaluated by `evaluate` and the reports
combined by `aggregate`. The report is emitted by `emit_report!` at `instant`, numbered
by `numbering`, and returned. Refuses records whose instants do not strictly increase.
"""
function exit_verdict(loop::FixedPointLoop; kwargs...)
    site = "Coupling.exit_verdict"
    k, _ = read_keywords(site, values(kwargs), (:records, :level, :instant, :numbering), ())
    records = require_records(site, k.records)
    level = require_level("level", site, k.level)
    instant = require_instant("instant", site, k.instant)
    numbering = require_type("numbering", site, k.numbering, Numbering)
    n = length(records)
    report = if below_floor(loop, n)
        ExitReport(loop.name, Refused(), n, CriterionReport[],
                   "$(n) records lie below the run floor $(loop.floor) of the loop $(loop.name)")
    else
        reports = CriterionReport[evaluate(c, b, records, level)
                                  for (c, b) in zip(loop.exit, loop.brackets)]
        aggregate(loop, n, reports)
    end
    emit_report!(numbering, instant, loop, report)
    return report
end

# ---------------------------------------------------------------- running a loop

"""
    LoopOutcome

A loop run: the `state` its last iteration returned, its `ExitReport`, and its
`records` in iteration order.
"""
struct LoopOutcome{S}
    state::S
    report::ExitReport
    records::Vector{Record}
end

"""
    run_loop(loop; state, instant, numbering)

Runs `loop` from `state` at `instant`. At each iteration `i` from one to the cap,
`loop.body(state, i)` returns an `Iteration` whose instant lies after the one before,
and its `Record` is kept; from the run floor on, `exit_verdict` over the loop's records
at `loop.level` is evaluated, and the run returns at the first verdict other than
`Refused`. When the verdict at the cap is `Refused`, the run returns `BudgetExhausted`,
carrying the criteria of that last evaluation, emitted as a `verdict` event with the
number of records as its statistic and `(floor, cap)` as its bracket, and then as a
`budget` event. Every event is numbered by `numbering`. Refuses a body that returns
anything but an `Iteration`, and an instant that does not lie after the one before.
"""
function run_loop(loop::FixedPointLoop; kwargs...)
    site = "Coupling.run_loop"
    k, _ = read_keywords(site, values(kwargs), (:state, :instant, :numbering), ())
    instant = require_instant("instant", site, k.instant)
    numbering = require_type("numbering", site, k.numbering, Numbering)
    state = k.state
    records = Record[]
    judged_last = nothing
    for i in 1:loop.cap
        it = loop.body(state, i)
        it isa Iteration || refuse(
            String(loop.name), site,
            "the body of the loop $(loop.name) returned a $(typeof(it)) at iteration $(i), " *
            "where an Iteration is required")
        it.instant > instant || refuse(
            String(loop.name), site,
            "iteration $(i) of the loop $(loop.name) reached $(it.instant) s, which does not " *
            "lie after $(instant) s")
        state, instant = it.state, it.instant
        push!(records, Record{typeof(it.samples)}(Checked(), loop.name, i, instant, it.samples))
        below_floor(loop, i) && continue
        judged_last = exit_verdict(loop; records = records, level = loop.level,
                                   instant = instant, numbering = numbering)
        judged_last.verdict isa Refused || return LoopOutcome(state, judged_last, records)
    end
    report = ExitReport(loop.name, BudgetExhausted(), loop.cap, judged_last.criteria,
                        "the loop $(loop.name) reached its cap of $(loop.cap) iterations " *
                        "with its exit refused: $(judged_last.reason)")
    emit!(numbering, Events.Verdict(), instant,
          Events.VerdictPayload(predicate = String(loop.name), verdict = report.verdict,
                                statistic = Float64(loop.cap),
                                bracket = (Float64(loop.floor), Float64(loop.cap))))
    emit!(numbering, Events.Budget(), instant,
          Events.BudgetPayload(cap = Float64(loop.cap), which = "iterations of the loop $(loop.name)"))
    return LoopOutcome(state, report, records)
end

# ---------------------------------------------------------------- the ladder

"""
    OpenLoop(; name, argument, cost, scale)

A loop left open on purpose (REQ-SYS-007): its `name`, the `argument` for leaving it
open, a non-empty string, and the names of the samples `cost`, the measured cost of
leaving it open, and `scale`, the value the cost is reported as a fraction of.
"""
struct OpenLoop
    name::Symbol
    argument::String
    cost::Symbol
    scale::Symbol

    OpenLoop(::Checked, n, a, c, s) = new(n, a, c, s)
end

function OpenLoop(; kwargs...)
    site = "Coupling.OpenLoop"
    k, _ = read_keywords(site, values(kwargs), (:name, :argument, :cost, :scale), ())
    name = require_type("name", site, k.name, Symbol)
    (k.argument isa AbstractString && !isempty(k.argument)) || refuse(
        "argument", site, "the open loop $(name) carries no argument for being open")
    cost = require_type("cost", site, k.cost, Symbol)
    scale = require_type("scale", site, k.scale, Symbol)
    return OpenLoop(Checked(), name, String(k.argument), cost, scale)
end

"""
    Finalizer(; level)

The finalizer of a `Ladder`, which re-evaluates every loop's exit over the records of
the run with its samples read at `level`, the level of the operating run.
"""
struct Finalizer
    level::Int

    Finalizer(::Checked, l::Int) = new(l)
end

function Finalizer(; kwargs...)
    site = "Coupling.Finalizer"
    k, _ = read_keywords(site, values(kwargs), (:level,), ())
    return Finalizer(Checked(), require_level("level", site, k.level))
end

"""
    Ladder(; loops, open, finalizer)

The `loops` of one run in the order they run, a tuple of one or more `FixedPointLoop`s;
the loops left `open`, a tuple, empty or not, of `OpenLoop`s; and its `finalizer`, a
`Finalizer`. Every name is distinct. Refuses, naming the keyword, each clause.
"""
struct Ladder{L<:Tuple,O<:Tuple}
    loops::L
    open::O
    finalizer::Finalizer

    Ladder{L,O}(::Checked, l, o, f) where {L,O} = new{L,O}(l, o, f)
end

function Ladder(; kwargs...)
    site = "Coupling.Ladder"
    k, _ = read_keywords(site, values(kwargs), (:loops, :open, :finalizer), ())
    loops, open = k.loops, k.open
    (loops isa Tuple && !isempty(loops)) || refuse(
        "loops", site, "a $(typeof(loops)) where a tuple of one or more FixedPointLoop is required")
    foreach(l -> require_type("loops", site, l, FixedPointLoop), loops)
    open isa Tuple || refuse("open", site, "a $(typeof(open)) where a tuple of OpenLoop is required")
    foreach(o -> require_type("open", site, o, OpenLoop), open)
    repeated = first_repeated([map(l -> l.name, loops)..., map(o -> o.name, open)...])
    repeated === nothing || refuse(String(repeated), site, "the ladder names $(repeated) twice")
    finalizer = require_type("finalizer", site, k.finalizer, Finalizer)
    return Ladder{typeof(loops),typeof(open)}(Checked(), loops, open, finalizer)
end

"""
    OpenReport

An open loop at the final state: its `name`, its `argument`, its `cost` as a fraction
of its scale or `nothing` when the records do not measure it, and the `reason` naming
what they lack, empty when the cost is measured.
"""
struct OpenReport
    name::Symbol
    argument::String
    cost::Union{Float64,Nothing}
    reason::String
end

"""
    FinalReport

What the finalizer reports: the `ExitReport` of each loop and the `OpenReport` of each
open loop, each in ladder order. `passes`, `failed` and `not_evaluable` read it.
"""
struct FinalReport
    loops::Vector{ExitReport}
    open::Vector{OpenReport}
end

"The names of the loops whose re-evaluated verdict is `Refused`."
failed(r::FinalReport) = Symbol[e.loop for e in r.loops if e.verdict isa Refused]

"The names of the loops whose re-evaluated verdict is `NotEvaluable`, then of the open loops whose cost is not measured."
not_evaluable(r::FinalReport) =
    Symbol[[e.loop for e in r.loops if e.verdict isa NotEvaluable];
           [o.name for o in r.open if o.cost === nothing]]

"`true` when no loop of `r` is `failed` and none is `not_evaluable`."
passes(r::FinalReport) = isempty(failed(r)) && isempty(not_evaluable(r))

"""
    open_report(o, records, level)

The `OpenReport` of `o`: the magnitude of the sample `o.cost` over the sample `o.scale`,
both at the last record measured at `level`; `nothing` with the reason when there is no
record, a sample is missing, at another level or not finite, or the scale is not above
zero.
"""
function open_report(o::OpenLoop, records::AbstractVector{<:Record}, level::Int)
    isempty(records) && return OpenReport(o.name, o.argument, nothing, "the run produced no record")
    cost = sample_value(last(records), o.cost, level)
    cost isa String && return OpenReport(o.name, o.argument, nothing, cost)
    scale = sample_value(last(records), o.scale, level)
    scale isa String && return OpenReport(o.name, o.argument, nothing, scale)
    scale > 0 || return OpenReport(o.name, o.argument, nothing,
        "the sample $(o.scale) is $(scale), and the cost divides by a value above zero")
    return OpenReport(o.name, o.argument, abs(cost) / scale, "")
end

"""
    verify(ladder; records, instant, numbering)

The `FinalReport` of `ladder` over `records`, every record of the run in instant order,
at the final `instant`: `exit_verdict` of every loop in ladder order over all of
`records` with its samples read at the finalizer's level, and `open_report` of every
open loop in ladder order at that level, each emitted as a `verdict` event with
predicate `name.open`, verdict `NotEvaluable`, its cost or `NaN` as the statistic, and
`(NaN, NaN)` as the bracket. Calls no loop's body. Every event is numbered by
`numbering`.
"""
function verify(ladder::Ladder; kwargs...)
    site = "Coupling.verify"
    k, _ = read_keywords(site, values(kwargs), (:records, :instant, :numbering), ())
    records = require_records(site, k.records)
    instant = require_instant("instant", site, k.instant)
    numbering = require_type("numbering", site, k.numbering, Numbering)
    level = ladder.finalizer.level
    loops = ExitReport[exit_verdict(l; records = records, level = level, instant = instant,
                                    numbering = numbering) for l in ladder.loops]
    open = OpenReport[]
    for o in ladder.open
        r = open_report(o, records, level)
        push!(open, r)
        emit!(numbering, Events.Verdict(), instant,
              Events.VerdictPayload(predicate = "$(o.name).open", verdict = NotEvaluable(),
                                    statistic = r.cost === nothing ? NaN : r.cost,
                                    bracket = (NaN, NaN)))
    end
    return FinalReport(loops, open)
end

"""
    LadderOutcome

A ladder run: the `state` its last loop returned, the `LoopOutcome` of each loop that
ran in ladder order, and the finalizer's `FinalReport`.
"""
struct LadderOutcome{S}
    state::S
    loops::Vector{LoopOutcome}
    final::FinalReport
end

"""
    run_ladder(ladder; state, instant, numbering)

Runs the loops of `ladder` in order by `run_loop`, each from the state and the instant
the one before returned, stopping after the first whose verdict is neither `Converged`
nor `Bracketed`; then `verify` over every record the loops produced, at the instant of
the last. Every event is numbered by `numbering`.
"""
function run_ladder(ladder::Ladder; kwargs...)
    site = "Coupling.run_ladder"
    k, _ = read_keywords(site, values(kwargs), (:state, :instant, :numbering), ())
    instant = require_instant("instant", site, k.instant)
    numbering = require_type("numbering", site, k.numbering, Numbering)
    state = k.state
    records = Record[]
    outcomes = LoopOutcome[]
    for loop in ladder.loops
        o = run_loop(loop; state = state, instant = instant, numbering = numbering)
        push!(outcomes, o)
        append!(records, o.records)
        state, instant = o.state, last(o.records).instant
        o.report.verdict isa Union{Converged,Bracketed} || break
    end
    final = verify(ladder; records = records, instant = instant, numbering = numbering)
    return LadderOutcome(state, outcomes, final)
end

# ---------------------------------------------------------------- drift against its own scatter

"""
    unit_turn(word)

`2 pi` times the top 53 bits of the `UInt64` `word` over `2^53`: a phase in `[0, 2 pi)`.
"""
unit_turn(word::UInt64) = 2 * Float64(pi) * ldexp(Float64(word >> 11), -53)

"""
    fourier_tables(n)

`(c, s)`, each an `n` by `cld(n, 2) - 1` matrix, `c[t + 1, k] = cos(2 pi k t / n)` and
`s[t + 1, k] = sin(2 pi k t / n)`.
"""
function fourier_tables(n::Int)
    frequencies = cld(n, 2) - 1
    c = Matrix{Float64}(undef, n, frequencies)
    s = Matrix{Float64}(undef, n, frequencies)
    for k in 1:frequencies, t in 0:(n - 1)
        angle = 2 * Float64(pi) * (k * t) / n
        c[t + 1, k] = cos(angle)
        s[t + 1, k] = sin(angle)
    end
    return c, s
end

"""
    fourier_coefficients(values, c, s)

`(re, im)`, the real and imaginary parts of `sum(values[t + 1] * exp(-2 pi i k t / n))`
over `t` from 0 to `n - 1`, for each frequency `k` of the tables `c` and `s` of
`fourier_tables(n)`.
"""
function fourier_coefficients(values::AbstractVector{Float64}, c::Matrix{Float64}, s::Matrix{Float64})
    n, frequencies = size(c)
    re = zeros(Float64, frequencies)
    imag = zeros(Float64, frequencies)
    for k in 1:frequencies, t in 1:n
        xc = values[t] * c[t, k]
        xs = values[t] * s[t, k]
        re[k] += xc
        imag[k] -= xs
    end
    return re, imag
end

"""
    phase_randomised!(out, values, re, im, c, s, draw, offset)

`out` set to the surrogate of `values` (length `n`) of Schreiber and Schmitz (2000,
"Surrogate time series", arXiv:chao-dyn/9909037, section 4, eq. 8, p. 7): the
coefficient `re[k] + i im[k]` of each frequency `k` from 1 to `cld(n, 2) - 1` turned
through the phase `unit_turn(draw(offset + k))` and its conjugate frequency through the
opposite phase, the coefficients at frequency zero and, for even `n`, at `n / 2` those
of `values`, transformed back to the time domain. Returns `out`.
"""
function phase_randomised!(out::Vector{Float64}, values::AbstractVector{Float64},
                           re::Vector{Float64}, imag::Vector{Float64},
                           c::Matrix{Float64}, s::Matrix{Float64}, draw::F,
                           offset::Int) where {F}
    n, frequencies = size(c)
    mean = sum(values) / n
    fill!(out, mean)
    if iseven(n)
        nyquist = zero(Float64)
        for t in 1:n
            nyquist += isodd(t) ? values[t] : -values[t]
        end
        for t in 1:n
            out[t] += (isodd(t) ? nyquist : -nyquist) / n
        end
    end
    for k in 1:frequencies
        word = draw(offset + k)
        word isa UInt64 || refuse(
            "draw", "Coupling.phase_randomised!",
            "draw($(offset + k)) returned a $(typeof(word)), where a UInt64 is required")
        phase = unit_turn(word)
        cp, sp = cos(phase), sin(phase)
        rc, is_ = re[k] * cp, imag[k] * sp
        rs, ic = re[k] * sp, imag[k] * cp
        turned_re = rc - is_
        turned_im = rs + ic
        for t in 1:n
            a = turned_re * c[t, k]
            b = turned_im * s[t, k]
            term = a - b
            scaled = 2 * term / n
            out[t] += scaled
        end
    end
    return out
end

"""
    ScatterReport

`loop.drift_against_its_own_scatter` for one `Drift` criterion over one run: the `loop`
and `criterion` names; the criterion's `report`; the `bracket` of its tolerance as the
least and greatest values it declares; the observed `drift`, the magnitude of the
least-squares slope of the series; the `drifts` of its phase-randomised surrogates in
the order drawn; and `exceeding`, how many of those exceed `drift`. `fraction` reads
`exceeding` over the number of surrogates.
"""
struct ScatterReport
    loop::Symbol
    criterion::Symbol
    report::CriterionReport
    bracket::Tuple{Float64,Float64}
    drift::Float64
    drifts::Vector{Float64}
    exceeding::Int
end

"`exceeding` over the number of surrogates of `r`, as a `Rational{Int}`."
fraction(r::ScatterReport) = r.exceeding // length(r.drifts)

"""
    scatter_report(loop; criterion, records, level, surrogates, draw, instant, numbering)

The `ScatterReport` of the `Drift` criterion named `criterion` of `loop` over `records`,
reading its samples at `level`: its report by `evaluate`; the series of its quantity over
its span; and `surrogates` phase-randomised surrogates of that series by
`phase_randomised!`, the `j`-th reading its phases from `draw` at the counters
`(j - 1) * f + 1` to `j * f`, `f = cld(span, 2) - 1`, each drift taken against the
instants of the series. `draw(i)` is a `UInt64` for each counter. The fraction is
emitted as an `oracle` event, registry id `loop.drift_against_its_own_scatter`, verdict
`REPORT`, threshold `NaN`, at `instant`, numbered by `numbering`.

Returns the criterion's `UnevaluableReport` when `evaluate` cannot evaluate it, and an
`UnevaluableReport` naming the span when the span holds no frequency to randomise.
Refuses a `criterion` that names no `Drift` criterion of `loop`, and `surrogates` below
one.
"""
function scatter_report(loop::FixedPointLoop; kwargs...)
    site = "Coupling.scatter_report"
    k, _ = read_keywords(site, values(kwargs),
                         (:criterion, :records, :level, :surrogates, :draw, :instant, :numbering), ())
    name = require_type("criterion", site, k.criterion, Symbol)
    i = findfirst(c -> c.criterion === name, loop.exit)
    (i !== nothing && loop.exit[i] isa Drift) || refuse(
        String(name), site, "the loop $(loop.name) has no Drift criterion named $(name)")
    c, bracket = loop.exit[i], loop.brackets[i]
    records = require_records(site, k.records)
    level = require_level("level", site, k.level)
    surrogates = require_type("surrogates", site, k.surrogates, Int)
    surrogates >= 1 || refuse("surrogates", site, "$(surrogates) surrogates report no fraction")
    instant = require_instant("instant", site, k.instant)
    numbering = require_type("numbering", site, k.numbering, Numbering)
    report = evaluate(c, bracket, records, level)
    report isa UnevaluableReport && return report
    n = span(c)
    frequencies = cld(n, 2) - 1
    frequencies >= 1 || return UnevaluableReport(
        name, NotEvaluable(), report.tolerance,
        "a span of $(n) records holds no frequency to randomise")
    window = records[(end - n + 1):end]
    instants = [r.instant for r in window]
    series = [r.samples[c.quantity].value for r in window]
    drift = abs(least_squares_slope(instants, series))
    tables = fourier_tables(n)
    re, imag = fourier_coefficients(series, tables...)
    out = Vector{Float64}(undef, n)
    drifts = Vector{Float64}(undef, surrogates)
    for j in 1:surrogates
        phase_randomised!(out, series, re, imag, tables..., k.draw, (j - 1) * frequencies)
        drifts[j] = abs(least_squares_slope(instants, out))
    end
    exceeding = count(>(drift), drifts)
    declared = declared_values(bracket.tolerance)
    result = ScatterReport(loop.name, name, report,
                           (Float64(minimum(declared)), Float64(maximum(declared))),
                           drift, drifts, exceeding)
    emit!(numbering, Events.Oracle(), instant,
          Events.OraclePayload(registry_id = "loop.drift_against_its_own_scatter",
                               verdict = REPORT(), statistic = Float64(fraction(result)),
                               threshold = NaN))
    return result
end
