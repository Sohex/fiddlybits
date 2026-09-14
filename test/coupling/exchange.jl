using Test
import CUDA
using Fiddlybits: Coupling, Backends, Events, Verdicts, Fields, Mesh, Time, Dimensions, Reductions,
                  Provenance

# ledger.closure on its exchange arm, the refusals of Exchange and exchange!, and the
# residual signature of an exchange's ledger series, on fixture components:
# docs/plans/fiddlybits-52v.11-coupling.md, section "Exchanges"; docs/oracles/registry.toml.

module ExchangeFixtures

using Fiddlybits: Coupling, Backends, Events, Fields, Mesh, Time, Dimensions, Verdicts, Provenance,
                  Reductions
using UUIDs: UUID

"A fixture component: its declaration and nothing else."
struct Component
    declaration::Coupling.Declaration
end

Coupling.declare(c::Component) = c.declaration

"Levels 2 and 1 of a hierarchy two levels deep: each support and its primal cell areas."
function mesh()
    h = Mesh.hierarchy(2)
    function built(level)
        l = h.levels[level + 1]
        g = Mesh.geometry(l, Mesh.stencils(l))
        s = Mesh.Support(level, l, g; kind = :icosahedral_bisection, refinement = (), radius = 1.0,
                         element_type = :Float64, fractions = ())
        return s, g.cell_area
    end
    fine, fine_area = built(2)
    coarse, coarse_area = built(1)
    return (fine = fine, coarse = coarse, fine_area = fine_area, coarse_area = coarse_area)
end

reading(q, level, operator; lagged = false, move = false) =
    Coupling.Read(quantity = q, level = level, operator = operator, lagged = lagged, move = move)
at_level() = Coupling.AtLevel(measure = Coupling.NoMeasure())
at_level_over_area() = Coupling.AtLevel(measure = :primal_cell_area)
by_sum() = Coupling.Coarsen(rule = Coupling.RuleOfSemantics(), measure = Coupling.NoMeasure())
by_area_mean() = Coupling.Coarsen(rule = Coupling.RuleOfSemantics(), measure = :primal_cell_area)
by_area_split() = Coupling.Refine(measure = :primal_cell_area)
water(q, semantics) = Coupling.Write(quantity = q, semantics = semantics, conserves = (:water,))
water_stock(qs...) = (Coupling.Stock(conserved = :water, quantities = qs),)
initial(q, level; backend = Backends.CPU()) =
    Coupling.InitialCondition(quantity = q, level = level, backend = backend)

component(name; level, reads, writes, stocks, backend = Backends.CPU()) =
    Component(Coupling.Declaration(name = name, level = level, reads = reads, writes = writes,
                                   stocks = stocks, system_fields = (), profile_fields = (),
                                   backend = backend))

"""
    land(; stocks)

Level 2: reads its soil water lagged and the precipitation `air` writes lagged, through a
refinement; writes runoff, soil water and evaporation, each carrying water.
"""
land(; stocks = water_stock(:soil_water)) =
    component(:land; level = 2,
              reads = (reading(:soil_water, 2, at_level(); lagged = true),
                       reading(:precipitation, 2, by_area_split(); lagged = true)),
              writes = (water(:runoff, Fields.Extensive()), water(:soil_water, Fields.Extensive()),
                        water(:evaporation, Fields.FluxDensity())), stocks = stocks)

"Level 1: reads runoff and soil water through a sum, and its channel lagged; writes the channel."
river() = component(:river; level = 1,
                    reads = (reading(:runoff, 1, by_sum()), reading(:soil_water, 1, by_sum()),
                             reading(:channel, 1, at_level(); lagged = true)),
                    writes = (water(:channel, Fields.Extensive()),), stocks = water_stock(:channel))

"Level 1: reads evaporation through an area mean, and its humidity lagged; writes humidity and precipitation."
air() = component(:air; level = 1,
                  reads = (reading(:evaporation, 1, by_area_mean()),
                           reading(:humidity, 1, at_level(); lagged = true)),
                  writes = (water(:humidity, Fields.Extensive()), water(:precipitation, Fields.FluxDensity())),
                  stocks = water_stock(:humidity))

assembly(components = (land(), river(), air())) =
    Coupling.assemble(components...;
                      initial_conditions = (initial(:soil_water, 2), initial(:channel, 1),
                                            initial(:humidity, 1), initial(:precipitation, 1)),
                      sequence = 1, instant = 0.0, tier = :fast)

run_id() = UUID("6e1c0a2e-0000-4000-8000-000000000112")

field(support, data, semantics, time) =
    Fields.Field(semantics = semantics, dimension = Dimensions.MASS, data = data, support = support,
                 time = time, origin = Fields.unstamped(:fixture, run_id()))

"`n` values `1 + sin(phase * i) / 2`, so no two neighbouring cells hold one amount."
varying(n, phase) = [1.0 + 0.5 * sin(phase * i) for i in 1:n]

accumulated(i) = Time.TimeSupport(Time.IntervalAccumulation(), i)
endpoint(i) = Time.TimeSupport(Time.EndpointState(), i)
mean_over(i) = Time.TimeSupport(Time.IntervalMean(), i)

