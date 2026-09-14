using Test
using CUDA
import KernelAbstractions
using KernelAbstractions: @kernel, @index, @Const
using Fiddlybits
using Fiddlybits: Backends, Reductions, Provenance

# kernels.body_types_concrete, the test docs/imports/cuda.md and
# docs/imports/kernelabstractions.md, section "Dynamic dispatch", name beside
# test/backends/dispatch_refusal.jl. docs/plans/fiddlybits-52v.3-fields.md, section
# "Inference, and what it costs", states what it checks.
#
# Every kernel in BODY_TABLE is launched through its own door on Backends.GPU and
# Backends.CPU at each precision its entry names. The device arm reads the typed code
# of every GPUCompiler job those launches asked for, through that job's own
# interpreter; the CPU arm reads the typed code of every specialization of the CPU
# function at a dispatch tuple. Both fail on a value body_flagged marks.

"The module the static pass is loaded into, for its `component_methods`, `device_kernel` and `within`."
module BodyTypesDriver
include(joinpath(@__DIR__, "..", "fields", "static_pass.jl"))
end

const BodyPass = BodyTypesDriver.StaticPass

"The GPUCompiler module CUDA loaded, for its `compile_hook`, `get_interpreter` and `code_llvm`."
const BODY_GPUCOMPILER =
    Base.loaded_modules[Base.PkgId(Base.UUID("61eb1bfa-7361-4325-ad38-22787b887f55"), "GPUCompiler")]

@isdefined(BackendFixtures) || include(joinpath(@__DIR__, "..", "backends", "fixtures.jl"))

"The floating-point precisions a kernel of this package is launched at."
const BODY_FLOATS = (Float64, Float32)

"""
    body_device_kernels(root)

Every method of module `root` or a module inside it that `StaticPass.device_kernel`
names.
"""
body_device_kernels(root::Module) = filter(BodyPass.device_kernel, BodyPass.component_methods(root))

"""
    body_kernel_method(kernel, dev)

The method of the function the `KernelAbstractions.Kernel` `kernel(dev)` holds in its
`f`, for `dev` a `KernelAbstractions.Backend`: `gpu_<name>` on a device backend and
`cpu_<name>` on `KernelAbstractions.CPU()`. `nothing` when `kernel` has no method for
`dev` or does not return a `Kernel`.
"""
function body_kernel_method(kernel, dev)
    applicable(kernel, dev) || return nothing
    built = kernel(dev)
    built isa KernelAbstractions.Kernel || return nothing
    return only(methods(built.f))
end

body_device_method(kernel) = body_kernel_method(kernel, Backends.ka_backend(Backends.GPU()))
body_cpu_method(kernel) = body_kernel_method(kernel, KernelAbstractions.CPU())

"""
    body_flagged(type)

Whether `type`, a widened inferred type, is one `code_warntype` highlights: not a
dispatch element, or `Core.Box` (InteractiveUtils `warntype_type_printer`).
"""
body_flagged(type) = !Base.isdispatchelem(type) || type == Core.Box

"""
    body_flagged_values(src, nargs)

`(label, type, statement)` for every argument among the first `nargs` slots of the
typed code `src`, and every statement of it that another statement reads and whose type
`Base.IRShow` prints, whose widened type `body_flagged` marks.
"""
function body_flagged_values(src::Core.CodeInfo, nargs::Integer)
    found = Tuple{String,Any,Any}[]
    slottypes = src.slottypes === nothing ? Any[] : src.slottypes
    for i in 1:min(nargs, length(slottypes))
        t = Core.Compiler.widenconst(slottypes[i])
        body_flagged(t) && push!(found, ("argument $(i)", t, src.slotnames[i]))
    end
    used = Base.IRShow.stmts_used(devnull, src)
    for (i, stmt) in enumerate(src.code)
        (i in used && Base.IRShow.should_print_ssa_type(stmt)) || continue
        t = Core.Compiler.widenconst(src.ssavaluetypes[i])
        body_flagged(t) && push!(found, ("%$(i)", t, stmt))
    end
    return found
end

