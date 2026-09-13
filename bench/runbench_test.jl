# The positive control for `held_all_shards`: a failed reading of `held` or `total`
# is `-1`, and `-1 == -1` must not read as holding every share. Included rather than
# run through `main`, so no case is measured and no scheduler job is required.
include(joinpath(@__DIR__, "runbench.jl"))

using Test

@testset "held_all_shards" begin
    @test held_all_shards(-1, -1) == false
    @test held_all_shards(1, 4) == false
    @test held_all_shards(4, 4) == true
end
