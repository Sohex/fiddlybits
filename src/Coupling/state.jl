# WorldState, the component declaration and assemble:
# docs/plans/fiddlybits-52v.11-coupling.md, section "The state and its assembly";
# decision 0009. Every check, search and ordering here visits component names and
# quantity names in sorted order, so the order `assemble` is given its components in
# reaches no result (decision 0029).

using ..Verdicts: Refusal, refuse
using ..Events: Events
using ..Backends: Backend, array_type
using ..Systems: Systems, Checked, read_keywords, require_type, require_path
using ..Fields: Fields, Field

"The component name every event this module emits carries."
const COMPONENT = "Coupling"

"""
    CONSERVED

The conserved quantities a write carries and a stock reports, by name (decision 0009).
"""
const CONSERVED = (:mass, :energy, :water, :salt, :carbon, :nitrogen, :phosphorus,
                   :angular_momentum)

# ---------------------------------------------------------------- checks

"""
    require_level(quantity, site, level)

`level` when it is an `Int` from 0 to `Systems.FINEST_INDEXABLE_LEVEL`; refuses at
`site` naming `quantity` otherwise.
"""
function require_level(quantity::AbstractString, site::AbstractString, level)
    level isa Int || refuse(quantity, site, "a $(typeof(level)) where a level, an Int, is required")
    0 <= level <= Systems.FINEST_INDEXABLE_LEVEL || refuse(
        quantity, site,
        "level $(level) lies outside 0 to $(Systems.FINEST_INDEXABLE_LEVEL), the levels " *
        "of the hierarchy an Int indexes")
    return level
end

"""
    require_symbols(quantity, site, given, within)

`given` when it is a tuple of distinct `Symbol`s, empty or not, each in `within` when
`within` is not `nothing`; refuses at `site` naming `quantity` otherwise.
"""
function require_symbols(quantity::AbstractString, site::AbstractString, given, within)
    (given isa Tuple && all(x -> x isa Symbol, given)) || refuse(
        quantity, site, "$(repr(given)) is not a tuple of names")
    allunique(given) || refuse(quantity, site, "$(given) names one member twice")
    if within !== nothing
        for x in given
            x in within || refuse(quantity, site, "$(x) is not one of $(join(within, ", "))")
        end
    end
    return given
end

"""
    require_members(quantity, site, given, T, key)

`given` when it is a tuple, empty or not, of `T` values whose `key` names are
distinct; refuses at `site` naming `quantity` otherwise.
"""
function require_members(quantity::AbstractString, site::AbstractString, given, T::Type,
                         key::Symbol)
    given isa Tuple || refuse(quantity, site, "a $(typeof(given)) where a tuple of $(T) is required")
    for x in given
        require_type(quantity, site, x, T)
    end
    names = map(x -> getfield(x, key), given)
    allunique(names) || refuse(
        quantity, site, "$(names) names one $(key) twice")
    return given
end

"The name of `backend`'s type, which is the device it runs on."
device_label(backend::Backend) = nameof(typeof(backend))

"`true` when `a` and `b` hold arrays of the one type `Backends.array_type` names."
same_device(a::Backend, b::Backend) = array_type(a) === array_type(b)

# ---------------------------------------------------------------- operators

"""
    Operator

How a read reaches the level it names from the level its quantity is written at:
`AtLevel`, `Coarsen` or `Refine`.
"""
abstract type Operator end

"The coarsening rule the semantics of the coarsened field fixes, where it names no `Fields.Rule`."
struct RuleOfSemantics end

"An operator that integrates over no measure."
struct NoMeasure end

"""
    require_measure(site, measure)

`measure` when it is a name in `Fields.MEASURE_NAMES` or a `NoMeasure`; refuses at
`site` otherwise.
"""
function require_measure(site::AbstractString, measure)
    measure isa NoMeasure || (measure isa Symbol && measure in Fields.MEASURE_NAMES) || refuse(
        "measure", site,
        "$(repr(measure)) is not one of $(join(map(repr, Fields.MEASURE_NAMES), ", ")), " *
        "or NoMeasure()")
    return measure
end

"""
    AtLevel(; measure)

A read at the level its quantity is written at, through no operator, with `measure`, a
name in `Fields.MEASURE_NAMES` or `NoMeasure()`: the measure the receipt of a move of
its quantity is integrated under, which `assemble` checks by `require_measures`.
"""
struct AtLevel{M} <: Operator
    measure::M

    AtLevel{M}(::Checked, m) where {M} = new{M}(m)
end

function AtLevel(; kwargs...)
    site = "Coupling.AtLevel"
    k, _ = read_keywords(site, values(kwargs), (:measure,), ())
    measure = require_measure(site, k.measure)
    return AtLevel{typeof(measure)}(Checked(), measure)
end

"""
    Coarsen(; rule, measure)

A read at a coarser level than its quantity is written at, through `Fields.coarsen`
under `rule`, a `Fields.Rule` or `RuleOfSemantics()`, over `measure`, a name in
`Fields.MEASURE_NAMES` or `NoMeasure()`.
"""
struct Coarsen{R,M} <: Operator
    rule::R
    measure::M

    Coarsen{R,M}(::Checked, r, m) where {R,M} = new{R,M}(r, m)
end

