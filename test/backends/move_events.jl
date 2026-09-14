using Test
using CUDA
using Fiddlybits: Backends, Events, Verdicts

# on(array, backend) records a move through Events.moved only when the array
# actually changes device: docs/plans/fiddlybits-52v.7-kernels.md, section
# "The device layer". A move is a thing that happened to a field; placing an
# array on the backend it already lives on is not one.
#
# A move goes to the sink Events.move_sink! installs, which is not the one
# Events.sink! installs for journal events: decision 0046.

@testset "on records a move only when the device actually changes" begin
    @testset "already on the target backend: nothing recorded, same object returned" begin
        sink = Events.Collector{Events.Moved}()
        Events.move_sink!(sink)
        x = [1.0, 2.0, 3.0]
        y = Backends.on(x, Backends.CPU(1))
        @test isempty(Events.collected(sink))
        @test y === x
        Events.move_sink!(Events.noop_sink)
    end

    @testset "positive control: a genuine cross-device move is recorded" begin
        @test CUDA.functional()
        sink = Events.Collector{Events.Moved}()
        Events.move_sink!(sink)
        x = [1.0, 2.0, 3.0]
        g = Backends.on(x, Backends.GPU(1))
        log = Events.collected(sink)
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
        sink = Events.Collector{Events.Moved}()
        Events.move_sink!(sink)
        x = [1.0, 2.0, 3.0]
        g = Backends.on(x, Backends.GPU(1))
        h = Backends.on(g, Backends.CPU(1))
        log = Events.collected(sink)
        @test length(log) == 2
        @test log[2].from == :gpu
        @test log[2].to == :cpu
        @test h == x

        # Already on CPU: no third move.
        Backends.on(h, Backends.CPU(1))
        @test length(Events.collected(sink)) == 2
        Events.move_sink!(Events.noop_sink)
    end

    @testset "a fixture sink counts every genuine move" begin
        tally = Events.MoveTally()
        Events.move_sink!(tally)
        n = 5
        for i in 1:n
            Backends.on([Float64(i)], Backends.GPU(1))
        end
        @test Events.move_counts(tally) == Dict((:cpu, :gpu) => n)
        Events.move_sink!(Events.noop_sink)
    end

    @testset "positive control: no sink installed counts nothing" begin
        tally = Events.MoveTally()
        Events.move_sink!(tally)
        Events.move_sink!(Events.noop_sink)
        Backends.on([1.0], Backends.GPU(1))
        @test Events.move_total(tally) == 0
    end
end

@testset "an array with no elements is placed but not recorded as a move" begin
    @test CUDA.functional()
    gpu = Backends.GPU(1)
    cpu = Backends.CPU(1)

    @testset "host to device: nothing recorded, an empty device array returned" begin
        sink = Events.Collector{Events.Moved}()
        Events.move_sink!(sink)
        g = Backends.on(Float64[], gpu)
        @test isempty(Events.collected(sink))
        @test g isa CuArray
        @test isempty(g)
        Events.move_sink!(Events.noop_sink)
    end

    @testset "device to host: nothing recorded, an empty host array returned" begin
        g = Backends.on(Float64[], gpu)
        sink = Events.Collector{Events.Moved}()
        Events.move_sink!(sink)
        h = Backends.on(g, cpu)
        @test isempty(Events.collected(sink))
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
        sink = Events.Collector{Events.Moved}()
        Events.move_sink!(sink)
        before = Events.move_counts()
        g = Backends.on([1.0], gpu)
        h = Backends.on(g, cpu)
        log = Events.collected(sink)
        @test length(log) == 2
        @test log[1].from == :cpu && log[1].to == :gpu
        @test log[2].from == :gpu && log[2].to == :cpu
        @test h == [1.0]
        @test Events.move_counts() != before
        Events.move_sink!(Events.noop_sink)
    end
end

# Every array backend_of cannot name a backend for leaves through a
# Verdicts.Refusal carrying the site and the type, rather than through the
# error KernelAbstractions raises for an array type it has no method for:
# fiddlybits-52v.7.55, raised by docs/decisions/0047.

module ElsewhereFixture

import KernelAbstractions

"A KernelAbstractions backend that is neither CPU nor CUDABackend."
struct Elsewhere <: KernelAbstractions.Backend end

"An array whose KernelAbstractions backend is `Elsewhere`."
struct ElsewhereArray{T,N} <: AbstractArray{T,N}
    data::Array{T,N}
end

Base.size(a::ElsewhereArray) = size(a.data)
Base.getindex(a::ElsewhereArray, i::Int...) = a.data[i...]
KernelAbstractions.get_backend(::ElsewhereArray) = Elsewhere()

end # module ElsewhereFixture

@testset "backend_of names a backend or raises its own refusal" begin
    @testset "a BitMatrix refuses, naming the site and the type" begin
        @test_throws Verdicts.Refusal Backends.backend_of(falses(2, 3))
        caught = try
            Backends.backend_of(falses(2, 3))
        catch e
            e
        end
        @test caught isa Verdicts.Refusal
        @test caught.site == "Backends.backend_of"
        @test caught.quantity == "array backend"
        @test occursin("BitMatrix", caught.reason)
    end

    @testset "a BitVector refuses the same way" begin
        caught = try
            Backends.backend_of(falses(4))
        catch e
            e
        end
        @test caught isa Verdicts.Refusal
        @test caught.site == "Backends.backend_of"
        @test occursin("BitVector", caught.reason)
    end

    @testset "on carries the refusal to the caller, in both directions" begin
        @test_throws Verdicts.Refusal Backends.on(falses(2, 3), Backends.CPU(1))
        @test_throws Verdicts.Refusal Backends.on(falses(2, 3), Backends.GPU(1))
    end

    @testset "positive control: a resolvable array type still names its backend" begin
        @test Backends.backend_of([1.0, 2.0]) === :cpu
        @test Backends.backend_of(Array(falses(2, 3))) === :cpu

        @test CUDA.functional()
        g = Backends.on([1.0, 2.0], Backends.GPU(1))
        @test Backends.backend_of(g) === :gpu
    end

    @testset "positive control: an unsupported backend still refuses" begin
        elsewhere = ElsewhereFixture.ElsewhereArray(rand(3))
        caught = try
            Backends.backend_of(elsewhere)
        catch e
            e
        end
        @test caught isa Verdicts.Refusal
        @test caught.site == "Backends.backend_of"
        @test occursin("neither CPU nor CUDABackend", caught.reason)
        @test occursin("Elsewhere", caught.reason)
    end
end
