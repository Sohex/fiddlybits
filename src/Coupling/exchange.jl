# Exchange and exchange!: docs/plans/fiddlybits-52v.11-coupling.md, section "Exchanges";
# decision 0009; docs/requirements/sys/exchanges-have-one-owner-per-flux-and-carry-their-fraction.md
# (REQ-SYS-009) and docs/requirements/num/closure-tolerance-from-floating-point.md
# (REQ-NUM-004). Crossings are held and visited in quantity order and conserved
# quantities in name order, so the order an exchange is declared in reaches no result
# (decision 0029).

using ..Backends: on
using ..Mesh: Mesh
using ..Time: Time

# ---------------------------------------------------------------- declarations

"The legend of a crossing whose field is not a `Fields.CategoricalLabel`."
struct NoLegend end

"""
    Crossing(; quantity, support, measure, legend)

One quantity an `Exchange` hands over: the `quantity` by name; the `Mesh.Support` its
reader reads it on; `measure`, a `Fields.Measured` at the finer of the writer's and the
reader's levels under the name the read's operator declares, or `NoMeasure()` where the
operator declares none; and `legend`, the tuple of distinct classes a
`Fields.CategoricalLabel` field is reduced over, or `NoLegend()`.
"""
struct Crossing{S<:Mesh.Support,M,G}
    quantity::Symbol
    support::S
    measure::M
    legend::G

    Crossing{S,M,G}(::Checked, q, s, m, g) where {S,M,G} = new{S,M,G}(q, s, m, g)
end

function Crossing(; kwargs...)
    site = "Coupling.Crossing"
    k, _ = read_keywords(site, values(kwargs), (:quantity, :support, :measure, :legend), ())
    quantity = require_type("quantity", site, k.quantity, Symbol)
    support = require_type("support", site, k.support, Mesh.Support)
    measure = require_type("measure", site, k.measure, Union{Fields.Measured,NoMeasure})
    legend = k.legend
    legend isa NoLegend || (legend isa Tuple && !isempty(legend) && allunique(legend)) || refuse(
        "legend", site, "$(repr(legend)) is neither a tuple of distinct classes nor NoLegend()")
    return Crossing{typeof(support),typeof(measure),typeof(legend)}(Checked(), quantity, support,
                                                                    measure, legend)
end

"""
    Recomputed(; quantity, replacing)

A term of a replayed forcing its receiver recomputes against its live state: the
`quantity` the receiver writes, and `replacing`, the name of the forcing term it is
written in place of.
"""
struct Recomputed
    quantity::Symbol
    replacing::Symbol

    Recomputed(::Checked, q, r) = new(q, r)
end

function Recomputed(; kwargs...)
    site = "Coupling.Recomputed"
    k, _ = read_keywords(site, values(kwargs), (:quantity, :replacing), ())
    quantity = require_type("quantity", site, k.quantity, Symbol)
    replacing = require_type("replacing", site, k.replacing, Symbol)
    quantity === replacing && refuse(String(quantity), site, "$(quantity) is declared to replace itself")
    return Recomputed(Checked(), quantity, replacing)
end

"""
    Classification(; false_alarm, permutations, draw)

What `signatures` hands `Fields.classify` for every ledger series of an exchange: the
false-alarm probability `false_alarm`, the permutation count `permutations`, and
`draw`, called as `draw(identity, counter)` for a `UInt64`, `identity` the
`(from, to, quantity, ledger, class)` of the series and `counter` the counter
`Fields.classify` reads. `Fields.classify` refuses what it cannot run at.
"""
struct Classification{A<:Real,D}
    false_alarm::A
    permutations::Int
    draw::D

    Classification{A,D}(::Checked, a, p, d) where {A,D} = new{A,D}(a, p, d)
end

function Classification(; kwargs...)
    site = "Coupling.Classification"
    k, _ = read_keywords(site, values(kwargs), (:false_alarm, :permutations, :draw), ())
    false_alarm = require_type("false_alarm", site, k.false_alarm, Real)
    permutations = require_type("permutations", site, k.permutations, Integer)
    return Classification{typeof(false_alarm),typeof(k.draw)}(Checked(), false_alarm,
                                                              Int(permutations), k.draw)
end

