# coarsen, refine and time_reduce, dispatched on the type parameters:
# docs/plans/fiddlybits-52v.3-fields.md, sections "The operators and the refusal table"
# and "Ledgers".
#
# A combination that has no meaning has no working method and a declared refusal
# instead, and the refusals are the table below rather than scattered calls, so that
# the enumeration test of fiddlybits-52v.3.4 can read them. Every working method returns
# `(field, ledger)`; the ledger position holds a `Ledger`, a `ColumnLedgers`, a
# `ClassLedgers` or a `NotConserved` from the table that declares it.

using ..Mesh: ncells, require_ancestor
using ..Reductions: Segmentation, segmented_sum, segmented_mean, segmented_quantile,
                    segmented_weighted_sum, pairwise_sum, trailing_shape
using ..Backends: Backend, CPU, on
using ..Time: Forcing, Interval, IntervalMean, IntervalAccumulation, EndpointState,
              Instantaneous, Static, TimeSupport, duration

"""
    MEASURE_NAMES

The measures a reduction may integrate over, by name. Closed: REQ-TER-011 requires a
mesh to carry both its tiling measure and its operator measure and every reduction to
name which of them it used, and the predecessor's two duals differed per cell by more
than ten per cent on most cells.
"""
const MEASURE_NAMES = (:primal_cell_area, :dual_area)

"""
    MEASURE_INTEGRALS

The conserved quantity a ledger of an integral under each measure of `MEASURE_NAMES`
names: the measure's name followed by `_integral`, keyed by the measure's name.
"""
const MEASURE_INTEGRALS =
    NamedTuple{MEASURE_NAMES}(map(name -> Symbol(name, :_integral), MEASURE_NAMES))

"""
    Measured{Name}(values)

A measure's values together with the name of which measure they are. Every reduction
below that integrates over a measure takes one of these, so no call passes an
unqualified area.
"""
struct Measured{Name,V<:AbstractVector}
    values::V

    function Measured{Name,V}(values::V) where {Name,V<:AbstractVector}
        Name in MEASURE_NAMES || refuse(
            "measure name", "Fields.Measured",
            "$(repr(Name)) is not one of $(join(map(repr, MEASURE_NAMES), ", "))")
        return new{Name,V}(values)
    end
end

Measured{Name}(values::V) where {Name,V<:AbstractVector} = Measured{Name,V}(values)

"The name of the measure `m` holds."
measure_name(::Measured{Name}) where {Name} = Name

"The values of the measure `m` holds."
values_of(m::Measured) = m.values

"The quantity a ledger of the integral under `m` names, from `MEASURE_INTEGRALS`."
integral_quantity(::Measured{Name}) where {Name} = getfield(MEASURE_INTEGRALS, Name)

"""
    Rule

What a caller names when a semantics does not fix what a coarse cell is.
"""
abstract type Rule end

"The area-weighted mean over the measure the call names."
struct AreaMean <: Rule end

"The mean over the measure the call names, restricted to the cells a mask selects."
struct MaskedMean <: Rule end

"A table of the quantiles `P` within each coarse cell."
struct ToQuantiles{P} <: Rule end

"""
    REFUSAL_TABLE

Every combination that has no meaning, as data rather than as scattered `error` calls,
so `test/fields/semantics_closure.jl` reads the same table the methods raise from.

`semantics` and `time_semantics` are matched by subtyping, so the abstract type in
either slot means the entry does not constrain it. `rule` is the rule a caller could
have named and did not; `nothing` means the entry applies whatever was named.
"""
const REFUSAL_TABLE = (
    (operator = :coarsen, semantics = Intensive, time_semantics = TimeSemantics,
     rule = nothing,
     sentence = "the caller names what a coarse cell is: an area mean, a masked mean, or a quantile table"),
    (operator = :coarsen, semantics = VectorComponent{:east_north},
     time_semantics = TimeSemantics, rule = nothing,
     sentence = "lift to :cartesian at the source frames first, because east at one longitude is not east at another"),
    (operator = :refine, semantics = VectorComponent{:east_north},
     time_semantics = TimeSemantics, rule = nothing,
     sentence = "project at the destination frames instead, because east at one longitude is not east at another"),
    (operator = :coarsen, semantics = Quantiles, time_semantics = TimeSemantics,
     rule = nothing,
     sentence = "a quantile table is not re-aggregable; recompute from the fine field"),
    (operator = :refine, semantics = Quantiles, time_semantics = TimeSemantics,
     rule = nothing,
     sentence = "a quantile table is not a moment; recompute from the fine field"),
    (operator = :refine, semantics = CategoricalFraction, time_semantics = TimeSemantics,
     rule = nothing,
     sentence = "a histogram does not carry which child held which class"),
    (operator = :time_reduce, semantics = Semantics, time_semantics = Instantaneous,
     rule = nothing,
     sentence = "an instantaneous value has no interval to reduce over; name a sampling rule"),
    (operator = :time_reduce, semantics = Semantics, time_semantics = Static,
     rule = nothing,
     sentence = "a quantity with no time axis has no interval to reduce over"),
)

"""
    refusal_sentence(operator, S, T)

The sentence `REFUSAL_TABLE` declares for `operator` on a field of semantics `S` and
time semantics `T`, and refuses when the table declares none, because a refusing method
whose sentence is not in the table is the scattered `error` call the table exists to
replace.
"""
function refusal_sentence(operator::Symbol, S::Type, T::Type)
    for entry in REFUSAL_TABLE
        entry.operator === operator || continue
        S <: entry.semantics || continue
        T <: entry.time_semantics || continue
        return entry.sentence
    end
    refuse("refusal table", "Fields.refusal_sentence",
           "no entry declares why $(operator) refuses $(S) at $(T)")
end

"""
    refuse_declared(operator, f)

Raises the refusal `REFUSAL_TABLE` declares for `operator` on `f`. The one door every
refusing method below goes through.
"""
refuse_declared(operator::Symbol, ::Field{S,T}) where {S,T} =
    refuse("$(operator) of $(type_name(S))", "Fields.$(operator)",
           refusal_sentence(operator, S, T))

