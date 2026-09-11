+++
id = "0044"
title = "Bitwise mode fuses on purpose: every multiply that feeds an add is an explicit fma, and the fusion barrier keeps only the role it is named for"
status = "accepted"
date = 2026-09-11
amends = [{ record = "0029", what = "the mechanism of the bitwise mode: the two backends are brought together by writing the fused operation explicitly rather than by suppressing the device's fusion, so bitwise mode is the once-rounded chain and not the twice-rounded one" }]
+++

## Decision

**In source compiled for bitwise mode, no bare multiply feeds a bare add.** Every such
pair is written as `fma(a, b, c)`. `Backends.nofuse_mul` is not withdrawn; its role
narrows to the one its name describes, a product that has to be rounded on its own
before whatever consumes it sees it, which is what a compensated step needs and what
`src/Backends/transcendentals.jl`'s `cube_root` already uses it for. `muladd` does not
appear in source bitwise mode compiles.

**In source compiled only for fast mode, and in the fast arm of a site compiled for
both, the pair is `muladd(a, b, c)` or a bare multiply and a bare add.** Neither is
determined by the source and fast mode does not ask for one that is; `muladd` is the
spelling to reach for, because it returns the once-rounded value wherever the
compilation reaches it and the twice-rounded value otherwise, and can therefore not be
less accurate than the bare pair. The bare pair stays where exhibiting the unfused
chain is the point of the site. `Orbit.fma_add` is the one spelling of a site compiled
for both modes.

This is one rule with one mechanism, and it is a property of the source rather than of
the compiler: it is auditable by reading, and by the lint the consequences name.
Decision 0029's bitwise mode said "no implicit fused multiply-add" and the barrier was
read as the way to get it. The ban on implicit fusion stands. What changes is that the
way two backends are made to agree is to write the fused operation, not to forbid it:
the device fuses unconditionally, so forbidding fusion means holding the device back to
the processor's answer, and the two backends then agree on a value that is one rounding
step worse than the one the device would have produced for free.

### Why `fma` and not `muladd`

`muladd` is permitted to fuse and not required to. On a target with the instruction it
fuses and is the correctly rounded operation; on a target without it, it becomes a
multiply and an add, two roundings, while the device backend keeps contracting
unconditionally. A bitwise mode built on `muladd` would therefore be bitwise on the
machines that have the instruction and not on the machines that do not, with nothing in
the source changed, no flag set and no error raised. That is the shape of defect the
oracle exists to find, appearing in the oracle itself.

It is not only the target that decides. The same `muladd` fuses or does not according
to the expressions written around it, on one host, at one optimisation level, which
`notes/findings/2026-09-11-the-fast-arm-of-a-multiply-that-feeds-an-add.md` measured:
a plain copy of the same product a line away is enough to make the compiler share one
multiply between them and stop contracting. So the defect is not reached only by
changing machines; it is reached by editing a neighbouring line.

`fma` is required by IEEE 754 to be the single correctly rounded operation, which is a
statement about the value and not about the instruction. Where the instruction exists it
is that instruction; where it does not it is emulated in software, more slowly, and
returns the same bits. Bitwise mode's value is therefore fixed by the standard rather
than by the host, which is what decision 0029 asks of a debugging oracle.

The cost of the emulated form is real and it is paid only by bitwise mode. Production is
fast mode (decision 0029), which runs the unbarriered kernels and lets each backend
contract as it will; the bitwise kernels run on the short case as an oracle. A slower
oracle on a machine without the instruction is the right trade against an oracle that
quietly stops being one. The numbers for both are in
`notes/findings/2026-09-11-fma-against-the-fusion-barrier-in-bitwise-mode.md`.

The reliance is checked rather than assumed, on both backends, because it is the whole
foundation: `test/backends/bitwise_mode.jl` compares `fma` against a single rounding
evaluated at 300 bits over a fixed triple set, on the processor and on the device. Its
positive control is `Backends.nofuse_mul(a, b) + c` rather than the plain `a * b + c`,
because the device contracts the plain form into the operation under test and a control
that cannot fire is not a control.

### The scope of the ban, and what the fast arm is

The rule is not that `fma` is right and `muladd` is wrong wherever they appear. It is
that **bitwise mode's value has to be a function of the source**, and `fma` is the only
one of the three spellings that is. Both of the others return either the once-rounded
or the twice-rounded value depending on something the source does not say: `muladd` on
the target's instruction set and on its own surroundings, the bare pair on the backend,
because the device contracts it unconditionally and the processor does not. That is
why the bitwise-mode arm takes `fma` and takes nothing else.

