# coarsen, refine and time_reduce, dispatched on the type parameters:
# docs/plans/fiddlybits-52v.3-fields.md, section "The operators and the refusal table".
#
# A combination that has no meaning has no working method and a declared refusal
# instead, and the refusals are the table below rather than scattered calls, so that
# the enumeration test of fiddlybits-52v.3.4 can read them.

using ..Mesh: ncells
using ..Reductions: Segmentation, segmented_sum, segmented_mean, segmented_quantile
using ..Backends: Backend
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
    block_segmentation(fine, coarse_level, fine_level, site)

The contiguous ranges the cells of `fine_level` occupy under the cells of
`coarse_level`, checked against `fine`'s own length. A crossing between two levels is a
segmented reduction because the bisection numbers a cell's descendants contiguously
(decision 0005, `Mesh.descendants`).

Refuses a pair of levels that is not strictly finer to coarser, and a length that is
not the coarse cell count times the block size, which is what a locally refined support
would give and what `fiddlybits-52v.3.12` carries.
"""
function block_segmentation(fine::AbstractVector, coarse_level::Integer,
                             fine_level::Integer, site::AbstractString)
    fine_level > coarse_level || refuse(
        "level crossing", site,
        "level $(fine_level) is not finer than level $(coarse_level)")
    block = 4^(fine_level - coarse_level)
    ncoarse = ncells(coarse_level)
    n = length(fine)
    n == block * ncoarse || refuse(
        "level crossing extent", site,
        "level $(fine_level) under level $(coarse_level) is $(block * ncoarse) cells " *
        "in blocks of $(block), and the array holds $(n)")
    return Segmentation(fine, collect(1:block:(n + 1)))
end

"""
    block_size(coarse_level, fine_level)

How many cells of `fine_level` each cell of `coarse_level` holds.
"""
block_size(coarse_level::Integer, fine_level::Integer) = 4^(fine_level - coarse_level)

"""
    child_segmentation(f, to)

The segmentation a coarsening of `f` onto the coarser support `to` reduces over.
"""
child_segmentation(f::Field{S,T,D,L}, to::Support{L2}) where {S,T,D,L,L2} =
    block_segmentation(f.data, L2, L, "Fields.coarsen")

"""
    require_columnar(f, site)

Returns `nothing` when `f`'s data is one value per cell. The segmented reductions take
a vector, so a field carrying levels or components reduces column by column, which
`fiddlybits-52v.3.12` adds; until it does, the shape is refused here rather than
reduced along the wrong axis.
"""
require_columnar(f::Field, site::AbstractString) =
    f.data isa AbstractVector ? nothing : refuse(
        "field shape", site,
        "$(ndims(f.data)) dimensions; only one value per cell reduces here, and " *
        "fiddlybits-52v.3.12 carries the rest")

"""
    require_measure_extent(f, m, site)

Returns `nothing` when `m` has one value per cell of `f`, and refuses naming both
lengths otherwise.
"""
require_measure_extent(f::Field, m::Measured, site::AbstractString) =
    length(values_of(m)) == length(f.data) ? nothing : refuse(
        "measure extent", site,
        "the field holds $(length(f.data)) cells and the " *
        "$(measure_name(m)) measure holds $(length(values_of(m)))")

"""
    require_same_family(from, to, site)

Returns `nothing` when two supports could be two levels of one mesh, and refuses at
`site` naming what differs otherwise. It compares what two levels of one hierarchy
share: the kind, the radius, the element type and the refinement. It cannot establish
ancestry, which no field of a `Support` carries; `fiddlybits-52v.2.14` asks `Mesh` for
a check that can.
"""
function require_same_family(from::Support, to::Support, site::AbstractString)
    for name in (:kind, :radius, :element_type, :refinement_digest)
        a, b = getproperty(from, name), getproperty(to, name)
        a == b || refuse("support family", site,
                         "the supports differ in $(name): $(repr(a)) and $(repr(b))")
    end
    return nothing
end

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
    setup(f, to, site)

The checks every coarsening makes before it reduces, and the segmentation it reduces
over: one value per cell, a destination that could be a coarser level of the same mesh,
and the contiguous child ranges.
"""
function setup(f::Field, to::Support, site::AbstractString)
    require_columnar(f, site)
    require_same_family(f.support, to, site)
    return child_segmentation(f, to)
end