"""
    Exchange(; from, to, crossings, conserved, replayed, recomputed, classification)

A crossing of quantities from the component `from`, their declared writer, to the
component `to`, their reader (decision 0009): `crossings`, a non-empty tuple of
`Crossing` naming each quantity once; `conserved`, the names from `CONSERVED` the
exchange balances; `replayed`, the names of the crossing quantities taken from a
stored cycle rather than handed over live; `recomputed`, a tuple of `Recomputed` naming
the terms `to` recomputes against its live state; and the `Classification` its ledger
series are classified under. Every tuple but `crossings` may be empty.

Refuses: an exchange of a component with itself; a replayed name the crossings do not
hold; a `Recomputed` whose quantity or replaced term is a crossing quantity; two
`Recomputed` replacing one term. The crossings are held in quantity order and the
names in name order.
"""
struct Exchange{C<:Tuple,K<:Tuple,P<:Tuple,R<:Tuple,F<:Classification}
    from::Symbol
    to::Symbol
    crossings::C
    conserved::K
    replayed::P
    recomputed::R
    classification::F

    Exchange{C,K,P,R,F}(::Checked, a, b, c, k, p, r, f) where {C,K,P,R,F} =
        new{C,K,P,R,F}(a, b, c, k, p, r, f)
end

function Exchange(; kwargs...)
    site = "Coupling.Exchange"
    k, _ = read_keywords(site, values(kwargs),
                         (:from, :to, :crossings, :conserved, :replayed, :recomputed,
                          :classification), ())
    from = require_type("from", site, k.from, Symbol)
    to = require_type("to", site, k.to, Symbol)
    from === to && refuse("to", site, "$(from) is declared to exchange with itself")
    given = require_members("crossings", site, k.crossings, Crossing, :quantity)
    isempty(given) && refuse("crossings", site, "the exchange from $(from) to $(to) hands over no quantity")
    handed = Set(c.quantity for c in given)
    conserved = require_symbols("conserved", site, k.conserved, CONSERVED)
    replayed = require_symbols("replayed", site, k.replayed, nothing)
    for q in sort(collect(replayed))
        q in handed || refuse(String(q), site,
                              "$(q) is declared replayed, and the exchange from $(from) to $(to) " *
                              "hands over no $(q)")
    end
    recomputed = require_members("recomputed", site, k.recomputed, Recomputed, :quantity)
    replaced = map(r -> r.replacing, recomputed)
    allunique(replaced) || refuse("recomputed", site, "$(replaced) names one replaced term twice")
    for r in sort(collect(recomputed); by = r -> r.quantity)
        r.replacing in handed && refuse(
            String(r.replacing), site,
            "$(to) is declared to recompute $(r.replacing) as $(r.quantity), and the exchange " *
            "hands $(r.replacing) over from $(from); a flux handed over is not recomputed by " *
            "its receiver")
        r.quantity in handed && refuse(
            String(r.quantity), site,
            "$(to) is declared to recompute $(r.quantity), and the exchange hands " *
            "$(r.quantity) over from $(from)")
    end
    classification = require_type("classification", site, k.classification, Classification)
    crossings = Tuple(sort(collect(given); by = c -> c.quantity))
    names(t) = Tuple(sort(collect(t)))
    recomputes = Tuple(sort(collect(recomputed); by = r -> r.quantity))
    return Exchange{typeof(crossings),typeof(names(conserved)),typeof(names(replayed)),
                    typeof(recomputes),typeof(classification)}(
        Checked(), from, to, crossings, names(conserved), names(replayed), recomputes,
        classification)
end

"The quantity names of the crossings of `ex`, in quantity order."
crossing_names(ex::Exchange) = map(c -> c.quantity, ex.crossings)

# ---------------------------------------------------------------- the declared graph

"The `Write` of `quantity` in the declaration `d`, which writes it."
write_of(d::Declaration, quantity::Symbol) = d.writes[findfirst(w -> w.quantity === quantity, d.writes)]

"The quantities the declaration `d` names in any of its stocks."
stocked(d::Declaration) = Set(q for s in d.stocks for q in s.quantities)

"The measure name `operator` declares: `NoMeasure()` for `AtLevel`."
declared_measure(::AtLevel) = NoMeasure()
declared_measure(op::Coarsen) = op.measure
declared_measure(op::Refine) = op.measure

