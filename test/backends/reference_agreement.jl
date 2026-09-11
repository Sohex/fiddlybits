using Test
using Fiddlybits: Backends

# Decision 0027: every optimised kernel agrees with its own naive serial
# reference to a tolerance derived from floating point.

@testset "reference agreement (decision 0027)" begin
    for FT in (Float64, Float32)
        @testset "axpy! against axpy_reference! ($FT)" begin
            n = BackendFixtures.N_CELLS
            x = BackendFixtures.seeded_vector(FT, n)
            a = FT(1.3)

            y_kernel = BackendFixtures.seeded_vector(FT, n) .* FT(2)
            y_ref = copy(y_kernel)

            Backends.axpy!(y_kernel, a, x, Backends.CPU(16))
            Backends.axpy_reference!(y_ref, a, x)

            tol = BackendFixtures.fp_tolerance(FT, 2, maximum(abs, y_ref))
            @test maximum(abs.(y_kernel .- y_ref)) <= tol
            # The kernel and the reference perform the identical fixed-order
            # operation, so the observed agreement is exact.
            @test y_kernel == y_ref
        end

        @testset "stencil_gather! against stencil_gather_reference! ($FT)" begin
            n, nk = BackendFixtures.N_CELLS, BackendFixtures.NK
            neighbour, weight = BackendFixtures.stencil_tables(FT, n, nk)
            input = BackendFixtures.seeded_vector(FT, n)

            out_kernel = Vector{FT}(undef, n)
            out_ref = Vector{FT}(undef, n)
            Backends.stencil_gather!(out_kernel, input, neighbour, weight, Backends.CPU(16))
            Backends.stencil_gather_reference!(out_ref, input, neighbour, weight)

            tol = BackendFixtures.fp_tolerance(FT, nk, maximum(abs, out_ref))
            @test maximum(abs.(out_kernel .- out_ref)) <= tol
            @test out_kernel == out_ref
        end
    end

    @testset "positive control: a fixed-order sum is order-sensitive" begin
        # Every accumulation here is the same fixed order on the kernel and
        # the reference, so an exact match between them is a real check and
        # not a tautology: reordering the same three terms changes the
        # answer, by construction of double-precision rounding.
        in = [1.0e16, -1.0e16, 1.0]
        forward_neighbour = reshape(Int32[1, 2, 3], 3, 1)
        forward_weight = reshape([1.0, 1.0, 1.0], 3, 1)
        forward = Vector{Float64}(undef, 1)
        Backends.stencil_gather_reference!(forward, in, forward_neighbour, forward_weight)
        @test forward[1] == 1.0

        backward_neighbour = reshape(Int32[3, 2, 1], 3, 1)
        backward_weight = reshape([1.0, 1.0, 1.0], 3, 1)
        backward = Vector{Float64}(undef, 1)
        Backends.stencil_gather_reference!(backward, in, backward_neighbour, backward_weight)
        @test backward[1] == 0.0

        @test forward[1] != backward[1]
    end
end
