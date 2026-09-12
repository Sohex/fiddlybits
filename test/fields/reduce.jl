using Test
using Fiddlybits: Fields, Dimensions, Time, Mesh, Backends
using Fiddlybits.Verdicts: Refusal
using UUIDs: UUID

# mesh.constant_field_reduction and the declared refusal table:
# docs/oracles/registry.toml and docs/plans/fiddlybits-52v.3-fields.md, row 52v.3.3.
#
# The two levels are built here rather than taken from the shared fixture, which holds
# one level; a crossing needs both ends.

const R = Fields
const RD = Dimensions

module ReduceMesh

using Fiddlybits: Mesh

const FINE = 2
const COARSE = 1
const HIERARCHY = Mesh.hierarchy(FINE)

level(l) = HIERARCHY.levels[l + 1]
geometry(l) = Mesh.geometry(level(l), Mesh.stencils(level(l)))

support(l; kind = :icosahedral_bisection, radius = 1.0, element_type = :Float64,
           refinement = (), fractions = ()) =
    Mesh.Support(l, level(l), geometry(l); kind = kind, refinement = refinement,
                  radius = radius, element_type = element_type, fractions = fractions)

const FINE_SUPPORT = support(FINE)
const COARSE_SUPPORT = support(COARSE)
const FINE_AREA = geometry(FINE).cell_area
const COARSE_AREA = geometry(COARSE).cell_area
const NFINE = Mesh.ncells(FINE)
const NCOARSE = Mesh.ncells(COARSE)
const BLOCK = NFINE ÷ NCOARSE

end # module ReduceMesh

const RM = ReduceMesh
const RUN = UUID("2f1d4a80-0000-4000-8000-000000000000")
const BACKEND = Backends.CPU(8)
const AREA = R.Measured{:primal_cell_area}(RM.FINE_AREA)

"A field at `support` carrying `data`, `semantics` and `dimension`."
reduce_field(semantics, data, support; dimension = RD.MASS,
              time = Time.TimeSupport(Time.IntervalMean(),
                                      Time.Interval(Time.SimTime(0.0),
                                                    Time.SimTime(3600.0)))) =
    R.Field(semantics = semantics, dimension = dimension, data = data,
            support = support, time = time, origin = R.unstamped(:test, RUN))

"A field that varies cell by cell, so an unweighted mean and an area mean differ."
varying(n) = [1.0 + sin(3.0 * i) for i in 1:n]