"""
    require_declared_measure(site, quantity, operator, measure)

Refuses at `site`, naming `quantity`: a `Fields.Measured` where `operator` declares no
measure; `NoMeasure()` where it declares one; a `Fields.Measured` under another name
than it declares.
"""
function require_declared_measure(site::AbstractString, quantity::Symbol, operator::Operator, measure)
    name = declared_measure(operator)
    op = nameof(typeof(operator))
    if name isa NoMeasure
        measure isa NoMeasure || refuse(
            String(quantity), site,
            "the read of $(quantity) through $(op) declares no measure, and its crossing is " *
            "given the $(Fields.measure_name(measure)) measure")
        return nothing
    end
    measure isa Fields.Measured || refuse(
        String(quantity), site,
        "the read of $(quantity) through $(op) declares the $(name) measure, and its crossing " *
        "is given none")
    Fields.measure_name(measure) === name || refuse(
        String(quantity), site,
        "the read of $(quantity) through $(op) declares the $(name) measure, and its crossing " *
        "is given the $(Fields.measure_name(measure)) measure")
    return nothing
end

"""
    require_exchange(site, assembly, ex)

Refuses at `site`, in this order: a `from` or `to` that is not a component of
`assembly`; a crossing quantity whose declared writer is not `from`; one `to` declares
no read of, or reads other than across a crossing; a crossing measure its read's
operator does not declare; a conserved quantity a crossing quantity carries, by its
`Write`, that `ex` does not name, and one `ex` names that no crossing quantity carries;
a replayed quantity whose writer `from` declares a read of a quantity `to` writes; a
recomputed quantity `to` does not write.
"""
function require_exchange(site::AbstractString, assembly::Assembly, ex::Exchange)
    source = declaration(assembly, ex.from)
    reader = declaration(assembly, ex.to)
    carried = Set{Symbol}()
    for c in ex.crossings
        q = c.quantity
        w = writer(assembly, q)
        w === ex.from || refuse(
            String(q), site,
            w === nothing ? "the exchange from $(ex.from) hands over $(q), which has no declared writer" :
            "the exchange from $(ex.from) hands over $(q), whose declared writer is $(w)")
        r = declared_read(site, assembly, ex.to, q)
        crossing(r) || refuse(
            String(q), site,
            "$(ex.to) reads $(q) at its own level on its own device, which is not a crossing")
        require_declared_measure(site, q, r.operator, c.measure)
        union!(carried, write_of(source, q).conserves)
    end
    for c in sort(collect(carried))
        c in ex.conserved || refuse(
            String(c), site,
            "a quantity the exchange from $(ex.from) to $(ex.to) hands over carries $(c), " *
            "which the exchange does not balance")
    end
    for c in ex.conserved
        c in carried || refuse(
            String(c), site,
            "the exchange from $(ex.from) to $(ex.to) balances $(c), which no quantity it " *
            "hands over carries")
    end
    written = Set(w.quantity for w in reader.writes)
    for q in ex.replayed, r in sort(collect(source.reads); by = r -> r.quantity)
        r.quantity in written && refuse(
            String(q), site,
            "$(q) is declared replayed, and its writer $(ex.from) reads $(r.quantity), which " *
            "$(ex.to) writes; a term that depends on its receiver's state is recomputed " *
            "against it")
    end
    for r in ex.recomputed
        r.quantity in written || refuse(
            String(r.quantity), site,
            "$(ex.to) is declared to recompute $(r.quantity), which it does not write")
    end
    return nothing
end

# ---------------------------------------------------------------- the hand-over

"The operator ledger of a crossing that runs no operator: a move between devices alone."
struct NoOperator end

"The receipt ledger of a crossing quantity that carries no conserved quantity."
struct NoReceipt end

"""
    HandOver

One crossing quantity handed over and not yet received: the `Crossing`, the read's
`operator`, the conserved quantities it `carries`, whether its writer stocks it
(`reservoir`), the reader's `backend`, the `source` field and the `measure` on that
backend, and the `result` and `ledger` the operator returned. Built by `hand_over`.
"""
struct HandOver{C,O,B,S,M,R,L}
    crossing::C
    operator::O
    carries::Tuple
    reservoir::Bool
    backend::B
    source::S
    measure::M
    result::R
    ledger::L
end

"`f` with its array moved to `backend` through `Backends.on`; `f` itself when it is there."
function moved_field(f::Field, backend::Backend)
    d = on(Fields.data(f), backend)
    d === Fields.data(f) && return f
    return Field(semantics = Fields.semantics(f), dimension = Fields.dimension(f), data = d,
                 support = Fields.support(f), time = Fields.time_support(f),
                 origin = Fields.origin(f))