"""
    NOT_CONSERVED_TABLE

Every working combination whose operation conserves no quantity a ledger closes, as
data, so the methods that return a `NotConserved` and the tests that walk them read one
table.

`semantics` and `time_semantics` are matched by subtyping as in `REFUSAL_TABLE`. `rule`
is a type the rule the call named is matched against by subtyping, `Nothing` for a call
that names no rule.
"""
const NOT_CONSERVED_TABLE = (
    (operator = :coarsen, semantics = Intensive, time_semantics = TimeSemantics,
     rule = ToQuantiles,
     sentence = "a quantile table holds order statistics of the children, not an amount they sum to"),
    (operator = :refine, semantics = Intensive, time_semantics = TimeSemantics,
     rule = Nothing,
     sentence = "a spread intensive state gives each child the parent's value, and names no measure an amount is taken over"),
    (operator = :refine, semantics = VectorComponent{:cartesian},
     time_semantics = TimeSemantics, rule = Nothing,
     sentence = "a spread vector component gives each child the parent's value in its basis, which is not an amount"),
    (operator = :time_reduce, semantics = Semantics, time_semantics = EndpointState,
     rule = Nothing,
     sentence = "an endpoint state is the state at the last interval's end, and balances nothing across the series"),
)

"""
    not_conserved_sentence(operator, S, T, R)

The sentence `NOT_CONSERVED_TABLE` declares for `operator` on a field of semantics `S`
and time semantics `T` under the rule type `R`, and refuses when the table declares
none.
"""
function not_conserved_sentence(operator::Symbol, S::Type, T::Type, R::Type)
    for entry in NOT_CONSERVED_TABLE
        entry.operator === operator || continue
        S <: entry.semantics || continue
        T <: entry.time_semantics || continue
        R <: entry.rule || continue
        return entry.sentence
    end
    refuse("conservation table", "Fields.not_conserved_sentence",
           "no entry declares that $(operator) of $(S) at $(T) under $(R) conserves nothing")
end

"""
    NotConserved

What an operator returns in the ledger position when its operation conserves no
quantity: the operator, the name of the semantics it ran on, and the sentence
`NOT_CONSERVED_TABLE` declares. `closed` refuses it with that sentence.
"""
struct NotConserved
    operator::Symbol
    semantics::String
    sentence::String
end

"""
    not_conserved(operator, f, R)

The `NotConserved` `NOT_CONSERVED_TABLE` declares for `operator` on `f` under the rule
type `R`. The one door every method returning a `NotConserved` goes through.
"""
not_conserved(operator::Symbol, ::Field{S,T}, R::Type) where {S,T} =
    NotConserved(operator, type_name(S), not_conserved_sentence(operator, S, T, R))

"""
    closed(n::NotConserved)

Refuses, with the sentence `n` carries: an operation that conserves nothing has no
balance to be closed or open.
"""
closed(n::NotConserved) =
    refuse("ledger of $(n.operator) of $(n.semantics)", "Fields.closed", n.sentence)

"""
    ClassLedgers{Q}(classes, ledgers)

One balance of `Q` per class of a legend: `ledgers[i]` balances the amount of `Q` held
by `classes[i]`, a `Ledger{Q}` for a field of one value per cell besides its legend and
a `ColumnLedgers{Q}` for a field that carries columns besides its legend.
"""
struct ClassLedgers{Q,C<:Tuple,G<:Tuple}
    classes::C
    ledgers::G
end

ClassLedgers{Q}(classes::C, ledgers::G) where {Q,C<:Tuple,G<:Tuple} =
    ClassLedgers{Q,C,G}(classes, ledgers)

"The `Symbol` naming the quantity every ledger of `c` balances."
quantity(::ClassLedgers{Q}) where {Q} = Q

"The classes `c` holds a ledger for, in the order of its ledgers."
classes(c::ClassLedgers) = c.classes

"The ledgers `c` holds, one per class."
ledgers(c::ClassLedgers) = c.ledgers

"Whether every ledger `c` holds is closed."
closed(c::ClassLedgers) = all(closed, c.ledgers)

"""
    ledger_of(c, class)

The ledger `c` holds for `class`, refusing a class `c` holds none for.
"""
function ledger_of(c::ClassLedgers, class)
    i = findfirst(==(class), c.classes)
    i === nothing && refuse("class ledger", "Fields.ledger_of",
                            "$(repr(class)) is not one of $(join(map(repr, c.classes), ", "))")
    return c.ledgers[i]
end

"""
    ColumnLedgers{Q}(ledgers)

One `Ledger{Q}` per column of a field of cells by trailing axes (`Backends.LAYOUT`):
`ledgers` is an array of the trailing shape, and `ledgers[c...]` balances the amount of
`Q` in column `c`.
"""
struct ColumnLedgers{Q,G<:AbstractArray}
    ledgers::G
end

ColumnLedgers{Q}(ledgers::G) where {Q,G<:AbstractArray} = ColumnLedgers{Q,G}(ledgers)

quantity(::ColumnLedgers{Q}) where {Q} = Q

"The ledgers `c` holds, an array of the trailing shape."
ledgers(c::ColumnLedgers) = c.ledgers

"Whether every column's ledger `c` holds is closed."
closed(c::ColumnLedgers) = all(closed, c.ledgers)

"""
    ledger_of(c::ColumnLedgers, column...)

The ledger `c` holds for the column at the trailing index `column`, refusing an index
outside the trailing shape.
"""
function ledger_of(c::ColumnLedgers, column::Integer...)
    checkbounds(Bool, c.ledgers, column...) || refuse(
        "column ledger", "Fields.ledger_of",
        "column $(column) is outside the trailing shape $(size(c.ledgers))")
    return c.ledgers[column...]
end

"""
    conserved_ledger(Val(Q), T, n, magnitude, before, after; reservoir)

The balance of `Q` across an operation that summed `n` terms per column in the
accumulator `T`, from `Float64` totals. When `magnitude`, `before` and `after` are
numbers, the totals of a field of one value per cell, it is `Ledger{Q}` of them with no
flux. When they are arrays of one trailing shape, one total per column, it is
`ColumnLedgers{Q}` holding that `Ledger{Q}` of each column's entries, and it refuses
arrays of different shapes.
"""
conserved_ledger(::Val{Q}, ::Type{T}, n::Integer, magnitude::Real, before::Real,
                 after::Real; reservoir::Bool) where {Q,T<:AbstractFloat} =
    Ledger{Q}(T, n, magnitude, before, after, zero(Float64); reservoir = reservoir)

