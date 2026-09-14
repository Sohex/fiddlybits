using Test
using CUDA
using Fiddlybits: Reductions, Backends

# fiddlybits-52v.7.39: a reduction allocates no temporary the size of its
# input. segmented_mean's numerator and area_fraction_above's indicator each
# used to be built as a separate array the size of xs before the reduction
# ran; both are now folded into the same accumulation loop the reduction
# already walks. The rule this row settles for a later reduction: none, not
# "whatever Backends.budget is told about".

const TEMP_N = 8192
const TEMP_NSEG = 128

"A vector of `n` values from a fixed formula, not a random draw, both signs, magnitude under 3."
temp_vector(n::Integer) = Float64[mod(i * 7919 + 13, 251) / 50 - 2.5 for i in 1:n]

"1-based CSR boundaries splitting `n` into `nseg` equal contiguous segments."
temp_starts(n::Integer, nseg::Integer) = collect(1:(n ÷ nseg):(n + 1))

"segmented_mean's own allocation for `xs`, `segmentation` and `weights` on `backend`, measured after a warm-up call."
function segmented_mean_allocation(xs, segmentation, weights, backend)
    Reductions.segmented_mean(Float64, xs, segmentation, weights, backend)
    return @allocated Reductions.segmented_mean(Float64, xs, segmentation, weights, backend)
end

"""
The allocation `segmented_mean`'s numerator took before this row: `xs .*
weights` built as its own array first, then summed by `segmented_sum`.
"""
function materialized_weighted_sum_allocation(xs, segmentation, weights, backend)
    Reductions.segmented_sum(Float64, xs .* weights, segmentation, backend)
    return @allocated Reductions.segmented_sum(Float64, xs .* weights, segmentation, backend)
end

"area_fraction_above's own allocation for `xs`, `areas` and `x` on `backend`, measured after a warm-up call."
function area_fraction_above_allocation(xs, areas, x, backend)
    Reductions.area_fraction_above(xs, areas, x, backend)
    return @allocated Reductions.area_fraction_above(xs, areas, x, backend)
end

"""
The allocation `area_fraction_above`'s weighted sum took before this row:
the indicator built as its own array first, then summed by `pairwise_sum`.
"""
function materialized_indicator_sum_allocation(xs, areas, x, backend)
    above = ifelse.(xs .>= x, areas, zero(eltype(areas)))
    Reductions.pairwise_sum(Float64, above, backend)
    return @allocated begin
        above2 = ifelse.(xs .>= x, areas, zero(eltype(areas)))
        Reductions.pairwise_sum(Float64, above2, backend)
    end
end

@testset "segmented_mean and area_fraction_above allocate no temporary the size of their input" begin
    xs = temp_vector(TEMP_N)
    weights = abs.(xs) .+ 0.1
    areas = abs.(xs) .+ 1.0
    starts = temp_starts(TEMP_N, TEMP_NSEG)
    segmentation = Reductions.Segmentation(xs, starts)
    cpu = Backends.CPU(8)
    input_bytes = TEMP_N * sizeof(Float64)

    @testset "CPU, at TEMP_N=$TEMP_N elements ($input_bytes bytes)" begin
        @testset "segmented_mean allocates below the input's own size" begin
            used = segmented_mean_allocation(xs, segmentation, weights, cpu)
            @test used < input_bytes

            @testset "positive control: materializing the product first reaches the input's size" begin
                before = materialized_weighted_sum_allocation(xs, segmentation, weights, cpu)
                @test before >= input_bytes
            end
        end

        @testset "area_fraction_above allocates below the input's own size" begin
            used = area_fraction_above_allocation(xs, areas, 0.0, cpu)
            @test used < input_bytes

            @testset "positive control: materializing the indicator first reaches the input's size" begin
                before = materialized_indicator_sum_allocation(xs, areas, 0.0, cpu)
                @test before >= input_bytes
            end
        end
    end

    @testset "GPU, at TEMP_N=$TEMP_N elements ($input_bytes bytes)" begin
        @test CUDA.functional()

        gpu = Backends.GPU(8)
        xs_gpu = Backends.on(xs, gpu)
        weights_gpu = Backends.on(weights, gpu)
        areas_gpu = Backends.on(areas, gpu)
        starts_gpu = Backends.on(starts, gpu)
        segmentation_gpu = Reductions.Segmentation(xs_gpu, starts_gpu)

        @testset "segmented_mean allocates no device temporary the size of the input" begin
            Reductions.segmented_mean(Float64, xs_gpu, segmentation_gpu, weights_gpu, gpu)
            used = CUDA.@allocated Reductions.segmented_mean(Float64, xs_gpu, segmentation_gpu, weights_gpu, gpu)
            @test used < input_bytes

            @testset "positive control: a device temporary the size of the input is caught by the bound" begin
                (xs_gpu .* weights_gpu)
                before = CUDA.@allocated (xs_gpu .* weights_gpu)
                @test before >= input_bytes
            end
        end

        @testset "area_fraction_above allocates no device temporary the size of the input" begin
            Reductions.area_fraction_above(xs_gpu, areas_gpu, 0.0, gpu)
            used = CUDA.@allocated Reductions.area_fraction_above(xs_gpu, areas_gpu, 0.0, gpu)
            @test used < input_bytes

            @testset "positive control: a device temporary the size of the input is caught by the bound" begin
                above = ifelse.(xs_gpu .>= 0.0, areas_gpu, zero(eltype(areas_gpu)))
                before = CUDA.@allocated ifelse.(xs_gpu .>= 0.0, areas_gpu, zero(eltype(areas_gpu)))
                @test before >= input_bytes
            end
        end
    end