end

"`measure` with its values moved to `backend` through `Backends.on`."
moved_measure(::NoMeasure, ::Backend) = NoMeasure()
moved_measure(m::Fields.Measured, backend::Backend) =
    Fields.Measured{Fields.measure_name(m)}(on(Fields.values_of(m), backend))

"""
    operator_keywords(c, measure, reservoir, backend)

The keywords a conserving operator takes for the crossing `c`: `legend` and `measure`
where `c` declares them, then `reservoir` and `backend`.
"""
operator_keywords(c::Crossing, measure, reservoir::Bool, backend::Backend) =
    merge(legend_keyword(c.legend), measure_keyword(measure),
          (reservoir = reservoir, backend = backend))

legend_keyword(::NoLegend) = NamedTuple()
legend_keyword(legend::Tuple) = (legend = legend,)
measure_keyword(::NoMeasure) = NamedTuple()
measure_keyword(m::Fields.Measured) = (measure = m,)

"""
    reduce_by(site, operator, f, c, measure, reservoir, backend)

`(field, ledger)` of the destination operator of the crossing `c` on `f`: `f` and
`NoOperator()` for `AtLevel`, refusing a support other than `c`'s; `Fields.coarsen`
onto `c.support` for `Coarsen`, under its rule where it names one, refusing a measure
beside a `Fields.ToQuantiles` rule; `Fields.refine` onto `c.support` for `Refine`, with
no keywords where it declares no measure.
"""
function reduce_by(site::AbstractString, ::AtLevel, f::Field, c::Crossing, measure,
                   reservoir::Bool, backend::Backend)
    Mesh.require_same_support(Fields.support(f), c.support, site)
    return f, NoOperator()
end

reduce_by(site::AbstractString, op::Coarsen, f::Field, c::Crossing, measure, reservoir::Bool,
          backend::Backend) = coarsen_by(site, op.rule, f, c, measure, reservoir, backend)

reduce_by(site::AbstractString, op::Refine, f::Field, c::Crossing, measure, reservoir::Bool,
          backend::Backend) = refine_by(op.measure, f, c, measure, reservoir, backend)

coarsen_by(site::AbstractString, ::RuleOfSemantics, f, c, measure, reservoir, backend) =
    Fields.coarsen(f, c.support; operator_keywords(c, measure, reservoir, backend)...)

coarsen_by(site::AbstractString, rule::Fields.Rule, f, c, measure, reservoir, backend) =
    Fields.coarsen(f, c.support, rule; operator_keywords(c, measure, reservoir, backend)...)

function coarsen_by(site::AbstractString, rule::Fields.ToQuantiles, f, c, measure, reservoir,
                    backend)
    measure isa NoMeasure || refuse(
        String(c.quantity), site,
        "the read of $(c.quantity) coarsens to a quantile table, which takes no measure")
    return Fields.coarsen(f, c.support, rule; backend = backend)
end

refine_by(::NoMeasure, f, c, measure, reservoir, backend) = Fields.refine(f, c.support)
refine_by(::Symbol, f, c, measure, reservoir, backend) =
    Fields.refine(f, c.support; operator_keywords(c, measure, reservoir, backend)...)

"""
    hand_over(state, ex)

A `NamedTuple` from each crossing quantity of `ex`, in quantity order, to its
`HandOver`: the field `source_field` serves the read of it by `ex.to`, moved to the
backend `ex.to` runs on through `Backends.on`, taken through the destination operator
by `reduce_by` with the crossing's measure moved alongside, `reservoir` when `ex.from`
names the quantity in a stock. Receives nothing. Refuses whatever `require_exchange`,
`source_field` and the operator refuse.
"""
function hand_over(state::WorldState, ex::Exchange)
    site = "Coupling.hand_over"
    assembly = state.assembly
    require_exchange(site, assembly, ex)
    source = declaration(assembly, ex.from)
    backend = declaration(assembly, ex.to).backend
    reservoirs = stocked(source)
    entries = map(ex.crossings) do c
        q = c.quantity
        r = declared_read(site, assembly, ex.to, q)
        f = moved_field(source_field(state, ex.to, q), backend)
        measure = moved_measure(c.measure, backend)
        reservoir = q in reservoirs
        result, ledger = reduce_by(site, r.operator, f, c, measure, reservoir, backend)
        HandOver(c, r.operator, write_of(source, q).conserves, reservoir, backend, f, measure,
                 result, ledger)
    end
    return NamedTuple{crossing_names(ex)}(entries)