function conserved_ledger(q::Val{Q}, ::Type{T}, n::Integer, magnitude::AbstractArray,
                          before::AbstractArray, after::AbstractArray;
                          reservoir::Bool) where {Q,T<:AbstractFloat}
    size(magnitude) == size(before) == size(after) || refuse(
        "column ledger", "Fields.conserved_ledger",
        "magnitude, before and after have sizes $(size(magnitude)), $(size(before)) " *
        "and $(size(after))")
    column(m, b, a) = conserved_ledger(q, T, n, m, b, a; reservoir = reservoir)
    return ColumnLedgers{Q}(map(column, magnitude, before, after))
end

"""
    legend_ledgers(Val(Q), T, n, legend, magnitude, before, after; reservoir)

The `ClassLedgers{Q}` of `legend` from `Float64` totals whose last axis is the legend:
class `k`'s entry is the `conserved_ledger` of slice `k` of `magnitude`, `before` and
`after` along that axis (`legend_slice`).
"""
function legend_ledgers(q::Val{Q}, ::Type{T}, n::Integer, legend::Tuple,
                        magnitude::AbstractArray, before::AbstractArray,
                        after::AbstractArray; reservoir::Bool) where {Q,T<:AbstractFloat}
    class_ledger(k) = conserved_ledger(q, T, n, legend_slice(magnitude, k),
                                       legend_slice(before, k), legend_slice(after, k);
                                       reservoir = reservoir)
    return ClassLedgers{Q}(legend, ntuple(class_ledger, Val(length(legend))))
end

"""
    legend_slice(xs, k)

Slice `k` of `xs` along its last axis: a number when `xs` is a vector, and an array of
its other axes otherwise.
"""
legend_slice(xs::AbstractVector, k::Integer) = xs[k]
legend_slice(xs::AbstractArray{E,N}, k::Integer) where {E,N} =
    xs[ntuple(_ -> Colon(), Val(N - 1))..., k]

"""
    float64_total(xs, backend)

`Reductions.pairwise_sum` of `xs` in `Float64` on `backend`: a host scalar for a vector,
and for an array of cells by trailing axes a host array of the trailing shape holding
each column's total.
"""
float64_total(xs::AbstractArray, backend::Backend) = pairwise_sum(Float64, xs, backend)

"""
    zero_total(xs)

The zero `float64_total` of `xs`'s shape takes: `zero(Float64)` for a vector, and a host
array of zeros of the trailing shape otherwise.
"""
zero_total(::AbstractVector) = zero(Float64)
zero_total(xs::AbstractArray) = zeros(Float64, trailing_shape(xs))

"""
    weighted_total(xs, weights, backend)

The sum over the cells `j` of `xs[j, c...] * weights[j]` in `Float64` on `backend`, one
segment of `Reductions.segmented_weighted_sum` over every column, read to the host
through `Backends.on`: a host scalar for a vector, and a host array of the trailing
shape holding each column's sum otherwise.
"""
function weighted_total(xs::AbstractArray, weights::AbstractVector, backend::Backend)
    starts = on([1, size(xs, CELL_AXIS) + 1], backend)
    total = segmented_weighted_sum(Float64, xs, weights, Segmentation(xs, starts), backend)
    return one_segment(on(total, CPU()))
end

"""
    one_segment(total)

The entries of a reduction over one segment with its segment axis dropped: the number
a vector holds, or an array of the trailing shape.
"""
one_segment(total::AbstractVector) = only(total)
one_segment(total::AbstractArray) = reshape(total, trailing_shape(total))

"""
    coarse_measure(T, measure, seg, backend)

The measure each segment of `seg` holds: the segmented sum in `T` of `measure`'s values
on `backend`.
"""
coarse_measure(::Type{T}, measure::Measured, seg::Segmentation, backend::Backend) where {T} =
    segmented_sum(T, values_of(measure), seg, backend)

"""
    total_ledger(T, n, source, result; reservoir, backend)

The balance of `:total` across an operation that summed `n` terms per column in the
accumulator `T` to take `source` to `result`: `conserved_ledger` of `before` and `after`
the `float64_total` of `source` and `result`, and the magnitude the `float64_total` of
`abs.(source)`, all on `backend`.
"""
function total_ledger(::Type{T}, n::Integer, source::AbstractArray,
                      result::AbstractArray; reservoir::Bool,
                      backend::Backend) where {T<:AbstractFloat}
    return conserved_ledger(Val(:total), T, n, float64_total(abs.(source), backend),
                            float64_total(source, backend), float64_total(result, backend);
                            reservoir = reservoir)
end

"""
    integral_ledger(T, n, measure, before, after, terms; reservoir, backend)

The balance of the integral under `measure` across an operation that summed `n` terms
per column in the accumulator `T`. `before`, `after` and `terms` are each a pair of a
value array and the measure vector it is weighted by: `conserved_ledger` of `before`
and `after` the `weighted_total` of their pairs, and the magnitude the `weighted_total`
of the absolute values of `terms`, all on `backend`.
"""
function integral_ledger(::Type{T}, n::Integer, measure::Measured,
                         before::NTuple{2,AbstractArray}, after::NTuple{2,AbstractArray},
                         terms::NTuple{2,AbstractArray}; reservoir::Bool,
                         backend::Backend) where {T<:AbstractFloat}
    return conserved_ledger(Val(integral_quantity(measure)), T, n,
                            weighted_total(abs.(terms[1]), abs.(terms[2]), backend),
                            weighted_total(before[1], before[2], backend),
                            weighted_total(after[1], after[2], backend);
                            reservoir = reservoir)
end