end

"The allocation `f` makes, measured after a warm-up call."
function column_allocation(f)
    f()
    return @allocated f()
end

"The device allocation `f` makes, measured after a warm-up call."
function column_device_allocation(f)
    f()
    return CUDA.@allocated f()
end

@testset "the column forms of segmented_weighted_sum and segmented_mean allocate no temporary the size of their input" begin
    ncol = 4
    field = reshape(temp_vector(TEMP_N * ncol), TEMP_N, ncol)
    weights = abs.(temp_vector(TEMP_N)) .+ 0.1
    starts = temp_starts(TEMP_N, TEMP_NSEG)
    segmentation = Reductions.Segmentation(field, starts)
    cpu = Backends.CPU(8)
    input_bytes = sizeof(field)

    @testset "CPU, at $TEMP_N cells by $ncol columns ($input_bytes bytes)" begin
        @test column_allocation(() -> Reductions.segmented_weighted_sum(Float64, field, weights, segmentation, cpu)) <
              input_bytes
        @test column_allocation(() -> Reductions.segmented_mean(Float64, field, segmentation, weights, cpu)) < input_bytes

        @testset "positive control: the weights applied to every column first reach the input's size" begin
            @test column_allocation(() -> field .* weights) >= input_bytes
        end
    end

    @testset "GPU, at $TEMP_N cells by $ncol columns ($input_bytes bytes)" begin
        @test CUDA.functional()
        gpu = Backends.GPU(8)
        field_gpu = Backends.on(field, gpu)
        weights_gpu = Backends.on(weights, gpu)
        segmentation_gpu = Reductions.Segmentation(field_gpu, Backends.on(starts, gpu))

        @test column_device_allocation(() -> Reductions.segmented_weighted_sum(Float64, field_gpu, weights_gpu,
                                                                               segmentation_gpu, gpu)) < input_bytes
        @test column_device_allocation(() -> Reductions.segmented_mean(Float64, field_gpu, segmentation_gpu,
                                                                       weights_gpu, gpu)) < input_bytes

        @testset "positive control: the weights applied to every column first reach the input's size" begin
            @test column_device_allocation(() -> field_gpu .* weights_gpu) >= input_bytes
        end
    end
end

@testset "the fused reductions are bitwise unchanged from materializing the temporary first" begin
    xs = temp_vector(TEMP_N)
    weights = abs.(xs) .+ 0.1
    areas = abs.(xs) .+ 1.0
    starts = temp_starts(TEMP_N, TEMP_NSEG)
    segmentation = Reductions.Segmentation(xs, starts)
    cpu = Backends.CPU(8)

    @testset "segmented_weighted_sum equals segmented_sum of the materialized product" begin
        materialized = Reductions.segmented_sum(Float64, xs .* weights, segmentation, cpu)
        fused = Reductions.segmented_weighted_sum(Float64, xs, weights, segmentation, cpu)
        @test fused == materialized

        @testset "block partition invariance carries through the fused form" begin
            fused16 = Reductions.segmented_weighted_sum(Float64, xs, weights, segmentation, Backends.CPU(16))
            @test fused == fused16
        end
    end

    @testset "area_weighted_sum equals pairwise_sum of the materialized indicator" begin
        x = xs[10]
        above = ifelse.(xs .>= x, areas, zero(eltype(areas)))
        materialized = Reductions.pairwise_sum(Float64, above, cpu)
        fused = Reductions.area_weighted_sum(Float64, xs, areas, x, cpu)
        @test fused == materialized

        @testset "block partition invariance carries through the fused form" begin
            fused16 = Reductions.area_weighted_sum(Float64, xs, areas, x, Backends.CPU(16))
            @test fused == fused16
        end
    end

    @testset "GPU: the fused reductions are bitwise unchanged from materializing the temporary first" begin
        @test CUDA.functional()

        gpu = Backends.GPU(8)
        xs_gpu = Backends.on(xs, gpu)
        weights_gpu = Backends.on(weights, gpu)
        areas_gpu = Backends.on(areas, gpu)
        starts_gpu = Backends.on(starts, gpu)
        segmentation_gpu = Reductions.Segmentation(xs_gpu, starts_gpu)

        materialized = Reductions.segmented_sum(Float64, xs_gpu .* weights_gpu, segmentation_gpu, gpu)
        fused = Reductions.segmented_weighted_sum(Float64, xs_gpu, weights_gpu, segmentation_gpu, gpu)
        @test Array(fused) == Array(materialized)

        x = xs[10]
        above = ifelse.(xs_gpu .>= x, areas_gpu, zero(eltype(areas_gpu)))
        materialized_area = Reductions.pairwise_sum(Float64, above, gpu)
        fused_area = Reductions.area_weighted_sum(Float64, xs_gpu, areas_gpu, x, gpu)
        @test fused_area == materialized_area

        @testset "and against the CPU result" begin
            cpu_fused = Reductions.segmented_weighted_sum(Float64, xs, weights, segmentation, cpu)
            @test Array(fused) == cpu_fused

            cpu_fused_area = Reductions.area_weighted_sum(Float64, xs, areas, x, cpu)
            @test fused_area == cpu_fused_area
        end
    end
end
