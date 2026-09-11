using Test
using CUDA
using Fiddlybits: Backends, Events

# on(array, backend) records a move through Events.moved only when the array
# actually changes device: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The device layer". A move is a thing that happened to a field; placing an
# array on the backend it already lives on is not one.

@testset "on records a move only when the device actually changes" begin
    @testset "already on the target backend: nothing recorded, same object returned" begin
        log = Events.Moved[]
        Events.sink!(rec -> push!(log, rec))
        x = [1.0, 2.0, 3.0]
        y = Backends.on(x, Backends.CPU(1))
        @test isempty(log)
        @test y === x
        Events.sink!(Events.noop_sink)
    end

    @testset "positive control: a genuine cross-device move is recorded" begin
        @test CUDA.functional()
        log = Events.Moved[]
        Events.sink!(rec -> push!(log, rec))
        x = [1.0, 2.0, 3.0]
        g = Backends.on(x, Backends.GPU(1))
        @test length(log) == 1
        @test log[1].from == :cpu
        @test log[1].to == :gpu
        @test g isa CuArray
        @test g !== x
        @test Array(g) == x
        Events.sink!(Events.noop_sink)
    end

    @testset "a move back is a second genuine move, also recorded" begin
        @test CUDA.functional()
        log = Events.Moved[]
        Events.sink!(rec -> push!(log, rec))
        x = [1.0, 2.0, 3.0]
        g = Backends.on(x, Backends.GPU(1))
        h = Backends.on(g, Backends.CPU(1))
        @test length(log) == 2
        @test log[2].from == :gpu
        @test log[2].to == :cpu
        @test h == x

        # Already on CPU: no third move.
        Backends.on(h, Backends.CPU(1))
        @test length(log) == 2
    end

    @testset "a fixture sink counts every genuine move" begin
        count = Ref(0)
        Events.sink!(ev -> (count[] += 1; nothing))
        n = 5
        for i in 1:n
            Backends.on([Float64(i)], Backends.GPU(1))
        end
        @test count[] == n
        Events.sink!(Events.noop_sink)
    end

    @testset "positive control: no sink installed counts nothing" begin
        count = Ref(0)
        Events.sink!(ev -> (count[] += 1; nothing))
        Events.sink!(Events.noop_sink)
        Backends.on([1.0], Backends.GPU(1))
        @test count[] == 0
    end
end
