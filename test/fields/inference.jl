using Test
using Fiddlybits: Fields, Time, Mesh, Backends, Dimensions
using UUIDs: UUID

# fields.inference_tight: docs/plans/fiddlybits-52v.3-fields.md, section
# "Inference, and what it costs", and decision 0006. Rides the same two closed
# vocabularies test/fields/semantics_closure.jl's operator-closure walk reads,
# Fields.semantics_types() and Time.time_semantics(), so a semantics or time
# semantics added later carries this assertion without anyone remembering to
# add it: the loops below skip a head only when it has no working form, which
# test/fields/semantics_closure.jl already establishes by name, not by a
# second list kept in step with it by hand.
#
# A pair with only a declared refusal (REFUSAL_TABLE) carries nothing to
# infer, since a refusing method raises rather than returns; @inferred asks a
# question a raise has no answer to, so those pairs are absent from the call
# tables below rather than wrapped in a call expected to throw.

module InferenceMesh

using Fiddlybits: Mesh

const FINE = 2
const COARSE = 1
const HIERARCHY = Mesh.hierarchy(FINE)

level(l) = HIERARCHY.levels[l + 1]
geometry(l) = Mesh.geometry(level(l), Mesh.stencils(level(l)))

support(l) = Mesh.Support(l, level(l), geometry(l); kind = :icosahedral_bisection,
                           refinement = (), radius = 1.0, element_type = :Float64,
                           fractions = ())

const FINE_SUPPORT = support(FINE)
const COARSE_SUPPORT = support(COARSE)
const FINE_AREA = geometry(FINE).cell_area
const NFINE = Mesh.ncells(FINE)
const NCOARSE = Mesh.ncells(COARSE)

end # module InferenceMesh

const IM = InferenceMesh
const RUN = UUID("2f1d4a80-0000-4000-8000-000000000002")
const BACKEND = Backends.CPU(4)
const AREA = Fields.Measured{:primal_cell_area}(IM.FINE_AREA)
const LEGEND = (:rock, :ice)

"A field at `support` carrying `data`, `semantics` and `time`, over `Dimensions.MASS`
unless `dimension` names another."
field(semantics, data, support; dimension = Dimensions.MASS,
      time = Time.TimeSupport(Time.IntervalMean(),
                              Time.Interval(Time.SimTime(0.0), Time.SimTime(3600.0)))) =
    Fields.Field(semantics = semantics, dimension = dimension, data = data,
                support = support, time = time, origin = Fields.unstamped(:inference, RUN))

"A field that varies cell by cell, so a mean and a sum give different numbers."
inference_varying(n) = [1.0 + sin(3.0 * i) for i in 1:n]

"Labels that alternate cell by cell between the two classes of `LEGEND`."
inference_alternating(n) = [isodd(i) ? :rock : :ice for i in 1:n]

fine_field(semantics) = field(semantics, inference_varying(IM.NFINE), IM.FINE_SUPPORT)
coarse_field(semantics) = field(semantics, inference_varying(IM.NCOARSE), IM.COARSE_SUPPORT)
fine_labels() = field(Fields.CategoricalLabel{:inference_closure}(),
                     inference_alternating(IM.NFINE), IM.FINE_SUPPORT;
                     dimension = Dimensions.DIMENSIONLESS)
coarse_labels() = field(Fields.CategoricalLabel{:inference_closure}(),
                       inference_alternating(IM.NCOARSE), IM.COARSE_SUPPORT;
                       dimension = Dimensions.DIMENSIONLESS)
fine_fractions() = field(Fields.CategoricalFraction{:inference_closure}(),
                         hcat(fill(0.25, IM.NFINE), fill(0.75, IM.NFINE)), IM.FINE_SUPPORT;
                         dimension = Dimensions.DIMENSIONLESS)

"`n` cells by two levels, each level varying cell by cell."
inference_layered(n) = inference_varying(n) .* [1.0 2.0]

