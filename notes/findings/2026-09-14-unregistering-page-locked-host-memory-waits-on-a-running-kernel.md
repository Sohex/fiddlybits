# Unregistering page-locked host memory waited for a running kernel, pinning did not, and registered memory left to a finalizer stalled whatever task allocated

Measured on 2026-09-14 on yggdrasil, an NVIDIA GeForce RTX 4090 on driver 610.57.04 under the
card's MPS server, Julia 1.12.7 with 8 default threads, CUDA.jl and CUDACore 6.3.1, from the
worktree of `fiddlybits-52v.6.26`. The instrument throughout is a fixture kernel that loops
while a cell in device-mapped page-locked host memory holds a sentinel and its iteration count
is below a ceiling, released by a host write (`test/provenance/writer.jl`, `writer_gate_kernel!`).
Every run below had all four shares of the card (`qrun -p gpu`), and `journalctl -k` showed no
Xid over any of them.

## The stall on the writer's submit path

- Job 3648, `held_none` with the writer's two held testsets repeated ten times, the wait bound
  15 s and the gate ceiling 10 s of spinning. Of 48 holds, 6 had a submit phase of 9.7 to 10.1 s,
  each ending when the gate kernel reached its ceiling; the other 42 were under 1.3 s.
- A native profile (Julia's `Profile` with C frames, sampled from the hold's start to the wait's
  entry) was the same in all six: the submitting task in `Provenance.submit!` ->
  `enqueue!` -> `Backends.host_buffer(GPU())` (`src/Backends/move.jl`, the `Vector`
  allocation) -> `ijl_gc_collect` -> the finalizer of a `CuArray{Float64, 1, HostMemory}`
  (CUDACore `src/array.jl`, lines 320-324) -> `unregister` (`lib/cudadrv/memory.jl`, line 185)
  -> `cuMemHostUnregister` (`lib/cudadrv/libcuda.jl`, lines 4617-4620), in libcuda for 892 of
  895 samples. Every other Julia thread of the process was idle in `pthread_cond_wait`.
- A `CuArray` over `HostMemory` is what `unsafe_wrap` returns for host memory it registers
  (CUDACore `src/array.jl`, lines 304-330), and in that process only the test's gates made
  them: the memory the finalizer unregistered was a gate of an earlier hold, not the writer's.

## Which calls wait

Job 3658: a gate kernel with a 40 s ceiling, each operation on a second task, 15 s timed wait.

| operation during the hold | returned |
| --- | --- |
| `Backends.free_host_buffer!` of a 2_048_000-element buffer pinned before the hold | at the release, 15.5 s |
| `Backends.host_buffer(GPU())` pinning a new 2_048_000-element buffer | 0.009 s |
| `CUDA.unsafe_free!` of an unrelated device-mapped host array | at the release, 15.5 s |
| `Backends.free_host_buffer!` of a 16-element pinned buffer | at the release, 15.5 s |
| a 2_048_000-element host allocation and copy | at the release, 15.5 s |

The last row's process held registered memory it no longer referenced, the arrays of earlier rows.

Job 3679: a full collection (`GC.gc(true)`) after a 2_048_000-element host allocation and copy,
on a second task, 10 s timed wait.

| registered host memory left for a finalizer before the hold | returned |
| --- | --- |
| none | 0.1 s |
| one `unsafe_wrap` `HostMemory` array, dropped unfreed | at the release, 10.6 s |
| both arrays freed through `CUDA.unsafe_free!` before the hold | 0.1 s |
| one `Backends.host_buffer(GPU())` buffer, dropped unfreed | at the release, 10.5 s |

## A hang, not explained

Job 3701: the same repeated held testsets as job 3648, with the test calling `CUDA.unsafe_free!`
on each gate's two arrays right after its kernel completed. After 32 holds, a hold's wait returned
at the gate's ceiling with one host submission unfinished, and the process did not leave that
hold. From that moment one thread the process had started mid-run sat in the kernel wait channel
`do_wait_intr_irq` while every Julia thread was in `futex_wait`, with the process's CPU idle.
SIGUSR1 and then SIGTERM produced no output and ran no exit hook; `qrun cancel` ended it. No
backtrace could be taken, the host's ptrace scope being 1. Whether the explicit unregister caused
it is not established.

## What is established and what is not

- Established on this host and these versions: `cuMemHostUnregister`, reached by
  `Backends.free_host_buffer!`, by `CUDA.unsafe_free!` of a registered array and by their
  finalizers, did not return while a kernel of the same process ran on the card; registering new
  host memory did.
- Established: a collection triggered by any allocation runs the finalizers of unreachable
  registered memory on the allocating task, so such memory stalls that task, the writer's
  `submit!` included, for as long as a kernel runs.
- Not established: whether the wait is on kernels of other processes sharing the card, why the
  unregister waits, and the cause of the hang in job 3701. The CUDA driver documentation for
  `cuMemHostUnregister` is not held here.