@testset "mesh.constant_field_reduction" begin
    @testset "the mesh's area variation is wide enough to expose a count weighting" begin
        spread = maximum(RM.FINE_AREA) / minimum(RM.FINE_AREA)
        @test spread > 1.2
    end

    @testset "a constant field coarsens to the constant" begin
        for (semantics, kwargs) in ((R.FluxDensity(), (measure = AREA,)),
                                    (R.Fraction(), (measure = AREA,)))
            f = reduce_field(semantics, fill(2.5, RM.NFINE), RM.FINE_SUPPORT)
            c = R.coarsen(f, RM.COARSE_SUPPORT; backend = BACKEND, kwargs...)
            @test length(R.data(c)) == RM.NCOARSE
            @test all(≈(2.5), R.data(c))
            @test R.level(c) == RM.COARSE
            @test R.semantics(c) === semantics
        end

        f = reduce_field(R.Intensive(), fill(2.5, RM.NFINE), RM.FINE_SUPPORT)
        c = R.coarsen(f, RM.COARSE_SUPPORT, R.AreaMean(); measure = AREA, backend = BACKEND)
        @test all(≈(2.5), R.data(c))
    end

    @testset "an extensive integral is preserved" begin
        fine = RM.FINE_AREA .* varying(RM.NFINE)
        f = reduce_field(R.Extensive(), fine, RM.FINE_SUPPORT)
        c = R.coarsen(f, RM.COARSE_SUPPORT; backend = BACKEND)
        @test sum(R.data(c)) ≈ sum(fine)
        @test length(R.data(c)) == RM.NCOARSE
    end

    @testset "the children's areas sum to the parent's" begin
        f = reduce_field(R.Extensive(), copy(RM.FINE_AREA), RM.FINE_SUPPORT)
        c = R.coarsen(f, RM.COARSE_SUPPORT; backend = BACKEND)
        @test R.data(c) ≈ RM.COARSE_AREA
    end

    @testset "positive control: a count weighting breaks the integral" begin
        values = varying(RM.NFINE)
        f = reduce_field(R.FluxDensity(), values, RM.FINE_SUPPORT)
        weighted = R.data(R.coarsen(f, RM.COARSE_SUPPORT; measure = AREA, backend = BACKEND))

        counted = [sum(@view values[(k - 1) * RM.BLOCK + 1:k * RM.BLOCK]) / RM.BLOCK
                   for k in 1:RM.NCOARSE]

        integral = sum(values .* RM.FINE_AREA)
        @test sum(weighted .* RM.COARSE_AREA) ≈ integral
        @test !isapprox(sum(counted .* RM.COARSE_AREA), integral)
        @test !isapprox(weighted, counted)
    end

    @testset "a categorical label coarsens to a histogram, never a centre sample" begin
        legend = (:rock, :ice)
        labels = [isodd(i) ? :rock : :ice for i in 1:RM.NFINE]
        f = reduce_field(R.CategoricalLabel{:lithology}(), labels, RM.FINE_SUPPORT;
                          dimension = RD.DIMENSIONLESS)
        c = R.coarsen(f, RM.COARSE_SUPPORT; legend = legend, measure = AREA,
                       backend = BACKEND)
        @test R.semantics(c) === R.CategoricalFraction{:lithology}()
        @test size(R.data(c)) == (RM.NCOARSE, length(legend))
        @test all(≈(1.0), sum(R.data(c), dims = 2))
        rock_share = [sum(RM.FINE_AREA[j] for j in (k - 1) * RM.BLOCK + 1:k * RM.BLOCK
                          if labels[j] === :rock) /
                      sum(@view RM.FINE_AREA[(k - 1) * RM.BLOCK + 1:k * RM.BLOCK])
                      for k in 1:RM.NCOARSE]
        @test R.data(c)[:, 1] ≈ rock_share
    end

    @testset "a quantile table is a table, one column per probability" begin
        values = varying(RM.NFINE)
        f = reduce_field(R.Intensive(), values, RM.FINE_SUPPORT)
        c = R.coarsen(f, RM.COARSE_SUPPORT, R.ToQuantiles{(0.0, 1.0)}(); backend = BACKEND)
        @test R.semantics(c) === R.Quantiles{(0.0, 1.0)}()
        @test size(R.data(c)) == (RM.NCOARSE, 2)
        for k in 1:RM.NCOARSE
            block = @view values[(k - 1) * RM.BLOCK + 1:k * RM.BLOCK]
            @test R.data(c)[k, 1] ≈ minimum(block)
            @test R.data(c)[k, 2] ≈ maximum(block)
        end
    end
end

@testset "Fields.refine" begin
    @testset "an extensive total splits by the fine measure and sums back" begin
        coarse = varying(RM.NCOARSE)
        f = reduce_field(R.Extensive(), coarse, RM.COARSE_SUPPORT)
        r = R.refine(f, RM.FINE_SUPPORT; measure = AREA, backend = BACKEND)
        @test length(R.data(r)) == RM.NFINE
        @test R.level(r) == RM.FINE
        for k in 1:RM.NCOARSE
            @test sum(@view R.data(r)[(k - 1) * RM.BLOCK + 1:k * RM.BLOCK]) ≈ coarse[k]
        end
        back = R.coarsen(r, RM.COARSE_SUPPORT; backend = BACKEND)
        @test R.data(back) ≈ coarse
    end

    @testset "a density gives each child the parent's value" begin
        coarse = varying(RM.NCOARSE)
        for semantics in (R.Intensive(), R.FluxDensity(), R.Fraction())
            f = reduce_field(semantics, coarse, RM.COARSE_SUPPORT)
            r = R.refine(f, RM.FINE_SUPPORT)
            @test R.semantics(r) === semantics
            @test R.data(r) == repeat(coarse, inner = RM.BLOCK)
        end
    end

    @testset "a refined flux density carries the same integral" begin
        coarse = varying(RM.NCOARSE)
        f = reduce_field(R.FluxDensity(), coarse, RM.COARSE_SUPPORT)
        r = R.refine(f, RM.FINE_SUPPORT)
        @test sum(R.data(r) .* RM.FINE_AREA) ≈ sum(coarse .* RM.COARSE_AREA)
    end