fine_layered(semantics) = field(semantics, inference_layered(IM.NFINE), IM.FINE_SUPPORT)
coarse_layered(semantics) = field(semantics, inference_layered(IM.NCOARSE), IM.COARSE_SUPPORT)
fine_layered_labels() = field(Fields.CategoricalLabel{:inference_closure}(),
                              hcat(inference_alternating(IM.NFINE),
                                   inference_alternating(IM.NFINE)), IM.FINE_SUPPORT;
                              dimension = Dimensions.DIMENSIONLESS)
coarse_layered_labels() = field(Fields.CategoricalLabel{:inference_closure}(),
                                hcat(inference_alternating(IM.NCOARSE),
                                     inference_alternating(IM.NCOARSE)), IM.COARSE_SUPPORT;
                                dimension = Dimensions.DIMENSIONLESS)
fine_layered_fractions() = field(Fields.CategoricalFraction{:inference_closure}(),
                                 stack((hcat(fill(0.25, IM.NFINE), fill(0.75, IM.NFINE)),
                                        hcat(fill(0.5, IM.NFINE), fill(0.5, IM.NFINE)));
                                       dims = 2),
                                 IM.FINE_SUPPORT; dimension = Dimensions.DIMENSIONLESS)

"""
    COARSEN_CALLS

One representative, working `Fields.coarsen` call per `Fields.semantics_types()`
head that has one, on a field of one value per cell (a class-fraction field holds its
legend on a second axis). `VectorComponent` and `Quantiles` carry no working coarsen
form and are absent rather than forced through a call meant to raise.
"""
const COARSEN_CALLS = (
    Extensive = () -> Fields.coarsen(fine_field(Fields.Extensive()), IM.COARSE_SUPPORT;
                                     reservoir = false, backend = BACKEND),
    FluxDensity = () -> Fields.coarsen(fine_field(Fields.FluxDensity()), IM.COARSE_SUPPORT;
                                       measure = AREA, reservoir = false, backend = BACKEND),
    Fraction = () -> Fields.coarsen(fine_field(Fields.Fraction()), IM.COARSE_SUPPORT;
                                    measure = AREA, reservoir = false, backend = BACKEND),
    Intensive = () -> Fields.coarsen(fine_field(Fields.Intensive()), IM.COARSE_SUPPORT,
                                     Fields.AreaMean(); measure = AREA, reservoir = false,
                                     backend = BACKEND),
    CategoricalLabel = () -> Fields.coarsen(fine_labels(), IM.COARSE_SUPPORT;
                                            legend = LEGEND, measure = AREA,
                                            reservoir = false, backend = BACKEND),
    CategoricalFraction = () -> Fields.coarsen(fine_fractions(), IM.COARSE_SUPPORT;
                                               legend = LEGEND, measure = AREA,
                                               reservoir = false, backend = BACKEND),
)

"""
    COLUMN_COARSEN_CALLS

The heads of `COARSEN_CALLS` again, each called on a field of cells by two levels.
"""
const COLUMN_COARSEN_CALLS = (
    Extensive = () -> Fields.coarsen(fine_layered(Fields.Extensive()), IM.COARSE_SUPPORT;
                                     reservoir = false, backend = BACKEND),
    FluxDensity = () -> Fields.coarsen(fine_layered(Fields.FluxDensity()), IM.COARSE_SUPPORT;
                                       measure = AREA, reservoir = false, backend = BACKEND),
    Fraction = () -> Fields.coarsen(fine_layered(Fields.Fraction()), IM.COARSE_SUPPORT;
                                    measure = AREA, reservoir = false, backend = BACKEND),
    Intensive = () -> Fields.coarsen(fine_layered(Fields.Intensive()), IM.COARSE_SUPPORT,
                                     Fields.AreaMean(); measure = AREA, reservoir = false,
                                     backend = BACKEND),
    CategoricalLabel = () -> Fields.coarsen(fine_layered_labels(), IM.COARSE_SUPPORT;
                                            legend = LEGEND, measure = AREA,
                                            reservoir = false, backend = BACKEND),
    CategoricalFraction = () -> Fields.coarsen(fine_layered_fractions(), IM.COARSE_SUPPORT;
                                               legend = LEGEND, measure = AREA,
                                               reservoir = false, backend = BACKEND),
)

