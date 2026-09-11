# Backends.launch! queues instead of stopping, and every path from a kernel to a host read is walked

Measured and argued on 2026-09-11 on yggdrasil through `qrun` with this repository's
defaults (profile `gpu-share`, one share of an NVIDIA GeForce RTX 4090, driver
610.57.04, 8 CPUs, 16G), Julia 1.12.7, CUDA.jl 6.3.1, KernelAbstractions.jl 0.9.42,
Adapt.jl 4.7.0, on branch `fiddlybits-52v.7.50`. Another repository gate held a second
share of the card throughout, so every absolute number below is larger than the floor
`notes/findings/2026-09-11-device-scalar-reduction-contract.md` measured on a quiet
card; the two jobs reported here bracket the scatter and the comparisons are within a
job.

`Backends.launch!` ended with `KernelAbstractions.synchronize(dev)` on every call, so
every kernel was a host-visible stop. This record is the argument for removing that
stop and the measurement of what removing it buys. The row is
`fiddlybits-52v.7.50`.

## The shape

`launch!` compiles, launches and returns. A new `Backends.complete!` is the only place
in this module that waits, and `Backends.on` calls it before it copies device memory to
the host, so the wait is stated in this repository's source rather than inherited from
what a copy of unpinned memory happens to do. `launch!` records the kernel it queued in
a task-local list that `complete!` empties; when the wait raises, `complete!` refuses
naming that list, because an asynchronous launch cannot put the faulting kernel on the
host stack and the list is what is left to name it with.

## The argument, path by path

Each path is marked CHECKED where the guarantee was read out of the source named, or
measured, and ASSUMED where it rests on a documented model that was not verified here.

**Every kernel in the tree goes through `launch!`.** CHECKED: `grep -rn "launch!" src/`
finds the definition and five call sites (`Backends.axpy!`,
`Backends.stencil_gather!`, `Reductions.pairwise_block_sums`,
`Reductions.segmented_sum`, `Reductions.segmented_quantile`); there is no `CUDA.@cuda`
and no direct KernelAbstractions kernel call anywhere in `src/`.

**1. Kernel to kernel, same backend, same task.** Both launches reach
`CUDACore.kernel_launch` and then `cudacall` with no `stream` keyword, which defaults to
`CUDA.stream()`, the task-local current stream. CHECKED, in
`CUDA/EwwXC/CUDACore/src/CUDAKernels.jl` line 155 and
`CUDACore/src/compiler/execution.jl` `launch_converted`. That a CUDA stream runs the
work submitted to it in submission order is ASSUMED: it is the CUDA programming model
and was not verified here. `test/backends/launch_completion.jl` chains a slow kernel
and a dependent one with no completion between them and asserts the dependent kernel
saw the finished write rather than the sentinel; that exercises the assumption and does
not prove it.

**2. Kernel to kernel, same backend, different tasks.** CUDA.jl gives each Julia task
its own stream, so the stream does not order these. What orders them is CUDA.jl's
per-array ownership: converting a `CuArray` to a device pointer for a launch calls
`take_ownership!`, which calls `maybe_synchronize(managed)` whenever
`managed.stream != stream` before recording the new owner. CHECKED, in
`CUDACore/src/memory.jl`, `Base.convert(::Type{CuPtr{T}}, managed)` and
`take_ownership!`. Not exercised by any check here, because nothing in this tree
launches from more than one task: CHECKED, `grep -rn "@spawn\|@async\|@threads" src/`
finds nothing. Where it does not hold, which is any backend without per-array stream
ownership, two tasks sharing an array would need an explicit event and this module has
none. `fiddlybits-52v.7.52` carries that.

**3. Kernel to a host read through `Backends.on(array, CPU)`.** `on` calls
`complete!(array)`, which reaches `CUDA.synchronize(array)`, that is
`synchronize(array.data[])`, that is `synchronize(managed.stream)`, the stream that last
took ownership of the array and so the stream the kernel that wrote it ran on; that call
ends in `check_exceptions()`. CHECKED: the `complete!` call is in this repository's
`src/Backends/move.jl`; `synchronize(x::CuArray) = synchronize(x.data[])` at
`CUDACore/src/array.jl` line 494, `synchronize(managed::Managed)` at
`CUDACore/src/memory.jl` line 580, `synchronize(stream::CuStream)` at
`CUDACore/lib/cudadrv/synchronization.jl` line 201. CHECKED by measurement: a read
through `on` of an array a 32 ms kernel is writing takes at least half that kernel's
duration, and the value it returns is the finished one.

