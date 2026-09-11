# build.module_order_acyclic: the include order of the top-level module is a
# topological order of the inter-module reference graph recovered from the source.

module ModuleOrder

"The submodule names the top-level file includes, in include order."
function include_order(toplevel::AbstractString)
    order = Symbol[]
    for line in eachline(toplevel)
        m = match(r"^\s*include\(\"([A-Za-z][A-Za-z0-9_]*)/\1\.jl\"\)", line)
        m === nothing || push!(order, Symbol(m.captures[1]))
    end
    return order
end

"Every `.jl` file under the submodule's directory."
function sources(srcdir::AbstractString, mod::Symbol)
    dir = joinpath(srcdir, String(mod))
    isdir(dir) || return String[]
    files = String[]
    for (root, _, names) in walkdir(dir), name in names
        endswith(name, ".jl") && push!(files, joinpath(root, name))
    end
    return files
end

"""
    references(srcdir, order)

`mod => referenced` for every relative reference `..Name` a submodule makes to
another submodule in `order`.
"""
function references(srcdir::AbstractString, order::Vector{Symbol})
    edges = Pair{Symbol,Symbol}[]
    for mod in order, file in sources(srcdir, mod)
        text = read(file, String)
        for other in order
            other === mod && continue
            occursin(Regex("\\.\\.$(other)\\b"), text) && push!(edges, mod => other)
        end
    end
    return unique(edges)
end

"""
    violations(srcdir, toplevel)

Every reference that points at a module included later than the one making it.
Empty means the include order is a topological order of the graph, which also
means the graph has no cycle.
"""
function violations(srcdir::AbstractString, toplevel::AbstractString)
    order = include_order(toplevel)
    position = Dict(mod => i for (i, mod) in enumerate(order))
    return [e for e in references(srcdir, order) if position[e.second] > position[e.first]]
end

end # module ModuleOrder

using Test

const SRC = joinpath(@__DIR__, "..", "..", "src")
const TOP = joinpath(SRC, "Fiddlybits.jl")
const FIXTURES = joinpath(@__DIR__, "fixtures")

@testset "build.module_order_acyclic" begin
    order = ModuleOrder.include_order(TOP)

    @testset "the tree" begin
        @test !isempty(order)
        @test allunique(order)
        @test all(isdir(joinpath(SRC, String(m))) for m in order)
        @test isempty(ModuleOrder.violations(SRC, TOP))
    end

    @testset "positive control: a back reference is refused" begin
        dir = joinpath(FIXTURES, "backref")
        found = ModuleOrder.violations(dir, joinpath(dir, "Top.jl"))
        @test length(found) == 1
        @test found[1] == (:A => :B)
    end

    @testset "clean fixture: a forward reference passes" begin
        dir = joinpath(FIXTURES, "clean")
        @test isempty(ModuleOrder.violations(dir, joinpath(dir, "Top.jl")))
        @test !isempty(ModuleOrder.references(dir, ModuleOrder.include_order(joinpath(dir, "Top.jl"))))
    end
end