"""
    REFINE_CALLS

The same for `Fields.refine`: `CategoricalFraction` and `Quantiles` carry no
working refine form (`REFUSAL_TABLE` refuses both) and are absent.
"""
const REFINE_CALLS = (
    Extensive = () -> Fields.refine(coarse_field(Fields.Extensive()), IM.FINE_SUPPORT;
                                    measure = AREA, reservoir = false, backend = BACKEND),
    FluxDensity = () -> Fields.refine(coarse_field(Fields.FluxDensity()), IM.FINE_SUPPORT;
                                      measure = AREA, reservoir = false, backend = BACKEND),
    Fraction = () -> Fields.refine(coarse_field(Fields.Fraction()), IM.FINE_SUPPORT;
                                   measure = AREA, reservoir = false, backend = BACKEND),
    Intensive = () -> Fields.refine(coarse_field(Fields.Intensive()), IM.FINE_SUPPORT),
    CategoricalLabel = () -> Fields.refine(coarse_labels(), IM.FINE_SUPPORT;
                                           legend = LEGEND, measure = AREA,
                                           reservoir = false, backend = BACKEND),
    VectorComponent = () -> Fields.refine(coarse_field(Fields.VectorComponent{:cartesian}()),
                                          IM.FINE_SUPPORT),
)

"""
    COLUMN_REFINE_CALLS

The heads of `REFINE_CALLS` again, each called on a field of cells by two levels.
"""
const COLUMN_REFINE_CALLS = (
    Extensive = () -> Fields.refine(coarse_layered(Fields.Extensive()), IM.FINE_SUPPORT;
                                    measure = AREA, reservoir = false, backend = BACKEND),
    FluxDensity = () -> Fields.refine(coarse_layered(Fields.FluxDensity()), IM.FINE_SUPPORT;
                                      measure = AREA, reservoir = false, backend = BACKEND),
    Fraction = () -> Fields.refine(coarse_layered(Fields.Fraction()), IM.FINE_SUPPORT;
                                   measure = AREA, reservoir = false, backend = BACKEND),
    Intensive = () -> Fields.refine(coarse_layered(Fields.Intensive()), IM.FINE_SUPPORT),
    CategoricalLabel = () -> Fields.refine(coarse_layered_labels(), IM.FINE_SUPPORT;
                                           legend = LEGEND, measure = AREA,
                                           reservoir = false, backend = BACKEND),
    VectorComponent = () -> Fields.refine(coarse_layered(Fields.VectorComponent{:cartesian}()),
                                          IM.FINE_SUPPORT),
)

"A `Time.Forcing` of `datas` at `semantics` and `time_semantics`, one hour per entry."
function series(semantics, time_semantics, datas)
    hour(k) = Time.Interval(Time.SimTime(3600.0 * (k - 1)), Time.SimTime(3600.0 * k))
    return Time.Forcing([hour(k) for k in eachindex(datas)],
                        [field(semantics, datas[k], IM.FINE_SUPPORT;
                              time = Time.TimeSupport(time_semantics, hour(k)))
                         for k in eachindex(datas)])
end

"""
    TIME_REDUCE_CALLS

One representative, working `Fields.time_reduce` call per `Time.time_semantics()`
member that has one: `time_reduce` dispatches on time semantics alone, which
test/fields/semantics_closure.jl's operator-closure walk finds (every one of its
methods is free in the field's own semantics), so the semantics named here is a
fixed, unremarkable stand-in and not a second axis being walked. `Static` and
`Instantaneous` carry no working form (`REFUSAL_TABLE` refuses both) and are
absent.
"""
const TIME_REDUCE_CALLS = (
    IntervalMean = () -> Fields.time_reduce(
        series(Fields.FluxDensity(), Time.IntervalMean(),
              [inference_varying(IM.NFINE), inference_varying(IM.NFINE)]);
        reservoir = false, backend = BACKEND),
    IntervalAccumulation = () -> Fields.time_reduce(
        series(Fields.Extensive(), Time.IntervalAccumulation(),
              [inference_varying(IM.NFINE), inference_varying(IM.NFINE)]);
        reservoir = false, backend = BACKEND),
    EndpointState = () -> Fields.time_reduce(
        series(Fields.Intensive(), Time.EndpointState(),
              [inference_varying(IM.NFINE), inference_varying(IM.NFINE)])),
)

