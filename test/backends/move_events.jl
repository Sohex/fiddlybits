using Test
using CUDA
using Fiddlybits: Backends, Events

# on(array, backend) records a move through Events.moved only when the array
# actually changes device: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The device layer". A move is a thing that happened to a field; placing an
# array on the backend it already lives on is not one.
#
# A move goes to the sink Events.move_sink! installs, which is not the one
# Events.sink! installs for journal events: decision 0046.

@testset "on records a move only when the device actually changes" begin
    @testset "already on the target backend: nothing recorded, same object returned" begin
        log = Events.Moved[]
        Events.move_sink!(rec -> push!(log, rec))
        x = [1.0, 2.0, 3.0]
        y = Backends.on(x, Backends.CPU(1))
        @test isempty(log)
        @test y === x
        Events.move_sink!(Events.noop_sink)
    end

    @testset "positive control: a genuine cross-device move is recorded" begin
        @test CUDA.functional()
        log = Events.Moved[]
        Events.move_sink!(rec -> push!(log, rec))
        x = [1.0, 2.0, 3.0]
        g = Backends.on(x, Backends.GPU(1))
        @test length(log) == 1
        @test log[1].from == :cpu
        @test log[1].to == :gpu
        @test g isa CuArray
        @test g !== x
        @test Array(g) == x
        Events.move_sink!(Events.noop_sink)
    end

    @testset "a move back is a second genuine move, also recorded" begin
        @test CUDA.functional()
        log = Events.Moved[]
        Events.move_sink!(rec -> push!(log, rec))
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
        Events.move_sink!(ev -> (count[] += 1; nothing))
        n = 5
        for i in 1:n
            Backends.on([Float64(i)], Backends.GPU(1))
        end
        @test count[] == n
        Events.move_sink!(Events.noop_sink)
    end

    @testset "positive control: no sink installed counts nothing" begin
        count = Ref(0)
        Events.move_sink!(ev -> (count[] += 1; nothing))
        Events.move_sink!(Events.noop_sink)
        Backends.on([1.0], Backends.GPU(1))
        @test count[] == 0
    end
end

@testset "an array with no elements is placed but not recorded as a move" begin
    @test CUDA.functional()
    gpu = Backends.GPU(1)
    cpu = Backends.CPU(1)

    @testset "host to device: nothing recorded, an empty device array returned" begin
        log = Events.Moved[]
        Events.move_sink!(rec -> push!(log, rec))
        g = Backends.on(Float64[], gpu)
        @test isempty(log)
        @test g isa CuArray
        @test isempty(g)
        Events.move_sink!(Events.noop_sink)
    end

    @testset "device to host: nothing recorded, an empty host array returned" begin
        g = Backends.on(Float64[], gpu)
        log = Events.Moved[]
        Events.move_sink!(rec -> push!(log, rec))
        h = Backends.on(g, cpu)
        @test isempty(log)
        @test h isa Array
        @test isempty(h)
        Events.move_sink!(Events.noop_sink)
    end

    @testset "the tally is unmoved by an empty array in either direction" begin
        before = Events.move_counts()
        g = Backends.on(Float64[], gpu)
        Backends.on(g, cpu)
        @test Events.move_counts() == before
    end

    @testset "positive control: the same array at one element is recorded both ways" begin
        # The check above says nothing unless the same shape at a nonzero
        # length still counts, in both directions and in the tally.
        log = Events.Moved[]
        Events.move_sink!(rec -> push!(log, rec))
        before = Events.move_counts()
        g = Backends.on([1.0], gpu)
        h = Backends.on(g, cpu)
        @test length(log) == 2
        @test log[1].from == :cpu && log[1].to == :gpu
        @test log[2].from == :gpu && log[2].to == :cpu
        @test h == [1.0]
        @test Events.move_counts() != before
        Events.move_sink!(Events.noop_sink)
    end
end