"""
    body_findings(read, mi, root, arm)

One line for every value `body_flagged_values` finds in the typed code `read` returns
for the signature of the method instance `mi`, and in that of every method instance an
`:invoke` in it names whose method is defined in module `root` or a module inside it,
each read once; and one line for each of those signatures `read` returns no inferred
code for. `arm` begins each line.
"""
function body_findings(read, mi::Core.MethodInstance, root::Module, arm::AbstractString)
    found = String[]
    seen = Set{Core.MethodInstance}()
    pending = Core.MethodInstance[mi]
    while !isempty(pending)
        current = pop!(pending)
        current in seen && continue
        push!(seen, current)
        where_read = "$(current.def.module).$(current.def.name) at $(current.specTypes)"
        for (src, _) in read(current.specTypes)
            if !(src isa Core.CodeInfo)
                push!(found, "$(arm): $(where_read) has no inferred code")
                continue
            end
            for (label, t, stmt) in body_flagged_values(src, current.def.nargs)
                push!(found, "$(arm): $(where_read): $(label)::$(t) = $(stmt)")
            end
            for stmt in src.code
                Meta.isexpr(stmt, :invoke) || continue
                target = stmt.args[1]
                callee = target isa Core.CodeInstance ? target.def : target
                (callee isa Core.MethodInstance && callee.def isa Method &&
                 BodyPass.within(callee.def.module, root)) && push!(pending, callee)
            end
        end
    end
    return found
end

"""
    body_launch_jobs(table)

Run the launches of every entry of `table` at each of its precisions, on `Backends.GPU`
and then on `Backends.CPU`, and return one vector per entry holding every
`GPUCompiler.CompilerJob` the device launches of that entry passed to
`GPUCompiler.compile_hook`.
"""
function body_launch_jobs(table)
    jobs = [Any[] for _ in table]
    for (i, entry) in enumerate(table), T in entry.precisions
        Base.ScopedValues.with(BODY_GPUCOMPILER.compile_hook => (job -> push!(jobs[i], job))) do
            entry.launch(Backends.GPU, T)
        end
        entry.launch(Backends.CPU, T)
    end
    return jobs
end

"""
    body_device_findings(jobs, root)

`body_findings` on the device arm for each distinct method instance and cache owner
among `jobs`, each read with `Base.code_typed_by_type` through
`GPUCompiler.get_interpreter` of its job.
"""
function body_device_findings(jobs, root::Module)
    found = String[]
    for job in unique(j -> (j.source, BODY_GPUCOMPILER.cache_owner(j)), jobs)
        interp = BODY_GPUCOMPILER.get_interpreter(job)
        append!(found, body_findings(sig -> Base.code_typed_by_type(sig; interp), job.source,
                                     root, "device"))
    end
    return found
end

"""
    body_cpu_findings(kernel, root)

`body_findings` on the CPU arm, with `Base.code_typed_by_type`, for every
specialization at a dispatch tuple of the method `body_cpu_method(kernel)`. Empty when
`kernel` has no CPU method.
"""
function body_cpu_findings(kernel, root::Module)
    m = body_cpu_method(kernel)
    m === nothing && return String[]
    found = String[]
    for mi in Base.specializations(m)
        Base.isdispatchtuple(mi.specTypes) || continue
        append!(found, body_findings(sig -> Base.code_typed_by_type(sig), mi, root, "cpu"))
    end
    return found
end

"""
    body_table_findings(table, root)

One line for every entry of `table` whose `kernel` has no device method among
`body_device_kernels(root)`.
"""
function body_table_findings(table, root::Module)
    kernels = Set(body_device_kernels(root))
    return ["the table entry $(entry.kernel) names no kernel of $(root)"
            for entry in table if !(body_device_method(entry.kernel) in kernels)]
end

"""
    body_coverage_findings(jobs, root)

One line for every method of `body_device_kernels(root)` that no job among `jobs`
compiled.
"""
function body_coverage_findings(jobs, root::Module)
    compiled = Set(job.source.def for entry_jobs in jobs for job in entry_jobs)
    return ["$(m.module).$(m.name) is a kernel no launch in the test compiled for the device"
            for m in body_device_kernels(root) if !(m in compiled)]
end