"""
    COLUMN_TIME_REDUCE_CALLS

The members of `TIME_REDUCE_CALLS` again, each over a series of fields of cells by two
levels.
"""
const COLUMN_TIME_REDUCE_CALLS = (
    IntervalMean = () -> Fields.time_reduce(
        series(Fields.FluxDensity(), Time.IntervalMean(),
              [inference_layered(IM.NFINE), inference_layered(IM.NFINE)]);
        reservoir = false, backend = BACKEND),
    IntervalAccumulation = () -> Fields.time_reduce(
        series(Fields.Extensive(), Time.IntervalAccumulation(),
              [inference_layered(IM.NFINE), inference_layered(IM.NFINE)]);
        reservoir = false, backend = BACKEND),
    EndpointState = () -> Fields.time_reduce(
        series(Fields.Intensive(), Time.EndpointState(),
              [inference_layered(IM.NFINE), inference_layered(IM.NFINE)])),
)

"Whether `x` is a `(Field, ledger)` pair of a concrete type."
pair(x) = x isa Tuple{Fields.Field,Any} && isconcretetype(typeof(x))

"The data shapes each operator is walked over, with the call tables for each."
const SHAPES = (
    (name = "one value per cell", coarsen = COARSEN_CALLS, refine = REFINE_CALLS,
     time_reduce = TIME_REDUCE_CALLS),
    (name = "cells by levels", coarsen = COLUMN_COARSEN_CALLS, refine = COLUMN_REFINE_CALLS,
     time_reduce = COLUMN_TIME_REDUCE_CALLS),
)

@testset "fields.inference_tight" begin
    @testset "the call tables name only real heads" begin
        for shape in SHAPES
            @test issubset(keys(shape.coarsen), Tuple(nameof(S) for S in Fields.semantics_types()))
            @test issubset(keys(shape.refine), Tuple(nameof(S) for S in Fields.semantics_types()))
            @test issubset(keys(shape.time_reduce),
                           Tuple(nameof(typeof(T)) for T in Time.time_semantics()))
        end
    end

    for shape in SHAPES
        @testset "coarsen, $(shape.name)" begin
            for S in Fields.semantics_types()
                name = nameof(S)
                haskey(shape.coarsen, name) || continue
                @testset "$(name)" begin
                    @test pair(@inferred(getfield(shape.coarsen, name)()))
                end
            end
        end

        @testset "refine, $(shape.name)" begin
            for S in Fields.semantics_types()
                name = nameof(S)
                haskey(shape.refine, name) || continue
                @testset "$(name)" begin
                    @test pair(@inferred(getfield(shape.refine, name)()))
                end
            end
        end

        @testset "time_reduce, $(shape.name)" begin
            for T in Time.time_semantics()
                name = nameof(typeof(T))
                haskey(shape.time_reduce, name) || continue
                @testset "$(name)" begin
                    @test pair(@inferred(getfield(shape.time_reduce, name)()))
                end
            end
        end
    end

    @testset "the walk over cells by levels returns one ledger per level" begin
        _, ledger = COLUMN_COARSEN_CALLS.Extensive()
        @test ledger isa Fields.ColumnLedgers{:total}
        _, class_ledgers = COLUMN_COARSEN_CALLS.CategoricalFraction()
        @test Fields.ledger_of(class_ledgers, :rock) isa Fields.ColumnLedgers
    end

    @testset "positive control: an operator that picks its semantics at runtime fails @inferred" begin
        # The compiler would constant-fold a call on a literal Bool, which is
        # exactly the case this control must not accidentally test; the flag
        # is read from a Ref so no call site's argument is a compile-time
        # constant (decision 0006, "Inference, and what it costs").
        flag = Ref(true)
        runtime_pick() = flag[] ? Fields.Extensive() : Fields.Intensive()
        @test_throws ErrorException @inferred(runtime_pick())

        @testset "control: the two branches really are different concrete types" begin
            @test typeof(Fields.Extensive()) !== typeof(Fields.Intensive())
            @test isconcretetype(typeof(Fields.Extensive()))
            @test isconcretetype(typeof(Fields.Intensive()))
        end
    end
end