"""
    block_segmentation(fine, coarse_level, fine_level, site, backend)

The contiguous ranges the cells of `fine_level` occupy under the cells of
`coarse_level`, checked against the cell count of `fine` along `CELL_AXIS`, with the
boundaries moved to `backend` through `Backends.on`. A crossing between two levels is a
segmented reduction because the bisection numbers a cell's descendants contiguously
(decision 0005, `Mesh.descendants`).

Refuses a pair of levels that is not strictly finer to coarser, and a cell count that
is not the coarse cell count times the block size, which is what a locally refined
support would give, or an array whose cells do not lie on `CELL_AXIS`.
"""
function block_segmentation(fine::AbstractArray, coarse_level::Integer,
                             fine_level::Integer, site::AbstractString, backend::Backend)
    fine_level > coarse_level || refuse(
        "level crossing", site,
        "level $(fine_level) is not finer than level $(coarse_level)")
    block = 4^(fine_level - coarse_level)
    ncoarse = ncells(coarse_level)
    n = size(fine, CELL_AXIS)
    n == block * ncoarse || refuse(
        "level crossing extent", site,
        "level $(fine_level) under level $(coarse_level) is $(block * ncoarse) cells " *
        "in blocks of $(block), and the array holds $(n) along its cell axis")
    return Segmentation(fine, on(collect(1:block:(n + 1)), backend))
end

"""
    block_size(coarse_level, fine_level)

How many cells of `fine_level` each cell of `coarse_level` holds.
"""
block_size(coarse_level::Integer, fine_level::Integer) = 4^(fine_level - coarse_level)

"""
    cell_blocks(xs, block)

The `inner` counts of `repeat` that repeat each cell of `xs` `block` times along
`CELL_AXIS` and keep every trailing axis as it is.
"""
cell_blocks(::AbstractArray{E,N}, block::Integer) where {E,N} =
    ntuple(d -> d == CELL_AXIS ? block : 1, Val(N))

"""
    child_segmentation(f, to, backend)

The segmentation a coarsening of `f` onto the coarser support `to` reduces over on
`backend`.
"""
child_segmentation(f::Field{S,T,D,L}, to::Support{L2}, backend::Backend) where {S,T,D,L,L2} =
    block_segmentation(f.data, L2, L, "Fields.coarsen", backend)

"""
    require_measure_extent(values, m, site)

Returns `nothing` when `m` has one value per cell of `values` along `CELL_AXIS`, and
refuses naming both counts otherwise.
"""
require_measure_extent(values::AbstractArray, m::Measured, site::AbstractString) =
    length(values_of(m)) == size(values, CELL_AXIS) ? nothing : refuse(
        "measure extent", site,
        "the field holds $(size(values, CELL_AXIS)) cells and the " *
        "$(measure_name(m)) measure holds $(length(values_of(m)))")

"""
    position_phrase(i)

How a refusal names the entry `i` of a field's array: `cell i` for a vector, and the
cell and the trailing index of its column otherwise.
"""
position_phrase(i::CartesianIndex{1}) = "cell $(i[1])"
position_phrase(i::CartesianIndex) = "cell $(i[1]) of column $(Base.tail(Tuple(i)))"

"""
    require_in_legend(labels, legend, site)

Returns `nothing` when every label of `labels` is a class of `legend`, and refuses
naming the first entry, by `position_phrase`, whose label is not.
"""
function require_in_legend(labels::AbstractArray, legend::Tuple, site::AbstractString)
    for i in CartesianIndices(labels)
        labels[i] in legend || refuse(
            "categorical label", site,
            "$(position_phrase(i)) holds $(repr(labels[i])), which the legend " *
            "$(join(map(repr, legend), ", ")) does not name")
    end
    return nothing
end

"""
    require_legend_axis(fractions, legend, site)

Returns `nothing` when `fractions` holds one column per class of `legend` on its last
axis, after its cell axis, and refuses naming its size and the class count otherwise.
"""
require_legend_axis(fractions::AbstractArray, legend::Tuple, site::AbstractString) =
    ndims(fractions) >= 2 && size(fractions, ndims(fractions)) == length(legend) ?
    nothing : refuse(
        "class-fraction shape", site,
        "a class-fraction field holds one column per class on its last axis; the array " *
        "has size $(size(fractions)) and the legend $(length(legend)) classes")

"""
    reduced(f, semantics, data, support, writer)

`data` on `support` carrying `semantics`, `f`'s dimension and time support, and an
unstamped origin written by `writer` in `f`'s run. The one place the operators below
build a result.
"""
reduced(f::Field{S,T,D}, semantics::Semantics, data::AbstractArray,
        support::Support, writer::Symbol) where {S,T,D} =
    Field(semantics = semantics, dimension = D(), data = data, support = support,
          time = f.time, origin = unstamped(writer, f.origin.run))

"""
    setup(f, to, site, backend)

The checks every coarsening makes before it reduces, and the segmentation it reduces
over on `backend`: a destination that could be a coarser level of the same mesh, and
the contiguous child ranges along `CELL_AXIS`.
"""
function setup(f::Field, to::Support, site::AbstractString, backend::Backend)
    require_ancestor(f.support, to, site)
    return child_segmentation(f, to, backend)
end