end

"""
    require_conserving(site, handed)

Refuses at `site`, naming the quantity, the first `HandOver` of `handed` in quantity
order that carries a conserved quantity and whose operator returned a
`Fields.NotConserved`, with its sentence, or a `Fields.ClassLedgers`.
"""
function require_conserving(site::AbstractString, handed::NamedTuple)
    for h in values(handed)
        isempty(h.carries) && continue
        h.ledger isa Fields.NotConserved && refuse(
            String(h.crossing.quantity), site,
            "$(h.crossing.quantity) carries $(join(h.carries, ", ")), and its operator " *
            "conserves nothing: " * h.ledger.sentence)
        h.ledger isa Fields.ClassLedgers && refuse(
            String(h.crossing.quantity), site,
            "$(h.crossing.quantity) carries $(join(h.carries, ", ")), and its operator " *
            "balances the area of each class, which is no amount of it")
    end
    return nothing
end

"""
    deliver!(state, ex, handed)

`receive!` of the result of each `HandOver` of `handed` for the read of its quantity by
`ex.to`, in quantity order. Returns `state`.
"""
function deliver!(state::WorldState, ex::Exchange, handed::NamedTuple)
    foreach(h -> receive!(state, ex.to, h.crossing.quantity, h.result), values(handed))
    return state
end

# ---------------------------------------------------------------- the ledgers

"""
    CrossingLedgers

What an exchange records for one quantity: the `quantity`, the conserved quantities it
`carries`, the `operator` ledger its destination operator returned (a `Fields.Ledger`,
`Fields.ClassLedgers`, `Fields.NotConserved`, or `NoOperator()`), and its `receipt`
ledger (a `Fields.Ledger`, or `NoReceipt()` for a quantity carrying no conserved
quantity).
"""
struct CrossingLedgers{O,R}
    quantity::Symbol
    carries::Tuple
    operator::O
    receipt::R
end

"""
    receipt_ledger(site, h, received)

The `Fields.Ledger` of the field `received` the reader holds against the result of the
`HandOver` `h`, both at the reader's level on `h.backend`, in `Float64` over the
result's cell count, `reservoir` as `h` declares:

- after an operator ledger of the total, and after `NoOperator()` on an `Extensive`
  field: `Fields.total_ledger` from the result to `received`;
- after an operator ledger of the integral under `h.measure`: `Fields.integral_ledger`
  from the result to `received`, each weighted by the measure at the reader's level,
  with the terms the result so weighted; that measure is `Fields.coarse_measure` over
  `Fields.child_segmentation` in the source's element type after a `Coarsen`, and
  `h.measure` after a `Refine`.

Refuses an operator ledger of an integral under another measure, a
`Fields.ClassLedgers`, a `Fields.NotConserved`, and `NoOperator()` on a field that is
not `Extensive`, the last naming fiddlybits-52v.11.5.
"""
receipt_ledger(site::AbstractString, h::HandOver, received::Field) =
    receipt_by(site, h.ledger, h, received)

total_receipt(h::HandOver, received::Field) =
    Fields.total_ledger(Float64, length(Fields.data(h.result)), Fields.data(h.result),
                        Fields.data(received); reservoir = h.reservoir, backend = h.backend)

receipt_by(site::AbstractString, ::Fields.Ledger{:total}, h::HandOver, received::Field) =
    total_receipt(h, received)

function receipt_by(site::AbstractString, ::Fields.Ledger{Q}, h::HandOver,
                    received::Field) where {Q}
    m = h.measure
    (m isa Fields.Measured && Fields.integral_quantity(m) === Q) || refuse(
        String(h.crossing.quantity), site,
        "the operator of $(h.crossing.quantity) balances $(Q), which is not the integral " *
        "under the measure its crossing declares")
    data = Fields.data(h.result)
    weights = reader_weights(h.operator, h)
    return Fields.integral_ledger(Float64, length(data), m, (data, weights),
                                  (Fields.data(received), weights), (data, weights);
                                  reservoir = h.reservoir, backend = h.backend)
end

