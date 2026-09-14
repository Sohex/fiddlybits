using Test
using TOML
using CUDA
using KernelAbstractions: @kernel, @index
using Fiddlybits: Fiddlybits, Provenance, Fields, Mesh, Time, Dimensions, Backends, Verdicts, Events

# The store's writer: provenance.pooled_write_is_reference, provenance.write_order_independent
# and provenance.write_ceiling_held, docs/plans/fiddlybits-52v.6-provenance.md, section "The
# writer"; decisions 0027, 0029, 0038 and 0060; docs/imports/zarr.md.
#
# Tasks below are ordered by Channels, by fetch and by the writer's lock and condition. The
# GPU order arm queues the large field's copy behind a running kernel, waits on the writer's
# condition until every other submission has finished, and fails when the stream has
# already finished by then; the CPU order arm has no such hold and reads no finish order.

isdefined(@__MODULE__, :StoreFixtures) || include(joinpath(@__DIR__, "..", "io", "store_fixtures.jl"))
import .StoreFixtures as ST

"The cells of the fixture level."
const WRITER_CELLS = Mesh.ncells(ST.level())

"The columns of the large field the order arms submit first."
const WRITER_BIG_COLUMNS = 6400

"An array of `T` of size `dims` whose elements are a fixed mixing formula of their index and `seed`."
function writer_pattern(T, dims, seed)
    a = Array{T}(undef, dims...)
    for i in eachindex(a)
        x = UInt64(i) * 0x9e3779b97f4a7c15 + UInt64(seed) * 0xbf58476d1ce4e5b9
        x = xor(x, x >> 31) * 0x94d049bb133111eb
        a[i] = T === Bool ? isodd(x >> 7) : T <: Integer ? x % T : T(Float64(x >> 11) / 2.0^53)
    end
    return a
end

"The backends each oracle runs on."
writer_backends() = (Backends.CPU(), Backends.GPU())

"The name of `backend`'s type."
writer_name(backend) = String(nameof(typeof(backend)))

"The keywords of a cell-id write of `values` into `:parent_cell`, beside the field on `support` in `run` over `data`."
writer_cell_keywords(support, run, data, values) =
    (field = ST.field(support, run, data; semantics = Fields.Intensive(), dimension = Dimensions.DIMENSIONLESS),
     declaration = ST.declaration(quantity = :parent_cell, semantics = Fields.Intensive()),
     quantity = :parent_cell, values = values)

"""
    writer_cases(support, run, backend)

The fields `provenance.pooled_write_is_reference` writes, as keywords of `ST.submit` and
`ST.put` with their `field`, data on `backend`: amounts in `Float64`, `Float32`, `Int32` and
`Bool` and a two-axis `Float64`, and cell ids of the level above in `Int64` and of the fixture
level in `Int32`, at chunk levels zero to two.
"""
function writer_cases(support, run, backend)
    on(x) = Backends.on(x, backend)
    amounts(data, chunk_level) = (field = ST.field(support, run, on(data)), chunk_level = chunk_level)
    parents = [Mesh.parent(i) for i in 1:WRITER_CELLS]
    cells = Int32[mod1(7 * i, WRITER_CELLS) for i in 1:WRITER_CELLS]
    return [
        amounts(writer_pattern(Float64, (WRITER_CELLS,), 1), 1),
        amounts(writer_pattern(Float32, (WRITER_CELLS,), 2), 0),
        amounts(writer_pattern(Int32, (WRITER_CELLS,), 3), 2),
        amounts(writer_pattern(Bool, (WRITER_CELLS,), 4), 1),
        amounts(writer_pattern(Float64, (WRITER_CELLS, 7), 5), 1),
        merge(writer_cell_keywords(support, run, on(parents), Provenance.CellIds(level = ST.level() - 1)),
              (chunk_level = 1,)),
        merge(writer_cell_keywords(support, run, on(cells), Provenance.CellIds(level = ST.level())),
              (chunk_level = 0,)),
    ]
end

"`case` without its `field`, with `operator_version` set to `op`."
writer_rest(case, op) = merge(Base.structdiff(case, NamedTuple{(:field,)}), (operator_version = op,))

"Whether some submission in the finish record `order` finished before one submitted earlier."
writer_inverted(order) = any(k -> order[k] > order[k + 1], 1:(length(order) - 1))

"The manifest path of the artifact `key` in `store`."
writer_manifest(store, key) = joinpath(Provenance.object_directory(store, key), Provenance.MANIFEST)

"A `Ledger{Q}` over the fixture level taking a stock of 5 to `after`."
writer_ledger(Q, after) = Fields.Ledger{Q}(Float64, WRITER_CELLS, 1.0, 5.0, after, 0.0; reservoir = false)

"""
The bound, in seconds, on a wait that ends only when writer stages finish; reaching it fails
the arm. Sized from the healthy wait measured under a contended card and loaded cores:
`fiddlybits-52v.6.26`'s notes carry the measurements and the factor.
"""
const WRITER_BOUND = 120.0

"""
The seconds of spinning, at the rate `writer_warm` measures, a gate kernel's iteration ceiling
allows: above the longest healthy hold measured and below `WRITER_BOUND`. Reaching it fails
the arm.
"""
const WRITER_GATE_SECONDS = 90.0

"The iterations `writer_warm` times an unreleased gate kernel over."
const WRITER_GATE_PROBE = 2.0^22

"The value a gate cell holds until the test releases it."
const WRITER_HOLD = -1.0

@kernel function writer_gate_kernel!(spins, gate, hold, ceiling)
    i = @index(Global)
    while gate[1] == hold && spins[1] < ceiling
        spins[1] += one(eltype(spins))
    end