"""
    stepped(a, m, window)

A `WorldState` of the assembly `a` with its first step begun over the interval from 0 to
`window`, and `land`'s writes placed: runoff accumulated in proportion to `window`, soil
water at a level `window` does not change, evaporation as a mean rate. Returns
`(state, interval)`.
"""
function stepped(a, m, window)
    interval = Time.Interval(0.0, window)
    before = Time.Interval(-window, 0.0)
    nf, nc = length(m.fine_area), length(m.coarse_area)
    state = Coupling.WorldState(a; initial = (
        channel = field(m.coarse, varying(nc, 0.7), Fields.Extensive(), endpoint(before)),
        humidity = field(m.coarse, varying(nc, 1.1), Fields.Extensive(), endpoint(before)),
        precipitation = field(m.coarse, varying(nc, 1.9), Fields.FluxDensity(), mean_over(before)),
        soil_water = field(m.fine, varying(nf, 2.3), Fields.Extensive(), endpoint(before))))
    Coupling.begin_step!(state)
    Coupling.write_quantity!(state, :land, :runoff,
                             field(m.fine, window .* varying(nf, 3.0), Fields.Extensive(),
                                   accumulated(interval)))
    Coupling.write_quantity!(state, :land, :soil_water,
                             field(m.fine, varying(nf, 2.9), Fields.Extensive(), endpoint(interval)))
    Coupling.write_quantity!(state, :land, :evaporation,
                             field(m.fine, varying(nf, 3.7), Fields.FluxDensity(), mean_over(interval)))
    return state, interval
end

"The position of each `(quantity, ledger)` a fixture classifies, as the process word of its draw."
ledger_positions() =
    Dict((q, kind) => 2 * (i - 1) + j
         for (i, q) in enumerate((:evaporation, :melt, :precipitation, :runoff, :snow, :soil_water,
                                  :temperature, :sublimation, :pool, :vapour, :vapour_columns))
         for (j, kind) in enumerate((:operator, :receipt)))

"""
    keyed_draw(root_seed, support)

`(identity, counter) ->` the first word of `Provenance.philox_draw` keyed on `root_seed`,
`support`, cell 0, the process `ledger_positions` gives the identity's quantity and
ledger, time index 0 and draw index `counter`.
"""
function keyed_draw(root_seed, support)
    positions = ledger_positions()
    return (identity, counter) ->
        Provenance.philox_draw(root_seed, support, 0, positions[(identity.quantity, identity.ledger)],
                               0, counter)[1]
end

