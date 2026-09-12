using Test
using CUDA
using Fiddlybits: Backends

# The certification run on the card: the candidate is the stand-in case's step
# with its gathers launched through Backends.stencil_gather! on the GPU backend
# and its field mixing broadcast on the device arrays, so both the Float32 and
# the Float64 trajectory of the certification are computed on the card.

@testset "certify.correct_fp32_certifies on the GPU backend" begin
    @test CUDA.functional()

    n = CertifyFixtures.N_CELLS
    gpu = Backends.GPU(64)
    host = Backends.CPU(64)
    neighbour = Backends.on(CASE_NB, gpu)
    weight = Dict(Float64 => Backends.on(CASE_W, gpu),
                  Float32 => Backends.on(Float32.(CASE_W), gpu))

    function gpu_step!(state::Vector{Vector{T}}) where {T}
        w = weight[T]
        u = Backends.on(state[1], gpu)
        v = Backends.on(state[2], gpu)
        gu = Backends.on(Vector{T}(undef, n), gpu)
        gv = Backends.on(Vector{T}(undef, n), gpu)
        Backends.stencil_gather!(gu, u, neighbour, w, gpu)
        Backends.stencil_gather!(gv, v, neighbour, w, gpu)
        c = T(CertifyFixtures.COUPLING)
        copyto!(state[1], Backends.on(gu .+ c .* gv, host))
        copyto!(state[2], Backends.on(gv .- c .* gu, host))
        return state
    end

    report = Backends.certification(gpu_step!, CASE, CASE_ENVELOPE; roundoff = CASE_ROUNDOFF)
    @test report.verdict == Backends.PASS()
    @test maximum(report.observed ./ report.admitted) < 1 / 32

    @testset "positive control: a Float32-only defect on the card fails" begin
        function defective!(state::Vector{Vector{T}}) where {T}
            gpu_step!(state)
            T === Float32 && (state[1] .*= T(1 + 1.0e-4))
            return state
        end
        @test Backends.certify(defective!, CASE, CASE_ENVELOPE; roundoff = CASE_ROUNDOFF) ==
              Backends.FAIL()
    end
end