function Coarsen(; kwargs...)
    site = "Coupling.Coarsen"
    k, _ = read_keywords(site, values(kwargs), (:rule, :measure), ())
    rule = require_type("rule", site, k.rule, Union{Fields.Rule,RuleOfSemantics})
    measure = require_measure(site, k.measure)
    return Coarsen{typeof(rule),typeof(measure)}(Checked(), rule, measure)
end

"""
    Refine(; measure)

A read at a finer level than its quantity is written at, through `Fields.refine` over
`measure`, a name in `Fields.MEASURE_NAMES` or `NoMeasure()`.
"""
struct Refine{M} <: Operator
    measure::M

    Refine{M}(::Checked, m) where {M} = new{M}(m)
end

function Refine(; kwargs...)
    site = "Coupling.Refine"
    k, _ = read_keywords(site, values(kwargs), (:measure,), ())
    measure = require_measure(site, k.measure)
    return Refine{typeof(measure)}(Checked(), measure)
end

"""
    operator_for(read_level, source_level)

The operator type a read at `read_level` of a quantity at `source_level` names:
`AtLevel` at the same level, `Coarsen` at a coarser (smaller) level, `Refine` at a
finer one.
"""
operator_for(read_level::Int, source_level::Int) =
    read_level == source_level ? AtLevel : read_level < source_level ? Coarsen : Refine

# ---------------------------------------------------------------- the declaration

"""
    Read(; quantity, level, operator, lagged, move)

One read of a component: the `quantity` by name, the `level` it is read at, the
`Operator` that reaches that level, whether it is `lagged` (read as it stood at the
start of the step rather than as written in it), and whether it declares a `move`
between devices.
"""
struct Read{O<:Operator}
    quantity::Symbol
    level::Int
    operator::O
    lagged::Bool
    move::Bool

    Read{O}(::Checked, q, l, o, lag, m) where {O} = new{O}(q, l, o, lag, m)
end

function Read(; kwargs...)
    site = "Coupling.Read"
    k, _ = read_keywords(site, values(kwargs), (:quantity, :level, :operator, :lagged, :move), ())
    quantity = require_type("quantity", site, k.quantity, Symbol)
    level = require_level("level", site, k.level)
    operator = require_type("operator", site, k.operator, Operator)
    lagged = require_type("lagged", site, k.lagged, Bool)
    move = require_type("move", site, k.move, Bool)
    return Read{typeof(operator)}(Checked(), quantity, level, operator, lagged, move)
end

"`true` when `r` is served across a crossing: an operator other than `AtLevel`, or a move."
crossing(r::Read) = !(r.operator isa AtLevel) || r.move

"""
    Write(; quantity, semantics, conserves)

One write of a component: the `quantity` by name, written at the component's level;
`semantics`, the `Fields.Semantics` every field placed for it carries; and `conserves`,
the tuple of names from `CONSERVED` it carries an amount of, empty when it carries
none.
"""
struct Write{S<:Fields.Semantics,C}
    quantity::Symbol
    semantics::S
    conserves::C

    Write{S,C}(::Checked, q, s, c) where {S,C} = new{S,C}(q, s, c)
end

function Write(; kwargs...)
    site = "Coupling.Write"
    k, _ = read_keywords(site, values(kwargs), (:quantity, :semantics, :conserves), ())
    quantity = require_type("quantity", site, k.quantity, Symbol)
    semantics = require_type("semantics", site, k.semantics, Fields.Semantics)
    conserves = require_symbols("conserves", site, k.conserves, CONSERVED)
    return Write{typeof(semantics),typeof(conserves)}(Checked(), quantity, semantics, conserves)
end

"The `Write` of `quantity` in the declaration `d`, which writes it."
write_of(d, quantity::Symbol) = d.writes[findfirst(w -> w.quantity === quantity, d.writes)]

"The name of the semantics `s`, as `Fields` prints it."
semantics_name(s::Fields.Semantics) = Fields.type_name(typeof(s))

"""
    Stock(; conserved, quantities)

A stock a component reports: the `conserved` quantity, a name from `CONSERVED`, and
`quantities`, the one or more quantities it writes whose amounts are its inventory of
it.
"""
struct Stock{Q}
    conserved::Symbol
    quantities::Q

    Stock{Q}(::Checked, c, q) where {Q} = new{Q}(c, q)
end

function Stock(; kwargs...)
    site = "Coupling.Stock"
    k, _ = read_keywords(site, values(kwargs), (:conserved, :quantities), ())
    conserved = require_type("conserved", site, k.conserved, Symbol)
    conserved in CONSERVED || refuse(
        "conserved", site, "$(conserved) is not one of $(join(CONSERVED, ", "))")
    quantities = require_symbols("quantities", site, k.quantities, nothing)
    isempty(quantities) && refuse("quantities", site, "the stock of $(conserved) names no quantity")
    return Stock{typeof(quantities)}(Checked(), conserved, quantities)
end

