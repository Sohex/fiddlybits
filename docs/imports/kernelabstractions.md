# KernelAbstractions.jl

**What it is.** A portable kernel language for Julia: `@kernel` functions with
`@index` that compile to CUDA, ROCm, oneAPI, Metal or a multithreaded CPU backend.

**What of it is used.** `@kernel`, `@index(Global)`, `@Const`, backend selection,
`synchronize`, and the CPU backend as the fallback and as the reference for every
GPU kernel. Nothing else.

**Assumptions it carries.**

| assumption | present | how a leak is caught |
| --- | --- | --- |
| Earth defaults | none | n/a |
| calendar or time | none | n/a |
| grid or mesh | none; kernels index flat arrays | `test/mesh/stencil_valence.jl` asserts stencil tables are the only geometry a kernel sees |
| index base | 1-based `@index`; workgroup indices 1-based | decision F7: 1-based in kernels; `CellId` refuses arithmetic at the host boundary; `test/lint/lint_index_base.jl` greps kernels for `- 1` and `+ 1` on cell indices |
| precision | element type follows the array | `FT` is a type parameter end to end; `repro.fp32_kernel_certification` |
| threading and GPU model | CPU backend splits the index range across threads; reductions are the caller's responsibility | no `@atomic` in physics kernels (lint); segmented reductions with fixed order; `repro.thread_count_bitwise` |
| mutable global state | none in the API | n/a |
| fail-open branches | a kernel launched with an out-of-range `ndrange` on the CPU backend silently does nothing for the excess | every launch asserts `ndrange == length(target)`; the reference path compares full arrays |
| dynamic dispatch in a kernel body | refused when the kernel is compiled for the CUDA backend; run without complaint on the CPU backend | `test/backends/dispatch_refusal.jl`; the section below |

**Licence.** MIT. **Version.** 0.9.42, as `Manifest.toml` resolves it on Julia
1.12.7; verify Enzyme interaction is not relied upon (decision F8 defers it).

**Checklist items applied.** A1 none, A2 none, A3 none, A6 index base (recorded),
C3 the CPU backend's determinism is a demonstrated capability only with our own
fixed-order reductions, and the device refusal of dynamic dispatch is demonstrated
on both backends (`test/backends/dispatch_refusal.jl`), C4 the `ndrange` fail-open
(recorded), and a kernel body's dynamic dispatch on the CPU backend (recorded),
D4 the reference path comparison per kernel.

## Dynamic dispatch

Read in the installed source of KernelAbstractions 0.9.42, relative to the package
root under the depot's `packages` directory. The CUDA backend's half lives in
CUDACore and GPUCompiler, and `docs/imports/cuda.md`, section "Dynamic dispatch",
carries its locators.

**One body, two functions.** `__kernel`, `src/macros.jl` lines 13-79, writes each
`@kernel` body out twice, as `cpu_<name>` with the work-group loops inserted and
as `gpu_<name>`. The constructor it generates at lines 54-72 picks `gpu_<name>`
when `isgpu(dev)` (lines 57-58) and `cpu_<name>` otherwise (line 61). The two share the body, so a call left to
dispatch in one is left to dispatch in the other.

**The CUDA backend refuses it.** KernelAbstractions adds no validation of its own.
The `Kernel{CUDABackend}` call method is CUDACore's (`src/CUDAKernels.jl` lines
111-127), and it compiles `gpu_<name>` through `cufunction` and
`GPUCompiler.compile`, whose `check_ir` throws `InvalidIRError` for a call to the
generic dispatcher or an invoke trampoline anywhere in the optimised module.
What that refuses and what it does not is in `docs/imports/cuda.md`: a resolved
union, a folded constant, a box with no call on its contents and host-side
non-concreteness all compile.

**The CPU backend runs it.** The `Kernel{CPU}` call method, `src/cpu.jl` lines
39-48, calls `__run` (lines 98-127), which calls `__thread_run` (lines 129-150). That
calls `obj.f(ctx, args...)` at line 147, an ordinary Julia call of `cpu_<name>`
with no validation pass. A call left to dispatch is dispatched at run time on every
work item and returns the right answer, with nothing raised or logged.

**What follows for this project.** The CPU backend is the fallback and the
reference path, so a kernel body launched only on `Backends.CPU` has no refusal
behind it. The same holds for an element type or argument signature that no launch
compiles for the device: the device refusal covers a kernel only where a device
compilation has happened. `docs/plans/fiddlybits-52v.3-fields.md`, section
"Inference, and what it costs", names `kernels.body_types_concrete` as the instrument
for both.

**The two functions of one kernel.** `Kernel`, `src/KernelAbstractions.jl` lines
706-709, holds the function a launch calls in its field `f`, which the constructor
above fills with `gpu_<name>` or `cpu_<name>`. `kernel(dev).f` is therefore the device
function for a device backend and the CPU function for `KernelAbstractions.CPU()`.

**How the leak is caught.** `test/backends/dispatch_refusal.jl` launches the same
kernels on both backends through `Backends.launch!`. On the CUDA backend the
dispatching arms are refused with `InvalidIRError` and leave the output at zero,
and the concrete arm runs and writes the known answer. On the CPU backend every
dispatching arm runs and writes the same answer, which pins the CPU backend's
silence as recorded behaviour rather than an assumption.

`test/kernels/body_types.jl` (`kernels.body_types_concrete`) reads the typed code of
`cpu_<name>` at every dispatch-tuple specialization and of `gpu_<name>` at every
device compilation of each kernel the package defines, resolving both through
`kernel(dev).f`, and fails on a value whose type `code_warntype` highlights. It also
fails when a kernel is compiled for the device at no signature. The locators of the
reflection it reads are in `docs/imports/cuda.md`, section "Dynamic dispatch".