"""
    coarsen(f, to; reservoir, backend)
    coarsen(f, to; measure, reservoir, backend)
    coarsen(f, to; legend, measure, reservoir, backend)
    coarsen(f, to, rule; ...)

`(field, ledger)`: `f` on the coarser support `to`, by the rule its semantics fixes or
the rule the caller names, and the balance of what that rule conserves. Every form that
integrates over a measure takes a `Measured`, so no call here passes an unqualified area
(REQ-TER-011). Every form that returns a ledger takes `reservoir`, which the ledger
reads.

A field of cells by trailing axes (`Backends.LAYOUT`) is reduced down its cell axis in
every column at once, through the column form of the same reduction, and keeps its
trailing axes; where a field of one value per cell returns a `Ledger`, it returns a
`ColumnLedgers` of one `Ledger` per column.

`Extensive` is a segmented sum in the field's element type and takes no measure; its
ledger is `coarsen_total_ledger`. `FluxDensity`, `Fraction` and `Intensive` under
`AreaMean` are means weighted by the named measure in the field's element type; their
ledger is `coarsen_integral_ledger`. `CategoricalFraction` is the mean of each class
column, the legend the call names on the data's last axis, weighted by the named
measure in the field's element type; it refuses data without that axis, and its ledgers
are `class_ledgers`. `CategoricalLabel` is that coarsening taken class by class from
each class's indicator (`label_coarsening`) over the legend the call names, in the
measure's element type, never a centre sample, into `CategoricalFraction`; it refuses a label the legend does not name. `Intensive`
under `ToQuantiles` is a table of the quantiles on a new last axis and returns the
`NotConserved` `NOT_CONSERVED_TABLE` declares.

`Intensive` has no form without a rule, and `Quantiles` has no form: see
`REFUSAL_TABLE`.
"""
function coarsen(f::Field{Extensive}, to::Support; reservoir::Bool, backend::Backend)
    seg = setup(f, to, "Fields.coarsen", backend)
    data = segmented_sum(eltype(f.data), f.data, seg, backend)
    ledger = coarsen_total_ledger(f, data; reservoir = reservoir, backend = backend)
    return reduced(f, Extensive(), data, to, :coarsen), ledger
end

function coarsen(f::Field{FluxDensity}, to::Support; measure::Measured, reservoir::Bool,
                  backend::Backend)
    return mean_coarsening(f, FluxDensity(), to, measure, reservoir, backend)
end

function coarsen(f::Field{Fraction}, to::Support; measure::Measured, reservoir::Bool,
                  backend::Backend)
    return mean_coarsening(f, Fraction(), to, measure, reservoir, backend)
end

function coarsen(f::Field{Intensive}, to::Support, ::AreaMean;
                  measure::Measured, reservoir::Bool, backend::Backend)
    return mean_coarsening(f, Intensive(), to, measure, reservoir, backend)
end

function coarsen(f::Field{Intensive}, to::Support, ::ToQuantiles{P};
                  backend::Backend) where {P}
    seg = setup(f, to, "Fields.coarsen", backend)
    columns = map(p -> segmented_quantile(f.data, seg, p, backend), P)
    return reduced(f, Quantiles{P}(), stack(columns), to, :coarsen),
           not_conserved(:coarsen, f, ToQuantiles{P})
end

function coarsen(f::Field{CategoricalFraction{Legend}}, to::Support;
                  legend::Tuple, measure::Measured, reservoir::Bool,
                  backend::Backend) where {Legend}
    seg = setup(f, to, "Fields.coarsen", backend)
    require_measure_extent(f.data, measure, "Fields.coarsen")
    require_legend_axis(f.data, legend, "Fields.coarsen")
    data, ledgers = class_coarsening(f.data, seg, legend, measure, reservoir, backend)
    return reduced(f, CategoricalFraction{Legend}(), data, to, :coarsen), ledgers
end

function coarsen(f::Field{CategoricalLabel{Legend}}, to::Support;
                  legend::Tuple, measure::Measured, reservoir::Bool,
                  backend::Backend) where {Legend}
    seg = setup(f, to, "Fields.coarsen", backend)
    require_measure_extent(f.data, measure, "Fields.coarsen")
    require_in_legend(f.data, legend, "Fields.coarsen")
    data, ledgers = label_coarsening(f.data, seg, legend, measure, reservoir, backend)
    return reduced(f, CategoricalFraction{Legend}(), data, to, :coarsen), ledgers
end

"""
    indicator(labels, class, T)

One where `labels` equals `class` and zero elsewhere, in `T`, on the host, in the shape
of `labels`.
"""
indicator(labels::AbstractArray, class, ::Type{T}) where {T} =
    map(l -> l == class ? one(T) : zero(T), labels)

"""
    indicator!(buffer, labels, class)

`buffer` overwritten with one where `labels` equals `class` and zero elsewhere, and
returned; `buffer` has the shape of `labels`.
"""
indicator!(buffer::AbstractArray{T}, labels::AbstractArray, class) where {T} =
    map!(l -> l == class ? one(T) : zero(T), buffer, labels)

"""
    class_shares(fractions, seg, measure, backend)

The share of each coarse cell of `seg` the class fractions `fractions` hold: the mean
of every column of `fractions` weighted by `measure`, in `fractions`'s element type, on
`backend`.
"""
class_shares(fractions::AbstractArray, seg::Segmentation, measure::Measured,
             backend::Backend) =
    segmented_mean(eltype(fractions), fractions, seg, values_of(measure), backend)

"""
    class_area_totals(fine, fine_magnitude, coarse, held, weights, magnitude_weights, backend)

`(magnitude, before, after)`, the `Float64` totals a class-area ledger closes: the
`weighted_total` of `fine_magnitude`, the absolute values of the fine class fractions
`fine`, by `magnitude_weights`, the absolute values of `weights`; that of `fine` by
`weights`; and that of the coarse shares `coarse` by the coarse measure `held`.
"""
function class_area_totals(fine::AbstractArray, fine_magnitude::AbstractArray,
                           coarse::AbstractArray, held::AbstractVector,
                           weights::AbstractVector, magnitude_weights::AbstractVector,
                           backend::Backend)
    return weighted_total(fine_magnitude, magnitude_weights, backend),
           weighted_total(fine, weights, backend),
           weighted_total(coarse, held, backend)
end

"""
    class_coarsening(fractions, seg, legend, measure, reservoir, backend)

`(data, ledgers)` for the class fractions `fractions`, cells by trailing axes with
`legend` on the last, coarsened over `seg` on `backend`: `data` the `class_shares` of
every column in one launch, and `ledgers` the `class_ledgers` of it.
"""
function class_coarsening(fractions::AbstractArray, seg::Segmentation, legend::Tuple,
                          measure::Measured, reservoir::Bool, backend::Backend)
    data = class_shares(fractions, seg, measure, backend)
    ledgers = class_ledgers(fractions, data, seg, legend, measure; reservoir = reservoir,
                            backend = backend)
    return data, ledgers
end

