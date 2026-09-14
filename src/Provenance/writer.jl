# The store's writer: docs/plans/fiddlybits-52v.6-provenance.md, section "The writer";
# decisions 0010, 0027, 0029, 0038 and 0060. `submit!` admits a field inline through the
# admission `put_field!` makes, takes its charge whole from one `Backends.BytePool` and
# queues its host copy; an encode stage and a disk stage land it into a staging directory;
# `settle!` renames the staging directories into place in submission order.

import ..Dispositions
using ..Verdicts: Refusal
using ..Backends: Backends, GPU, BytePool, Handoff, after!, backend_of, charge!, close_pool!,
                  complete!, copy_to_host!, free_host_buffer!, host_buffer, release!

"""
    Submission

One write handed to a `Writer`: `index`, its place in submission order; `admission`;
`host`, the host buffer its copy lands in, and `point`, the copy's `Handoff`; `charge`, the
`write_charge` it took; `device`, whether its data lived on the card. The stages set
`chunks`, its compressed chunks in chunk order, and `staging`, its staging directory;
`refusal`, the late refusal it met; `landed`, once no stage holds it; `outcome`, `:pending`
until the commit makes it `:committed`, `:refused` or `:discarded`; and `holding` and
`peak`, the host bytes the writer holds for it now and the most at once, each buffer
counted by its own `sizeof` and each compressed chunk by its compressed length. Every field
a stage or the commit sets is set under the writer's lock.
"""
mutable struct Submission
    const index::Int
    const admission::Admission
    const host::Vector
    const point::Handoff
    const charge::NamedTuple{(:host, :translated, :buffer, :compressed),NTuple{4,Int}}
    const device::Bool
    chunks::Vector{Vector{UInt8}}
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
profile's `write_ceiling`; `encode_queue` and `disk_queue`, unbounded in items; `encoders`
and `disk_writers`, the stage tasks. Under `lock`, with `condition` notified at every
landing: `submissions` in submission order; `dirs`, the directory of every submission to
its index; `finished`, the indices in the order the disk stage finished them; `closed`,
once `drain!` began; `stopped`, once its stages stopped; `cleared`, the submissions a
settle's `Backends.complete!` has run after; `settled`, the submissions the commit has
walked; `refused`, the index of the earliest refused submission the commit met, zero for
none; `lowest_refusal`, the lowest index any stage recorded a refusal at; `reported`, once
`settle!` has raised that refusal; `host_alive` and `host_high_water`, the sum of every
submission's `holding` and the most at once.
"""
mutable struct Writer
    const store::Store
    const run::RunID
    const opener::Task
    const pool::BytePool
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

"""
    open_writer(store; run, profile)

A `Writer` over `store` for the `RunID` `run`, its stages started: a `BytePool` at
`value(profile.write_ceiling)` bytes; `Threads.nthreads(:default)` encode tasks; and
`value(profile.store_writers)` disk tasks. The calling task is the writer's opener. Every
keyword is required. Refuses a `run` that is not a `RunID` and a `profile` that is not a
`Systems.Profile`.
"""
function open_writer(store::Store; kwargs...)
    site = "Provenance.open_writer"
    k, _ = read_keywords(site, values(kwargs), (:run, :profile), ())
    run = require_type("run", site, k.run, RunID)
    profile = require_type("profile", site, k.profile, Profile)
    lock = ReentrantLock()
    w = Writer(store, run, current_task(), BytePool(ceiling = Dispositions.value(profile.write_ceiling)),
               Channel{Submission}(Inf), Channel{Submission}(Inf), Task[], Task[], lock,
               Threads.Condition(lock), Submission[], Dict{String,Int}(), Int[], false, false, 0, 0, 0,
               typemax(Int), false, 0, 0)
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
once, naming both counts, a charge above the ceiling; allocates a `Backends.host_buffer`
on the backend the field's data lives on; and queues `Backends.copy_to_host!` of the data
into it. Refuses whatever `host_buffer` and `copy_to_host!` refuse, the charge released. A
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

`(host, translated, buffer, compressed)`, the bytes of every host buffer the writer holds
for `admission`, the four parts of its charge: `host`, its host copy, the bytes of its
data; `translated`, the array `to_disk` makes, the bytes of its data for `CellIds` and none
for `Amounts`; `buffer`, the chunk-shaped array `compress_chunks` copies each chunk into,
one chunk's bytes; and `compressed`, over each of its chunks, the chunk's bytes plus
`Zarr.Blosc.MAX_OVERHEAD`. The encode stage releases the first three and the disk stage
the fourth.
"""
function write_charge(a::Admission)
    T = eltype(a.data)
    cells = size(a.data, 1)
    per_cell = div(length(a.data), cells)
    data_bytes = sizeof(T) * length(a.data)
    chunk_bytes = sizeof(T) * a.per_chunk * per_cell
    return (host = data_bytes, translated = a.values isa CellIds ? data_bytes : 0, buffer = chunk_bytes,
            compressed = div(cells, a.per_chunk) * (chunk_bytes + Zarr.Blosc.MAX_OVERHEAD))
end

"The bytes of every part of `charge`, a `write_charge`."
charge_total(charge) = charge.host + charge.translated + charge.buffer + charge.compressed

"The parts of `charge`, a `write_charge`, the encode stage releases."
encode_part(charge) = charge.host + charge.translated + charge.buffer

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