"""
    Declaration(; name, level, reads, writes, stocks, system_fields, profile_fields, backend)

What a component declares (decision 0009): its `name`; the `level` it writes at; its
`reads`, a tuple of `Read` naming each quantity once; its `writes`, a tuple of `Write`
naming each quantity once; its `stocks`, a tuple of `Stock` naming each conserved
quantity once; `system_fields`, a tuple of distinct paths from a `System` in the
grammar of `Systems.affected`; `profile_fields`, a tuple of distinct paths from a
`Systems.Profile` in the same grammar, a component's own entry of the profile's
components reached as `(:components, name, ...)`; and the `Backend` it runs on. Every
tuple may be empty. Refuses, naming the component, a profile path that is empty or
whose first step is `:label`, each of which reaches the profile's label (decision 0010,
section What the key names).
"""
struct Declaration{R,W,S,P,Q,B<:Backend}
    name::Symbol
    level::Int
    reads::R
    writes::W
    stocks::S
    system_fields::P
    profile_fields::Q
    backend::B

    Declaration{R,W,S,P,Q,B}(::Checked, n, l, r, w, s, p, q, b) where {R,W,S,P,Q,B} =
        new{R,W,S,P,Q,B}(n, l, r, w, s, p, q, b)
end

"""
    require_paths(quantity, site, name, paths)

`paths` when it is a tuple of distinct paths, each a tuple of steps; refuses at `site`
naming `quantity` otherwise.
"""
function require_paths(quantity::AbstractString, site::AbstractString, name::Symbol, paths)
    paths isa Tuple || refuse(quantity, site, "a $(typeof(paths)) where a tuple of paths is required")
    foreach(p -> require_path(site, name, p), paths)
    allunique(paths) || refuse(quantity, site, "$(paths) names one path twice")
    return paths
end

function Declaration(; kwargs...)
    site = "Coupling.Declaration"
    k, _ = read_keywords(site, values(kwargs),
                         (:name, :level, :reads, :writes, :stocks, :system_fields,
                          :profile_fields, :backend), ())
    name = require_type("name", site, k.name, Symbol)
    level = require_level("level", site, k.level)
    reads = require_members("reads", site, k.reads, Read, :quantity)
    writes = require_members("writes", site, k.writes, Write, :quantity)
    stocks = require_members("stocks", site, k.stocks, Stock, :conserved)
    paths = require_paths("system_fields", site, name, k.system_fields)
    profile_paths = require_paths("profile_fields", site, name, k.profile_fields)
    for p in profile_paths
        (isempty(p) || first(p) === :label) && refuse(
            "profile_fields", site,
            "$(name) declares $(p), which reaches the profile's label, a name and not a " *
            "setting (decision 0010)")
    end
    backend = require_type("backend", site, k.backend, Backend)
    return Declaration{typeof(reads),typeof(writes),typeof(stocks),typeof(paths),
                       typeof(profile_paths),typeof(backend)}(
        Checked(), name, level, reads, writes, stocks, paths, profile_paths, backend)
end

"""
    InitialCondition(; quantity, level, backend)

A quantity present before any component writes it: the `quantity` by name, the
`level` it is placed at and the `Backend` whose device holds it.
"""
struct InitialCondition{B<:Backend}
    quantity::Symbol
    level::Int
    backend::B

    InitialCondition{B}(::Checked, q, l, b) where {B} = new{B}(q, l, b)
end

function InitialCondition(; kwargs...)
    site = "Coupling.InitialCondition"
    k, _ = read_keywords(site, values(kwargs), (:quantity, :level, :backend), ())
    quantity = require_type("quantity", site, k.quantity, Symbol)
    level = require_level("level", site, k.level)
    backend = require_type("backend", site, k.backend, Backend)
    return InitialCondition{typeof(backend)}(Checked(), quantity, level, backend)
end

"""
    declare(component)

The `Declaration` of `component`. A component type adds a method; `assemble` refuses a
component that has none.
"""
function declare end

"""
    step!(component, state, interval, constants)

Advances `component` over the `Time.Interval` `interval`, reading and writing the
`WorldState` `state` through `read_quantity` and `write_quantity!`, with `constants`
the stripped constants (decision 0007). A component type adds a method.
"""
function step! end

# ---------------------------------------------------------------- assembly

"""
    Assembly

The wired system `assemble` returns: the components and their declarations in
evaluation order, the declared writer of each written quantity, and the initial
conditions by quantity. Built by `assemble`, never directly.
"""
struct Assembly
    components::Vector{Any}
    declarations::Vector{Declaration}
    index::Dict{Symbol,Int}
    writers::Dict{Symbol,Symbol}
    initial_conditions::Dict{Symbol,InitialCondition}
end

"The component names of `a` in evaluation order."
order(a::Assembly) = [d.name for d in a.declarations]

"""
    declaration(a, name)

The `Declaration` of the component `name` in `a`; refuses a name `a` does not hold.
"""
function declaration(a::Assembly, name::Symbol)
    haskey(a.index, name) || refuse(String(name), "Coupling.declaration",
                                    "$(name) is not a component of the assembly")
    return a.declarations[a.index[name]]
end

"""
    writer(a, quantity)

The declared writer of `quantity` in `a`, or `nothing` when it has none.
"""
writer(a::Assembly, quantity::Symbol) = get(a.writers, quantity, nothing)

"""
    declared_graph(a)

The declared graph of `a` as `Systems.affected` and `Systems.dependency_subset` read
it: a `Dict` from each component's name to the `Set` of the system paths it declares.
"""
declared_graph(a::Assembly) =
    Dict{Symbol,Set{Tuple}}(d.name => Set{Tuple}(d.system_fields) for d in a.declarations)

