# BracketingNonlinearSolve

**What it is.** The bracketing half of `NonlinearSolve.jl`, now a subpackage of it
(`lib/BracketingNonlinearSolve`): bisection, Brent, regula falsi, Ridder, Alefeld, the
modified Anderson-Bjorck method, Muller, and ITP, the Interpolate-Truncate-Project method
of Oliveira and Takahashi, whose worst case is no worse than bisection and whose average
behaviour is superlinear. Each solver is a method of `SciMLBase.__solve` on an
`IntervalNonlinearProblem` and returns a solution object carrying a return code.

**What of it is used.** Nothing. ITP's algorithm is read as an algorithmic reference.

**Licence.** MIT. **Version.** 1.12.6. **Read at.**
`0dccd34d125638394c2f3e5e53be3b5e272896a0`, committed 2026-09-07, in
`/home/cfutro/git/SciML/NonlinearSolve.jl`. Run on the RTX 4090 and on the processor:
`notes/findings/2026-09-10-kepler-in-a-portable-kernel.md`.

**Verdict.** Do not adopt. The solvers do not compile for a CUDA backend inside a
`KernelAbstractions` kernel, and the reason is structural rather than incidental: a
logging call on each solver's refusal branch. The loops themselves are exemplary and ITP
is worth reading before this project's own bracketing loop is written.

## The portable-kernel launch test, and what it found

The row asked for the test the survey said was missing: the same in-kernel solve the
package demonstrates under `CUDA.@cuda`, run instead under
`KernelAbstractions.@kernel` on both backends. It was written and run, four ways, with
`ITP()` and `Bisection()`, each with the problem built inside the kernel body and with a
problem built on the host and passed in. All four run on the processor backend. All four
fail to compile for the CUDA backend.

The cause is named in the stack trace and is not the solve loop. Each solver carries a
`@SciMLMessage` on the branch that reports a bracket whose endpoints do not straddle the
root (`bisection.jl:45`, `itp.jl:82`, and the same construction in `brent.jl`,
`falsi.jl`, `ridder.jl` and `modAB.jl`). That macro reaches `SciMLLogging.emit_message`,
which is a dynamic dispatch through `jl_f_invokelatest` with a lock and a symbol
construction behind it. A device compiler must compile every reachable branch, so a
refusal that never fires still has to be device-compilable, and this one is not. The
`@assert` at the top of each `__solve` and the ordinary exception paths are the same shape
in smaller.

This is worth stating precisely because the survey inferred the opposite, and the
inference was reasonable: nothing in the loops is CUDA-specific, no shared memory, no
atomics, no intrinsics. What was missed is that a solver is not only its loop. The
package's own GPU test passes because it exercises the first-order solvers under
`CUDA.@cuda`, not these.

## What the loops are worth reading for

ITP (`itp.jl`) is the algorithm this project's own bracketing loop should be measured
against. The loop maintains the bracket as an invariant that is visible in the body:
every branch either returns or replaces one endpoint with a point already known to lie
inside. It interpolates, truncates the interpolated step toward the midpoint, and
projects it into a shrinking neighbourhood of the bisection point, so it cannot do worse
than bisection while usually doing much better. The docstring cites its paper by DOI.

Two properties of the shape carry to this project whichever solver is written.
The state is four scalars and nothing else, so the loop is allocation-free by
construction. And the iteration count is data-dependent, which is the one thing that does
not carry: a fixed-cost loop with no early exit is what keeps every lane in a warp doing
the same work, so this project's version runs its iterations unconditionally and judges
convergence from the bracket width afterwards.

## Assumptions it carries

**Earth defaults (A2, A3), calendar (A1).** Clean negatives. No physical content.

**Grid, mesh and index base (A6).** No grid notion; scalar.

