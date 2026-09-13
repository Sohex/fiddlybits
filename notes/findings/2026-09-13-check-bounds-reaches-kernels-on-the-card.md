# --check-bounds=yes restores the upper bounds check inside kernels on the card and both checks on the CPU backend; the card checks no lower bound in any configuration; the nightly's GPU suites run under the flag; the gate's checked pass costs a branch that elides a check 282 s of wall against 97

Measured on 2026-09-13 on yggdrasil through `qrun` with this repository's defaults
(profile `gpu-share`, one share of an NVIDIA GeForce RTX 4090, driver 610.57.04, 8 CPUs,
16G), Julia 1.12.7, CUDA.jl 6.3.1 (CUDACore 6.3.1), GPUCompiler 2.6.0,
KernelAbstractions 0.9.42, on branch `fiddlybits-j8o` cut from `e11dac8`. The row is
`fiddlybits-j8o`; decision 0055 is what it settles.

## The cells

A KernelAbstractions kernel over four work items writing `out[i] = xs[i + offset]`,
launched through `Backends.launch!` on `Backends.CPU(4)` and `Backends.GPU(4)` and
completed through `Backends.complete!`, once with the read under `@inbounds` and once
without. The kernels are `tools/gate/bounds_probe.jl`. Four reads:

- **past the end**: a four-element `xs`, offset +1, so the last item reads index 5;
- **index 0**: a four-element `xs`, offset -1, so the first item reads index 0;
- **negative**: a sixteen-element `xs`, offset -8, so every item reads an index from -7
  to -4;
- **index 0 of a view**: `xs = view(parent, 5:8)` of an eight-element `parent`, offset
  -1, so the first item reads index 0 of the view, which is `parent[4]`. On the card the
  view is a `CuArray{Float64, 1, CUDACore.DeviceMemory}` over the parent's memory; on the
  CPU backend it is a `SubArray`. This is the shape of a read one below a block or
  segment start inside a larger array.

One process per cell, under `--check-bounds=auto` (`Base.JLOptions().check_bounds == 0`,
the default) and `--check-bounds=yes` (`== 1`). "launch" and "completion" say where the
error surfaced.

### CPU backend

| read | `@inbounds`, default | `@inbounds`, flag | checked, default | checked, flag |
| --- | --- | --- | --- | --- |
| past the end | silent | `BoundsError` at launch, index [5] | `BoundsError` at launch | `BoundsError` at launch |
| index 0 | silent | `BoundsError` at launch, index [0] | `BoundsError` at launch | `BoundsError` at launch |
| negative | silent | `BoundsError` at launch, index [-7] | `BoundsError` at launch | `BoundsError` at launch |
| index 0 of a view | silent, read `[4.0, 5.0, 6.0, 7.0]` | `BoundsError` at launch, index [0] of the view | `BoundsError` at launch | `BoundsError` at launch |

### The card

| read | `@inbounds`, default | `@inbounds`, flag | checked, default | checked, flag |
| --- | --- | --- | --- | --- |
| past the end | silent, read `[2.0, 3.0, 4.0, 0.0]` | `KernelException` at completion | `KernelException` at completion | `KernelException` at completion |
| index 0 | illegal memory access at completion | illegal memory access at completion | illegal memory access at completion | illegal memory access at completion |
| negative | illegal memory access at completion | illegal memory access at completion | illegal memory access at completion | illegal memory access at completion |
| index 0 of a view | silent, read `[4.0, 5.0, 6.0, 7.0]` | silent, read `[4.0, 5.0, 6.0, 7.0]` | silent, read `[4.0, 5.0, 6.0, 7.0]` | silent, read `[4.0, 5.0, 6.0, 7.0]` |

A `KernelException` is the refusal `Backends.complete!` raises carrying `KernelException:
exception thrown during kernel execution on device NVIDIA GeForce RTX 4090; raised by one
of the kernels queued since the last completion: read_past_inbounds!` (or
`read_past_checked!`), after the card wrote its own report to stdout: `ERROR: a
BoundsError was thrown during kernel execution on thread (4, 1, 1) in block (1, 1, 1).
Out-of-bounds array access`. An illegal memory access is the refusal carrying `CUDA
error: an illegal memory access was encountered (code 700, ERROR_ILLEGAL_ADDRESS)`, with
no kernel report before it. The process exited 0 in every cell; the refusal was caught.

A marker kernel writing `@inbounds boundscheck_marker()`, where the marker returns 1.0
when its `@boundscheck` block is compiled and 0.0 when it is elided, read all 0.0 on both
backends under the default and all 1.0 on both under the flag; the same marker called
without `@inbounds` read all 1.0 in every configuration. It reads nothing out of range.

## What the cells say