"""
    body_entry_findings(table, jobs)

One line for every entry of `table` whose own launches, the jobs at the same position of
`jobs`, did not compile its kernel's device method.
"""
body_entry_findings(table, jobs) =
    ["the launches of $(entry.kernel) did not compile it for the device"
     for (entry, entry_jobs) in zip(table, jobs)
     if !(body_device_method(entry.kernel) in Set(j.source.def for j in entry_jobs))]

"`host` moved to `backend` through `Backends.on`."
body_on(host, backend) = Backends.on(host, backend)

"`n` values of `T` from `BackendFixtures.seeded_vector`, shifted to lie above zero."
body_positive(::Type{T}, n::Integer) where {T} = BackendFixtures.seeded_vector(T, n) .+ T(3)

"The segment starts of `nseg` segments of `seglen` elements each."
body_starts(nseg::Integer, seglen::Integer) = collect(1:seglen:(nseg * seglen + 1))

"The work item count of the launches below that fit under every device-form limit."
const BODY_N = 1024

"The segment count and segment length of the segmented launches."
const BODY_NSEG = 8
const BODY_SEGLEN = 128

function body_axpy(bitwise::Bool)
    return (B, T) -> begin
        b = B(; bitwise = bitwise)
        y = body_on(BackendFixtures.seeded_vector(T, BODY_N), b)
        Backends.axpy!(y, 2, body_on(BackendFixtures.seeded_vector(T, BODY_N), b), b)
        Backends.complete!(b)
    end
end

function body_stencil(bitwise::Bool)
    return (B, T) -> begin
        b = B(; bitwise = bitwise)
        neighbour, weight = BackendFixtures.stencil_tables(T, BODY_N, BackendFixtures.NK)
        out = body_on(zeros(T, BODY_N), b)
        Backends.stencil_gather!(out, body_on(BackendFixtures.seeded_vector(T, BODY_N), b),
                                 body_on(neighbour, b), body_on(weight, b), b)
        Backends.complete!(b)
    end
end

function body_pairwise(n::Integer)
    return (B, T) -> begin
        b = B()
        xs = body_on(BackendFixtures.seeded_vector(T, n), b)
        for A in BODY_FLOATS
            Reductions.pairwise_sum(A, xs, b)
        end
        Backends.complete!(b)
    end
end

function body_pairwise_columns(B, T)
    b = B()
    xs = body_on(reshape(BackendFixtures.seeded_vector(T, 3 * BODY_N), BODY_N, 3), b)
    for A in BODY_FLOATS
        Reductions.pairwise_sum(A, xs, b)
    end
    Backends.complete!(b)
end

function body_quantile(k::Integer)
    return (B, T) -> begin
        b = B()
        seglen = 4^k
        starts = body_on(body_starts(BODY_NSEG, seglen), b)
        xs = BackendFixtures.seeded_vector(T, 2 * BODY_NSEG * seglen)
        Reductions.segmented_quantile(body_on(xs[1:(BODY_NSEG * seglen)], b), starts, 0.5, b)
        Reductions.segmented_quantile(body_on(reshape(xs, BODY_NSEG * seglen, 2), b), starts, 0.5, b)
        Backends.complete!(b)
    end
end

function body_area_weighted(n::Integer)
    return (B, T) -> begin
        b = B()
        xs = body_on(BackendFixtures.seeded_vector(T, n), b)
        areas = body_on(body_positive(T, n), b)
        for A in BODY_FLOATS
            Reductions.area_weighted_sum(A, xs, areas, T(0.5), b)
        end
        Backends.complete!(b)
    end
end

function body_area_fraction(n::Integer)
    return (B, T) -> begin
        b = B()
        Reductions.area_fraction_above(body_on(BackendFixtures.seeded_vector(T, n), b),
                                       body_on(body_positive(T, n), b), T(0.5), b)
        Backends.complete!(b)
    end
end

"""
    body_segmented(reduce)

A launch that calls `reduce(A, xs, weights, segmentation, backend)` for every
accumulator `A` of `BODY_FLOATS`, with `xs` a vector and then a three-column array of
`T`, `weights` a positive vector of `T`, and their `Reductions.Segmentation`.
"""
function body_segmented(reduce)
    return (B, T) -> begin
        b = B()
        n = BODY_NSEG * BODY_SEGLEN
        starts = body_on(body_starts(BODY_NSEG, BODY_SEGLEN), b)
        weights = body_on(body_positive(T, n), b)
        for xs in (body_on(BackendFixtures.seeded_vector(T, n), b),
                   body_on(reshape(BackendFixtures.seeded_vector(T, 3 * n), n, 3), b))
            segmentation = Reductions.Segmentation(xs, starts)
            for A in BODY_FLOATS
                reduce(A, xs, weights, segmentation, b)
            end
        end
        Backends.complete!(b)
    end