**Precision.** Parametric, and the default tolerance is a formula in the type's own
epsilon rather than a literal: `get_tolerance` returns `eps(one(T))^0.8` for a scalar or
static-array problem, with a separate Float64 branch returning `3.0e-13` whose comment
explains that the rational exponent hangs a static-compilation trimming pass. That is
better discipline than a chosen number and it is still a silent default across a
component boundary: `eps(Float64)^0.8` is 1.4e-13, three orders coarser than the rounding
decision 0008 asks for, and a caller who does not pass `abstol` gets it without being
told. The in-kernel run on the processor backend shows the consequence, ITP and Bisection
returning answers that agree only to the thirteenth digit.

**Threading and GPU model.** None of its own. The package inherits whatever the caller's
array type provides, and the device path is the one that does not work; see above.

**Mutable global state (C5).** None in the bracketing solvers. The verbosity object is
passed as an argument, not read from a global, which is the right design and is also the
thing that drags the logging machinery into the kernel.

**Clamps and limiters (B5).** `maxiters` defaults to 1000 and exhausting it returns a
solution with `ReturnCode.MaxIters` rather than refusing. ITP's own hyper-parameters
`scaled_k1 = 0.2`, `k2 = 2`, `n0 = 10` are checked at construction against the bounds the
paper proves, and the check throws.

**Declared against demonstrated (C3).** Two gaps. `Bisection`'s `exact_left` and
`exact_right` keyword arguments are documented and then declared not implemented, in a
danger admonition in the same docstring. And the in-kernel capability is demonstrated for
the first-order solvers under a vendor macro only; for the bracketing family under a
portable kernel it is now demonstrated not to hold.

**Fail-open branches (C4).** Three, all returning a plausible-looking solution object
with a return code that the caller has to read: a non-enclosing bracket returns
`InitialFailure` with the left endpoint as the root, exhausted iterations return
`MaxIters` with the last iterate, and the default tolerance above. This is the same shape
as `RootSolvers.jl`'s three defaults and calls for the same wrapper rule: refuse on
anything but success rather than reading the root.

## Checklist

| item | result |
| --- | --- |
| A1 day and year | clean negative |
| A2 planetary constant block | clean negative |
| A3 Earth literals | clean negative |
| A6 grid and index base | no grid notion; scalar and bracket |
| B4 comment against value | the Float64 tolerance comment explains a workaround and matches its code; `Bisection`'s docstring documents two keywords the code ignores, and says so |
| B5 clamps and limiters | `maxiters` 1000; ITP's hyper-parameter bounds, checked at construction |
| C1 use site of every constant | the tolerance formula and the three ITP hyper-parameters, each read at its own use site |
| C3 declared against demonstrated | unimplemented documented keywords; the in-kernel claim demonstrated only under a vendor macro and only for other solvers |
| C4 fail-open branches | non-enclosing bracket, exhausted iterations, default tolerance; all three return a usable-looking root |
| C5 duplicate state and second constant sets | clean negative; verbosity is an argument |
| D2 boundary field by field | the boundary is the problem and solution structs; the solution carries a return code that must be read, and the problem carries a closure whose captured parameters must be `isbits` for any device use |
| D4 conservation identity | run here as the accuracy identity of the finding: Kepler's equation against a 300-bit reference at seven eccentricities |

## References

- The measurements and the launch test: `notes/findings/2026-09-10-kepler-in-a-portable-kernel.md`.
- The survey entry: `docs/surveys/sciml.md`, the `NonlinearSolve.jl` closer look.
- Decision 0008 (Kepler to rounding), decision 0011 (portable kernels), decision 0027
  (the reference path beside every optimised kernel), decision 0029 (fixed-cost,
  data-independent kernels), decision 0033 (kernel purity and deferred differentiation).
- `docs/imports/rootsolvers-jl.md`, the other bracketing tree, whose three silent defaults
  are the same shape; `docs/imports/astrolib-jl.md`, the closed form.
- The row that takes the decision: `fiddlybits-52v.10`.