reader_weights(::Refine, h::HandOver) = Fields.values_of(h.measure)
reader_weights(::Coarsen, h::HandOver) =
    Fields.coarse_measure(eltype(Fields.data(h.source)), h.measure,
                          Fields.child_segmentation(h.source, h.crossing.support, h.backend),
                          h.backend)

receipt_by(site::AbstractString, ::Fields.ClassLedgers, h::HandOver, received::Field) = refuse(
    String(h.crossing.quantity), site,
    "$(h.crossing.quantity) carries $(join(h.carries, ", ")), and its operator balances the " *
    "area of each class, which is no amount of it")

receipt_by(site::AbstractString, n::Fields.NotConserved, h::HandOver, received::Field) = refuse(
    String(h.crossing.quantity), site,
    "$(h.crossing.quantity) carries $(join(h.carries, ", ")), and its operator conserves " *
    "nothing: " * n.sentence)

receipt_by(site::AbstractString, ::NoOperator, h::HandOver, received::Field) =
    move_receipt(site, h.source, h, received)

move_receipt(site::AbstractString, ::Field{Fields.Extensive}, h::HandOver, received::Field) =
    total_receipt(h, received)

move_receipt(site::AbstractString, f::Field, h::HandOver, received::Field) = refuse(
    String(h.crossing.quantity), site,
    "$(h.crossing.quantity) carries $(join(h.carries, ", ")) as $(Fields.describe(f)) across " *
    "a move alone, whose read declares no measure a receipt integral is taken over; " *
    "fiddlybits-52v.11.5 carries it")

"""
    measure_ledgers(state, ex, handed)

A `NamedTuple` from each crossing quantity of `ex`, in quantity order, to its
`CrossingLedgers`: the operator ledger its `HandOver` in `handed` holds, and the
`receipt_ledger` of the field `read_quantity` serves `ex.to` for it, or `NoReceipt()`
for a quantity that carries no conserved quantity. Refuses a `handed` that is not a
`HandOver` for each crossing quantity of `ex` in its order, and whatever
`read_quantity` and `receipt_ledger` refuse.
"""
function measure_ledgers(state::WorldState, ex::Exchange, handed::NamedTuple)
    site = "Coupling.measure_ledgers"
    (keys(handed) == crossing_names(ex) && all(h -> h isa HandOver, values(handed))) || refuse(
        "handed", site,
        "a hand-over of $(keys(handed)) is given, and the exchange from $(ex.from) to " *
        "$(ex.to) hands over $(crossing_names(ex))")
    entries = map(values(handed)) do h
        q = h.crossing.quantity
        receipt = isempty(h.carries) ? NoReceipt() :
            receipt_ledger(site, h, read_quantity(state, ex.to, q))
        CrossingLedgers(q, h.carries, h.ledger, receipt)
    end
    return NamedTuple{keys(handed)}(entries)
end

# ---------------------------------------------------------------- the journal

"""
    ledger_label(quantity, kind, ledger)

`"quantity kind name"`, `name` the conserved quantity `ledger` balances; `"quantity
kind"` for a ledger that names none.
"""
ledger_label(quantity::Symbol, kind::Symbol, l::Union{Fields.Ledger,Fields.ClassLedgers}) =
    "$(quantity) $(kind) $(Fields.quantity(l))"
ledger_label(quantity::Symbol, kind::Symbol, ::Any) = "$(quantity) $(kind)"

"""
    open_ledgers(label, ledger)

The `(label, ledger)` pairs of the `Fields.Ledger`s in `ledger` that are not
`Fields.closed`: `ledger` itself, or each class ledger of a `Fields.ClassLedgers` with
its class after `label`. None for a `Fields.NotConserved`, `NoOperator()` or
`NoReceipt()`.
"""
open_ledgers(label::String, l::Fields.Ledger) = Fields.closed(l) ? () : ((label, l),)
open_ledgers(label::String, c::Fields.ClassLedgers) =
    Tuple(p for (class, l) in zip(Fields.classes(c), Fields.ledgers(c))
          for p in open_ledgers("$(label) $(class)", l))
open_ledgers(::String, ::Union{Fields.NotConserved,NoOperator,NoReceipt}) = ()

