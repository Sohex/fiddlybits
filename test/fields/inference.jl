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
#
# Each call table below is a function of a `Backends.Backend`, called once per
# entry of BACKENDS: the backend is an axis SHAPES is built over, not a second
# table copied by hand for the device. An operator on device arrays is the
# same operator compiled at another array type (fiddlybits-52v.3.21), so
# building a field's data with `Backends.on(data, backend)` and passing
# `backend` through to the operator call is what puts it on the device.

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
const BACKENDS = (("CPU", Backends.CPU(4)), ("GPU", Backends.GPU(4)))
const LEGEND = (:rock, :ice)

"The primal-cell-area measure, moved to `backend`."
area_of(backend) = Fields.Measured{:primal_cell_area}(Backends.on(IM.FINE_AREA, backend))

"A field at `support` carrying `data` moved to `backend`, with `semantics` and `time`,
over `Dimensions.MASS` unless `dimension` names another."
field(semantics, data, support, backend; dimension = Dimensions.MASS,
      time = Time.TimeSupport(Time.IntervalMean(),
                              Time.Interval(Time.SimTime(0.0), Time.SimTime(3600.0)))) =
    Fields.Field(semantics = semantics, dimension = dimension, data = Backends.on(data, backend),
                support = support, time = time, origin = Fields.unstamped(:inference, RUN))

"A field at `support` carrying `data` as given, with `semantics` and `time`: for
CategoricalLabel data, whose element type is not a bits type, so no `Backend` can hold
it and it stays where `inference_alternating` built it."
label_field(semantics, data, support; dimension = Dimensions.DIMENSIONLESS,
            time = Time.TimeSupport(Time.IntervalMean(),
                                    Time.Interval(Time.SimTime(0.0), Time.SimTime(3600.0)))) =
    Fields.Field(semantics = semantics, dimension = dimension, data = data,
                support = support, time = time, origin = Fields.unstamped(:inference, RUN))

"A field that varies cell by cell, so a mean and a sum give different numbers."
inference_varying(n) = [1.0 + sin(3.0 * i) for i in 1:n]

"Labels that alternate cell by cell between the two classes of `LEGEND`."
inference_alternating(n) = [isodd(i) ? :rock : :ice for i in 1:n]

fine_field(semantics, backend) = field(semantics, inference_varying(IM.NFINE), IM.FINE_SUPPORT, backend)
coarse_field(semantics, backend) = field(semantics, inference_varying(IM.NCOARSE), IM.COARSE_SUPPORT, backend)
fine_labels() = label_field(Fields.CategoricalLabel{:inference_closure}(),
                            inference_alternating(IM.NFINE), IM.FINE_SUPPORT)
coarse_labels() = label_field(Fields.CategoricalLabel{:inference_closure}(),
                              inference_alternating(IM.NCOARSE), IM.COARSE_SUPPORT)
fine_fractions(backend) = field(Fields.CategoricalFraction{:inference_closure}(),
                                hcat(fill(0.25, IM.NFINE), fill(0.75, IM.NFINE)), IM.FINE_SUPPORT,
                                backend; dimension = Dimensions.DIMENSIONLESS)

"`n` cells by two levels, each level varying cell by cell."
inference_layered(n) = inference_varying(n) .* [1.0 2.0]

fine_layered(semantics, backend) = field(semantics, inference_layered(IM.NFINE), IM.FINE_SUPPORT, backend)
coarse_layered(semantics, backend) = field(semantics, inference_layered(IM.NCOARSE), IM.COARSE_SUPPORT, backend)
fine_layered_labels() = label_field(Fields.CategoricalLabel{:inference_closure}(),
                                    hcat(inference_alternating(IM.NFINE),
                                         inference_alternating(IM.NFINE)), IM.FINE_SUPPORT)
coarse_layered_labels() = label_field(Fields.CategoricalLabel{:inference_closure}(),
                                      hcat(inference_alternating(IM.NCOARSE),
                                           inference_alternating(IM.NCOARSE)), IM.COARSE_SUPPORT)
fine_layered_fractions(backend) = field(Fields.CategoricalFraction{:inference_closure}(),
                                        stack((hcat(fill(0.25, IM.NFINE), fill(0.75, IM.NFINE)),
                                               hcat(fill(0.5, IM.NFINE), fill(0.5, IM.NFINE)));
                                              dims = 2),
                                        IM.FINE_SUPPORT, backend; dimension = Dimensions.DIMENSIONLESS)

