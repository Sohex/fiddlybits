# CUDA.jl

**What it is.** The Julia CUDA stack: `CuArray`, kernel compilation, streams,
memory management, and wrapped libraries (CUBLAS, CUSPARSE, CUFFT).

**What of it is used.** `CuArray` as the device array behind `Field`, the
KernelAbstractions backend, memory queries for the profile budget, and
`CUSPARSE` only behind the same interface as the CPU sparse solve if a GPU
groundwater solve is ever wanted. No CUBLAS in the physics path.

**Assumptions it carries.**

| assumption | present | how a leak is caught |
| --- | --- | --- |
| Earth defaults | none | n/a |
| calendar or time | none | n/a |
| grid or mesh | none | n/a |
| index base | 1-based arrays | decision F7 |
| precision | `Float64` runs at a small fraction of `Float32` throughput on consumer hardware; library reductions may reassociate | reservoirs and ledgers in FP64 accumulators regardless of `FT`; no library reductions in the ledger path; `repro.backend_ulp_envelope` |
| threading and GPU model | asynchronous streams; unsynchronised reads are undefined | every exchange synchronises before a ledger is computed; the bitwise debug mode |
| mutable global state | the default stream and the memory pool are process-global | one process per run; the profile records the device |
| fail-open branches | fast-math and FMA contraction differ from CPU | production mode carries the measured envelope; debug mode disables contraction and asserts bitwise |
| dynamic dispatch in device code | the kernel compiler refuses a call left to runtime dispatch; it does not refuse a non-concrete type that host inference resolves, and it sees only what is compiled for the device | `test/backends/dispatch_refusal.jl`; the section below |

**Licence.** MIT. **Version.** CUDA 6.3.1 and CUDACore 6.3.1, with GPUCompiler
2.6.0 beneath them, as `Manifest.toml` resolves them on Julia 1.12.7; `to verify`
the driver and toolkit versions on this host.

**Checklist items applied.** A3 none, A6 none, B5 memory-pool limits are the
only limiter and are read into the profile budget, C3 the refusal of dynamic
dispatch is demonstrated here and not only declared (`test/backends/dispatch_refusal.jl`),
C4 FMA contraction (recorded), D4 the ledger closure on device against the CPU
reference path.

## Dynamic dispatch

Read in the installed source of the versions above. Package paths are relative to
the package root under the depot's `packages` directory; the Julia compiler is
`/usr/share/julia/Compiler/src`.

**The path from a launch to the refusal.**

- CUDACore `src/CUDAKernels.jl`, the `KA.Kernel{CUDABackend}` call method, lines
  111-127: a KernelAbstractions launch builds `kernel_call(obj.f, (ctx, args...))`
  and calls `kernel_compile(call; always_inline, maxthreads)`.
- CUDACore `src/compiler/execution.jl`: `kernel_compile(call)` at lines 145-148
  takes the argument types of the call; `kernel_compile(::LLVMBackend, f, tt)` at
  lines 65-66 is `cufunction`; `cufunction` at lines 675-681 builds the
  `CompilerJob` from `compiler_config(device; kwargs...)` and calls
  `compile_or_lookup`.
- CUDACore `src/compiler/compilation.jl`: `compile_or_lookup` at lines 572-575
  calls `compile(job)`, which at lines 378-383 calls `GPUCompiler.compile(:asm, job)`.
  `_compiler_config` at lines 237-317 ends in
  `CompilerConfig(target, params; kernel, name, always_inline)` at line 317 and
  passes its remaining keywords to `PTXCompilerTarget`, so no launch keyword
  reaches GPUCompiler's `validate`.
- GPUCompiler `src/interface.jl`, the `CompilerConfig` constructor, lines 173-179:
  `toplevel=true` and `validate=toplevel` by default. The copy constructor at
  lines 203-211 sets `validate = false` for a non-toplevel job, which is a
  deferred sub-job linked into a toplevel module that is itself validated.
- GPUCompiler `src/driver.jl`: `compile_unhooked` at lines 64-73 runs
  `check_method` unconditionally and `check_invocation` when `validate`;
  `emit_llvm` at lines 422-426 runs `check_ir(job, ir, relocations)` when the job
  is toplevel and `validate`, on the module after LLVM optimisation and after
  deferred jobs are linked.
