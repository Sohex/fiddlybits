using Test
using CUDA
using Fiddlybits: Reductions, Backends

# The block-sum kernels on GPU run one workgroup per block over shared memory
# (Reductions.launch_block_sums!). The per-lane kernels are the same accumulation
# reading global memory, and still run on CPU; launched on the card directly they
# are the path the shared-memory kernels replaced there, so every comparison below
# is between the two on the same device, bitwise.

"The block sums `kernel` writes when launched on `backend` one work item per block."
function per_lane_block_sums(kernel, ::Type{A}, backend, n, blocksize, inputs...) where {A}
    partials = similar(first(inputs), A, cld(n, blocksize))
    Backends.launch!(kernel, backend, length(partials), partials, inputs..., blocksize, n)
    return Backends.on(partials, Backends.CPU(1))
end

"The nb-by-2 block sums `kernel` writes when launched on `backend` one work item per block."
function per_lane_area_fraction_block_sums(kernel, backend, n, blocksize, inputs...)
    nb = cld(n, blocksize)
    partials = similar(first(inputs), Float64, nb, 2)
    Backends.launch!(kernel, backend, size(partials, 1), partials, inputs..., blocksize, n)
    return Backends.on(partials, Backends.CPU(1))
end

bits(v::AbstractArray{Float64}) = reinterpret(UInt64, v)
bits(v::AbstractArray{Float32}) = reinterpret(UInt32, v)

