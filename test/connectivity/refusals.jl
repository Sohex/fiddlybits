using Test
using Fiddlybits: Connectivity, Dimensions, Verdicts

# The refusals of Connectivity.derive and Connectivity.topology_changes.

isdefined(@__MODULE__, :ConnectivityFixtures) || include(joinpath(@__DIR__, "fixtures.jl"))
using .ConnectivityFixtures
const CR = ConnectivityFixtures

"The `Verdicts.Refusal` `f()` raises, or `nothing`."
function cr_refusal(f)
    try
        f()
    catch err
        err isa Verdicts.Refusal && return err
        rethrow()
    end
    return nothing
end

@testset "Connectivity refusals" begin
    @testset "a field that is not an elevation" begin
        z = CR.field(CR.elevation(); dimension = Dimensions.MASS)
        r = cr_refusal(() -> Connectivity.derive(z; datum = CR.DATUM, ocean_seeds = [CR.OCEAN_SEED],
                                                 water_depth = CR.field(CR.water_depth()),
                                                 terrain = CR.TERRAIN, coarse = CR.COARSE,
                                                 coarse_support = CR.COARSE_SUPPORT))
        @test r !== nothing && r.quantity == "elevation"
    end

    @testset "an ocean seed at or above the datum" begin
        r = cr_refusal(() -> CR.graph(CR.elevation(); seeds = [CR.ISLAND]))
        @test r !== nothing && r.quantity == "ocean seed"
        r = cr_refusal(() -> CR.graph(CR.elevation(); seeds = Int[]))
        @test r !== nothing && r.quantity == "ocean seed"
    end

    @testset "a negative water depth, and a lake on the ocean" begin
        negative = CR.water_depth()
        negative[CR.ISLAND] = -CR.LAKE_DEPTH
        r = cr_refusal(() -> CR.graph(CR.elevation(); depth = negative))
        @test r !== nothing && r.quantity == "water depth"
        on_ocean = CR.water_depth()
        on_ocean[CR.OCEAN_SEED] = CR.LAKE_DEPTH
        r = cr_refusal(() -> CR.graph(CR.elevation(); depth = on_ocean))
        @test r !== nothing && r.quantity == "water depth"
    end

    @testset "a non-finite elevation" begin
        z = CR.elevation()
        z[CR.ISLAND] = NaN
        r = cr_refusal(() -> CR.graph(z))
        @test r !== nothing && r.quantity == "elevation"
    end

    @testset "a mesh that is not its support's, and a coarse level that is not coarser" begin
        r = cr_refusal(() -> CR.graph(CR.elevation(); coarse = CR.TERRAIN))
        @test r !== nothing && r.quantity == "support level"
        r = cr_refusal(() -> CR.graph(CR.elevation(); coarse = CR.TERRAIN,
                                      coarse_support = CR.TERRAIN_SUPPORT))
        @test r !== nothing && r.quantity == "coarse level"
    end

    @testset "graphs on different supports" begin
        other = CR.graph(CR.elevation(); support = CR.support(CR.TERRAIN; radius = 2 * CR.RADIUS),
                         coarse_support = CR.support(CR.COARSE; radius = 2 * CR.RADIUS))
        r = cr_refusal(() -> Connectivity.topology_changes(CR.graph(CR.elevation()), other))
        @test r !== nothing && r.quantity == "support identity"
    end

    @testset "an edit outside the vocabulary" begin
        r = cr_refusal(() -> Connectivity.Edit(:continent_drifted, [1], 1.0))
        @test r !== nothing && r.quantity == "edit"
        @test all(name -> Connectivity.Edit(name, [1], 1.0) isa Connectivity.Edit,
                  Connectivity.edit_names())
    end
end
