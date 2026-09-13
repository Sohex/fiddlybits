+++
id = "0051"
title = "A kernel may carry a form specialised to the device beside its portable form, when the device form keeps the portable form's arithmetic order, is tested bitwise against it on the device, and is measured faster there"
status = "accepted"
date = 2026-09-13
amends = [{ record = "0011", what = "every kernel written once and run on both backends: every kernel still has one portable form, which is what the CPU backend runs, and a kernel may also carry a second form that the GPU backend runs instead, under the conditions this record states" }]
+++

## Decision

**The project is GPU-native first.** Where a kernel can be made significantly faster on
the GPU backend by a form the CPU backend cannot run well, the faster form is taken.
Divergence between the backends is still the cost it was in decision 0011, so it is
taken only where it pays, and a single text that serves both is preferred whenever one
exists.

**Every kernel keeps its portable form.** It is written once against
KernelAbstractions, it is what the CPU backend runs, and it stays launchable on the GPU
backend. A kernel may carry, beside it, a device form: a second KernelAbstractions
kernel the GPU backend runs in its place. Both are portable-layer kernels; neither is
vendor code.

**A device form is admitted under four conditions, all of them.**

1. **The same arithmetic in the same order.** The device form computes the same terms,
   rounds them the same way and accumulates them in the same order as the portable
   form. It may change where the operands are read from and how the work is laid out
   on the device; it may not change what is added to what, or when.
2. **Tested bitwise against the portable form on the device.** A test in the tree
   launches both forms on the GPU backend over the same inputs and requires the
   results to be bitwise identical, over the shapes that exercise the layout: every
   block or segment full, a partial last one, one shorter than a block, a single
   element, a second block or segment length, and each accumulator and element type
   the reduction accepts. The test carries a positive control showing it can tell a
   changed element apart. This test is what says the two texts agree; a CPU-against-GPU
   comparison no longer does, because it compares two texts.
3. **Measured faster on the device.** The gain is measured on the registered benchmark
   bed before and after, against that bed's A/A scatter, and recorded in a finding.
   The dispatch names the finding by path.
4. **Chosen at one door, by backend type.** The form is selected by a method on the
   backend type at the function that launches the kernel, never by a flag, a keyword or
   a branch inside a kernel. Refusals, argument checks and result types sit above that
   door and are the same for both forms.

**The reference path is untouched.** Decision 0027's naive serial reference is
unaffected by a device form and is still what both forms are checked against for
correctness.

**A device form is removed when it stops paying.** A single text that reaches the device
form's performance on the GPU backend without costing the CPU backend replaces both.

## Alternatives considered

- **Keep one text and forgo the gain.** The reading of decision 0011 that the block-sum
  row was reviewed against. It holds the backends to one text at the price of the GPU
  path, which is the production path. Lost: the project is GPU-native first, and a
  bitwise-identical speed-up on the production device is not one to decline for the
  sake of the fallback.
- **One text, the device form, on both backends.** Keeps decision 0011 whole. Lost on
  the block sums: KernelAbstractions backs `@localmem` on the CPU backend with a buffer
  per workgroup, so the shared-memory form allocates about its input's size on every
  call there, which breaks the rule that a reduction allocates no temporary the size of
  its input, and it is slower on the CPU backend than the form it would replace. The
  probe is in the notes of `fiddlybits-2tg`.
- **Separate CPU and GPU code paths, as ClimaComms has them.** Decision 0012 rejected
  ClimaComms for this, and the rejection stands. What differs here is what keeps two
  texts honest: both are kernels of the one portable layer, the portable form still
  runs on the device, and the two are held bitwise identical there by a test in the
  tree. ClimaComms' CPU path is a different programming model with no such test.
- **Vendor-specific GPU code for the fast path.** Lost for the reason decision 0011
  gave: the portable layer is what lets the CPU backend be the fallback and the debug
  path, and a device form written in it keeps that.
- **Admit a device form on measurement alone.** Lost: a faster form that rounds or
  accumulates differently changes answers, and decision 0029 does not allow the device
  to be where an answer changes.

## Consequences

- `Reductions.pairwise_block_sums` and `Reductions.area_weighted_block_sums` are the
  first kernels with a device form. The door is `Reductions.launch_block_sums!`, the
  bitwise test is `test/reductions/shared_block_kernels.jl`, and the measurement is
  `notes/findings/2026-09-13-block-sums-in-shared-memory.md`.
- The portable forms of those two stay in the tree and run on the CPU backend; the
  bitwise test launches them on the GPU backend as its comparison.
- `fiddlybits-zgh` may give the segmented kernels a device form under the same four
  conditions.
- The reviewer's checklist in `docs/workflow.md` asks, of a merge that adds a device
  form, for the bitwise test on the device and the finding the dispatch names.
- The scope of `docs/plans/fiddlybits-52v.7-kernels.md` and
  `docs/requirements/num/thread-invariance-and-backend-agreement.md` name this record
  where they state that the backends run the same kernels.
- Nothing checks mechanically that a second kernel for one reduction meets the
  conditions; the review does. A kernel that grows a device form without its bitwise
  test is caught at merge, not at commit.

## References

- Decision 0011, the portable kernel layer and the CPU backend as fallback and debug
  path; decision 0012, the ClimaComms verdict on separate CPU and GPU code paths;
  decision 0027, the naive serial reference path; decision 0029, fixed-order reductions
  and bitwise reproducibility.
- `notes/findings/2026-09-13-block-sums-in-shared-memory.md`, the before and after on the
  benchmark bed and the bitwise identity of the registered cases.
- `notes/findings/2026-09-12-reduction-bench-scatter.md`, the bed's A/A scatter a gain is
  measured against.
- `fiddlybits-2tg`, the row whose review raised this, and its notes for the CPU probe;
  the direction to take option one was given on 2026-09-13.
