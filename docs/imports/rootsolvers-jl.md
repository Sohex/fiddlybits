# RootSolvers.jl

**What it is.** A scalar root-finding package: bisection, regula falsi, Brent's
method, the secant method, and Newton's method with an analytic derivative or with
a forward-mode automatic one. Convergence criteria are types the caller constructs
and passes, solutions come back as one of three result structs, and the whole
package is two source concepts wide and about two thousand lines including its
documentation strings.

**What of it is used.** Nothing. This is a survey record. It is read because
decision 0008 requires Kepler's equation solved to rounding for any eccentricity
below one and forbids a series truncated in eccentricity, and because the column
physics will want the same scalar solve in several places.

**Licence.** Apache 2.0. **Version.** 1.1.0. **Read at.**
`7389b926dd93bad4d872f4b50a1e49208167fa3f`, committed 2026-09-01, in
`/home/cfutro/git/CliMA/RootSolvers.jl`.

**Verdict.** Adopt as infrastructure, subject to a wrapper. It is the cleanest
candidate the CliMA survey has found: no planetary content of any kind, two
dependencies, a real test suite, and a solver loop written in the discipline
decision 0033 asks for. It does not enter bare, because three of its defaults
are exactly the silent-default shape this project refuses at a component
boundary. The decision an adoption would need is named at the end.

## The questions, answered from source

### It does run in a device kernel, and the demonstration is not the portable one

The solver loop is written for a device. `_find_zero_bracketed`, which carries
bisection, regula falsi and Brent, contains no exception, no I/O, no allocation
and no data-dependent branch: the bracket update is three `ifelse` calls, a
non-finite input returns a failed result rather than throwing, and the whole
body reduces to a `for i in 1:maxiters` loop over a fixed arithmetic. The result
structs are `isbits` for two of the three kinds, and the package's own test file
`test/test_fval_inputs.jl` asserts both properties directly: `@test isbits(sol)`
at line 82, and `@test fval_alloc_measure(f_alloc, M, soltype) == 0` at line 205
for the pre-evaluated-endpoint entry points. `test/runtests.jl:158` makes the
same zero-allocation assertion across every method and tolerance combination.
The third result kind, `VerboseSolution`, keeps an iterate history in two growing
vectors and is documented as CPU-only; the test suite excludes it from the
allocation check by name and from the device path entirely.

`NoTolerance` deserves its own paragraph, because it is an unusually thoughtful
piece of design and it is the one this project would use. It always returns
`false`, so the solver runs exactly `maxiters` iterations with no early exit,
returns `converged = false` unconditionally, and leaves the caller to judge
convergence from the returned bracket. That is a fixed-cost, data-independent
solve: every lane in a warp does the same work regardless of its data, which is
what decision 0029 wants from a kernel that must give the same answer whatever
the partitioning. The docstring names its own exception honestly: Brent's method
keeps an internal exact-zero exit independent of the tolerance, so under
`NoTolerance` its iteration count, though not its result, can still become
data-dependent.

The gap is what demonstrates it. `test/runtests.jl` imports CUDA directly, sets
`ArrayType = CUDA.CuArray`, and exercises the device path by broadcasting
`find_zero.(f, method, ...)` over a device array. So the demonstrated GPU
capability is vendor-specific and is broadcast-shaped: it shows the solver
compiling and running inside CUDA.jl's own broadcast kernel, not inside a
`KernelAbstractions` kernel a caller wrote. The package has no
`KernelAbstractions` dependency and no portable-kernel test. Nothing read here
suggests it would fail under the portable macro, since the loop body is plain
scalar arithmetic, but it is not shown, and this is the same gap
`fiddlybits-bon.6` records against the other bracketing-solver tree. The test
that closes it belongs here and is named below.

Two further observations from the device path. The zero-allocation assertion is
guarded by `ArrayType <: Array`, so it is made on the CPU only, with the comment
"allocations expected during CUDA kernel launches"; the non-allocating claim is
therefore about the solver body and not about a launch. And at
`test/runtests.jl:198` there is a skip that does not skip: a comment explains at
length that automatic-differentiation Newton on the trigonometric problem must
be passed over on the GPU because `sin(::Dual)` lowers to a device `sincos`
whose `Ref` allocation fails GPU code generation, and the `if` that follows has
an empty body. Whatever the history, the code does not perform the skip the
comment describes.

### The tolerance is caller-supplied, and there is a default anyway

The organisation sweep recorded that tolerances here "are types that a caller
supplies rather than numbers the package chooses". That is right about the
machinery and wrong about the default, and the difference matters for decision
0008.

The machinery is as described. `ResidualTolerance`, `SolutionTolerance`,
`RelativeSolutionTolerance`, `RelativeOrAbsoluteSolutionTolerance` and
`NoTolerance` are distinct types, each a callable `(x1, x2, y)` predicate, so the
convergence criterion is dispatched rather than configured. Every one of them
except `NoTolerance` also ORs in `abs(y) < eps(typeof(y))`, so a residual at
machine epsilon counts as converged whatever the requested tolerance. That
epsilon clause is the door decision 0008 needs: a Kepler solve to rounding is
reachable here, by passing a tolerance at or below the type's epsilon and
letting the clause terminate it.