end

@testset "Fields.time_reduce" begin
    hours(k) = Time.Interval(Time.SimTime(3600.0 * (k - 1)), Time.SimTime(3600.0 * k))

    series(semantics, time_semantics, datas) = Time.Forcing(
        [hours(k) for k in 1:length(datas)],
        [reduce_field(semantics, datas[k], RM.FINE_SUPPORT;
                      time = Time.TimeSupport(time_semantics, hours(k)))
         for k in 1:length(datas)])

    @testset "an interval mean reduces by a duration-weighted mean" begin
        datas = [fill(1.0, RM.NFINE), fill(3.0, RM.NFINE)]
        r = R.time_reduce(series(R.FluxDensity(), Time.IntervalMean(), datas))
        @test all(≈(2.0), R.data(r))
        @test Time.duration(R.time_support(r)) ≈ 7200.0
        @test R.time_semantics(r) === Time.IntervalMean()
    end

    @testset "an accumulation reduces by a sum" begin
        datas = [fill(1.0, RM.NFINE), fill(3.0, RM.NFINE)]
        r = R.time_reduce(series(R.Extensive(), Time.IntervalAccumulation(), datas))
        @test all(≈(4.0), R.data(r))
        @test Time.duration(R.time_support(r)) ≈ 7200.0
    end

    @testset "an endpoint state reduces to the last one" begin
        datas = [fill(1.0, RM.NFINE), fill(3.0, RM.NFINE)]
        r = R.time_reduce(series(R.Intensive(), Time.EndpointState(), datas))
        @test all(≈(3.0), R.data(r))
    end
end

@testset "the declared refusal table" begin
    fine(semantics; dimension = RD.MASS, data = fill(1.0, RM.NFINE)) =
        reduce_field(semantics, data, RM.FINE_SUPPORT; dimension = dimension)
    coarse(semantics; dimension = RD.MASS, data = fill(1.0, RM.NCOARSE)) =
        reduce_field(semantics, data, RM.COARSE_SUPPORT; dimension = dimension)

    raised(thunk) = try
        thunk()
    catch e
        e
    end

    @testset "every entry of the table is raised by some method, with its sentence" begin
        cases = (
            (:coarsen, R.Intensive,
             () -> R.coarsen(fine(R.Intensive()), RM.COARSE_SUPPORT; backend = BACKEND)),
            (:coarsen, R.VectorComponent{:east_north},
             () -> R.coarsen(fine(R.VectorComponent{:east_north}()), RM.COARSE_SUPPORT;
                             backend = BACKEND)),
            (:refine, R.VectorComponent{:east_north},
             () -> R.refine(coarse(R.VectorComponent{:east_north}()), RM.FINE_SUPPORT)),
            (:coarsen, R.Quantiles{(0.5,)},
             () -> R.coarsen(fine(R.Quantiles{(0.5,)}()), RM.COARSE_SUPPORT;
                             backend = BACKEND)),
            (:refine, R.Quantiles{(0.5,)},
             () -> R.refine(coarse(R.Quantiles{(0.5,)}()), RM.FINE_SUPPORT)),
            (:refine, R.CategoricalFraction{:lithology},
             () -> R.refine(coarse(R.CategoricalFraction{:lithology}()), RM.FINE_SUPPORT)),
        )
        for (operator, S, thunk) in cases
            err = raised(thunk)
            @test err isa Refusal
            @test err.site == "Fields.$(operator)"
            @test err.reason == R.refusal_sentence(operator, S, Time.IntervalMean)
            @test !isempty(err.reason)
        end
    end

    @testset "time_reduce refuses an instantaneous and a static series" begin
        for (time_semantics, when) in
            ((Time.Instantaneous(), Time.SimTime(0.0)), (Time.Static(), nothing))
            values = [reduce_field(R.Intensive(), fill(1.0, RM.NFINE), RM.FINE_SUPPORT;
                                   time = when === nothing ?
                                          Time.TimeSupport(time_semantics) :
                                          Time.TimeSupport(time_semantics, when))]
            s = Time.Forcing([Time.Interval(Time.SimTime(0.0), Time.SimTime(3600.0))],
                             values)
            err = raised(() -> R.time_reduce(s))
            @test err isa Refusal
            @test err.site == "Fields.time_reduce"
            @test err.reason ==
                  R.refusal_sentence(:time_reduce, R.Intensive, typeof(time_semantics))
        end
    end

    @testset "a sentence the table does not declare is refused, not invented" begin
        err = raised(() -> R.refusal_sentence(:coarsen, R.Extensive, Time.IntervalMean))
        @test err isa Refusal
        @test err.site == "Fields.refusal_sentence"
        @test occursin("no entry declares", err.reason)
    end

    @testset "every sentence in the table is distinct and says what to do" begin
        sentences = [entry.sentence for entry in R.REFUSAL_TABLE]
        @test length(unique(sentences)) == length(sentences)
        @test all(s -> length(s) > 20, sentences)
    end
