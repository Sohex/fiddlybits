using Test
using CUDA
using KernelAbstractions: @kernel, @index, @Const
using Fiddlybits: Backends

# Bitwise mode is a backend property (decision 0029): pure Julia arithmetic,
# no fast-math, no implicit fused multiply-add, the same on both backends.
# Decision 0044 fixes which rounding the two backends meet on: every multiply
# that feeds an add is written as an explicit fma, so each backend performs
# one rounding step per term rather than the two the fusion barrier forced.
# The project's own polynomial transcendentals live in transcendentals.jl and
# are covered by test/backends/transcendentals.jl; every other file in the
# module reaches a transcendental through them and never through the platform
# library, which is what the search below asserts.

const BACKENDS_SRC = normpath(joinpath(@__DIR__, "..", "..", "src", "Backends"))
const TRANSCENDENTALS_SRC = joinpath(BACKENDS_SRC, "transcendentals.jl")
const TRANSCENDENTAL_CALL = r"\b(?:sin|cos|sincos|cbrt|exp|log)\b"

"`text` with every `#`-comment blanked, so a match cannot land inside one."
strip_hash_comments(text::AbstractString) =
    join((split(l, '#'; limit = 2)[1] for l in split(text, '\n')), '\n')

"Every `.jl` file under `dir`, recursively."
function jl_files(dir::AbstractString)
    out = String[]
    for (root, _, names) in walkdir(dir), name in names
        endswith(name, ".jl") && push!(out, joinpath(root, name))
    end
    return sort(out)
end

"Every match of `pattern` across the `.jl` files under `dir` other than
`transcendentals.jl`, comments blanked first."
function grep_jl(dir::AbstractString, pattern::Regex)
    found = Tuple{String,Int,String}[]
    for path in jl_files(dir)
        path == TRANSCENDENTALS_SRC && continue
        text = strip_hash_comments(read(path, String))
        for (i, line) in enumerate(split(text, '\n'))
            for m in eachmatch(pattern, line)
                push!(found, (path, i, m.match))
            end
        end
    end
    return found
end

"`fma(a, b, c)` elementwise, on whichever backend the arrays sit on."
@kernel function fma_triple_kernel!(out, @Const(a), @Const(b), @Const(c))
    i = @index(Global)
    out[i] = fma(a[i], b[i], c[i])
end

"`a * b` rounded on its own, then added to `c`, elementwise."
@kernel function barrier_triple_kernel!(out, @Const(a), @Const(b), @Const(c))
    i = @index(Global)
    out[i] = Backends.nofuse_mul(a[i], b[i]) + c[i]
end

"`kernel` applied to `a`, `b` and `c` on `backend`, returned on the host."
function run_triples(kernel, backend, a, b, c)
    out = Backends.on(similar(a), backend)
    Backends.launch!(kernel, backend, length(a), out,
                     Backends.on(a, backend), Backends.on(b, backend), Backends.on(c, backend))
    return Array(out)
end

"The single-rounding value of `a * x + y` elementwise, evaluated at 256 bits."
function axpy_specification(a::T, x::Vector{T}, y::Vector{T}) where {T}
    out = Vector{T}(undef, length(x))
    setprecision(BigFloat, 256) do
        for i in eachindex(x)
            out[i] = T(big(a) * big(x[i]) + big(y[i]))
        end
    end
    return out
end

"The stencil sum with one rounding per term, evaluated at 256 bits."
function stencil_specification(input::Vector{T}, neighbour, weight) where {T}
    nk, n = size(neighbour)
    out = Vector{T}(undef, n)
    setprecision(BigFloat, 256) do
        for i in 1:n
            acc = zero(T)
            for k in 1:nk
                acc = T(big(input[neighbour[k, i]]) * big(weight[k, i]) + big(acc))
            end
            out[i] = acc
        end
    end
    return out
end

