using Test
using CUDA
using Fiddlybits: Backends

# Bitwise mode is a backend property (decision 0029): pure Julia arithmetic,
# no fast-math, no implicit fused multiply-add, the same on both backends.
# The project's own polynomial transcendentals are fiddlybits-52v.7.8's; until
# that row lands this claim covers arithmetic and stencils only, never a
# function that calls sin, cos, sincos, cbrt, exp or log.

const BACKENDS_SRC = normpath(joinpath(@__DIR__, "..", "..", "src", "Backends"))
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

"Every match of `pattern` across the `.jl` files under `dir`, comments blanked first."
function grep_jl(dir::AbstractString, pattern::Regex)
    found = Tuple{String,Int,String}[]
    for path in jl_files(dir)
        text = strip_hash_comments(read(path, String))
        for (i, line) in enumerate(split(text, '\n'))
            for m in eachmatch(pattern, line)
                push!(found, (path, i, m.match))
            end
        end
    end
    return found
end

@testset "bitwise mode (decision 0029)" begin
    @testset "no transcendental is in this module's scope yet" begin
        # The gap this leaves is fiddlybits-52v.7.8's, not claimed here.
        sites = grep_jl(BACKENDS_SRC, TRANSCENDENTAL_CALL)
        @test isempty(sites)

        @testset "positive control: the search finds a planted call" begin
            mktempdir() do dir
                write(joinpath(dir, "planted.jl"), "f(x) = sin(x)\n")
                @test !isempty(grep_jl(dir, TRANSCENDENTAL_CALL))
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