"""
    journalled(f, journal)

`f()`. A `Verdicts.Refusal` it raises is handed to `Events.emit` as a `refusal` event
numbered `journal.sequence` at `journal.instant` on `journal.tier` from `COMPONENT`,
and rethrown.
"""
function journalled(f, journal::NamedTuple)
    try
        return f()
    catch err
        err isa Refusal && Events.emit(Events.Event(Events.Refusal(), journal.sequence,
                                                    journal.instant, journal.tier, COMPONENT,
                                                    err))
        rethrow()
    end
end

"""
    refuse_open(site, ex, open, journal)

`nothing` when `open` is empty. Otherwise hands a `ledger_open` event for each
`(label, ledger)` of `open`, in its order, to `Events.emit`, numbered
`journal.sequence` at `journal.instant` on `journal.tier` from `COMPONENT`, carrying
the label, the residual, the tolerance and the exchange as `"from -> to"`; then
refuses at `site` naming the first.
"""
function refuse_open(site::AbstractString, ex::Exchange, open::Tuple, journal::NamedTuple)
    isempty(open) && return nothing
    name = "$(ex.from) -> $(ex.to)"
    for (label, l) in open
        payload = Events.LedgerOpenPayload(ledger = label, imbalance = Fields.residual(l),
                                           tolerance = Fields.tolerance(l), exchange = name)
        Events.emit(Events.Event(Events.LedgerOpen(), journal.sequence, journal.instant,
                                 journal.tier, COMPONENT, payload))
    end
    label, l = first(open)
    more = length(open) - 1
    refuse(label, site,
           "the $(label) ledger of the exchange $(name) is open, residual $(Fields.residual(l)) " *
           "against tolerance $(Fields.tolerance(l))" *
           (more == 0 ? "" : ", and $(more) more ledgers of it are open"))
end

"""
    settled(site, state, ex, handed, journal)

`measure_ledgers(state, ex, handed)` under `journalled`, refused through `refuse_open`
when a receipt ledger is open.
"""
function settled(site::AbstractString, state::WorldState, ex::Exchange, handed::NamedTuple,
                 journal::NamedTuple)
    ledgers = journalled(() -> measure_ledgers(state, ex, handed), journal)
    open = Tuple(p for l in values(ledgers)
                 for p in open_ledgers(ledger_label(l.quantity, :receipt, l.receipt), l.receipt))
    refuse_open(site, ex, open, journal)
    return ledgers
end

"""
    settle(state, ex, handed; sequence, instant, tier)

The `measure_ledgers` of the hand-over `handed` of `ex` as `ex.to` holds it, refusing
when a receipt ledger is open: an open ledger journalled through `refuse_open` and
every other refusal through `journalled`, numbered `sequence` at `instant` on `tier`.
"""
function settle(state::WorldState, ex::Exchange, handed::NamedTuple; kwargs...)
    site = "Coupling.settle"
    k, _ = read_keywords(site, values(kwargs), (:sequence, :instant, :tier), ())
    journal = (sequence = require_type("sequence", site, k.sequence, Integer),
               instant = require_type("instant", site, k.instant, Real),
               tier = require_type("tier", site, k.tier, Symbol))
    return settled(site, state, ex, handed, journal)
end

"""
    exchange!(state, ex, interval; sequence, tier)

`(state, ledgers)`: each crossing quantity of `ex` handed over from `ex.from` to
`ex.to` over the `Time.Interval` `interval`, and a `NamedTuple` from each, in quantity
order, to its `CrossingLedgers`. In order: `hand_over` and `require_conserving`; the
operator ledgers through `refuse_open`, before anything is received; `deliver!`; the
receipt ledgers `measure_ledgers` measures on what `ex.to` holds, through
`refuse_open`. Events are numbered `sequence` at the end of `interval` on `tier`: an
open ledger is journalled as `ledger_open` events and every other refusal past the
keyword checks as a `refusal` event.
"""
function exchange!(state::WorldState, ex::Exchange, interval::Time.Interval; kwargs...)
    site = "Coupling.exchange!"
    k, _ = read_keywords(site, values(kwargs), (:sequence, :tier), ())
    journal = (sequence = require_type("sequence", site, k.sequence, Integer),
               instant = interval.t1.seconds,
               tier = require_type("tier", site, k.tier, Symbol))
    handed = journalled(journal) do
        h = hand_over(state, ex)
        require_conserving(site, h)
        h
    end
    open = Tuple(p for h in values(handed)
                 for p in open_ledgers(ledger_label(h.crossing.quantity, :operator, h.ledger),
                                       h.ledger))
    refuse_open(site, ex, open, journal)
    journalled(() -> deliver!(state, ex, handed), journal)
    return state, settled(site, state, ex, handed, journal)
