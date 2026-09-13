using Test
using CUDA
using Fiddlybits: Reductions, Backends, Events, Verdicts

# Segmented quantiles and their exact inverse: docs/plans/fiddlybits-52v.7-
# kernels.md, section "The reductions", decision 0005 (the 4^k segment) and
# decision 0027 (reference path).

"A permutation of `0:n-1` as type `T`, from a fixed formula, not a random
draw: every slice taken from it has no repeated value, so a selected
quantile names an unambiguous element."
function distinct_vector(::Type{T}, n::Integer) where {T}
    keys = [mod(i * 2654435761 + 17, 1_000_000_007) for i in 1:n]
    order = sortperm(keys)
    ranks = similar(order)
    ranks[order] = 1:n
    return T.(ranks .- 1)
end

"1-based CSR boundaries for `nseg` contiguous segments of the fixed length
`seglen`."
uniform_starts(nseg::Integer, seglen::Integer) = collect(1:seglen:(nseg * seglen + 1))

"A positive, non-uniform area per element, from a fixed formula."
area_vector(n::Integer) = Float64[mod(i * 31 + 7, 97) / 20 + 0.5 for i in 1:n]

"The linearly interpolated quantile (a value between two data points
rather than one of them), used only as the positive control below:
`segmented_quantile` never computes this."
function interpolated_quantile(sorted::AbstractVector, q::Real)
    n = length(sorted)
    h = (n - 1) * q + 1
    lo = floor(Int, h)
    hi = ceil(Int, h)
    return sorted[lo] + (h - lo) * (sorted[hi] - sorted[lo])
end