"""
    declared_profile_graph(a)

The declared profile graph of `a` as `Systems.affected` and `Systems.dependency_subset`
read it over a `Systems.Profile`: a `Dict` from each component's name to the `Set` of the
profile paths it declares.
"""
declared_profile_graph(a::Assembly) =
    Dict{Symbol,Set{Tuple}}(d.name => Set{Tuple}(d.profile_fields) for d in a.declarations)

"""
    declaration_of(site, component)

`declare(component)`; refuses at `site` when `component` has no `declare` method or
its method returns something other than a `Declaration`.
"""
function declaration_of(site::AbstractString, component)
    hasmethod(declare, Tuple{typeof(component)}) || refuse(
        string(typeof(component)), site, "a $(typeof(component)) has no declare method")
    d = declare(component)
    d isa Declaration || refuse(
        string(typeof(component)), site,
        "declare of a $(typeof(component)) returns a $(typeof(d)), not a Declaration")
    return d
end

"The first name that `names`, sorted, holds twice, or `nothing`."
function first_repeated(names)
    s = sort(collect(names))
    i = findfirst(j -> s[j] === s[j+1], 1:(length(s) - 1))
    return i === nothing ? nothing : s[i]
end

"""
    require_one_writer(site, declarations)

The declared writer of each written quantity of `declarations`, sorted by name, as a
`Dict`. Refuses at `site`, naming the quantity and its writers, the first quantity by
name with more than one.
"""
function require_one_writer(site::AbstractString, declarations)
    writers = Dict{Symbol,Vector{Symbol}}()
    for d in declarations, w in d.writes
        push!(get!(writers, w.quantity, Symbol[]), d.name)
    end
    for q in sort(collect(keys(writers)))
        ws = writers[q]
        length(ws) == 1 || refuse(
            String(q), site,
            "$(q) has $(length(ws)) declared writers, $(join(ws, ", ")); a quantity has one")
    end
    return Dict(q => only(ws) for (q, ws) in writers)
end

"""
    require_stocks(site, declarations)

Refuses at `site`, naming the component: a stock in a quantity its component does not
write, and a write carrying a conserved quantity its component declares no stock of.
"""
function require_stocks(site::AbstractString, declarations)
    for d in declarations
        written = Set(w.quantity for w in d.writes)
        for s in sort(collect(d.stocks); by = s -> s.conserved), q in sort(collect(s.quantities))
            q in written || refuse(
                String(d.name), site,
                "$(d.name) declares its stock of $(s.conserved) in $(q), which it does not write")
        end
        reported = Set(s.conserved for s in d.stocks)
        for w in sort(collect(d.writes); by = w -> w.quantity), c in sort(collect(w.conserves))
            c in reported || refuse(
                String(d.name), site,
                "$(d.name) writes $(w.quantity), which carries $(c), and cannot report a " *
                "stock of $(c)")
        end
    end
    return nothing
end

"""
    source(declarations_by_name, writers, initial, quantity)

`(level, backend, holder)` of `quantity`: the level and backend of its declared
writer and the writer's name, or those of its initial condition and the text
`"its initial condition"` when it has no writer.
"""
function source(by_name, writers, initial, quantity::Symbol)
    if haskey(writers, quantity)
        d = by_name[writers[quantity]]
        return d.level, d.backend, String(d.name)
    end
    ic = initial[quantity]
    return ic.level, ic.backend, "its initial condition"
end

"""
    require_initial_agrees(site, by_name, writers, initial)

Refuses at `site`, naming the quantity, an initial condition whose level or device
differs from its declared writer's.
"""
function require_initial_agrees(site::AbstractString, by_name, writers, initial)
    for q in sort(collect(keys(initial)))
        haskey(writers, q) || continue
        ic, d = initial[q], by_name[writers[q]]
        ic.level == d.level || refuse(
            String(q), site,
            "the initial condition of $(q) is at level $(ic.level) and its writer " *
            "$(d.name) writes it at level $(d.level)")
        same_device(ic.backend, d.backend) || refuse(
            String(q), site,
            "the initial condition of $(q) is on $(device_label(ic.backend)) and its " *
            "writer $(d.name) runs on $(device_label(d.backend))")
    end
    return nothing
end

"""
    require_sources(site, declarations, by_name, writers, initial)

Refuses at `site`, naming the quantity, the first read by component and quantity
name that: has no writer and no initial condition; is lagged with no initial
condition; names an operator other than `operator_for` its level and its quantity's;
reads a quantity held on another device with no declared move; or declares a move
where its quantity is held on the reader's device.
"""
function require_sources(site::AbstractString, declarations, by_name, writers, initial)
    for d in declarations, r in sort(collect(d.reads); by = r -> r.quantity)
        q = r.quantity
        haskey(writers, q) || haskey(initial, q) || refuse(
            String(q), site, "$(d.name) reads $(q), which has no writer and no initial condition")
        r.lagged && !haskey(initial, q) && refuse(
            String(q), site,
            "$(d.name) reads $(q) lagged, and $(q) has no initial condition for the first " *
            "step's lagged read")
        level, backend, holder = source(by_name, writers, initial, q)
        expected = operator_for(r.level, level)
        r.operator isa expected || refuse(
            String(q), site,
            "$(d.name) reads $(q) at level $(r.level) through $(nameof(typeof(r.operator))), " *
            "and $(holder) holds $(q) at level $(level), which a read reaches through " *
            "$(nameof(expected))")
        agree = same_device(d.backend, backend)
        agree && r.move && refuse(
            String(q), site,
            "$(d.name) declares a move of $(q), which $(holder) holds on " *
            "$(device_label(backend)), the device $(d.name) runs on")
        agree || r.move || refuse(
            String(q), site,
            "$(d.name) runs on $(device_label(d.backend)) and reads $(q), which $(holder) " *
            "holds on $(device_label(backend)), with no declared move")
    end
    return nothing