classification(m; draw = keyed_draw(20260913, m.coarse)) =
    Coupling.Classification(false_alarm = 1 // 100, permutations = 1000, draw = draw)

crossing(q, support; measure = Coupling.NoMeasure()) =
    Coupling.Crossing(quantity = q, support = support, measure = measure, legend = Coupling.NoLegend())

area(m) = Fields.Measured{:primal_cell_area}(m.fine_area)

exchange(m; from, to, crossings, conserved = (:water,), replayed = (), recomputed = (),
         draw = keyed_draw(20260913, m.coarse)) =
    Coupling.Exchange(from = from, to = to, crossings = crossings, conserved = conserved,
                      replayed = replayed, recomputed = recomputed,
                      classification = classification(m; draw = draw))

to_river(m; crossings = (crossing(:runoff, m.coarse), crossing(:soil_water, m.coarse)), kwargs...) =
    exchange(m; from = :land, to = :river, crossings = crossings, kwargs...)
to_air(m; crossings = (crossing(:evaporation, m.coarse; measure = area(m)),), kwargs...) =
    exchange(m; from = :land, to = :air, crossings = crossings, kwargs...)
to_land(m; kwargs...) =
    exchange(m; from = :air, to = :land,
             crossings = (crossing(:precipitation, m.fine; measure = area(m)),), kwargs...)

"The strictly increasing windows every series here is measured at."
windows() = [10.0, 30.0, 100.0, 200.0, 400.0, 700.0, 1000.0, 1200.0]

"The ledgers `Coupling.exchange!` returns for `ex` on a state `stepped` at each of `windows`."
exchanged(a, m, ex, windows) = map(windows) do w
    state, interval = stepped(a, m, w)
    last(Coupling.exchange!(state, ex, interval; sequence = 1, tier = :fast))
end

"""
    staged(a, m, ex, windows, stage)

At each of `windows`, `Coupling.measure_ledgers` of `ex` on a state `stepped` there whose
reader was handed `stage(h)` in place of the result of each `Coupling.HandOver` `h`.
"""
staged(a, m, ex, windows, stage) = map(windows) do w
    state, _ = stepped(a, m, w)
    handed = Coupling.hand_over(state, ex)
    foreach(h -> Coupling.receive!(state, ex.to, h.crossing.quantity, stage(h)), values(handed))
    Coupling.measure_ledgers(state, ex, handed)
end

"A stage handing over the result of `h`, and for `quantity` the result added to itself."
counted_twice(quantity) = h -> h.crossing.quantity === quantity ? h.result + h.result : h.result

"A stage handing over the result of `h`, and for `quantity` the result with its first cell emptied."
first_pool_omitted(quantity) =
    h -> h.crossing.quantity === quantity ? first_cell_emptied(h.result) : h.result

function first_cell_emptied(f)
    d = copy(Fields.data(f))
    d[1] = zero(eltype(d))
    return Fields.Field(semantics = Fields.semantics(f), dimension = Fields.dimension(f), data = d,
                        support = Fields.support(f), time = Fields.time_support(f),
                        origin = Fields.origin(f))
end

"The one signature `signatures` recorded for the `kind` ledger of `q`."
signature_of(found, q, kind) = only(s.signature for s in found if s.quantity === q && s.ledger === kind)

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

"`(caught(f), events)`: what `f` raises and every event `Events.emit` was handed meanwhile."
function journal(f)
    events = Any[]
    Events.sink!(e -> push!(events, e))
    try
        return caught(f), events
    finally
        Events.sink!(Events.noop_sink)
    end
end

"""
    with_bound(f, bound)

`f()` in the latest world, with `Reductions.error_bound` over a `Float64` accumulator, an
`Int` term count and a `Float64` magnitude answered by `bound(generic)`, `generic` that
bound as `Reductions` defines it; the method is deleted on return.
"""
function with_bound(f, bound)
    Core.eval(Reductions, :(error_bound(::Type{Float64}, n::Int, magnitude::Float64) =
        $(bound)(invoke(error_bound, Tuple{Type{Float64},Integer,Real}, Float64, n, magnitude))))
    added = Base.invokelatest(which, Reductions.error_bound, (Type{Float64}, Int, Float64))
    try
        return Base.invokelatest(f), added
    finally
        Base.delete_method(added)
    end
end

sensor(; conserves, stocks) =
    component(:sensor; level = 2, reads = (),
              writes = (Coupling.Write(quantity = :temperature, semantics = Fields.Intensive(), conserves = conserves),),
              stocks = stocks)
probe() = component(:probe; level = 1,
                    reads = (reading(:temperature, 1, Coupling.Coarsen(rule = Fields.ToQuantiles{(0.5,)}(),
                                                                       measure = Coupling.NoMeasure())),),
                    writes = (), stocks = ())

snowpack() = component(:snowpack; level = 2, reads = (reading(:snow, 2, at_level(); lagged = true),),
                       writes = (water(:snow, Fields.Extensive()), water(:melt, Fields.Extensive()),
                                 water(:sublimation, Fields.FluxDensity())),
                       stocks = water_stock(:snow))
sea() = component(:sea; level = 1,
                  reads = (reading(:melt, 1, by_sum(); move = true),
                           reading(:sea_water, 1, at_level(); lagged = true)),
                  writes = (water(:sea_water, Fields.Extensive()),), stocks = water_stock(:sea_water),
                  backend = Backends.GPU())
lake() = component(:lake; level = 2,
                   reads = (reading(:snow, 2, at_level(); move = true),
                            reading(:sublimation, 2, at_level_over_area(); move = true),
                            reading(:lake_water, 2, at_level(); lagged = true)),
                   writes = (water(:lake_water, Fields.Extensive()),), stocks = water_stock(:lake_water),
                   backend = Backends.GPU())

"""
    source(backend)

Level 2 on `backend`: writes `pool`, an extensive amount in three columns, `vapour`, a
flux density, and `vapour_columns`, a flux density in three columns, each carrying water.
"""
source(backend) = component(:source; level = 2, reads = (),
                            writes = (water(:pool, Fields.Extensive()), water(:vapour, Fields.FluxDensity()),
                                      water(:vapour_columns, Fields.FluxDensity())),
                            stocks = water_stock(:pool), backend = backend)

"Level 2 on `backend`: moves `pool` in with no measure, and `vapour` and `vapour_columns` over the primal cell area."
sink(backend) = component(:sink; level = 2,
                          reads = (reading(:pool, 2, at_level(); move = true),
                                   reading(:vapour, 2, at_level_over_area(); move = true),
                                   reading(:vapour_columns, 2, at_level_over_area(); move = true)),
                          writes = (), stocks = (), backend = backend)

"The exchange handing `source`'s three writes to `sink`."
to_sink(m) = exchange(m; from = :source, to = :sink,
                      crossings = (crossing(:pool, m.fine), crossing(:vapour, m.fine; measure = area(m)),
                                   crossing(:vapour_columns, m.fine; measure = area(m))))

"`hcat` of three `varying` columns of `n` cells at the phases `phases`."
columns(n, phases) = reduce(hcat, (varying(n, p) for p in phases))

"""
    moved(from, to, m, window)

A `WorldState` of `source` on `from` and `sink` on `to` with its first step begun over the
interval from 0 to `window` and `source`'s writes placed on `from`, each in proportion to
`window`. Returns `(state, interval, written)`, `written` the host arrays placed, by
quantity.
"""
function moved(from, to, m, window)
    a = Coupling.assemble(source(from), sink(to); initial_conditions = (), sequence = 1, instant = 0.0,
                          tier = :fast)
    interval = Time.Interval(0.0, window)
    n = length(m.fine_area)
    written = (pool = window .* columns(n, (0.4, 1.3, 2.2)), vapour = window .* varying(n, 3.1),
               vapour_columns = window .* columns(n, (0.8, 1.7, 2.6)))
    state = Coupling.WorldState(a; initial = NamedTuple())
    Coupling.begin_step!(state)
    place(q, semantics, time) =
        Coupling.write_quantity!(state, :source, q,
                                 field(m.fine, Backends.on(written[q], from), semantics, time))
    place(:pool, Fields.Extensive(), accumulated(interval))
    place(:vapour, Fields.FluxDensity(), mean_over(interval))
    place(:vapour_columns, Fields.FluxDensity(), mean_over(interval))
    return state, interval, written
end

"""
    moved_staged(from, to, m, ex, windows, stage)

At each of `windows`, `Coupling.measure_ledgers` of `ex` on a state `moved` there whose
reader was handed `stage(h)` in place of the result of each `Coupling.HandOver` `h`.
"""
moved_staged(from, to, m, ex, windows, stage) = map(windows) do w
    state, _, _ = moved(from, to, m, w)
    handed = Coupling.hand_over(state, ex)
    foreach(h -> Coupling.receive!(state, ex.to, h.crossing.quantity, stage(h)), values(handed))
    Coupling.measure_ledgers(state, ex, handed)
end

"""
    first_cell_doubled(quantities)

A stage handing over the result of `h`, and for a quantity in `quantities` the result with
the value of its first cell in its first column doubled, formed on the result's device by
multiplying by a factor array moved there through `Backends.on`.
"""
first_cell_doubled(quantities) = h -> h.crossing.quantity in quantities ? doubled_first(h.result, h.backend) : h.result

function doubled_first(f, backend)
    factor = ones(size(Fields.data(f)))
    factor[1] = 2.0
    return Fields.Field(semantics = Fields.semantics(f), dimension = Fields.dimension(f),
                        data = Fields.data(f) .* Backends.on(factor, backend), support = Fields.support(f),
                        time = Fields.time_support(f), origin = Fields.origin(f))
end

end # module ExchangeFixtures

import .ExchangeFixtures as EF

@testset "ledger.closure: the exchange arm" begin
    m = EF.mesh()
    a = EF.assembly()
    ws = EF.windows()

    @testset "every ledger of every exchange closes within one derived bound unit, its series classified" begin
        for ex in (EF.to_river(m), EF.to_air(m), EF.to_land(m))
            series = EF.exchanged(a, m, ex, ws)
            for ledgers in series, l in values(ledgers), kind in (:operator, :receipt)
                ledger = getfield(l, kind)
                @test ledger isa Fields.Ledger
                @test abs(Fields.residual(ledger)) <= Fields.tolerance(ledger)
            end
            found = Coupling.signatures(ex, series, ws)
            @test length(found) == 2 * length(ex.crossings)
            for s in found
                @test s.signature in (s.ledger === :receipt ? (Fields.Rounding(),) :
                                      (Fields.Rounding(), Fields.Unexplained()))
            end
        end
    end

    ex = EF.to_river(m)

    @testset "positive control: a flux counted twice at the crossing is a Leak, distinguished from rounding" begin
        series = EF.staged(a, m, ex, ws, EF.counted_twice(:runoff))
        @test all(l -> !Fields.closed(l.runoff.receipt), series)
        found = Coupling.signatures(ex, series, ws)
        @test EF.signature_of(found, :runoff, :receipt) === Fields.Leak()
        @test EF.signature_of(found, :soil_water, :receipt) === Fields.Rounding()
    end

    @testset "positive control: a pool omitted from what the reader holds is a StockOmission, distinguished from rounding" begin
        series = EF.staged(a, m, ex, ws, EF.first_pool_omitted(:soil_water))
        @test all(l -> !Fields.closed(l.soil_water.receipt), series)
        found = Coupling.signatures(ex, series, ws)
        @test EF.signature_of(found, :soil_water, :receipt) === Fields.StockOmission()
        @test EF.signature_of(found, :runoff, :receipt) === Fields.Rounding()
    end

    @testset "the same staging handing over each result as it is is Rounding" begin
        found = Coupling.signatures(ex, EF.staged(a, m, ex, ws, h -> h.result), ws)
        @test EF.signature_of(found, :runoff, :receipt) === Fields.Rounding()
        @test EF.signature_of(found, :soil_water, :receipt) === Fields.Rounding()
    end

    @testset "the draw is called with the identity of the series it classifies" begin
        keyed = EF.keyed_draw(20260913, m.coarse)
        seen = Set{Any}()
        recording = EF.to_river(m; draw = (identity, counter) -> (push!(seen, identity); keyed(identity, counter)))
        series = EF.staged(a, m, recording, ws, EF.counted_twice(:runoff))
        first_pass = Coupling.signatures(recording, series, ws)
        @test (from = :land, to = :river, quantity = :soil_water, ledger = :receipt, class = nothing,
               column = nothing) in seen
        @test all(i -> i.from === :land && i.to === :river, seen)
        @test Coupling.signatures(recording, series, ws) == first_pass
    end

    @testset "a conserved quantity's ledgers are the entries whose quantity carries it" begin
        ledgers = only(EF.exchanged(a, m, ex, ws[1:1]))
        @test keys(Coupling.conserved_ledgers(ledgers, :water)) == (:runoff, :soil_water)
        @test EF.refused(EF.caught(() -> Coupling.conserved_ledgers(ledgers, :heat)), "heat", "not one of")
    end
end

@testset "an open ledger is journalled as ledger_open and refused" begin
    m = EF.mesh()
    a = EF.assembly()
    ex = EF.to_river(m)

    @testset "an open receipt ledger" begin
        state, _ = EF.stepped(a, m, 100.0)
        handed = Coupling.hand_over(state, ex)
        foreach(h -> Coupling.receive!(state, :river, h.crossing.quantity, EF.counted_twice(:runoff)(h)),
                values(handed))
        open = Coupling.measure_ledgers(state, ex, handed).runoff.receipt
        e, events = EF.journal(() -> Coupling.settle(state, ex, handed; sequence = 5, instant = 100.0, tier = :fast))
        @test EF.refused(e, "runoff receipt total", "of the exchange land -> river is open")
        event = only(events)
        @test event.header.kind === Events.LedgerOpen()
        @test event.header.sequence == 5
        @test event.header.component == "Coupling"
        @test event.payload.ledger == "runoff receipt total"
        @test event.payload.exchange == "land -> river"
        @test event.payload.imbalance == Fields.residual(open)
        @test event.payload.tolerance == Fields.tolerance(open)
    end

    @testset "control: a faithful exchange journals nothing" begin
        state, interval = EF.stepped(a, m, 100.0)
        e, events = EF.journal(() -> Coupling.exchange!(state, ex, interval; sequence = 6, tier = :fast))
        @test e === nothing
        @test isempty(events)
    end

    @testset "an open operator ledger refuses before anything is received" begin
        faithful_state, interval = EF.stepped(a, m, 100.0)
        faithful = last(Coupling.exchange!(faithful_state, EF.to_air(m), interval; sequence = 1, tier = :fast))
        @test Fields.residual(faithful.evaporation.operator) != 0
        state, interval = EF.stepped(a, m, 100.0)
        (outcome, _) = EF.with_bound(generic -> zero(generic)) do
            EF.journal(() -> Coupling.exchange!(state, EF.to_air(m), interval; sequence = 7, tier = :fast))
        end
        e, events = outcome
        @test EF.refused(e, "evaporation operator primal_cell_area_integral", "is open")
        @test only(events).header.kind === Events.LedgerOpen()
        @test EF.refused(EF.caught(() -> Coupling.read_quantity(state, :air, :evaporation)), "evaporation",
                         "nothing has been received")
    end
end

@testset "the tolerance is read from Reductions: widening the bound there widens it here" begin
    m = EF.mesh()
    a = EF.assembly()
    ex = EF.to_river(m)
    tolerances(l) = (Fields.tolerance(l.runoff.operator), Fields.tolerance(l.runoff.receipt),
                     Fields.tolerance(l.soil_water.operator), Fields.tolerance(l.soil_water.receipt))
    run() = only(EF.exchanged(a, m, ex, [100.0]))
    before = tolerances(run())
    (widened, added) = EF.with_bound(generic -> 2 * generic) do
        tolerances(run())
    end
    @test added.module === Reductions
    @test all(before .> 0)
    @test widened == 2 .* before
    @test tolerances(Base.invokelatest(run)) == before
end

@testset "a NotConserved ledger is recorded as not conserved, never treated as closed" begin
    m = EF.mesh()
    interval = Time.Interval(0.0, 10.0)
    temperature = EF.field(m.fine, EF.varying(length(m.fine_area), 1.3), Fields.Intensive(), EF.endpoint(interval))
    function sensed(sensor)
        a = Coupling.assemble(sensor, EF.probe(); initial_conditions = (), sequence = 1, instant = 0.0, tier = :fast)
        state = Coupling.WorldState(a; initial = NamedTuple())
        Coupling.begin_step!(state)
        Coupling.write_quantity!(state, :sensor, :temperature, temperature)
        return state
    end
    quantiles(conserved) = EF.exchange(m; from = :sensor, to = :probe,
                                       crossings = (EF.crossing(:temperature, m.coarse),), conserved = conserved)

    @testset "a quantity carrying nothing keeps its NotConserved ledger" begin
        ex = quantiles(())
        _, ledgers = Coupling.exchange!(sensed(EF.sensor(conserves = (), stocks = ())), ex, interval;
                                        sequence = 1, tier = :fast)
        @test ledgers.temperature.operator isa Fields.NotConserved
        @test ledgers.temperature.receipt === Coupling.NoReceipt()
        @test EF.refused(EF.caught(() -> Fields.closed(ledgers.temperature.operator)),
                         "ledger of coarsen of Intensive", "order statistics")
        @test only(Coupling.signatures(ex, [ledgers], [10.0])).signature isa Fields.NotConserved
    end

    @testset "a quantity carrying a conserved quantity refuses, and nothing is received" begin
        energy = (Coupling.Stock(conserved = :energy, quantities = (:temperature,)),)
        state = sensed(EF.sensor(conserves = (:energy,), stocks = energy))
        e, events = EF.journal(() -> Coupling.exchange!(state, quantiles((:energy,)), interval;
                                                        sequence = 2, tier = :fast))
        @test EF.refused(e, "temperature", "carries energy, and its operator conserves nothing: a quantile table")
        @test only(events).header.kind === Events.Refusal()
        @test only(events).payload === e
        @test EF.refused(EF.caught(() -> Coupling.read_quantity(state, :probe, :temperature)), "temperature",
                         "nothing has been received")
    end
end

@testset "a receiver that recomputes a handed-over flux is refused" begin
    m = EF.mesh()
    a = EF.assembly()
    recompute(q, replacing) = (Coupling.Recomputed(quantity = q, replacing = replacing),)

    e = EF.caught(() -> EF.to_river(m; recomputed = recompute(:channel, :runoff)))
    @test EF.refused(e, "runoff", "a flux handed over is not recomputed by its receiver")
    @test EF.refused(EF.caught(() -> EF.to_river(m; recomputed = recompute(:runoff, :inflow))), "runoff",
                     "the exchange hands runoff over from land")
    @test EF.refused(EF.caught(() -> EF.to_river(m; recomputed = (recompute(:channel, :inflow)...,
                                                                   recompute(:bank, :inflow)...))),
                     "recomputed", "names one replaced term twice")

    @testset "control: recomputing a term the exchange does not hand over exchanges" begin
        state, interval = EF.stepped(a, m, 100.0)
        _, ledgers = Coupling.exchange!(state, EF.to_river(m; recomputed = recompute(:channel, :inflow)),
                                        interval; sequence = 1, tier = :fast)
        @test Fields.closed(ledgers.runoff.receipt)
        state, interval = EF.stepped(a, m, 100.0)
        e = EF.caught(() -> Coupling.exchange!(state, EF.to_river(m; recomputed = recompute(:humidity, :inflow)),
                                               interval; sequence = 1, tier = :fast))
        @test EF.refused(e, "humidity", "river is declared to recompute humidity, which it does not write")
    end
end

@testset "a replayed forcing declares its replayed terms, and a term depending on its receiver's state is refused" begin
    m = EF.mesh()
    a = EF.assembly()
    state, interval = EF.stepped(a, m, 100.0)
    e = EF.caught(() -> Coupling.exchange!(state, EF.to_air(m; replayed = (:evaporation,)), interval;
                                           sequence = 1, tier = :fast))
    @test EF.refused(e, "evaporation", "its writer land reads precipitation, which air writes")
    @test EF.refused(EF.caught(() -> EF.to_river(m; replayed = (:channel,))), "channel",
                     "declared replayed, and the exchange from land to river hands over no channel")

    @testset "control: a replayed term whose writer reads nothing its receiver writes exchanges" begin
        state, interval = EF.stepped(a, m, 100.0)
        replaying = EF.to_river(m; replayed = (:runoff,))
        @test replaying.replayed == (:runoff,)
        _, ledgers = Coupling.exchange!(state, replaying, interval; sequence = 1, tier = :fast)
        @test Fields.closed(ledgers.runoff.receipt)
    end
end

@testset "a component that cannot report a stock is refused at assembly (fiddlybits-52v.11.1), never credited zero here" begin
    e = EF.caught(() -> EF.assembly((EF.land(stocks = ()), EF.river(), EF.air())))
    @test EF.refused(e, "land", "writes evaporation, which carries water, and cannot report a stock of water")
end

@testset "an exchange refuses what its declaration and the assembly do not agree on" begin
    m = EF.mesh()
    a = EF.assembly()
    attempt(ex) = begin
        state, interval = EF.stepped(a, m, 100.0)
        EF.journal(() -> Coupling.exchange!(state, ex, interval; sequence = 9, tier = :fast))
    end
    refused_by(ex, quantity, text) = begin
        e, events = attempt(ex)
        EF.refused(e, quantity, text) && only(events).header.kind === Events.Refusal()
    end

    @test EF.refused(EF.caught(() -> EF.exchange(m; from = :land, to = :land, crossings = (EF.crossing(:runoff, m.coarse),))),
                     "to", "exchange with itself")
    @test EF.refused(EF.caught(() -> EF.to_river(m; crossings = ())), "crossings", "hands over no quantity")
    @test EF.refused(EF.caught(() -> EF.to_river(m; conserved = (:heat,))), "conserved", "not one of")
    @test EF.refused(EF.caught(() -> Coupling.Crossing(quantity = :runoff, support = m.coarse,
                                                       measure = Coupling.NoMeasure())),
                     "legend", "missing")
    @test EF.refused(EF.caught(() -> Coupling.Exchange(from = :land, to = :river,
                                                       crossings = (EF.crossing(:runoff, m.coarse),),
                                                       conserved = (:water,), replayed = (), recomputed = ())),
                     "classification", "missing")

    @test refused_by(EF.exchange(m; from = :air, to = :river, crossings = (EF.crossing(:runoff, m.coarse),)),
                     "runoff", "the exchange from air hands over runoff, whose declared writer is land")
    @test refused_by(EF.exchange(m; from = :land, to = :air, crossings = (EF.crossing(:runoff, m.coarse),)),
                     "runoff", "air declares no read of runoff")
    @test refused_by(EF.to_air(m; crossings = (EF.crossing(:evaporation, m.coarse),)),
                     "evaporation", "declares the primal_cell_area measure, and its crossing is given none")
    @test refused_by(EF.to_air(m; crossings = (EF.crossing(:evaporation, m.coarse;
                                                            measure = Fields.Measured{:dual_area}(m.fine_area)),)),
                     "evaporation", "and its crossing is given the dual_area measure")
    @test refused_by(EF.to_river(m; crossings = (EF.crossing(:runoff, m.coarse; measure = EF.area(m)),
                                                  EF.crossing(:soil_water, m.coarse))),
                     "runoff", "declares no measure, and its crossing is given the primal_cell_area measure")
    @test refused_by(EF.to_river(m; conserved = ()), "water", "carries water, which the exchange does not balance")
    @test refused_by(EF.to_river(m; conserved = (:carbon, :water)), "carbon",
                     "balances carbon, which no quantity it hands over carries")

    @testset "a read that is not a crossing" begin
        plain = Coupling.assemble(EF.component(:w; level = 2, reads = (),
                                               writes = (Coupling.Write(quantity = :x, semantics = Fields.Extensive(), conserves = ()),),
                                               stocks = ()),
                                  EF.component(:r; level = 2, reads = (EF.reading(:x, 2, EF.at_level()),), writes = (), stocks = ());
                                  initial_conditions = (), sequence = 1, instant = 0.0, tier = :fast)
        state = Coupling.WorldState(plain; initial = NamedTuple())
        Coupling.begin_step!(state)
        Coupling.write_quantity!(state, :w, :x, EF.field(m.fine, ones(length(m.fine_area)), Fields.Extensive(),
                                                         EF.endpoint(Time.Interval(0.0, 1.0))))
        ex = EF.exchange(m; from = :w, to = :r, crossings = (EF.crossing(:x, m.fine),), conserved = ())
        @test EF.refused(EF.caught(() -> Coupling.exchange!(state, ex, Time.Interval(0.0, 1.0); sequence = 1, tier = :fast)),
                         "x", "r reads x at its own level on its own device, which is not a crossing")
    end

    @testset "signatures refuses a series it cannot classify" begin
        ex = EF.to_river(m)
        series = EF.exchanged(a, m, ex, EF.windows()[1:2])
        @test EF.refused(EF.caught(() -> Coupling.signatures(ex, series, [1.0])), "series", "2 entries are given at 1 windows")
        @test EF.refused(EF.caught(() -> Coupling.signatures(ex, empty(series), Float64[])), "series", "no ledgers")
        @test EF.refused(EF.caught(() -> Coupling.signatures(EF.to_air(m), series, [1.0, 2.0])), "series",
                         "does not hold the crossing quantities")
    end
end

@testset "arrival order never reaches an exchange's result" begin
    m = EF.mesh()
    a = EF.assembly()
    forward = EF.to_river(m)
    backward = EF.to_river(m; crossings = (EF.crossing(:soil_water, m.coarse), EF.crossing(:runoff, m.coarse)))
    @test Coupling.crossing_names(forward) == Coupling.crossing_names(backward) == (:runoff, :soil_water)
    numbers(ledgers) = [(Fields.residual(getfield(l, k)), Fields.tolerance(getfield(l, k)))
                        for l in values(ledgers) for k in (:operator, :receipt)]
    @test numbers(only(EF.exchanged(a, m, forward, [100.0]))) == numbers(only(EF.exchanged(a, m, backward, [100.0])))
end

@testset "a crossing between devices moves through Backends.on and closes on the reader's device" begin
    @test CUDA.functional()
    m = EF.mesh()
    a = Coupling.assemble(EF.snowpack(), EF.sea(), EF.lake();
                          initial_conditions = (EF.initial(:snow, 2),
                                                EF.initial(:sea_water, 1; backend = Backends.GPU()),
                                                EF.initial(:lake_water, 2; backend = Backends.GPU())),
                          sequence = 1, instant = 0.0, tier = :fast)
    gpu(x) = Backends.on(x, Backends.GPU())
    nf, nc = length(m.fine_area), length(m.coarse_area)
    interval, before = Time.Interval(0.0, 100.0), Time.Interval(-100.0, 0.0)
    state = Coupling.WorldState(a; initial = (
        lake_water = EF.field(m.fine, gpu(EF.varying(nf, 0.3)), Fields.Extensive(), EF.endpoint(before)),
        sea_water = EF.field(m.coarse, gpu(EF.varying(nc, 0.5)), Fields.Extensive(), EF.endpoint(before)),
        snow = EF.field(m.fine, EF.varying(nf, 0.9), Fields.Extensive(), EF.endpoint(before))))
    Coupling.begin_step!(state)
    snow = EF.varying(nf, 1.7)
    Coupling.write_quantity!(state, :snowpack, :snow, EF.field(m.fine, snow, Fields.Extensive(), EF.endpoint(interval)))
    Coupling.write_quantity!(state, :snowpack, :melt,
                             EF.field(m.fine, EF.varying(nf, 2.1), Fields.Extensive(), EF.accumulated(interval)))
    Coupling.write_quantity!(state, :snowpack, :sublimation,
                             EF.field(m.fine, EF.varying(nf, 2.5), Fields.FluxDensity(), EF.mean_over(interval)))
    handing(q, to, support) = EF.exchange(m; from = :snowpack, to = to, crossings = (EF.crossing(q, support),))

    _, to_sea = Coupling.exchange!(state, handing(:melt, :sea, m.coarse), interval; sequence = 1, tier = :fast)
    @test to_sea.melt.operator isa Fields.Ledger{:total}
    @test Fields.closed(to_sea.melt.operator)
    @test Fields.closed(to_sea.melt.receipt)
    @test Fields.data(Coupling.read_quantity(state, :sea, :melt)) isa CUDA.CuArray

    _, to_lake = Coupling.exchange!(state, handing(:snow, :lake, m.fine), interval; sequence = 1, tier = :fast)
    @test to_lake.snow.operator === Coupling.NoOperator()
    @test Fields.closed(to_lake.snow.receipt)
    received = Fields.data(Coupling.read_quantity(state, :lake, :snow))
    @test received isa CUDA.CuArray
    @test Backends.on(received, Backends.CPU()) == snow

    e = EF.caught(() -> Coupling.exchange!(state, handing(:sublimation, :lake, m.fine), interval;
                                           sequence = 1, tier = :fast))
    @test EF.refused(e, "sublimation", "declares the primal_cell_area measure, and its crossing is given none")
    over_area = EF.exchange(m; from = :snowpack, to = :lake,
                            crossings = (EF.crossing(:sublimation, m.fine; measure = EF.area(m)),))
    _, to_lake = Coupling.exchange!(state, over_area, interval; sequence = 1, tier = :fast)
    @test to_lake.sublimation.operator === Coupling.NoOperator()
    @test to_lake.sublimation.receipt isa Fields.Ledger{:primal_cell_area_integral}
    @test Fields.closed(to_lake.sublimation.receipt)
end

@testset "a move alone closes its receipt ledger under the measure its read declares, between devices both ways" begin
    @test CUDA.functional()
    m = EF.mesh()
    ex = EF.to_sink(m)
    ws = EF.windows()
    for (from, to) in ((Backends.CPU(), Backends.GPU()), (Backends.GPU(), Backends.CPU()))
        @testset "$(nameof(typeof(from))) to $(nameof(typeof(to)))" begin
            state, interval, written = EF.moved(from, to, m, 100.0)
            _, ledgers = Coupling.exchange!(state, ex, interval; sequence = 1, tier = :fast)
            @test all(q -> ledgers[q].operator === Coupling.NoOperator(), keys(ledgers))
            @test ledgers.pool.receipt isa Fields.ColumnLedgers{:total}
            @test ledgers.vapour.receipt isa Fields.Ledger{:primal_cell_area_integral}
            @test ledgers.vapour_columns.receipt isa Fields.ColumnLedgers{:primal_cell_area_integral}
            @test size(Fields.ledgers(ledgers.pool.receipt)) == size(Fields.ledgers(ledgers.vapour_columns.receipt)) == (3,)
            @test all(q -> Fields.closed(ledgers[q].receipt), keys(ledgers))
            @test all(l -> Fields.tolerance(l) > 0, (ledgers.vapour.receipt, Fields.ledgers(ledgers.vapour_columns.receipt)...))
            for q in keys(written)
                received = Fields.data(Coupling.read_quantity(state, :sink, q))
                @test received isa Backends.array_type(to)
                @test Backends.on(received, Backends.CPU()) == written[q]
            end

            @testset "positive control: a move that doubles one cell's value opens its receipt ledger, a Leak beside Rounding" begin
                series = EF.moved_staged(from, to, m, ex, ws, EF.first_cell_doubled((:vapour, :vapour_columns)))
                @test all(l -> !Fields.closed(l.vapour.receipt), series)
                @test all(l -> !Fields.closed(Fields.ledger_of(l.vapour_columns.receipt, 1)), series)
                @test all(l -> Fields.closed(Fields.ledger_of(l.vapour_columns.receipt, 2)), series)
                found = Coupling.signatures(ex, series, ws)
                @test length(found) == 1 + 3 + 3
                receipt(q, column) = only(s.signature for s in found
                                          if s.quantity === q && s.ledger === :receipt && s.column == column)
                @test receipt(:vapour, nothing) === Fields.Leak()
                @test receipt(:vapour_columns, (1,)) === Fields.Leak()
                @test receipt(:vapour_columns, (2,)) === receipt(:vapour_columns, (3,)) === Fields.Rounding()
                @test all(c -> receipt(:pool, (c,)) === Fields.Rounding(), 1:3)
            end

            @testset "an open move receipt is journalled by column and refused" begin
                state, _, _ = EF.moved(from, to, m, 100.0)
                handed = Coupling.hand_over(state, ex)
                stage = EF.first_cell_doubled((:vapour_columns,))
                foreach(h -> Coupling.receive!(state, :sink, h.crossing.quantity, stage(h)), values(handed))
                e, events = EF.journal(() -> Coupling.settle(state, ex, handed; sequence = 4, instant = 100.0, tier = :fast))
                @test EF.refused(e, "vapour_columns receipt primal_cell_area_integral column (1,)", "is open")
                @test [event.payload.ledger for event in events] == ["vapour_columns receipt primal_cell_area_integral column (1,)"]
            end
        end
    end
end