@testset "bitwise mode (decision 0029)" begin
    @testset "no transcendental call outside transcendentals.jl" begin
        sites = grep_jl(BACKENDS_SRC, TRANSCENDENTAL_CALL)
        @test isempty(sites)

        @testset "positive control: the search finds a planted call" begin
            mktempdir() do dir
                write(joinpath(dir, "planted.jl"), "f(x) = sin(x)\n")
                @test !isempty(grep_jl(dir, TRANSCENDENTAL_CALL))
            end
        end
    end

    @testset "fma is the single-rounding operation on both backends (decision 0044)" begin
        @test CUDA.functional()
        m = 2000
        a = [1.0 + i / m for i in 1:m]
        b = [1.0 + mod(i * 7, m) / m for i in 1:m]
        c = [-(a[i] * b[i]) for i in 1:m]
        reference = Vector{Float64}(undef, m)
        setprecision(BigFloat, 300) do
            for i in 1:m
                reference[i] = Float64(big(a[i]) * big(b[i]) + big(c[i]))
            end
        end

        for backend in (Backends.CPU(64; bitwise = true), Backends.GPU(64; bitwise = true))
            fused = run_triples(fma_triple_kernel!, backend, a, b, c)
            @test fused == reference
            @testset "positive control: a separately rounded product is not fma" begin
                # On the GPU a plain a*b+c is contracted, so the control has
                # to be the barrier rather than the plain form.
                @test run_triples(barrier_triple_kernel!, backend, a, b, c) != fused
            end
        end
    end

    @testset "the bitwise kernels round once per term (decision 0044)" begin
        @test CUDA.functional()
        n, nk = BackendFixtures.N_CELLS, BackendFixtures.NK

        for FT in (Float64, Float32)
            @testset "$FT" begin
                x = BackendFixtures.seeded_vector(FT, n)
                a = FT(1.3)
                y0 = BackendFixtures.seeded_vector(FT, n) .* FT(2)
                neighbour, weight = BackendFixtures.stencil_tables(FT, n, nk)
                input = BackendFixtures.seeded_vector(FT, n)

                axpy_spec = axpy_specification(a, x, y0)
                stencil_spec = stencil_specification(input, neighbour, weight)

                for backend in (Backends.CPU(4; bitwise = true), Backends.GPU(4; bitwise = true))
                    y = Backends.on(copy(y0), backend)
                    Backends.axpy!(y, a, Backends.on(x, backend), backend)
                    @test Array(y) == axpy_spec

                    out = Backends.on(Vector{FT}(undef, n), backend)
                    Backends.stencil_gather!(out, Backends.on(input, backend),
                                             Backends.on(neighbour, backend),
                                             Backends.on(weight, backend), backend)
                    @test Array(out) == stencil_spec
                end

                # Decision 0027: the naive serial reference performs the same
                # operation in the same order with a plain multiply and a
                # plain add, and the kernel agrees with it to the roundoff
                # bound rather than exactly.
                y_ref = copy(y0)
                Backends.axpy_reference!(y_ref, a, x)
                out_ref = Vector{FT}(undef, n)
                Backends.stencil_gather_reference!(out_ref, input, neighbour, weight)

                axpy_tol = BackendFixtures.fp_tolerance(FT, 2, maximum(abs.(a .* x) .+ abs.(y0)))
                @test maximum(abs.(axpy_spec .- y_ref)) <= axpy_tol
                per_element_sums = [sum(abs.(input[neighbour[:, i]] .* weight[:, i])) for i in 1:n]
                stencil_tol = BackendFixtures.fp_tolerance(FT, nk, maximum(per_element_sums))
                @test maximum(abs.(stencil_spec .- out_ref)) <= stencil_tol

                @testset "positive control: two roundings per term is a different answer" begin
                    @test y_ref != axpy_spec
                    @test out_ref != stencil_spec
                end
            end
        end
    end

    @testset "bitwise is a backend property" begin
        @test Backends.bitwise(Backends.CPU(4)) == false
        @test Backends.bitwise(Backends.CPU(4; bitwise = true)) == true
        @test Backends.bitwise(Backends.GPU(4; bitwise = true)) == true
    end

    @testset "CPU and GPU bitwise backends agree for arithmetic and stencils" begin
        @test CUDA.functional()
        cpu = Backends.CPU(4; bitwise = true)
        gpu = Backends.GPU(4; bitwise = true)

        n, nk = BackendFixtures.N_CELLS, BackendFixtures.NK
        x = BackendFixtures.seeded_vector(Float64, n)
        a = 1.3
        y0 = BackendFixtures.seeded_vector(Float64, n) .* 2.0

        y_cpu = copy(y0)
        Backends.axpy!(y_cpu, a, x, cpu)

        y_gpu = Backends.on(copy(y0), gpu)
        x_gpu = Backends.on(x, gpu)
        Backends.axpy!(y_gpu, a, x_gpu, gpu)
        @test Array(y_gpu) == y_cpu

        neighbour, weight = BackendFixtures.stencil_tables(Float64, n, nk)
        input = BackendFixtures.seeded_vector(Float64, n)
        out_cpu = Vector{Float64}(undef, n)
        Backends.stencil_gather!(out_cpu, input, neighbour, weight, cpu)

        out_gpu = Backends.on(Vector{Float64}(undef, n), gpu)
        input_gpu = Backends.on(input, gpu)
        neighbour_gpu = Backends.on(neighbour, gpu)
        weight_gpu = Backends.on(weight, gpu)
        Backends.stencil_gather!(out_gpu, input_gpu, neighbour_gpu, weight_gpu, gpu)
        @test Array(out_gpu) == out_cpu
    end
end
