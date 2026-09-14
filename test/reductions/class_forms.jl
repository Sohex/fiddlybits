using Test
using CUDA
using Fiddlybits: Reductions, Backends, Verdicts

# fiddlybits-52v.7.60: the class forms of segmented_mean and segmented_weighted_sum over a
# Reductions.ClassIndicator, docs/plans/fiddlybits-52v.7-kernels.md, section "The
# reductions". Each result is compared as raw bytes with the column form run on the one-hot
# the test builds from the same labels, on the same backend, and with the reference path;
# launches are read from Backends.queued_launches.

"The raw bytes of `v`, read to the host through Backends.on."
class_bytes(v::AbstractArray) = collect(reinterpret(UInt8, vec(collect(Backends.on(v, Backends.CPU(1))))))

"The refusal `f` raises, or `nothing` when it returns."
function class_refusal(f)
    try
        f()
    catch e
        e isa Verdicts.Refusal && return e
        rethrow()
    end
    return nothing
end

"The `(kernel, work items)` of each launch `f` queues on `gpu` from this task."
function class_launches(f, gpu)
    Backends.complete!(gpu)
    f()
    launches = [(launch.kernel, launch.n) for launch in Backends.queued_launches(gpu)]
    Backends.complete!(gpu)
    return launches
end

"`n` weights of type `T` of both signs, none zero, one per cell."
class_signed_weights(::Type{T}, n::Integer) where {T} =
    T.([isodd(i) ? 1.0 : -1.0 for i in 1:n] .* (abs.(ReductionFixtures.seeded_vector(Float64, n)) .+ 0.1))

"`n` positive weights of type `T`, one per cell."
class_weights(::Type{T}, n::Integer) where {T} = T.(abs.(ReductionFixtures.seeded_vector(Float64, n)) .+ 0.1)

"A legend of `k` distinct classes."
class_legend(k::Integer) = Tuple(Symbol(:class, i) for i in 1:k)

const CLASS_BACKENDS = (("CPU", Backends.CPU()), ("GPU", Backends.GPU()))
const CLASS_TRAILING = [(), (5,), (3, 4)]
const CLASS_STARTS = [1, 2, 17, 40, 65, 70]
const CLASS_TYPES = [(Float64, Float64), (Float32, Float64), (Float64, Float32), (Float32, Float32)]

