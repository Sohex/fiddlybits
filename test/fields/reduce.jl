using Test
using Fiddlybits: Fields, Dimensions, Time, Mesh, Backends, Reductions
using Fiddlybits.Verdicts: Refusal
using UUIDs: UUID
import CUDA

# mesh.constant_field_reduction, the operator arm of ledger.closure, and the declared
# refusal and non-conservation tables: docs/oracles/registry.toml and
# docs/plans/fiddlybits-52v.3-fields.md, rows 52v.3.3 and 52v.3.14.
#
# The levels are built here rather than taken from the shared fixture, which holds one
# level; a crossing needs both ends.

const R = Fields
const RD = Dimensions

module ReduceMesh

using Fiddlybits: Mesh

const FINEST = 3
const HIERARCHY = Mesh.hierarchy(FINEST)

level(l) = HIERARCHY.levels[l + 1]
geometry(l) = Mesh.geometry(level(l), Mesh.stencils(level(l)))

support(l; kind = :icosahedral_bisection, radius = 1.0, element_type = :Float64,
           refinement = (), fractions = ()) =
    Mesh.Support(l, level(l), geometry(l); kind = kind, refinement = refinement,
                  radius = radius, element_type = element_type, fractions = fractions)

"The two ends of a crossing from level `fine` to level `coarse`, with their measures."
crossing(fine, coarse) = (fine = fine, coarse = coarse,
                          fine_support = support(fine), coarse_support = support(coarse),
                          fine_area = geometry(fine).cell_area,
                          coarse_area = geometry(coarse).cell_area,
                          nfine = Mesh.ncells(fine), ncoarse = Mesh.ncells(coarse),
                          block = Mesh.ncells(fine) ÷ Mesh.ncells(coarse))

const CROSSINGS = (crossing(2, 0), crossing(3, 2))
const X = crossing(2, 1)
const FINE_SUPPORT = X.fine_support
const COARSE_SUPPORT = X.coarse_support
const FINE_AREA = X.fine_area
const NFINE = X.nfine
const NCOARSE = X.ncoarse
const BLOCK = X.block

end # module ReduceMesh

const RM = ReduceMesh
const RUN = UUID("2f1d4a80-0000-4000-8000-000000000000")
const BACKEND = Backends.CPU(8)
const BACKENDS = (("CPU", Backends.CPU(8)), ("GPU", Backends.GPU(8)))
const AREA = R.Measured{:primal_cell_area}(RM.FINE_AREA)

"`x` on the host, through `Backends.on`."
host(x) = Backends.on(x, Backends.CPU())

"A field at `support` carrying `data`, `semantics` and `dimension`."
reduce_field(semantics, data, support; dimension = RD.MASS,
              time = Time.TimeSupport(Time.IntervalMean(),
                                      Time.Interval(Time.SimTime(0.0),
                                                    Time.SimTime(3600.0)))) =
    R.Field(semantics = semantics, dimension = dimension, data = data,
            support = support, time = time, origin = R.unstamped(:test, RUN))

"A field that varies cell by cell, so an unweighted mean and an area mean differ."
varying(n) = [1.0 + sin(3.0 * i) for i in 1:n]

"Labels that alternate cell by cell between the two classes of `LEGEND`."
alternating(n) = [isodd(i) ? :rock : :ice for i in 1:n]

const LEGEND = (:rock, :ice)

"The `Reductions.error_bound` in `Float64` over `n` terms of total absolute value `M`."
bound(n, M) = Float64(Reductions.error_bound(Float64, n, M))

"The thunk's exception, or its value when it raises none."
raised_by(thunk) = try
    thunk()
catch e
    e
end