"""
    coarsen_calls(backend)

One representative, working `Fields.coarsen` call per `Fields.semantics_types()` head
that has one, on a field of one value per cell (a class-fraction field holds its legend
on a second axis), its data and measure moved to `backend` and the operator launched
there. `VectorComponent` and `Quantiles` carry no working coarsen form and are absent
rather than forced through a call meant to raise.
"""
coarsen_calls(backend) = (
    Extensive = () -> Fields.coarsen(fine_field(Fields.Extensive(), backend), IM.COARSE_SUPPORT;
                                     reservoir = false, backend = backend),
    FluxDensity = () -> Fields.coarsen(fine_field(Fields.FluxDensity(), backend), IM.COARSE_SUPPORT;
                                       measure = area_of(backend), reservoir = false, backend = backend),
    Fraction = () -> Fields.coarsen(fine_field(Fields.Fraction(), backend), IM.COARSE_SUPPORT;
                                    measure = area_of(backend), reservoir = false, backend = backend),
    Intensive = () -> Fields.coarsen(fine_field(Fields.Intensive(), backend), IM.COARSE_SUPPORT,
                                     Fields.AreaMean(); measure = area_of(backend), reservoir = false,
                                     backend = backend),
    CategoricalLabel = () -> Fields.coarsen(fine_labels(), IM.COARSE_SUPPORT;
                                            legend = LEGEND, measure = area_of(backend),
                                            reservoir = false, backend = backend),
    CategoricalFraction = () -> Fields.coarsen(fine_fractions(backend), IM.COARSE_SUPPORT;
                                               legend = LEGEND, measure = area_of(backend),
                                               reservoir = false, backend = backend),
)

"""
    column_coarsen_calls(backend)

The heads of `coarsen_calls` again, each called on a field of cells by two levels, on
`backend`.
"""
column_coarsen_calls(backend) = (
    Extensive = () -> Fields.coarsen(fine_layered(Fields.Extensive(), backend), IM.COARSE_SUPPORT;
                                     reservoir = false, backend = backend),
    FluxDensity = () -> Fields.coarsen(fine_layered(Fields.FluxDensity(), backend), IM.COARSE_SUPPORT;
                                       measure = area_of(backend), reservoir = false, backend = backend),
    Fraction = () -> Fields.coarsen(fine_layered(Fields.Fraction(), backend), IM.COARSE_SUPPORT;
                                    measure = area_of(backend), reservoir = false, backend = backend),
    Intensive = () -> Fields.coarsen(fine_layered(Fields.Intensive(), backend), IM.COARSE_SUPPORT,
                                     Fields.AreaMean(); measure = area_of(backend), reservoir = false,
                                     backend = backend),
    CategoricalLabel = () -> Fields.coarsen(fine_layered_labels(), IM.COARSE_SUPPORT;
                                            legend = LEGEND, measure = area_of(backend),
                                            reservoir = false, backend = backend),
    CategoricalFraction = () -> Fields.coarsen(fine_layered_fractions(backend), IM.COARSE_SUPPORT;
                                               legend = LEGEND, measure = area_of(backend),
                                               reservoir = false, backend = backend),
)

"""
    refine_calls(backend)

The same for `Fields.refine`, on `backend`: `CategoricalFraction` and `Quantiles` carry
no working refine form (`REFUSAL_TABLE` refuses both) and are absent.
"""
refine_calls(backend) = (
    Extensive = () -> Fields.refine(coarse_field(Fields.Extensive(), backend), IM.FINE_SUPPORT;
                                    measure = area_of(backend), reservoir = false, backend = backend),
    FluxDensity = () -> Fields.refine(coarse_field(Fields.FluxDensity(), backend), IM.FINE_SUPPORT;
                                      measure = area_of(backend), reservoir = false, backend = backend),
    Fraction = () -> Fields.refine(coarse_field(Fields.Fraction(), backend), IM.FINE_SUPPORT;
                                   measure = area_of(backend), reservoir = false, backend = backend),
    Intensive = () -> Fields.refine(coarse_field(Fields.Intensive(), backend), IM.FINE_SUPPORT),
    CategoricalLabel = () -> Fields.refine(coarse_labels(), IM.FINE_SUPPORT;
                                           legend = LEGEND, measure = area_of(backend),
                                           reservoir = false, backend = backend),
    VectorComponent = () -> Fields.refine(coarse_field(Fields.VectorComponent{:cartesian}(), backend),
                                          IM.FINE_SUPPORT),
)

"""
    column_refine_calls(backend)

The heads of `refine_calls` again, each called on a field of cells by two levels, on
`backend`.
"""
column_refine_calls(backend) = (
    Extensive = () -> Fields.refine(coarse_layered(Fields.Extensive(), backend), IM.FINE_SUPPORT;
                                    measure = area_of(backend), reservoir = false, backend = backend),
    FluxDensity = () -> Fields.refine(coarse_layered(Fields.FluxDensity(), backend), IM.FINE_SUPPORT;
                                      measure = area_of(backend), reservoir = false, backend = backend),
    Fraction = () -> Fields.refine(coarse_layered(Fields.Fraction(), backend), IM.FINE_SUPPORT;
                                   measure = area_of(backend), reservoir = false, backend = backend),
    Intensive = () -> Fields.refine(coarse_layered(Fields.Intensive(), backend), IM.FINE_SUPPORT),
    CategoricalLabel = () -> Fields.refine(coarse_layered_labels(), IM.FINE_SUPPORT;
                                           legend = LEGEND, measure = area_of(backend),
                                           reservoir = false, backend = backend),
    VectorComponent = () -> Fields.refine(coarse_layered(Fields.VectorComponent{:cartesian}(), backend),
                                          IM.FINE_SUPPORT),
)