- GPUCompiler `src/validation.jl`: `check_ir` at lines 165-173 collects errors
  and throws `InvalidIRError(job, errors)` when there is any. `check_ir!` visits
  every function of the module (lines 175-184) and every call instruction in it
  (lines 186-196). The call check, lines 224-358, records `DYNAMIC_CALL`
  (`"dynamic function invocation"`, line 133) for a call to a `tojlinvoke`
  trampoline (lines 255-267), to `jl_invoke` or `ijl_invoke` (lines 268-285) and
  to `jl_apply_generic` or `ijl_apply_generic` (lines 286-296), naming the called
  function where it can decode it. A call to any other undefined symbol exported
  by `libjulia` is `RUNTIME_FUNCTION` (lines 314-328).

**What is refused.** A kernel whose optimised device module still holds a call to
the generic dispatcher or an invoke trampoline. The launch raises
`GPUCompiler.InvalidIRError` on the host, before anything is queued, and nothing
falls back. The check reads every call in every function of the module, so it
does not depend on the call being reached:

- a call on a value read from an `Any`-typed container;
- a dispatch that only happens on an error path. GPUCompiler `src/irgen.jl`,
  `lower_throw!` at lines 166-230, replaces each throw with a device exception and
  erases the throw's own argument when nothing else uses it (lines 205-218), but
  it does not erase the call that computed that argument, so the dispatch
  survives to `check_ir`;
- a call on the contents of a `Core.Box`, whose contents are typed `Any`.

A kernel argument that is not a bits type is refused separately, before code
generation: `check_invocation`, `src/validation.jl` lines 75-115, throws a
`KernelError` at lines 103-111.

**What is not refused.**

- A non-concrete type that host inference resolves before code generation. The
  device compiler judges the code Julia's compiler hands it and does not re-judge
  its types. `find_method_matches`, `Compiler/src/abstractinterpretation.jl` lines
  342-349, splits a union argument when its split cost is at most
  `max_union_splitting` (lines 352-353). Otherwise
  `find_simple_method_matches` at lines 385-397 matches the whole union signature
  and fails only when more than `max_methods` methods match. GPUCompiler builds its
  interpreter's parameters in `src/interface.jl` without changing either limit:
  `inference_params` at lines 615-621 returns the default `InferenceParams()` on
  Julia 1.12, and `optimization_params` at lines 629-630 sets only
  `compilesig_invokes=false`. A call on a six-member union of
  concrete number types compiles on the device as a chain of `isa` branches, and
  so does a call that constant propagation folds.
- A `Core.Box` whose contents reach no call, only a type assertion. It compiles.
  Where the box survives optimisation, its allocation is lowered to the device
  runtime's `gc_pool_alloc` (GPUCompiler `src/optim.jl` line 556), which is a
  device `malloc` (`src/runtime.jl` lines 190-199).
- Non-concreteness on the host side of a launch. `cufunction` compiles at the
  runtime types of the arguments. `check_invocation` requires a dispatch tuple
  (`src/validation.jl` line 80), so a host value whose inferred type is abstract
  reaches the compiler as its concrete runtime type. A `Field` operator whose
  return type is not concrete is therefore invisible to this refusal, because the
  wrapper never enters a kernel.
- Anything not compiled for `CUDABackend`. The refusal is a property of a
  compilation, so it covers a kernel only at the argument signatures a device
  launch has compiled. The same kernel on the KernelAbstractions CPU backend runs
  its dispatch: `docs/imports/kernelabstractions.md`, section "Dynamic dispatch".

**Against the argument that relies on it.** `docs/plans/fiddlybits-52v.3-fields.md`,
section "Inference, and what it costs", says a drop to a non-concrete type
degrades loudly on the device, so the device needs no instrument. That holds for a
call left to dispatch inside device-compiled kernel code, and it is narrower than
the paragraph in four ways: resolved non-concrete types compile quietly as
branches; a box with no call on its contents compiles; host-side non-concreteness,
including a `Field` operator's return, never reaches the device compiler; and a
kernel run only on the CPU backend, or at a signature never compiled for the
device, is never checked. `fiddlybits-52v.3.17` carries the change to the argument.

**How the leak is caught.** `test/backends/dispatch_refusal.jl` launches one kernel
through `Backends.launch!` with a call that differs per arm. The arms that must be
refused raise `InvalidIRError` naming a dynamic invocation of the planted call and
leave the output at zero: a value read from an `Any` vector, a dispatch only on an
error path, and a call on a boxed variable. The arms that must compile write the
known answer: a concrete call (the positive control), a split union, a folded
union, a box with no call on its contents, and a non-concrete value at the launch.
A device compiler that fell back to dispatch instead of refusing fails the refused
arms.
