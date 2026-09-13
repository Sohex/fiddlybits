+++
id = "0055"
title = "A kernel text may read and write under @inbounds behind a length check at its door and the edge-shape tests beside it, host code stays checked, and a change to a file that elides a check runs every suite under --check-bounds=yes before it merges"
status = "accepted"
date = 2026-09-13
amends = [{ record = "0050", what = "the position that this tree elides no bounds check of its own: elision is admitted inside kernel texts under the conditions this record states, host code stays checked, the nightly's source assertion becomes an assertion that every elision sits inside a kernel, and the flag decision 0050 kept off the gate is carried by the gate's second pass whenever a change touches a file that elides a check" }]
+++

## Decision

**`--check-bounds=yes` restores the checks inside kernels on both backends.** A
KernelAbstractions kernel launched through `Backends.launch!` that reads one past its
array under `@inbounds` reads silently under the default on the CPU backend and on the
card, and raises under the flag on both: at the launch on the CPU backend, and at
`Backends.complete!` on the card, as a `KernelException` naming the kernel. The same
read without `@inbounds` raises in both configurations, which is the control that the
index is out of range. The flag reaches the card because CUDA.jl compiles a kernel in
the process that launches it, under that process's options, and its device array
carries the check as a `@boundscheck` block
(`notes/findings/2026-09-13-check-bounds-reaches-kernels-on-the-card.md`). No GPUCompiler
or CUDA.jl option is needed beside it.

**Where elision is admitted.** `@inbounds` is admitted inside the body of a
KernelAbstractions `@kernel` function, on a read or a write whose index is bounded by
the check at the kernel's door. Nowhere else in `src/`: host code stays checked,
because the only elisions host code ever carried bought nothing measurable
(`notes/findings/2026-09-12-what-seven-inbounds-annotations-buy.md`), while the kernel's
serial loop pays for its checks on every read on the card
(`notes/findings/2026-09-13-the-per-lane-block-kernel-pays-for-one-thread-s-checked-serial-reads.md`).
`@kernel inbounds=true` is not admitted: it elides every check in the body, including
reads the door check was not written to bound, and leaves no site a reader can hold
against the door.

**What stands beside every elision.** All three, for each kernel that carries one:

1. **A length check at its door.** The function that launches the kernel checks, on the
   host and before the launch, every length the kernel's indices are derived from: that
   each array it reads or writes holds at least as many elements as the largest index
   the work item count and its arguments reach. A length that does not hold refuses
   through `Verdicts.refuse`, naming the array and both lengths. A test carries the
   positive control: an argument one element short refuses.
2. **Tests over the edge shapes.** The kernel is run on both backends over the shapes
   where an index derived from a count is most likely to be wrong: a single element,
   fewer elements than one block or segment, a partial last block, every block full, a
   second block or segment length, and each element and accumulator type the function
   accepts. Each agrees with its reference path (decision 0027). These are the shapes
   decision 0051 already names for a device form, now required of any kernel that
   elides a check whether or not it has one.
3. **A measured gain.** The elision is an optimisation, and it is taken where a finding
   measures it on the bed its kernel is benchmarked on, cited by path from the plan or
   the dispatch that takes it. An elision nobody measured is what decision 0050 removed.

**The nightly bed runs every suite under the flag, and checks that it reaches the
kernels first.** `tools/nightly/run.jl` runs the bounds probe of `tools/gate/bounds_probe.jl`
under the flag before any suite, and refuses the night unless kernels launched under
`@inbounds` read as checked on the CPU backend and on the card; the night's record
carries what the probe read. The source assertion of decision 0050, that no file under
`src/` carries `@inbounds`, is replaced by the assertion that every elision in `src/`
sits inside a `@kernel` body, read from the parsed source by `Gate.elision_sites`.

**The gate runs a second pass under the flag when a change elides a check.** Before any
suite, `tools/gate/run.jl` diffs the working tree against its merge base with `main`,
committed, staged, unstaged and untracked alike, parses every changed `.jl` file, and
names each that elides a bounds check: an `@inbounds`, a `@kernel inbounds=true`, or
an `Expr(:inbounds, ...)` built in code. When one does, every suite also runs under
`--check-bounds=yes` in the same pool as the plain pass, after the bounds probe has
read the checks on both backends under that flag. The gate prints what the door found,
at the start of the run and again after the report. A detector that decides whether a
pass runs is itself controlled on every run: the gate runs it on scratch repositories
whose answer is known, a change to a file carrying `@inbounds` and one without, a
docstring naming the macro, an untracked file, a committed change and a forced
`@kernel`, and refuses unless each comes out as stated.

