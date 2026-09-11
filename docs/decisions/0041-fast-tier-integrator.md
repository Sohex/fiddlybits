+++
id = "0041"
title = "The fast tier integrates with ClimaTimeSteppers under five conditions, and the alternative is excluded by its own dependency graph"
status = "proposed"
date = 2026-09-10
amends = [{ record = "0012", what = "takes the ClimaTimeSteppers.jl candidacy it left open, and closes the four points it named for that decision" }]
+++

## Decision

The fast tier of decision 0023 integrates with `ClimaTimeSteppers.jl`, which becomes a
dependency under the five conditions below. Decision 0012 named four of them and left the
decision open; the fifth closes the comparison the survey asked for.

**1. The device is constructed from the profile.** `ClimaComms` is a hard dependency of
the integrators, not a weak one, so the device and context abstraction decision 0012
refused arrives transitively. `ClimaComms.device()` and `ClimaComms.context()` with no
argument read the `CLIMACOMMS_DEVICE` and `CLIMACOMMS_CONTEXT` environment variables, which
is a silent default across a component boundary and would put the backend of a run outside
its own identity. Both are constructed explicitly from the profile at the one place the
integrator is built, and the lint `docs/imports/climacomms-jl.md` already names,
refusing any argument-free call to either, is part of the adoption.

**2. An implicit stage that has not converged refuses.** `NewtonsMethod` defaults to
`max_iters = 1`, `convergence_checker = nothing` and `verbose = Silent()`, so by default
the implicit solve takes exactly one step and reports nothing. Even with a checker, failing
to converge within `max_iters` exits the loop and returns; the only report is a `@warn`
under `Verbose()`. Every implicit stage in this project therefore carries a
`ConvergenceChecker` with a condition declared against the quantity being solved, an
explicit `max_iters`, and a post-solve check that turns the outcome into a verdict of
decision 0009's vocabulary: `Converged`, or `Refused` with the stage and the residual
named. A step containing a refused stage does not advance the clock.

**3. The fast tier's tableau is `SSP333` under the `SSP` constraint.** The fast tier
carries tracer transport (decision 0023), so the step has to admit a limiter, and the
limiter path (`T_lim!` and `lim!`) is valid only under the strong-stability-preserving
constraint. `SSP333` is third order with three implicit stages, is singly diagonally
implicit at its default parameter, and defaults to the `SSP` constraint by its own type.
The unconstrained third-order `ARS343` is the comparison arm for the convergence-order
oracle and for any configuration that declares no limiter. Its coefficients were checked
against Ascher, Ruuth and Spiteri section 2.7 one by one: the package builds the paper's
two-parameter family at the paper's own choice of free parameters, every coefficient
agrees to the ten digits the paper prints, the diagonal entry is a root of the paper's
cubic to machine zero, and both row sums are exactly one. The tableau is named in the
profile (decision 0014) and enters the run identity, because changing it changes the
answer.

**4. The tableau's element type is set against the state's, explicitly.**
`IMEXAlgorithm`'s `cast_tableau_to_state_eltype` defaults to `false`, and the named
methods carry Float64 coefficients, so a Float32 state integrates against a Float64
tableau unless the caller says otherwise. The package's own comment says tableaux of order
three and above require the Float64 coefficients for stability. This project passes the
flag explicitly at construction, records its value in the run identity, and admits a
Float32 state in a production profile only through the per-kernel certification of
decision 0029.

**5. `OrdinaryDiffEq.jl` is not the alternative, on its dependency graph.**
`OrdinaryDiffEqCore` depends directly on `SciMLBase`, `DiffEqBase`,
`RecursiveArrayTools`, `SciMLOperators`, `SciMLStructures` and
`SymbolicIndexingInterface`, the apparatus decision 0012 declined, and on `FastPower`,
which `docs/imports/fastpower-jl.md` excludes by a manifest check. The exclusion is not a
preference to be weighed against the scheme families: the manifest check refuses the
build. The scheme implementations remain readable as a second source for a tableau's
coefficients.

## Alternatives considered

- **`OrdinaryDiffEq.jl`.** Rejected as above. Its scheme families are a superset of
  `ClimaTimeSteppers.jl`'s, and nothing in the multirate implementations is
  column-layout-specific, so the comparison turns entirely on what arrives with them.

