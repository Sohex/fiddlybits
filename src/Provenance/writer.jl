# The store's writer: docs/plans/fiddlybits-52v.6-provenance.md, section "The writer";
# decisions 0010, 0027, 0029, 0038 and 0060. `submit!` admits a field inline through the
# admission `put_field!` makes, takes its charge whole from one `Backends.BytePool`, places it
# as one block of the writer's `Arena` and queues its host copy into that block; an encode
# stage and a disk stage land it into a staging directory; `settle!` renames the staging
# directories into place in submission order; `drain!` unregisters the arena.

import ..Dispositions
using ..Verdicts: Refusal
using ..Backends: Backends, GPU, BytePool, Handoff, after!, backend_of, charge!, close_pool!,
                  complete!, copy_to_host!, free_host_buffer!, host_buffer, release!

# ---------------------------------------------------------------- the arena

"The byte multiple every arena range starts at and every charge part is rounded up to."
const ARENA_ALIGN = 8

"`bytes` rounded up to a multiple of `ARENA_ALIGN`."
arena_round(bytes::Integer) = cld(Int(bytes), ARENA_ALIGN) * ARENA_ALIGN

"""
    Arena

The host memory every buffer of one writer is carved from: `bytes`, a `Vector{UInt8}`;
`pinned`, whether it is page-locked through `Backends.host_buffer(GPU(), UInt8, n)`; `free`,
its free ranges of 1-based byte indices, sorted, disjoint and never adjacent, every one
starting at an index one more than a multiple of `ARENA_ALIGN`; `condition`, notified at
every release and at the close; `closed`, once `close_arena!` began; and `unregistered`, once
its page lock is released. When no range is placed, `free` holds the one range `1:length(bytes)`.
`try_place!`, `place!`, `release_range!` and `close_arena!` are its doors.
"""
mutable struct Arena
    const bytes::Vector{UInt8}
    const pinned::Bool
    const free::Vector{UnitRange{Int}}
    const condition::Threads.Condition
    closed::Bool
    unregistered::Bool
end

"The site every refusal of the arena's doors names."
const ARENA_SITE = "Provenance.Arena"

"""
    open_arena(capacity)

An `Arena` of `capacity` bytes, `capacity` a positive multiple of `ARENA_ALIGN`: page-locked
through `Backends.host_buffer(GPU(), UInt8, capacity)`, and, when that refuses at
`Backends.ka_backend` because CUDA reports no functional device on the host, a
`Backends.host_buffer(CPU(), UInt8, capacity)` that is not page-locked. Refuses any other
`capacity`, and rethrows any other refusal of `host_buffer`.
"""
function open_arena(capacity::Integer)
    (capacity > 0 && capacity % ARENA_ALIGN == 0) || refuse(
        "capacity", ARENA_SITE, "an arena of $(capacity) bytes, and an arena is a positive multiple of $(ARENA_ALIGN) bytes")
    bytes, pinned = try
        host_buffer(GPU(), UInt8, Int(capacity)), true
    catch err
        (err isa Refusal && err.quantity == "GPU backend" && err.site == "Backends.ka_backend") || rethrow()
        host_buffer(CPU(), UInt8, Int(capacity)), false
    end
    return Arena(bytes, pinned, [1:Int(capacity)], Threads.Condition(), false, false)
end

"""
    try_place!(arena, n)

The first free range of `arena`, in index order, long enough for `n` bytes, `n` a positive
multiple of `ARENA_ALIGN`: its first `n` bytes taken from `arena.free` and returned as a range.
`nothing`, taking nothing, when no free range is that long. Refuses any other `n`. The caller
holds `arena.condition`.
"""
function try_place!(arena::Arena, n::Int)
    (n > 0 && n % ARENA_ALIGN == 0) || refuse(
        "bytes", ARENA_SITE, "a request of $(n) bytes, and a request is a positive multiple of $(ARENA_ALIGN) bytes")
    for (k, r) in enumerate(arena.free)
        length(r) >= n || continue
        placed = first(r):(first(r) + n - 1)
        length(r) == n ? deleteat!(arena.free, k) : (arena.free[k] = (first(r) + n):last(r))
        return placed
    end
    return nothing
end

"""
    place!(arena, n)

The range `try_place!` gives for `n` bytes, waiting on `arena.condition` until a release makes
one long enough. Refuses naming the close when `arena` is closed, before or during the wait.
"""
function place!(arena::Arena, n::Int)
    @lock arena.condition begin
        while true
            arena.closed && refuse("arena", ARENA_SITE, "the arena is closed; a request of $(n) bytes refused")
            placed = try_place!(arena, n)
            placed === nothing || return placed
            wait(arena.condition)
        end
    end