end

"""
    body_classes(reduce)

A launch that calls `reduce(A, indicator, weights, segmentation, backend)` for every
accumulator `A` of `BODY_FLOATS`, with `indicator` a `Reductions.ClassIndicator{A}` of
two columns of labels over a legend of three, `weights` a positive vector of `T` and then
its `Reductions.AbsoluteValues`, and their `Reductions.Segmentation`.
"""
function body_classes(reduce)
    return (B, T) -> begin
        b = B()
        n = BODY_NSEG * BODY_SEGLEN
        starts = body_on(body_starts(BODY_NSEG, BODY_SEGLEN), b)
        weights = body_on(body_positive(T, n), b)
        labels = [mod1(3 * i + c, 3) for i in 1:n, c in 1:2]
        for A in BODY_FLOATS
            indicator = Reductions.ClassIndicator{A}(labels, (1, 2, 3), b)
            segmentation = Reductions.Segmentation(indicator, starts)
            for w in (weights, Reductions.AbsoluteValues(weights))
                reduce(A, indicator, w, segmentation, b)
            end
        end
        Backends.complete!(b)
    end
end

function body_philox(B, T)
    b = B()
    out = body_on(Vector{T}(undef, BODY_N), b)
    Provenance.philox_draw!(out, b, 1, ntuple(i -> UInt8(i), 32), 2, 3, 4)
    Backends.complete!(b)
end

"""
    BODY_TABLE

The kernels of the package this test launches: each entry names the kernel, the element
types its launches are made at, and the launch, called as `launch(B, T)` with `B` the
backend type and `T` the element type.
"""
const BODY_TABLE = [
    (kernel = Backends.axpy_fused_kernel!, precisions = BODY_FLOATS, launch = body_axpy(false)),
    (kernel = Backends.axpy_bitwise_kernel!, precisions = BODY_FLOATS, launch = body_axpy(true)),
    (kernel = Backends.stencil_gather_fused_kernel!, precisions = BODY_FLOATS, launch = body_stencil(false)),
    (kernel = Backends.stencil_gather_bitwise_kernel!, precisions = BODY_FLOATS, launch = body_stencil(true)),
    (kernel = Reductions.pairwise_block_kernel!, precisions = BODY_FLOATS,
     launch = body_pairwise(Reductions.PAIRWISE_DEVICE_FORM_MAX + 1)),
    (kernel = Reductions.pairwise_block_shared_kernel!, precisions = BODY_FLOATS, launch = body_pairwise(BODY_N)),
    (kernel = Reductions.pairwise_column_block_kernel!, precisions = BODY_FLOATS, launch = body_pairwise_columns),
    [(kernel = Reductions.quantile_kernel(Val(k)), precisions = BODY_FLOATS, launch = body_quantile(k))
     for k in Reductions.QUANTILE_K_MIN:Reductions.QUANTILE_K_MAX]...,
    (kernel = Reductions.area_weighted_block_kernel!, precisions = BODY_FLOATS,
     launch = body_area_weighted(Reductions.AREA_WEIGHTED_DEVICE_FORM_MAX + 1)),
    (kernel = Reductions.area_weighted_block_shared_kernel!, precisions = BODY_FLOATS,
     launch = body_area_weighted(BODY_N)),
    (kernel = Reductions.area_fraction_block_kernel!, precisions = BODY_FLOATS,
     launch = body_area_fraction(Reductions.AREA_FRACTION_DEVICE_FORM_MAX + 1)),
    (kernel = Reductions.area_fraction_block_shared_kernel!, precisions = BODY_FLOATS,
     launch = body_area_fraction(BODY_N)),
    (kernel = Reductions.segmented_sum_kernel!, precisions = BODY_FLOATS,
     launch = body_segmented((A, xs, w, s, b) -> xs isa AbstractVector && Reductions.segmented_sum(A, xs, s, b))),
    (kernel = Reductions.segmented_weighted_sum_kernel!, precisions = BODY_FLOATS,
     launch = body_segmented((A, xs, w, s, b) -> xs isa AbstractVector && Reductions.segmented_weighted_sum(A, xs, w, s, b))),
    (kernel = Reductions.segmented_mean_kernel!, precisions = BODY_FLOATS,
     launch = body_segmented((A, xs, w, s, b) -> xs isa AbstractVector && Reductions.segmented_mean(A, xs, s, w, b))),
    (kernel = Reductions.segmented_column_sum_kernel!, precisions = BODY_FLOATS,
     launch = body_segmented((A, xs, w, s, b) -> xs isa AbstractMatrix && Reductions.segmented_sum(A, xs, s, b))),
    (kernel = Reductions.segmented_column_weighted_sum_kernel!, precisions = BODY_FLOATS,
     launch = body_segmented((A, xs, w, s, b) -> xs isa AbstractMatrix && Reductions.segmented_weighted_sum(A, xs, w, s, b))),
    (kernel = Reductions.segmented_column_mean_kernel!, precisions = BODY_FLOATS,
     launch = body_segmented((A, xs, w, s, b) -> xs isa AbstractMatrix && Reductions.segmented_mean(A, xs, s, w, b))),
    (kernel = Reductions.segmented_class_weighted_sum_kernel!, precisions = BODY_FLOATS,
     launch = body_classes((A, c, w, s, b) -> Reductions.segmented_weighted_sum(A, c, w, s, b))),
    (kernel = Reductions.segmented_class_mean_kernel!, precisions = BODY_FLOATS,
     launch = body_classes((A, c, w, s, b) -> Reductions.segmented_mean(A, c, s, w, b))),
    (kernel = Provenance.philox_draw_kernel!, precisions = (NTuple{4,UInt64},), launch = body_philox),
]