end

"""
    WriterGate

A gate for `writer_gate_kernel!` in page-locked host memory the device maps: `cell`, the host
`Vector` holding `WRITER_HOLD` until released, and `counter`, the host `Vector` the kernel
counts its iterations into; `device` and `spins`, the `CuArray`s over the same memory;
`ceiling`, the iterations after which the kernel ends unreleased; and `point`, the handoff
recorded after the kernel while one is queued over the gate.
"""
mutable struct WriterGate
    cell::Vector{Float64}
    counter::Vector{Float64}
    device::CuArray{Float64,1,CUDA.HostMemory}
    spins::CuArray{Float64,1,CUDA.HostMemory}
    ceiling::Float64
    point::Union{Nothing,Backends.Handoff}
end

"The gates with a kernel queued over them."
const WRITER_LIVE_GATES = WriterGate[]

"The lock `WRITER_LIVE_GATES` is read and written under."
const WRITER_GATES_LOCK = ReentrantLock()

"""
    writer_release!(g)

Writes `0.0` into `g.cell`. When a kernel is queued over `g`, waits for it with a blocking
wait on `g.point`'s event, which reads no kernel-exception flag, and removes `g` from
`WRITER_LIVE_GATES`.
"""
function writer_release!(g::WriterGate)
    g.cell[1] = 0.0
    point = g.point
    if point !== nothing
        CUDA.synchronize(point.event; blocking = true)
        g.point = nothing
        @lock WRITER_GATES_LOCK filter!(x -> x !== g, WRITER_LIVE_GATES)
    end
    return nothing
end

"Releases every gate in `WRITER_LIVE_GATES` through `writer_release!`."
writer_release_all() = foreach(writer_release!, @lock WRITER_GATES_LOCK copy(WRITER_LIVE_GATES))

# At process exit, SIGTERM included, every gate with a kernel queued over it is released and
# its kernel waited for, ahead of the exit hooks of the packages loaded before this file.
atexit(writer_release_all)

@kernel function writer_copy_kernel!(out, @Const(src))
    i = @index(Global)
    out[i] = src[i]
end

@kernel function writer_fault_kernel!(out, offset)
    i = @index(Global)
    out[i + offset] = one(eltype(out))
end

"""
    writer_gate(gpu, ceiling)

A `WriterGate` holding `WRITER_HOLD`, its counter at zero and its ceiling `ceiling`, the two
host vectors registered device-mapped through `unsafe_wrap(CuArray{Float64,1,CUDA.HostMemory}, ...)`.
"""
function writer_gate(gpu, ceiling)
    cell = [WRITER_HOLD]
    counter = [0.0]
    return WriterGate(cell, counter, unsafe_wrap(CuArray{Float64,1,CUDA.HostMemory}, cell),
                      unsafe_wrap(CuArray{Float64,1,CUDA.HostMemory}, counter), ceiling, nothing)
end

"""
    writer_hold(f, gpu, g)

Queues `writer_gate_kernel!` over the `WriterGate` `g` on this task's stream, behind every
kernel this task has queued, records the handoff after it in `g.point`, adds `g` to
`WRITER_LIVE_GATES`, and calls `f(point)`. In a `finally`, `writer_release!(g)`. Returns
`(value, reached)`: what `f` returned, and whether the kernel counted up to its ceiling.
"""
function writer_hold(f, gpu, g::WriterGate)
    Backends.launch!(writer_gate_kernel!, gpu, 1, g.spins, g.device, WRITER_HOLD, g.ceiling)
    g.point = Backends.handoff(gpu)
    @lock WRITER_GATES_LOCK push!(WRITER_LIVE_GATES, g)
    value = try
        f(g.point)
    finally
        writer_release!(g)
    end
    return value, g.counter[1] >= g.ceiling
end

"""
    writer_warm(gpu, shape)

The iteration ceiling a gate kernel is given: `WRITER_GATE_SECONDS` times the iterations per
second an unreleased `writer_gate_kernel!` counts on `gpu`, timed from its launch until its
event completes at the ceiling `WRITER_GATE_PROBE`, after one released launch has compiled it.
Refuses a probe whose counter ends below that ceiling. Also launches and completes, in range,
`writer_copy_kernel!` over device matrices of size `shape` and `writer_fault_kernel!` over
four work items, so no kernel a held interval launches is compiled while a gate holds the card.
"""
function writer_warm(gpu, shape)
    probe = writer_gate(gpu, WRITER_GATE_PROBE)
    probe.cell[1] = 0.0
    writer_hold(_ -> nothing, gpu, probe)
    probe.cell[1] = WRITER_HOLD
    probe.counter[1] = 0.0
    seconds = @elapsed writer_hold(point -> CUDA.synchronize(point.event; blocking = true), gpu, probe)
    probe.counter[1] >= WRITER_GATE_PROBE ||
        error("the unreleased probe gate kernel counted $(probe.counter[1]) of its $(WRITER_GATE_PROBE) iterations")
    out = Backends.on(zeros(shape...), gpu)
    Backends.launch!(writer_copy_kernel!, gpu, length(out), out, Backends.on(ones(shape...), gpu))
    Backends.launch!(writer_fault_kernel!, gpu, 4, Backends.on(zeros(4), gpu), 0)
    Backends.complete!(gpu)
    return WRITER_GATE_SECONDS * WRITER_GATE_PROBE / seconds
end