**Past the end, the flag restores the check on both backends.** The checked read raises
in both configurations, which is the control that index 5 is out of range for the device
array's own check. No GPUCompiler or CUDA.jl option was needed: CUDA.jl's device array
carries the check as `@boundscheck index <= length(A) || Base.throw_boundserror(A, index)`
in `arrayref` (`CUDACore/src/device/array.jl`), and the device override of
`throw_boundserror` (`CUDACore/src/device/quirks.jl`) reports it as a kernel exception.

**Below index 1, the card checks nothing in any configuration.** The device array's check
is that one comparison against the length. Index 0 and the negative indices faulted
whether or not the read was under `@inbounds` and whether or not the flag was passed, and
with a memory fault rather than a kernel exception: each array in those cells was its own
allocation, and the address before it was not mapped. Index 0 of a view, whose address
lies inside the parent's allocation, read the parent's element silently in all four
configurations, the checked read under the flag included. What an out-of-range read below
index 1 does on the card is therefore a property of where the array sits in device memory,
not of any check.

**Below index 1, the CPU backend checks under the flag.** Every one of the four reads
raised a `BoundsError` naming the index under the flag, with or without `@inbounds`, the
view included; Base's check reads both bounds of the array's axes. So the lower bound of a
kernel text's indices is checked by running that text on the CPU backend under the flag,
and by nothing on the card.

No cheap way to restore a lower-bound check on the card was found inside this tree. The
check sits in CUDACore's `arrayref`; replacing it would be a device override of a
dependency's method from this package.

## The nightly runs the GPU suites under the flag

`tools/nightly/nightly.sh` was not run: its driver refuses a branch, and `main` does not
yet carry the probe. What was run instead is the driver's own code from the branch,
loaded as `tools/nightly/run.jl` is: `Gate.warm_both`, `Gate.bounds_reach` with the
driver's `EXTRA_FLAGS`, and `Gate.in_process` with `EXTRA_FLAGS` over the two suites that
launch kernels on the card most, through one `qrun` job at the defaults above, before the
lower-bound arms were added.

- `EXTRA_FLAGS` is `` `--check-bounds=yes` ``, the gate's `BOUNDS_FLAGS`, and the suite
  command it built was `julia --startup-file=no --warn-overwrite=yes --depwarn=yes
  --check-bounds=yes --project=<worktree> -t 8 -e 'include(raw"<worktree>/test/backends/runtests.jl")'`.
- The probe read `check_bounds = 1`, `marker_cpu = "checked"`, `marker_gpu = "checked"`.
- `backends` passed in 73.9 s and `reductions` in 48.4 s. The backends log carries the
  line its own in-process probe prints, `backends: check_bounds = 1; bounds checks in
  kernels under @inbounds: cpu checked, gpu checked`, and
  `backends.bounds_checks_reach_kernels` passed.

So a suite process the nightly starts compiles the kernels it launches on the card with
the upper bound check restored, and the kernels it launches on the CPU backend with both.

## The gate's checked pass and what it costs

`tools/gate/gate.sh` from the worktree at `2acb9db`, whose diff against `main` adds
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
| with the checked pass | branch `fiddlybits-j8o` at `2acb9db` | 282.4 s | 1276.2 s | 167.7 s plain, 282.4 s `+bounds` | 132.2 s, 133.0 s `+bounds` |
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

## The gate at this revision, with the lower-bound arms

Two runs of `tools/gate/gate.sh` from the worktree with the lower-bound arms in
`tools/gate/bounds_probe.jl` and `test/backends/bounds_reach.jl`, each sharing the
machine with a job holding all four GPU shares and 8 CPUs. Both printed:

```
gate: bounds door against main at e11dac8230ee: 1 changed .jl file(s) elide a bounds check; every suite also runs under --check-bounds=yes
gate:   tools/gate/bounds_probe.jl at line(s) 58, 75
gate: the door's 7 controls came out as stated
gate: under --check-bounds=yes kernels under @inbounds read checked on cpu and checked on gpu
```

- The first run failed one assertion in the plain `reductions` pass: the positive control
  of `kernels.reduction_partition_independent` that five 16-thread atomic accumulations
  are not all equal to the one-thread total (`test/reductions/partition_independent.jl`,
  line 99). All five were equal. Its `reductions+bounds` twin passed, as did every other
  suite in both passes; wall 279.8 s, load average 7.4 at the start and 6.9 at the end.
  That control depends on the operating system interleaving sixteen threads, and a pool
  of 34 processes on 8 CPUs gives it less interleaving than the plain gate's 17. Making
  that control independent of scheduling is `fiddlybits-52v.7.56`.
- The second run passed every suite in both passes: wall 273.7 s, sum of suites 1354.9 s,
  `certify+bounds` 273.7 s, `certify` 176.1 s, `backends` 137.8 s and `backends+bounds`
  144.2 s; load average 5.1 at the start and 7.8 at the end.