@testset "mesh.constant_field_reduction" begin
    @test CUDA.functional()
    for X in RM.CROSSINGS, (bname, backend) in BACKENDS
        dev(x) = Backends.on(x, backend)
        area = R.Measured{:primal_cell_area}(dev(X.fine_area))
        cs = X.coarse_support

        @testset "level $(X.fine) to level $(X.coarse) on $(bname)" begin
            @testset "the mesh's area variation is wide enough to expose a count weighting" begin
                @test maximum(X.fine_area) / minimum(X.fine_area) > 1.2
            end

            @testset "a constant field coarsens to the constant, its integral ledger closed" begin
                for (semantics, rule) in ((R.FluxDensity(), ()), (R.Fraction(), ()),
                                          (R.Intensive(), (R.AreaMean(),)))
                    values = fill(2.5, X.nfine)
                    f = reduce_field(semantics, dev(values), X.fine_support)
                    c, ledger = R.coarsen(f, cs, rule...; measure = area, reservoir = false,
                                          backend = backend)
                    @test length(R.data(c)) == X.ncoarse
                    @test all(≈(2.5), host(R.data(c)))
                    @test R.level(c) == X.coarse
                    @test R.semantics(c) === semantics
                    @test ledger isa R.Ledger{:primal_cell_area_integral}
                    @test abs(R.residual(ledger)) <= R.tolerance(ledger)
                    @test R.closed(ledger)
                    magnitude = sum(abs.(values .* X.fine_area))
                    @test R.tolerance(ledger) ≈ bound(X.nfine, magnitude)
                    @test !isapprox(R.tolerance(ledger), bound(X.ncoarse, magnitude))
                end
            end

            @testset "a constant label coarsens to a whole share, its class ledgers closed" begin
                f = reduce_field(R.CategoricalLabel{:lithology}(), fill(:rock, X.nfine),
                                 X.fine_support; dimension = RD.DIMENSIONLESS)
                c, ledgers = R.coarsen(f, cs; legend = LEGEND, measure = area,
                                       reservoir = false, backend = backend)
                shares = host(R.data(c))
                @test all(≈(1.0), shares[:, 1])
                @test all(==(0.0), shares[:, 2])
                @test ledgers isa R.ClassLedgers{:primal_cell_area}
                @test R.classes(ledgers) == LEGEND
                @test R.closed(ledgers)
                @test R.tolerance(R.ledger_of(ledgers, :rock)) ≈ bound(X.nfine, sum(X.fine_area))
                @test R.residual(R.ledger_of(ledgers, :ice)) == 0.0
            end

            @testset "an extensive integral is preserved, its total ledger closed" begin
                fine = X.fine_area .* varying(X.nfine)
                f = reduce_field(R.Extensive(), dev(fine), X.fine_support)
                c, ledger = R.coarsen(f, cs; reservoir = false, backend = backend)
                @test sum(host(R.data(c))) ≈ sum(fine)
                @test length(R.data(c)) == X.ncoarse
                @test ledger isa R.Ledger{:total}
                @test abs(R.residual(ledger)) <= R.tolerance(ledger)
                @test R.closed(ledger)
                @test R.tolerance(ledger) ≈ bound(X.nfine, sum(abs, fine))
                @test !isapprox(R.tolerance(ledger), bound(X.block, sum(abs, fine)))
            end

            @testset "the children's areas sum to the parent's" begin
                f = reduce_field(R.Extensive(), dev(copy(X.fine_area)), X.fine_support)
                c, ledger = R.coarsen(f, cs; reservoir = false, backend = backend)
                @test host(R.data(c)) ≈ X.coarse_area
                @test R.closed(ledger)
            end

            @testset "positive control: a coarsen that drops one child's contribution returns an open ledger naming the quantity" begin
                fine = X.fine_area .* varying(X.nfine)
                f = reduce_field(R.Extensive(), dev(fine), X.fine_support)
                dropped = copy(fine)
                dropped[2] = 0.0
                broken = Reductions.segmented_sum(Float64, dev(dropped),
                                                  R.child_segmentation(f, cs, backend), backend)
                ledger = R.coarsen_total_ledger(f, broken; reservoir = false,
                                                backend = backend)
                @test !R.closed(ledger)
                @test R.quantity(ledger) === :total
                @test R.residual(ledger) ≈ -fine[2]
            end

            @testset "positive control: a mean that drops one child's contribution returns an open ledger naming the quantity" begin
                values = varying(X.nfine)
                f = reduce_field(R.FluxDensity(), dev(values), X.fine_support)
                weights = copy(X.fine_area)
                weights[2] = 0.0
                broken = Reductions.segmented_mean(Float64, dev(values),
                                                   R.child_segmentation(f, cs, backend),
                                                   dev(weights), backend)
                ledger = R.coarsen_integral_ledger(f, cs, broken, area; reservoir = false,
                                                   backend = backend)
                @test !R.closed(ledger)
                @test R.quantity(ledger) === :primal_cell_area_integral
            end

            @testset "positive control: a count weighting breaks the integral and opens the ledger" begin
                values = varying(X.nfine)
                f = reduce_field(R.FluxDensity(), dev(values), X.fine_support)
                c, ledger = R.coarsen(f, cs; measure = area, reservoir = false,
                                      backend = backend)
                weighted = host(R.data(c))
                counted = [sum(@view values[(k - 1) * X.block + 1:k * X.block]) / X.block
                           for k in 1:X.ncoarse]
                integral = sum(values .* X.fine_area)
                @test R.closed(ledger)
                @test !isapprox(sum(counted .* X.coarse_area), integral)
                @test !isapprox(weighted, counted)
                @test !R.closed(R.coarsen_integral_ledger(f, cs, dev(counted), area;
                                                          reservoir = false,
                                                          backend = backend))
            end

            @testset "a categorical label coarsens to a histogram, never a centre sample" begin
                labels = alternating(X.nfine)
                f = reduce_field(R.CategoricalLabel{:lithology}(), labels, X.fine_support;
                                 dimension = RD.DIMENSIONLESS)
                c, ledgers = R.coarsen(f, cs; legend = LEGEND, measure = area,
                                       reservoir = false, backend = backend)
                shares = host(R.data(c))
                @test R.semantics(c) === R.CategoricalFraction{:lithology}()
                @test size(shares) == (X.ncoarse, length(LEGEND))
                @test all(≈(1.0), sum(shares, dims = 2))
                block(k) = (k - 1) * X.block + 1:k * X.block
                rock_share = [sum(X.fine_area[j] for j in block(k) if labels[j] === :rock) /
                              sum(@view X.fine_area[block(k)]) for k in 1:X.ncoarse]
                @test shares[:, 1] ≈ rock_share
                @test R.closed(ledgers)

                @testset "positive control: a count-weighted histogram opens a class ledger" begin
                    seg = R.child_segmentation(f, cs, backend)
                    fractions = dev(hcat(Float64.(labels .=== :rock), Float64.(labels .=== :ice)))
                    counted = Reductions.segmented_mean(Float64, fractions, seg,
                                                        dev(ones(X.nfine)), backend)
                    broken = R.class_ledgers(fractions, counted, seg, LEGEND, area;
                                             reservoir = false, backend = backend)
                    @test !R.closed(broken)
                    @test !R.closed(R.ledger_of(broken, :rock))
                    @test R.quantity(broken) === :primal_cell_area
                end
            end

            @testset "a class-fraction field coarsens by the area-weighted mean of each class, its class ledgers closed" begin
                rock = [0.5 + 0.4 * sin(3.0 * i) for i in 1:X.nfine]
                fractions = hcat(rock, 1.0 .- rock)
                f = reduce_field(R.CategoricalFraction{:lithology}(), dev(fractions),
                                 X.fine_support; dimension = RD.DIMENSIONLESS)
                seg = R.child_segmentation(f, cs, backend)
                c, ledgers = R.coarsen(f, cs; legend = LEGEND, measure = area,
                                       reservoir = false, backend = backend)
                shares = host(R.data(c))
                block(k) = (k - 1) * X.block + 1:k * X.block
                @test R.semantics(c) === R.CategoricalFraction{:lithology}()
                @test size(shares) == (X.ncoarse, length(LEGEND))
                @test all(≈(1.0), sum(shares, dims = 2))
                @test shares[:, 1] ≈ [sum(X.fine_area[block(k)] .* rock[block(k)]) /
                                      sum(X.fine_area[block(k)]) for k in 1:X.ncoarse]
                @test ledgers isa R.ClassLedgers{:primal_cell_area}
                @test R.classes(ledgers) == LEGEND
                @test R.closed(ledgers)
                @test R.tolerance(R.ledger_of(ledgers, :rock)) ≈
                      bound(X.nfine, sum(rock .* X.fine_area))

                @testset "on fractions histogrammed from labels it is the histogram" begin
                    labels = alternating(X.nfine)
                    lf = reduce_field(R.CategoricalLabel{:lithology}(), labels, X.fine_support;
                                      dimension = RD.DIMENSIONLESS)
                    hist, hist_ledgers = R.coarsen(lf, cs; legend = LEGEND, measure = area,
                                                   reservoir = false, backend = backend)
                    onehot = hcat(Float64.(labels .=== :rock), Float64.(labels .=== :ice))
                    ff = reduce_field(R.CategoricalFraction{:lithology}(), dev(onehot),
                                      X.fine_support; dimension = RD.DIMENSIONLESS)
                    frac, frac_ledgers = R.coarsen(ff, cs; legend = LEGEND, measure = area,
                                                   reservoir = false, backend = backend)
                    @test host(R.data(frac)) == host(R.data(hist))
                    for class in LEGEND
                        @test R.residual(R.ledger_of(frac_ledgers, class)) ==
                              R.residual(R.ledger_of(hist_ledgers, class))
                    end
                end

                @testset "positive control: a mean that drops one child opens a class ledger" begin
                    weights = copy(X.fine_area)
                    weights[2] = 0.0
                    dropped = Reductions.segmented_mean(Float64, dev(fractions), seg,
                                                        dev(weights), backend)
                    broken = R.class_ledgers(dev(fractions), dropped, seg, LEGEND, area;
                                             reservoir = false, backend = backend)
                    @test !R.closed(broken)
                    @test !R.closed(R.ledger_of(broken, :rock))
                    @test R.quantity(broken) === :primal_cell_area
                end

                @testset "positive control: a count weighting opens a class ledger" begin
                    counted = Reductions.segmented_mean(Float64, dev(fractions), seg,
                                                        dev(ones(X.nfine)), backend)
                    broken = R.class_ledgers(dev(fractions), counted, seg, LEGEND, area;
                                             reservoir = false, backend = backend)
                    @test !R.closed(broken)
                    @test !R.closed(R.ledger_of(broken, :rock))
                end

                @testset "with levels, each class holds one ledger per level" begin
                    swapped = fractions[:, [2, 1]]
                    layered = stack((fractions, swapped); dims = 2)
                    g = reduce_field(R.CategoricalFraction{:lithology}(), dev(layered),
                                     X.fine_support; dimension = RD.DIMENSIONLESS)
                    c3, l3 = R.coarsen(g, cs; legend = LEGEND, measure = area,
                                       reservoir = false, backend = backend)
                    @test size(R.data(c3)) == (X.ncoarse, 2, length(LEGEND))
                    @test host(R.data(c3))[:, 1, :] == shares
                    @test R.ledger_of(l3, :rock) isa R.ColumnLedgers{:primal_cell_area}
                    @test R.closed(l3)
                    @test R.residual(R.ledger_of(R.ledger_of(l3, :rock), 1)) ==
                          R.residual(R.ledger_of(ledgers, :rock))

                    @testset "positive control: a count weighting in one level opens that level's ledger alone" begin
                        broken_data = copy(host(R.data(c3)))
                        broken_data[:, 2, :] = host(Reductions.segmented_mean(
                            Float64, dev(swapped), seg, dev(ones(X.nfine)), backend))
                        broken = R.class_ledgers(dev(layered), dev(broken_data), seg, LEGEND,
                                                 area; reservoir = false, backend = backend)
                        rock_levels = R.ledger_of(broken, :rock)
                        @test R.closed(R.ledger_of(rock_levels, 1))
                        @test !R.closed(R.ledger_of(rock_levels, 2))
                        @test !R.closed(broken)
                    end
                end
            end

            @testset "a field of (cells, levels) coarsens column by column, its level axis kept" begin
                block(k) = (k - 1) * X.block + 1:k * X.block
                varied = varying(X.nfine) .* [1.0 -2.0 0.5]

                @testset "a constant field coarsens to the constant in every level, one ledger per level" begin
                    levels = [2.5 4.0 0.5]
                    for (semantics, rule) in ((R.FluxDensity(), ()), (R.Fraction(), ()),
                                              (R.Intensive(), (R.AreaMean(),)))
                        values = repeat(levels, X.nfine)
                        f = reduce_field(semantics, dev(values), X.fine_support)
                        c, ledger = R.coarsen(f, cs, rule...; measure = area,
                                              reservoir = false, backend = backend)
                        coarse = host(R.data(c))
                        @test size(coarse) == (X.ncoarse, 3)
                        @test ledger isa R.ColumnLedgers{:primal_cell_area_integral}
                        @test size(R.ledgers(ledger)) == (3,)
                        @test R.closed(ledger)
                        for k in 1:3
                            @test all(≈(levels[k]), coarse[:, k])
                            @test R.tolerance(R.ledger_of(ledger, k)) ≈
                                  bound(X.nfine, sum(abs.(values[:, k] .* X.fine_area)))
                        end
                    end
                end

                @testset "each level is the single-level coarsening of that level, bit for bit" begin
                    for (semantics, kwargs) in ((R.Extensive(), NamedTuple()),
                                                (R.FluxDensity(), (measure = area,)))
                        f = reduce_field(semantics, dev(varied), X.fine_support)
                        c, ledger = R.coarsen(f, cs; kwargs..., reservoir = false,
                                              backend = backend)
                        for k in 1:3
                            single, single_ledger = R.coarsen(
                                reduce_field(semantics, dev(varied[:, k]), X.fine_support), cs;
                                kwargs..., reservoir = false, backend = backend)
                            @test host(R.data(c))[:, k] == host(R.data(single))
                            @test R.residual(R.ledger_of(ledger, k)) == R.residual(single_ledger)
                            @test R.tolerance(R.ledger_of(ledger, k)) == R.tolerance(single_ledger)
                        end
                    end
                end

                @testset "two trailing axes are kept, one ledger per column" begin
                    fine = stack((varied, 2.0 .* varied); dims = 3)
                    f = reduce_field(R.Extensive(), dev(fine), X.fine_support)
                    c, ledger = R.coarsen(f, cs; reservoir = false, backend = backend)
                    @test size(R.data(c)) == (X.ncoarse, 3, 2)
                    @test size(R.ledgers(ledger)) == (3, 2)
                    @test R.closed(ledger)
                    @test host(R.data(c))[:, 3, 2] ≈
                          [sum(fine[block(k), 3, 2]) for k in 1:X.ncoarse]
                end

                @testset "positive control: a coarsen that drops one child in one level opens that level's ledger alone" begin
                    fine = X.fine_area .* varied
                    f = reduce_field(R.Extensive(), dev(fine), X.fine_support)
                    dropped = copy(fine)
                    dropped[2, 2] = 0.0
                    broken = Reductions.segmented_sum(Float64, dev(dropped),
                                                      R.child_segmentation(f, cs, backend), backend)
                    ledger = R.coarsen_total_ledger(f, broken; reservoir = false,
                                                    backend = backend)
                    @test ledger isa R.ColumnLedgers{:total}
                    @test !R.closed(ledger)
                    @test R.closed(R.ledger_of(ledger, 1))
                    @test !R.closed(R.ledger_of(ledger, 2))
                    @test R.closed(R.ledger_of(ledger, 3))
                    @test R.residual(R.ledger_of(ledger, 2)) ≈ -fine[2, 2]
                end

                @testset "positive control: a count weighting in one level breaks its integral and opens that level's ledger alone" begin
                    values = varying(X.nfine) .* [1.0 2.0 3.0]
                    f = reduce_field(R.FluxDensity(), dev(values), X.fine_support)
                    c, ledger = R.coarsen(f, cs; measure = area, reservoir = false,
                                          backend = backend)
                    counted = copy(host(R.data(c)))
                    counted[:, 2] = [sum(@view values[block(k), 2]) / X.block for k in 1:X.ncoarse]
                    broken = R.coarsen_integral_ledger(f, cs, dev(counted), area;
                                                       reservoir = false, backend = backend)
                    @test R.closed(ledger)
                    @test !R.closed(broken)
                    @test R.closed(R.ledger_of(broken, 1))
                    @test !R.closed(R.ledger_of(broken, 2))
                    @test R.closed(R.ledger_of(broken, 3))
                end

                @testset "a quantile table of a field with levels keeps the level axis" begin
                    values = varying(X.nfine) .* [1.0 -1.0]
                    f = reduce_field(R.Intensive(), dev(values), X.fine_support)
                    c, absent = R.coarsen(f, cs, R.ToQuantiles{(0.0, 1.0)}(); backend = backend)
                    table = host(R.data(c))
                    @test size(table) == (X.ncoarse, 2, 2)
                    for k in 1:2
                        single, _ = R.coarsen(reduce_field(R.Intensive(), dev(values[:, k]),
                                                           X.fine_support),
                                              cs, R.ToQuantiles{(0.0, 1.0)}(); backend = backend)
                        @test table[:, k, :] == host(R.data(single))
                    end
                    @test absent isa R.NotConserved
                end
            end

            @testset "a quantile table is a table, and conserves nothing" begin
                values = varying(X.nfine)
                f = reduce_field(R.Intensive(), dev(values), X.fine_support)
                c, absent = R.coarsen(f, cs, R.ToQuantiles{(0.0, 1.0)}(); backend = backend)
                table = host(R.data(c))
                @test R.semantics(c) === R.Quantiles{(0.0, 1.0)}()
                @test size(table) == (X.ncoarse, 2)
                for k in 1:X.ncoarse
                    block = @view values[(k - 1) * X.block + 1:k * X.block]
                    @test table[k, 1] ≈ minimum(block)
                    @test table[k, 2] ≈ maximum(block)
                end
                @test absent isa R.NotConserved
                @test absent.sentence == R.not_conserved_sentence(
                    :coarsen, R.Intensive, Time.IntervalMean, R.ToQuantiles{(0.0, 1.0)})
            end
        end
    end
