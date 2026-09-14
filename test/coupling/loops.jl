using Test
using Fiddlybits: Coupling, Systems, Events, Verdicts, Dimensions, Provenance

# coupling.loop_finalizer, loop.exit_criteria_on_a_known_surrogate and
# loop.drift_against_its_own_scatter: docs/plans/fiddlybits-52v.11-coupling.md, section
# "Loops as values".

isdefined(@__MODULE__, :SystemFixtures) ||
    include(joinpath(@__DIR__, "..", "system", "fixtures.jl"))

module LoopFixtures

using Fiddlybits: Coupling, Systems, Events, Verdicts, Dimensions, Provenance
using SHA: sha256
import ..SystemFixtures as SF

const ONE = Dimensions.DIMENSIONLESS
const TIME = Dimensions.TIME

"An `ExitBracket` of `loop` and `criterion` in `normalisation` with `tolerance`."
exit_bracket(loop, criterion, normalisation, tolerance) = Systems.ExitBracket(
    loop = loop, criterion = criterion, normalisation = normalisation, tolerance = tolerance)

"A `Systems.Absent` carrying `text`."
absent(text) = Systems.Absent(argument = text)

"A profile on `system` holding `brackets` as its exit brackets and every other setting absent."
profile(system, brackets) = Systems.Profile(
    label = :loops, system = system, components = absent("the loop fixture has no component"),
    radiation = absent("the loop fixture has no radiation"), fast_precision = Float64,
    slow_tier = absent("the loop fixture has no slow tier"),
    memory_ceiling = SF.irreducible(1024, ONE),
    write_ceiling = SF.irreducible(256, ONE),
    store_writers = SF.irreducible(4, ONE),
    settle_interval = SF.irreducible(3600.0, TIME),
    daily_fallback_interval = absent("the loop fixture has no vegetation tier"),
    exit_brackets = brackets)

"The low, value and high of the fixture's balance tolerance."
balance_tolerance() = SF.bracket(1.0e-3, 1.0e-4, 1.0e-2, ONE)

"The low, value and high of the fixture's drift tolerance."
drift_tolerance() = SF.bracket(1.0e-2, 5.0e-3, 2.0e-2, ONE)

"The tolerance of the fixture's antitone map, a sixteenth."
map_tolerance() = SF.irreducible(1 / 16, ONE)

"Every exit bracket the fixture's loops read."
function fixture_brackets()
    b, d = balance_tolerance(), drift_tolerance()
    return (exit_bracket(:climate, :toa_balance, :absorbed_instellation, b),
            exit_bracket(:climate, :deep_drift, :stock_per_relaxation_time, d),
            exit_bracket(:climate_window, :deep_drift, :stock_per_relaxation_time, d),
            exit_bracket(:climate_alternating, :toa_straddle, :absorbed_instellation, b),
            exit_bracket(:tail, :deep_drift, :stock_per_relaxation_time, d),
            exit_bracket(:null, :deep_drift, :stock_per_relaxation_time, d),
            exit_bracket(:map, :alternation, :aa_scatter, map_tolerance()),
            exit_bracket(:constant, :level_drift, :aa_scatter, map_tolerance()),
            exit_bracket(:constant_alternating, :alternation, :aa_scatter, map_tolerance()))
end

"The fixture profile on the system fixture."
fixture_profile() = profile(SF.system(Float64), fixture_brackets())

"What calling `f` raises, or `nothing`."
caught(f) = try
    f()
    nothing
catch err
    err
end

"`true` when `e` is a `Verdicts.Refusal` of `quantity` whose reason contains `text`."
refused(e, quantity, text) =
    e isa Verdicts.Refusal && e.quantity == quantity && occursin(text, e.reason)

"`(f(), events)`, `events` every event emitted while `f` ran."
function recording(f)
    events = Events.Event[]
    Events.sink!(e -> push!(events, e))
    try
        return f(), events
    finally
        Events.sink!(Events.noop_sink)
    end
end

"A `Coupling.Numbering` from one on the slow tier."
numbering() = Coupling.Numbering(first = 1, tier = :slow)

"A body calling `body` and adding one to `calls` at each call."
counted(body, calls::Base.RefValue{Int}) = (state, i) -> (calls[] += 1; body(state, i))

# ---------------------------------------------------------------- the antitone map

"""
    alternating(; damping, fixed, start, level)

A body whose iteration `i` reaches the instant `i` and measures at `level`: `x`, the
iterate `fixed + start * (-damping)^i` of the map `x -> fixed - damping * (x - fixed)`;
`offset`, `x - fixed`; and `scatter`, one.
"""
alternating(; damping, fixed, start, level) = (state, i) -> begin
    offset = start * (-damping)^i
    Coupling.Iteration(state = state, instant = i, samples = (
        x = Coupling.Sample(value = fixed + offset, level = level),
        offset = Coupling.Sample(value = offset, level = level),
        scatter = Coupling.Sample(value = 1, level = level)))
end