But `find_zero` has a default, and it is a number the package chose:

    _default_tol_value(::Type{Float64}) = 1e-4
    _default_tol_value(::Type{FT}) where {FT <: AbstractFloat} = FT(1e-3)

`default_tol(FT)` wraps that in a `SolutionTolerance`, and the main `find_zero`
entry point applies it whenever `tol` is `nothing`, which is its own default. So
a caller who writes `find_zero(f, BrentsMethod{Float64}(a, b))` gets an absolute
step tolerance of one part in ten thousand and no indication that a choice was
made. For a mean anomaly in radians that is an error of order `1e-4` radians in
the true anomaly, which is roughly twenty arcseconds of orbital phase: twelve
orders of magnitude short of rounding, and silent. It is worth being precise
about what is wrong with it here. The value is not unreasonable for the moist
thermodynamics the package was written for. The defect is that it crosses a
component boundary unannounced, which is the rule in `CLAUDE.md` that this
project checks at the point of reading.

Two more defaults of the same kind. `maxiters` defaults to `1_000`, and
exhausting it returns `converged = false` with the last iterate as the root
rather than refusing. And the bracketing entry points return a result instead of
erroring when the bracket is invalid:

    if y0 * y1 >= 0
        # Return failed solution instead of error for GPU compatibility.
        # Pick the endpoint with the smaller residual as the best guess.

with `converged = false` and the smaller-residual endpoint as the returned root.
That is the right choice for a device kernel, where an exception has nowhere to
go, and it is a loaded gun for a caller who reads `sol.root` without reading
`sol.converged`. All three are handled by one wrapper rule: this project's call
site supplies the tolerance and the iteration count explicitly and refuses on
`converged == false` rather than reading the root.

One numerical note on that same line. The bracket test is written as a product,
`y0 * y1 >= 0`, and a product of two small residuals underflows. For residuals
of order `1e-200` in double precision the product is `-0.0`, which compares
`>= 0` as true, so a genuine sign change is reported as no bracket. A
`signbit(y0) != signbit(y1)` test is exact and costs the same. This does not
bite on a Kepler solve, whose endpoint residuals are of order one, but it is the
kind of thing a saturation adjustment on a trace condensable can reach.

### The ForwardDiff dependency, against decision 0033

Decision 0033 defers automatic differentiation and requires that the code be
written so it can be added: pure kernels, no mutable globals, preallocated
buffers, no I/O and no exceptions. RootSolvers satisfies every one of those
constraints in its solver loop, which is the strongest thing this record can say
about it.

The dependency itself is thin and severable. `ForwardDiff` appears in exactly
two places: `base_type` at line 84, one method teaching the tolerance machinery
to see through a `Dual` to its underlying float type, and `value_deriv` at line
1947, three lines that evaluate `f` on a `Dual` and return the value and the
first partial together. Only `NewtonsMethodAD` reaches the second. Bisection,
regula falsi, Brent, the secant method and Newton with a supplied derivative do
not touch it, and those are the methods a Kepler solve and a saturation
adjustment would use.

The implication for 0033 is therefore not a conflict but a cost, and it has two
parts. First, `ForwardDiff` is a hard dependency in `Project.toml` rather than a
package extension, so a project that has deferred differentiation would carry a
differentiation library in its dependency graph and its precompile time for a
method it does not call. That is an argument for taking the methods and not the
package, or for asking upstream to move the AD method behind an extension.
Second, and more useful, the empty skip described above is evidence for one of
0033's own cost bullets: the tree's authors found that `sin(::Dual)` fails GPU
code generation under GPUCompiler and wrote it down. Differentiating through a
device kernel is exactly where 0033 says the tooling is immature, and here is a
small, careful package hitting it.

## Assumptions it carries

**Earth defaults (A2, A3).** Clean negative, and unusually so. A grep of `src/`
for `9.81`, `6371`, `1361`, `101325` and their relatives returns nothing. There
is no planetary constant block, no physical constant of any kind, and nothing in
the package knows what it is solving for.

**Calendar and time (A1).** Clean negative. No `Dates` import, no day, no year,
no seconds.

**Grid, mesh and index base (A6).** Clean negative. The package is scalar and
broadcast; it has no notion of a grid. Arrays enter only through
`FTypes = Union{Real, AbstractArray}` and the broadcast overload, which threads
`find_zero` through Julia's own machinery rather than indexing anything itself.

**Precision.** Parameterised throughout on `FT`, with `base_type` resolving
through `Dual` wrappers so that a scalar, an array and a dual over the same
element type get the same tolerance. The only precision decision the package
makes on its own behalf is the default tolerance value discussed above, which is
keyed on the element type and is a fixed number rather than a multiple of its
epsilon.

**Threading and GPU model.** No threading. The device model is broadcast over a
vendor array type, demonstrated on CUDA only; see above.