"""
    class_ledgers(fine, coarse, seg, legend, measure; reservoir, backend)

The `ClassLedgers{Name}` of a coarsening over `seg` of the class fractions `fine` to
`coarse` under the measure `Name`, `legend` on the last axis of both. Class `k`'s entry
is `legend_ledgers` in `fine`'s element type `T` over `fine`'s cell count, from slice
`k` of the `class_area_totals` of `fine`, `abs.(fine)`, `coarse`, `coarse_measure` in
`T`, the measure and its absolute values.
"""
function class_ledgers(fine::AbstractArray, coarse::AbstractArray, seg::Segmentation,
                       legend::Tuple, measure::Measured{Name}; reservoir::Bool,
                       backend::Backend) where {Name}
    weights = values_of(measure)
    T = eltype(fine)
    held = coarse_measure(T, measure, seg, backend)
    magnitude, before, after = class_area_totals(fine, abs.(fine), coarse, held, weights,
                                                 abs.(weights), backend)
    return legend_ledgers(Val(Name), T, size(fine, CELL_AXIS), legend, magnitude, before,
                          after; reservoir = reservoir)
end

"""
    label_coarsening(labels, seg, legend, measure, reservoir, backend)

`(data, ledgers)` for the labels `labels`, cells by trailing axes, histogrammed over
`seg` into the shares of `legend`, the classes on a new last axis of `data`. Class by
class, the `indicator!` of the class is written into one host buffer in the measure's
element type `T` and moved to `backend`; its `class_shares` are the class's slice of
`data`, and its ledger is the `conserved_ledger` in `T` over the cell count of its
`class_area_totals`, the indicator standing for its own absolute values. One class's
indicator is held at a time; the class fractions of every class are never built.
"""
function label_coarsening(labels::AbstractArray, seg::Segmentation, legend::Tuple,
                          measure::Measured{Name}, reservoir::Bool,
                          backend::Backend) where {Name}
    weights = values_of(measure)
    T = eltype(weights)
    held = coarse_measure(T, measure, seg, backend)
    magnitude_weights = abs.(weights)
    buffer = similar(labels, T)
    n = size(labels, CELL_AXIS)
    function class_part(k)
        fine = on(indicator!(buffer, labels, legend[k]), backend)
        shares = class_shares(fine, seg, measure, backend)
        totals = class_area_totals(fine, fine, shares, held, weights, magnitude_weights,
                                   backend)
        return shares, conserved_ledger(Val(Name), T, n, totals...; reservoir = reservoir)
    end
    parts = ntuple(class_part, Val(length(legend)))
    return stack(map(first, parts)), ClassLedgers{Name}(legend, map(last, parts))
end

"""
    mean_coarsening(f, semantics, to, measure, reservoir, backend)

`(field, ledger)` of a mean coarsening of `f` onto `to` weighted by `measure`, carrying
`semantics`: the mean in `f`'s element type and `coarsen_integral_ledger` of it.
"""
function mean_coarsening(f::Field, semantics::Semantics, to::Support, measure::Measured,
                         reservoir::Bool, backend::Backend)
    seg = setup(f, to, "Fields.coarsen", backend)
    require_measure_extent(f.data, measure, "Fields.coarsen")
    data = segmented_mean(eltype(f.data), f.data, seg, values_of(measure), backend)
    ledger = coarsen_integral_ledger(f, to, data, measure; reservoir = reservoir,
                                     backend = backend)
    return reduced(f, semantics, data, to, :coarsen), ledger
end

"""
    coarsen_total_ledger(f, data; reservoir, backend)

The balance of `:total` across a coarsening of the `Extensive` field `f` to the coarse
values `data`: `total_ledger` in `f`'s element type over `f`'s cell count, from `f`'s
data to `data`.
"""
coarsen_total_ledger(f::Field, data::AbstractArray; reservoir::Bool, backend::Backend) =
    total_ledger(eltype(f.data), size(f.data, CELL_AXIS), f.data, data;
                 reservoir = reservoir, backend = backend)

"""
    coarsen_integral_ledger(f, to, data, measure; reservoir, backend)

The balance of the integral under `measure` across a mean coarsening of `f` onto `to` to
the coarse values `data`: `integral_ledger` in `f`'s element type `T` over `f`'s cell
count, from `f`'s data weighted by `measure` to `data` weighted by `coarse_measure` in
`T`, with the terms `f`'s data weighted by `measure`.
"""
function coarsen_integral_ledger(f::Field, to::Support, data::AbstractArray,
                                 measure::Measured; reservoir::Bool, backend::Backend)
    T = eltype(f.data)
    seg = child_segmentation(f, to, backend)
    weights = values_of(measure)
    return integral_ledger(T, size(f.data, CELL_AXIS), measure, (f.data, weights),
                           (data, coarse_measure(T, measure, seg, backend)),
                           (f.data, weights); reservoir = reservoir, backend = backend)
end

coarsen(f::Field{Intensive}, ::Support; kwargs...) = refuse_declared(:coarsen, f)
coarsen(f::Field{VectorComponent{:east_north}}, ::Support; kwargs...) =
    refuse_declared(:coarsen, f)
coarsen(f::Field{VectorComponent{:east_north}}, ::Support, ::Rule; kwargs...) =
    refuse_declared(:coarsen, f)
coarsen(f::Field{<:Quantiles}, ::Support; kwargs...) = refuse_declared(:coarsen, f)
coarsen(f::Field{<:Quantiles}, ::Support, ::Rule; kwargs...) = refuse_declared(:coarsen, f)