"""
    writer_await(writer, indices)

The indices among `indices` that `writer`'s disk stage has not finished, waiting on the
writer's condition until it has finished all of them or `WRITER_BOUND` seconds have passed.
"""
function writer_await(w, indices)
    deadline = time() + WRITER_BOUND
    timer = Timer(_ -> (@lock w.lock notify(w.condition)), WRITER_BOUND; interval = 1.0)
    try
        return @lock w.lock begin
            while !all(in(w.finished), indices) && time() < deadline
                wait(w.condition)
            end
            [i for i in indices if !(i in w.finished)]
        end
    finally
        close(timer)
    end
end

@testset "provenance.pooled_write_is_reference" begin
    for backend in writer_backends()
        @testset "on $(writer_name(backend))" begin
            backend isa Backends.GPU && @test CUDA.functional()
            mktempdir() do dir
                run = Provenance.mint_run_id()
                pooled, _, m = ST.seeded(joinpath(dir, "pooled"); run = run)
                reference, _, _ = ST.seeded(joinpath(dir, "reference"); run = run)
                w = Provenance.open_writer(pooled; run = run,
                                           profile = ST.profile(write_ceiling = 1_000_000, store_writers = 2))
                cases = writer_cases(m.support, run, backend)
                keys = map(enumerate(cases)) do (op, case)
                    k, s = ST.submit(w, run, case.field; writer_rest(case, op)...)
                    kr, sr = ST.put(reference, run, case.field; writer_rest(case, op)...)
                    @test k == kr
                    @test Fields.origin(s) == Fields.origin(sr)
                    k
                end
                @test all(k -> !ispath(Provenance.object_directory(pooled, k)), keys)
                Provenance.drain!(w)
                @test Provenance.outcomes(w) == fill(:committed, length(cases))
                @test isempty(ST.staging_left(pooled.root))
                @test ST.tree(pooled.root) == ST.tree(reference.root)

                backend isa Backends.CPU && @testset "positive control: two chunks under each other's keys differ, and decoded totals agree" begin
                    copied = joinpath(dir, "swapped")
                    cp(pooled.root, copied)
                    store = Provenance.Store(root = copied)
                    array = ST.array_path(store, keys[3])
                    @test read(joinpath(array, "0")) != read(joinpath(array, "1"))
                    mv(joinpath(array, "0"), joinpath(array, "swap"))
                    mv(joinpath(array, "1"), joinpath(array, "0"))
                    mv(joinpath(array, "swap"), joinpath(array, "1"))
                    @test ST.tree(copied) != ST.tree(reference.root)
                    @test sum(Fields.data(ST.read_back(store, keys[3], m.support))) ==
                          sum(Fields.data(cases[3].field))
                end

                backend isa Backends.CPU && @testset "positive control: chunks at another level differ in their chunks alone" begin
                    copied = joinpath(dir, "rechunked")
                    cp(pooled.root, copied)
                    store = Provenance.Store(root = copied)
                    array = ST.array_path(store, keys[1])
                    attributes = Provenance.array_attributes(support = m.support, semantics = Fields.Extensive(),
                                                             time = ST.interval(), dimension = Dimensions.MASS,
                                                             owner = :surface)
                    rm(array; recursive = true)
                    Provenance.write_array!(array, Fields.data(cases[1].field), attributes,
                                            Provenance.cells_per_chunk(ST.level(), 0))
                    @test ST.tree(copied) != ST.tree(reference.root)
                    @test read(joinpath(array, ".zattrs")) ==
                          read(joinpath(ST.array_path(reference, keys[1]), ".zattrs"))
                end
            end
        end
    end

    # The writer's lock is held from before submit! until the overwrite is made or queued:
    # the encode stage reads whether an earlier submission is refused under that lock before
    # it reads anything of a submission, so no stage reads the submission before the overwrite.
    for backend in writer_backends()
        @testset "an array overwritten after submit! returns is stored as it was at submission, on $(writer_name(backend))" begin
            backend isa Backends.GPU && @test CUDA.functional()
            mktempdir() do dir
                run = Provenance.mint_run_id()
                pooled, _, m = ST.seeded(joinpath(dir, "pooled"); run = run)
                reference, _, _ = ST.seeded(joinpath(dir, "reference"); run = run)
                overwritten, _, _ = ST.seeded(joinpath(dir, "overwritten"); run = run)
                original = writer_pattern(Float64, (WRITER_CELLS,), 40)
                data = Backends.on(copy(original), backend)
                w = Provenance.open_writer(pooled; run = run, profile = ST.profile(write_ceiling = 1_000_000, store_writers = 1))
                lock(w.lock)
                try
                    ST.submit(w, run, ST.field(m.support, run, data))
                    fill!(data, 0.0)
                finally
                    unlock(w.lock)
                end
                Provenance.drain!(w)
                ST.put(reference, run, ST.field(m.support, run, original))
                @test ST.tree(pooled.root) == ST.tree(reference.root)

                @testset "positive control: the array holds the overwrite, and its values store another tree" begin
                    @test Backends.on(data, Backends.CPU()) == zeros(WRITER_CELLS)
                    ST.put(overwritten, run, ST.field(m.support, run, data))
                    @test ST.tree(overwritten.root) != ST.tree(reference.root)
                end
            end
        end
    end
end

"""
    writer_order_fields(support, run, backend; small = backend)

The fields the order arms submit, each as `(field, chunk_level)`: a two-axis `Float64`
field of `WRITER_BIG_COLUMNS` columns with its data on `backend` first, then six one-axis
fields with their data on `small`.
"""
writer_order_fields(support, run, backend; small = backend) = vcat(
    [(field = ST.field(support, run, Backends.on(writer_pattern(Float64, (WRITER_CELLS, WRITER_BIG_COLUMNS), 100), backend)),
      chunk_level = 0)],
    [(field = ST.field(support, run, Backends.on(writer_pattern(Float64, (WRITER_CELLS,), 100 + i), small)),
      chunk_level = 1) for i in 1:6])

