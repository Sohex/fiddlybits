# ClimaComms.jl

**What it is.** A small abstraction over where code runs and how processes talk:
a device type (`CPUSingleThreaded`, `CPUMultiThreaded`, `CUDADevice`), a
communications context (`SingletonCommsContext`, `MPICommsContext`), the
collectives over a context, a neighbour-graph context for halo exchange, a
device-flexible parallel-loop macro, and a set of rank-aware loggers.

**Why it was surveyed.** It is a hard dependency of both RRTMGP.jl and
ClimaTimeSteppers.jl, so a verdict on either implies a verdict on this. The plan
asks whether it is separable from ClimaCore, and how its device model compares
with the KernelAbstractions plus CUDA that decision 0012 already adopted.

## Is it separable from ClimaCore?

Completely. Its only dependencies are `Adapt`, `Logging` and `LoggingExtras`,
with CUDA and MPI behind package extensions. There is no mesh, no grid, no field
and no geometry anywhere in its 1,655 lines; `ClimaCore` depends on it and not the
other way round. The plan's question has a clean answer: yes, separable, and it
is the one CliMA package of this group that carries no discretisation at all.

## How its device model compares with KernelAbstractions plus CUDA

It duplicates the part this project has already adopted, and it does so less
generally.

**The parallel loop.** `ClimaComms.@threaded device for i in itr ... end`
(`src/devices.jl`) dispatches to `run_threaded`. On a CPU device it splits the
range across Julia threads; on `CUDADevice` the extension
(`ext/ClimaCommsCUDAExt.jl`) writes a closure, launches it with `CUDA.@cuda
always_inline = true launch = false`, queries the occupancy limits itself, and
either maps one item per thread or falls back to a grid-stride loop when the item
count exceeds the launch geometry. That is exactly the job KernelAbstractions'
`@kernel` plus `@index(Global)` does, written once for CUDA only. Where
KernelAbstractions compiles the same kernel source to CUDA, ROCm, oneAPI, Metal
or a threaded CPU backend, `@threaded` reaches CPU threads and NVIDIA and nothing
else, and its CPU and GPU paths are two separate code paths rather than one
source with two backends. For this project's CPU-fallback-as-reference-path
discipline that difference matters: the KernelAbstractions CPU backend runs the
same kernel text that the GPU runs, and `@threaded` does not.

**The device selection.** `ClimaComms.device()` reads the environment variable
`CLIMACOMMS_DEVICE` (default `CPU`, with `CPUSingleThreaded` chosen over
`CPUMultiThreaded` on the thread count) and `context()` reads
`CLIMACOMMS_CONTEXT` (default `SINGLETON`). Both refuse an unrecognised value,
which is the right behaviour, but the defaults themselves are silent: a run that
declares nothing gets a CPU device and a single-process context from the
environment rather than from its configuration. This project's rule is that no
default crosses a component boundary silently and the check happens at the point
of reading, so the profile would name the device and the environment variable
would not be consulted.

**What it adds that KernelAbstractions does not.** Only the distributed half:
the collectives (`reduce`, `allreduce`, `gather`, `barrier`, `bcast`) over a
context that becomes a no-op in a single process, and `graph_context` with
`start`/`progress`/`finish` for neighbour halo exchange. Decision 0009 puts
everything in one process on one mesh, so none of that is needed. If a future
decision ever distributes the mesh, the neighbour-graph context is the piece to
re-read; nothing else here would be wanted then either.

## Assumptions it carries

| assumption | present | how a leak is caught |
| --- | --- | --- |
| Earth defaults | none; there is no physical quantity in the package | n/a |
| calendar or time | none; the one time-like thing is `time()` wall clock inside a benchmarking helper | n/a |
| grid or mesh | none; `graph_context` takes neighbour ranks and buffer lengths and knows nothing of what the buffers mean | n/a |
| index base | 1-based; process ids run `1:nprocs` with the root at 1, and the CUDA extension converts its zero-based thread index with `itr[firstindex(itr) + item_index - 1]` | n/a |
| precision | none of its own; buffers are the caller's | n/a |
| threading and GPU model | CPU threads plus CUDA only, with two separate code paths and no portable kernel language; MPI must be CUDA-aware for a GPU context, and `init` errors if it is not, which is a refusal rather than a fallback and is the right shape | n/a; duplicates KernelAbstractions with less reach |
| mutable global state | `init` on an MPI context installs a process-global logger via `Logging.global_logger` and assigns a GPU to the rank from the node-local communicator; device and context selection read process-global environment variables | n/a; both are the reason it would have to be constructed explicitly rather than through `device()` and `context()` if it were ever adopted transitively |
| fail-open branches | none found: an unknown `CLIMACOMMS_DEVICE` or `CLIMACOMMS_CONTEXT` errors, a `CUDADevice` without CUDA.jl loaded errors with the fix named, and a GPU MPI context without a CUDA-aware MPI errors. The defaults are silent, but every failure refuses | n/a |

## Checklist items applied

**A1** none: no day, no year, no calendar. **A2** none: no planetary constant
block, and no physical constant of any kind. **A3** none: the Earth-literal grep
is clean. **A6** none in the used surface; the process-id base is 1 and is
documented. **B4** no constants to check comments against. **B5** the only
limiters are the CUDA launch-geometry caps in `block_size_limit` and
`grid_size_limit`, which bind on the device's own occupancy limits and coarsen
rather than truncate. **C1** no carried constant. **C3** every capability that
would be relied on transitively (device selection, `array_type`, `@threaded`) is
exercised by the upstream suite. **C4** recorded above: the failures refuse. This
is the clean negative for this package. **C5** the device and context are
duplicated live state against this project's own profile record of the device;
the authoritative copy would be the profile, and `ClimaComms` would be
constructed from it. **D2** the only exchanged arrays are the collectives' send
and receive buffers, which are the caller's own and carry no units. **D4** the
conservation identity that applies is that a reduction over one process equals
the local value, which is what the singleton context asserts by construction.

**Licence.** Apache 2.0. **Version.** Read against `main` at commit
`5e2d0328aea258dba12eb02150aa5904e0137ddd` (2026-07-13), `Project.toml` version
0.6.11.

## Verdict

**Do not adopt.** It is clean, it carries no planetary content and it is fully
separable from ClimaCore, but its device model duplicates KernelAbstractions plus
CUDA with a narrower backend set and separate CPU and GPU code paths, and its
distributed half serves a multi-process design decision 0009 does not have.

It will nonetheless arrive transitively if ClimaTimeSteppers.jl is adopted, since
`ClimaComms` is a hard dependency there rather than a weak one. That is a cost to
name in the decision that adopts the integrators, not a separate adoption: the
surface actually reached would be `ClimaComms.device()` for a wall-clock callback
and a benchmarking helper, and the mitigation is to construct the device from the
profile and never call `device()` or `context()`, so the two environment
variables are never read. Were that ever wanted as a named check, the test is
`test/lint/lint_no_env_device.jl`, asserting that no call to
`ClimaComms.device()` or `ClimaComms.context()` without an explicit argument
appears in this repository.