Fast mode claims nothing that requires a value fixed by the source. Decision 0029 gives
it a measured envelope rather than an identity, and puts the backend and the
environment manifest in the run identity precisely because its answer is a function of
the platform: it already reads the platform's `sin`, `cbrt` and `exp`, and it already
takes whatever contraction each backend applies to a bare multiply and a bare add.
Adding the compiler's contraction decision to that list does not change the kind of
thing fast mode's answer depends on. So the argument that refuses `muladd` has no force
in fast mode, and the unscoped sentence this record opened with claimed more than the
argument under it supported.

What is left in fast mode is accuracy, and there the two admissible spellings are
ordered. Each returns the once-rounded or the twice-rounded value and nothing else, and
the once-rounded value is the correctly rounded one, so `muladd` cannot be less accurate
than the bare pair at the same site and is more accurate wherever the compilation
contracts it. The Kepler solve is where that was measured, in
`notes/findings/2026-09-11-the-fast-arm-of-a-multiply-that-feeds-an-add.md`: reading
this record's unscoped sentence literally cost the production path accuracy at the
highest eccentricity it is sampled at, and the fast arm's `muladd` returns it and gains
more at the lowest.

The fast arm is not `fma`. Production is fast mode (decision 0029), and an `fma` on a
target without the instruction is a software emulation whose cost this record already
records: fast mode would then be paying for a value it never claimed. And a fast mode
whose arithmetic is bitwise mode's arithmetic leaves bitwise mode as an oracle over
nothing but its transcendentals and its reduction trees, which is less of an oracle
than the one decision 0029 asked for.

### The reference path, and fusion the source does not fix

Decision 0027 puts a naive serial reference beside every optimised kernel and asks for
agreement to a tolerance derived from floating point. A fast path that fuses where the
compilation allows can therefore differ from its reference by machine, which is the
portability defect that gets `muladd` refused in bitwise mode, appearing in the arm
where it is tolerated. It is worth stating why it is tolerated rather than assuming it.

The tolerance is derived for the unfused chain, and the unfused chain is the worst case
over every fusion choice. Rounding a product and then rounding the sum admits an error
in the product as well as in the sum; the fused operation rounds once and admits only
the second, so its error is inside the bound derived for the first at every triple. A
tolerance that admits the reference's own chain therefore admits every fused variant of
it, and the 0027 verdict cannot flip from one machine to another on account of fusion.

This is also not a new exposure. With no `muladd` anywhere in the tree, the fast kernel
already agrees with its reference exactly on the processor and to a fraction of the
tolerance on the device, because the device contracts the bare pair on its own; the
numbers are in the finding. The comparison is at a tolerance because that dependence is
already there.

What fusion does break is an *exact* assertion against the reference. Two survive, in
`test/backends/reference_agreement.jl`, and they hold because they run the fast kernel
on the processor, where nothing contracts, against a reference that is then the same
chain: they are statements about one backend and they stay true while those kernels
keep a bare multiply and a bare add. That is why the fast arm is permissive and not
mandatory. `Backends.axpy_fused_kernel!` and `Backends.stencil_gather_fused_kernel!`
exist to exhibit the difference between what the device contracts and what the
processor does not, and a `muladd` in them would erase the thing they measure. A row
that moves either onto `muladd` moves those two assertions onto `Reductions.error_bound`
in the same change. The naive reference itself is never fused and never `muladd`:
decision 0027 fixes that and this record does not touch it.

### What the lint checks

The rule is a property of the source, so it is decided by walking the parsed expression
tree of each file. Two prohibitions:

1. **No bare multiply feeds a bare add in source bitwise mode compiles.** A call to `+`
   or `-` one of whose arguments is a call to `*`, or a `+=` or `-=` whose right-hand
   side is, fails.
2. **No `muladd` in source bitwise mode compiles.** A call to `muladd` there fails,
   whatever its arguments.

A site is in source bitwise mode compiles unless it is one of three things: the false
arm of a conditional whose test is a call to `bitwise`; a site inside a function the
lint's list file names as reached only by fast mode; or a site the list file exempts by
name with its reason. Anything the lint cannot classify is flagged, because a lint that
guessed "fast" for a site whose mode it could not see would pass exactly the defect the
rule exists for.

Two shapes pass by construction rather than by exemption, which is the point of writing
the rule this way: `fma(a, b, c)` passes both prohibitions everywhere, and
`Backends.nofuse_mul(a, b) + c` passes the first because its operand is a call to
`nofuse_mul` and not to `*`.

### The running sum is the shape, not an exception to it

The fused form needs the multiply and the add adjacent in source, and the objection was
that `Backends.stencil_gather_bitwise_kernel!` accumulates into a running sum rather
than performing a bare add. It does, and `acc += a * b` is `acc = a * b + acc`: the
multiply feeds the add and the add's other operand is the accumulator. That is the
fused multiply-accumulate, the operation the instruction is named for, and it is written
`acc = fma(a, b, acc)`. The running sum is not the hard shape; it is the shape.