The copy that follows the wait, `Array(array)`, also calls `synchronize(src)` of its own
before an `async = false` transfer. CHECKED, `CUDACore/src/array.jl` lines 610 to 622.
So on this platform the copy would have waited anyway. That is the platform behaviour
the guarantee must not rest on, and after this row it does not: the wait in `on` is
unconditional and is written in this repository. On a platform where a device-to-host
copy does not synchronize, which is what a pinned destination or another backend would
give, `Array`'s wait is the one that disappears and `complete!` is the one that remains.

**4. Kernel to a host read through `Backends.adapt_for(x, CPU)`.** `adapt_for` for a
`CPU` target completes the device first, and completes nothing when `CUDA.functional()`
is false. CHECKED, in `src/Backends/move.jl`. It waits on the task's current stream and
not on a named array, because it is handed a struct, so it is weaker than path 3; it has
no callers in the tree yet.

**5. Kernel to a host read through anything else in `src/`.** There is none.
CHECKED: `grep -rn "Array(" src/` returns exactly two lines, both in
`src/Backends/move.jl`, and `grep -rl "CUDA\|CuArray" src/` returns only
`src/Backends/backend.jl` and `src/Backends/move.jl`. `Backends.on` and
`Backends.adapt_for` are the complete set of device-to-host doors in the source tree.

**6. Kernel to a host read in `test/` that does not go through `on`.** Every one is
`Array(cuarray)` or `copyto!(host, cuarray)` and waits through the CUDA.jl behaviour of
path 3, which is inherited rather than stated. The sites inside this row's boundary were
routed through `Backends.on`, so `test/backends/` now states its waits. Six files
outside the boundary still read this way: `test/certify/gpu_certification.jl`,
`test/mesh/stencil_valence.jl`, `test/orbit/runtests.jl`,
`test/reductions/gpu_agreement.jl`, `test/reductions/quantiles.jl`,
`test/reductions/segment_moves.jl`. `fiddlybits-52v.7.53` carries them. This is the part
of the argument that rests on the platform, and it is named.

**7. Kernel to a device-side broadcast over what it wrote.**
`test/certify/gpu_certification.jl` broadcasts `gu .+ c .* gv` after two
`stencil_gather!` launches. A CUDA.jl broadcast launches through the same
`kernel_launch` path as a kernel and so onto the same task-local stream, giving path 1's
ordering, with path 2's ownership transfer behind it if the streams differ. CHECKED, by
the same source as path 1.

**8. A running kernel against the freeing of its own arguments.** With the barrier gone,
a temporary `CuArray` handed to `launch!` can become garbage while the kernel is still
reading it; `Backends.axpy!(y, a, Backends.on(x, backend), backend)` in
`test/backends/bitwise_mode.jl` is exactly that shape. Its finalizer reaches
`pool_free`, which calls `_pool_free(mem, managed.stream)` and frees on the stream that
last used the memory, which is the kernel's, so the free is ordered after the kernel.
CHECKED, `CUDACore/src/memory.jl` lines 775 and 803. For an allocation that is not
stream-ordered the free is `cuMemFree`, which the driver documents as synchronizing the
device: ASSUMED, from the driver documentation and not read here. The `gc_preserve` that
`kernel_launch` wraps the launch in covers only the launch call itself and is not what
makes this safe.

**9. The CPU backend.** `KernelAbstractions.synchronize(::CPU)` is literally `nothing`,
and `Kernel{CPU}`'s call runs `__run`, which is `Threads.@threads :static` or
`@sync ... Threads.@spawn` and joins either way before returning. A CPU launch is
therefore finished when `launch!` returns and there is nothing to order. CHECKED,
`KernelAbstractions/scVtc/src/cpu.jl` line 2 and lines 97 to 124. CHECKED by
measurement: the positive control in `test/backends/launch_completion.jl` asserts that a
CPU launch of a 50 ms kernel does not return in under a tenth of that, which is the
shape the GPU check has to be able to reject.

**10. An error a kernel raises.** The synchronize in `launch!` used to raise a device
fault with the caller's frame on the stack. It now raises at the next `complete!`,
which refuses carrying the raised error's own message and naming every kernel
`launch!` recorded since the last completion; for a single launch that is the launch.
CHECKED by `test/backends/kernel_fault.jl`, which makes a real kernel write out of
range in a fresh process, because a device fault leaves the CUDA context unusable, and
asserts the refusal names `out_of_range_kernel!`, with the in-range arm as the positive
control.

**What the evidence does not cover.** A race does not fail reliably, so a green suite is
not evidence that the ordering holds; it is evidence that it held on these runs. The
strongest thing the suite says is the positive control of path 3: a read of the same
array with no ordering saw the pre-kernel sentinel in 4 of 5 repeats, so the failure
this change could have introduced is real and observable, and the check that the ordered
read does not show it is a check. Path 2 has no check. Paths 6 and the second half of 8
rest on the platform. Nothing here says anything about a device backend other than CUDA,
because there is none.