- **Writing the integrator here.** An implicit-explicit additive Runge-Kutta step over a
  declared tableau is a small amount of code: the stage loop, the fused increment, and the
  call into a Newton solve the project would own anyway. This is the fallback if the
  `ClimaComms` dependency proves unacceptable in practice, and it is not the first choice
  for one reason: the tableau coefficients and the strong-stability-preserving machinery
  around the limiter are where the errors would be, and those are exactly what the adopted
  package has already tested. Decision 0027's reference path applies either way, so the
  naive fixed-step form exists next to whichever is used.

- **An explicit-only fast tier at a shorter step.** Rejected by the vertical stiffness the
  tier exists to handle; the acoustic and diffusive limits set a step far below what the
  horizontal Courant ceiling would allow.

- **Leaving the fast tier without an integrator until the dynamical core is written.**
  Rejected: decision 0023's tier table has no driver behind it until this is taken, and
  every row that plans a tendency needs to know whether its interface is
  `T_exp!`/`T_lim!`/`T_imp!` or something this project defines.

## Consequences

- `ClimaComms`, `Krylov`, `LinearOperators`, `NVTX`, `NullBroadcasts` and `StaticArrays`
  enter the dependency graph. `NVTX` is a profiling-annotation package that is active on
  the CUDA path; it is recorded here so that the annotations are a known presence rather
  than a surprise in a profile.
- A second licence family, Apache 2.0, enters the tree, as decision 0012 anticipated.
- `Field` must admit `Field + Field` and `dt * Field` under broadcasting, with the
  semantics, time semantics, dimension and level agreeing on both sides. Decision 0006
  makes that a deliberate question and `docs/imports/dimensionaldata-jl.md` shows the
  mechanism: the broadcast style carries all four parameters and a mismatch has no
  combination rule. The integrator asks for nothing else of the state beyond `zero`,
  `eltype` and, where a convergence checker is used, a norm.
- The implicit solve's Jacobian is written here. The package never forms one: the caller
  supplies `Wfact` filling `W = dtgamma * J - I` and a `jac_prototype` supporting
  `ldiv!`, which is the hand-written band solve decision 0012 already chose over the
  symbolic stack.
- Two registry entries follow, both fixed before the first artifact they judge: the
  integrator's convergence order against a manufactured solution, on the SSP-constrained
  and unconstrained arms; and the refusal control, a deliberately unconvergeable implicit
  stage that must return `Refused` rather than advancing.
- The tableau, the constraint, the cast flag, the device and the iteration cap are all in
  the run identity, because each of them changes the answer.

## References

- `docs/imports/climatimesteppers-jl.md`, the import review this decision acts on, and
  `docs/imports/climacomms-jl.md` for the device and context reading.
- `docs/imports/fastpower-jl.md` and
  `notes/findings/2026-09-10-fastpower-accuracy.md`, for the exclusion in condition five.
- `docs/surveys/sciml.md`, the `OrdinaryDiffEq.jl` and `FastPower.jl` closer looks.
- Decision 0006 (the field type and its broadcast), decision 0009 (the verdict
  vocabulary), decision 0012 (the ecosystem verdicts and the candidacy this takes),
  decision 0014 (the profile), decision 0023 (the timestep tiers), decision 0027 (the
  reference path), decision 0029 (precision certification and the run identity).
- Gardner, D. J., J. E. Guerra, F. P. Hamon, D. R. Reynolds, P. A. Ullrich and C. S.
  Woodward. "Implicit-explicit (IMEX) Runge-Kutta methods for non-hydrostatic atmospheric
  models." Geoscientific Model Development 11 (2018). DOI: 10.5194/gmd-11-1497-2018. The
  source of the SSP3(333)c tableau this decision names, fetched and held as
  `references/pdf/gardner2018-imex-runge-kutta-nonhydrostatic-atmospheric-models.pdf`.
  Held, not yet read: this record does not move from proposed to accepted until its
  tableau table has been read against the coefficients the package implements.
- Ascher, U. M., S. J. Ruuth and R. J. Spiteri. "Implicit-explicit Runge-Kutta methods for
  time-dependent partial differential equations." Applied Numerical Mathematics 25 (1997).
  DOI: 10.1016/S0168-9274(97)00056-1. Read, and held as
  `references/pdf/ascher1997-implicit-explicit-runge-kutta-methods.pdf`. Its section 2.7
  is the comparison arm named in condition three: the L-stable three-stage third-order
  DIRK and the four-stage explicit partner built to share the stability region of the
  four-stage fourth-order explicit schemes.