end

@testset "the ledger reads the reservoir declaration" begin
    fine = Float32.(RM.FINE_AREA .* varying(RM.NFINE))
    f = reduce_field(R.Extensive(), fine, RM.FINE_SUPPORT)
    err = raised_by(() -> R.coarsen(f, RM.COARSE_SUPPORT; reservoir = true, backend = BACKEND))
    @test err isa Refusal
    @test err.site == "Fields.Ledger"
    @test occursin("total", err.reason)
    @test occursin("reservoir", err.reason)

    @testset "control: the same Float32 coarsening not declared a reservoir closes" begin
        _, ledger = R.coarsen(f, RM.COARSE_SUPPORT; reservoir = false, backend = BACKEND)
        @test R.closed(ledger)
        @test R.tolerance(ledger) ≈
              Float64(Reductions.error_bound(Float32, RM.NFINE, sum(abs, Float64.(fine))))
    end

    @testset "control: a Float64 coarsening declared a reservoir closes" begin
        g = reduce_field(R.Extensive(), Float64.(fine), RM.FINE_SUPPORT)
        _, ledger = R.coarsen(g, RM.COARSE_SUPPORT; reservoir = true, backend = BACKEND)
        @test R.closed(ledger)
    end

    @testset "a coarsening without the declaration does not run" begin
        @test raised_by(() -> R.coarsen(f, RM.COARSE_SUPPORT; backend = BACKEND)) isa
              UndefKeywordError
    end
