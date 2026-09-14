# A device kernel still running when its process is killed faulted the card, and every CUDA call of another client's processes failed after it

Measured on 2026-09-14 on yggdrasil, an NVIDIA GeForce RTX 4090 on driver 610.57.04, Julia
1.12.7, CUDA.jl and CUDACore 6.3.1. The row is `fiddlybits-52v.6.26`. The subject is a test
fixture kernel of `test/provenance/writer.jl` that loops until a device cell stops holding a
sentinel, held on the card while the writer's later submissions finish.

## The setting

- Every `qrun` job with a share of the card is a client of one NVIDIA MPS server,
  `nvidia-cuda-mps-server`, pid 82924 (`nvidia-smi --query-compute-apps`). `qrun spec` states
  that the per-job memory cap is enforced through MPS; the card's compute mode is Default.
- The fixture kernel read its gate cell from device memory, and the release was a `copyto!` of
  a host `Array` into that cell from a second task, queued with `async = true` on that task's
  stream (CUDACore `src/array.jl`, lines 590-608).

## What happened

- 04:33:04. Job 2934 started a break run of the writer's order arm, the disk stage waiting in
  submission order, in process 1273230. The arm's wait on the later submissions ran to its
  60 s bound, and the `finally` queued the release write and then waited on the gate kernel's
  handoff.
- 04:48. The run's `timeout 900` sent SIGTERM. The process printed `signal 15: Terminated`
  and a backtrace with its main task in `Backends.after!` at `test/provenance/writer.jl:153`,
  waiting on the gate kernel's handoff event, and two CUDA synchronization worker threads in
  `cuEventSynchronize`. The process did not exit.
- Until 05:09. The process stayed alive with the card busy, as did job 2944, a gate of this
  worktree whose provenance suite stopped printing at 04:52, after the late-refusal arm's
  deliberate out-of-range kernel reported its `BoundsError`.
- 05:09:40.168 and 05:09:40.196. `slurmctld` logged `REQUEST_KILL_JOB` for jobs 2944 and 2934.
- 05:09:40. The kernel logged
  `NVRM: Xid (PCI:0000:01:00): 31, pid=1273230, name=julia, channel 0x0000003e, intr 00000000. MMU Fault: ENGINE GRAPHICS GPC3 GPCCLIENT_GCC faulted @ 0x100_05252000. Fault is of type FAULT_PDE ACCESS_TYPE_VIRT_READ`.
  It is the only Xid in `journalctl -k` since 04:30.
- 05:09:42. Job 2950, the gate of the main checkout and another client of the same server,
  wrote `CUDA error: an illegal memory access was encountered (code 700, ERROR_ILLEGAL_ADDRESS)`
  in its reductions suite (`/tmp/jl_cT2Vrc/reductions.log`, last written 05:09:42), and every
  later CUDA call in that process failed.
- 05:10:20. The same error in that gate's provenance suite (`/tmp/jl_cT2Vrc/provenance.log`,
  last written 05:10:20). The code that gate ran had passed the gate in its own worktree.

## What is established and what is not

- Established: a process killed while its kernel was running on the card was followed, in the
  same second, by an MMU fault in that process's name, and within two seconds by illegal address
  errors in the processes of another job sharing the card through the same MPS server.
- Established: Julia runs `atexit` hooks on SIGTERM. A process started with `timeout -s TERM 8`
  printed `signal 15: Terminated` and its hook ran; `/usr/share/julia/base/initdefs.jl`, lines
  406 and 420, state that hooks run last in, first out.
- Not established: why the queued release write did not end the gate kernel in process
  1273230. The same kernel and release ended at once when the hold lasted seconds with no other
  GPU job running, in a proof run and in two unbroken runs of the arms. Here the hold had lasted
  the full 60 s bound, and other GPU jobs were running on the card.
- Not established: whether the fault reached the other processes through the MPS server's
  shared context or through the driver's teardown of the killed process alone. The timing and
  the shared server are the evidence; no source for the mechanism was read.
