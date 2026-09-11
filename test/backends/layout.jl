using Test
using Fiddlybits: Backends

# The (cells, levels) layout convention: docs/plans/fiddlybits-52v.7-kernels.md,
# section "The device layer". `Fields` reads this constant rather than
# restating it.

@testset "LAYOUT is the declared (cells, levels) convention" begin
    @test Backends.LAYOUT == (:cells, :levels)
    @test Backends.LAYOUT isa Tuple{Symbol,Symbol}
end