end

"""
    release_range!(arena, r)

Returns the placed range `r` to `arena.free`, merged with the free ranges it adjoins, and
notifies every waiter. Returns at once for an empty `r`. Refuses a range outside the arena,
not starting at an index one more than a multiple of `ARENA_ALIGN`, or overlapping a free range.
"""
function release_range!(arena::Arena, r::UnitRange{Int})
    isempty(r) && return nothing
    (first(r) >= 1 && last(r) <= length(arena.bytes) && (first(r) - 1) % ARENA_ALIGN == 0) || refuse(
        "range", ARENA_SITE, "the range $(r) is not a placed range of an arena of $(length(arena.bytes)) bytes")
    @lock arena.condition begin
        k = searchsortedfirst(arena.free, r; by = first)
        k > 1 && last(arena.free[k - 1]) >= first(r) && refuse(
            "range", ARENA_SITE, "the range $(r) overlaps the free range $(arena.free[k - 1])")
        k <= length(arena.free) && first(arena.free[k]) <= last(r) && refuse(
            "range", ARENA_SITE, "the range $(r) overlaps the free range $(arena.free[k])")
        merged = r
        if k <= length(arena.free) && first(arena.free[k]) == last(r) + 1
            merged = first(merged):last(arena.free[k])
            deleteat!(arena.free, k)
        end
        if k > 1 && last(arena.free[k - 1]) + 1 == first(merged)
            merged = first(arena.free[k - 1]):last(merged)
            deleteat!(arena.free, k - 1)
            k -= 1
        end
        insert!(arena.free, k, merged)
        notify(arena.condition; all = true)
    end
    return nothing
end

"The free ranges of `arena`, a copy."
free_ranges(arena::Arena) = @lock arena.condition copy(arena.free)

"""
    close_arena!(arena)

Marks `arena` closed, waking every `place!` waiting on it to refuse. Idempotent.
"""
function close_arena!(arena::Arena)
    @lock arena.condition begin
        arena.closed = true
        notify(arena.condition; all = true)
    end
    return nothing
end

"""
    arena_array(arena, r, T, dims)

An `Array{T}` of size `dims` over the bytes of `arena` from the first index of `r`, through
`unsafe_wrap`, not owning them. Refuses dims whose bytes exceed `r`.
"""
function arena_array(arena::Arena, r::UnitRange{Int}, T::Type, dims::Tuple)
    n = prod(dims; init = 1)
    sizeof(T) * n <= length(r) || refuse(
        "range", ARENA_SITE, "$(n) elements of $(T) do not fit the $(length(r)) bytes of the range $(r)")
    return unsafe_wrap(Array, Ptr{T}(pointer(arena.bytes, first(r))), dims; own = false)
end

# ---------------------------------------------------------------- the writer

"""
    Submission

One write handed to a `Writer`: `index`, its place in submission order; `admission`;
`block`, the arena range its charge is placed at, and `host`, its host copy over the first
bytes of that block; `point`, the copy's `Handoff`; `charge`, the `write_charge` it took;
`device`, whether its data lived on the card. The stages set `chunks`, the arena ranges of its
compressed chunks in chunk order, and `staging`, its staging directory; `refusal`, the late
refusal it met; `landed`, once no stage holds it; `outcome`, `:pending` until the commit makes
it `:committed`, `:refused` or `:discarded`; and `holding` and `peak`, the host bytes the
writer holds for it now and the most at once, each array counted by its own `sizeof` and each
compressed chunk by its compressed length. Every field a stage or the commit sets is set under
the writer's lock.
"""
mutable struct Submission
    const index::Int
    const admission::Admission
    const block::UnitRange{Int}
    const host::Vector
    const point::Handoff
    const charge::NamedTuple{(:host, :translated, :buffer, :compressed),NTuple{4,Int}}
    const device::Bool
    chunks::Vector{UnitRange{Int}}
    staging::Union{Nothing,String}
    refusal::Union{Nothing,Refusal}
    landed::Bool
    outcome::Symbol
    holding::Int
    peak::Int
end