end

"""
    move_measure(semantics)

The measure a move through `AtLevel` of a quantity written with `semantics` and
carrying a conserved quantity declares, as the type its `measure` is: `NoMeasure` for
`Fields.Extensive`, whose receipt is its total; `Symbol`, a measure name, for
`Fields.FluxDensity`, `Fields.Fraction` and `Fields.Intensive`, whose receipt is the
integral under that measure; `nothing` for every other semantics.
"""
move_measure(::Fields.Extensive) = NoMeasure
move_measure(::Union{Fields.FluxDensity,Fields.Fraction,Fields.Intensive}) = Symbol
move_measure(::Fields.Semantics) = nothing

"""
    require_measures(site, declarations, by_name, writers)

Refuses at `site`, naming the quantity, the first read through `AtLevel` by component
and quantity name that: declares a measure name and is not a move of a quantity whose
`Write` carries a conserved quantity; moves a quantity carrying a conserved quantity
whose semantics `move_measure` gives `nothing`; or declares a measure other than of the
type `move_measure` gives for the semantics of the quantity it moves.
"""
function require_measures(site::AbstractString, declarations, by_name, writers)
    for d in declarations, r in sort(collect(d.reads); by = r -> r.quantity)
        r.operator isa AtLevel || continue
        q = r.quantity
        m = r.operator.measure
        w = haskey(writers, q) ? write_of(by_name[writers[q]], q) : nothing
        if !r.move || w === nothing || isempty(w.conserves)
            m isa NoMeasure || refuse(
                String(q), site,
                "$(d.name) declares the $(m) measure on its read of $(q) through AtLevel, " *
                (r.move ? "a move of a quantity carrying no conserved quantity" : "which is not a move") *
                ", and no receipt of it is integrated")
            continue
        end
        name = semantics_name(w.semantics)
        carried = "$(writers[q]) writes as $(name) carrying $(join(w.conserves, ", "))"
        expected = move_measure(w.semantics)
        expected === nothing && refuse(
            String(q), site,
            "$(d.name) moves $(q), which $(carried), and a $(name) field holds no amount a " *
            "receipt ledger closes")
        m isa expected && continue
        refuse(String(q), site,
               expected === NoMeasure ?
               "$(d.name) declares the $(m) measure on its move of $(q), which $(carried), " *
               "whose receipt is its total over no measure" :
               "$(d.name) moves $(q), which $(carried), through AtLevel declaring no measure, " *
               "and its receipt is the integral under a declared measure")
    end
    return nothing
end

"""
    require_read(site, declarations, writers, initial)

Refuses at `site`, naming the quantity, the first by name that: its writer writes and
no component reads; stands as an initial condition with no writer and no read; or
stands as an initial condition beside a writer with no lagged read.
"""
function require_read(site::AbstractString, declarations, writers, initial)
    read = Set(r.quantity for d in declarations for r in d.reads)
    lagged = Set(r.quantity for d in declarations for r in d.reads if r.lagged)
    for q in sort(collect(keys(writers)))
        q in read || refuse(String(q), site, "$(writers[q]) writes $(q), which nothing reads")
    end
    for q in sort(collect(keys(initial)))
        if haskey(writers, q)
            q in lagged || refuse(
                String(q), site,
                "the initial condition of $(q) is read by no lagged read, and every other " *
                "read of $(q) reads what $(writers[q]) writes in the step")
        else
            q in read || refuse(String(q), site, "the initial condition of $(q) is read by nothing")
        end
    end
    return nothing
end

"`true` when `r` makes an edge of the intra-step graph: a read that is not lagged."
in_step(r::Read) = !r.lagged

"""
    intra_step_edges(declarations, writers)

The intra-step graph of `declarations`: a `Dict` from a writer's name to a `Dict` from
each component that reads one of its quantities `in_step` to the sorted names of
those quantities. A read of a quantity with no writer makes no edge.
"""
function intra_step_edges(declarations, writers)
    edges = Dict{Symbol,Dict{Symbol,Vector{Symbol}}}()
    for d in declarations, r in d.reads
        in_step(r) || continue
        haskey(writers, r.quantity) || continue
        to = get!(edges, writers[r.quantity], Dict{Symbol,Vector{Symbol}}())
        push!(get!(to, d.name, Symbol[]), r.quantity)
    end
    foreach(to -> foreach(sort!, values(to)), values(edges))
    return edges
end

