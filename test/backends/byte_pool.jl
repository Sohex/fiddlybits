using Test
using Fiddlybits: Backends, Verdicts

# Backends.BytePool, charge! and release!: docs/plans/fiddlybits-52v.6-provenance.md,
# section "The writer"; decision 0038, item 4.
#
# Every task below is spawned with @async on the caller's thread. A `Channel` take!
# meets a spawned task, and the `yield()` after it lets that task reach its `wait`
# inside `charge!` before the caller goes on.

@testset "BytePool(; ceiling) refuses a ceiling that is not a positive Int" begin
    @test_throws Verdicts.Refusal Backends.BytePool(; ceiling = 0)
    @test_throws Verdicts.Refusal Backends.BytePool(; ceiling = -1)

    try
        Backends.BytePool(; ceiling = 0)
    catch err
        @test err isa Verdicts.Refusal
        @test occursin("0", err.reason)
    end

    # Positive control: a positive ceiling does not refuse.
    pool = Backends.BytePool(; ceiling = 1)
    @test Backends.held(pool) == 0
    @test Backends.high_water(pool) == 0
end

@testset "a burst above the ceiling never lifts high_water above it, and drains to zero" begin
    ceiling = 120
    pool = Backends.BytePool(; ceiling = ceiling)
    charges = [40, 40, 40, 40, 40]  # sum 200, above ceiling 120: not every charge fits at once

    @sync for bytes in charges
        @async begin
            Backends.charge!(pool, bytes)
            yield()  # hold the charge across a yield rather than release it at once
            Backends.release!(pool, bytes)
        end
    end

    @test Backends.high_water(pool) <= ceiling
    @test Backends.high_water(pool) > 0
    @test Backends.held(pool) == 0
end

@testset "charge! above the ceiling refuses at once, holding nothing and disturbing no other waiter" begin
    ceiling = 50
    pool = Backends.BytePool(; ceiling = ceiling)

    # A legitimate charge already fills the pool and a second is already queued
    # behind it, waiting.
    Backends.charge!(pool, ceiling)

    started = Channel{Bool}(1)
    result = Channel{Any}(1)
    waiting_task = @async begin
        put!(started, true)
        try
            Backends.charge!(pool, ceiling)
            put!(result, :charged)
        catch err
            put!(result, err)
        end
    end
    take!(started)
    yield()  # let waiting_task enqueue itself and reach its wait

    @test !isready(result)  # still waiting on the full pool

    @test_throws Verdicts.Refusal Backends.charge!(pool, ceiling + 1)
    try
        Backends.charge!(pool, ceiling + 1)
    catch err
        @test err isa Verdicts.Refusal
        @test occursin(string(ceiling + 1), err.reason)
        @test occursin(string(ceiling), err.reason)
    end
    @test Backends.held(pool) == ceiling  # the refusal held nothing

    # The already-waiting charge is unaffected: releasing the first charge serves it.
    Backends.release!(pool, ceiling)
    @test take!(result) === :charged
    Backends.release!(pool, ceiling)
    @test Backends.held(pool) == 0
    wait(waiting_task)
end

@testset "waiters are served in the order they began waiting: a small charge never passes a large one" begin
    ceiling = 100
    pool = Backends.BytePool(; ceiling = ceiling)

    Backends.charge!(pool, ceiling)  # the pool is full

    big_started = Channel{Bool}(1)
    big_result = Channel{Any}(1)
    big_task = @async begin
        put!(big_started, true)
        try
            Backends.charge!(pool, ceiling)
            put!(big_result, :charged)
            Backends.release!(pool, ceiling)
        catch err
            put!(big_result, err)
        end
    end
    take!(big_started)
    yield()  # big_task enqueues and begins waiting first

    small_started = Channel{Bool}(1)
    small_result = Channel{Any}(1)
    small_task = @async begin
        put!(small_started, true)
        try
            Backends.charge!(pool, 1)
            put!(small_result, :charged)
        catch err
            put!(small_result, err)
        end
    end
    take!(small_started)
    yield()  # small_task enqueues behind big_task and begins waiting

    # One byte freed is enough room for the small charge, but strict arrival order
    # keeps it behind the still-unserved large one.
    Backends.release!(pool, 1)
    yield()
    @test !isready(small_result)
    @test !isready(big_result)

    # Freeing the rest lets the large charge through; it releases in turn, and only
    # then does the small charge, still behind it, get served.
    Backends.release!(pool, ceiling - 1)
    @test take!(big_result) === :charged
    @test take!(small_result) === :charged
    Backends.release!(pool, 1)
    @test Backends.held(pool) == 0
    wait(big_task)
    wait(small_task)