"""
    Writer

The write path `open_writer` opens over `store` for the run `run`: `opener`, the task that
opened it and the only one that submits, settles and drains; `pool`, the `BytePool` at the
arena's capacity; `arena`, the `Arena` every host buffer of the writer is carved from;
`encode_queue` and `disk_queue`, unbounded in items; `encoders` and `disk_writers`, the stage
tasks. Under `lock`, with `condition` notified at every landing: `submissions` in submission
order; `dirs`, the directory of every submission to its index; `finished`, the indices in the
order the disk stage finished them; `closed`, once `drain!` began; `stopped`, once its stages
stopped; `cleared`, the submissions a settle's `Backends.complete!` has run after; `settled`,
the submissions the commit has walked; `refused`, the index of the earliest refused submission
the commit met, zero for none; `lowest_refusal`, the lowest index any stage recorded a refusal
at; `reported`, once `settle!` has raised that refusal; `host_alive` and `host_high_water`,
the sum of every submission's `holding` and the most at once.
"""
mutable struct Writer
    const store::Store
    const run::RunID
    const opener::Task
    const pool::BytePool
    const arena::Arena
    const encode_queue::Channel{Submission}
    const disk_queue::Channel{Submission}
    const encoders::Vector{Task}
    const disk_writers::Vector{Task}
    const lock::ReentrantLock
    const condition::Threads.Condition
    const submissions::Vector{Submission}
    const dirs::Dict{String,Int}
    const finished::Vector{Int}
    closed::Bool
    stopped::Bool
    cleared::Int
    settled::Int
    refused::Int
    lowest_refusal::Int
    reported::Bool
    host_alive::Int
    host_high_water::Int
end

"Every writer `open_writer` opened and `drain!` has not yet unregistered, held until then."
const OPEN_WRITERS = Writer[]

"The lock `OPEN_WRITERS` is read and written under."
const OPEN_WRITERS_LOCK = ReentrantLock()

"Whether `report_open_writers` is installed as an exit hook."
const OPEN_WRITERS_HOOKED = Ref(false)

"""
    report_open_writers()

Warns, once per writer, naming its store root, its run and its submission count, for every
writer in `OPEN_WRITERS`: a writer never drained, whose arena is still registered. Unregisters
nothing.
"""
function report_open_writers()
    for w in @lock OPEN_WRITERS_LOCK copy(OPEN_WRITERS)
        n = @lock w.lock length(w.submissions)
        @warn "Provenance.Writer over $(w.store.root) for run $(w.run.uuid) was never drained: " *
              "$(n) submissions, its arena of $(length(w.arena.bytes)) bytes still registered"
    end
    return nothing
end

"""
    open_writer(store; run, profile)

A `Writer` over `store` for the `RunID` `run`, its stages started: an `Arena` from
`open_arena` of `value(profile.write_ceiling)` bytes rounded down to a multiple of
`ARENA_ALIGN`; a `BytePool` of that capacity; `Threads.nthreads(:default)` encode tasks; and
`value(profile.store_writers)` disk tasks. The calling task is the writer's opener. The writer
is held in `OPEN_WRITERS` until `drain!` unregisters its arena, and the first call installs
`report_open_writers` as an exit hook. Every keyword is required. Refuses a `run` that is not a
`RunID`, a `profile` that is not a `Systems.Profile`, a `write_ceiling` below `ARENA_ALIGN`,
and whatever `open_arena` refuses.
"""
function open_writer(store::Store; kwargs...)
    site = "Provenance.open_writer"
    k, _ = read_keywords(site, values(kwargs), (:run, :profile), ())
    run = require_type("run", site, k.run, RunID)
    profile = require_type("profile", site, k.profile, Profile)
    ceiling = Dispositions.value(profile.write_ceiling)
    capacity = div(ceiling, ARENA_ALIGN) * ARENA_ALIGN
    capacity > 0 || refuse(
        "write_ceiling", site, "a write_ceiling of $(ceiling) bytes holds no arena range of $(ARENA_ALIGN) bytes")
    arena = open_arena(capacity)
    lock = ReentrantLock()
    w = Writer(store, run, current_task(), BytePool(ceiling = capacity), arena,
               Channel{Submission}(Inf), Channel{Submission}(Inf), Task[], Task[], lock,
               Threads.Condition(lock), Submission[], Dict{String,Int}(), Int[], false, false, 0, 0, 0,
               typemax(Int), false, 0, 0)
    @lock OPEN_WRITERS_LOCK begin
        push!(OPEN_WRITERS, w)
        if !OPEN_WRITERS_HOOKED[]
            atexit(report_open_writers)
            OPEN_WRITERS_HOOKED[] = true
        end
    end
    for _ in 1:Threads.nthreads(:default)
        push!(w.encoders, Threads.@spawn :default foreach(s -> encode_stage!(w, s), w.encode_queue))
    end
    for _ in 1:Dispositions.value(profile.store_writers)
        push!(w.disk_writers, Threads.@spawn :default foreach(s -> disk_stage!(w, s), w.disk_queue))
    end
    return w