The part of `submit!` after the admission: the refusals of the writer, the charge, the host
copy, and the `Submission` queued for the encode stage. Returns `(key, stamped)`.
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
    charge!(w.pool, charge_total(charge))
    device = backend_of(a.data) === :gpu
    host = nothing
    point = try
        host = host_buffer(device ? GPU() : CPU(), eltype(a.data), length(a.data))
        copy_to_host!(host, a.data)
    catch
        host === nothing || free_host_buffer!(host)
        release!(w.pool, charge_total(charge))
        rethrow()
    end
    s = @lock w.lock begin
        s = Submission(length(w.submissions) + 1, a, host, point, charge, device,
                       Vector{UInt8}[], nothing, nothing, false, :pending, 0, 0)
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
    compress_chunks(held, disk, per_chunk)

The chunks of `disk` along its cell axis, `per_chunk` cells each and whole along every other
axis, each copied into one `Array` of the chunk's shape and compressed by `Zarr.zcompress`
with `compressor()` under `BLOSC_LOCK`, in chunk order. Calls `held(bytes)` with the
`sizeof` of that array once it is allocated and with the length of each compressed chunk
once it is made.
"""
function compress_chunks(held, disk::AbstractArray, per_chunk::Int)
    rest = size(disk)[2:end]
    buffer = Array{eltype(disk)}(undef, per_chunk, rest...)
    held(sizeof(buffer))
    others = ntuple(_ -> Colon(), ndims(disk) - 1)
    starts = 1:per_chunk:size(disk, 1)
    chunks = Vector{Vector{UInt8}}(undef, length(starts))
    for (c, first) in enumerate(starts)
        copyto!(buffer, view(disk, first:(first + per_chunk - 1), others...))
        chunks[c] = @lock BLOSC_LOCK Zarr.zcompress(buffer, compressor())
        held(sizeof(chunks[c]))
    end
    return chunks
end

"""
    encode_stage!(writer, s)

The encode stage for `s`: reads under the writer's lock, before anything of `s`, whether an
earlier submission is refused; unless one is, waits on its copy's handoff through
`after!(CPU(), point)`, translates the host copy by `to_disk`, holding the translated array
for `CellIds`, and compresses it by `compress_chunks`, holding its chunk buffer and each
compressed chunk. Then frees the host buffer, drops everything it held for `s` but the
compressed chunks, and releases the host, translated and buffer parts of the charge. Queues
`s` for the disk stage when it compressed; otherwise drops the chunks, releases the
compressed part and marks `s` landed with the refusal it met, if any. Waits on nothing
between taking `s` and releasing its parts but the handoff and `BLOSC_LOCK`.
"""
function encode_stage!(w::Writer, s::Submission)
    a = s.admission
    skip = dropped(w, s)
    kept = 0
    refusal = skip ? nothing : stage_refusal(a) do
        after!(CPU(), s.point)
        disk = to_disk(a.values, reshape(s.host, size(a.data)), a.site)
        a.values isa CellIds && hold!(w, s, sizeof(disk))
        chunks = compress_chunks(bytes -> hold!(w, s, bytes), disk, a.per_chunk)
        kept = sum(sizeof, chunks; init = 0)
        @lock w.lock s.chunks = chunks
    end
    freed = stage_refusal(() -> free_host_buffer!(s.host), a)
    refusal = refusal === nothing ? freed : refusal
    failed = skip || refusal !== nothing
    @lock w.lock begin
        failed && (s.chunks = Vector{UInt8}[])
        drop!(w, s, failed ? s.holding : s.holding - kept)
    end
    encode_part(s.charge) > 0 && release!(w.pool, encode_part(s.charge))
    if failed
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
element type and size under its quantity, each of `chunks` through `Zarr.store_writechunk`
under the chunk key the array's own chunk key encoding gives its chunk index, and the
manifest.
"""
function write_staged!(staging::AbstractString, a::Admission, chunks::Vector{Vector{UInt8}})
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
`write_staged!` into a `new_staging` directory beside its place, removing that directory
when the write raises. Then drops the compressed chunks it held for `s`, releases the
compressed part of the charge, appends `s` to the finish record when it was staged, and
marks it landed with the refusal it met, if any.
"""
function disk_stage!(w::Writer, s::Submission)
    a = s.admission
    skip = dropped(w, s)
    staging = nothing
    refusal = skip ? nothing : stage_refusal(a) do
        staging = new_staging(a.dir)
        write_staged!(staging, a, s.chunks)
    end
    refusal === nothing || staging === nothing || rm(staging; recursive = true, force = true)
    staged = !skip && refusal === nothing
    @lock w.lock begin
        s.chunks = Vector{UInt8}[]
        drop!(w, s, s.holding)
        if staged
            s.staging = staging
            push!(w.finished, s.index)
        end
    end
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

Closes `writer` to submissions, settles it, and stops its stages whether the settle
refused or not: the encode queue closed and its tasks waited for, then the disk queue and
its tasks, then the pool closed. Raises what `settle!` raises. A second call settles and
raises nothing further. Refuses a call from a task other than the opener.
"""
function drain!(w::Writer)
    site = "Provenance.drain!"
    require_opener(w, site)
    @lock w.lock w.closed = true
    try
        settle!(w)
    finally
        stop_stages!(w)
    end
    return nothing
end

"Stops `writer`'s stages once: each queue closed and its tasks waited for, then its pool closed."
function stop_stages!(w::Writer)
    w.stopped && return nothing
    close(w.encode_queue)
    foreach(wait, w.encoders)
    close(w.disk_queue)
    foreach(wait, w.disk_writers)
    close_pool!(w.pool)
    w.stopped = true
    return nothing
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