end

@testset "release! of more than is held refuses" begin
    pool = Backends.BytePool(; ceiling = 50)
    Backends.charge!(pool, 20)

    @test_throws Verdicts.Refusal Backends.release!(pool, 21)
    try
        Backends.release!(pool, 21)
    catch err
        @test err isa Verdicts.Refusal
        @test occursin("21", err.reason)
        @test occursin("20", err.reason)
    end
    @test Backends.held(pool) == 20  # the refused release changed nothing

    # Positive control: releasing exactly what is held does not refuse.
    Backends.release!(pool, 20)
    @test Backends.held(pool) == 0
end

@testset "release! refuses a bytes count that is not a positive Int" begin
    pool = Backends.BytePool(; ceiling = 50)
    Backends.charge!(pool, 10)
    @test_throws Verdicts.Refusal Backends.release!(pool, 0)
    @test_throws Verdicts.Refusal Backends.release!(pool, -1)
    @test Backends.held(pool) == 10
    Backends.release!(pool, 10)
end

@testset "charge! refuses a bytes count that is not a positive Int" begin
    pool = Backends.BytePool(; ceiling = 50)
    @test_throws Verdicts.Refusal Backends.charge!(pool, 0)
    @test_throws Verdicts.Refusal Backends.charge!(pool, -5)
    @test Backends.held(pool) == 0
end

@testset "close_pool! makes a waiting charge! refuse naming the close" begin
    pool = Backends.BytePool(; ceiling = 10)
    Backends.charge!(pool, 10)  # the pool is full

    started = Channel{Bool}(1)
    result = Channel{Any}(1)
    waiting_task = @async begin
        put!(started, true)
        try
            Backends.charge!(pool, 10)
            put!(result, :charged)
        catch err
            put!(result, err)
        end
    end
    take!(started)
    yield()  # let it enqueue and begin waiting

    @test !isready(result)  # still waiting before the close

    Backends.close_pool!(pool)
    err = take!(result)
    @test err isa Verdicts.Refusal
    @test occursin("clos", err.reason)  # "closed" or "close"

    # A later charge! on the same pool refuses the same way, at once.
    @test_throws Verdicts.Refusal Backends.charge!(pool, 1)
    try
        Backends.charge!(pool, 1)
    catch err2
        @test err2 isa Verdicts.Refusal
        @test occursin("clos", err2.reason)
    end
    wait(waiting_task)

    @testset "positive control: an open pool does not refuse the same waiting charge" begin
        open_pool = Backends.BytePool(; ceiling = 10)
        Backends.charge!(open_pool, 10)
        opened_started = Channel{Bool}(1)
        opened_result = Channel{Any}(1)
        opened_task = @async begin
            put!(opened_started, true)
            try
                Backends.charge!(open_pool, 10)
                put!(opened_result, :charged)
            catch err3
                put!(opened_result, err3)
            end
        end
        take!(opened_started)
        yield()
        @test !isready(opened_result)
        Backends.release!(open_pool, 10)
        @test take!(opened_result) === :charged
        Backends.release!(open_pool, 10)
        wait(opened_task)
    end
end