**Mutable global state (C5).** Clean negative. One `const FTypes` type alias and
nothing else at module scope. No second constant set, no global cache, no
package-level configuration.

**Clamps and limiters (B5).** The `maxiters` bound and the invalid-bracket
early return, both discussed. No clamp on an iterate, no floor on a residual, no
damping factor.

**Declared against demonstrated (C3).** Good. There is a `test/` directory with
six files, a `runtests.jl` that sweeps every method against every tolerance type
over a problem list in both scalar and array form, separate suites for
pre-evaluated endpoints, the method selector, printing and robustness, and a CUDA
path in continuous integration. The declared-but-not-demonstrated items are the
portable-kernel launch and the GPU allocation behaviour.

## The wrapper an adoption would need

Not a decision this record takes. If one is proposed, the surface is small enough
to state exactly:

1. **A call site that supplies its own tolerance and iteration count**, so
   `default_tol` is never reached. The Kepler solve passes a tolerance at the
   type's epsilon; every other call site declares its own against the quantity it
   is solving for.
2. **A refusal on `converged == false`**, so no caller reads `sol.root` past a
   failed solve. This is where the invalid-bracket return and the exhausted
   iteration count are both caught.
3. **`NoTolerance` with `TwoPointSolution` on the device**, with the convergence
   judgement made by the caller from the bracket width, which is the pattern the
   package documents and the one that keeps a kernel data-independent.

The leak tests that would catch each:

- **The silent default.** A lint over the source refusing any call to `find_zero`
  that does not pass a tolerance argument explicitly. This is the same shape as
  the earth-constant quarantine lint and the calendar-import lint already filed
  under `fiddlybits-52v.1.3`, and belongs in that suite.
- **The tolerance actually reaching rounding.** The registered oracle
  `system.kepler_period` already carries it: its statistic includes the true
  anomaly from the Kepler solve against a closed form at every eccentricity the
  synthetic instances declare, and its threshold is roundoff derived from the
  type's epsilon and the iteration count of the solve. So both of the defaults
  this record objects to are inside that threshold's own definition, and a
  tolerance left at `1e-4` fails the oracle. This is the positive control the
  lint alone does not give.
- **The portable-kernel launch.** The test `fiddlybits-bon.6` already names for
  the other bracketing tree: the same solve driven from inside a
  `KernelAbstractions` kernel on both backends, with a bitwise comparison against
  the CPU reference path. Whichever solver is adopted, this test is written once.
- **Thread-count invariance.** `NoTolerance` plus a fixed iteration count makes
  the solve data-independent by construction; the repeat-under-different-launch-
  geometry test of decision 0029 is what confirms it.

## Checklist

| item | result |
| --- | --- |
| A1 day and year | clean negative; no `Dates`, no day, no year |
| A2 planetary constant block | clean negative; no physical constants at all |
| A3 Earth literals | clean negative; no hits in `src/` |
| A6 grid and index base | clean negative; scalar and broadcast, no grid notion |
| B4 comment against value | the GPU skip at `test/runtests.jl:198` describes a skip the empty `if` body does not perform |
| B5 clamps and limiters | `maxiters` default `1_000` returning `converged = false`; invalid bracket returning a best-guess endpoint; no clamps on iterates |
| C1 use site of every constant | the only constants are the default tolerance values `1e-4` and `1e-3`, applied at the main `find_zero` entry when `tol` is `nothing` |
| C3 declared against demonstrated | six test files, every method against every tolerance, scalar and array, CUDA in CI; not demonstrated: a portable-kernel launch, and allocation behaviour on the device |
| C4 fail-open branches | three, all deliberate and documented for device compatibility: the default tolerance, the exhausted iteration count, the invalid bracket. Each returns a usable-looking root with `converged = false` |
| C5 duplicate state and second constant sets | clean negative; one type alias at module scope |
| D2 boundary field by field | the exchanged objects are the method struct, the tolerance struct and the result struct, all `isbits` except `VerboseSolution`, which is documented CPU-only; no units, no index base, no array orientation crosses the boundary |
| D4 conservation identity | not applicable; there is no conserved quantity. The identity that would stand in its place is the Kepler round trip named above, which belongs to this project's clock and not to the package |

## References

- The organisation sweep that flagged this package:
  `docs/imports/clima-organisation-sweep.md`.
- The plan this record answers to: `docs/plans/clima-survey.md`, the numerics and
  time group.
- Decision 0008 (the clock; Kepler to rounding for any eccentricity below one),
  decision 0012 (the adopt, borrow and reject lists this verdict feeds), decision
  0029 (partition-independent results and repeats), decision 0033 (design for
  differentiability, defer it).
- The sibling row on the other bracketing-solver tree and the portable-kernel
  launch test it names: `fiddlybits-bon.6`, against `docs/surveys/sciml.md`.
- The closed-form Kepler solve read as an algorithm rather than a dependency:
  `fiddlybits-bon.13`, against `docs/surveys/orbits-and-stellar.md`. That row and
  this one answer the same requirement by different routes and should be settled
  together.
