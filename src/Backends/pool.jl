# Backends.BytePool: docs/plans/fiddlybits-52v.6-provenance.md, section "The writer";
# decision 0038, item 4. The one pool of bytes a stage charges whole and releases,
# bounded by a declared ceiling, sitting beside the memory budget of budget.jl so every
# stage a tree builds charges this one pool rather than declaring a second.

using ..Verdicts: refuse

"The site every refusal of `BytePool`, `charge!`, `release!` and `close_pool!` names."
const BYTE_POOL_SITE = "Backends.BytePool"

"""
    BytePool

The one pool of bytes a stage charges whole and releases, bounded by `ceiling`. Waiters
are queued in `queue`, the tickets of `charge!` calls still waiting, in the order they
began waiting; only the ticket at the front of `queue` is ever served, so a large charge
is never passed by a smaller one behind it. `condition` is the `Threads.Condition` a
waiter parks on and every state change notifies. `charge!`, `release!`, `held`,
`high_water` and `close_pool!` are its doors; nothing reads or writes a field of a
`BytePool` outside them.
"""
mutable struct BytePool
    ceiling::Int
    held::Int
    high_water::Int
    closed::Bool
    next_ticket::UInt64
    queue::Vector{UInt64}
    condition::Threads.Condition
end

"""
    BytePool(; ceiling)

A pool bounded at `ceiling` bytes, nothing held. Refuses a `ceiling` that is not a
positive `Int`.
"""
function BytePool(; ceiling::Integer)
    ceiling > 0 ||
        refuse("ceiling", BYTE_POOL_SITE, "ceiling must be a positive Int; got $(ceiling)")
    return BytePool(Int(ceiling), 0, 0, false, UInt64(0), UInt64[], Threads.Condition())
end

"""
    held(pool)

The bytes `pool` has charged and not yet released.
"""
held(pool::BytePool) = @lock pool.condition pool.held

"""
    high_water(pool)

The most bytes `pool` has held at once since it was made.
"""
high_water(pool::BytePool) = @lock pool.condition pool.high_water

"""
    charge!(pool, bytes)

Waits until the whole of `bytes` is free in `pool` and every charge that began waiting
before this one has been served, then takes it: waiters yield their thread on
`pool.condition` rather than busy-waiting, and are woken and rechecked in the order
they began waiting, so a large charge already at the front of the queue is never passed
by a smaller one behind it.

Refuses at once, before anything is queued, naming both counts, a `bytes` above
`pool`'s ceiling, and refuses a `bytes` that is not a positive `Int`. Refuses naming the
close when `pool` is already closed, and refuses the same way a charge that was already
waiting when `close_pool!` closed it.
"""
function charge!(pool::BytePool, bytes::Integer)
    bytes > 0 ||
        refuse("charge", BYTE_POOL_SITE, "charge must be a positive Int; got $(bytes)")
    bytes = Int(bytes)

    @lock pool.condition begin
        pool.closed &&
            refuse("charge", BYTE_POOL_SITE,
                   "pool is closed; charge of $(bytes) bytes refused")
        bytes > pool.ceiling &&
            refuse("charge", BYTE_POOL_SITE,
                   "charge of $(bytes) bytes exceeds ceiling of $(pool.ceiling) bytes")

        ticket = pool.next_ticket
        pool.next_ticket += UInt64(1)
        push!(pool.queue, ticket)

        try
            while true
                pool.closed &&
                    refuse("charge", BYTE_POOL_SITE,
                           "pool closed while a charge of $(bytes) bytes was waiting")
                if first(pool.queue) == ticket && bytes <= pool.ceiling - pool.held
                    pool.held += bytes
                    pool.high_water = max(pool.high_water, pool.held)
                    break
                end
                wait(pool.condition)
            end
        finally
            deleteat!(pool.queue, findfirst(==(ticket), pool.queue))
            notify(pool.condition; all = true)
        end
    end
    return nothing
end

"""
    release!(pool, bytes)

Returns `bytes` to `pool` and wakes every waiter to recheck its place in the queue.
Refuses a release of more bytes than `pool` currently holds, and refuses a `bytes` that
is not a positive `Int`. Takes effect whether or not `pool` is closed, because a stage
still has to return the bytes of a charge it took before the close.
"""
function release!(pool::BytePool, bytes::Integer)
    bytes > 0 ||
        refuse("release", BYTE_POOL_SITE, "release must be a positive Int; got $(bytes)")
    bytes = Int(bytes)

    @lock pool.condition begin
        bytes > pool.held &&
            refuse("release", BYTE_POOL_SITE,
                   "release of $(bytes) bytes exceeds $(pool.held) bytes held")
        pool.held -= bytes
        notify(pool.condition; all = true)
    end
    return nothing
end

"""
    close_pool!(pool)

Marks `pool` closed: every `charge!` already waiting on it wakes and refuses naming the
close, and every `charge!` called on it afterward refuses the same way at once.
Idempotent; closing an already-closed pool changes nothing.
"""
function close_pool!(pool::BytePool)
    @lock pool.condition begin
        pool.closed = true
        notify(pool.condition; all = true)
    end
    return nothing
end