end

@testset "Fields.refine" begin
    for X in RM.CROSSINGS, (bname, backend) in BACKENDS
        dev(x) = Backends.on(x, backend)
        fine_area = R.Measured{:primal_cell_area}(dev(X.fine_area))
        fs = X.fine_support

        @testset "level $(X.coarse) to level $(X.fine) on $(bname)" begin
            @testset "an extensive total splits by the fine measure and sums back" begin
                coarse = varying(X.ncoarse)
                f = reduce_field(R.Extensive(), dev(coarse), X.coarse_support)
                r, ledger = R.refine(f, fs; measure = fine_area, reservoir = false,
                                     backend = backend)
                split = host(R.data(r))
                @test length(split) == X.nfine
                @test R.level(r) == X.fine
                for k in 1:X.ncoarse
                    @test sum(@view split[(k - 1) * X.block + 1:k * X.block]) ≈ coarse[k]
                end
                @test ledger isa R.Ledger{:total}
                @test R.closed(ledger)
                @test R.tolerance(ledger) ≈ bound(X.nfine, sum(abs, coarse))
                back, back_ledger = R.coarsen(r, X.coarse_support; reservoir = false,
                                              backend = backend)
                @test host(R.data(back)) ≈ coarse
                @test R.closed(back_ledger)

                @testset "positive control: a split that doubles one child opens the ledger" begin
                    doubled = copy(split)
                    doubled[1] *= 2
                    broken = R.total_ledger(Float64, X.nfine, R.data(f), dev(doubled);
                                            reservoir = false, backend = backend)
                    @test !R.closed(broken)
                    @test R.quantity(broken) === :total
                end
            end

            @testset "a density gives each child the parent's value, its integral ledger closed" begin
                coarse = varying(X.ncoarse)
                for semantics in (R.FluxDensity(), R.Fraction())
                    f = reduce_field(semantics, dev(coarse), X.coarse_support)
                    r, ledger = R.refine(f, fs; measure = fine_area, reservoir = false,
                                         backend = backend)
                    @test R.semantics(r) === semantics
                    @test host(R.data(r)) == repeat(coarse, inner = X.block)
                    @test ledger isa R.Ledger{:primal_cell_area_integral}
                    @test R.closed(ledger)
                    spread = repeat(coarse, inner = X.block)
                    @test R.tolerance(ledger) ≈ bound(X.nfine, sum(abs.(spread .* X.fine_area)))
                end
                @test sum(repeat(coarse, inner = X.block) .* X.fine_area) ≈
                      sum(coarse .* X.coarse_area)

                @testset "positive control: children given the wrong parents open the ledger" begin
                    f = reduce_field(R.FluxDensity(), dev(coarse), X.coarse_support)
                    misplaced = dev(repeat(coarse, outer = X.block))
                    broken = R.refine_integral_ledger(f, fs, misplaced, fine_area;
                                                      reservoir = false, backend = backend)
                    @test !R.closed(broken)
                    @test R.quantity(broken) === :primal_cell_area_integral
                end
            end

            @testset "a label gives each child the parent's label, its class ledgers closed" begin
                labels = alternating(X.ncoarse)
                f = reduce_field(R.CategoricalLabel{:lithology}(), labels, X.coarse_support;
                                 dimension = RD.DIMENSIONLESS)
                r, ledgers = R.refine(f, fs; legend = LEGEND, measure = fine_area,
                                      reservoir = false, backend = backend)
                @test R.data(r) == repeat(labels, inner = X.block)
                @test ledgers isa R.ClassLedgers{:primal_cell_area}
                @test R.closed(ledgers)

                @testset "positive control: children given the wrong parents' labels open a class ledger" begin
                    misplaced = repeat(labels, outer = X.block)
                    broken = R.refine_class_ledgers(f, fs, misplaced, LEGEND, fine_area;
                                                    reservoir = false, backend = backend)
                    @test !R.closed(broken)
                end
            end

            @testset "a spread intensive state and a Cartesian component conserve nothing" begin
                coarse = varying(X.ncoarse)
                for semantics in (R.Intensive(), R.VectorComponent{:cartesian}())
                    f = reduce_field(semantics, dev(coarse), X.coarse_support)
                    r, absent = R.refine(f, fs)
                    @test host(R.data(r)) == repeat(coarse, inner = X.block)
                    @test absent isa R.NotConserved
                    @test absent.sentence == R.not_conserved_sentence(
                        :refine, typeof(semantics), Time.IntervalMean, Nothing)
                end
            end

            @testset "a field of (cells, levels) refines column by column, its level axis kept" begin
                coarse = varying(X.ncoarse) .* [1.0 -2.0 0.5]

                @testset "an extensive total splits in every level, one ledger per level" begin
                    f = reduce_field(R.Extensive(), dev(coarse), X.coarse_support)
                    r, ledger = R.refine(f, fs; measure = fine_area, reservoir = false,
                                         backend = backend)
                    split = host(R.data(r))
                    @test size(split) == (X.nfine, 3)
                    @test ledger isa R.ColumnLedgers{:total}
                    @test R.closed(ledger)
                    for k in 1:3
                        single, single_ledger = R.refine(
                            reduce_field(R.Extensive(), dev(coarse[:, k]), X.coarse_support), fs;
                            measure = fine_area, reservoir = false, backend = backend)
                        @test split[:, k] == host(R.data(single))
                        @test R.residual(R.ledger_of(ledger, k)) == R.residual(single_ledger)
                    end
                end

                @testset "a density spreads in every level, one ledger per level" begin
                    f = reduce_field(R.FluxDensity(), dev(coarse), X.coarse_support)
                    r, ledger = R.refine(f, fs; measure = fine_area, reservoir = false,
                                         backend = backend)
                    @test host(R.data(r)) == repeat(coarse, inner = (X.block, 1))
                    @test ledger isa R.ColumnLedgers{:primal_cell_area_integral}
                    @test R.closed(ledger)

                    @testset "positive control: children given the wrong parents in one level open that level's ledger alone" begin
                        misplaced = repeat(coarse, inner = (X.block, 1))
                        misplaced[:, 2] = repeat(coarse[:, 2], outer = X.block)
                        broken = R.refine_integral_ledger(f, fs, dev(misplaced), fine_area;
                                                          reservoir = false, backend = backend)
                        @test R.closed(R.ledger_of(broken, 1))
                        @test !R.closed(R.ledger_of(broken, 2))
                        @test R.closed(R.ledger_of(broken, 3))
                    end
                end

                @testset "an intensive state and a Cartesian component spread in every level" begin
                    for semantics in (R.Intensive(), R.VectorComponent{:cartesian}())
                        f = reduce_field(semantics, dev(coarse), X.coarse_support)
                        r, absent = R.refine(f, fs)
                        @test host(R.data(r)) == repeat(coarse, inner = (X.block, 1))
                        @test absent isa R.NotConserved
                    end
                end

                @testset "labels with levels hold one ledger per level in each class" begin
                    labels = hcat(alternating(X.ncoarse), reverse(alternating(X.ncoarse)))
                    f = reduce_field(R.CategoricalLabel{:lithology}(), labels, X.coarse_support;
                                     dimension = RD.DIMENSIONLESS)
                    r, ledgers = R.refine(f, fs; legend = LEGEND, measure = fine_area,
                                          reservoir = false, backend = backend)
                    @test R.data(r) == repeat(labels, inner = (X.block, 1))
                    @test R.ledger_of(ledgers, :rock) isa R.ColumnLedgers{:primal_cell_area}
                    @test R.closed(ledgers)
                end
            end
        end
    end
