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
| page-locked memory and the queued copy | `Base.copyto!` from a `CuArray` into an `Array` synchronizes first; a pointer copy with `async=true` is queued on the calling task's stream; a copy into memory the driver has not page-locked may wait on the host; an event's host wait yields only while nonblocking synchronization is enabled; an event's wait does not read the kernel-exception flag, which is one per context and cleared by the first read that finds it set | `Backends.copy_to_host!` copies through the pointer form and refuses a host that is not page-locked; a device fault is raised by `Backends.complete!` and never by `after!`; `test/backends/host_copy.jl`, `test/backends/kernel_fault.jl`; the section "Page-locked memory and the queued copy" |

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

## Page-locked memory and the queued copy

Read in the installed source of the versions above, CUDACore paths relative to its
package root; Julia's base library is `/usr/share/julia/base`.
`Backends.copy_to_host!` and `Backends.host_buffer` rest on what follows.

**The copy that is queued and the copy that waits.**

- CUDACore `lib/cudadrv/memory.jl`, lines 417-430: `unsafe_copyto!(dst::Ptr{T},
  src::CuPtr{T}, N; stream = stream(), async = false)` calls `cuMemcpyDtoHAsync_v2` on
  `stream` and then `synchronize(stream)` unless `async` is true. `copy_to_host!` calls
  it with `async = true` and the default stream.
- CUDACore `src/array.jl`, lines 610-627: `Base.unsafe_copyto!(dest::Array, doffs,
  src::DenseCuArray, soffs, n)`, which `Base.copyto!` reaches at lines 557-569, calls
  `synchronize(src)` at line 617 and copies with `async = false` at line 620, so the
  `Base.copyto!` door waits on the host. The comments at lines 593-595 and 613-616 say
  that a copy of unpinned memory normally blocks in the driver, not for all sizes and not
  on all memory architectures; the driver's own documentation is not held here, and the
  door does not rely on the unpinned case either way, because it refuses it.
- CUDACore `lib/cudadrv/state.jl`, lines 289-298: `stream()` is the stream held in the
  task-local state for the current device, created on first use, so the copy and the
  handoff's event are queued on the task's own stream.
- CUDACore `src/compiler/execution.jl`, lines 411-416: `managed_kernel_launch` launches
  on `stream()` unless a `stream` keyword is passed and takes ownership of each argument
  on it, and CUDACore `src/CUDAKernels.jl` lines 111-127 pass none for a
  KernelAbstractions launch. A launch and a copy from one task are therefore on one stream
  in the order they were called.
- CUDACore `src/array.jl`, lines 417-426 and 467-468, and `src/memory.jl`, lines 650-660:
  `pointer(::CuArray)` converts through the array's `Managed` memory, which calls
  `take_ownership!`. `take_ownership!`, lines 597-648, synchronizes when the memory's
  owning stream is another stream and its synchronization is enabled (lines 631-634),
  then records the current stream as the owner and marks the memory dirty. From the task
  that wrote the array the conversion does not wait; from another task it waits unless
  `order_explicitly!` switched that off, which is why `copy_to_host!` asks for `after!`
  on the writing task's handoff first.
- CUDACore `src/memory.jl`, lines 770-800: `pool_free` frees through `_pool_free(mem,
  managed.stream)`, against the stream that last owned the memory, so a device array
  collected after its copy is queued is released behind that copy on the same stream.

**The page lock.**

- CUDACore `lib/cudadrv/memory.jl`, `pin(a::AbstractArray)`, lines 683-707: registers
  `sizeof(a)` bytes from `pointer(a)` through `__pin`, lines 734-757, which calls
  `register(HostMemory, ptr, sz)` once per context and address; `register`, lines
  171-177, calls `cuMemHostRegister_v2` and raises an `ArgumentError` for an empty range
  (line 172). `pin` attaches a finalizer that calls `__unpin` (lines 702-704), and
  `__unpin`, lines 758-775, calls `unregister` (`cuMemHostUnregister`, lines 184-186)
  when the address's count reaches zero.
- `is_pinned(ptr::Ptr)`, lines 858-871: queries `POINTER_ATTRIBUTE_MEMORY_TYPE` and
  returns true for `CU_MEMORYTYPE_HOST`, false where the driver reports an invalid value,
  which is what it reports for memory it has not registered.
