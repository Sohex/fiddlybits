# Two tasks sharing a device array: the library's door is a host stop, and an event is the one this module states

Measured on 2026-09-11 on yggdrasil through `qrun` with this repository's defaults
(profile `gpu-share`, one share of an NVIDIA GeForce RTX 4090, driver 610.57.04, 8
CPUs, 16G), Julia 1.12.7, CUDA.jl 6.3.1, KernelAbstractions.jl 0.9.42, on branch
`fiddlybits-52v.7.52`. The card was otherwise quiet. The row is
`fiddlybits-52v.7.52`, raised by path 2 of
`notes/findings/2026-09-11-a-launch-that-queues-and-a-completion-that-is-stated.md`,
which is the one path of that argument with no door in this module and no check.

## What path 2 said and what was missing

`Backends.launch!` queues on the stream of the task that calls it, and CUDA.jl gives
each Julia task its own stream, so two launches from two tasks are not ordered by the
stream. What ordered them was CUDA.jl's per-array ownership: converting a `CuArray`
to a device pointer calls `take_ownership!`, which synchronizes the previous owning
stream whenever `managed.stream != stream`. That is a library behaviour this module
stated nowhere, and it is not available to be checked, because with it in place the
two tasks are already ordered and a control cannot fail.

## The door

Three names in `src/Backends/launch.jl`.

`handoff(backend)` returns a `Handoff`, which on `GPU` is a CUDA event recorded on the
stream the calling task queues on, and on `CPU` carries nothing, a CPU launch having
run every work item before it returned.

`after!(backend, point)` orders everything the calling task queues after it behind the
work `point` stands for. On `GPU` that is `cuStreamWaitEvent`, a wait on the device:
the host returns at once. On `CPU`, whose launch runs the kernel before it returns,
there is nowhere else to put the wait and the host waits for the event there.

`order_explicitly!(array)` takes an array out of CUDA.jl's per-array bookkeeping
through `CUDA.enable_synchronization!`, so that `handoff` and `after!` are what order
it. Without this the module would have two definitions of one ordering; with it the
control below can fail.

## The measurement

A producer task queues a spin kernel writing `out`, hands its queue point over through
a channel, and a consumer task doubles `out` into `result`. One work item per cell,
four cells, the spin count calibrated so the kernel runs 266.7 ms, 20 repeats.

| arm | consumer's result |
| --- | --- |
| `order_explicitly!`, consumer calls `after!` | the finished write, 20 of 20 |
| `order_explicitly!`, consumer does not | the sentinel, 20 of 20 |
| library ordering left on, consumer does not | the finished write, 20 of 20 |

The second row is the positive control and it fires on every repeat: with the library's
door shut and this module's door unused, the consumer reads what the producer had not
yet written. The third row is path 2's claim, and it holds.

What the third row costs is the point of the first:

| the consumer's `launch!` | min (ms) | median (ms) |
|---|---|---|
| ordered by `after!` | 0.00 | 0.00 |
| ordered by the library's ownership transfer | 266.9 | 267.9 |

The library's ordering is a host stop for the whole of the producer's kernel, inside
the consumer's launch, where nothing names it. That is the barrier decision 0038
rejects, arrived at by accident rather than by choice.

The door itself, while the producer's kernel is running:

| call | min | median |
|---|---|---|
| `after!(gpu, point)` | 0.95 us | 0.95 us |
| `complete!(gpu)` immediately after it | 266.7 ms | 267.4 ms |
| `after!(cpu, point)` | 266.7 ms | 267.7 ms |

The second line is what gives the first its meaning: the work was still outstanding
when `after!` returned, so the microsecond is a queued wait and not an early finish.
The third is the same point waited for on the host, which is the shape the first has
to be able to reject.

On an idle stream, minimum of 20 runs of 1000 calls each:

| call | us |
|---|---|
| `handoff(gpu)` | 0.23 |
| `after!(gpu, point)` | 0.12 |
| the pair | 0.37 |
| `complete!(gpu)` | 0.25 |

A handoff and its wait cost about what one completion costs, and neither stops the
host.

## What the evidence does not cover

A race does not fail reliably and a green suite is not a proof of ordering. What the
control says is that the failure this door prevents is real and was observed on every
repeat of this shape, so the ordered arm is a check. Nothing here says anything about
a device backend other than CUDA, because there is none; on a backend with no
per-array ownership at all, the third row of the first table would read like the
second, and `after!` is then the only thing between the two tasks.

`order_explicitly!` is a property of the allocation and not of the array object, so it
reaches every array sharing that memory. Nothing in `src/` calls it yet: the first
caller is the first component built to the shape of decision 0038.

## A timing check that was measuring the compiler

`test/backends/launch_completion.jl` asserted `t_complete > whole / 2` and failed
about one run in three. `elapsed` compiles a specialization for every closure it is
handed, and that compilation was tens of milliseconds against a 50 ms kernel: the
kernel finished while the compiler ran between the two measurements, and the
completion then measured nothing. Each shape is now written once and run twice, once
over a one-spin kernel to compile it and then over the calibrated one, and the
calibration target was raised so the host-side scatter stays well under the fractions
asserted. Six consecutive runs passed after the change.

## References

- Decision 0038, concurrency from the outset: the barrier this door replaces.
- Decision 0011, the device abstraction.
- `notes/findings/2026-09-11-a-launch-that-queues-and-a-completion-that-is-stated.md`,
  path 2, which named the gap.
- `docs/plans/fiddlybits-52v.7-kernels.md`, section "The device layer".