end

@testset "Fields.time_reduce" begin
    hours(k) = Time.Interval(Time.SimTime(3600.0 * (k - 1)), Time.SimTime(3600.0 * k))

    series(semantics, time_semantics, datas) = Time.Forcing(
        [hours(k) for k in 1:length(datas)],
        [reduce_field(semantics, datas[k], RM.FINE_SUPPORT;
                      time = Time.TimeSupport(time_semantics, hours(k)))
         for k in 1:length(datas)])

    for (bname, backend) in BACKENDS
        dev(x) = Backends.on(x, backend)

        @testset "on $(bname)" begin
            @testset "an interval mean reduces by a duration-weighted mean, its ledger closed" begin
                datas = [dev(varying(RM.NFINE)), dev(fill(3.0, RM.NFINE))]
                r, ledger = R.time_reduce(series(R.FluxDensity(), Time.IntervalMean(), datas);
                                          reservoir = false, backend = backend)
                @test host(R.data(r)) ≈ (varying(RM.NFINE) .+ 3.0) ./ 2
                @test Time.duration(R.time_support(r)) ≈ 7200.0
                @test R.time_semantics(r) === Time.IntervalMean()
                @test ledger isa R.Ledger{:duration_integral}
                @test R.closed(ledger)
                magnitude = 3600.0 * sum(abs, varying(RM.NFINE)) + 3600.0 * 3.0 * RM.NFINE
                @test R.tolerance(ledger) ≈ bound(2 * RM.NFINE, magnitude)

                @testset "positive control: a mean that drops one interval opens the ledger" begin
                    s = series(R.FluxDensity(), Time.IntervalMean(), datas)
                    broken = R.time_mean_ledger(s, dev(varying(RM.NFINE) ./ 2);
                                                reservoir = false, backend = backend)
                    @test !R.closed(broken)
                    @test R.quantity(broken) === :duration_integral
                end
            end

            @testset "a mean over one interval is the field, and its residual is zero" begin
                values = varying(RM.NFINE)
                r, ledger = R.time_reduce(series(R.FluxDensity(), Time.IntervalMean(),
                                                 [dev(values)]);
                                          reservoir = false, backend = backend)
                @test host(R.data(r)) == values
                @test R.residual(ledger) == 0.0
            end

            @testset "an accumulation reduces by a sum, its ledger closed" begin
                datas = [dev(varying(RM.NFINE)), dev(fill(3.0, RM.NFINE))]
                s = series(R.Extensive(), Time.IntervalAccumulation(), datas)
                r, ledger = R.time_reduce(s; reservoir = false, backend = backend)
                @test host(R.data(r)) ≈ varying(RM.NFINE) .+ 3.0
                @test Time.duration(R.time_support(r)) ≈ 7200.0
                @test ledger isa R.Ledger{:total}
                @test R.closed(ledger)

                @testset "positive control: an accumulation that drops one interval opens the ledger" begin
                    broken = R.accumulation_ledger(s, dev(fill(3.0, RM.NFINE));
                                                   reservoir = false, backend = backend)
                    @test !R.closed(broken)
                    @test R.quantity(broken) === :total
                end
            end

            @testset "an accumulation over one interval is a copy, not the input" begin
                input = dev(varying(RM.NFINE))
                r, ledger = R.time_reduce(series(R.Extensive(), Time.IntervalAccumulation(),
                                                 [input]);
                                          reservoir = false, backend = backend)
                @test R.data(r) !== input
                @test host(R.data(r)) == host(input)
                @test R.residual(ledger) == 0.0
            end

            @testset "an endpoint state reduces to the last one, and conserves nothing" begin
                datas = [dev(fill(1.0, RM.NFINE)), dev(fill(3.0, RM.NFINE))]
                r, absent = R.time_reduce(series(R.Intensive(), Time.EndpointState(), datas))
                @test all(≈(3.0), host(R.data(r)))
                @test absent isa R.NotConserved
                @test absent.sentence == R.not_conserved_sentence(
                    :time_reduce, R.Intensive, Time.EndpointState, Nothing)
            end

            @testset "a series of fields with levels reduces in every level, one ledger per level" begin
                layered = varying(RM.NFINE) .* [1.0 -2.0]
                datas = [dev(layered), dev(fill(3.0, RM.NFINE, 2))]
                s = series(R.FluxDensity(), Time.IntervalMean(), datas)
                r, ledger = R.time_reduce(s; reservoir = false, backend = backend)
                @test size(R.data(r)) == (RM.NFINE, 2)
                @test host(R.data(r)) ≈ (layered .+ 3.0) ./ 2
                @test ledger isa R.ColumnLedgers{:duration_integral}
                @test R.closed(ledger)
                for k in 1:2
                    _, single = R.time_reduce(
                        series(R.FluxDensity(), Time.IntervalMean(),
                               [dev(layered[:, k]), dev(fill(3.0, RM.NFINE))]);
                        reservoir = false, backend = backend)
                    @test R.residual(R.ledger_of(ledger, k)) == R.residual(single)
                    @test R.tolerance(R.ledger_of(ledger, k)) == R.tolerance(single)
                end

                @testset "positive control: a mean that drops one interval in one level opens that level's ledger alone" begin
                    dropped = copy(host(R.data(r)))
                    dropped[:, 2] = layered[:, 2] ./ 2
                    broken = R.time_mean_ledger(s, dev(dropped); reservoir = false,
                                                backend = backend)
                    @test R.closed(R.ledger_of(broken, 1))
                    @test !R.closed(R.ledger_of(broken, 2))
                end

                @testset "an accumulation with levels, one ledger per level" begin
                    acc = series(R.Extensive(), Time.IntervalAccumulation(), datas)
                    ra, la = R.time_reduce(acc; reservoir = false, backend = backend)
                    @test host(R.data(ra)) ≈ layered .+ 3.0
                    @test la isa R.ColumnLedgers{:total}
                    @test R.closed(la)

                    @testset "positive control: an accumulation that drops one interval in one level opens that level's ledger alone" begin
                        dropped = copy(host(R.data(ra)))
                        dropped[:, 1] = fill(3.0, RM.NFINE)
                        broken = R.accumulation_ledger(acc, dev(dropped); reservoir = false,
                                                       backend = backend)
                        @test !R.closed(R.ledger_of(broken, 1))
                        @test R.closed(R.ledger_of(broken, 2))
                    end
                end
            end
        end
    end