**Every suite, not the suites the change reaches.** The checked pass runs the whole
suite, for the reason decisions 0049 and 0050 refused a map from paths to suites: a map
that misses the suite a change breaks fails silently, and an out-of-range index in a
kernel is exactly the fault that shows up in a caller's suite rather than the kernel's
own.

**The backends suite holds the four cells on every run.** `test/backends/bounds_reach.jl`
runs the probe under the default and under the flag, each in its own process with its
flag stated, and asserts the table above, including the checked-read control. A
dependency upgrade that stopped the flag reaching the card fails the gate at the commit
that brings it in.

## Alternatives considered

- **Keep this tree free of elisions, as decision 0050 left it.** Rejected on the
  measurement: on the card the largest single part of a reduction kernel's cost is the
  check on each read of its serial loop, and a single `@inbounds` text reaches or beats
  a device form that exists only to avoid it. Declining it trades speed on the
  production device for a guarantee that the door check and the checked passes give.
- **Carry `--check-bounds=yes` on every gate run.** Rejected for the push window, as in
  decision 0050: the flag's cost is almost all `certify`, and `pre-push` runs the gate on
  `main`. The door carries it on exactly the runs that need it; on `main` after a merge
  the diff against `main` is empty, so `pre-push` pays nothing for it.
- **A named door in the executor loop instead of the gate.** An executor would run a
  second command when a row touches a file with `@inbounds`. Rejected: it relies on the
  executor noticing, which is the silent skip the row forbids. The gate is already the
  command every executor runs and every reviewer checks, and a door inside it cannot be
  forgotten without forgetting the gate.
- **Detect by searching the text for `@inbounds`.** Simpler, and wrong in both
  directions: a docstring naming the macro runs a pass for nothing, and a
  `@kernel inbounds=true` is not found. The parsed source answers the question asked.
- **Run the checked pass after the plain pass rather than in the same pool.** Rejected
  under decision 0038: two passes over one pool of workers is one queue, and a barrier
  between them makes the plain pass the unit of waiting.
- **Compare against the upstream `origin/main`, so `pre-push` on `main` would run the
  checked pass over a merged change that skipped it.** Rejected: it puts a pass that
  roughly doubles the gate's wall time on the hook the remote's idle timeout bounds,
  exactly on the pushes that carry an elision. The reviewer's checklist reads the door's
  lines in the branch's gate output, and the nightly runs every suite under the flag
  against `main` regardless.
- **A GPUCompiler or CUDA.jl debug option for the card.** Not needed: the flag reaches
  the card's kernels, measured.

## Consequences

- `fiddlybits-2c9` applies this to the reduction kernels. Its change fails the nightly
  suite's current assertion that `src/` carries no `@inbounds`, and replaces that
  assertion with the one this record states, reading `Gate.elision_sites`.
- A change to a file that elides a check costs the gate a second pass of every suite
  on its branch, with both passes printed per suite. The time is measured in the
  finding; the push window is untouched, because `pre-push` runs on `main`.
- An out-of-range index that a change introduces without touching an eliding file,
  by changing the lengths a caller passes, is caught first by the door check, which
  refuses in every configuration, and otherwise by the nightly, a night late.
- A kernel written inside a string, as a test's child process sometimes carries one, is
  not seen by the door; the nightly still runs it under the flag.
- The reviewer's checklist in `docs/workflow.md` asks for the door's lines from the
  branch's gate run, and the executor loop names them.
- The four cells are re-measured by the backends suite on every gate run, so the claim
  this record rests on is held rather than inherited across dependency upgrades.

## References

- `notes/findings/2026-09-13-check-bounds-reaches-kernels-on-the-card.md`, the four
  cells, the checked-read control, the nightly runner on the GPU suites, and the gate's
  cost with and without the checked pass.
- `notes/findings/2026-09-13-the-per-lane-block-kernel-pays-for-one-thread-s-checked-serial-reads.md`
  and `notes/findings/2026-09-13-the-segmented-kernels-shared-memory-form-is-slower-on-every-bench-case.md`,
  what the checks cost on the card.
- `notes/findings/2026-09-12-what-seven-inbounds-annotations-buy.md`, what they bought in
  host code.
- Decision 0043, the nightly row; decision 0049, the gate's wall time as a bound and the
  refusal of a path-to-suite map; decision 0050, the record amended; decision 0051, the
  edge shapes; decision 0027, the reference path; decision 0038, one pool rather than a
  barrier.
- `CUDACore/src/device/array.jl`, `arrayref` and `arrayset`, the `@boundscheck` on a
  device array's index, and `CUDACore/src/device/quirks.jl`, `throw_boundserror` as a
  reported kernel exception; `KernelAbstractions/src/macros.jl`, `inbounds=true`.
