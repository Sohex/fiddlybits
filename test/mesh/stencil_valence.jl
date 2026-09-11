using Test
using CUDA
using Fiddlybits: Backends, Mesh, Verdicts

# The stencil acceptance of docs/plans/fiddlybits-52v.2-mesh.md, section
# "Stencils", row 52v.2.4, and the leak check
# docs/imports/kernelabstractions.md names for the grid-or-mesh assumption:
# stencil tables are the only mesh geometry a kernel sees.

include(joinpath(@__DIR__, "..", "lint", "support.jl"))
include(joinpath(@__DIR__, "fixtures", "clean", "leak_kernel.jl"))

const TOP_LEVEL = 4
const HIERARCHY = Mesh.hierarchy(TOP_LEVEL)
const STENCILS = [Mesh.stencils(HIERARCHY.levels[l + 1]) for l in 0:TOP_LEVEL]
const EDGE_LEVELS = 0:TOP_LEVEL
const BASE_VERTEX_COUNT = 12
const BASE_VERTEX_CELLS = 60

# The base icosahedron's own level has no vertex of valence six yet: every
# one of its twelve vertices is a base vertex, so the sixty-cells pattern
# only holds once at least one bisection has run.
const VERTEX_LEVELS = 1:TOP_LEVEL

level_at(l) = HIERARCHY.levels[l + 1]
stencils_at(l) = STENCILS[l + 1]

const BLOCK_OPEN_WORDS = ("function", "if", "for", "while", "let", "try", "do",
                          "struct", "quote", "begin", "macro", "module")
const TOKEN = r"[A-Za-z_][A-Za-z0-9_!]*|\[|\]"

"""
    scan_blocks(line, brackets)

The block openings and closings on `line` that sit outside any square bracket,
and the bracket depth the line leaves behind. An `end` inside a bracket is an
index rather than a block close, and a `for` inside one belongs to a
comprehension, which carries no `end`.
"""
function scan_blocks(line::AbstractString, brackets::Integer)
    opens = 0
    closes = 0
    for m in eachmatch(TOKEN, line)
        token = m.match
        if token == "["
            brackets += 1
        elseif token == "]"
            brackets = max(brackets - 1, 0)
        elseif brackets == 0
            token in BLOCK_OPEN_WORDS && (opens += 1)
            token == "end" && (closes += 1)
        end
    end
    return opens, closes, brackets
end

"""
    kernel_block_range(lines, start)

The line range of the block that opens at or after `lines[start]`, tracked by
counting Julia's block-opening keywords against `end` outside square brackets.
Returns `nothing` if the block never closes within `lines`.
"""
function kernel_block_range(lines::Vector{<:AbstractString}, start::Integer)
    depth = 0
    brackets = 0
    started = false
    for j in start:length(lines)
        opens, closes, brackets = scan_blocks(lines[j], brackets)
        opens > 0 && (started = true)
        depth += opens - closes
        started && depth <= 0 && return start:j
    end
    return nothing
end

"""
    kernel_spans(lines)

The line ranges of every `@kernel` function body in `lines`.
"""
function kernel_spans(lines::Vector{<:AbstractString})
    spans = UnitRange{Int}[]
    i = 1
    n = length(lines)
    while i <= n
        if occursin(r"@kernel\b", lines[i])
            span = kernel_block_range(lines, i)
            span === nothing && break
            push!(spans, span)
            i = last(span) + 1
        else
            i += 1
        end
    end
    return spans
end

# The mesh geometry a kernel may not name directly: the vertex coordinate
# array, the Level and Hierarchy types, and the hierarchy constructor. A
# kernel reaching neighbours through a Stencils field is unaffected.
const MESH_GEOMETRY = r"\b(vertices|Level|Hierarchy)\b|\bhierarchy\s*\("