end

"""
    submit!(writer, run::RunID; code, declaration, system, profile, inputs, quantity,
            operator_version, field, ledgers, chunk_level, values, interval)
    submit!(writer, scratch::ScratchRun; declaration, system, profile, inputs, quantity,
            operator_version, field, ledgers, chunk_level, values, interval)

Admits the write `put_field!` makes with the same keywords, through the same admission, and
returns the same `(key, stamped)` without landing it: the key is in flight until the
`settle!` that commits it. Refuses at `Provenance.submit!` everything that admission
refuses; then, before anything is charged, a directory this writer was handed already, a
submission after `drain!` began, a submission from a task other than the writer's opener,
and a run other than the writer's. Then takes the whole `write_charge` of the write from
the writer's pool, waiting behind every earlier waiter until it is free, and refusing at
once, naming both counts, a charge above the arena's capacity; places it as one block of the
writer's arena through `place!`, waiting for releases while no free range is long enough; and
queues `Backends.copy_to_host!` of the data into the block's first bytes. Refuses whatever
`copy_to_host!` refuses, the block and the charge released. Unregisters no host memory. A
refusal a stage met for an earlier submission refuses nothing here.
"""
submit!(w::Writer, run::RunID; kwargs...) =
    enqueue!(w, admit_put(w.store, SUBMIT_SITE, run, kwargs), run)

submit!(w::Writer, scratch::ScratchRun; kwargs...) =
    enqueue!(w, admit_put(w.store, SUBMIT_SITE, scratch, kwargs), scratch.run)

"The site every refusal of `submit!` names."
const SUBMIT_SITE = "Provenance.submit!"

"""
    write_charge(admission)

`(host, translated, buffer, compressed)`, the arena bytes of `admission`'s charge, each
rounded up by `arena_round`: `host`, its host copy, the bytes of its data; `translated`, the
array `to_disk!` writes, the bytes of its data for `CellIds` and none for `Amounts`; `buffer`,
the chunk-shaped array `compress_chunks!` copies each chunk into, one chunk's bytes; and
`compressed`, over each of its chunks, the chunk's bytes plus `Zarr.Blosc.MAX_OVERHEAD`. The
block places them in that order; the encode stage releases the first three and the disk stage
the fourth.
"""
function write_charge(a::Admission)
    T = eltype(a.data)
    cells = size(a.data, 1)
    per_cell = div(length(a.data), cells)
    data_bytes = sizeof(T) * length(a.data)
    chunk_bytes = sizeof(T) * a.per_chunk * per_cell
    return (host = arena_round(data_bytes), translated = a.values isa CellIds ? arena_round(data_bytes) : 0,
            buffer = arena_round(chunk_bytes),
            compressed = arena_round(div(cells, a.per_chunk) * (chunk_bytes + Zarr.Blosc.MAX_OVERHEAD)))
end

"The bytes of every part of `charge`, a `write_charge`."
charge_total(charge) = charge.host + charge.translated + charge.buffer + charge.compressed

"The parts of `charge`, a `write_charge`, the encode stage releases."
encode_part(charge) = charge.host + charge.translated + charge.buffer

"The arena range of the translated array in the block of `s`."
translated_range(s::Submission) = (first(s.block) + s.charge.host):(first(s.block) + s.charge.host + s.charge.translated - 1)

"The arena range of the chunk buffer in the block of `s`."
buffer_range(s::Submission) =
    (last(translated_range(s)) + 1):(last(translated_range(s)) + s.charge.buffer)

"The arena range of the part of the block of `s` the encode stage releases."
encode_range(s::Submission) = first(s.block):(first(s.block) + encode_part(s.charge) - 1)

"The arena range of the compressed chunks in the block of `s`."
compressed_range(s::Submission) = (first(s.block) + encode_part(s.charge)):last(s.block)

"""
    hold!(writer, s, bytes)

Adds `bytes` to what `writer` holds for `s` under the writer's lock, raising `s.peak` and the
writer's `host_high_water` to what is now held when it is more.
"""
function hold!(w::Writer, s::Submission, bytes::Int)
    @lock w.lock begin
        s.holding += bytes
        s.peak = max(s.peak, s.holding)
        w.host_alive += bytes
        w.host_high_water = max(w.host_high_water, w.host_alive)
    end
    return nothing