"""
The module the controls run on, where every answer is known: a kernel calling a
six-member union that inference splits, one holding a boxed variable that a call the
compiler does not inline receives, one whose union call constant propagation folds, one
calling a concrete function, and one no launch compiles.
"""
module BodyTypesFixture

using KernelAbstractions: @kernel, @index, @Const

"A value equal to 2 of one of six concrete types, chosen by `k`."
@noinline union_value(k) =
    k == 1 ? 2.0 : k == 2 ? 2.0f0 : k == 3 ? 2 : k == 4 ? Int32(2) : k == 5 ? Int16(2) : UInt8(2)

"`f`, returned through a call the compiler does not inline."
@noinline kept(f) = f

"2.0, read back through `kept` of a closure over a local assigned after the closure is made, with no call on the value read."
function boxed_value(i)
    get = () -> s
    s = Float64(i) - Float64(i) + 2.0
    v = kept(get)()
    return v isa Float64 ? v : 2.0
end

"2.0, computed from `i` through a call the compiler does not inline."
@noinline concrete_value(i) = Float64(i) - Float64(i) + 2.0

@kernel function split_kernel!(out, @Const(x))
    i = @index(Global)
    out[i] = x[i] * union_value(mod1(i, 6))
end

@kernel function boxed_kernel!(out, @Const(x))
    i = @index(Global)
    out[i] = x[i] * boxed_value(i)
end

@kernel function folded_kernel!(out, @Const(x))
    i = @index(Global)
    out[i] = x[i] * union_value(1)
end

@kernel function concrete_kernel!(out, @Const(x))
    i = @index(Global)
    out[i] = x[i] * concrete_value(i)
end

@kernel function unlaunched_kernel!(out, @Const(x))
    i = @index(Global)
    out[i] = x[i]
end

end # module BodyTypesFixture

"""
    body_fixture_output(kernel, B)

`kernel` of `BodyTypesFixture` launched through `Backends.launch!` on `B()` over
`BODY_FIXTURE_N` work items of `1:BODY_FIXTURE_N`, and the output read back through
`Backends.on`.
"""
function body_fixture_output(kernel, B)
    b = B()
    x = body_on(collect(1.0:BODY_FIXTURE_N), b)
    out = body_on(zeros(Float64, BODY_FIXTURE_N), b)
    Backends.launch!(kernel, b, BODY_FIXTURE_N, out, x)
    Backends.complete!(b)
    return Backends.on(out, Backends.CPU())