"The components `u` has an edge to in `edges`, sorted."
successors(edges, u::Symbol) = haskey(edges, u) ? sort(collect(keys(edges[u]))) : Symbol[]

"""
    find_cycle(names, edges)

A cycle of the graph `edges` over `names` as the vector of its components in edge
order, the closing edge from the last to the first, rotated to start at its least
name; `nothing` when there is none. The search starts from each name in sorted order
and follows successors in sorted order.
"""
function find_cycle(names::Vector{Symbol}, edges)
    mark = Dict(n => 0 for n in names)
    stack = Symbol[]
    function visit(u)
        mark[u] = 1
        push!(stack, u)
        for v in successors(edges, u)
            mark[v] == 1 && return stack[findfirst(==(v), stack):end]
            if mark[v] == 0
                found = visit(v)
                found === nothing || return found
            end
        end
        pop!(stack)
        mark[u] = 2
        return nothing
    end
    for n in names
        mark[n] == 0 || continue
        found = visit(n)
        found === nothing && continue
        return circshift(found, 1 - argmin(found))
    end
    return nothing
end

"""
    cycle_text(cycle, edges)

`cycle` written as `a -(x)-> b -(y)-> a`, each arrow labelled with the quantities of
its edge joined by commas.
"""
function cycle_text(cycle::Vector{Symbol}, edges)
    io = IOBuffer()
    for (i, u) in enumerate(cycle)
        v = cycle[mod1(i + 1, length(cycle))]
        print(io, u, " -(", join(edges[u][v], ","), ")-> ")
    end
    print(io, first(cycle))
    return String(take!(io))
end

"""
    require_acyclic(site, names, edges)

Refuses at `site` with the cycle printed by `cycle_text` when `find_cycle` finds one.
"""
function require_acyclic(site::AbstractString, names::Vector{Symbol}, edges)
    cycle = find_cycle(names, edges)
    cycle === nothing || refuse(
        "intra-step cycle", site,
        "the reads that are not lagged form the cycle $(cycle_text(cycle, edges))")
    return nothing
end

"""
    evaluation_order(names, edges)

A topological order of the acyclic graph `edges` over `names`: each step takes the
least name, by sort, among the components every writer of whose in-step reads is
already placed.
"""
function evaluation_order(names::Vector{Symbol}, edges)
    indegree = Dict(n => 0 for n in names)
    for u in names, v in successors(edges, u)
        indegree[v] += 1
    end
    ready = sort([n for n in names if indegree[n] == 0])
    placed = Symbol[]
    while !isempty(ready)
        u = popfirst!(ready)
        push!(placed, u)
        for v in successors(edges, u)
            indegree[v] -= 1
            indegree[v] == 0 && push!(ready, v)
        end
        sort!(ready)
    end
    return placed
end

"""
    wire(site, components, initial_conditions)

The `Assembly` of `components`, running every check of `assemble` in its order.
"""
function wire(site::AbstractString, components::Tuple, initial_conditions)
    isempty(components) && refuse("components", site, "no component is given")
    given = [declaration_of(site, c) for c in components]
    repeated = first_repeated(d.name for d in given)
    repeated === nothing || refuse(String(repeated), site, "two components are named $(repeated)")
    by_name = Dict(d.name => d for d in given)
    component_by_name = Dict(d.name => c for (c, d) in zip(components, given))
    names = sort(collect(keys(by_name)))
    declarations = [by_name[n] for n in names]

    ics = require_members("initial_conditions", site, initial_conditions, InitialCondition, :quantity)
    initial = Dict{Symbol,InitialCondition}(ic.quantity => ic for ic in ics)

    writers = require_one_writer(site, declarations)
    require_stocks(site, declarations)
    require_initial_agrees(site, by_name, writers, initial)
    require_sources(site, declarations, by_name, writers, initial)
    require_measures(site, declarations, by_name, writers)
    require_read(site, declarations, writers, initial)
    edges = intra_step_edges(declarations, writers)
    require_acyclic(site, names, edges)

    placed = evaluation_order(names, edges)
    return Assembly(Any[component_by_name[n] for n in placed],
                    Declaration[by_name[n] for n in placed],
                    Dict(n => i for (i, n) in enumerate(placed)), writers, initial)
end

"""
    assemble(components...; initial_conditions, sequence, instant, tier)

The `Assembly` of `components`, each declared through `declare`, with
`initial_conditions` a tuple of `InitialCondition` naming each quantity once. Refuses,
in this order: a component with no `declare` method; two components of one name; a
quantity with more than one declared writer; a stock in a quantity its component does
not write, and a write carrying a conserved quantity its component cannot report a
stock of; an initial condition whose level or device differs from its writer's; a
read with no writer and no initial condition, a lagged read with no initial
condition, a read whose operator does not reach its level from its quantity's, a read
of a quantity on another device with no declared move, and a declared move within one
device; a read through `AtLevel` whose measure `require_measures` refuses; a written
quantity nothing reads, and an initial condition nothing reads; an
intra-step cycle once the lagged reads are removed, with the cycle printed.

Every refusal raised past the keyword checks is handed to `Events.emit` as a `refusal`
event numbered `sequence`, at `instant` on `tier`, from `COMPONENT`, and then
rethrown.
"""
function assemble(components...; kwargs...)
    site = "Coupling.assemble"
    k, _ = read_keywords(site, values(kwargs), (:initial_conditions, :sequence, :instant, :tier), ())
    sequence = require_type("sequence", site, k.sequence, Integer)
    instant = require_type("instant", site, k.instant, Real)
    tier = require_type("tier", site, k.tier, Symbol)
    try
        return wire(site, components, k.initial_conditions)
    catch err
        err isa Refusal &&
            Events.emit(Events.Event(Events.Refusal(), sequence, instant, tier, COMPONENT, err))
        rethrow()
    end