"The `Straddle` of the antitone map on `x`, overshoot `offset`, scale `scatter`."
alternation() = Coupling.Straddle(criterion = :alternation, quantity = :x, overshoot = :offset,
                                  scale = :scatter, normalisation = :aa_scatter)

"The `Drift` of `x` over `span` records, rate `scatter`."
level_drift(span) = Coupling.Drift(criterion = :level_drift, quantity = :x, rate = :scatter,
                                   normalisation = :aa_scatter, span = span)

"A `FixedPointLoop` with every keyword given."
fixed_point_loop(; name, body, exit, monotonicity, cap, floor, level, profile) =
    Coupling.FixedPointLoop(name = name, body = body, exit = exit, monotonicity = monotonicity,
                            cap = cap, floor = floor, level = level, profile = profile)

"The antitone loop `:map` on `alternating` at level 5."
map_loop(p; damping, start = 4 // 1, cap = 20) = fixed_point_loop(
    name = :map, body = alternating(damping = damping, fixed = 8 // 1, start = start, level = 5),
    exit = (alternation(),), monotonicity = Coupling.Antitone(), cap = cap, floor = 2, level = 5,
    profile = p)

# ---------------------------------------------------------------- the two-reservoir surrogate

"""
    TwoBox

The fixture's linear two-reservoir energy balance, `C T' = S + a sin(w t) - A - B T -
g (T - D)` and `Cd D' = g (T - D)`, its coefficients as fields; `two_box()` builds it.
"""
struct TwoBox
    C::Float64
    Cd::Float64
    B::Float64
    g::Float64
    S::Float64
    A::Float64
    a::Float64
    w::Float64
end

two_box() = TwoBox(1.0, 1.0e4, 2.0, 1.0, 240.0, 200.0, 1.0e-3, 2 * pi / 4)

"`(S - A) / B`, the temperature of both reservoirs at the fixed point of `m` with `a = 0`."
fixed_point(m::TwoBox) = (m.S - m.A) / m.B

"The rows of the matrix of `m`'s linear system in `(T, D)`."
matrix(m::TwoBox) = ((-(m.B + m.g) / m.C, m.g / m.C), (m.g / m.Cd, -m.g / m.Cd))

"The eigenvalues `(fast, slow)` of `matrix(m)`, from the characteristic quadratic."
function eigenvalues(m::TwoBox)
    (a11, a12), (a21, a22) = matrix(m)
    half = (a11 + a22) / 2
    root = sqrt(half^2 - (a11 * a22 - a12 * a21))
    return half - root, half + root
end

"The eigenvector `(a12, mu - a11)` of `matrix(m)` for the eigenvalue `mu`."
eigenvector(m::TwoBox, mu) = (matrix(m)[1][2], mu - matrix(m)[1][1])

"`-1 / slow`, the relaxation time of the slow mode of `m`."
slow_relaxation_time(m::TwoBox) = -1 / eigenvalues(m)[2]

"""
    periodic_response(m)

`(ZT, ZD)`, the solution of `(i w I - matrix(m)) Z = (a / C, 0)`: the periodic orbit of
the forcing is `(T, D) = fixed_point(m) + imag(Z exp(i w t))`.
"""
function periodic_response(m::TwoBox)
    (a11, a12), (a21, a22) = matrix(m)
    iw = im * m.w
    det = (iw - a11) * (iw - a22) - a12 * a21
    f = m.a / m.C
    return (iw - a22) * f / det, a21 * f / det
end

"""
    trajectory(m, kind, t0)

A function of the instant `t` returning `(T, D, N)`, `N = S + forcing - A - B T` the
imbalance, on the trajectory `kind` of `m`: `:settled`, the fast mode of amplitude ten
started sixty fast relaxation times before `t0`, no periodic forcing; `:crawling`, the
slow mode with `D - D*` equal to `-D* / 2` at `t0`, no periodic forcing; `:oscillating`,
the periodic orbit of the forcing.
"""
function trajectory(m::TwoBox, kind::Symbol, t0::Float64)
    star = fixed_point(m)
    fast, slow = eigenvalues(m)
    if kind === :oscillating
        ZT, ZD = periodic_response(m)
        return t -> begin
            e = exp(im * m.w * t)
            T = star + imag(ZT * e)
            (T, star + imag(ZD * e), m.S + m.a * sin(m.w * t) - m.A - m.B * T)
        end
    end
    mu, amplitude, start = kind === :settled ? (fast, 10.0, t0 + 60 / fast) :
                           (slow, -star / 2 / eigenvector(m, slow)[2], t0)
    v = eigenvector(m, mu)
    return t -> begin
        e = amplitude * exp(mu * (t - start))
        T = star + v[1] * e
        (T, star + v[2] * e, m.S - m.A - m.B * T)
    end
end

"""
    surrogate_body(m, kind; spacing, span, level, extra)

A body whose state is an instant and whose iteration reaches that instant plus
`spacing`, measuring at `level` on `trajectory(m, kind, spacing)`: `imbalance`, `N`;
`imbalance_offset`, `N`, whose fixed-point value is zero; `absorbed`, `S`; `deep`, `D`;
`deep_rate`, `D*` over the slow relaxation time; `window_rate`, `D*` over `(span - 1)
spacing`; and the samples of `extra`, a `NamedTuple` of values.
"""
function surrogate_body(m::TwoBox, kind::Symbol; spacing, span, level, extra = (;))
    path = trajectory(m, kind, Float64(spacing))
    star, tau = fixed_point(m), slow_relaxation_time(m)
    sample(v) = Coupling.Sample(value = v, level = level)
    return (state, i) -> begin
        t = state + spacing
        T, D, N = path(t)
        samples = (imbalance = sample(N), imbalance_offset = sample(N), absorbed = sample(m.S),
                   deep = sample(D), deep_rate = sample(star / tau),
                   window_rate = sample(star / ((span - 1) * spacing)))
        Coupling.Iteration(state = t, instant = t,
                           samples = merge(samples, map(sample, extra)))
    end
end

"The `Balance` of `imbalance` over `absorbed` across `span` records."
toa_balance(span) = Coupling.Balance(criterion = :toa_balance, quantity = :imbalance,
                                     scale = :absorbed, normalisation = :absorbed_instellation,
                                     span = span)

"The `Drift` of `deep` over the sample `rate` across `span` records."
deep_drift(rate, span) = Coupling.Drift(criterion = :deep_drift, quantity = :deep, rate = rate,
                                        normalisation = :stock_per_relaxation_time, span = span)

"The `Straddle` of `imbalance`, overshoot `imbalance_offset`, scale `absorbed`."
toa_straddle() = Coupling.Straddle(criterion = :toa_straddle, quantity = :imbalance,
                                   overshoot = :imbalance_offset, scale = :absorbed,
                                   normalisation = :absorbed_instellation)

"""
    climate_loop(p, kind; name, exit, level, cap, body)

An `Unordered` loop on the surrogate trajectory `kind` spaced a quarter second, span 32,
floor 32, measured and read at `level`.
"""
climate_loop(p, kind; name = :climate, exit = (toa_balance(32), deep_drift(:deep_rate, 32)),
             level = 5, cap = 64, extra = (;),
             body = surrogate_body(two_box(), kind; spacing = 0.25, span = 32, level = level,
                                   extra = extra)) =
    fixed_point_loop(name = name, body = body, exit = exit, monotonicity = Coupling.Unordered(),
                     cap = cap, floor = 32, level = level, profile = p)

"The instants of `records`."
instants(records) = [r.instant for r in records]

# ---------------------------------------------------------------- the scatter report

"The 32 bytes of the SHA-256 digest of `text`."
digest(text) = Tuple(sha256(text))

"A `draw` reading the first word of `Provenance.philox_draw` at draw index `i`."
philox_words(seed, text, cell, process) =
    i -> Provenance.philox_draw(seed, digest(text), cell, process, 0, i)[1]

"""
    null_records(seed, cell, n; trend)

`n` records of the loop `:null` at instants `1` to `n`, level 5: `deep` the value
`sum(cos(2 pi k t / n + p_k) / k for k in 1:(cld(n, 2) - 1)) + trend * t` at `t = 0, ...,
n - 1`, `p_k = 2 pi u_k / 2^64` from `philox_draw(seed, ..., cell, 1, 0, k)`; `deep_rate`
one.
"""
function null_records(seed, cell, n; trend)
    words = philox_words(seed, "loop fixture null series", cell, 1)
    phases = [2 * pi * ldexp(Float64(words(k) >> 11), -53) for k in 1:(cld(n, 2) - 1)]
    return [Coupling.Record(loop = :null, iteration = t + 1, instant = t + 1, samples = (
                deep = Coupling.Sample(value = sum(cos(2 * pi * k * t / n + phases[k]) / k
                                                   for k in eachindex(phases)) + trend * t,
                                       level = 5),
                deep_rate = Coupling.Sample(value = 1, level = 5)))
            for t in 0:(n - 1)]
end

"""
    binomial_rejects(count, trials, p, false_alarm)

`true` when `P(X <= count)` or `P(X >= count)` is at most `false_alarm / 2`, `X`
binomial over `trials` with success probability `p`, computed in `Rational{BigInt}`.
"""
function binomial_rejects(count, trials, p, false_alarm)
    q = Rational{BigInt}(p)
    pmf(j) = binomial(big(trials), big(j)) * q^j * (1 - q)^(trials - j)
    half = Rational{BigInt}(false_alarm) / 2
    return sum(pmf, 0:count) <= half || sum(pmf, count:trials) <= half
end

end # module LoopFixtures

import .LoopFixtures as LF

@testset "coupling.loop_finalizer" begin
    p = LF.fixture_profile()

    @testset "an exit predicate returns a LoopVerdict, never a boolean and never a number" begin
        loop = LF.map_loop(p; damping = 1 // 2)
        outcome = Coupling.run_loop(loop; state = nothing, instant = 0, numbering = LF.numbering())
        report = Coupling.exit_verdict(loop; records = outcome.records, level = 5, instant = 20,
                                       numbering = LF.numbering())
        @test report isa Coupling.ExitReport
        @test report.verdict isa Verdicts.LoopVerdict
        @test all(r -> r.verdict isa Verdicts.LoopVerdict, report.criteria)
        @test fieldtype(Coupling.ExitReport, :verdict) === Verdicts.LoopVerdict
        @test all(T -> fieldtype(T, :verdict) <: Verdicts.LoopVerdict,
                  (Coupling.DistanceReport, Coupling.BracketReport, Coupling.UnevaluableReport))
    end

    @testset "an Antitone loop never returns Converged and reports width and overshoot separately" begin
        loop = LF.map_loop(p; damping = 1 // 2)
        (outcome, events) = LF.recording(() ->
            Coupling.run_loop(loop; state = nothing, instant = 0, numbering = LF.numbering()))
        @test outcome.report.verdict === Verdicts.Bracketed()
        @test outcome.report.records == 8
        bracket = only(outcome.report.criteria)
        @test bracket isa Coupling.BracketReport
        @test bracket.width == 3 / 64
        @test bracket.overshoot == 1 / 64
        @test [e.payload.statistic for e in events if e.payload.predicate == "map.alternation.width"][end] == 3 / 64
        @test [e.payload.statistic for e in events if e.payload.predicate == "map.alternation.overshoot"][end] == 1 / 64
        @test !any(e -> e.payload.verdict === Verdicts.Converged(), events)

        verdicts = [Coupling.run_loop(LF.map_loop(p; damping = d, start = s); state = nothing, instant = 0,
                                      numbering = LF.numbering()).report.verdict
                    for d in (1 // 4, 1 // 2, 3 // 4, 1 // 1), s in (4 // 1, -4 // 1, 0 // 1)]
        @test !any(==(Verdicts.Converged()), verdicts)
        @test count(==(Verdicts.Bracketed()), verdicts) == 10
        @test count(==(Verdicts.BudgetExhausted()), verdicts) == 2

        constant = LF.alternating(damping = 0 // 1, fixed = 8 // 1, start = 0 // 1, level = 5)
        antitone = LF.fixed_point_loop(name = :constant_alternating, body = constant,
                                       exit = (LF.alternation(),), monotonicity = Coupling.Antitone(),
                                       cap = 9, floor = 2, level = 5, profile = p)
        unordered = LF.fixed_point_loop(name = :constant, body = constant, exit = (LF.level_drift(2),),
                                        monotonicity = Coupling.Unordered(), cap = 9, floor = 2,
                                        level = 5, profile = p)
        run(loop) = Coupling.run_loop(loop; state = nothing, instant = 0, numbering = LF.numbering()).report
        @test run(antitone).verdict === Verdicts.Bracketed()
        @test run(unordered).verdict === Verdicts.Converged()

        @test LF.refused(LF.caught(() -> LF.fixed_point_loop(
            name = :constant, body = constant, exit = (LF.level_drift(2),),
            monotonicity = Coupling.Antitone(), cap = 9, floor = 2, level = 5, profile = p)),
            "exit", "the Antitone loop constant exits on a bracket")
        @test LF.refused(LF.caught(() -> LF.fixed_point_loop(
            name = :constant_alternating, body = constant, exit = (LF.alternation(),),
            monotonicity = Coupling.Isotone(), cap = 9, floor = 2, level = 5, profile = p)),
            "exit", "declares no alternation")
        @test_throws TypeError Coupling.BracketReport{Verdicts.Converged}
        @test_throws MethodError Coupling.BracketReport(:alternation, Verdicts.Converged(), 0.0, 0.0, 1.0)
    end

    @testset "a bracket whose overshoot exceeds the tolerance is refused where its width alone would pass" begin
        loop = LF.map_loop(p; damping = 1 // 2)
        arm(i, offset) = Coupling.Record(loop = :map, iteration = i, instant = i, samples = (
            x = Coupling.Sample(value = 8 + offset, level = 5),
            offset = Coupling.Sample(value = offset, level = 5),
            scatter = Coupling.Sample(value = 1, level = 5)))
        report = Coupling.exit_verdict(loop; records = [arm(1, 5 // 16), arm(2, 6 // 16)], level = 5,
                                       instant = 2, numbering = LF.numbering())
        b = only(report.criteria)
        @test b.width == 1 / 16
        @test b.width <= b.tolerance
        @test b.overshoot == 6 / 16
        @test report.verdict === Verdicts.Refused()
        straddling = Coupling.exit_verdict(loop; records = [arm(1, -1 // 32), arm(2, 1 // 32)], level = 5,
                                           instant = 2, numbering = LF.numbering())
        @test straddling.verdict === Verdicts.Bracketed()
    end

    @testset "a cap returns BudgetExhausted, which is not a pass" begin
        loop = LF.map_loop(p; damping = 1 // 1, cap = 10)
        (outcome, events) = LF.recording(() ->
            Coupling.run_loop(loop; state = nothing, instant = 0, numbering = LF.numbering()))
        @test outcome.report.verdict === Verdicts.BudgetExhausted()
        @test outcome.report.records == 10
        @test length(outcome.records) == 10
        @test only(outcome.report.criteria).verdict === Verdicts.Refused()
        @test events[end - 1].payload.verdict === Verdicts.BudgetExhausted()
        @test events[end].header.kind === Events.Budget()
        @test events[end].payload.cap == 10
        @test [e.header.sequence for e in events] == collect(1:length(events))

        ladder = Coupling.Ladder(loops = (loop, LF.climate_loop(p, :settled)), open = (),
                                 finalizer = Coupling.Finalizer(level = 5))
        run = Coupling.run_ladder(ladder; state = nothing, instant = 0, numbering = LF.numbering())
        @test length(run.loops) == 1
        @test !Coupling.passes(run.final)
        @test :map in Coupling.failed(run.final)
    end

    @testset "a loop cannot exit before its run floor" begin
        calls = Ref(0)
        constant = LF.alternating(damping = 0 // 1, fixed = 8 // 1, start = 0 // 1, level = 5)
        loop = LF.fixed_point_loop(name = :constant, body = LF.counted(constant, calls),
                                   exit = (LF.level_drift(2),), monotonicity = Coupling.Unordered(),
                                   cap = 9, floor = 5, level = 5, profile = p)
        (outcome, events) = LF.recording(() ->
            Coupling.run_loop(loop; state = nothing, instant = 0, numbering = LF.numbering()))
        @test outcome.report.verdict === Verdicts.Converged()
        @test outcome.report.records == 5
        @test calls[] == 5
        @test first(e.payload.statistic for e in events if e.payload.predicate == "constant") == 5
        early = Coupling.exit_verdict(loop; records = outcome.records[1:4], level = 5, instant = 4,
                                      numbering = LF.numbering())
        @test early.verdict === Verdicts.Refused()
        @test occursin("4 records lie below the run floor 5", early.reason)
        build(; floor, cap) = LF.caught(() -> LF.fixed_point_loop(
            name = :climate, body = constant, exit = (LF.toa_balance(32), LF.deep_drift(:deep_rate, 32)),
            monotonicity = Coupling.Unordered(), cap = cap, floor = floor, level = 5, profile = p))
        @test LF.refused(build(floor = 31, cap = 64), "floor", "is below 32")
        @test LF.refused(build(floor = 32, cap = 31), "cap", "below its run floor 32")
        @test build(floor = 32, cap = 32) === nothing
    end

    @testset "an absolute tolerance is refused at construction" begin
        flux = Dimensions.Dim{1,0,-3,0,0}()
        @test LF.refused(LF.caught(() -> LF.exit_bracket(:climate, :toa_balance, :absorbed_instellation,
                                                          LF.SF.irreducible(1.0, flux))),
                         "tolerance", "an absolute tolerance")
        build(tolerances) = LF.caught(() -> LF.climate_loop(tolerances, :settled))
        @test LF.refused(build(LF.SF.irreducible(1.0, flux)), "profile", "an absolute tolerance in")
        @test LF.refused(build((LF.SF.irreducible(1.0, Dimensions.TIME),)), "profile", "an absolute tolerance in")
        @test LF.refused(build(LF.SF.irreducible(1.0e-3, LF.ONE)), "profile", "second declaration")
        @test LF.refused(build(1.0e-3), "profile", "second declaration")
        @test LF.refused(build(LF.fixture_brackets()), "profile", "second declaration")
        @test build(p) === nothing

        system = LF.SF.system(Float64)
        @test LF.refused(build(LF.profile(system, LF.absent("no loop in this profile"))), "profile",
                         "declares its exit brackets absent")
        only_balance = (LF.exit_bracket(:climate, :toa_balance, :absorbed_instellation, LF.balance_tolerance()),)
        @test LF.refused(build(LF.profile(system, only_balance)), "deep_drift", "holds no exit bracket")
        renormalised = (only_balance..., LF.exit_bracket(:climate, :deep_drift, :aa_scatter, LF.drift_tolerance()))
        @test LF.refused(build(LF.profile(system, renormalised)), "deep_drift", "and its exit bracket in aa_scatter")
        stray = (LF.fixture_brackets()..., LF.exit_bracket(:climate, :sea_ice_drift, :aa_scatter, LF.drift_tolerance()))
        @test LF.refused(build(LF.profile(system, stray)), "sea_ice_drift", "which no criterion of the loop reads")
        @test Coupling.tolerance(LF.exit_bracket(:climate, :deep_drift, :stock_per_relaxation_time,
                                                 LF.drift_tolerance())) == 5.0e-3
    end

    @testset "the finalizer offered a coarser artifact than its predicate needs refuses to substitute it" begin
        coarse = LF.climate_loop(p, :settled; level = 3)
        records = Coupling.run_loop(coarse; state = 0.0, instant = 0, numbering = LF.numbering()).records
        at(level) = Coupling.Ladder(loops = (coarse,), open = (), finalizer = Coupling.Finalizer(level = level))
        check(level) = Coupling.verify(at(level); records = records, instant = last(records).instant,
                                       numbering = LF.numbering())
        @test only(check(3).loops).verdict === Verdicts.Converged()
        @test Coupling.passes(check(3))
        for level in (5, 2, 4)
            final = check(level)
            report = only(final.loops)
            @test report.verdict === Verdicts.NotEvaluable()
            @test Coupling.not_evaluable(final) == [:climate]
            @test !Coupling.passes(final)
            @test all(r -> r isa Coupling.UnevaluableReport, report.criteria)
            @test occursin("measured at level 3, and the exit reads it at level $(level)",
                           first(report.criteria).reason)
        end
        missing_sample = [Coupling.Record(loop = r.loop, iteration = r.iteration, instant = r.instant,
                                          samples = Base.structdiff(r.samples, (deep = nothing,)))
                          for r in records]
        final = Coupling.verify(at(3); records = missing_sample, instant = last(records).instant,
                                numbering = LF.numbering())
        @test only(final.loops).verdict === Verdicts.NotEvaluable()
        @test occursin("carries no sample deep", only(final.loops).reason * only(
            r.reason for r in only(final.loops).criteria if r isa Coupling.UnevaluableReport))
        empty = Coupling.verify(at(3); records = Coupling.Record[], instant = 0, numbering = LF.numbering())
        @test only(empty.loops).verdict === Verdicts.Refused()
        @test !Coupling.passes(empty)
    end

    @testset "the finalizer verifies over the final records, fails naming the loop, and never iterates" begin
        calls = Ref(0)
        m = LF.two_box()
        settled = LF.climate_loop(p, :settled; body = LF.counted(
            LF.surrogate_body(m, :settled; spacing = 0.25, span = 32, level = 5), calls))
        crawl = LF.surrogate_body(m, :crawling; spacing = 0.25, span = 32, level = 5)
        tail = LF.fixed_point_loop(name = :tail, body = (state, i) -> crawl(state, i),
                                   exit = (LF.deep_drift(:window_rate, 32),),
                                   monotonicity = Coupling.Unordered(), cap = 32, floor = 32, level = 5,
                                   profile = p)
        ladder = Coupling.Ladder(loops = (settled, tail), open = (), finalizer = Coupling.Finalizer(level = 5))
        run = Coupling.run_ladder(ladder; state = 0.0, instant = 0, numbering = LF.numbering())
        @test [o.report.verdict for o in run.loops] == [Verdicts.Converged(), Verdicts.Converged()]
        @test calls[] == 32
        @test Coupling.failed(run.final) == [:climate]
        @test run.final.loops[1].verdict === Verdicts.Refused()
        @test run.final.loops[2].verdict === Verdicts.Converged()
        records = vcat((o.records for o in run.loops)...)
        again = Coupling.verify(ladder; records = records, instant = last(records).instant,
                                numbering = LF.numbering())
        @test calls[] == 32
        @test [r.verdict for r in again.loops] == [r.verdict for r in run.final.loops]
        @test LF.refused(LF.caught(() -> Coupling.verify(ladder; records = reverse(records), instant = 0,
                                                          numbering = LF.numbering())),
                         "records", "does not follow")
    end

    @testset "a loop left open is reported with its measured cost and never read as a result" begin
        carbon = Coupling.OpenLoop(name = :carbon, argument = "the fixture closes no carbon cycle",
                                   cost = :carbon_cost, scale = :absorbed)
        measured = LF.climate_loop(p, :settled; extra = (carbon_cost = 1.2,))
        ladder(loop) = Coupling.Ladder(loops = (loop,), open = (carbon,), finalizer = Coupling.Finalizer(level = 5))
        (run, events) = LF.recording(() ->
            Coupling.run_ladder(ladder(measured); state = 0.0, instant = 0, numbering = LF.numbering()))
        report = only(run.final.open)
        @test report.cost == 1.2 / 240
        @test Coupling.passes(run.final)
        open_event = only(e for e in events if e.payload.predicate == "carbon.open")
        @test open_event.payload.verdict === Verdicts.NotEvaluable()
        @test open_event.payload.statistic == 1.2 / 240
        unmeasured = Coupling.run_ladder(ladder(LF.climate_loop(p, :settled)); state = 0.0, instant = 0,
                                         numbering = LF.numbering())
        @test only(unmeasured.final.open).cost === nothing
        @test Coupling.not_evaluable(unmeasured.final) == [:carbon]
        @test !Coupling.passes(unmeasured.final)
        @test LF.refused(LF.caught(() -> Coupling.OpenLoop(name = :carbon, argument = "", cost = :c, scale = :s)),
                         "argument", "carries no argument")
        @test LF.refused(LF.caught(() -> Coupling.Ladder(loops = (measured,), open = (Coupling.OpenLoop(
            name = :climate, argument = "a", cost = :c, scale = :s),), finalizer = Coupling.Finalizer(level = 5))),
            "climate", "names climate twice")
    end

    @testset "every verdict goes through Events.emit, numbered in order" begin
        (outcome, events) = LF.recording(() -> Coupling.run_loop(
            LF.climate_loop(p, :settled); state = 0.0, instant = 0,
            numbering = Coupling.Numbering(first = 41, tier = :slow)))
        @test outcome.report.verdict === Verdicts.Converged()
        @test [e.header.sequence for e in events] == [41, 42, 43]
        @test all(e -> e.header.kind === Events.Verdict(), events)
        @test all(e -> e.header.component == "Coupling" && e.header.tier === :slow, events)
        @test all(e -> e.header.instant == 8.0, events)
        @test [e.payload.predicate for e in events] == ["climate.deep_drift", "climate.toa_balance", "climate"]
        @test events[3].payload.bracket == (32.0, 64.0)
        @test events[1].payload.bracket == (0.0, 5.0e-3)
    end

    @testset "the order criteria are given in reaches no result" begin
        given = ((LF.toa_balance(32), LF.deep_drift(:deep_rate, 32)),
                 (LF.deep_drift(:deep_rate, 32), LF.toa_balance(32)))
        runs = [LF.recording(() -> Coupling.run_loop(LF.climate_loop(p, :crawling; exit = e, cap = 40);
                                                     state = 0.0, instant = 0, numbering = LF.numbering()))
                for e in given]
        (a, ea), (b, eb) = runs
        @test [c.criterion for c in a.report.criteria] == [c.criterion for c in b.report.criteria]
        @test a.report.reason == b.report.reason
        @test [(e.header.sequence, e.header.kind, e.payload) for e in ea] ==
              [(e.header.sequence, e.header.kind, e.payload) for e in eb]
    end
end

@testset "loop.exit_criteria_on_a_known_surrogate" begin
    p = LF.fixture_profile()
    m = LF.two_box()
    star, tau = LF.fixed_point(m), LF.slow_relaxation_time(m)
    balance, drift = LF.balance_tolerance(), LF.drift_tolerance()
    run(loop) = Coupling.run_loop(loop; state = 0.0, instant = 0, numbering = LF.numbering())
    window = 31 * 0.25

    @testset "the surrogate's statuses, known before the loop runs" begin
        fast, slow = LF.eigenvalues(m)
        @test fast < slow < 0
        @test exp(-window / tau) / 2 > drift.high
        @test window / tau / 2 < drift.low
        ZT, ZD = LF.periodic_response(m)
        t = collect(0.25:0.25:8.0)
        centred = t .- sum(t) / length(t)
        @test (m.a + m.B * abs(ZT)) / m.S < balance.low
        @test abs(ZD) * sum(abs, centred) / sum(abs2, centred) * tau / star < drift.low
        @test 2 * (m.a + m.B * abs(ZT)) / m.S < balance.low
        settled = LF.trajectory(m, :settled, 0.25)
        @test maximum(abs(settled(s)[2] - star) for s in t) * sum(abs, centred) / sum(abs2, centred) *
              tau / star < drift.low
        @test maximum(abs(settled(s)[3]) for s in t) / m.S < balance.low
    end

    @testset "Converged on the settled trajectory" begin
        outcome = run(LF.climate_loop(p, :settled))
        @test outcome.report.verdict === Verdicts.Converged()
        @test outcome.report.records == 32
    end

    @testset "Converged or Bracketed on the oscillating trajectory" begin
        outcome = run(LF.climate_loop(p, :oscillating))
        @test outcome.report.verdict === Verdicts.Converged()
        alternating = LF.fixed_point_loop(
            name = :climate_alternating,
            body = LF.surrogate_body(m, :oscillating; spacing = 2.0, span = 2, level = 5),
            exit = (LF.toa_straddle(),), monotonicity = Coupling.Antitone(), cap = 8, floor = 2,
            level = 5, profile = p)
        bracketed = run(alternating)
        @test bracketed.report.verdict === Verdicts.Bracketed()
        @test bracketed.report.records == 2
        b = only(bracketed.report.criteria)
        @test b.width > b.overshoot > 0
    end

    @testset "not Converged on the crawling trajectory" begin
        outcome = run(LF.climate_loop(p, :crawling))
        @test outcome.report.verdict === Verdicts.BudgetExhausted()
        judged = Coupling.exit_verdict(LF.climate_loop(p, :crawling); records = outcome.records[1:32],
                                       level = 5, instant = 8, numbering = LF.numbering())
        @test judged.verdict === Verdicts.Refused()
        deep = only(r for r in judged.criteria if r.criterion === :deep_drift)
        @test deep.verdict === Verdicts.Refused()
        @test deep.statistic > drift.high
    end

    @testset "positive control: a drift-window test alone passes the crawling trajectory" begin
        window_only = LF.climate_loop(p, :crawling; name = :climate_window,
                                      exit = (LF.deep_drift(:window_rate, 32),))
        outcome = run(window_only)
        @test outcome.report.verdict === Verdicts.Converged()
        @test only(outcome.report.criteria).statistic < drift.low
    end
end

@testset "loop.drift_against_its_own_scatter" begin
    p = LF.fixture_profile()
    m = LF.two_box()
    surrogates = 19

    @testset "reported beside the declared bracket for each surrogate trajectory" begin
        for kind in (:settled, :oscillating, :crawling)
            loop = LF.climate_loop(p, kind)
            records = Coupling.run_loop(loop; state = 0.0, instant = 0, numbering = LF.numbering()).records
            draw = LF.philox_words(20260913, "climate deep_drift", 1, 2)
            (report, events) = LF.recording(() -> Coupling.scatter_report(
                loop; criterion = :deep_drift, records = records, level = 5, surrogates = surrogates,
                draw = draw, instant = last(records).instant, numbering = LF.numbering()))
            @test report isa Coupling.ScatterReport
            @test report.bracket == (LF.drift_tolerance().low, LF.drift_tolerance().high)
            @test length(report.drifts) == surrogates
            @test Coupling.fraction(report) == count(>(report.drift), report.drifts) // surrogates
            @test report.report == only(r for r in Coupling.exit_verdict(
                loop; records = records, level = 5, instant = 0, numbering = LF.numbering()).criteria
                if r.criterion === :deep_drift)
            event = only(events)
            @test event.header.kind === Events.Oracle()
            @test event.payload.registry_id == "loop.drift_against_its_own_scatter"
            @test event.payload.verdict === Verdicts.REPORT()
            @test event.payload.statistic == Float64(Coupling.fraction(report))
            @test isnan(event.payload.threshold)
            println("loop.drift_against_its_own_scatter: ", kind, ": fraction ", Coupling.fraction(report),
                    " of ", surrogates, " surrogates beside the bracket ", report.bracket,
                    "; statistic ", report.report.statistic, ", verdict ",
                    nameof(typeof(report.report.verdict)))
        end
    end

    @testset "reproducible: the phases are the counter-based generator's draws" begin
        loop = LF.climate_loop(p, :crawling)
        records = Coupling.run_loop(loop; state = 0.0, instant = 0, numbering = LF.numbering()).records
        report(draw) = Coupling.scatter_report(loop; criterion = :deep_drift, records = records, level = 5,
                                               surrogates = surrogates, draw = draw, instant = 0,
                                               numbering = LF.numbering())
        read = Int[]
        logged(i) = (push!(read, i); LF.philox_words(7, "climate deep_drift", 1, 2)(i))
        first_report = report(logged)
        @test read == collect(1:(surrogates * (cld(32, 2) - 1)))
        second_report = report(LF.philox_words(7, "climate deep_drift", 1, 2))
        @test second_report.drifts == first_report.drifts
        @test second_report.exceeding == first_report.exceeding
        other_seed = report(LF.philox_words(8, "climate deep_drift", 1, 2))
        @test other_seed.drifts != first_report.drifts
        @test LF.refused(LF.caught(() -> report(i -> 1.0)), "draw", "where a UInt64 is required")
        @test LF.refused(LF.caught(() -> Coupling.scatter_report(
            loop; criterion = :toa_balance, records = records, level = 5, surrogates = surrogates,
            draw = LF.philox_words(7, "x", 1, 2), instant = 0, numbering = LF.numbering())),
            "toa_balance", "has no Drift criterion named toa_balance")
    end

    @testset "under exchangeable phases the data has the largest drift with probability 1 / (M + 1)" begin
        loop = LF.fixed_point_loop(name = :null, body = (s, i) -> nothing, exit = (LF.deep_drift(:deep_rate, 32),),
                                   monotonicity = Coupling.Unordered(), cap = 32, floor = 32, level = 5,
                                   profile = p)
        series = 200
        largest(trend) = count(1:series) do cell
            records = LF.null_records(20260913, cell, 32; trend = trend)
            r = Coupling.scatter_report(loop; criterion = :deep_drift, records = records, level = 5,
                                        surrogates = surrogates,
                                        draw = LF.philox_words(20260913, "null surrogates", cell, 2),
                                        instant = 32, numbering = LF.numbering())
            r.exceeding == 0
        end
        null = largest(0)
        println("loop.drift_against_its_own_scatter: null ensemble: ", null, " of ", series,
                " series with no surrogate exceeding, expected ", series // (surrogates + 1))
        @test !LF.binomial_rejects(null, series, 1 // (surrogates + 1), 1 // 100)
        trending = largest(1)
        @test LF.binomial_rejects(trending, series, 1 // (surrogates + 1), 1 // 100)
    end
end