"The profile the order arms open their writers under, with `writers` disk tasks."
writer_order_profile(writers) = ST.profile(write_ceiling = 64_000_000, store_writers = writers)

@testset "provenance.write_order_independent" begin
    @testset "the finish-order check fails on a record with no later submission first" begin
        @test !writer_inverted([1, 2, 3, 4])
        @test writer_inverted([1, 3, 2, 4])
    end

    for backend in writer_backends()
        @testset "on $(writer_name(backend))" begin
            backend isa Backends.GPU && @test CUDA.functional()
            mktempdir() do dir
                run = Provenance.mint_run_id()
                reference, _, m = ST.seeded(joinpath(dir, "reference"); run = run)
                fields = writer_order_fields(m.support, run, backend; small = Backends.CPU())
                for (op, f) in enumerate(fields)
                    ST.put(reference, run, f.field; operator_version = op, chunk_level = f.chunk_level)
                end

                for writers in (1, 4)
                    @testset "store_writers = $(writers)" begin
                        pooled, _, _ = ST.seeded(joinpath(dir, "pooled$(writers)"); run = run)
                        w = Provenance.open_writer(pooled; run = run, profile = writer_order_profile(writers))
                        for (op, f) in enumerate(fields)
                            ST.submit(w, run, f.field; operator_version = op, chunk_level = f.chunk_level)
                        end
                        Provenance.drain!(w)
                        @test ST.tree(pooled.root) == ST.tree(reference.root)
                        @test Provenance.outcomes(w) == fill(:committed, length(fields))
                        @test sort(Provenance.finish_order(w)) == collect(1:length(fields))
                    end
                end
            end

            @testset "a rename collided after submission stores exactly the earlier submissions" begin
                mktempdir() do dir
                    run = Provenance.mint_run_id()
                    store, _, m = ST.seeded(dir; run = run)
                    fields = writer_order_fields(m.support, run, backend)
                    w = Provenance.open_writer(store; run = run, profile = writer_order_profile(1))
                    submit(op, i) = first(ST.submit(w, run, fields[i].field; operator_version = op,
                                                    chunk_level = fields[i].chunk_level))
                    k1 = submit(1, 2)
                    k2 = submit(2, 1)
                    mkpath(Provenance.object_directory(store, k2))
                    k3 = submit(3, 3)
                    k4 = submit(4, 4)
                    e = ST.caught(() -> Provenance.settle!(w))
                    @test ST.refused(e, "surface_mass", "submission 2 of surface_mass under key $(bytes2hex(collect(k2.digest)))")
                    @test e isa Verdicts.Refusal && occursin("was written while this write was staged", e.reason)
                    @test e isa Verdicts.Refusal && occursin("; 2 later submissions discarded", e.reason)
                    @test Provenance.outcomes(w) == [:committed, :refused, :discarded, :discarded]
                    @test isfile(writer_manifest(store, k1))
                    @test isempty(readdir(Provenance.object_directory(store, k2)))
                    @test !ispath(Provenance.object_directory(store, k3))
                    @test !ispath(Provenance.object_directory(store, k4))
                    @test isempty(ST.staging_left(store.root))

                    @testset "a later submission is copied and not refused, and nothing is raised again" begin
                        before = get(Events.move_counts(), (:gpu, :cpu), 0)
                        k5 = submit(5, 5)
                        copies = get(Events.move_counts(), (:gpu, :cpu), 0) - before
                        @test copies == (backend isa Backends.GPU ? 1 : 0)
                        @test ST.caught(() -> Provenance.settle!(w)) === nothing
                        @test ST.caught(() -> Provenance.drain!(w)) === nothing
                        @test Provenance.outcomes(w)[5] === :discarded
                        @test !ispath(Provenance.object_directory(store, k5))
                        @test isempty(ST.staging_left(store.root))
                    end
                end
            end

            @testset "a cell id outside its level, before a collided rename, stores exactly the earlier submissions" begin
                mktempdir() do dir
                    run = Provenance.mint_run_id()
                    store, _, m = ST.seeded(dir; run = run)
                    up = Provenance.CellIds(level = ST.level() - 1)
                    good(seed) = [Mesh.parent(mod1(i * seed, WRITER_CELLS)) for i in 1:WRITER_CELLS]
                    bad = [mod1(i, Mesh.ncells(ST.level() - 1)) for i in 1:WRITER_CELLS, _ in 1:WRITER_BIG_COLUMNS]
                    bad[7] = Mesh.ncells(ST.level() - 1) + 1
                    w = Provenance.open_writer(store; run = run, profile = writer_order_profile(2))
                    submit(op, data) = first(ST.submit(w, run, nothing; operator_version = op, chunk_level = 1,
                        writer_cell_keywords(m.support, run, Backends.on(data, backend), up)...))
                    k1 = submit(1, good(1))
                    k2 = submit(2, bad)
                    k3 = submit(3, good(3))
                    mkpath(Provenance.object_directory(store, k3))
                    k4 = submit(4, good(5))
                    e = ST.caught(() -> Provenance.settle!(w))
                    @test ST.refused(e, "parent_cell", "submission 2 of parent_cell under key $(bytes2hex(collect(k2.digest)))")
                    @test e isa Verdicts.Refusal && occursin("values at Provenance.submit!: entry 7", e.reason)
                    @test e isa Verdicts.Refusal && occursin("; 2 later submissions discarded", e.reason)
                    @test Provenance.outcomes(w) == [:committed, :refused, :discarded, :discarded]
                    @test isfile(writer_manifest(store, k1))
                    @test !ispath(Provenance.object_directory(store, k2))
                    @test isempty(readdir(Provenance.object_directory(store, k3)))
                    @test !ispath(Provenance.object_directory(store, k4))
                    @test isempty(ST.staging_left(store.root))
                    @test ST.caught(() -> Provenance.drain!(w)) === nothing
                end
            end
        end
    end
