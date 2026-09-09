+++
id = "0033"
title = "Design for differentiability and defer it; the trigger is a non-chaotic subsystem's sensitivity report"
status = "accepted"
date = 2026-09-08
+++

## Decision

Automatic differentiation is not a first-version requirement. The code is written so
that it can be added: every kernel is a pure function of its arguments, there are no
mutable globals, buffers are preallocated and passed in, and no kernel performs I/O
or raises exceptions. Those constraints cost nothing because they are wanted anyway
for reproducibility (decision 0029) and for the reference-path discipline (decision
0027).

**What differentiation would buy, concretely.**

- The sensitivity of any output to every parameter in one reverse pass, instead of one
  run per parameter. With tens of bracketed constants, a sweep by finite differences
  is tens of runs.
- Inverse design: the orbit or flux that yields a target state by gradient descent.
- Well-posed adjoints for the non-chaotic subsystems: the terrain model at steady
  state (which uplift pattern yields a given hypsometry), single-column radiation and
  land models, the lake cascade. These are the natural first users.

**What it would cost, concretely.**

- Every kernel must avoid constructs the tool cannot handle (some GPU atomics,
  exceptions, I/O, certain type instabilities). Most are avoided already.
- Reverse mode needs the state at every timestep, so memory grows with run length
  unless a checkpointing schedule is used; on a single consumer card that is a real
  constraint for anything but short windows.
- For a chaotic climate trajectory, long-time adjoints diverge, and sensitivities of
  climate means need ensemble or shadowing methods. The biggest hoped-for payoff is
  the hardest to obtain.
- Tool maturity: differentiating through portable GPU kernels has open issues at the
  time of writing, and the compiler-tracing alternative wants a coding style
  (traceable array operations) that this project's kernel design does not use.
- Compile and test time roughly double for anything differentiated.

**The trigger to revisit.** The first non-chaotic subsystem for which a sensitivity
report is wanted and finite differences are too expensive. The candidate tool is the
source-level differentiator; the tracing-compiler route is not adopted because it
constrains kernel style.

## Alternatives considered

- *A first-class requirement from day one.* Rejected: it would slow every milestone
  for a payoff that is either cheap by brackets (inverse design) or ill-posed for the
  chaotic subsystems (climate-mean sensitivities), while the well-posed uses are
  small and can be added when wanted.
- *Adopt the tracing-compiler route to get GPU differentiation and compilation in one.*
  Rejected: it dictates a traceable-array coding style that conflicts with the
  portable-kernel design, and imports a large dependency whose defaults would need
  their own import review.
- *Rule it out.* Rejected: the design constraints that keep it possible are free.

## Consequences

- A lint refuses mutable globals and I/O inside kernel modules, serving this record
  and decision 0029 together.
- Checkpointing of state is a designed capability of the run loop (it is also what
  restarts need), so a future reverse pass has a schedule to use.
- Sensitivity brackets in the first versions are finite-difference sweeps over
  declared brackets, and their cost is a recorded number per subsystem.

## References

- Griewank, A., and A. Walther. Evaluating Derivatives: Principles and Techniques of
  Algorithmic Differentiation, second edition. SIAM, 2008. DOI: 10.1137/1.9780898717761.
- Griewank, A., and A. Walther. "Algorithm 799: revolve: an implementation of
  checkpointing for the reverse or adjoint mode of computational differentiation."
  ACM Transactions on Mathematical Software 26 (2000). DOI: 10.1145/347837.347846.
- Lea, D. J., M. R. Allen, and T. W. N. Haine. "Sensitivity analysis of the climate of
  a chaotic system." Tellus A 52 (2000). DOI: 10.3402/tellusa.v52i5.12283.
- Wang, Q., R. Hu, and P. Blonigan. "Least Squares Shadowing sensitivity analysis of
  chaotic limit cycle oscillations." Journal of Computational Physics 267 (2014).
  DOI: 10.1016/j.jcp.2014.03.002.
- Moses, W. S., and V. Churavy. "Instead of Rewriting Foreign Code for Machine
  Learning, Automatically Synthesize Fast Gradients." Advances in Neural Information
  Processing Systems 33 (2020). (Enzyme; DOI: to confirm)