Measurement rather than inspection, because the question was whether the compiled result
agrees and not whether the source parses: with the accumulation written that way, the
stencil kernel is bitwise identical across the two backends at every cell of the
module's fixture at both element types, and reproduces exactly the chain that rounds
once per term evaluated at 256 bits.

So there is no kernel in the module left on the barrier, and bitwise mode does not carry
two mechanisms. A shape that genuinely cannot be written fused would be a shape in which
some product is required to be rounded separately, and that is `nofuse_mul`'s narrowed
role rather than a second mechanism for the same job: the two are distinguished by what
the algorithm needs, not by what the source happens to look like.

### What the reference path is for

Decision 0027 puts a naive serial reference beside every optimised kernel and asks the
kernel to agree with it "to a tolerance derived from floating point". The reference does
a plain multiply and a plain add. It stays that way: 0027 forbids optimising or fusing
it, and a reference rewritten to match whatever the fast path does stops being an
independent statement of the operation.

What the reference specifies is the operation and its order: which cells are read, which
weights multiply them, in which sequence they are accumulated. It does not specify the
last bit, and it never did; the rounding chain is specified by the arithmetic rule of
decision 0029, which this record fixes. The exact agreement the suite used to assert
between the bitwise kernel and its reference was not the tolerance being tight. It was
the barrier kernel and the reference being the same rounding chain, so the assertion
recorded that identity and nothing beyond it.

The agreement that decision 0027 asks for holds and is asserted at its stated tolerance,
`Reductions.error_bound`. The exact assertion is not dropped, it moves to a better right
answer: the bitwise kernel is asserted equal, bit for bit, to the same computation with
one rounding per term evaluated at 256 bits. That is an identity oracle in the sense of
decision 0026, it is independent of both the kernel and the reference, and it pins the
rounding chain rather than merely observing that two implementations of one chain agree.
Its positive control is the two-rounding chain, which fails it. A reference-agreement
test that compares two things that must differ, and an identity test that names what the
answer is, together decide more than one exact comparison between two spellings of the
same chain did.

## Alternatives considered

- **Keep the barrier everywhere.** The status quo, and it does deliver cross-backend
  identity. Lost on three counts. It reaches identity by discarding accuracy the device
  produces for nothing, so bitwise mode and fast mode differ by more than they need to,
  and every comparison between the two modes carries that gap. It cannot express a
  compensated step at all, which
  `notes/findings/2026-09-11-polynomial-transcendentals-for-bitwise-mode.md` measured on
  `cube_root`, so the module already had to route around it. And it is a rule about what
  the compiler must not do, enforced by a call the compiler is asked not to inline,
  which is a weaker foundation than a rule about what the source says.
- **`muladd` where the source shape allows it, the barrier where it does not.** The
  proposal this row was opened on. Lost on the hardware argument above, and on the
  shape argument: with the running sum written as a fused multiply-accumulate there is
  no "where it does not", so the mixed rule would carry a second mechanism for no case.
- **The ban on `muladd` binds the whole tree, fast mode included.** The reading this
  record's first draft admitted by ending a scoped paragraph with an unscoped sentence,
  and the one `fiddlybits-52v.7.21` acted on. Lost on two counts. Its reason does not
  reach fast mode: `muladd`'s offence is that it may or may not fuse, and fast mode
  neither claims nor can have a value fixed by the source, since it reads the platform's
  transcendentals and takes each backend's own contraction of a bare multiply and a bare
  add. And it costs accuracy in the production path to buy nothing: the bare pair is
  never more accurate than `muladd` at the same site and is measurably less accurate in
  the Kepler solve. A rule whose reason does not reach the case it governs is a rule the
  next reader will break for a good reason and be right to.
- **`fma` in fast mode as well, so that one spelling covers the tree.** Simplest to
  state and to lint, and lost on cost and on what it would do to the oracle. Fast mode
  is production, and an emulated `fma` on a target without the instruction charges
  production for a guarantee it never claimed. It would also leave bitwise mode
  differing from fast mode only in its transcendentals and its reduction trees, so a
  defect in the arithmetic would have no mode that could catch it.
- **`fma` where the source shape allows it, the barrier where it does not.** Right about
  the operation and wrong about the exception, for the same reason: there is no case
  left for the barrier to cover, and leaving it in the rule as a fallback invites a
  future kernel to take the fallback rather than be written in the fused form.
- **Rewrite the naive reference as `fma` so that exact agreement is kept.** Lost to
  decision 0027: the reference is never fused, and one written to agree with the fast
  path by construction cannot catch the fast path being wrong.
- **Drop the exact comparison and keep only the roundoff-bound comparison against the
  reference.** Lost because it weakens the suite to fit the decision. The bitwise
  kernels' output is exactly determined, so a test that only bounds it is refusing to
  state what it knows.
