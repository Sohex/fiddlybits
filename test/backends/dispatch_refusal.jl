using Test
using CUDA
using KernelAbstractions: @kernel, @index, @Const
using Fiddlybits: Backends

# The leak test docs/imports/cuda.md and docs/imports/kernelabstractions.md,
# section "Dynamic dispatch", name.
#
# One kernel writes out[i] = x[i] * scale(i). Each arm passes a different
# `scale`, every one of which returns a value equal to 2, so an arm that runs
# writes 2x and an arm that is refused leaves `out` at zero.

const DISPATCH_N = 8

"The GPUCompiler module CUDA loaded, for its `InvalidIRError` and `DYNAMIC_CALL`."
const DISPATCH_GPUCOMPILER =
    Base.loaded_modules[Base.PkgId(Base.UUID("61eb1bfa-7361-4325-ad38-22787b887f55"), "GPUCompiler")]

"An Any-typed vector holding 2.0; a call on a value read from it is left to runtime dispatch."
const DISPATCH_TABLE = Any[2.0]

@kernel function dispatch_scaled_kernel!(out, @Const(x), scale)
    i = @index(Global)
    out[i] = x[i] * scale(i)
end

"2.0."
dispatch_concrete_scale(i) = 2.0

"`DISPATCH_TABLE[1]`, typed `Any`."
dispatch_table_scale(i) = DISPATCH_TABLE[1]

"2.0 for `i` of 1 or more; below 1, throws a `DomainError` built from `DISPATCH_TABLE[1] * i`."
function dispatch_error_path_scale(i)
    i < 1 && throw(DomainError(DISPATCH_TABLE[1] * i))
    return 2.0
end

"2.0, computed as `s + 1.0` on a local `s` that a closure captures and that is reassigned after the closure is made."
function dispatch_boxed_call_scale(i)
    s = Float64(i) - Float64(i) + 1.0
    get = () -> s
    s = s + 1.0
    return get()::Float64
end

"2.0, read back through a closure over a local assigned after the closure is made, with no call on it."
function dispatch_boxed_pass_scale(i)
    get = () -> s
    s = Float64(i) - Float64(i) + 2.0
    return get()::Float64
end

"A value equal to 2 of one of six concrete types, chosen by `k`."
@noinline dispatch_union_value(k) =
    k == 1 ? 2.0 : k == 2 ? 2.0f0 : k == 3 ? 2 : k == 4 ? Int32(2) : k == 5 ? Int16(2) : UInt8(2)

"`dispatch_union_value` at `mod1(i, 6)`: a six-member union, chosen at run time."
dispatch_union_scale(i) = dispatch_union_value(mod1(i, 6))

"`dispatch_union_value` at the literal 1."
dispatch_constant_scale(i) = dispatch_union_value(1)

"""
    dispatch_launch(scale, backend; barrier = false)

Launch `dispatch_scaled_kernel!` over `DISPATCH_N` work items on `backend` with
`scale`, and return `(err, out)`: the error the launch or its completion raised,
or `nothing`, and the output array read back to the host through `Backends.on`.
`out` starts at zero. With `barrier`, the host passes `x` to `launch!` through
`Base.inferencebarrier`.
"""
function dispatch_launch(scale, backend::Backends.Backend; barrier::Bool = false)
    x = Backends.on(collect(1.0:DISPATCH_N), backend)
    out = Backends.on(zeros(Float64, DISPATCH_N), backend)
    err = try
        Backends.launch!(dispatch_scaled_kernel!, backend, DISPATCH_N, out,
                         barrier ? Base.inferencebarrier(x) : x, scale)
        Backends.complete!(backend)
        nothing
    catch e
        e
    end
    return err, Backends.on(out, Backends.CPU())
end

"""
    refused_dispatch(err, f)

Whether `err` is GPUCompiler's `InvalidIRError` and names a dynamic function
invocation of `f` among its errors.
"""
refused_dispatch(err, f) =
    err isa DISPATCH_GPUCOMPILER.InvalidIRError &&
    any(e -> e[1] == DISPATCH_GPUCOMPILER.DYNAMIC_CALL && e[3] === f, err.errors)

const DISPATCH_EXPECTED = 2.0 .* collect(1.0:DISPATCH_N)

@testset "the device compiler refuses dynamic dispatch; the CPU backend runs it" begin
    @test CUDA.functional()
    gpu = Backends.GPU()

    @testset "positive control: the concrete call compiles and runs on the device" begin
        err, out = dispatch_launch(dispatch_concrete_scale, gpu)
        @test err === nothing
        @test out == DISPATCH_EXPECTED
        @test !refused_dispatch(err, *)
    end

    @testset "refused on the device: $(name)" for (name, scale, f) in (
            ("a call on a value read from an Any-typed vector", dispatch_table_scale, *),
            ("a dispatch only on an error path", dispatch_error_path_scale, *),
            ("a call on a boxed closure variable", dispatch_boxed_call_scale, +))
        err, out = dispatch_launch(scale, gpu)
        @test refused_dispatch(err, f)
        @test out == zeros(Float64, DISPATCH_N)
    end

    @testset "compiled on the device: $(name)" for (name, scale, barrier) in (
            ("a six-member union that inference splits", dispatch_union_scale, false),
            ("a union that constant propagation folds", dispatch_constant_scale, false),
            ("a boxed closure variable no call reads", dispatch_boxed_pass_scale, false),
            ("a non-concrete value on the host side of the launch", dispatch_concrete_scale, true))
        err, out = dispatch_launch(scale, gpu; barrier = barrier)
        @test err === nothing
        @test out == DISPATCH_EXPECTED
    end

    @testset "run on the CPU backend: $(name)" for (name, scale) in (
            ("a call on a value read from an Any-typed vector", dispatch_table_scale),
            ("a dispatch only on an error path", dispatch_error_path_scale),
            ("a call on a boxed closure variable", dispatch_boxed_call_scale),
            ("the concrete call", dispatch_concrete_scale))
        err, out = dispatch_launch(scale, Backends.CPU())
        @test err === nothing
        @test out == DISPATCH_EXPECTED
    end
end