"""
    coarsen(f, to; measure, backend)
    coarsen(f, to, rule; measure, backend)

`f` on the coarser support `to`, by the rule its semantics fixes or the rule the caller
names. Every form that integrates over a measure takes a `Measured`, so no call here
passes an unqualified area (REQ-TER-011).

`Extensive` is a segmented sum and takes no measure, because a total over a coarse cell
is the total over its children whatever they are shaped like. `FluxDensity` and
`Fraction` are means weighted by the named measure, so the integral over the coarse cell
is the integral over its children. `CategoricalLabel` is a histogram into
`CategoricalFraction` over the legend the call names, never a centre sample.

`Intensive` has no form without a rule: see `REFUSAL_TABLE`.

The accumulator is the field's own element type. The reservoir rule of decision 0011,
which puts a declared reservoir in FP64 whatever the working precision, arrives with the
ledgers of `fiddlybits-52v.3.6` and refuses there.
"""
function coarsen(f::Field{Extensive}, to::Support; backend::Backend)
    seg = setup(f, to, "Fields.coarsen")
    data = segmented_sum(eltype(f.data), f.data, seg, backend)
    return reduced(f, Extensive(), data, to, :coarsen)
end

function coarsen(f::Field{FluxDensity}, to::Support; measure::Measured, backend::Backend)
    return reduced(f, FluxDensity(), measure_mean(f, to, measure, backend), to, :coarsen)
end

function coarsen(f::Field{Fraction}, to::Support; measure::Measured, backend::Backend)
    return reduced(f, Fraction(), measure_mean(f, to, measure, backend), to, :coarsen)
end

function coarsen(f::Field{Intensive}, to::Support, ::AreaMean;
                  measure::Measured, backend::Backend)
    return reduced(f, Intensive(), measure_mean(f, to, measure, backend), to, :coarsen)
end

function coarsen(f::Field{Intensive}, to::Support, ::ToQuantiles{P};
                  backend::Backend) where {P}
    seg = setup(f, to, "Fields.coarsen")
    columns = map(p -> segmented_quantile(f.data, seg, p, backend), P)
    return reduced(f, Quantiles{P}(), stack(columns), to, :coarsen)
end

function coarsen(f::Field{CategoricalLabel{Legend}}, to::Support;
                  legend, measure::Measured, backend::Backend) where {Legend}
    seg = setup(f, to, "Fields.coarsen")
    require_measure_extent(f, measure, "Fields.coarsen")
    weights = values_of(measure)
    share(class) = segmented_mean(eltype(weights), indicator(f.data, class, eltype(weights)),
                                  seg, weights, backend)
    return reduced(f, CategoricalFraction{Legend}(),
                   stack(map(share, Tuple(legend))), to, :coarsen)
end

"""
    indicator(labels, class, T)

One where `labels` equals `class` and zero elsewhere, in `T`, the element type the
measure is weighted in, so the area-weighted mean of it is the area share of `class`.
"""
indicator(labels::AbstractVector, class, ::Type{T}) where {T} =
    map(l -> l == class ? one(T) : zero(T), labels)

"""
    measure_mean(f, to, measure, backend)

`f`'s mean over each coarse cell of `to`, weighted by `measure`.
"""
function measure_mean(f::Field, to::Support, measure::Measured, backend::Backend)
    seg = setup(f, to, "Fields.coarsen")
    require_measure_extent(f, measure, "Fields.coarsen")
    return segmented_mean(eltype(f.data), f.data, seg, values_of(measure), backend)
end

coarsen(f::Field{Intensive}, ::Support; kwargs...) = refuse_declared(:coarsen, f)
coarsen(f::Field{VectorComponent{:east_north}}, ::Support; kwargs...) =
    refuse_declared(:coarsen, f)
coarsen(f::Field{VectorComponent{:east_north}}, ::Support, ::Rule; kwargs...) =
    refuse_declared(:coarsen, f)
coarsen(f::Field{<:Quantiles}, ::Support; kwargs...) = refuse_declared(:coarsen, f)
coarsen(f::Field{<:Quantiles}, ::Support, ::Rule; kwargs...) = refuse_declared(:coarsen, f)