end

@testset "the declared refusal table" begin
    fine(semantics; dimension = RD.MASS, data = fill(1.0, RM.NFINE)) =
        reduce_field(semantics, data, RM.FINE_SUPPORT; dimension = dimension)
    coarse(semantics; dimension = RD.MASS, data = fill(1.0, RM.NCOARSE)) =
        reduce_field(semantics, data, RM.COARSE_SUPPORT; dimension = dimension)

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
            err = raised_by(thunk)
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
            err = raised_by(() -> R.time_reduce(s; reservoir = false, backend = BACKEND))
            @test err isa Refusal
            @test err.site == "Fields.time_reduce"
            @test err.reason ==
                  R.refusal_sentence(:time_reduce, R.Intensive, typeof(time_semantics))
        end
    end

    @testset "a sentence the table does not declare is refused, not invented" begin
        err = raised_by(() -> R.refusal_sentence(:coarsen, R.Extensive, Time.IntervalMean))
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

@testset "the declared non-conservation table" begin
    @testset "a combination the table does not declare is refused, not invented" begin
        err = raised_by(() -> R.not_conserved_sentence(:coarsen, R.Extensive,
                                                    Time.IntervalMean, Nothing))
        @test err isa Refusal
        @test err.site == "Fields.not_conserved_sentence"
        @test occursin("no entry declares", err.reason)
        @test R.not_conserved_sentence(:coarsen, R.Intensive, Time.IntervalMean,
                                       R.ToQuantiles{(0.5,)}) isa String
        @test raised_by(() -> R.not_conserved_sentence(:coarsen, R.Intensive, Time.IntervalMean,
                                                    R.AreaMean)) isa Refusal
    end

    @testset "closed refuses a NotConserved with its sentence" begin
        endpoint = Time.TimeSupport(Time.EndpointState(),
                                    Time.Interval(Time.SimTime(0.0), Time.SimTime(3600.0)))
        absent = R.not_conserved(:time_reduce,
                                 reduce_field(R.Intensive(), fill(1.0, RM.NFINE),
                                              RM.FINE_SUPPORT; time = endpoint), Nothing)
        err = raised_by(() -> R.closed(absent))
        @test err isa Refusal
        @test err.site == "Fields.closed"
        @test err.reason == absent.sentence
        @testset "control: closed of a Ledger returns a Bool" begin
            @test R.closed(R.Ledger{:total}(Float64, 3, 1.0, 1.0, 1.0, 0.0;
                                            reservoir = false)) === true
        end
    end

    @testset "every sentence in the table is distinct and says what is not conserved" begin
        sentences = [entry.sentence for entry in R.NOT_CONSERVED_TABLE]
        @test length(unique(sentences)) == length(sentences)
        @test all(s -> length(s) > 20, sentences)
        @test isempty(intersect(sentences, [e.sentence for e in R.REFUSAL_TABLE]))
    end

    @testset "ledger_of refuses a class the ledgers do not hold" begin
        f = reduce_field(R.CategoricalLabel{:lithology}(), alternating(RM.NFINE),
                         RM.FINE_SUPPORT; dimension = RD.DIMENSIONLESS)
        _, ledgers = R.coarsen(f, RM.COARSE_SUPPORT; legend = LEGEND, measure = AREA,
                               reservoir = false, backend = BACKEND)
        err = raised_by(() -> R.ledger_of(ledgers, :sand))
        @test err isa Refusal
        @test occursin("sand", err.reason)
        @test R.ledger_of(ledgers, :ice) isa R.Ledger{:primal_cell_area}
    end
end