@testset "class forms of the segmented reductions (fiddlybits-52v.7.60)" begin
    @test CUDA.functional()

    @testset "a ClassIndicator is the one-hot of its labels" begin
        n = last(CLASS_STARTS) - 1
        for trailing in CLASS_TRAILING, k in (1, 3), T in (Float64, Float32)
            legend = class_legend(k)
            labels = ReductionFixtures.seeded_labels(n, trailing, legend)
            indicator = Reductions.ClassIndicator{T}(labels, legend, Backends.CPU())
            @test size(indicator) == (n, trailing..., k)
            @test eltype(indicator) === T
            @test collect(indicator) == ReductionFixtures.one_hot(T, labels, legend)
        end

        @testset "positive control: the one-hot of labels with one cell changed differs" begin
            legend = class_legend(3)
            labels = ReductionFixtures.seeded_labels(n, (5,), legend)
            indicator = Reductions.ClassIndicator{Float64}(labels, legend, Backends.CPU())
            changed = copy(labels)
            changed[7, 2] = legend[mod1(findfirst(==(labels[7, 2]), legend) + 1, 3)]
            @test collect(indicator) != ReductionFixtures.one_hot(Float64, changed, legend)
        end

        @testset "positions are held in the narrowest unsigned type the legend length needs" begin
            labels = ReductionFixtures.seeded_labels(n, (), class_legend(3))
            @test eltype(Reductions.ClassIndicator{Float64}(labels, class_legend(3), Backends.CPU()).positions) === UInt8
            wide = class_legend(Int(typemax(UInt8)) + 1)
            @test eltype(Reductions.ClassIndicator{Float64}(labels, wide, Backends.CPU()).positions) === UInt16
            @test eltype(Reductions.ClassIndicator{Float64}(labels, class_legend(Int(typemax(UInt8))),
                                                            Backends.CPU()).positions) === UInt8
        end

        @testset "an entry outside the indicator's shape is refused by its bounds check" begin
            legend = class_legend(3)
            indicator = Reductions.ClassIndicator{Float64}(ReductionFixtures.seeded_labels(n, (), legend), legend,
                                                           Backends.CPU())
            @test_throws BoundsError indicator[1, 4]
            @test_throws BoundsError indicator[1, 0]
            @test indicator[1, 3] isa Float64
        end

        @testset "the constructor refuses by name" begin
            legend = class_legend(3)
            labels = ReductionFixtures.seeded_labels(n, (5,), legend)
            empty_legend = class_refusal(() -> Reductions.ClassIndicator{Float64}(labels, (), Backends.CPU()))
            @test empty_legend isa Verdicts.Refusal
            @test occursin("empty", empty_legend.reason)
            repeated = class_refusal(() -> Reductions.ClassIndicator{Float64}(labels, (:class1, :class2, :class1),
                                                                               Backends.CPU()))
            @test repeated isa Verdicts.Refusal
            @test occursin("more than once", repeated.reason)
            stray = copy(labels)
            stray[5, 2] = :sand
            unnamed = class_refusal(() -> Reductions.ClassIndicator{Float64}(stray, legend, Backends.CPU()))
            @test unnamed isa Verdicts.Refusal
            @test unnamed.site == "Reductions.ClassIndicator"
            @test occursin("labels[5, 2]", unnamed.reason)
            @test occursin("sand", unnamed.reason)
            @test class_refusal(() -> Reductions.ClassIndicator{Float64}(labels, legend, Backends.CPU())) === nothing
        end
    end

    @testset "each class form is bitwise the column form on the one-hot" begin
        for (bname, backend) in CLASS_BACKENDS, trailing in CLASS_TRAILING, starts in (CLASS_STARTS, [1, 70])
            @testset "$bname, trailing shape $trailing, $(length(starts) - 1) segment(s)" begin
                n = last(starts) - 1
                starts_b = Backends.on(starts, backend)
                @testset "$TW weights into $A, $k class(es)" for (A, TW) in CLASS_TYPES, k in (1, 3)
                    (k == 3 || trailing == (5,)) || continue
                    legend = class_legend(k)
                    labels = ReductionFixtures.seeded_labels(n, trailing, legend)
                    onehot = ReductionFixtures.one_hot(Float64, labels, legend)
                    positive, signed = class_weights(TW, n), class_signed_weights(TW, n)
                    indicator = Reductions.ClassIndicator{A}(labels, legend, backend)
                    host_indicator = Reductions.ClassIndicator{A}(labels, legend, Backends.CPU())
                    onehot_b = Backends.on(onehot, backend)
                    segmentation = Reductions.Segmentation(indicator, starts_b)
                    onehot_segmentation = Reductions.Segmentation(onehot_b, starts_b)
                    positive_b, signed_b = Backends.on(positive, backend), Backends.on(signed, backend)

                    means = Reductions.segmented_mean(A, indicator, segmentation, positive_b, backend)
                    @test size(means) == (length(starts) - 1, trailing..., k)
                    @test eltype(means) === A
                    @test Backends.backend_of(means) === Backends.backend_of(onehot_b)
                    @test class_bytes(means) ==
                          class_bytes(Reductions.segmented_mean(A, onehot_b, onehot_segmentation, positive_b, backend))
                    @test class_bytes(Reductions.segmented_mean(A, indicator, starts_b, positive_b, backend)) ==
                          class_bytes(means)
                    @test class_bytes(means) ==
                          class_bytes(Reductions.segmented_mean_reference(A, host_indicator, starts, positive))
                    @test class_bytes(means) ==
                          class_bytes(Reductions.segmented_mean_reference(A, onehot, starts, positive))

                    weighted = Reductions.segmented_weighted_sum(A, indicator, signed_b, segmentation, backend)
                    @test size(weighted) == (length(starts) - 1, trailing..., k)
                    @test class_bytes(weighted) ==
                          class_bytes(Reductions.segmented_weighted_sum(A, onehot_b, signed_b, onehot_segmentation,
                                                                        backend))
                    @test class_bytes(weighted) ==
                          class_bytes(Reductions.segmented_weighted_sum_reference(A, host_indicator, signed, starts))

                    absolute = Reductions.segmented_weighted_sum(A, indicator, Reductions.AbsoluteValues(signed_b),
                                                                 segmentation, backend)
                    @test class_bytes(absolute) ==
                          class_bytes(Reductions.segmented_weighted_sum(A, onehot_b, Backends.on(abs.(signed), backend),
                                                                        onehot_segmentation, backend))
                    @test class_bytes(absolute) ==
                          class_bytes(Reductions.segmented_weighted_sum_reference(A, host_indicator,
                                                                                  Reductions.AbsoluteValues(signed),
                                                                                  starts))
                    @test class_bytes(Reductions.segmented_mean(A, indicator, segmentation,
                                                                Reductions.AbsoluteValues(signed_b), backend)) ==
                          class_bytes(Reductions.segmented_mean(A, onehot_b, onehot_segmentation,
                                                                Backends.on(abs.(signed), backend), backend))

                    @testset "positive control: the signed and the absolute weighting differ" begin
                        @test class_bytes(weighted) != class_bytes(absolute)
                    end
                end
            end
        end
    end

    @testset "each class form queues one launch whatever the legend length" begin
        gpu = Backends.GPU()
        starts = CLASS_STARTS
        n, nseg = last(starts) - 1, length(starts) - 1
        weights_b = Backends.on(class_weights(Float64, n), gpu)
        for trailing in ((), (3,)), k in (1, 2, 8, 64)
            ncol = prod(trailing; init = 1)
            legend = class_legend(k)
            indicator = Reductions.ClassIndicator{Float64}(ReductionFixtures.seeded_labels(n, trailing, legend), legend, gpu)
            segmentation = Reductions.Segmentation(indicator, Backends.on(starts, gpu))
            items = nseg * ncol * k
            @testset "trailing shape $trailing, $k class(es), $items work items" begin
                @test class_launches(() -> Reductions.segmented_mean_classes(Float64, indicator, segmentation,
                                                                             weights_b, gpu), gpu) ==
                      [(Reductions.segmented_class_mean_kernel!, items)]
                @test class_launches(() -> Reductions.segmented_weighted_sum(Float64, indicator, weights_b,
                                                                             segmentation, gpu), gpu) ==
                      [(Reductions.segmented_class_weighted_sum_kernel!, items)]
            end
        end

        @testset "positive control: the per-class indicator path fails the one-launch assertion" begin
            legend = class_legend(8)
            labels = ReductionFixtures.seeded_labels(n, (3,), legend)
            segmentation = Reductions.Segmentation(labels, Backends.on(starts, gpu))
            per_class() = [Reductions.segmented_mean_columns(Float64, Backends.on(Float64.(labels .== class), gpu),
                                                             segmentation, weights_b, gpu)
                           for class in legend]
            launches = class_launches(per_class, gpu)
            @test length(launches) == length(legend)
            @test launches != [(Reductions.segmented_class_mean_kernel!, nseg * 3 * length(legend))]
        end
    end

    @testset "the class forms refuse by name" begin
        starts = CLASS_STARTS
        n, nseg = last(starts) - 1, length(starts) - 1
        legend = class_legend(3)
        labels = ReductionFixtures.seeded_labels(n, (3,), legend)
        indicator = Reductions.ClassIndicator{Float64}(labels, legend, Backends.CPU())
        segmentation = Reductions.Segmentation(indicator, starts)
        weights = class_weights(Float64, n)

        @testset "weights one short of the cells" begin
            for call in (() -> Reductions.segmented_weighted_sum(Float64, indicator, weights[1:n-1], segmentation),
                         () -> Reductions.segmented_mean(Float64, indicator, segmentation, weights[1:n-1]),
                         () -> Reductions.segmented_mean(Float64, indicator, segmentation,
                                                         Reductions.AbsoluteValues(weights[1:n-1])))
                caught = class_refusal(call)
                @test caught isa Verdicts.Refusal
                @test occursin("xs has $n cells along its first axis", caught.reason)
                @test occursin("weights has length $(n - 1)", caught.reason)
            end
        end

        @testset "an indicator one cell short of the segmentation" begin
            short = Reductions.ClassIndicator{Float64}(labels[1:n-1, :], legend, Backends.CPU())
            for call in (() -> Reductions.segmented_weighted_sum(Float64, short, weights[1:n-1], segmentation),
                         () -> Reductions.segmented_mean(Float64, short, segmentation, weights[1:n-1]))
                caught = class_refusal(call)
                @test caught isa Verdicts.Refusal
                @test occursin("checked against $n elements", caught.reason)
                @test occursin("xs has $(n - 1) cells", caught.reason)
            end
        end

        @testset "a zero total weight, naming how many segment columns of the one-hot" begin
            caught = class_refusal(() -> Reductions.segmented_mean(Float64, indicator, segmentation, zeros(n)))
            @test caught isa Verdicts.Refusal
            @test occursin("$(nseg * 3 * 3) of $(nseg * 3 * 3) segment columns", caught.reason)
        end

        @testset "positive control: matched arguments do not refuse" begin
            @test class_refusal(() -> Reductions.segmented_weighted_sum(Float64, indicator, weights, segmentation)) === nothing
            @test class_refusal(() -> Reductions.segmented_mean(Float64, indicator, segmentation, weights)) === nothing
        end
    end
end