end

@testset "the crossing checks refuse rather than reduce along the wrong axis" begin
    raised(thunk) = try
        thunk()
    catch e
        e
    end

    @testset "a destination that is not coarser is refused" begin
        f = reduce_field(R.Extensive(), fill(1.0, RM.NFINE), RM.FINE_SUPPORT)
        err = raised(() -> R.coarsen(f, RM.FINE_SUPPORT; backend = BACKEND))
        @test err isa Refusal
        @test occursin("not finer", err.reason)
    end

    @testset "a support from another family is refused naming what differs" begin
        other = RM.support(RM.COARSE; radius = 2.0)
        f = reduce_field(R.Extensive(), fill(1.0, RM.NFINE), RM.FINE_SUPPORT)
        err = raised(() -> R.coarsen(f, other; backend = BACKEND))
        @test err isa Refusal
        @test occursin("radius", err.reason)
    end

    @testset "a measure of the wrong extent is refused naming both lengths" begin
        f = reduce_field(R.FluxDensity(), fill(1.0, RM.NFINE), RM.FINE_SUPPORT)
        short = R.Measured{:primal_cell_area}(RM.FINE_AREA[1:end - 1])
        err = raised(() -> R.coarsen(f, RM.COARSE_SUPPORT; measure = short,
                                     backend = BACKEND))
        @test err isa Refusal
    end

    @testset "a measure name outside the closed set is refused" begin
        err = raised(() -> R.Measured{:area}(RM.FINE_AREA))
        @test err isa Refusal
        @test err.site == "Fields.Measured"
        @test occursin("area", err.reason)
    end

    @testset "a field carrying levels is refused, naming the row that carries it" begin
        f = reduce_field(R.Extensive(), ones(RM.NFINE, 3), RM.FINE_SUPPORT)
        err = raised(() -> R.coarsen(f, RM.COARSE_SUPPORT; backend = BACKEND))
        @test err isa Refusal
        @test occursin("fiddlybits-52v.3.12", err.reason)
    end
end

@testset "every operator returns a concrete type" begin
    extensive = reduce_field(R.Extensive(), copy(RM.FINE_AREA), RM.FINE_SUPPORT)
    density = reduce_field(R.FluxDensity(), varying(RM.NFINE), RM.FINE_SUPPORT)
    intensive = reduce_field(R.Intensive(), varying(RM.NFINE), RM.FINE_SUPPORT)
    coarse_density = reduce_field(R.FluxDensity(), varying(RM.NCOARSE), RM.COARSE_SUPPORT)
    coarse_extensive = reduce_field(R.Extensive(), varying(RM.NCOARSE), RM.COARSE_SUPPORT)

    @test @inferred(R.coarsen(extensive, RM.COARSE_SUPPORT; backend = BACKEND)) isa R.Field
    @test @inferred(R.coarsen(density, RM.COARSE_SUPPORT; measure = AREA,
                              backend = BACKEND)) isa R.Field
    @test @inferred(R.coarsen(intensive, RM.COARSE_SUPPORT, R.AreaMean(); measure = AREA,
                              backend = BACKEND)) isa R.Field
    @test @inferred(R.coarsen(intensive, RM.COARSE_SUPPORT, R.ToQuantiles{(0.5,)}();
                              backend = BACKEND)) isa R.Field
    @test @inferred(R.refine(coarse_extensive, RM.FINE_SUPPORT; measure = AREA,
                             backend = BACKEND)) isa R.Field
    @test @inferred(R.refine(coarse_density, RM.FINE_SUPPORT)) isa R.Field
    @test @inferred(R.refusal_sentence(:coarsen, R.Intensive, Time.IntervalMean)) isa String
end