@testset "every operator returns (field, ledger) or the declared non-conserving form" begin
    fine(semantics; data = varying(RM.NFINE)) =
        reduce_field(semantics, data, RM.FINE_SUPPORT)
    coarse(semantics; data = varying(RM.NCOARSE)) =
        reduce_field(semantics, data, RM.COARSE_SUPPORT)
    labels(n, support) = reduce_field(R.CategoricalLabel{:lithology}(), alternating(n),
                                      support; dimension = RD.DIMENSIONLESS)
    fractions(n, support) = reduce_field(R.CategoricalFraction{:lithology}(),
                                         hcat(fill(0.25, n), fill(0.75, n)), support;
                                         dimension = RD.DIMENSIONLESS)
    layered(n) = varying(n) .* [1.0 2.0]
    hour = Time.Interval(Time.SimTime(0.0), Time.SimTime(3600.0))
    series(semantics, ts; time = Time.TimeSupport(ts, hour)) =
        Time.Forcing([hour], [reduce_field(semantics, varying(RM.NFINE), RM.FINE_SUPPORT;
                                           time = time)])
    fine_measure = (measure = AREA,)
    coarse_to = RM.COARSE_SUPPORT
    fine_to = RM.FINE_SUPPORT
    conserving = (reservoir = false, backend = BACKEND)

    cases = Dict(
        :coarsen => [
            ((fine(R.Extensive()), coarse_to), conserving),
            ((fine(R.FluxDensity()), coarse_to), (; fine_measure..., conserving...)),
            ((fine(R.Fraction()), coarse_to), (; fine_measure..., conserving...)),
            ((fine(R.Intensive()), coarse_to, R.AreaMean()), (; fine_measure..., conserving...)),
            ((fine(R.Intensive()), coarse_to, R.ToQuantiles{(0.5,)}()), (backend = BACKEND,)),
            ((labels(RM.NFINE, fine_to), coarse_to),
             (; legend = LEGEND, fine_measure..., conserving...)),
            ((fine(R.Intensive()), coarse_to), (backend = BACKEND,)),
            ((fine(R.VectorComponent{:east_north}()), coarse_to), (backend = BACKEND,)),
            ((fine(R.VectorComponent{:east_north}()), coarse_to, R.AreaMean()),
             (backend = BACKEND,)),
            ((fine(R.Quantiles{(0.5,)}()), coarse_to), (backend = BACKEND,)),
            ((fine(R.Quantiles{(0.5,)}()), coarse_to, R.AreaMean()), (backend = BACKEND,)),
            ((fractions(RM.NFINE, fine_to), coarse_to),
             (; legend = LEGEND, fine_measure..., conserving...)),
            ((fine(R.Fraction(); data = layered(RM.NFINE)), coarse_to),
             (; fine_measure..., conserving...)),
            ((fine(R.FluxDensity(); data = layered(RM.NFINE)), coarse_to),
             (; fine_measure..., conserving...)),
            ((fine(R.Intensive(); data = layered(RM.NFINE)), coarse_to, R.ToQuantiles{(0.5,)}()),
             (backend = BACKEND,)),
        ],
        :refine => [
            ((coarse(R.Extensive()), fine_to), (; fine_measure..., conserving...)),
            ((coarse(R.FluxDensity()), fine_to), (; fine_measure..., conserving...)),
            ((coarse(R.Fraction()), fine_to), (; fine_measure..., conserving...)),
            ((coarse(R.Intensive()), fine_to), NamedTuple()),
            ((labels(RM.NCOARSE, coarse_to), fine_to),
             (; legend = LEGEND, fine_measure..., conserving...)),
            ((coarse(R.VectorComponent{:cartesian}()), fine_to), NamedTuple()),
            ((coarse(R.VectorComponent{:east_north}()), fine_to), NamedTuple()),
            ((coarse(R.CategoricalFraction{:lithology}()), fine_to), NamedTuple()),
            ((coarse(R.Quantiles{(0.5,)}()), fine_to), NamedTuple()),
            ((coarse(R.FluxDensity(); data = layered(RM.NCOARSE)), fine_to),
             (; fine_measure..., conserving...)),
            ((coarse(R.Fraction(); data = layered(RM.NCOARSE)), fine_to),
             (; fine_measure..., conserving...)),
        ],
        :time_reduce => [
            ((series(R.FluxDensity(), Time.IntervalMean()),), conserving),
            ((series(R.Extensive(), Time.IntervalAccumulation()),), conserving),
            ((series(R.Intensive(), Time.EndpointState()),), NamedTuple()),
            ((series(R.Intensive(), Time.Instantaneous();
                     time = Time.TimeSupport(Time.Instantaneous(), Time.SimTime(0.0))),),
             conserving),
            ((series(R.Intensive(), Time.Static(); time = Time.TimeSupport(Time.Static())),),
             conserving),
        ],
    )

    operators = (coarsen = R.coarsen, refine = R.refine, time_reduce = R.time_reduce)

    subject(args) = args[1] isa Time.Forcing ? first(args[1].values) : args[1]
    rule_type(args) = length(args) >= 3 ? typeof(args[3]) : Nothing

    for (name, op) in pairs(operators)
        @testset "$(name)" begin
            for (args, kwargs) in cases[name]
                f = subject(args)
                S, T = typeof(R.semantics(f)), typeof(R.time_semantics(f))
                result = raised_by(() -> op(args...; kwargs...))
                if result isa Refusal
                    @test result.reason == R.refusal_sentence(name, S, T)
                else
                    @test result isa Tuple{R.Field,Any}
                    field, ledger = result
                    @test ledger isa
                          Union{R.Ledger,R.ColumnLedgers,R.ClassLedgers,R.NotConserved}
                    if ledger isa R.NotConserved
                        @test ledger.sentence ==
                              R.not_conserved_sentence(name, S, T, rule_type(args))
                    else
                        @test R.closed(ledger)
                    end
                end
            end

            exercised = Set(which(op, Base.typesof(args...)) for (args, _) in cases[name])
            @test exercised == Set(methods(op))

            @testset "positive control: a walk missing one case misses a method" begin
                partial = Set(which(op, Base.typesof(args...))
                              for (args, _) in cases[name][2:end])
                @test partial != Set(methods(op))
            end
        end
    end
end

@testset "the crossing checks refuse rather than reduce along the wrong axis" begin
    @testset "a destination that is not coarser is refused" begin
        f = reduce_field(R.Extensive(), fill(1.0, RM.NFINE), RM.FINE_SUPPORT)
        err = raised_by(() -> R.coarsen(f, RM.FINE_SUPPORT; reservoir = false,
                                     backend = BACKEND))
        @test err isa Refusal
        @test occursin("not finer", err.reason)
    end

    @testset "a support from another family is refused naming what differs" begin
        other = RM.support(RM.X.coarse; radius = 2.0)
        f = reduce_field(R.Extensive(), fill(1.0, RM.NFINE), RM.FINE_SUPPORT)
        err = raised_by(() -> R.coarsen(f, other; reservoir = false, backend = BACKEND))
        @test err isa Refusal
        @test occursin("radius", err.reason)
    end

    @testset "a refinement onto a support from another family is refused naming what differs" begin
        other = RM.support(RM.X.fine; radius = 2.0)
        f = reduce_field(R.FluxDensity(), fill(1.0, RM.NCOARSE), RM.COARSE_SUPPORT)
        err = raised_by(() -> R.refine(f, other; measure = AREA, reservoir = false,
                                    backend = BACKEND))
        @test err isa Refusal
        @test occursin("radius", err.reason)
    end

    @testset "a measure of the wrong extent is refused naming both lengths" begin
        f = reduce_field(R.FluxDensity(), fill(1.0, RM.NFINE), RM.FINE_SUPPORT)
        short = R.Measured{:primal_cell_area}(RM.FINE_AREA[1:end - 1])
        err = raised_by(() -> R.coarsen(f, RM.COARSE_SUPPORT; measure = short,
                                     reservoir = false, backend = BACKEND))
        @test err isa Refusal
        @test occursin("$(RM.NFINE)", err.reason)
    end

    @testset "a measure name outside the closed set is refused" begin
        err = raised_by(() -> R.Measured{:area}(RM.FINE_AREA))
        @test err isa Refusal
        @test err.site == "Fields.Measured"
        @test occursin("area", err.reason)
    end

    @testset "a label the legend does not name is refused, naming the cell" begin
        labels = alternating(RM.NFINE)
        labels[5] = :sand
        f = reduce_field(R.CategoricalLabel{:lithology}(), labels, RM.FINE_SUPPORT;
                         dimension = RD.DIMENSIONLESS)
        err = raised_by(() -> R.coarsen(f, RM.COARSE_SUPPORT; legend = LEGEND, measure = AREA,
                                     reservoir = false, backend = BACKEND))
        @test err isa Refusal
        @test occursin("cell 5", err.reason)
        @test occursin("sand", err.reason)
    end

    @testset "a field whose cells are not on its first axis is refused rather than reduced along another" begin
        f = reduce_field(R.Extensive(), ones(3, RM.NFINE), RM.FINE_SUPPORT)
        err = raised_by(() -> R.coarsen(f, RM.COARSE_SUPPORT; reservoir = false,
                                     backend = BACKEND))
        @test err isa Refusal
        @test occursin("cell axis", err.reason)
        g = reduce_field(R.FluxDensity(), ones(3, RM.NCOARSE), RM.COARSE_SUPPORT)
        err = raised_by(() -> R.refine(g, RM.FINE_SUPPORT; measure = AREA, reservoir = false,
                                    backend = BACKEND))
        @test err isa Refusal
        @test occursin("cell axis", err.reason)

        @testset "control: the same values with cells first coarsen, the trailing axis kept" begin
            h = reduce_field(R.Extensive(), ones(RM.NFINE, 3), RM.FINE_SUPPORT)
            c, ledger = R.coarsen(h, RM.COARSE_SUPPORT; reservoir = false, backend = BACKEND)
            @test size(R.data(c)) == (RM.NCOARSE, 3)
            @test R.closed(ledger)
        end
    end

    @testset "a class-fraction field without one column per class on its last axis is refused" begin
        for data in (fill(0.5, RM.NFINE), fill(0.25, RM.NFINE, 3))
            f = reduce_field(R.CategoricalFraction{:lithology}(), data, RM.FINE_SUPPORT;
                             dimension = RD.DIMENSIONLESS)
            err = raised_by(() -> R.coarsen(f, RM.COARSE_SUPPORT; legend = LEGEND,
                                         measure = AREA, reservoir = false, backend = BACKEND))
            @test err isa Refusal
            @test occursin("last axis", err.reason)
        end
    end

    @testset "a label of a field with levels the legend does not name is refused, naming its cell and column" begin
        labels = hcat(alternating(RM.NFINE), alternating(RM.NFINE))
        labels[5, 2] = :sand
        f = reduce_field(R.CategoricalLabel{:lithology}(), labels, RM.FINE_SUPPORT;
                         dimension = RD.DIMENSIONLESS)
        err = raised_by(() -> R.coarsen(f, RM.COARSE_SUPPORT; legend = LEGEND, measure = AREA,
                                     reservoir = false, backend = BACKEND))
        @test err isa Refusal
        @test occursin("cell 5 of column (2,)", err.reason)
    end

    @testset "ledger_of refuses a column outside the trailing shape" begin
        f = reduce_field(R.Extensive(), ones(RM.NFINE, 3), RM.FINE_SUPPORT)
        _, ledger = R.coarsen(f, RM.COARSE_SUPPORT; reservoir = false, backend = BACKEND)
        err = raised_by(() -> R.ledger_of(ledger, 4))
        @test err isa Refusal
        @test occursin("(3,)", err.reason)
        @test R.ledger_of(ledger, 3) isa R.Ledger{:total}
    end

    @testset "conserved_ledger refuses column totals of different shapes" begin
        err = raised_by(() -> R.conserved_ledger(Val(:total), Float64, 4, [1.0, 1.0],
                                              [1.0, 1.0], [1.0]; reservoir = false))
        @test err isa Refusal
        @test err.site == "Fields.conserved_ledger"
    end