- **Declare hardware fused multiply-add a requirement of every certified backend.**
  Lost: it would make bitwise mode's portability a property of a purchase order, and
  `fma` already gives the same bits without it. The requirement is IEEE 754's
  `fusedMultiplyAdd`, which is a language and standard guarantee rather than a hardware
  one.

## Consequences

- `Backends.axpy_bitwise_kernel!` and `Backends.stencil_gather_bitwise_kernel!` carry
  `fma`; the fused kernels beside them are unchanged and fast mode's tolerance
  (decision 0029) is unchanged.
- Bitwise mode's answer moves for both kernels, toward the once-rounded chain.
  Downstream, any tracked reference hash that covers a bitwise-mode run moves with it
  and carries the `answers:` line decision 0043 requires.
- `Backends.nofuse_mul` stays and its docstring states the narrowed role. A new use of
  it is a claim that the algorithm needs a separately rounded product, and has to say
  which.
- Every multiply that feeds an add in code bitwise mode compiles is a site the rule
  governs, including code outside `src/Backends`. `src/Orbit/kepler.jl` is such a site
  and is still on the barrier; `fiddlybits-52v.7.21` moves it.
- The rule is checked by a lint over the source rather than by a grid, because a grid
  can pass with a contractible site still in place, which
  `notes/findings/2026-09-11-polynomial-transcendentals-for-bitwise-mode.md` measured.
  `fiddlybits-52v.7.22` builds it.
- A target with no hardware fused multiply-add runs bitwise mode correctly and more
  slowly. No profile's production path is affected, because production is fast mode.
- `Orbit.fma_add`'s fast arm is `muladd`, so the fast-mode answer of every site that
  calls it moves toward the once-rounded chain wherever the compilation contracts it.
  The tracked reference hash of decision 0029 covers a fast-mode case and moves with it,
  carrying the `answers:` line decision 0043 requires.
- Fast mode's answer is a function of the compilation as well as of the source, and was
  already a function of the platform's transcendentals. A reference hash that must be a
  function of the source alone is a bitwise-mode case, and there is none tracked yet.
- `Backends.axpy_fused_kernel!` and `Backends.stencil_gather_fused_kernel!` keep a bare
  multiply and a bare add, and `test/backends/reference_agreement.jl` keeps its two
  exact assertions against the naive reference. Either kernel moving onto `muladd`
  carries those two assertions onto `Reductions.error_bound` in the same change.
- The lint of `fiddlybits-52v.7.22` carries two prohibitions rather than one, and a list
  file naming the functions only fast mode reaches.

## References

- The measurements this record turns on, and the three questions it had to settle:
  `notes/findings/2026-09-11-fma-against-the-fusion-barrier-in-bitwise-mode.md`.
- `muladd` unfusing beside a plain copy of the same product on a host that has the
  instruction, what the fast arm's spelling does to the Kepler solve's accuracy in both
  modes, the sample size the cross-backend control needs, and the fast kernel's distance
  from its naive reference on each backend:
  `notes/findings/2026-09-11-the-fast-arm-of-a-multiply-that-feeds-an-add.md`.
- The unconditional contraction on the device, its locator in `GPUCompiler.jl`, and the
  first measurement of the barrier's cost:
  `notes/findings/2026-09-11-gpucompiler-unconditional-fma-contraction.md`.
- The barrier's cost through a Horner chain, and the compensated step it cannot express:
  `notes/findings/2026-09-11-polynomial-transcendentals-for-bitwise-mode.md`.
- IEEE Std 754-2019, "IEEE Standard for Floating-Point Arithmetic", clause 5.4.1
  "Arithmetic operations", the `formatOf-fusedMultiplyAdd` entry: `fusedMultiplyAdd(x,
  y, z)` computes `(x * y) + z` as if with unbounded range and precision, rounding only
  once to the destination format, and differs from a multiplication followed by an
  addition. Read for that clause, which is the whole of what this record relies on.
  `references/pdf/ieee2019-standard-floating-point-arithmetic-754.pdf`.
  DOI: 10.1109/IEEESTD.2019.8766229.
- Higham, N. J. "The accuracy of floating point summation." SIAM Journal on Scientific
  Computing 14 (1993). DOI: 10.1137/0914050. The bound
  `Reductions.error_bound` carries and the reference-path tolerance is read from.

## Amendments

- 2026-09-11: the refusal of `muladd` is scoped to source bitwise mode compiles, rather
  than to the whole tree as one unscoped sentence read; the fast arm of a site compiled
  for both modes is `muladd`, and `Orbit.fma_add` carries it; the reference-path
  question decision 0027 raises is answered from the derivation of its tolerance rather
  than left implicit; the rule is stated as the two prohibitions a lint checks and the
  three exemptions that classify a site. From
  `notes/findings/2026-09-11-the-fast-arm-of-a-multiply-that-feeds-an-add.md`.