end

"""
    writer_require_threads()

Raises, naming the held arms of `provenance.write_order_independent`, when the default thread
pool runs fewer than two threads: the held submission occupies one encode task, and the later
submissions need another.
"""
writer_require_threads() = Threads.nthreads(:default) >= 2 || error(
    "the held arms of provenance.write_order_independent need at least two default threads, " *
    "and this process runs $(Threads.nthreads(:default)); start julia with -t 2 or more")

"The key of the artifact `ST.submit` names first, from the `(key, stamped)` it returns."
writer_key(returned) = first(returned)

# The gate kernel holds this task's stream until the test writes the gate cell, and every
# later submission is a host field, whose stages launch no kernel and wait on no stream.
@testset "provenance.write_order_independent, held on the card" begin
    @test CUDA.functional()
    writer_require_threads()
    gpu = Backends.GPU()
    ceiling = writer_warm(gpu, (WRITER_CELLS, WRITER_BIG_COLUMNS))
    for writers in (1, 2, 4)
        @testset "store_writers = $(writers): the first submission held until every later one has finished" begin
            mktempdir() do dir
                run = Provenance.mint_run_id()
                reference, _, m = ST.seeded(joinpath(dir, "reference"); run = run)
                pooled, _, _ = ST.seeded(joinpath(dir, "pooled"); run = run)
                fields = writer_order_fields(m.support, run, Backends.CPU())
                for (op, f) in enumerate(fields)
                    ST.put(reference, run, f.field; operator_version = op, chunk_level = f.chunk_level)
                end
                w = Provenance.open_writer(pooled; run = run, profile = writer_order_profile(writers))
                gate = writer_gate(gpu, ceiling)
                source = Fields.data(fields[1].field)
                big = Backends.on(zeros(size(source)...), gpu)
                Backends.launch!(writer_copy_kernel!, gpu, length(big), big, Backends.on(source, gpu))
                keys = []
                missing, reached = writer_hold(gpu, gate) do point
                    push!(keys, writer_key(ST.submit(w, run, ST.field(m.support, run, big); operator_version = 1,
                                                     chunk_level = fields[1].chunk_level)))
                    for op in 2:length(fields)
                        push!(keys, writer_key(ST.submit(w, run, fields[op].field; operator_version = op,
                                                         chunk_level = fields[op].chunk_level)))
                    end
                    unfinished = writer_await(w, 2:length(fields))
                    @test isempty(unfinished)
                    @test !CUDA.isdone(point.event)
                    @test !(1 in Provenance.finish_order(w))
                    @test all(k -> !ispath(Provenance.object_directory(pooled, k)), keys)
                    unfinished
                end
                @test !reached
                if isempty(missing)
                    Provenance.drain!(w)
                    @test Provenance.outcomes(w) == fill(:committed, length(fields))
                    @test last(Provenance.finish_order(w)) == 1
                    @test writer_inverted(Provenance.finish_order(w))
                    @test ST.tree(pooled.root) == ST.tree(reference.root)
                    @test isempty(ST.staging_left(pooled.root))
                end
            end
        end
    end
end

@testset "provenance.write_order_independent, a late refusal held on the card" begin
    @test CUDA.functional()
    writer_require_threads()
    gpu = Backends.GPU()
    ceiling = writer_warm(gpu, (WRITER_CELLS, WRITER_BIG_COLUMNS))
    for offset in (4, 0)
        @testset "the held second submission's fault kernel writing at offset $(offset)" begin
            mktempdir() do dir
                run = Provenance.mint_run_id()
                store, _, m = ST.seeded(dir; run = run)
                fields = writer_order_fields(m.support, run, Backends.CPU())
                w = Provenance.open_writer(store; run = run, profile = writer_order_profile(2))
                keys = [writer_key(ST.submit(w, run, fields[2].field; operator_version = 1,
                                             chunk_level = fields[2].chunk_level))]
                gate = writer_gate(gpu, ceiling)
                source = Fields.data(fields[1].field)
                big = Backends.on(zeros(size(source)...), gpu)
                Backends.launch!(writer_copy_kernel!, gpu, length(big), big, Backends.on(source, gpu))
                Backends.launch!(writer_fault_kernel!, gpu, 4, Backends.on(zeros(4), gpu), offset)
                missing, reached = writer_hold(gpu, gate) do point
                    push!(keys, writer_key(ST.submit(w, run, ST.field(m.support, run, big); operator_version = 2,
                                                     chunk_level = fields[1].chunk_level)))
                    for op in 3:length(fields)
                        push!(keys, writer_key(ST.submit(w, run, fields[op].field; operator_version = op,
                                                         chunk_level = fields[op].chunk_level)))
                    end
                    unfinished = writer_await(w, [1; 3:length(fields)])
                    @test isempty(unfinished)
                    @test !CUDA.isdone(point.event)
                    @test !(2 in Provenance.finish_order(w))
                    @test all(k -> !ispath(Provenance.object_directory(store, k)), keys)
                    unfinished
                end
                @test !reached
                if isempty(missing)
                    e = ST.caught(() -> Provenance.settle!(w))
                    later = length(fields) - 2
                    if offset > 0
                        @test ST.refused(e, "surface_mass",
                                         "submission 2 of surface_mass under key $(bytes2hex(collect(keys[2].digest)))")
                        @test e isa Verdicts.Refusal && occursin("kernel completion at Backends.complete!: KernelException", e.reason)
                        @test e isa Verdicts.Refusal && occursin("writer_fault_kernel!", e.reason)
                        @test e isa Verdicts.Refusal && occursin("; $(later) later submissions discarded", e.reason)
                        @test Provenance.outcomes(w) == [:committed; :refused; fill(:discarded, later)]
                        @test isfile(writer_manifest(store, keys[1]))
                        @test all(k -> !ispath(Provenance.object_directory(store, k)), keys[2:end])
                    else
                        @test e === nothing
                        @test Provenance.outcomes(w) == fill(:committed, length(fields))
                        @test all(k -> isfile(writer_manifest(store, k)), keys)
                    end
                    @test isempty(ST.staging_left(store.root))
                    @test ST.caught(() -> Provenance.drain!(w)) === nothing
                end
            end
        end
    end