end

# ---------------------------------------------------------------- the store

"""
    WorldState(assembly; initial)

The store of `assembly`'s quantities. `initial` is a `NamedTuple` holding a
`Fields.Field` for exactly the quantities `assembly` has initial conditions for, each
at its initial condition's level with an array of the type `Backends.array_type`
names for its backend, and with the semantics its declared writer's `Write` names
where it has one. A quantity's field type is fixed by its first placement.

The store holds each quantity's current field, the fields as they stood when the
current step began, which quantities have been written in the step, and the fields
received for crossing reads in the step. `begin_step!` begins a step; nothing is read,
written or received before the first.
"""
struct WorldState
    assembly::Assembly
    lock::ReentrantLock
    current::Dict{Symbol,Field}
    lagged::Dict{Symbol,Field}
    written::Set{Symbol}
    received::Dict{Tuple{Symbol,Symbol},Field}
    types::Dict{Any,Type}
    steps::Base.RefValue{Int}
end

"""
    require_placement(site, quantity, field, level, backend)

Refuses at `site`, naming `quantity`, a `field` that is not a `Fields.Field`, is not
at `level`, or holds an array other than of the type `Backends.array_type(backend)`.
"""
function require_placement(site::AbstractString, quantity::Symbol, field, level::Int,
                           backend::Backend)
    field isa Field || refuse(String(quantity), site, "a $(typeof(field)) where a Fields.Field is required")
    Fields.level(field) == level || refuse(
        String(quantity), site, "$(Fields.describe(field)) is placed where level $(level) is declared")
    Fields.data(field) isa array_type(backend) || refuse(
        String(quantity), site,
        "the field holds a $(typeof(Fields.data(field))), and $(device_label(backend)) holds " *
        "a $(array_type(backend))")
    return field
end

"""
    require_declared_semantics(site, assembly, quantity, field)

Refuses at `site`, naming `quantity`, a `field` whose semantics differ from those the
`Write` of `quantity` by its declared writer in `assembly` names. Returns `nothing` for
a quantity with no declared writer.
"""
function require_declared_semantics(site::AbstractString, assembly::Assembly, quantity::Symbol,
                                    field::Field)
    w = writer(assembly, quantity)
    w === nothing && return nothing
    declared = write_of(declaration(assembly, w), quantity).semantics
    Fields.semantics(field) === declared || refuse(
        String(quantity), site,
        "$(Fields.describe(field)) is placed for $(quantity), which $(w) declares it writes " *
        "as $(semantics_name(declared))")
    return nothing
end

"""
    require_type_fixed!(site, state, key, quantity, field)

Records `typeof(field)` under `key` at its first placement; refuses at `site`, naming
`quantity`, a field of any other type at a later one.
"""
function require_type_fixed!(site::AbstractString, state::WorldState, key, quantity::Symbol,
                             field::Field)
    fixed = get!(state.types, key, typeof(field))
    fixed === typeof(field) || refuse(
        String(quantity), site,
        "$(Fields.describe(field)) is a $(typeof(field)), and $(quantity) was first placed " *
        "as a $(fixed)")
    return nothing
end

function WorldState(assembly::Assembly; kwargs...)
    site = "Coupling.WorldState"
    k, _ = read_keywords(site, values(kwargs), (:initial,), ())
    initial = require_type("initial", site, k.initial, NamedTuple)
    expected = sort(collect(keys(assembly.initial_conditions)))
    given = sort(collect(keys(initial)))
    for q in expected
        q in given || refuse(String(q), site, "the initial condition of $(q) is given no field")
    end
    for q in given
        q in expected || refuse(String(q), site, "a field is given for $(q), which has no initial condition")
    end
    state = WorldState(assembly, ReentrantLock(), Dict{Symbol,Field}(), Dict{Symbol,Field}(),
                       Set{Symbol}(), Dict{Tuple{Symbol,Symbol},Field}(), Dict{Any,Type}(), Ref(0))
    for q in given
        ic = assembly.initial_conditions[q]
        field = require_placement(site, q, initial[q], ic.level, ic.backend)
        require_declared_semantics(site, assembly, q, field)
        require_type_fixed!(site, state, q, q, field)
        state.current[q] = field
    end
    return state
end

"""
    begin_step!(state)

Begins a step: the fields every lagged read reads become the current fields, and no
quantity is written or received in the step yet. Returns `state`.
"""
function begin_step!(state::WorldState)
    @lock state.lock begin
        empty!(state.lagged)
        merge!(state.lagged, state.current)
        empty!(state.written)
        empty!(state.received)
        state.steps[] += 1
    end
    return state
end