"""
    refine(f, to; measure, reservoir, backend)
    refine(f, to; legend, measure, reservoir, backend)
    refine(f, to)

`(field, ledger)`: `f` on the finer support `to`, and the balance of what the
refinement conserves. Every form that returns a ledger takes `reservoir`, which the
ledger reads.

A field of cells by trailing axes (`Backends.LAYOUT`) is refined along its cell axis in
every column and keeps its trailing axes; where a field of one value per cell returns a
`Ledger`, it returns a `ColumnLedgers` of one `Ledger` per column.

`Extensive` splits each cell's total among its children in proportion to the named
measure at the fine level, the measure's totals summed in its element type; its ledger
is `total_ledger` in that type over the fine cell count. `FluxDensity` and `Fraction`
give each child the parent's value, and their ledger is `refine_integral_ledger`.
`CategoricalLabel` gives each child the parent's label, refuses a label the legend does
not name, and its ledgers are `refine_class_ledgers`. `Intensive` and
`VectorComponent{:cartesian}` give each child the parent's value and return the
`NotConserved` `NOT_CONSERVED_TABLE` declares.

`CategoricalFraction` and `Quantiles` have no form at all: see `REFUSAL_TABLE`.
"""
function refine(f::Field{Extensive,T,D,L}, to::Support{L2};
                 measure::Measured, reservoir::Bool, backend::Backend) where {T,D,L,L2}
    require_ancestor(f.support, to, "Fields.refine")
    fine = values_of(measure)
    seg = block_segmentation(fine, L, L2, "Fields.refine", backend)
    totals = segmented_sum(eltype(fine), fine, seg, backend)
    block = block_size(L, L2)
    shares = fine ./ repeat(totals, inner = block)
    data = repeat(f.data, inner = cell_blocks(f.data, block)) .* shares
    ledger = total_ledger(eltype(fine), length(fine), f.data, data;
                          reservoir = reservoir, backend = backend)
    return reduced(f, Extensive(), data, to, :refine), ledger
end

for S in (:FluxDensity, :Fraction)
    @eval function refine(f::Field{$S,T,D,L}, to::Support{L2}; measure::Measured,
                          reservoir::Bool, backend::Backend) where {T,D,L,L2}
        data = spread(f, to, L, L2)
        ledger = refine_integral_ledger(f, to, data, measure; reservoir = reservoir,
                                        backend = backend)
        return reduced(f, $S(), data, to, :refine), ledger
    end
end

function refine(f::Field{Intensive,T,D,L}, to::Support{L2}) where {T,D,L,L2}
    return reduced(f, Intensive(), spread(f, to, L, L2), to, :refine),
           not_conserved(:refine, f, Nothing)
end

function refine(f::Field{CategoricalLabel{Legend},T,D,L}, to::Support{L2};
                 legend::Tuple, measure::Measured, reservoir::Bool,
                 backend::Backend) where {Legend,T,D,L,L2}
    require_in_legend(f.data, legend, "Fields.refine")
    data = spread(f, to, L, L2)
    ledgers = refine_class_ledgers(f, to, data, legend, measure; reservoir = reservoir,
                                   backend = backend)
    return reduced(f, CategoricalLabel{Legend}(), data, to, :refine), ledgers
end

function refine(f::Field{VectorComponent{:cartesian},T,D,L}, to::Support{L2}) where
                {T,D,L,L2}
    return reduced(f, VectorComponent{:cartesian}(), spread(f, to, L, L2), to, :refine),
           not_conserved(:refine, f, Nothing)
end

"""
    spread(f, to, from_level, to_level)

Each cell's value repeated over the cells it holds at `to_level`, in the order the
bisection numbers them, along `CELL_AXIS` in every column, with the checks a refinement
makes first: a destination that could be a finer level of the same mesh, and the
extents.
"""
function spread(f::Field, to::Support, from_level::Integer, to_level::Integer)
    require_ancestor(f.support, to, "Fields.refine")
    to_level > from_level || refuse(
        "level crossing", "Fields.refine",
        "level $(to_level) is not finer than level $(from_level)")
    size(f.data, CELL_AXIS) == ncells(from_level) || refuse(
        "level crossing extent", "Fields.refine",
        "level $(from_level) is $(ncells(from_level)) cells and the field holds " *
        "$(size(f.data, CELL_AXIS)) along its cell axis")
    return repeat(f.data, inner = cell_blocks(f.data, block_size(from_level, to_level)))
end

"""
    refine_integral_ledger(f, to, data, measure; reservoir, backend)

The balance of the integral under `measure` across a refinement of `f` onto `to` to the
fine values `data`, `measure` holding one value per fine cell: `integral_ledger` in
`Float64` over the fine cell count, from `f`'s data weighted by `coarse_measure` in
`Float64` to `data` weighted by `measure`, with the terms `data` weighted by `measure`.
"""
function refine_integral_ledger(f::Field{S,T,D,L}, to::Support{L2}, data::AbstractArray,
                                measure::Measured; reservoir::Bool,
                                backend::Backend) where {S,T,D,L,L2}
    require_measure_extent(data, measure, "Fields.refine")
    weights = values_of(measure)
    seg = block_segmentation(weights, L, L2, "Fields.refine", backend)
    return integral_ledger(Float64, size(data, CELL_AXIS), measure,
                           (f.data, coarse_measure(Float64, measure, seg, backend)),
                           (data, weights), (data, weights); reservoir = reservoir,
                           backend = backend)
end

"""
    refine_class_ledgers(f, to, data, legend, measure; reservoir, backend)

The `ClassLedgers{Name}` of a refinement of the labels of `f` onto `to` to the fine
labels `data`, under the measure `Name`, one value per fine cell. Class by class, the
`indicator!` of the class over `f`'s labels and over `data` is written into one host
buffer each and moved to `backend`, and class `k`'s entry is the `conserved_ledger` in
`Float64` over the fine cell count of three totals: `before` the `weighted_total` of the
coarse indicator by `coarse_measure` in `Float64`, `after` that of the fine indicator by
`measure`, and the magnitude that of the fine indicator by the absolute measure.
"""
function refine_class_ledgers(f::Field{S,T,D,L}, to::Support{L2}, data::AbstractArray,
                              legend::Tuple, measure::Measured{Name}; reservoir::Bool,
                              backend::Backend) where {S,T,D,L,L2,Name}
    require_measure_extent(data, measure, "Fields.refine")
    weights = values_of(measure)
    held = coarse_measure(Float64, measure,
                          block_segmentation(weights, L, L2, "Fields.refine", backend), backend)
    magnitude_weights = abs.(weights)
    coarse_buffer = similar(f.data, Float64)
    fine_buffer = similar(data, Float64)
    n = size(data, CELL_AXIS)
    function class_ledger(k)
        coarse = on(indicator!(coarse_buffer, f.data, legend[k]), backend)
        fine = on(indicator!(fine_buffer, data, legend[k]), backend)
        return conserved_ledger(Val(Name), Float64, n,
                                weighted_total(fine, magnitude_weights, backend),
                                weighted_total(coarse, held, backend),
                                weighted_total(fine, weights, backend); reservoir = reservoir)
    end
    return ClassLedgers{Name}(legend, ntuple(class_ledger, Val(length(legend))))