end

const BODY_FIXTURE_N = 8

"The launches of the control kernels of `BodyTypesFixture`, in the shape of `BODY_TABLE`."
const BODY_FIXTURE_TABLE = [(kernel = k, precisions = (Float64,), launch = (B, T) -> body_fixture_output(k, B))
                            for k in (BodyTypesFixture.split_kernel!, BodyTypesFixture.boxed_kernel!,
                                      BodyTypesFixture.folded_kernel!, BodyTypesFixture.concrete_kernel!)]

"Whether the device module of `job`, as `GPUCompiler.code_llvm` prints it, calls `gc_pool_alloc`."
body_device_allocates(job) =
    occursin(r"call [^\n]*gc_pool_alloc",
             sprint(io -> BODY_GPUCOMPILER.code_llvm(io, job; dump_module = true)))

@testset "kernels.body_types_concrete: every kernel body is concrete on the device and the CPU backend" begin
    @test CUDA.functional()

    @testset "positive controls on BodyTypesFixture" begin
        root = BodyTypesFixture
        jobs = body_launch_jobs(BODY_FIXTURE_TABLE)
        byname = Dict(nameof(e.kernel) => (e, j) for (e, j) in zip(BODY_FIXTURE_TABLE, jobs))

        @testset "every control kernel compiles on the device and writes the known answer on both backends" begin
            for entry in BODY_FIXTURE_TABLE, B in (Backends.GPU, Backends.CPU)
                @test body_fixture_output(entry.kernel, B) == 2.0 .* collect(1.0:BODY_FIXTURE_N)
            end
        end

        @testset "must fail on both arms: $(name)" for (name, kernel, marker) in (
                ("a six-member union that inference splits", :split_kernel!, "Union{"),
                ("a boxed variable no call reads, surviving optimisation", :boxed_kernel!, "Core.Box"))
            entry, entry_jobs = byname[kernel]
            device = body_device_findings(entry_jobs, root)
            cpu = body_cpu_findings(entry.kernel, root)
            @test !isempty(device) && any(l -> occursin(marker, l), device)
            @test !isempty(cpu) && any(l -> occursin(marker, l), cpu)
        end

        @testset "the surviving box is a device allocation in its device code, and the concrete call's is not" begin
            @test any(body_device_allocates, last(byname[:boxed_kernel!]))
            @test !any(body_device_allocates, last(byname[:concrete_kernel!]))
        end

        @testset "must pass on both arms: $(name)" for (name, kernel) in (
                ("a union that constant propagation folds", :folded_kernel!),
                ("a concrete call", :concrete_kernel!))
            entry, entry_jobs = byname[kernel]
            @test body_device_findings(entry_jobs, root) == String[]
            @test body_cpu_findings(entry.kernel, root) == String[]
        end

        @testset "the coverage check fails naming the kernel no launch compiles for the device" begin
            @test body_coverage_findings(jobs, root) ==
                  ["$(root).gpu_unlaunched_kernel! is a kernel no launch in the test compiled for the device"]
            @test body_entry_findings(BODY_FIXTURE_TABLE, jobs) == String[]
        end

        @testset "a table entry naming no kernel fails" begin
            @test body_table_findings(BODY_FIXTURE_TABLE, root) == String[]
            stray = (kernel = identity, precisions = (Float64,), launch = (B, T) -> nothing)
            @test body_table_findings(vcat(BODY_FIXTURE_TABLE, [stray]), root) ==
                  ["the table entry $(identity) names no kernel of $(root)"]
        end
    end

    @testset "every kernel the package defines" begin
        root = Fiddlybits
        jobs = body_launch_jobs(BODY_TABLE)
        @test body_table_findings(BODY_TABLE, root) == String[]
        @test body_coverage_findings(jobs, root) == String[]
        @test body_entry_findings(BODY_TABLE, jobs) == String[]
        @testset "$(nameof(entry.kernel))" for (entry, entry_jobs) in zip(BODY_TABLE, jobs)
            @test body_device_findings(entry_jobs, root) == String[]
            @test body_cpu_findings(entry.kernel, root) == String[]
        end
    end
end