end

@testset "every operator returns a concrete type" begin
    extensive = reduce_field(R.Extensive(), copy(RM.FINE_AREA), RM.FINE_SUPPORT)
    density = reduce_field(R.FluxDensity(), varying(RM.NFINE), RM.FINE_SUPPORT)
    intensive = reduce_field(R.Intensive(), varying(RM.NFINE), RM.FINE_SUPPORT)
    labelled = reduce_field(R.CategoricalLabel{:lithology}(), alternating(RM.NFINE),
                            RM.FINE_SUPPORT; dimension = RD.DIMENSIONLESS)
    coarse_density = reduce_field(R.FluxDensity(), varying(RM.NCOARSE), RM.COARSE_SUPPORT)
    coarse_intensive = reduce_field(R.Intensive(), varying(RM.NCOARSE), RM.COARSE_SUPPORT)
    coarse_extensive = reduce_field(R.Extensive(), varying(RM.NCOARSE), RM.COARSE_SUPPORT)
    coarse_labelled = reduce_field(R.CategoricalLabel{:lithology}(), alternating(RM.NCOARSE),
                                   RM.COARSE_SUPPORT; dimension = RD.DIMENSIONLESS)
    hour(k) = Time.Interval(Time.SimTime(3600.0 * (k - 1)), Time.SimTime(3600.0 * k))
    series(semantics, ts) = Time.Forcing(
        [hour(1), hour(2)],
        [reduce_field(semantics, varying(RM.NFINE), RM.FINE_SUPPORT;
                      time = Time.TimeSupport(ts, hour(k))) for k in 1:2])

    pair(x) = x isa Tuple{R.Field,Any} && isconcretetype(typeof(x))
    @test pair(@inferred(R.coarsen(extensive, RM.COARSE_SUPPORT; reservoir = false,
                                   backend = BACKEND)))
    @test pair(@inferred(R.coarsen(density, RM.COARSE_SUPPORT; measure = AREA,
                                   reservoir = false, backend = BACKEND)))
    @test pair(@inferred(R.coarsen(intensive, RM.COARSE_SUPPORT, R.AreaMean(); measure = AREA,
                                   reservoir = false, backend = BACKEND)))
    @test pair(@inferred(R.coarsen(intensive, RM.COARSE_SUPPORT, R.ToQuantiles{(0.5,)}();
                                   backend = BACKEND)))
    @test pair(@inferred(R.coarsen(labelled, RM.COARSE_SUPPORT; legend = LEGEND,
                                   measure = AREA, reservoir = false, backend = BACKEND)))
    fractions = reduce_field(R.CategoricalFraction{:lithology}(),
                             hcat(fill(0.25, RM.NFINE), fill(0.75, RM.NFINE)), RM.FINE_SUPPORT;
                             dimension = RD.DIMENSIONLESS)
    @test pair(@inferred(R.coarsen(fractions, RM.COARSE_SUPPORT; legend = LEGEND,
                                   measure = AREA, reservoir = false, backend = BACKEND)))
    layered_intensive = reduce_field(R.Intensive(), varying(RM.NFINE) .* [1.0 2.0],
                                     RM.FINE_SUPPORT)
    @test pair(@inferred(R.coarsen(layered_intensive, RM.COARSE_SUPPORT,
                                   R.ToQuantiles{(0.5,)}(); backend = BACKEND)))
    @test pair(@inferred(R.refine(coarse_extensive, RM.FINE_SUPPORT; measure = AREA,
                                  reservoir = false, backend = BACKEND)))
    @test pair(@inferred(R.refine(coarse_density, RM.FINE_SUPPORT; measure = AREA,
                                  reservoir = false, backend = BACKEND)))
    @test pair(@inferred(R.refine(coarse_intensive, RM.FINE_SUPPORT)))
    @test pair(@inferred(R.refine(coarse_labelled, RM.FINE_SUPPORT; legend = LEGEND,
                                  measure = AREA, reservoir = false, backend = BACKEND)))
    @test pair(@inferred(R.time_reduce(series(R.FluxDensity(), Time.IntervalMean());
                                       reservoir = false, backend = BACKEND)))
    @test pair(@inferred(R.time_reduce(series(R.Extensive(), Time.IntervalAccumulation());
                                       reservoir = false, backend = BACKEND)))
    @test pair(@inferred(R.time_reduce(series(R.Intensive(), Time.EndpointState()))))
    @test @inferred(R.refusal_sentence(:coarsen, R.Intensive, Time.IntervalMean)) isa String
end