"""
    refine(f, to; measure, backend)
    refine(f, to)

`f` on the finer support `to`.

`Extensive` splits each cell's total among its children in proportion to the named
measure at the fine level, so the total over the children is the total the parent held.
Every semantics whose value is a density or a share gives each child the parent's
value, which conserves the integral because the children tile the parent exactly
(decision 0005) and needs no measure to do it.

`CategoricalFraction` and `Quantiles` have no form at all: see `REFUSAL_TABLE`.
"""
function refine(f::Field{Extensive,T,D,L}, to::Support{L2};
                 measure::Measured, backend::Backend) where {T,D,L,L2}
    require_columnar(f, "Fields.refine")
    require_same_family(f.support, to, "Fields.refine")
    fine = values_of(measure)
    seg = block_segmentation(fine, L, L2, "Fields.refine")
    totals = segmented_sum(eltype(fine), fine, seg, backend)
    block = block_size(L, L2)
    shares = fine ./ repeat(totals, inner = block)
    return reduced(f, Extensive(), repeat(f.data, inner = block) .* shares, to, :refine)
end

for S in (:Intensive, :FluxDensity, :Fraction)
    @eval function refine(f::Field{$S,T,D,L}, to::Support{L2}) where {T,D,L,L2}
        return reduced(f, $S(), spread(f, L, L2), to, :refine)
    end
end

function refine(f::Field{CategoricalLabel{Legend},T,D,L}, to::Support{L2}) where
                {Legend,T,D,L,L2}
    return reduced(f, CategoricalLabel{Legend}(), spread(f, L, L2), to, :refine)
end

function refine(f::Field{VectorComponent{:cartesian},T,D,L}, to::Support{L2}) where
                {T,D,L,L2}
    return reduced(f, VectorComponent{:cartesian}(), spread(f, L, L2), to, :refine)
end

"""
    spread(f, from_level, to_level)

Each cell's value repeated over the cells it holds at `to_level`, in the order the
bisection numbers them, with the checks a refinement makes first.
"""
function spread(f::Field, from_level::Integer, to_level::Integer)
    require_columnar(f, "Fields.refine")
    to_level > from_level || refuse(
        "level crossing", "Fields.refine",
        "level $(to_level) is not finer than level $(from_level)")
    length(f.data) == ncells(from_level) || refuse(
        "level crossing extent", "Fields.refine",
        "level $(from_level) is $(ncells(from_level)) cells and the field holds " *
        "$(length(f.data))")
    return repeat(f.data, inner = block_size(from_level, to_level))
end

refine(f::Field{VectorComponent{:east_north}}, ::Support; kwargs...) =
    refuse_declared(:refine, f)
refine(f::Field{<:CategoricalFraction}, ::Support; kwargs...) = refuse_declared(:refine, f)
refine(f::Field{<:Quantiles}, ::Support; kwargs...) = refuse_declared(:refine, f)

"""
    time_reduce(series)

The one field a contiguous series of fields reduces to over the union of their
intervals, by the rule their time semantics fixes.

The series is a `Time.Forcing`, so the contiguity of the intervals is checked where it
is declared rather than restated here, and its one value type is what makes every field
in it agree in semantics, dimension and support.

An `IntervalMean` reduces by a duration-weighted mean, so the mean over the union is
the mean the parts carried. An `IntervalAccumulation` reduces by a sum. An
`EndpointState` reduces to the state at the last interval's end. `Instantaneous` and
`Static` have no form: see `REFUSAL_TABLE`.
"""
function time_reduce(series::Forcing{FT,F}) where {FT,S,F<:Field{S,IntervalMean}}
    weights = map(duration, series.intervals)
    total = sum(weights)
    data = sum(w .* f.data for (w, f) in zip(weights, series.values)) ./ total
    return retimed(series, data, :time_reduce)
end

function time_reduce(series::Forcing{FT,F}) where {FT,S,F<:Field{S,IntervalAccumulation}}
    return retimed(series, sum(f.data for f in series.values), :time_reduce)
end

function time_reduce(series::Forcing{FT,F}) where {FT,S,F<:Field{S,EndpointState}}
    return retimed(series, copy(last(series.values).data), :time_reduce)
end

time_reduce(series::Forcing{FT,F}) where {FT,S,F<:Field{S,Instantaneous}} =
    refuse_declared(:time_reduce, first(series.values))

time_reduce(series::Forcing{FT,F}) where {FT,S,F<:Field{S,Static}} =
    refuse_declared(:time_reduce, first(series.values))

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