end

@testset "provenance.write_ceiling_held" begin
    for backend in writer_backends()
        @testset "on $(writer_name(backend))" begin
            backend isa Backends.GPU && @test CUDA.functional()

            @testset "a burst above the ceiling holds neither the pool nor the host buffers above it" begin
                mktempdir() do dir
                    run = Provenance.mint_run_id()
                    store, _, m = ST.seeded(dir; run = run)
                    ceiling = 2_000_000
                    up = Provenance.CellIds(level = ST.level() - 1)
                    w = Provenance.open_writer(store; run = run, profile = ST.profile(write_ceiling = ceiling, store_writers = 1))
                    for op in 1:24
                        if isodd(op)
                            data = Backends.on(writer_pattern(UInt64, (WRITER_CELLS, 64), 200 + op), backend)
                            ST.submit(w, run, ST.field(m.support, run, data); operator_version = op)
                        else
                            ids = [mod1(i + op, Mesh.ncells(ST.level() - 1)) for i in 1:WRITER_CELLS, _ in 1:64]
                            ST.submit(w, run, nothing; operator_version = op, chunk_level = 1,
                                      writer_cell_keywords(m.support, run, Backends.on(ids, backend), up)...)
                        end
                    end
                    Provenance.drain!(w)
                    charges = Provenance.submitted_charges(w)
                    parts = Provenance.charge_parts(w)
                    peaks = Provenance.submission_peaks(w)
                    @test sum(charges) > 4 * ceiling
                    @test maximum(charges) <= ceiling
                    @test Provenance.pool_high_water(w) <= ceiling
                    @test Provenance.host_high_water(w) <= ceiling
                    @test Provenance.host_high_water(w) > 0
                    @test Provenance.pool_held(w) == 0
                    @test Provenance.outcomes(w) == fill(:committed, 24)

                    @testset "every submission's host buffers held at once stay within its own charge" begin
                        @test all(peaks .<= charges)
                        @test all(p -> p.buffer > 0, parts)
                        @test all(isodd(i) ? parts[i].translated == 0 : parts[i].translated == parts[i].host
                                  for i in eachindex(parts))
                    end

                    # The odd submissions hold UInt64 bits of the mixing formula, whose chunks
                    # compress to their bytes plus the Blosc header, so the chunk buffer is held
                    # beside compressed chunks of their worst-case size.
                    @testset "positive control: a charge leaving out the translated array or the chunk buffer is exceeded" begin
                        @test all(peaks[i] > charges[i] - parts[i].translated for i in eachindex(parts) if iseven(i))
                        @test all(peaks[i] > charges[i] - parts[i].buffer for i in eachindex(parts) if isodd(i))
                    end
                end
            end

            @testset "a charge above the ceiling refuses at once, naming both counts, with nothing charged or allocated" begin
                mktempdir() do dir
                    run = Provenance.mint_run_id()
                    store, _, m = ST.seeded(dir; run = run)
                    f = ST.field(m.support, run, Backends.on(writer_pattern(Float64, (WRITER_CELLS, 64), 300), backend))
                    opened = Channel{Any}(1)
                    result = Channel{Any}(1)
                    proceed = Channel{Bool}(1)
                    task = @async begin
                        w = Provenance.open_writer(store; run = run,
                                                   profile = ST.profile(write_ceiling = 100_000, store_writers = 1))
                        put!(opened, w)
                        put!(result, ST.caught(() -> ST.submit(w, run, f)))
                        take!(proceed)
                        ST.caught(() -> Provenance.drain!(w))
                    end
                    w = take!(opened)
                    yield()
                    @test isready(result)
                    isready(result) || Backends.close_pool!(w.pool)
                    e = take!(result)
                    @test ST.refused(e, "charge", "exceeds ceiling of 100000 bytes")
                    counted = e isa Verdicts.Refusal ? match(r"charge of (\d+) bytes", e.reason) : nothing
                    @test counted !== nothing && parse(Int, counted.captures[1]) > 100_000
                    @test isempty(Provenance.submitted_charges(w))
                    @test Provenance.host_high_water(w) == 0
                    @test Provenance.pool_held(w) == 0
                    put!(proceed, true)
                    @test fetch(task) === nothing
                    @test !isdir(joinpath(store.root, Provenance.OBJECTS))
                end
            end
        end
    end
end

