# ClimaTimeSteppers.jl

**What it is.** A library of ordinary-differential-equation time integrators
built for atmospheric cores: implicit-explicit additive Runge-Kutta and
strong-stability-preserving Runge-Kutta pairs, a Rosenbrock method, low-storage
and multirate explicit methods, with a Newton and Newton-Krylov nonlinear solver
attached to the implicit stages.

**Why it was surveyed.** Decision 0023's fast tier is exactly the split these
integrators are written for: a stiff vertical part solved implicitly against a
non-stiff horizontal part carried explicitly, at a fixed step. The plan asks
whether the integrators depend on ClimaCore's discretisation. They do not.

## Do the integrators depend on the discretisation?

No. `ClimaCore` is a weak dependency of the package, and the whole of the
extension it enables (`ext/ClimaTimeSteppersClimaCoreExt.jl`) is twenty lines
supplying one adapter so that a Krylov workspace can be kept flat on the device
when the state happens to be a ClimaCore `FieldVector`. Nothing in `src/` imports
it.

The problem type is the package's own (`src/problems.jl`): `ODEProblem(f, u0,
tspan, p)`, not SciMLBase's, so adopting it does not drag in the
differential-equations stack that decision 0012 already refused. The tendency
container is `ClimaODEFunction` (`src/functions.jl`), whose tendencies have the
signatures `T_exp!(du, u, p, t)`, `T_lim!(du, u, p, t)` and `T_imp!`, with
optional `lim!`, `dss!`, `constrain_state!`, `initialize_imp!` and `cache!`
callbacks. Every one is a function of the caller's own state object.

What the integrator actually requires of the state `u0`, read off the cache
allocation and the step body in `src/solvers/imex_ark.jl` and
`src/utilities/fused_increment.jl`, is small and entirely satisfiable by this
project's `Field` (decision 0006) or by a container of them:

- `zero(u0)`, called once per stage to allocate the stage and tendency slots.
- `eltype(u0)`, used only to decide whether to downcast the tableau.
- Broadcasting: the step body is `@. U = base + inc_exp + inc_imp`, where the
  increments are lazily fused `Broadcasted` objects with the zero tableau
  coefficients dropped at compile time.
- `norm(u)`, but only if a `ConvergenceChecker` or a `LineSearch` is used.

There is no `getindex`, no assumption of a flat vector, and no assumption about
what the state contains. A `Field` that broadcasts and has a `zero` is a legal
state. The one thing to note is that a semantics-typed `Field` would have to
admit `Field + Field` and `dt * Field` under broadcasting, which decision 0006's
dispatch rules make a deliberate question rather than an automatic yes.

## What the implicit solve asks of the caller

The implicit half is `T_imp!`, normally wrapped in the package's own
`ODEFunction(f; jac_prototype, Wfact, tgrad)`. `has_jac` checks for the two
fields, and `NewtonsMethod` (`src/nl_solvers/newtons_method.jl`) then requires:

- **`Wfact(W, u, p, dtgamma, t)`**, which fills `W = dtgamma * J - I`. The caller
  writes the Jacobian; the package never forms one.
- **`jac_prototype`**, an object supporting `ldiv!`. The docstring is explicit:
  it "should support `ldiv!` directly (e.g. a pre-factorized matrix or
  `LinearOperator`)", and a dense matrix triggers an `lu` on every solve and is
  "suitable only for testing". This is precisely the shape decision 0012 already
  chose when it rejected the symbolic stack in favour of a hand-written
  tridiagonal implicit solve in a kernel: that solve, wrapped as an `ldiv!`
  method, is what would be handed over here.
- **Or neither.** With a `KrylovMethod` carrying a `ForwardDiffJVP`, the solve is
  Jacobian-free Newton-Krylov and no Jacobian or prototype is needed at all; when
  both are given, the Jacobian is used as a left preconditioner. `max_iters`
  defaults to 1, which is the usual atmospheric single-Newton-step configuration.

`update_j` chooses when the Jacobian is refreshed (every iteration, every solve,
or every timestep), which is the chord method as an option rather than a
hard-coded choice.

## Is any of it tied to a vertical column layout?

No. The grep for "column" in `src/` returns only `zero_column` on the tableau
coefficient arrays and the dense-matrix-from-operator debugging helper, which
walks the columns of a matrix. There is no vertical index, no level count, no
banded or tridiagonal structure anywhere in the package: the band structure lives
entirely in the caller's `ldiv!`. This is the property that makes the package
usable on a triangle C-grid without touching it.

## Schemes implemented

Implicit-explicit additive Runge-Kutta (`src/solvers/imex_tableaus.jl`):
ARS111, ARS121, ARS122, ARS233, ARS232, ARS222, ARS343, ARS443, IMKG232a,
IMKG232b, IMKG242a, IMKG242b, IMKG243a, IMKG252a, IMKG252b, IMKG253a, IMKG253b,
IMKG254a, IMKG254b, IMKG254c, IMKG342a, IMKG343a, DBM453, HOMMEM1, ARK437L2SA1,
ARK548L2SA2. Beside them: an implicit-explicit SSP-RK family
(`src/solvers/imex_ssprk.jl`), explicit SSP22Heuns, SSP33ShuOsher and RK4, the
Rosenbrock method SSPKnoth, low-storage 2N methods, multirate infinitesimal step
methods, and a Wicker-Skamarock stepper. Both a constrained (limiter-carrying)
and an unconstrained algorithm form exist, and the limiter is applied to the
explicit increment before the implicit one is added, which is the flux-corrected
transport discipline decision 0016 wants for tracers.

## Time representation

Generic. The integrator stores `t::tType` and `dt::tType` and the only
operations performed on them are addition, comparison, `oneunit`, `float` and
`eps(float(t / oneunit(t)))` for the tstop-rounding tolerance
(`src/integrators.jl`). There is no date type, no calendar, no day, no year, and
no `Dates` import anywhere in `src/` or `ext/`. The package is written so that a
non-float duration type from elsewhere works, and casts `dt` to a float at the
increment boundary for that reason. This is the clean negative the plan asked
for: the time representation carries no Earth and no calendar, and a duration in
SI seconds is what it wants.

## Assumptions it carries

| assumption | present | how a leak is caught |
| --- | --- | --- |
| Earth defaults | none; the Earth-literal grep over `src/` returns nothing but Runge-Kutta tableau coefficients | n/a |
| calendar or time | none; `t` and `dt` are an arbitrary numeric type with no date semantics | this project's durations are SI seconds (0023), so the boundary is a scalar with a declared unit |
| grid or mesh | none; the state is opaque and never indexed | n/a |
| index base | none in the state; stage indices are 1-based and internal | n/a |
| precision | the tableau is stored at its own eltype and optionally downcast to `eltype(u0)` via the `cast_tableau_to_state_eltype` option; without it, a Float32 state is multiplied by Float64 coefficients | the option would be set explicitly and asserted, not left to the default; a mixed-precision step is a real reproducibility hazard |
| threading and GPU model | none of its own; it broadcasts and lets the state's array type decide, and touches `ClimaComms` only for a wall-clock callback and a device query | n/a for kernels; the `ClimaComms` hard dependency is the real cost, see below |
| mutable global state | none process-global; `UpdateEveryN` and `UpdateEveryDt` hold a `Ref` counter, but per handler instance | n/a |
| fail-open branches | without a `ConvergenceChecker` the Newton solve always runs exactly `max_iters` iterations and reports nothing, so a non-converged implicit stage is silent by default | a checker would be mandatory here, with a refusal rather than a warning; this is decision 0009's verdict vocabulary applied to the implicit solve |

The one carried cost worth naming: `ClimaComms` is a hard dependency of
ClimaTimeSteppers, not a weak one, so adopting the integrators adopts the device
and context abstraction of the companion record `climacomms-jl.md` alongside
this project's KernelAbstractions plus CUDA.

## Checklist items applied

**A1** none: no statement of a day or a year, and no calendar type. **A2** none:
there is no planetary constant block. **A3** none: the Earth-literal grep is
clean. **A6** none in the used surface: no compile-time grid bound, no index-base
assumption on the state. **B4** the constants present are tableau coefficients
and their comments cite the papers they come from. **B5** the limiters are
`lim!`, which is the caller's own, the line-search halving capped at five
backtracks, and the tstop rounding tolerance of a hundred machine epsilons.
**C1** every constant found is a tableau entry with its use site in the step
body. **C3** the capability relied on, driving the integrators with a state that
is not a ClimaCore `FieldVector`, is demonstrated upstream: the test suite runs
plain arrays and the package's own problem types. **C4** the silent
non-convergence above is the fail-open branch. **C5** no duplicate live state;
the stage slots are a `SparseContainer` keyed by stage index and the tableau is
the single coefficient set. **D2** the boundary is one function signature,
`(du, u, p, t)`, plus `Wfact(W, u, p, dtgamma, t)`; the array orientation and
units are wholly the caller's. **D4** the identity with a right answer in advance
is the convergence order of each tableau against an analytic problem, which the
upstream suite already runs, plus conservation under a divergence-free tendency
here.

**Licence.** Apache 2.0. **Version.** Read against `main` at commit
`2c9d9b9fcb638f9fb2828ad2da2e79439c23d3e2` (2026-09-08), `Project.toml` version
0.10.7. `to pin` if adopted.

## Verdict

**Adopt as infrastructure**, subject to a decision, because it is a tendency-and-
state integrator library with no grid, no calendar, no planetary constant and no
column layout, and it supplies exactly the implicit-explicit split decision 0023
describes with the implicit linear algebra left entirely to the caller.

The decision it would need: one that fixes which tableau the fast tier uses and
why, that requires a `ConvergenceChecker` on every implicit stage so a
non-converged step refuses rather than passes silently, that sets
`cast_tableau_to_state_eltype` explicitly, and that accepts `ClimaComms` as a
transitive dependency beside KernelAbstractions or replaces it. The named tests
that would catch what it carries:
`test/time/tableau_convergence_order.jl` (each adopted scheme reaches its
designed order on an analytic problem, with the positive control that a
deliberately wrong coefficient fails it), `test/time/implicit_refuses.jl` (a
Newton stage that does not converge returns `Refused`, never a silent state),
`test/time/step_precision.jl` (the tableau eltype matches the state eltype, so no
step silently promotes), and `test/fields/field_is_a_valid_state.jl` (`zero`,
broadcasting and `norm` on this project's `Field` satisfy the integrator's
contract, and a semantics combination that decision 0006 forbids still does not
exist).