end

"Subtracts `bytes` from what `writer` holds for `s`, under the writer's lock."
function drop!(w::Writer, s::Submission, bytes::Int)
    @lock w.lock begin
        s.holding -= bytes
        w.host_alive -= bytes
    end
    return nothing
end

"""
    enqueue!(writer, admission, run)

The part of `submit!` after the admission: the refusals of the writer, the charge, the block,
the host copy, and the `Submission` queued for the encode stage. Returns `(key, stamped)`.
"""
function enqueue!(w::Writer, a::Admission, run::RunID)
    @lock w.lock begin
        haskey(w.dirs, a.dir) && refuse(
            "artifact", SUBMIT_SITE,
            "this writer was handed $(hex(a.key.digest)) at $(a.dir) as submission $(w.dirs[a.dir]) already")
        w.closed && refuse("writer", SUBMIT_SITE, "drain! began on this writer; it takes no submission")
    end
    current_task() === w.opener || refuse(
        "task", SUBMIT_SITE, "the writer was opened by another task, and only that task submits to it")
    run == w.run || refuse(
        "run", SUBMIT_SITE, "the writer writes run $(w.run.uuid), and the submission names run $(run.uuid)")
    charge = write_charge(a)
    total = charge_total(charge)
    charge!(w.pool, total)
    block = try
        place!(w.arena, total)
    catch
        release!(w.pool, total)
        rethrow()
    end
    device = backend_of(a.data) === :gpu
    host = arena_array(w.arena, block, eltype(a.data), (length(a.data),))
    point = try
        copy_to_host!(host, a.data)
    catch
        release_range!(w.arena, block)
        release!(w.pool, total)
        rethrow()
    end
    s = @lock w.lock begin
        s = Submission(length(w.submissions) + 1, a, block, host, point, charge, device,
                       UnitRange{Int}[], nothing, nothing, false, :pending, 0, 0)
        push!(w.submissions, s)
        w.dirs[a.dir] = s.index
        hold!(w, s, sizeof(host))
        s
    end
    put!(w.encode_queue, s)
    return a.key, a.stamped
end

"""
    stage_refusal(f, admission)

`nothing` when `f()` returns, and otherwise the `Refusal` it raised; any other error is
carried as a `Refusal` of `"artifact"` at `admission.site` whose reason holds the error's
message.
"""
function stage_refusal(f, a::Admission)
    try
        f()
        return nothing
    catch err
        err isa Refusal && return err
        return Refusal("artifact", a.site,
                       "the write of $(a.quantity) under $(hex(a.key.digest)) met $(sprint(showerror, err))")
    end
end

"Whether a stage has recorded a refusal at a submission before `s`, which discards `s`."
dropped(w::Writer, s::Submission) = @lock w.lock w.lowest_refusal < s.index

"""
    mark_landed!(writer, s, refusal)

Records under the writer's lock that no stage holds `s`, with the late refusal `refusal`
when it is not `nothing`, and notifies every waiter on the writer's condition.
"""
function mark_landed!(w::Writer, s::Submission, refusal)
    @lock w.lock begin
        if refusal !== nothing
            s.refusal = refusal
            w.lowest_refusal = min(w.lowest_refusal, s.index)
        end
        s.landed = true
        notify(w.condition; all = true)
    end
    return nothing
end

