using Test
using CUDA
using Fiddlybits: Backends, Events

# on(array, backend) records every move through Events.moved: docs/plans/
# fiddlybits-52v.7-kernels.md, section "The device layer".

@testset "on records every move through Events.moved" begin
    @testset "CPU to CPU is a recorded no-op move" begin
        log = Events.Moved[]
        Events.sink!(rec -> push!(log, rec))
        x = [1.0, 2.0, 3.0]
        y = Backends.on(x, Backends.CPU(1))
        @test length(log) == 1
        @test log[1].from == :cpu
        @test log[1].to == :cpu
        @test y === x
        Events.sink!(Events.noop_sink)
    end

    @testset "CPU to GPU and back are each recorded" begin
        @test CUDA.functional()
        log = Events.Moved[]
        Events.sink!(rec -> push!(log, rec))
        x = [1.0, 2.0, 3.0]
        g = Backends.on(x, Backends.GPU(1))
        @test length(log) == 1
        @test log[1].from == :cpu
        @test log[1].to == :gpu
        @test g isa CuArray
        @test Array(g) == x

        h = Backends.on(g, Backends.CPU(1))
        @test length(log) == 2
        @test log[2].from == :gpu
        @test log[2].to == :cpu
        @test h == x
        Events.sink!(Events.noop_sink)
    end

    @testset "a fixture sink counts every call" begin
        count = Ref(0)
        Events.sink!(ev -> (count[] += 1; nothing))
        n = 5
        for i in 1:n
            Backends.on([Float64(i)], Backends.CPU(1))
        end
        @test count[] == n
        Events.sink!(Events.noop_sink)
    end

    @testset "positive control: no sink installed counts nothing" begin
        count = Ref(0)
        Events.sink!(ev -> (count[] += 1; nothing))
        Events.sink!(Events.noop_sink)
        Backends.on([1.0], Backends.CPU(1))
        @test count[] == 0
    end
end
