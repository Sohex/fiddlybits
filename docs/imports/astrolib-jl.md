# AstroLib.jl, `kepler_solver.jl` and `trueanom.jl`

**What it is.** A Julia port of the IDL Astronomy User's Library: about a hundred small
astronomical utilities. Two of its files are read here and the rest is dismissed with the
ephemeris cluster, because everything else takes a Julian date or a `DateTime` and this
project's clock is SI seconds from a declared epoch (decision 0008).

**What of it is used.** Nothing, as a package. `kepler_solver` is read as an algorithm:
Markley's closed-form solution of Kepler's equation, which this project reimplements.

**Licence.** MIT. **Version.** the tree's own. **Read at.**
`288bcfd14e71fba9e34db62cc6341a04751153a7`, committed 2026-07-08, in
`/home/cfutro/git/JuliaAstro/AstroLib.jl`. Measured on the RTX 4090 and the processor:
`notes/findings/2026-09-10-kepler-in-a-portable-kernel.md`.

**Verdict.** Algorithmic reference, carried into the clock module with the half of the
paper the implementation leaves out. Markley's method is the right starting value and is
accurate to rounding over the whole elliptic range only when its residual and derivative
are written as the paper's last two pages prescribe; `AstroLib.jl` implements the first
twenty-nine equations and not the five that follow, and the difference is measurable.

## The algorithm