"""
    compress_chunks!(held, out, disk, per_chunk, buffer)

The ranges of `out`, a `Vector{UInt8}`, holding the chunks of `disk` along its cell axis,
`per_chunk` cells each and whole along every other axis, compressed in chunk order: each
chunk copied into `buffer`, an array of the chunk's shape, and compressed through
`Zarr.Blosc.compress!` into the bytes of `out` after the previous chunk's, under `BLOSC_LOCK`
after `Zarr.Blosc.set_compressor`, with the codec name, level and shuffle the `BloscCompressor`
`compressor()` holds and the chunk's element size. Calls `held(bytes)` with the length of each
compressed chunk once it is made. Refuses a compressor whose shuffle is not one of
`Zarr.Blosc.NOSHUFFLE`, `SHUFFLE` and `BITSHUFFLE`, a chunk that does not fit what remains of
`out`, and a chunk Blosc returns no bytes for.
"""
function compress_chunks!(held, out::Vector{UInt8}, disk::AbstractArray, per_chunk::Int, buffer::AbstractArray)
    c = compressor()
    c.shuffle in (Zarr.Blosc.NOSHUFFLE, Zarr.Blosc.SHUFFLE, Zarr.Blosc.BITSHUFFLE) || refuse(
        "compressor", "Provenance.compress_chunks!",
        "the compressor's shuffle is $(c.shuffle), which Zarr.zcompress maps before compressing and this route does not")
    others = ntuple(_ -> Colon(), ndims(disk) - 1)
    worst = sizeof(buffer) + Zarr.Blosc.MAX_OVERHEAD
    ranges = UnitRange{Int}[]
    cursor = 1
    for first in 1:per_chunk:size(disk, 1)
        cursor + worst - 1 <= length(out) || refuse(
            "chunk", "Provenance.compress_chunks!",
            "a chunk of up to $(worst) bytes does not fit the $(length(out) - cursor + 1) bytes left of $(length(out))")
        copyto!(buffer, view(disk, first:(first + per_chunk - 1), others...))
        dest = unsafe_wrap(Array, pointer(out, cursor), worst; own = false)
        n = @lock BLOSC_LOCK begin
            Zarr.Blosc.set_compressor(c.cname)
            GC.@preserve out Zarr.Blosc.compress!(dest, buffer; level = c.clevel, shuffle = c.shuffle)
        end
        n > 0 || refuse("chunk", "Provenance.compress_chunks!", "Blosc returned no bytes for a chunk of $(sizeof(buffer))")
        push!(ranges, cursor:(cursor + n - 1))
        held(n)
        cursor += n
    end
    return ranges
end

"""
    encode_stage!(writer, s)

The encode stage for `s`: reads under the writer's lock, before anything of `s`, whether an
earlier submission is refused; unless one is, waits on its copy's handoff through
`after!(CPU(), point)`, translates the host copy by `to_disk!` into the block's translated
range for `CellIds`, holding it, and compresses the result by `compress_chunks!` through the
block's chunk buffer into its compressed range, holding the buffer and each compressed chunk.
Then drops everything it held for `s` but the compressed chunks and releases the host,
translated and buffer ranges and parts of the charge. Queues `s` for the disk stage when it
compressed; otherwise drops the chunks, releases the compressed range and part, and marks `s`
landed with the refusal it met, if any. Waits on nothing between taking `s` and releasing its
parts but the handoff and `BLOSC_LOCK`, and unregisters no host memory.
"""
function encode_stage!(w::Writer, s::Submission)
    a = s.admission
    skip = dropped(w, s)
    kept = 0
    refusal = skip ? nothing : stage_refusal(a) do
        after!(CPU(), s.point)
        T = eltype(a.data)
        shape = size(a.data)
        source = reshape(s.host, shape)
        disk = if a.values isa CellIds
            translated = to_disk!(arena_array(w.arena, translated_range(s), T, shape), a.values, source, a.site)
            hold!(w, s, sizeof(translated))
            translated
        else
            source
        end
        buffer = arena_array(w.arena, buffer_range(s), T, (a.per_chunk, shape[2:end]...))
        hold!(w, s, sizeof(buffer))
        out = arena_array(w.arena, compressed_range(s), UInt8, (length(compressed_range(s)),))
        relative = GC.@preserve w compress_chunks!(bytes -> hold!(w, s, bytes), out, disk, a.per_chunk, buffer)
        offset = first(compressed_range(s)) - 1
        chunks = [(first(r) + offset):(last(r) + offset) for r in relative]
        kept = sum(length, chunks; init = 0)
        @lock w.lock s.chunks = chunks
    end
    failed = skip || refusal !== nothing
    @lock w.lock begin
        failed && (s.chunks = UnitRange{Int}[])
        drop!(w, s, failed ? s.holding : s.holding - kept)
    end
    release_range!(w.arena, encode_range(s))
    release!(w.pool, encode_part(s.charge))
    if failed
        release_range!(w.arena, compressed_range(s))
        release!(w.pool, s.charge.compressed)
        mark_landed!(w, s, refusal)
    else
        put!(w.disk_queue, s)
    end
    return nothing
end