"Refuses at `site` when no step of `state` has begun."
require_step(site::AbstractString, state::WorldState) =
    state.steps[] > 0 || refuse("step", site, "no step has begun; begin_step! begins one")

"""
    declared_read(site, assembly, reader, quantity)

The `Read` of `quantity` the component `reader` declares; refuses at `site` when
`reader` is not a component of `assembly` or declares no such read.
"""
function declared_read(site::AbstractString, assembly::Assembly, reader::Symbol, quantity::Symbol)
    haskey(assembly.index, reader) || refuse(String(reader), site, "$(reader) is not a component of the assembly")
    reads = declaration(assembly, reader).reads
    i = findfirst(r -> r.quantity === quantity, reads)
    i === nothing && refuse(String(quantity), site, "$(reader) declares no read of $(quantity)")
    return reads[i]
end

"""
    source_field(state, reader, quantity)

The field the read of `quantity` by `reader` is taken from, at its quantity's level
and on its quantity's device: as it stood when the step began for a lagged read, and
as written in the step otherwise. Refuses a read `reader` does not declare, a read
before the first step, and a read that is not lagged of a quantity its writer has not
yet written in the step.
"""
function source_field(state::WorldState, reader::Symbol, quantity::Symbol)
    site = "Coupling.source_field"
    r = declared_read(site, state.assembly, reader, quantity)
    return @lock state.lock source_locked(site, state, reader, r)
end

function source_locked(site::AbstractString, state::WorldState, reader::Symbol, r::Read)
    require_step(site, state)
    q = r.quantity
    r.lagged && return state.lagged[q]
    w = writer(state.assembly, q)
    w === nothing || q in state.written || refuse(
        String(q), site,
        "$(reader) reads $(q) as written in the step, and its writer $(w) has not written it " *
        "in this step")
    return state.current[q]
end

"""
    read_quantity(state, reader, quantity)

The field `reader` reads for `quantity`: `source_field` for a read that is not a
crossing, and the field `receive!` placed in the step for a crossing read. Refuses a
crossing read nothing has been received for in the step, and whatever `source_field`
refuses.
"""
function read_quantity(state::WorldState, reader::Symbol, quantity::Symbol)
    site = "Coupling.read_quantity"
    r = declared_read(site, state.assembly, reader, quantity)
    @lock state.lock begin
        crossing(r) || return source_locked(site, state, reader, r)
        require_step(site, state)
        key = (reader, quantity)
        haskey(state.received, key) || refuse(
            String(quantity), site,
            "$(reader) reads $(quantity) across a crossing, and nothing has been received " *
            "for it in this step")
        return state.received[key]
    end
end

"""
    write_quantity!(state, writer, quantity, field)

Places `field` as the current value of `quantity`, written by `writer`. Refuses a
`writer` that is not the declared writer of `quantity`, a write before the first step,
a second write of `quantity` in one step, a field `require_placement` refuses at the
writer's level and backend, a field of other semantics than the writer's `Write` of
`quantity` names, a field of another type than `quantity` was first placed as, and a field holding the array its quantity held when the step began. Returns
`state`.
"""
function write_quantity!(state::WorldState, writer_name::Symbol, quantity::Symbol, field)
    site = "Coupling.write_quantity!"
    declared = writer(state.assembly, quantity)
    declared === writer_name || refuse(
        String(quantity), site,
        declared === nothing ? "$(writer_name) writes $(quantity), which has no declared writer" :
        "$(writer_name) writes $(quantity), whose declared writer is $(declared)")
    d = declaration(state.assembly, writer_name)
    @lock state.lock begin
        require_step(site, state)
        quantity in state.written && refuse(
            String(quantity), site, "$(writer_name) has already written $(quantity) in this step")
        require_placement(site, quantity, field, d.level, d.backend)
        require_declared_semantics(site, state.assembly, quantity, field)
        require_type_fixed!(site, state, quantity, quantity, field)
        haskey(state.lagged, quantity) && Fields.data(state.lagged[quantity]) === Fields.data(field) &&
            refuse(String(quantity), site,
                   "the field holds the array $(quantity) held when the step began, which its " *
                   "lagged reads read")
        state.current[quantity] = field
        push!(state.written, quantity)
    end
    return state
end

"""
    receive!(state, reader, quantity, field)

Places `field` as what the crossing read of `quantity` by `reader` reads in this step.
Refuses a read `reader` does not declare, a read that is not a crossing, a receipt
before the first step, a second receipt for the read in one step, a field
`require_placement` refuses at the read's level and the reader's backend, and a field
of another type than the read first received. Returns `state`.
"""
function receive!(state::WorldState, reader::Symbol, quantity::Symbol, field)
    site = "Coupling.receive!"
    r = declared_read(site, state.assembly, reader, quantity)
    crossing(r) || refuse(
        String(quantity), site,
        "$(reader) reads $(quantity) at its own level on its own device, which is not a crossing")
    d = declaration(state.assembly, reader)
    key = (reader, quantity)
    @lock state.lock begin
        require_step(site, state)
        haskey(state.received, key) && refuse(
            String(quantity), site, "$(reader) has already received $(quantity) in this step")
        require_placement(site, quantity, field, r.level, d.backend)
        require_type_fixed!(site, state, key, quantity, field)
        state.received[key] = field
    end
    return state
end
