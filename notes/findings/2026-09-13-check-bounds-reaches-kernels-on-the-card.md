# --check-bounds=yes restores the bounds checks inside kernels on the card and on the CPU backend, the nightly's GPU suites run under it, and the gate's checked pass costs a branch that elides a check 282 s of wall against 97

Measured on 2026-09-13 on yggdrasil through `qrun` with this repository's defaults
(profile `gpu-share`, one share of an NVIDIA GeForce RTX 4090, driver 610.57.04, 8 CPUs,
16G), Julia 1.12.7, CUDA.jl 6.3.1 (CUDACore 6.3.1), GPUCompiler 2.6.0,
KernelAbstractions 0.9.42, on branch `fiddlybits-j8o` cut from `e11dac8`. The row is
`fiddlybits-j8o`; decision 0055 is what it settles.

## The four cells

A KernelAbstractions kernel over four work items reading `xs[i + 1]` of a four-element
`xs`, so the last item reads index 5, launched through `Backends.launch!` on
`Backends.CPU(4)` and `Backends.GPU(4)` and completed through `Backends.complete!`. One
process per cell, the default configuration (`Base.JLOptions().check_bounds == 0`) and
`--check-bounds=yes` (`== 1`). The probe scripts first lived in the session scratchpad;
the kernels are now `tools/gate/bounds_probe.jl`, unchanged.

| read | configuration | CPU backend | card |
| --- | --- | --- | --- |
| under `@inbounds` | default | silent: read `[2.0, 3.0, 4.0, 6.9410594111925e-310]` | silent: read `[2.0, 3.0, 4.0, 0.0]` |
| under `@inbounds` | `--check-bounds=yes` | raised at launch: `BoundsError: attempt to access 4-element Vector{Float64} at index [5]` | raised at `complete!`: `Refusal ... KernelException: exception thrown during kernel execution on device NVIDIA GeForce RTX 4090; raised by one of the kernels queued since the last completion: read_past_inbounds!` |
| checked, the control | default | raised at launch: the same `BoundsError` | raised at `complete!`: the same refusal, naming `read_past_checked!` |
| checked, the control | `--check-bounds=yes` | raised at launch | raised at `complete!` |

Where a kernel raised on the card, `Backends.launch!` returned and the card wrote its own
report to stdout before the host's refusal: `ERROR: a BoundsError was thrown during
kernel execution on thread (4, 1, 1) in block (1, 1, 1). Out-of-bounds array access`,
the fourth work item. The process exited 0 in every cell; the refusal was caught.

The checked read raising in the default configuration is the control: index 5 is out of
range for the device array's own check as well as the host's.

A second instrument that faults nowhere: a kernel writing `@inbounds boundscheck_marker()`,
where the marker returns 1.0 when its `@boundscheck` block is compiled and 0.0 when it is
elided. It read `[0.0, 0.0, 0.0, 0.0]` on both backends under the default and
`[1.0, 1.0, 1.0, 1.0]` on both under the flag; the same marker called without `@inbounds`
read all 1.0 in every configuration.

No GPUCompiler or CUDA.jl option was needed. CUDA.jl's device array carries the check
as `@boundscheck index <= length(A) || Base.throw_boundserror(A, index)` in `arrayref`
(`CUDACore/src/device/array.jl`), and the device override of `throw_boundserror`
(`CUDACore/src/device/quirks.jl`) reports it as a kernel exception. As written there
the check compares against the upper bound only; a read at index 0 on the card was not
probed.

## The nightly runs the GPU suites under the flag

`tools/nightly/nightly.sh` was not run: its driver refuses a branch, and `main` does not
yet carry the probe. What was run instead is the driver's own code from the branch,
loaded as `tools/nightly/run.jl` is: `Gate.warm_both`, `Gate.bounds_reach` with the
driver's `EXTRA_FLAGS`, and `Gate.in_process` with `EXTRA_FLAGS` over the two suites that
launch kernels on the card most, through one `qrun` job at the defaults above.

- `EXTRA_FLAGS` is `` `--check-bounds=yes` ``, the gate's `BOUNDS_FLAGS`, and the suite
  command it built was `julia --startup-file=no --warn-overwrite=yes --depwarn=yes
  --check-bounds=yes --project=<worktree> -t 8 -e 'include(raw"<worktree>/test/backends/runtests.jl")'`.
- The probe read `check_bounds = 1`, `marker_cpu = "checked"`, `marker_gpu = "checked"`.
- `backends` passed in 73.9 s and `reductions` in 48.4 s. The backends log carries the
  line its own in-process probe prints, `backends: check_bounds = 1; bounds checks in
  kernels under @inbounds: cpu checked, gpu checked`, and
  `backends.bounds_checks_reach_kernels` passed 21 of 21.

So a suite process the nightly starts compiles the kernels it launches on the card with
the checks restored.

## The gate's checked pass and what it costs

`tools/gate/gate.sh` from the worktree, whose diff against `main` adds
`tools/gate/bounds_probe.jl`, a file with `@inbounds` in two kernels. The run printed:

```
gate: bounds door against main at e11dac8230ee: 1 changed .jl file(s) elide a bounds check; every suite also runs under --check-bounds=yes
gate:   tools/gate/bounds_probe.jl at line(s) 41, 58
gate: the door's 7 controls came out as stated
gate: 17 suites, 8 at once, logs in /tmp/jl_yAY4uG
gate: package warm in 2.5 s, and in 2.5 s under --check-bounds=yes
gate: under --check-bounds=yes kernels under @inbounds read checked on cpu and checked on gpu
```

Every suite passed twice. The seven door controls, run against scratch repositories on
every gate run, took 0.58 s when timed alone. Run on the main checkout at `e11dac8`, the
door read `no changed .jl file elides a bounds check; no checked pass`.

| gate | subject | wall | sum of suites | certify | backends |
| --- | --- | --- | --- | --- | --- |
| with the checked pass | branch `fiddlybits-j8o` | 282.4 s | 1276.2 s | 167.7 s plain, 282.4 s `+bounds` | 132.2 s, 133.0 s `+bounds` |
| without | `main` at `1c07acf` | 97.3 s | 401.1 s | 97.3 s | 77.2 s |

(`main` moved from `e11dac8` to `1c07acf` between the two runs; the baseline is the
later commit.) The branch run shared the machine with a job holding all four GPU shares
and 8 CPUs; the baseline shared it with that job's successor and a 4-CPU build, load
average 7.6 at its start and 10.1 at its end. Neither is quoted as a bench number.

- The checked pass nearly triples the gate's wall on a branch that triggers it. `certify
  +bounds` is the critical path, and the plain `certify` ran 70 s slower than the
  baseline's because the two ran in the same eight-CPU pool at once.
- The `backends` suite costs 132 s in both passes on the branch against 77 s on `main`.
  The probe processes of `test/backends/bounds_reach.jl` took 9.1 s of it under the
  nightly runner's uncontended run; the rest is the contention of 34 processes for 8
  CPUs and one share.
- `pre-push` runs the gate on `main`, where the diff against `main` is empty, so it pays
  the baseline and not the checked pass. The branch run, the one that pays it, is 282.4
  s against the 360 s the remote leaves an idle push open, and is not in a push.
- Nothing refused on video memory with every card-touching suite running twice at the
  profile's 3G cap.