end

"""
    conserved_ledgers(ledgers, conserved)

The entries of the `NamedTuple` `ledgers` an exchange returns whose quantity carries
`conserved`, in quantity order. Refuses a `conserved` not in `CONSERVED`.
"""
function conserved_ledgers(ledgers::NamedTuple, conserved::Symbol)
    conserved in CONSERVED || refuse(
        String(conserved), "Coupling.conserved_ledgers",
        "$(conserved) is not one of $(join(CONSERVED, ", "))")
    names = Tuple(q for q in keys(ledgers) if conserved in ledgers[q].carries)
    return NamedTuple{names}(map(q -> ledgers[q], names))
end

# ---------------------------------------------------------------- the residual signature

"""
    signatures(ex, series, windows)

The residual signature of every ledger series of `ex`, `series[i]` the `NamedTuple`
`exchange!` or `measure_ledgers` returned at `windows[i]`: a tuple of
`(quantity, ledger, class, carries, signature)` in quantity order, `ledger` `:operator`
before `:receipt`, one per class in legend order for a `Fields.ClassLedgers` with its
`class`, and `class = nothing` otherwise. `signature` is `Fields.classify` of the series
at `windows` with the `false_alarm` and `permutations` of `ex.classification`, and its
`draw` called as `draw(identity, counter)`, `identity` the
`(from, to, quantity, ledger, class)` of the series. A series of `Fields.NotConserved`
records its first as the signature, unclassified; a series of `NoOperator()` or
`NoReceipt()` records nothing.

Refuses an empty `series`, `series` and `windows` of different lengths, an entry that
does not hold the crossing quantities of `ex` in order, and a ledger whose type differs
between windows.
"""
function signatures(ex::Exchange, series::AbstractVector, windows::AbstractVector{<:Real})
    site = "Coupling.signatures"
    isempty(series) && refuse("series", site, "no ledgers are given to classify")
    length(series) == length(windows) || refuse(
        "series", site, "$(length(series)) entries are given at $(length(windows)) windows")
    names = crossing_names(ex)
    for s in series
        (s isa NamedTuple && keys(s) == names) || refuse(
            "series", site, "an entry does not hold the crossing quantities $(names) in order")
    end
    found = Any[]
    for q in names, kind in (:operator, :receipt)
        column = [getfield(s[q], kind) for s in series]
        append!(found, column_signatures(site, ex, q, kind, first(series)[q].carries, column,
                                         windows))
    end
    return Tuple(found)
end

"""
    column_signatures(site, ex, quantity, kind, carries, column, windows)

The entries `signatures` records for the series `column` of the `kind` ledger of
`quantity`.
"""
function column_signatures(site::AbstractString, ex::Exchange, q::Symbol, kind::Symbol,
                           carries::Tuple, column::AbstractVector, windows::AbstractVector)
    head = first(column)
    all(l -> typeof(l) === typeof(head), column) || refuse(
        String(q), site, "the $(kind) ledger of $(q) is not of one type at every window")
    head isa Union{NoOperator,NoReceipt} && return ()
    head isa Fields.NotConserved &&
        return ((quantity = q, ledger = kind, class = nothing, carries = carries, signature = head),)
    head isa Fields.Ledger && return (classified(ex, q, kind, nothing, carries, column, windows),)
    return Tuple(classified(ex, q, kind, class, carries, [Fields.ledger_of(l, class) for l in column],
                            windows)
                 for class in Fields.classes(head))
end

"""
    classified(ex, quantity, kind, class, carries, ledgers, windows)

The entry `signatures` records for the `Fields.Ledger` series `ledgers`.
"""
function classified(ex::Exchange, q::Symbol, kind::Symbol, class, carries::Tuple,
                    ledgers::AbstractVector, windows::AbstractVector)
    c = ex.classification
    identity = (from = ex.from, to = ex.to, quantity = q, ledger = kind, class = class)
    signature = Fields.classify(collect(ledgers), windows; false_alarm = c.false_alarm,
                                permutations = c.permutations,
                                draw = counter -> c.draw(identity, counter))
    return (quantity = q, ledger = kind, class = class, carries = carries, signature = signature)
end