`kepler_solver(M, e)` implements Markley (1995), Celestial Mechanics and Dynamical
Astronomy 63, 101, DOI 10.1007/BF00691917, cited in its own docstring. It reduces the
mean anomaly into `[-pi, pi]`, forms a starting value from a cubic whose root is written
out algebraically (Markley's equations 20, 5, 9, 10, 14, 15), and then applies three
successive correction terms built from one `sincos` evaluation (equations 21 through 29).
There is no loop, no tolerance and no convergence test: four transcendental evaluations
and a fixed sequence of arithmetic, the same instruction count for every input.

That shape is exactly what decision 0029 wants from a kernel and what decision 0011 wants
from column physics: no early exit, no data-dependent iteration count, every lane in a
warp doing the same work. It is also allocation-free, type-generic through
`promote_type`, and touches no array, no `Dates` and no global. `trueanom(E, e)` beside
it is the one-line half-angle conversion to the true anomaly.

The one thing in it that cannot cross into device code is the `DomainError` thrown for
`e` outside `[0, 1]`. Decision 0008's vocabulary has the replacement: the guard belongs
in the `System` constructor, where an eccentricity outside the elliptic range is refused
once, rather than in a per-cell kernel where an exception has nowhere to go.

## Where it holds, and where it does not

The paper is held and read: `references/pdf/markley1995-kepler-equation-solver.pdf`, from
the NASA technical-reports copy of the same work. Its Numerical Considerations section
says that a naive double-precision implementation "yields unacceptably large errors
exceeding 5e-14", that the errors above 5e-16 lie in the region `e > 0.75` and `E < 45`
degrees, and that the remedy is to replace the derivative by equation 30,
`f'(E) = 1 - e + 2 e sin^2(E/2)`, and the residual by equations 31 to 34, `M*(e,E) - M`
with `M*` taken as `(1 - e)E` plus `e E^3` times a printed Pade approximant inside that
region. `AstroLib.jl` implements equations 20 through 29 with `f0 = E1 - e sin E1 - M`
and `f1 = 1 - e cos E1`, which are the two expressions equations 30 to 35 exist to
replace.

Measured against the same equation solved at 300 bits, in ulps of pi:

| eccentricity | Markley closed form | Markley then two Newton steps on the stable residual |
|---|---|---|
| 0.5 | 0.78 | 0.72 |
| 0.9 | 0.70 | 0.70 |
| 0.99 | 0.79 | 0.70 |
| 0.999 | 0.74 | 0.63 |
| 1 - 1e-6 | 0.79 | 0.81 |
| 1 - 1e-9 | 24.1 | 0.70 |
| 1 - 1e-12 | 13500 | 0.70 |

The closed form as implemented is sub-ulp through `e = 1 - 1e-6` and then degrades
sharply. The cause is not Markley's method: it is the residual his correction terms are
built from, `E - e sin E - M`, whose two leading terms cancel completely as `e` approaches
one at small `E`. A plain bisection on the same residual degrades the same way, 2930 ulps
at `e = 1 - 1e-12`, so the failure belongs to the expression and not to the solver, which
is what the paper says and what its own fix addresses. In the paper's metric, relative
error, the implemented form reaches 5.35e-07 over the region the paper names and the fixed
form 6.26e-16. The finding carries the full tables and the reference's own control.

Rewriting the residual as `(1 - e)E + e(E - sin E) - M`, with `E - sin E` taken from its
series below half a radian, removes the cancellation, and then the closed form followed
by two Newton steps is under one ulp of pi at every eccentricity tried. Two steps, not
one: the closed form's starting value is good enough that Newton is quadratic from there,
and one step is not always enough when the start is 13500 ulps out.

## What the clock module takes

1. **Markley's closed form as the starting value**, transcribed with its equation numbers
   named in the comments and its paper anchored in `docs/references/INDEX.md`, read and
   held, as decision 0030 requires.
2. **Two Newton steps on the stable residual**, with the small-angle series to seven
   terms. Fewer terms leave a relative 7.8e-13 at the crossover, which is measurable in
   the answer. The paper's equation 33 uses a Pade approximant with printed coefficients
   in the same place; the series is equivalent and is checked against the same 300-bit
   reference.
3. **The eccentricity guard in the constructor**, not in the kernel.
4. **`trueanom`'s half-angle conversion**, which has no numerical subtlety at any
   eccentricity below one.

## Assumptions it carries

**Earth defaults (A2, A3).** Clean negative in the two files read. The package at large
carries observatory positions, Earth precession models and Julian-date conversions, which
is why only these two files are read.

**Calendar and time (A1).** Clean negative in the two files read, and the reason the rest
is dismissed: `helio_jd`, `precess`, `bprecess`, `helio_rv` and everything in `common.jl`
and `utils.jl` takes a Julian date or a `DateTime`. A Julian date is a calendar in a
number, and decision 0008 has one clock in SI seconds.

**Grid, mesh and index base (A6).** No arrays in the two files read.

**Precision.** Parametric through `promote_type`. The accuracy at high eccentricity is
the finding above and is a property of the residual, not of the precision.

**Threading and GPU model.** None. The two functions are scalar and would run in a kernel
but for the `DomainError`.

**Mutable global state (C5).** None in the two files read.

**Clamps and limiters (B5).** The `rem2pi` reduction and the `DomainError` guard.

**Declared against demonstrated (C3).** The docstring claims accuracy to machine
precision over the whole elliptic range and the package's tests check the solve at
moderate eccentricities. The claim does not hold at the top of the range as implemented,
and the paper it inherits the claim from says why and prescribes the fix the
implementation does not carry. This is the checklist item in its purest form: the claim is
true of the paper's algorithm and false of this code, and only reading both settles it.

**Fail-open branches (C4).** None. The out-of-range eccentricity throws rather than
returning something plausible.

## Checklist

| item | result |
| --- | --- |
| A1 day and year | clean negative in the two files read; the rest of the package is Julian dates and is dismissed for that reason |
| A2 planetary constant block | clean negative in the two files read |
| A3 Earth literals | clean negative in the two files read |
| A6 grid and index base | no arrays |
| B4 comment against value | the equation-number comments match Markley's paper as the implementation cites it |
| B5 clamps and limiters | `rem2pi`; the `DomainError` on eccentricity |
| C1 use site of every constant | the only constants are `pi` and the rational coefficients of Markley's equations |
| C3 declared against demonstrated | the machine-precision claim over the whole elliptic range does not hold above `e = 1 - 1e-6` as implemented, measured; the paper's equations 30 to 35, which exist to make it hold, are not in the code |
| C4 fail-open branches | none; it throws |
| D2 boundary field by field | two scalars in, one scalar out, no units and no index base |
| D4 conservation identity | run here: the solve against a 300-bit reference at seven eccentricities, in the finding |

## References

- The measurements: `notes/findings/2026-09-10-kepler-in-a-portable-kernel.md`.
- The survey entry: `docs/surveys/orbits-and-stellar.md`, AstroLib.jl.
- Markley, F. L. "Kepler Equation Solver." Celestial Mechanics and Dynamical Astronomy 63
  (1995). DOI: 10.1007/BF00691917. Read; held as
  `references/pdf/markley1995-kepler-equation-solver.pdf`.
- Decision 0008 (one clock, Kepler to rounding, the epoch rule), decision 0029
  (data-independent kernels), decision 0030 (every scheme anchored to a read source).
- `docs/imports/bracketingnonlinearsolve-jl.md` and `docs/imports/rootsolvers-jl.md`, the
  two packaged alternatives; `fiddlybits-52v.10` takes the decision between them.