- `/usr/share/julia/base/gcutils.jl`, line 102: `finalize(o)` runs the finalizers
  registered for `o` immediately, through `jl_finalize_th`. `free_host_buffer!` runs the
  one `pin` attached, and checks `is_pinned` afterwards rather than trusting it.

**The wait on the handoff.**

- CUDACore `lib/cudadrv/events.jl`, lines 45-46: `record(e, stream = stream())` records
  an event on the task's stream, which is what `Backends.handoff(GPU())` does.
- CUDACore `lib/cudadrv/synchronization.jl`, lines 217-229: `synchronize(event;
  blocking = false)` first polls `isdone` through `spinning_synchronization`, lines
  77-97, which pauses 32 times without yielding and then calls `yield()` for up to 224
  more polls, and then hands the event to `nonblocking_synchronize`, lines 158-183, whose
  `put!` on a `BidirectionalChannel` parks the task until a detached worker thread
  (lines 113-156) returns from `cuEventSynchronize`. Both branches are taken only when
  `use_nonblocking_synchronization` is true, the preference `nonblocking_synchronization`
  read at lines 3-4 with a default of true; otherwise, or with `blocking = true`, the
  task calls `cuEventSynchronize` and holds its thread.
- The same event form does not call `check_exceptions`. The stream form, lines 201-215,
  calls it at line 214, and `Backends.complete!` reaches the stream form: the backend form
  through `KA.synchronize(::CUDABackend)`, CUDACore `src/CUDAKernels.jl` line 28, which is
  `synchronize()` on the task's stream; the array form through `synchronize(::CuArray)`,
  `src/array.jl` line 494, and `synchronize(::Managed)`, `src/memory.jl` lines 580-584,
  on the stream that last owned the array. `wait(e::CuEvent, stream)`,
  `lib/cudadrv/events.jl` lines 78-79, which `after!(GPU(), point)` calls, is
  `cuStreamWaitEvent` and calls no check either.

**The kernel-exception flag and where a fault is raised.**

- CUDACore `src/device/runtime.jl`, `signal_exception`, lines 190-207: a kernel that
  throws on the device sets its exception record's `status` to one (line 200) and stops
  executing (line 204). Nothing is raised on the host at that point.
- CUDACore `src/compiler/exceptions.jl`, lines 16-26: the record is one
  `ExceptionInfo_st` in host memory mapped to the device, held in `exception_infos`,
  which is keyed by context and not by task or stream. `check_exceptions`, lines 29-43,
  reads every context's record, and on the first it finds set restores it to zero (line
  34) and throws `KernelException` (line 38). The first check anywhere in the process
  after a fault takes it, on whichever task makes that check.
- The rule `Backends` states. `after!(CPU(), point)` and `after!(GPU(), point)` raise no
  device fault, and a host copy behind a faulted kernel lands what the kernel left in the
  array. The fault is raised by the first `Backends.complete!` after it, which includes
  the one `on` and `adapt_for` call, as a `Verdicts.Refusal` at `Backends.complete!`
  carrying the `KernelException`. The store's writer raises a fault behind its host
  copies by calling `complete!` on the task that submitted the write, in `settle!`, at the
  settle point of decision 0060 (`fiddlybits-52v.6.26`).

**How the leak is caught.** `test/backends/host_copy.jl`. A copy that was not queued at
its stream position holds the second kernel's values instead of the first's (check 1);
a door that synchronizes, by `complete!` or by a bare device synchronize, leaves nothing
queued or no event outstanding when it returns (check 2); a host wait that holds its
thread, as a disabled nonblocking-synchronization preference would make `after!(CPU(),
point)`, leaves a second task on that thread unfinished (check 4); and a host that is
not page-locked is refused rather than copied into (check 5). `test/backends/kernel_fault.jl`
queues an out-of-range kernel and a host copy from one task and waits on the copy's
handoff from a second: an `after!` that read the exception flag would raise on the
waiting task and leave the submitting task's `complete!` without a refusal, which is
what its positive control, a waiter that calls `check_exceptions` after `after!`, shows.