"A `Time.Forcing` of `datas` at `semantics` and `time_semantics`, moved to `backend`, one
hour per entry."
function series(semantics, time_semantics, datas, backend)
    hour(k) = Time.Interval(Time.SimTime(3600.0 * (k - 1)), Time.SimTime(3600.0 * k))
    return Time.Forcing([hour(k) for k in eachindex(datas)],
                        [field(semantics, datas[k], IM.FINE_SUPPORT, backend;
                              time = Time.TimeSupport(time_semantics, hour(k)))
                         for k in eachindex(datas)])
end

"""
    time_reduce_calls(backend)

One representative, working `Fields.time_reduce` call per `Time.time_semantics()`
member that has one, on `backend`: `time_reduce` dispatches on time semantics alone,
which test/fields/semantics_closure.jl's operator-closure walk finds (every one of its
methods is free in the field's own semantics), so the semantics named here is a
fixed, unremarkable stand-in and not a second axis being walked. `Static` and
`Instantaneous` carry no working form (`REFUSAL_TABLE` refuses both) and are
absent.
"""
time_reduce_calls(backend) = (
    IntervalMean = () -> Fields.time_reduce(
        series(Fields.FluxDensity(), Time.IntervalMean(),
              [inference_varying(IM.NFINE), inference_varying(IM.NFINE)], backend);
        reservoir = false, backend = backend),
    IntervalAccumulation = () -> Fields.time_reduce(
        series(Fields.Extensive(), Time.IntervalAccumulation(),
              [inference_varying(IM.NFINE), inference_varying(IM.NFINE)], backend);
        reservoir = false, backend = backend),
    EndpointState = () -> Fields.time_reduce(
        series(Fields.Intensive(), Time.EndpointState(),
              [inference_varying(IM.NFINE), inference_varying(IM.NFINE)], backend)),
)

"""
    column_time_reduce_calls(backend)

The members of `time_reduce_calls` again, each over a series of fields of cells by two
levels, on `backend`.
"""
column_time_reduce_calls(backend) = (
    IntervalMean = () -> Fields.time_reduce(
        series(Fields.FluxDensity(), Time.IntervalMean(),
              [inference_layered(IM.NFINE), inference_layered(IM.NFINE)], backend);
        reservoir = false, backend = backend),
    IntervalAccumulation = () -> Fields.time_reduce(
        series(Fields.Extensive(), Time.IntervalAccumulation(),
              [inference_layered(IM.NFINE), inference_layered(IM.NFINE)], backend);
        reservoir = false, backend = backend),
    EndpointState = () -> Fields.time_reduce(
        series(Fields.Intensive(), Time.EndpointState(),
              [inference_layered(IM.NFINE), inference_layered(IM.NFINE)], backend)),
)

"Whether `x` is a `(Field, ledger)` pair of a concrete type."
pair(x) = x isa Tuple{Fields.Field,Any} && isconcretetype(typeof(x))

"""
    SHAPES

The data shapes each operator is walked over, crossed with `BACKENDS`: one call-table
generator per operator (`coarsen_calls` and its column and refine and time_reduce
counterparts), called once per entry of `BACKENDS`, so the CPU and GPU entries below are
built from the same table rather than a second one copied for the device.
"""
const SHAPES = Tuple(
    (name = "$(kind), $(bname)", coarsen = coarsen_of(backend), refine = refine_of(backend),
     time_reduce = time_reduce_of(backend))
    for (kind, coarsen_of, refine_of, time_reduce_of) in
        (("one value per cell", coarsen_calls, refine_calls, time_reduce_calls),
         ("cells by levels", column_coarsen_calls, column_refine_calls, column_time_reduce_calls))
    for (bname, backend) in BACKENDS
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
        for (bname, backend) in BACKENDS
            @testset "$(bname)" begin
                calls = column_coarsen_calls(backend)
                _, ledger = calls.Extensive()
                @test ledger isa Fields.ColumnLedgers{:total}
                _, class_ledgers = calls.CategoricalFraction()
                @test Fields.ledger_of(class_ledgers, :rock) isa Fields.ColumnLedgers
            end
        end
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

        for (bname, backend) in BACKENDS
            @testset "the same runtime choice fails @inferred through an operator call, on $(bname)" begin
                # FluxDensity and Fraction share one coarsen signature (measure, reservoir,
                # backend; no extra positional argument), so the runtime choice below
                # reaches a real call on either branch rather than a MethodError.
                runtime_semantics() = flag[] ? Fields.FluxDensity() : Fields.Fraction()
                runtime_coarsen() = Fields.coarsen(fine_field(runtime_semantics(), backend),
                                                   IM.COARSE_SUPPORT; measure = area_of(backend),
                                                   reservoir = false, backend = backend)
                @test_throws ErrorException @inferred(runtime_coarsen())
            end
        end
    end
end