@testset "a writer with no submissions settles and drains at once" begin
    mktempdir() do dir
        store, run, _ = ST.seeded(dir)
        opened = Channel{Any}(1)
        settled = Channel{Any}(1)
        proceed = Channel{Bool}(1)
        task = @async begin
            w = Provenance.open_writer(store; run = run, profile = ST.profile())
            put!(opened, w)
            put!(settled, ST.caught(() -> Provenance.settle!(w)))
            take!(proceed)
            ST.caught(() -> Provenance.drain!(w))
        end
        w = take!(opened)
        yield()
        @test isready(settled)
        if isready(settled)
            @test take!(settled) === nothing
            put!(proceed, true)
            @test fetch(task) === nothing
            @test isempty(Provenance.outcomes(w))
        end
    end
end

@testset "each admission refusal of the store's oracles refuses at submit! before it returns" begin
    mktempdir() do root
        store, run, m = ST.seeded(root)
        data = collect(range(1.0, 2.0; length = WRITER_CELLS))
        f = ST.field(m.support, run, data)
        _, stamped = ST.put(store, run, f; operator_version = 1)
        w = Provenance.open_writer(store; run = run, profile = ST.profile(write_ceiling = 1_000_000, store_writers = 1))
        given = ST.put_keywords(f, (operator_version = 60,))
        dirty = ST.code(dirty = true)
        drun = Provenance.mint_run_id()
        Provenance.open_run!(store; run = drun, code = dirty, system = ST.SF.system())
        unrecorded = Provenance.mint_run_id()
        elsewhere = ST.mesh(; r = 2 * ST.radius())
        cell_level = Provenance.CellIds(level = ST.level() - 1)
        refusals = [
            ("artifact", "already holds", () -> ST.submit(w, run, f; operator_version = 1)),
            ("mass", "is open", () -> ST.submit(w, run, f; operator_version = 2, ledgers = (writer_ledger(:mass, 6.0),))),
            ("water", "class :liquid", () -> ST.submit(w, run, f; operator_version = 2, ledgers = (
                Fields.ClassLedgers{:water}((:ice, :liquid), (writer_ledger(:water, 5.0), writer_ledger(:water, 6.0))),))),
            ("energy", "column (2,)", () -> ST.submit(w, run, f; operator_version = 2, ledgers = (
                Fields.ColumnLedgers{:energy}([writer_ledger(:energy, 5.0), writer_ledger(:energy, 6.0)]),))),
            ("surface_mass", "as Extensive",
             () -> ST.submit(w, run, ST.field(m.support, run, data; semantics = Fields.Intensive()); operator_version = 3)),
            ("owner", "elsewhere", () -> ST.submit(w, run, ST.field(m.support, run, data; writer = :elsewhere); operator_version = 3)),
            ("origin", "stamped", () -> ST.submit(w, run, stamped; operator_version = 3)),
            ("ledgers", "tuple", () -> ST.submit(w, run, f; operator_version = 3, ledgers = ST.closed_ledger())),
            ("profile", "missing", () -> Provenance.submit!(w, run; Base.structdiff(given, NamedTuple{(:profile,)})...)),
            ("interval", "missing", () -> Provenance.submit!(w, run; Base.structdiff(given, NamedTuple{(:interval,)})...)),
            ("interval", "IntervalMean", () -> ST.submit(w, run, f; operator_version = 4, interval = Time.Interval(0.0, 7200.0))),
            ("interval", "IntervalMean", () -> ST.submit(w, run, f; operator_version = 4, interval = Time.Interval(0.0f0, 3600.0f0))),
            ("chunk_level", "level $(ST.level() + 1)", () -> ST.submit(w, run, f; operator_version = 5, chunk_level = ST.level() + 1)),
            ("code version", "uncommitted", () -> ST.submit(w, drun, ST.field(m.support, drun, data); code = dirty)),
            ("run", "records no run", () -> ST.submit(w, unrecorded, ST.field(m.support, unrecorded, data); operator_version = 6)),
            ("support", "holds no support", () -> ST.submit(w, run, ST.field(elsewhere.support, run, data); operator_version = 6)),
            ("values", "integers", () -> ST.submit(w, run, nothing; operator_version = 7,
                writer_cell_keywords(m.support, run, Float64.(1:WRITER_CELLS), cell_level)...)),
        ]
        for (quantity, text, call) in refusals
            @testset "$(quantity): $(text)" begin
                @test ST.refused(ST.caught(call), quantity, text)
                @test isempty(Provenance.submitted_charges(w))
                @test Provenance.pool_held(w) == 0
            end
        end

        @testset "positive control: the same field under a fresh key is admitted under put_field!'s key" begin
            mktempdir() do other
                side, _, _ = ST.seeded(other; run = run)
                k, _ = ST.submit(w, run, f; operator_version = 60)
                @test k == first(ST.put(side, run, f; operator_version = 60))
                @test length(Provenance.submitted_charges(w)) == 1
            end
        end

        @testset "the writer refuses a key it was handed, another task, another run, and a submission after drain!" begin
            @test ST.refused(ST.caught(() -> ST.submit(w, run, f; operator_version = 60)), "artifact", "was handed")
            other_task = fetch(@async ST.caught(() -> ST.submit(w, run, f; operator_version = 61)))
            @test ST.refused(other_task, "task", "opened by another task")
            @test ST.refused(ST.caught(() -> ST.submit(w, drun, ST.field(m.support, drun, data); code = dirty,
                                                       operator_version = 62)),
                             "code version", "uncommitted")
            second = Provenance.mint_run_id()
            Provenance.open_run!(store; run = second, code = ST.code(), system = ST.SF.system())
            @test ST.refused(ST.caught(() -> ST.submit(w, second, ST.field(m.support, second, data); operator_version = 63)),
                             "run", "writes run")
            other_settle = fetch(@async ST.caught(() -> Provenance.settle!(w)))
            @test ST.refused(other_settle, "task", "Provenance.settle!")
            @test length(Provenance.submitted_charges(w)) == 1
            Provenance.drain!(w)
            @test Provenance.outcomes(w) == [:committed]
            @test ST.refused(ST.caught(() -> ST.submit(w, run, f; operator_version = 64)), "writer", "drain! began")
        end

        @testset "a scratch run under a dirty code version submits and reads back" begin
            wd = Provenance.open_writer(store; run = drun, profile = ST.profile(write_ceiling = 1_000_000, store_writers = 1))
            scratch = Provenance.ScratchRun(run = drun, code = dirty)
            fd = ST.field(m.support, drun, data)
            kw = Base.structdiff(ST.put_keywords(fd, (;)), NamedTuple{(:code,)})
            skey, sfield = Provenance.submit!(wd, scratch; kw...)
            Provenance.drain!(wd)
            @test Provenance.read_field(store, scratch, skey; quantity = :surface_mass, semantics = Fields.Extensive(),
                                        dimension = Dimensions.MASS, time = ST.interval(), support = m.support,
                                        backend = Backends.CPU()) == sfield
        end
    end