end

refine(f::Field{VectorComponent{:east_north}}, ::Support; kwargs...) =
    refuse_declared(:refine, f)
refine(f::Field{<:CategoricalFraction}, ::Support; kwargs...) = refuse_declared(:refine, f)
refine(f::Field{<:Quantiles}, ::Support; kwargs...) = refuse_declared(:refine, f)

"""
    time_reduce(series; reservoir, backend)
    time_reduce(series)

`(field, ledger)`: the one field a contiguous series of fields reduces to over the union
of their intervals, by the rule their time semantics fixes, and the balance of what the
rule conserves.

The series is a `Time.Forcing`, so the contiguity of the intervals is checked where it
is declared rather than restated here, and its one value type is what makes every field
in it agree in semantics, dimension and support.

An `IntervalMean` reduces by the sum over the series of each field weighted by its
interval's duration divided by the union's duration, and its ledger is
`time_mean_ledger`. An `IntervalAccumulation` reduces by a sum starting from a copy of
the first field, and its ledger is `accumulation_ledger`. A series of fields of cells
by trailing axes returns a `ColumnLedgers` of one `Ledger` per column. An
`EndpointState` reduces to a copy of the state at the last interval's end and returns
the `NotConserved` `NOT_CONSERVED_TABLE` declares. `Instantaneous` and `Static` have no
form: see `REFUSAL_TABLE`.
"""
function time_reduce(series::Forcing{FT,F}; reservoir::Bool,
                     backend::Backend) where {FT,S,F<:Field{S,IntervalMean}}
    weights = map(duration, series.intervals)
    total = sum(weights)
    data = sum((w / total) .* f.data for (w, f) in zip(weights, series.values))
    ledger = time_mean_ledger(series, data; reservoir = reservoir, backend = backend)
    return retimed(series, data, :time_reduce), ledger
end

function time_reduce(series::Forcing{FT,F}; reservoir::Bool,
                     backend::Backend) where {FT,S,F<:Field{S,IntervalAccumulation}}
    data = copy(first(series.values).data)
    for f in series.values[2:end]
        data .+= f.data
    end
    ledger = accumulation_ledger(series, data; reservoir = reservoir, backend = backend)
    return retimed(series, data, :time_reduce), ledger
end

function time_reduce(series::Forcing{FT,F}) where {FT,S,F<:Field{S,EndpointState}}
    return retimed(series, copy(last(series.values).data), :time_reduce),
           not_conserved(:time_reduce, first(series.values), Nothing)
end

time_reduce(series::Forcing{FT,F}; kwargs...) where {FT,S,F<:Field{S,Instantaneous}} =
    refuse_declared(:time_reduce, first(series.values))

time_reduce(series::Forcing{FT,F}; kwargs...) where {FT,S,F<:Field{S,Static}} =
    refuse_declared(:time_reduce, first(series.values))

"""
    wider_roundoff(A, B)

Whichever of the floating point types `A` and `B` has the larger `eps`, `A` when they
are equal.
"""
wider_roundoff(::Type{A}, ::Type{B}) where {A<:AbstractFloat,B<:AbstractFloat} =
    eps(A) >= eps(B) ? A : B

"""
    time_mean_ledger(series, data; reservoir, backend)

The balance of `:duration_integral` across a duration-weighted mean of the
`IntervalMean` `series` to `data`, in `wider_roundoff` of the interval type and
`data`'s element type, over the series length times the cell count. `before`
accumulates, over the series by `fma` in each column, each duration times the
`float64_total` of its field, from `zero_total`; the magnitude does the same over the
absolute fields; `after` is the sum of the durations times the `float64_total` of
`data`.
"""
function time_mean_ledger(series::Forcing{FT}, data::AbstractArray; reservoir::Bool,
                          backend::Backend) where {FT}
    weights = map(duration, series.intervals)
    total = sum(weights)
    before = zero_total(data)
    magnitude = zero_total(data)
    for (w, f) in zip(weights, series.values)
        before = fma.(Float64(w), float64_total(f.data, backend), before)
        magnitude = fma.(Float64(w), float64_total(abs.(f.data), backend), magnitude)
    end
    after = Float64(total) .* float64_total(data, backend)
    return conserved_ledger(Val(:duration_integral), wider_roundoff(FT, eltype(data)),
                            length(series) * size(data, CELL_AXIS), magnitude, before,
                            after; reservoir = reservoir)
end

"""
    accumulation_ledger(series, data; reservoir, backend)

The balance of `:total` across a sum of the `IntervalAccumulation` `series` to `data`,
in `data`'s element type over the series length times the cell count: `before` the sum
over the series of each field's `float64_total` in each column, from `zero_total`, the
magnitude that of each absolute field's, and `after` the `float64_total` of `data`.
"""
function accumulation_ledger(series::Forcing, data::AbstractArray; reservoir::Bool,
                             backend::Backend)
    before = zero_total(data)
    magnitude = zero_total(data)
    for f in series.values
        before = before .+ float64_total(f.data, backend)
        magnitude = magnitude .+ float64_total(abs.(f.data), backend)
    end
    return conserved_ledger(Val(:total), eltype(data),
                            length(series) * size(data, CELL_AXIS), magnitude, before,
                            float64_total(data, backend); reservoir = reservoir)
end

"""
    retimed(series, data, writer)

`data` carrying the declarations of `series`'s fields, placed on the clock over the
union of their intervals, with an unstamped origin written by `writer`.
"""
function retimed(series::Forcing, data::AbstractArray, writer::Symbol)
    f = first(series.values)
    union = Interval(first(series.intervals).t0, last(series.intervals).t1)
    return Field(semantics = semantics(f), dimension = dimension(f), data = data,
                 support = f.support,
                 time = TimeSupport(time_semantics(f), union),
                 origin = unstamped(writer, f.origin.run))
end