"""
    write_staged!(staging, admission, chunks)

Writes `admission`'s artifact into the directory `staging`: the `create_array` of its data's
element type and size under its quantity, each of `chunks`, a vector of bytes per chunk,
through `Zarr.store_writechunk` under the chunk key the array's own chunk key encoding gives
its chunk index, and the manifest.
"""
function write_staged!(staging::AbstractString, a::Admission, chunks::AbstractVector)
    shape = size(a.data)
    z = create_array(joinpath(staging, String(a.quantity)), eltype(a.data), shape, a.attributes, a.per_chunk)
    for (c, bytes) in enumerate(chunks)
        index = CartesianIndex((c, ntuple(_ -> 1, length(shape) - 1)...))
        Zarr.store_writechunk(z.storage, bytes, z.path, index, z.metadata.chunk_key_encoding)
    end
    write_toml(joinpath(staging, MANIFEST), a.manifest)
    return nothing
end

"""
    disk_stage!(writer, s)

The disk stage for `s`: unless an earlier submission is refused, writes it by
`write_staged!`, each chunk the arena bytes of its range, into a `new_staging` directory beside
its place, removing that directory when the write raises. Then drops the compressed chunks it
held for `s`, releases the compressed range and part of the charge, appends `s` to the finish
record when it was staged, and marks it landed with the refusal it met, if any.
"""
function disk_stage!(w::Writer, s::Submission)
    a = s.admission
    skip = dropped(w, s)
    staging = nothing
    refusal = skip ? nothing : stage_refusal(a) do
        staging = new_staging(a.dir)
        write_staged!(staging, a, [view(w.arena.bytes, r) for r in s.chunks])
    end
    refusal === nothing || staging === nothing || rm(staging; recursive = true, force = true)
    staged = !skip && refusal === nothing
    @lock w.lock begin
        s.chunks = UnitRange{Int}[]
        drop!(w, s, s.holding)
        if staged
            s.staging = staging
            push!(w.finished, s.index)
        end
    end
    release_range!(w.arena, compressed_range(s))
    release!(w.pool, s.charge.compressed)
    mark_landed!(w, s, refusal)
    return nothing
end

"""
    require_opener(writer, site)

Refuses at `site` a call from a task other than the one that opened `writer`.
"""
require_opener(w::Writer, site::AbstractString) = current_task() === w.opener || refuse(
    "task", site, "the writer was opened by another task, and only that task calls $(site)")

"""
    settle!(writer)

Returns once every submission made so far is committed, refused or discarded. On the
opener's task: when a submission since the last settle holds device data, calls
`Backends.complete!(GPU())` first, and a refusal it raises becomes the refusal of the
earliest such submission; then waits on each submission's own state; then renames the
staging directory of each submission not yet walked into place, in submission order. The
earliest submission refused by a stage, by that call or at its rename is refused, every
submission after it is discarded, and every staging directory of a refused or discarded
submission is removed.

Refuses at `Provenance.settle!`, naming the earliest refused write's quantity, submission
number and key, the refusal it met, and how many later submissions it discarded. Raises
that refusal once: a later `settle!` or `drain!` raises nothing further. Refuses a call from
a task other than the opener.
"""
function settle!(w::Writer)
    site = "Provenance.settle!"
    require_opener(w, site)
    n = @lock w.lock length(w.submissions)
    clear_device!(w, n)
    @lock w.lock begin
        while !all(i -> w.submissions[i].landed, (w.settled + 1):n)
            wait(w.condition)
        end
    end
    commit!(w, n)
    report!(w, n, site)
    return nothing
end

"""
    clear_device!(writer, n)

When a submission among `writer.cleared + 1` to `n` holds device data, calls
`Backends.complete!(GPU())` on this task, and records a refusal it raises as the refusal
of the earliest such submission. Marks the first `n` submissions cleared.
"""
function clear_device!(w::Writer, n::Int)
    earliest = @lock w.lock findfirst(i -> w.submissions[i].device, (w.cleared + 1):n)
    if earliest !== nothing
        index = w.cleared + earliest
        fault = try
            complete!(GPU())
            nothing
        catch err
            err isa Refusal || rethrow()
            err
        end
        if fault !== nothing
            @lock w.lock begin
                w.submissions[index].refusal = fault
                w.lowest_refusal = min(w.lowest_refusal, index)
            end
        end
    end
    @lock w.lock w.cleared = n
    return nothing
end