"""
    lint_mesh_leak(root)

Every site inside a `@kernel` function body under `root` that names mesh
geometry directly rather than through a `Stencils` field.
"""
function lint_mesh_leak(root::AbstractString)
    found = LintSupport.Site[]
    for path in LintSupport.sources(root)
        text = LintSupport.strip_comments_and_strings(read(joinpath(root, path), String))
        lines = String.(split(text, '\n'))
        for span in kernel_spans(lines)
            for i in span
                for m in eachmatch(MESH_GEOMETRY, lines[i])
                    push!(found, LintSupport.Site(path, i, m.match))
                end
            end
        end
    end
    return found
end

@testset "Mesh.stencils" begin
    @testset "every cell has exactly three distinct edge neighbours" begin
        for l in EDGE_LEVELS
            st = stencils_at(l)
            nc = Mesh.ncells(l)
            @test all(1:nc) do i
                row = view(st.edge_neighbour, :, i)
                length(Set(row)) == 3 && !(i in row)
            end
        end
    end

    @testset "the edge-neighbour relation is symmetric" begin
        for l in EDGE_LEVELS
            st = stencils_at(l)
            nc = Mesh.ncells(l)
            @test all(i -> all(j -> i in view(st.edge_neighbour, :, j),
                                view(st.edge_neighbour, :, i)), 1:nc)
        end
    end

    @testset "edge_cell has one column per edge of the closed form" begin
        for l in EDGE_LEVELS
            @test size(stencils_at(l).edge_cell, 2) == Mesh.nedges(l)
        end
    end

    @testset "cell_edge names three distinct edges, each shared by exactly two cells" begin
        for l in EDGE_LEVELS
            st = stencils_at(l)
            nc = Mesh.ncells(l)
            ne = Mesh.nedges(l)
            @test all(i -> length(Set(view(st.cell_edge, :, i))) == 3, 1:nc)

            counts = zeros(Int, ne)
            for e in st.cell_edge
                counts[e] += 1
            end
            @test all(==(2), counts)
        end
    end

    @testset "vertex-neighbour valence is twelve except at sixty base-vertex cells" begin
        for l in VERTEX_LEVELS
            st = stencils_at(l)
            nc = Mesh.ncells(l)
            valence = vec(sum(st.vertex_weight, dims = 1))
            @test all(v -> v == 11 || v == 12, valence)
            @test count(==(11), valence) == BASE_VERTEX_CELLS
            @test count(==(12), valence) == nc - BASE_VERTEX_CELLS
        end
    end

    @testset "the eleven-valence cells are exactly those touching a base vertex" begin
        for l in VERTEX_LEVELS
            level = level_at(l)
            st = stencils_at(l)
            nc = Mesh.ncells(l)
            valence = vec(sum(st.vertex_weight, dims = 1))
            eleven = Set(i for i in 1:nc if valence[i] == 11)
            touches_base = Set(i for i in 1:nc if any(<=(BASE_VERTEX_COUNT), view(level.cells, :, i)))
            @test eleven == touches_base
        end
    end

    @testset "vertex_neighbour is symmetric over nonzero weights, padded with self at zero weight" begin
        for l in VERTEX_LEVELS
            st = stencils_at(l)
            nc = Mesh.ncells(l)
            @test all(1:nc) do i
                all(1:12) do j
                    n = st.vertex_neighbour[j, i]
                    if st.vertex_weight[j, i] == 0
                        n == i
                    else
                        row = findfirst(==(i), view(st.vertex_neighbour, :, n))
                        row !== nothing && st.vertex_weight[row, n] == 1
                    end
                end
            end
        end
    end

    @testset "the base level pads every cell to twelve slots" begin
        st = stencils_at(0)
        nc = Mesh.ncells(0)
        valence = vec(sum(st.vertex_weight, dims = 1))
        # Every vertex of the base icosahedron is a base vertex, so no cell
        # there reaches eleven or twelve and the padding runs deeper.
        @test all(==(9), valence)
        @test all(1:nc) do i
            all(j -> st.vertex_neighbour[j, i] == i, 10:12)
        end
    end

    @testset "the tables are dense Int32 arrays of the documented shape" begin
        for l in EDGE_LEVELS
            st = stencils_at(l)
            nc = Mesh.ncells(l)
            @test eltype(st.cell_edge) === Int32 && size(st.cell_edge) == (3, nc)
            @test eltype(st.edge_cell) === Int32 && size(st.edge_cell, 1) == 2
            @test eltype(st.edge_neighbour) === Int32 && size(st.edge_neighbour) == (3, nc)
            @test eltype(st.vertex_neighbour) === Int32 && size(st.vertex_neighbour) == (12, nc)
            @test eltype(st.vertex_weight) === Int32 && size(st.vertex_weight) == (12, nc)
        end
    end

    @testset "building the tables allocates within a small multiple of them" begin
        level = level_at(TOP_LEVEL)
        nc = Mesh.ncells(TOP_LEVEL)
        ne = Mesh.nedges(TOP_LEVEL)
        tables = ((3 + 3 + 12 + 12) * nc + 2 * ne) * sizeof(Int32)
        Mesh.stencils(level)
        GC.gc()
        used = @allocated Mesh.stencils(level)
        @info "Mesh.stencils allocation" level = TOP_LEVEL tables_bytes = tables allocated_bytes = used
        @test used <= 2 * tables
    end

    @testset "a cells table that is not a closed triangulated surface is refused" begin
        # Two disjoint triangles carry six edges where edge_count admits three.
        disjoint = Int32[1 4; 2 5; 3 6]
        @test_throws Verdicts.Refusal Mesh.build_edges(disjoint)

        # Seven triangles around one vertex exceeds the valence a bisection
        # level produces.
        fan = Matrix{Int32}(undef, 3, 7)
        for i in 1:7
            fan[1, i] = 1
            fan[2, i] = Int32(i + 1)
            fan[3, i] = Int32(i == 7 ? 2 : i + 2)
        end
        @test_throws Verdicts.Refusal Mesh.build_vertex_neighbour(fan, 9)
    end

    @testset "the leak check catches mesh geometry named directly in a kernel" begin
        dirty = joinpath(@__DIR__, "fixtures", "dirty")
        clean = joinpath(@__DIR__, "fixtures", "clean")

        flagged = lint_mesh_leak(dirty)
        passed = lint_mesh_leak(clean)
        @test !isempty(flagged)
        @test any(s -> s.found == "vertices", flagged)
        @test isempty(passed)
        isempty(passed) || @info "lint_mesh_leak flagged its clean fixture" passed

        # An end counted as a block close truncates the span and the rest of
        # the kernel body goes unscanned. The dirty fixture indexes with end
        # ahead of its last line for this assertion to bite.
        text = LintSupport.strip_comments_and_strings(read(joinpath(dirty, "leak_kernel.jl"), String))
        lines = String.(split(text, '\n'))
        spans = kernel_spans(lines)
        @test length(spans) == 1
        @test findfirst(l -> occursin("out[i] = total", l), lines) in only(spans)

        found = lint_mesh_leak(normpath(joinpath(@__DIR__, "..", "..", "src")))
        isempty(found) || @info "lint_mesh_leak on the tree" found
        @test isempty(found)
    end

    @testset "the clean fixture kernel runs and matches the reference path" begin
        level = level_at(TOP_LEVEL)
        st = stencils_at(TOP_LEVEL)
        nc = Mesh.ncells(TOP_LEVEL)
        values = collect(Float64, 1:nc)
        reference = [sum(values[st.edge_neighbour[k, i]] for k in 1:3) for i in 1:nc]

        host = Backends.CPU(64)
        out = similar(values)
        Backends.launch!(neighbour_sum_kernel!, host, nc, out, values, st.edge_neighbour)
        Backends.complete!(host)
        @test out == reference

        if CUDA.functional()
            gpu = Backends.GPU(64)
            d_values = Backends.on(values, gpu)
            d_edge_neighbour = Backends.on(st.edge_neighbour, gpu)
            d_out = similar(d_values)
            Backends.launch!(neighbour_sum_kernel!, gpu, nc, d_out, d_values, d_edge_neighbour)
            @test Backends.on(d_out, host) == reference
        else
            @info "no functional device; the device arm of the kernel launch did not run"
        end
    end
end