## What it buys

One one-item kernel, `out[i] = src[i] + 1`, repeated 200 times, minimum and median
microseconds, two independent jobs reported as two numbers per cell.

| launches in the chain | launch and synchronize each | queue, then one complete |
|---|---|---|
| 1 | 8.99 / 9.78, 10.40 / 11.20 | 10.80 / 11.11, 9.27 / 10.08 |
| 2 | 21.42 / 23.16, 18.39 / 20.05 | 14.31 / 15.95, 12.74 / 13.64 |
| 3 | 32.32 / 32.91, 27.97 / 30.06 | 18.18 / 18.91, 16.24 / 17.30 |
| 5 | 53.74 / 54.74, 48.02 / 50.01 | 25.46 / 26.20, 22.77 / 23.80 |
| 10 | 108.59 / 115.26, 97.32 / 101.20 | 44.46 / 46.35, 38.88 / 40.24 |

One launch alone gains nothing, which is the shape of the thing: a chain of one still
pays one wait. What changes is the marginal cost of the next launch, which falls from
about 10.6 and 9.7 microseconds to about 3.7 and 3.3. At ten launches the chain costs
59 and 60 per cent less.

The pieces, same protocol:

| operation | min (us) | median (us) |
|---|---|---|
| `launch!`, queued and not waited for | 3.12, 3.09 | 3.25, 3.22 |
| the same launch with no queued record | 3.07, 3.04 | 3.16, 3.15 |
| `complete!(backend)` on an idle stream | 0.39, 0.38 | 0.40, 0.39 |
| `complete!(array)` on an idle stream | 0.41, 0.41 | 0.42, 0.43 |
| `Array(out)`, one element | 5.64, 5.72 | 6.44, 6.09 |
| `Backends.on(out, cpu)`, one element | 5.91, 6.09 | 7.23, 6.61 |

The task-local record `launch!` keeps costs 0.05 and 0.05 microseconds, which is inside
the scatter of the launch itself. The wait `on` now states costs 0.27 and 0.37
microseconds on top of the copy, which is the price of not inheriting it.

The chain the tree actually runs, `stencil_gather!` then `axpy!` over one field:

| cells | launch and synchronize each | queue, then one complete |
|---|---|---|
| 1024 | 20.38 / 21.71, 14.98 / 15.89 | 13.48 / 14.47, 10.52 / 10.93 |
| 16384 | 20.10 / 21.56, 14.87 / 16.09 | 13.91 / 14.93, 10.76 / 11.05 |
| 262144 | 43.25 / 44.92, 41.25 / 42.78 | 36.48 / 37.89, 34.80 / 36.36 |

`Reductions.pairwise_sum` on device-resident input is unchanged within the scatter at
every size measured, which is expected: it is one launch and then a host read, so there
is no chain for the change to shorten. What the change removes there is the obstacle
that `notes/findings/2026-09-11-device-scalar-reduction-contract.md` named, not a cost
that reduction was paying.

## The bitwise guarantees are unmoved

Removing a host-side wait cannot change what a kernel computes, but the record asked for
the assertion rather than the argument. Each of `axpy!` and `stencil_gather!` was run
through the old launch-then-synchronize path and through the new queue-then-complete
path, in the same process, and the two results compared as raw bytes: both precisions,
both bitwise modes, both backends, workgroup sizes 4, 8, 64 and 256. Sixty-four cases,
sixty-four identical. The `Float32` fast-mode difference between the processor and the
card, `0xc5f5a8beb81e9940` against `0xc5f5a8beb91e9940`, is the fused multiply-add
contraction of decision 0044 and appears identically in both columns.

`Reductions.pairwise_sum` gives one bit pattern per term count across both backends and
workgroup sizes 8, 64, 256 and 1024: `6666666666a49940` at n = 4096,
`9a9999991900d040` at n = 40962, `9a9999993900f040` at n = 163842.

The suite's own statements of the same guarantees all pass: `thread_bitwise.jl` (one
thread against sixteen, as raw bytes, in fresh processes), `bitwise_mode.jl` (both
backends against a 256-bit specification, and against each other),
`backend_agreement.jl` (the processor against the card inside the roundoff bound),
`reference_agreement.jl` (every kernel exactly equal to its naive serial reference), and
`test/reductions/partition_independent.jl`.

## References

- Decision 0038, concurrency from the outset: a barrier after every kernel is the shape
  that record rejects, and it is the argument for this change beyond the microseconds.
- Decision 0029, reproducibility: nothing here is about arithmetic, and the section
  above is the assertion of that.
- Decision 0011, the explicit recorded device move, which is the door the wait went
  into.
- `notes/findings/2026-09-11-device-scalar-reduction-contract.md`, which measured the
  floor this row removes.