"""
    commit!(writer, n)

Walks the submissions after `writer.settled` up to `n`, every one landed, in submission
order: after a refused submission each is discarded; a submission with a refusal is
refused; any other is renamed into place by `rename_staged!`, and refused when that raises.
Removes the staging directory of every submission refused or discarded.
"""
function commit!(w::Writer, n::Int)
    @lock w.lock begin
        for i in (w.settled + 1):n
            s = w.submissions[i]
            if w.refused != 0
                s.outcome = :discarded
            elseif s.refusal !== nothing
                s.outcome = :refused
                w.refused = i
            else
                a = s.admission
                refusal = stage_refusal(() -> rename_staged!(s.staging, a.dir, a.site), a)
                if refusal === nothing
                    s.outcome = :committed
                else
                    s.refusal = refusal
                    s.outcome = :refused
                    w.refused = i
                end
            end
            s.outcome === :committed || s.staging === nothing || rm(s.staging; recursive = true, force = true)
            s.staging = nothing
            w.settled = i
        end
    end
    return nothing
end

"""
    report!(writer, n, site)

Refuses at `site`, once for the writer, when the commit has met a refused submission,
naming it and how many of the first `n` submissions come after it.
"""
function report!(w::Writer, n::Int, site::AbstractString)
    refusal = @lock w.lock begin
        (w.refused == 0 || w.reported) && return nothing
        w.reported = true
        s = w.submissions[w.refused]
        a = s.admission
        r = s.refusal
        Refusal(String(a.quantity), site,
                "submission $(s.index) of $(a.quantity) under key $(hex(a.key.digest)) was refused: " *
                "$(r.quantity) at $(r.site): $(r.reason); $(n - s.index) later submissions discarded")
    end
    throw(refusal)
end

"""
    drain!(writer)

Closes `writer` to submissions, settles it, stops its stages whether the settle refused or
not, then unregisters its arena through `unregister_arena!` and removes it from
`OPEN_WRITERS`. Raises what `settle!` raises; otherwise what `unregister_arena!` raises. A
second call settles and raises nothing further. Refuses a call from a task other than the
opener.
"""
function drain!(w::Writer)
    site = "Provenance.drain!"
    require_opener(w, site)
    @lock w.lock w.closed = true
    settled = try
        settle!(w)
        nothing
    catch err
        err
    end
    stop_stages!(w)
    fault = unregister_arena!(w)
    settled === nothing || throw(settled)
    fault === nothing || throw(fault)
    return nothing
end

"""
    stop_stages!(writer)

Stops `writer`'s stages once: each queue closed and its tasks waited for, then its pool and its
arena closed.
"""
function stop_stages!(w::Writer)
    w.stopped && return nothing
    close(w.encode_queue)
    foreach(wait, w.encoders)
    close(w.disk_queue)
    foreach(wait, w.disk_writers)
    close_pool!(w.pool)
    close_arena!(w.arena)
    w.stopped = true
    return nothing
end

"""
    unregister_arena!(writer)

Once for `writer`, with its stages stopped: when its arena is page-locked, calls
`Backends.complete!(GPU())` on this task and then releases the page lock through
`Backends.free_host_buffer!`, whether `complete!` refused or not; then removes `writer` from
`OPEN_WRITERS`. Returns the refusal `complete!` raised, or `nothing`.
"""
function unregister_arena!(w::Writer)
    arena = w.arena
    arena.unregistered && return nothing
    fault = nothing
    if arena.pinned
        fault = try
            complete!(GPU())
            nothing
        catch err
            err isa Refusal || rethrow()
            err
        end
        free_host_buffer!(arena.bytes)
    end
    arena.unregistered = true
    @lock OPEN_WRITERS_LOCK filter!(x -> x !== w, OPEN_WRITERS)
    return fault
end

"The indices of `writer`'s submissions in the order its disk stage finished them."
finish_order(w::Writer) = @lock w.lock copy(w.finished)

"The outcome of each of `writer`'s submissions, in submission order."
outcomes(w::Writer) = @lock w.lock [s.outcome for s in w.submissions]

"The whole charge each of `writer`'s submissions took, in submission order."
submitted_charges(w::Writer) = @lock w.lock [charge_total(s.charge) for s in w.submissions]

"The `write_charge` each of `writer`'s submissions took, in submission order."
charge_parts(w::Writer) = @lock w.lock [s.charge for s in w.submissions]

"The most host bytes `writer` held at once for each of its submissions, in submission order."
submission_peaks(w::Writer) = @lock w.lock [s.peak for s in w.submissions]

"The most host bytes `writer` has held at once over all its submissions."
host_high_water(w::Writer) = @lock w.lock w.host_high_water

"The most bytes `writer`'s pool has held charged at once."
pool_high_water(w::Writer) = Backends.high_water(w.pool)

"The bytes `writer`'s pool holds charged now."
pool_held(w::Writer) = Backends.held(w.pool)
