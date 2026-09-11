using Test
using Fiddlybits: Backends

# Plan review: which backend a component runs on is part of the component
# declaration, which sits above this module; this module defines no
# `device(component)` function and no name `device` at all.

@testset "no name device is defined or exported" begin
    @test !isdefined(Backends, :device)
    @test !in(:device, names(Backends; all = true))

    @testset "positive control: a name this module does define is found" begin
        @test isdefined(Backends, :Backend)
        @test in(:Backend, names(Backends; all = true))
    end
end