@testset "block sums in workgroup shared memory" begin
    @test CUDA.functional()

    gpu = Backends.GPU(8)
    cpu = Backends.CPU(8)
    B = Reductions.BLOCKSIZE
    N = ReductionFixtures.N

    # Every block full, a partial last block, one block shorter than a block, one
    # element, at the declared blocksize and at one that divides none of them.
    shapes = [(n, B) for n in (N, N + 37, B - 3, 1)]
    push!(shapes, (N + 37, 17))

    @testset "pairwise_block_sums: accumulated in $A from $T, n=$n, blocksize=$bs" for
            (A, T) in ((Float64, Float64), (Float64, Float32), (Float32, Float32)),
            (n, bs) in shapes
        xs = ReductionFixtures.seeded_vector(T, n)
        xs_gpu = Backends.on(xs, gpu)

        shared = Backends.on(Reductions.pairwise_block_sums(A, xs_gpu, gpu; blocksize = bs), cpu)
        per_lane = per_lane_block_sums(Reductions.pairwise_block_kernel!, A, gpu, n, bs, xs_gpu)
        on_cpu = Reductions.pairwise_block_sums(A, xs, cpu; blocksize = bs)

        @test length(shared) == cld(n, bs)
        @test bits(shared) == bits(per_lane)
        @test bits(shared) == bits(on_cpu)
    end

    @testset "area_weighted_block_sums: n=$n, blocksize=$bs, threshold=$which" for
            (n, bs) in shapes, which in (:lowest, :middle, :above_all)
        xs = ReductionFixtures.seeded_vector(Float64, n)
        areas = abs.(ReductionFixtures.seeded_vector(Float64, n)) .+ 0.1
        x = which === :lowest ? minimum(xs) : which === :middle ? xs[cld(n, 2)] : maximum(xs) + 1.0
        xs_gpu = Backends.on(xs, gpu)
        areas_gpu = Backends.on(areas, gpu)

        shared = Backends.on(Reductions.area_weighted_block_sums(Float64, xs_gpu, areas_gpu, x, gpu;
                                                                  blocksize = bs), cpu)
        per_lane = per_lane_block_sums(Reductions.area_weighted_block_kernel!, Float64, gpu, n, bs,
                                       xs_gpu, areas_gpu, x)
        on_cpu = Reductions.area_weighted_block_sums(Float64, xs, areas, x, cpu; blocksize = bs)

        @test bits(shared) == bits(per_lane)
        @test bits(shared) == bits(on_cpu)
    end

    @testset "area_fraction_block_sums: n=$n, blocksize=$bs, threshold=$which" for
            (n, bs) in shapes, which in (:lowest, :middle, :above_all)
        xs = ReductionFixtures.seeded_vector(Float64, n)
        areas = abs.(ReductionFixtures.seeded_vector(Float64, n)) .+ 0.1
        x = which === :lowest ? minimum(xs) : which === :middle ? xs[cld(n, 2)] : maximum(xs) + 1.0
        xs_gpu = Backends.on(xs, gpu)
        areas_gpu = Backends.on(areas, gpu)

        shared = Backends.on(Reductions.area_fraction_block_sums(Float64, xs_gpu, areas_gpu, x, gpu;
                                                                  blocksize = bs), cpu)
        per_lane = per_lane_area_fraction_block_sums(Reductions.area_fraction_block_kernel!, gpu, n, bs,
                                                      xs_gpu, areas_gpu, x)
        on_cpu = Reductions.area_fraction_block_sums(Float64, xs, areas, x, cpu; blocksize = bs)

        @test size(shared) == (cld(n, bs), 2)
        @test bits(shared) == bits(per_lane)
        @test bits(shared) == bits(on_cpu)
    end

    @testset "positive control: every lane's element reaches its block's sum" begin
        # A change to the last lane of a full block, and to the last element of a
        # partial last block, each moves exactly that block's sum. Without this the
        # comparisons above would also hold of a kernel that accumulated only lane
        # 1's element, or that stopped the last block short, on both paths alike.
        n = N + 37
        xs = ReductionFixtures.seeded_vector(Float64, n)
        base = Backends.on(Reductions.pairwise_block_sums(Float64, Backends.on(xs, gpu), gpu), cpu)
        nb = length(base)
        for (index, block) in ((B, 1), (n, nb))
            mutated = copy(xs)
            mutated[index] += 1.0
            moved = Backends.on(Reductions.pairwise_block_sums(Float64, Backends.on(mutated, gpu), gpu), cpu)
            @test findall(moved .!= base) == [block]
        end

        areas = abs.(xs) .+ 0.1
        x = minimum(xs)
        abase = Backends.on(Reductions.area_weighted_block_sums(Float64, Backends.on(xs, gpu),
                                                                Backends.on(areas, gpu), x, gpu), cpu)
        mutated = copy(areas)
        mutated[n] += 1.0
        amoved = Backends.on(Reductions.area_weighted_block_sums(Float64, Backends.on(xs, gpu),
                                                                 Backends.on(mutated, gpu), x, gpu), cpu)
        @test findall(amoved .!= abase) == [nb]

        # A threshold with elements on both sides, so the two columns can be
        # told apart: an excluded element's area moves only the total column,
        # an included element's area moves both.
        fx = xs[cld(n, 2)]
        excluded_index = findfirst(v -> v < fx, xs)
        included_index = findfirst(v -> v >= fx, xs)
        excluded_block = cld(excluded_index, B)
        included_block = cld(included_index, B)

        fbase = Backends.on(Reductions.area_fraction_block_sums(Float64, Backends.on(xs, gpu),
                                                                 Backends.on(areas, gpu), fx, gpu), cpu)

        mutated_excluded = copy(areas)
        mutated_excluded[excluded_index] += 1.0
        excluded_moved = Backends.on(Reductions.area_fraction_block_sums(Float64, Backends.on(xs, gpu),
                                                                          Backends.on(mutated_excluded, gpu),
                                                                          fx, gpu), cpu)
        @test findall(excluded_moved[:, 1] .!= fbase[:, 1]) == [excluded_block]
        @test findall(excluded_moved[:, 2] .!= fbase[:, 2]) == []

        mutated_included = copy(areas)
        mutated_included[included_index] += 1.0
        included_moved = Backends.on(Reductions.area_fraction_block_sums(Float64, Backends.on(xs, gpu),
                                                                          Backends.on(mutated_included, gpu),
                                                                          fx, gpu), cpu)
        @test findall(included_moved[:, 1] .!= fbase[:, 1]) == [included_block]
        @test findall(included_moved[:, 2] .!= fbase[:, 2]) == [included_block]
    end
end