end

"The project the fault arms start their processes in."
const WRITER_PROJECT = normpath(joinpath(@__DIR__, "..", ".."))

"""
    writer_fault_run(offset)

The output of a process in which a writer's opener submits a host field, queues a kernel
writing at `out[i + offset]` over the cells of a device array `out`, submits a field over
`out`, submits a second host field, and calls `settle!` and then `drain!`, printing what each
raised, which of the three artifacts are stored, how many staging directories are left,
and whether the stored device field reads back as ones. `offset` of zero is in range and
the cell count is not.
"""
function writer_fault_run(offset::Integer)
    fixtures = normpath(joinpath(@__DIR__, "..", "io", "store_fixtures.jl"))
    code = """
        using CUDA
        using KernelAbstractions: @kernel, @index
        using Fiddlybits: Provenance, Backends, Mesh, Fields
        using Fiddlybits.Verdicts: Refusal
        include(raw"$(fixtures)")
        import .StoreFixtures as ST

        @kernel function writer_fault_kernel!(out, offset)
            i = @index(Global)
            out[i + offset] = 1.0
        end

        mktempdir() do root
            store, run, m = ST.seeded(root)
            n = Mesh.ncells(ST.level())
            gpu = Backends.GPU()
            out = Backends.on(zeros(n), gpu)
            Backends.complete!(gpu)
            w = Provenance.open_writer(store; run = run, profile = ST.profile(write_ceiling = 1_000_000, store_writers = 1))
            k1, _ = ST.submit(w, run, ST.field(m.support, run, fill(1.0, n)); operator_version = 1)
            Backends.launch!(writer_fault_kernel!, gpu, n, out, $(Int(offset)))
            k2, _ = ST.submit(w, run, ST.field(m.support, run, out); operator_version = 2)
            k3, _ = ST.submit(w, run, ST.field(m.support, run, fill(3.0, n)); operator_version = 3)
            println("SUBMITTED")
            try
                Provenance.settle!(w)
                println("SETTLED WITHOUT REFUSAL")
            catch err
                err isa Refusal || rethrow()
                println("SETTLE REFUSED ", err.quantity, " AT ", err.site, " :: ", err.reason)
            end
            for (name, k) in (("FIRST", k1), ("SECOND", k2), ("THIRD", k3))
                println(name, " STORED ", isfile(joinpath(Provenance.object_directory(store, k), Provenance.MANIFEST)))
            end
            println("STAGING LEFT ", length(ST.staging_left(root)))
            try
                Provenance.drain!(w)
                println("DRAINED WITHOUT REFUSAL")
            catch err
                println("DRAIN RAISED ", sprint(showerror, err))
            end
            if isfile(joinpath(Provenance.object_directory(store, k2), Provenance.MANIFEST))
                println("SECOND READS ONES ", Fields.data(ST.read_back(store, k2, m.support)) == ones(n))
            end
        end
    """
    cmd = `julia --startup-file=no --project=$WRITER_PROJECT -e $code`
    return read(pipeline(ignorestatus(cmd); stderr = devnull), String)
end

@testset "a kernel fault behind a submission's host copy is raised by settle! on the opener, the writes after it discarded" begin
    @test CUDA.functional()
    faulted = writer_fault_run(Mesh.ncells(ST.level()))
    @test occursin("SUBMITTED", faulted)
    @test occursin("SETTLE REFUSED surface_mass AT Provenance.settle! :: submission 2 of surface_mass", faulted)
    @test occursin("kernel completion at Backends.complete!: KernelException", faulted)
    @test occursin("writer_fault_kernel!", faulted)
    @test occursin("; 1 later submissions discarded", faulted)
    @test occursin("FIRST STORED true", faulted)
    @test occursin("SECOND STORED false", faulted)
    @test occursin("THIRD STORED false", faulted)
    @test occursin("STAGING LEFT 0", faulted)
    @test occursin("DRAINED WITHOUT REFUSAL", faulted)

    @testset "control: the same kernel in range settles, and every write is stored" begin
        clean = writer_fault_run(0)
        @test occursin("SETTLED WITHOUT REFUSAL", clean)
        @test !occursin("SETTLE REFUSED", clean)
        @test occursin("FIRST STORED true", clean)
        @test occursin("SECOND STORED true", clean)
        @test occursin("THIRD STORED true", clean)
        @test occursin("STAGING LEFT 0", clean)
        @test occursin("DRAINED WITHOUT REFUSAL", clean)
        @test occursin("SECOND READS ONES true", clean)
    end
end