@testset "segmented_quantile and area_fraction_above" begin
    @testset "the declared range of k" begin
        @test Reductions.QUANTILE_K_MIN == 1
        @test Reductions.QUANTILE_K_MAX == 5
    end

    @testset "kernels.segmented_quantile_exact: bitwise against the exactly sorted answer" begin
        for k in Reductions.QUANTILE_K_MIN:Reductions.QUANTILE_K_MAX
            seglen = 4^k
            nseg = 3
            starts = uniform_starts(nseg, seglen)
            for FT in (Float64, Float32)
                xs = distinct_vector(FT, nseg * seglen)
                for q in (0.0, 0.2, 0.5, 0.73, 1.0)
                    kernel = Reductions.segmented_quantile(xs, starts, q)
                    reference = Reductions.segmented_quantile_reference(xs, starts, q)
                    @test kernel == reference
                    rank = Reductions.quantile_rank(seglen, q)
                    for s in 1:nseg
                        slice_sorted = sort(xs[starts[s]:starts[s+1]-1])
                        @test kernel[s] === slice_sorted[rank]
                    end
                end
            end
        end
    end

    @testset "block partition invariance: same segments, different workgroup override" begin
        k = 4
        seglen = 4^k
        nseg = 5
        starts = uniform_starts(nseg, seglen)
        xs = distinct_vector(Float64, nseg * seglen)
        wg4 = Reductions.segmented_quantile(xs, starts, 0.42, Backends.CPU(4))
        wg64 = Reductions.segmented_quantile(xs, starts, 0.42, Backends.CPU(64))
        @test wg4 == wg64
    end

    @testset "refuses q outside [0, 1]" begin
        xs = distinct_vector(Float64, 4)
        starts = uniform_starts(1, 4)
        @test_throws Verdicts.Refusal Reductions.segmented_quantile(xs, starts, -0.1)
        @test_throws Verdicts.Refusal Reductions.segmented_quantile(xs, starts, 1.1)

        @testset "positive control: q inside [0, 1] does not refuse" begin
            @test Reductions.segmented_quantile(xs, starts, 0.5) isa AbstractVector
        end
    end

    @testset "refuses a segment length that is not uniform, not a power of four, or outside the declared k range" begin
        xs4 = distinct_vector(Float64, 4)
        @test_throws Verdicts.Refusal Reductions.segmented_quantile(xs4, [1, 2, 5], 0.5)

        xs12 = distinct_vector(Float64, 12)
        @test_throws Verdicts.Refusal Reductions.segmented_quantile(xs12, [1, 13], 0.5)

        xs1 = distinct_vector(Float64, 1)
        @test_throws Verdicts.Refusal Reductions.segmented_quantile(xs1, [1, 2], 0.5)

        xs_over = distinct_vector(Float64, 4^(Reductions.QUANTILE_K_MAX + 1))
        @test_throws Verdicts.Refusal Reductions.segmented_quantile(
            xs_over, [1, length(xs_over) + 1], 0.5)

        @testset "positive control: 4^QUANTILE_K_MIN and 4^QUANTILE_K_MAX do not refuse" begin
            xs_min = distinct_vector(Float64, 4^Reductions.QUANTILE_K_MIN)
            @test Reductions.segmented_quantile(xs_min, [1, length(xs_min) + 1], 0.5) isa AbstractVector
            xs_max = distinct_vector(Float64, 4^Reductions.QUANTILE_K_MAX)
            @test Reductions.segmented_quantile(xs_max, [1, length(xs_max) + 1], 0.5) isa AbstractVector
        end
    end

    @testset "empty starts yields no segments" begin
        @test isempty(Reductions.segmented_quantile(Float64[], [1], 0.5))
    end

    @testset "kernels.segmented_quantile_exact: the inverse identity, to roundoff" begin
        k = 3
        seglen = 4^k
        nseg = 4
        starts = uniform_starts(nseg, seglen)
        xs = distinct_vector(Float64, nseg * seglen)
        areas = area_vector(nseg * seglen)

        for q in (0.0, 0.1, 0.37, 0.5, 0.84, 1.0)
            quantiles = Reductions.segmented_quantile(xs, starts, q)
            for s in 1:nseg
                lo, hi = starts[s], starts[s+1] - 1
                slice_xs = xs[lo:hi]
                slice_areas = areas[lo:hi]
                v = quantiles[s]

                # The right answer: the area at or above v, computed at
                # 256-bit precision and rounded once, the same pattern
                # ReductionFixtures.exact_sum uses.
                mask = slice_xs .>= v
                exact_weighted = Float64(sum(BigFloat.(slice_areas[mask]; precision = 256)))
                exact_total = Float64(sum(BigFloat.(slice_areas; precision = 256)))
                magnitude = sum(abs, slice_areas)
                e = Reductions.error_bound(Float64, length(slice_areas), magnitude)
                tol = 2 * e / exact_total

                computed = Reductions.area_fraction_above(slice_xs, slice_areas, v)
                @test abs(computed - exact_weighted / exact_total) <= tol

                reference = Reductions.area_fraction_above_reference(slice_xs, slice_areas, v)
                @test abs(computed - reference) <= tol
            end
        end

        @testset "positive control: a quantile interpolated rather than selected breaks the inverse identity" begin
            s = 1
            lo, hi = starts[s], starts[s+1] - 1
            slice_xs = xs[lo:hi]
            slice_areas = areas[lo:hi]
            sorted_xs = sort(slice_xs)
            q = 0.5

            selected = Reductions.segmented_quantile(xs, starts, q)[s]
            interpolated = interpolated_quantile(sorted_xs, q)
            @test interpolated != selected

            selected_fraction = Reductions.area_fraction_above(slice_xs, slice_areas, selected)
            interpolated_fraction = Reductions.area_fraction_above(slice_xs, slice_areas, interpolated)
            @test selected_fraction != interpolated_fraction
        end
    end

    @testset "area_fraction_above refuses a length mismatch or a non-positive total area" begin
        @test_throws Verdicts.Refusal Reductions.area_fraction_above([1.0, 2.0], [1.0], 1.0)
        @test_throws Verdicts.Refusal Reductions.area_fraction_above([1.0, 2.0], [0.0, 0.0], 1.0)

        @testset "positive control: a matched, positive-area call does not refuse" begin
            @test Reductions.area_fraction_above([1.0, 2.0], [1.0, 1.0], 1.0) isa Float64
        end
    end

    @testset "area_weighted_block_sums refuses a length mismatch" begin
        xs = [1.0, 2.0, 3.0]
        areas_short = [1.0, 1.0]
        areas_long = [1.0, 1.0, 1.0, 1.0]
        @test_throws Verdicts.Refusal Reductions.area_weighted_block_sums(Float64, xs, areas_short, 1.5)
        @test_throws Verdicts.Refusal Reductions.area_weighted_block_sums(Float64, xs, areas_long, 1.5)

        @testset "positive control: a matched-length call does not refuse" begin
            @test Reductions.area_weighted_block_sums(Float64, xs, [1.0, 1.0, 1.0], 1.5) isa AbstractVector
        end

        @testset "and on the card" begin
            @test CUDA.functional()
            gpu = Backends.GPU(8)
            xs_gpu = Backends.on(xs, gpu)
            areas_short_gpu = Backends.on(areas_short, gpu)
            areas_long_gpu = Backends.on(areas_long, gpu)
            @test_throws Verdicts.Refusal Reductions.area_weighted_block_sums(Float64, xs_gpu, areas_short_gpu, 1.5, gpu)
            @test_throws Verdicts.Refusal Reductions.area_weighted_block_sums(Float64, xs_gpu, areas_long_gpu, 1.5, gpu)
        end
    end

    @testset "area_fraction_above's one read is bitwise the two reads it replaced" begin
        # The form it replaced: each sum read back to the host on its own.
        # Joining the two block-sum arrays on the device changes where the
        # block sums are read from, not what they are, and combine_tree takes
        # its shape from each half's length alone.
        two_read(vs, as, v, backend) =
            Reductions.area_weighted_sum(Float64, vs, as, v, backend) /
            Reductions.pairwise_sum(Float64, as, backend)

        n = 4^5
        xs = distinct_vector(Float64, n)
        areas = area_vector(n)
        thresholds = (minimum(xs), xs[div(n, 3)], xs[n], maximum(xs) + 1.0)
        cpu = Backends.CPU(8)

        for v in thresholds
            @test reinterpret(UInt64, Reductions.area_fraction_above(xs, areas, v, cpu)) ===
                  reinterpret(UInt64, two_read(xs, areas, v, cpu))
        end

        @testset "and on the card" begin
            @test CUDA.functional()
            gpu = Backends.GPU(8)
            xs_gpu = Backends.on(xs, gpu)
            areas_gpu = Backends.on(areas, gpu)
            for v in thresholds
                @test reinterpret(UInt64,
                                  Reductions.area_fraction_above(xs_gpu, areas_gpu, v, gpu)) ===
                      reinterpret(UInt64, two_read(xs_gpu, areas_gpu, v, gpu))
            end
        end

        @testset "positive control: the comparison separates neighbouring doubles" begin
            # Every equality above is between two computations of the same
            # quantity, so the check says nothing unless the comparison can
            # tell the closest pair of distinct values apart.
            f = Reductions.area_fraction_above(xs, areas, xs[div(n, 3)], cpu)
            @test !(reinterpret(UInt64, f) === reinterpret(UInt64, nextfloat(f)))
        end
    end

    @testset "CPU and GPU agree bitwise for segmented_quantile, and elementwise for area_fraction_above" begin
        @test CUDA.functional()

        k = 4
        seglen = 4^k
        nseg = 3
        starts = uniform_starts(nseg, seglen)
        xs = distinct_vector(Float64, nseg * seglen)
        areas = area_vector(nseg * seglen)

        cpu_result = Reductions.segmented_quantile(xs, starts, 0.42, Backends.CPU(8))

        gpu = Backends.GPU(8)
        xs_gpu = Backends.on(xs, gpu)
        starts_gpu = Backends.on(starts, gpu)
        gpu_result = Reductions.segmented_quantile(xs_gpu, starts_gpu, 0.42, gpu)

        @test Backends.on(gpu_result, Backends.CPU(8)) == cpu_result

        v = xs[div(seglen, 2)]
        areas_gpu = Backends.on(areas, gpu)
        cpu_fraction = Reductions.area_fraction_above(xs, areas, v, Backends.CPU(8))
        gpu_fraction = Reductions.area_fraction_above(xs_gpu, areas_gpu, v, gpu)
        @test gpu_fraction == cpu_fraction

        @testset "positive control: a difference between the two arrays is caught" begin
            # Moves segment 1's own selected element above every other
            # element of its segment, so the rank it was selected at now
            # names a different value.
            segment1 = view(xs, starts[1]:starts[2]-1)
            selected_index = starts[1] - 1 + findfirst(==(cpu_result[1]), segment1)
            mutated = copy(xs)
            mutated[selected_index] = maximum(segment1) + 1.0
            mutated_gpu = Backends.on(mutated, gpu)
            mutated_result = Reductions.segmented_quantile(mutated_gpu, starts_gpu, 0.42, gpu)
            @test Backends.on(mutated_result, Backends.CPU(8))[1] != cpu_result[1]
        end
    end

    @testset "the device bitonic tables are cached per array type and k, not rebuilt" begin
        @test CUDA.functional()

        gpu = Backends.GPU(8)
        k = Reductions.QUANTILE_K_MAX
        partner1, ascending1 = Reductions.device_bitonic_network(gpu, k)
        partner2, ascending2 = Reductions.device_bitonic_network(gpu, k)
        @test partner1 === partner2
        @test ascending1 === ascending2

        @testset "positive control: a different k is a different cache entry" begin
            other_partner, other_ascending = Reductions.device_bitonic_network(gpu, k - 1)
            @test !(other_partner === partner1)
            @test !(other_ascending === ascending1)
        end
    end

    @testset "segmented_quantile reads the boundary array to the host once" begin
        # A move goes to the sink Events.move_sink! installs, not the one
        # Events.sink! installs for journal events: decision 0046.
        @test CUDA.functional()

        k = 4
        seglen = 4^k
        nseg = 3
        starts = uniform_starts(nseg, seglen)
        xs = distinct_vector(Float64, nseg * seglen)

        gpu = Backends.GPU(8)
        xs_gpu = Backends.on(xs, gpu)
        starts_gpu = Backends.on(starts, gpu)

        log = Events.Moved[]
        Events.move_sink!(rec -> push!(log, rec))
        Reductions.segmented_quantile(xs_gpu, starts_gpu, 0.5, gpu)
        Events.move_sink!(Events.noop_sink)

        @test length(log) == 1
        @test log[1].from == :gpu
        @test log[1].to == :cpu

        @testset "positive control: a host-resident boundary array records no move" begin
            log2 = Events.Moved[]
            Events.move_sink!(rec -> push!(log2, rec))
            Reductions.segmented_quantile(xs, starts, 0.5, Backends.CPU(8))
            Events.move_sink!(Events.noop_sink)
            @test isempty(log2)
        end
    end
end
