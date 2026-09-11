# SeawaterPolynomials.jl

**What it is.** Polynomial approximations to the Boussinesq equation of state for
seawater: density and its two derivatives as functions of conservative temperature,
absolute salinity and geopotential height. Two families sit behind one interface: a
55-term fit to the TEOS-10 standard, translated from Roquet's `polyTEOS10.py`, and a
second-order form whose seven coefficients are struct fields, shipped with six named
coefficient sets from Roquet's simplified-equation-of-state paper. Three source
files, 765 lines, and no dependencies at all.

**What of it is used.** Nothing. This is a survey record. It is read because
decision 0017 routes every property of the water through one door with two limbs,
and this is the package that answers what the ocean and sea-ice codes in this
organisation assume about seawater composition.

**Licence.** MIT, not the Apache 2.0 the organisation sweep recorded. **Version.**
0.3.10. **Read at.** `18f3797f74cbf9f478b13789d9957934b1063ab1`, committed
2025-04-10, in `/home/cfutro/git/CliMA/SeawaterPolynomials.jl`.

**Verdict.** Borrow ideas only, and the idea worth borrowing is the second-order
form rather than the TEOS-10 one. The package confirms decision 0017's reading
rather than challenging it: the Reference Composition is structural in the
TEOS-10 half, not a coefficient that could be swapped. What it adds is the
demonstration that a general quadratic equation of state with caller-supplied
coefficients sits comfortably behind the same interface as the standard, which
is the shape the door's refused-beyond-tolerance branch needs.

## The composition question, against decision 0017's two limbs

Decision 0017 splits the water door in two: a pure-water limb that is IAPWS-95,
`Sourced`, read at zero salinity by every terrain, hydrology and land kernel that
needs a property of fresh water; and a saline limb that is TEOS-10, `Irreducible`
inside the Reference-Composition anomaly tolerance and refused beyond it, because
Absolute Salinity is itself defined against that composition and the function
cannot be re-derived for another solute.

**This package is the saline limb only, and it carries no pure-water limb at
all.** That is not a gap in the package; it is a fact about what it is for. But
it matters for how the door is built here, because setting `S_A = 0` in this
package does not give the pure-water limb. The salinity coordinate is, with the
source's Unicode subscripts transliterated to ASCII here and throughout,

    s(S_A) = sqrt((S_A + dS) / S_au)

with `dS = 32.0` and `S_au = 40 * 35.16504 / 35`. At zero salinity that is
`sqrt(32 / 40.188)`, about 0.892, not zero: the polynomial is centred on ocean
salinity and fresh water is an extrapolation off the end of its fitted range, not
a limiting case of it. Anyone reaching for one package to serve both limbs would
get a fresh-water density from a fit that was never asked to produce one.

**The Reference Composition is in the coordinate transformation, not only in the
coefficients.** The constant `35.16504` in `S_au` is the Reference-Composition
Absolute Salinity of Standard Seawater, the defining number of Millero et al.
(2008), and it normalises the salinity axis before any coefficient is touched.
`teos10_reference_heat_capacity = 3991.86795711963` J/kg/K, the conversion
between conservative temperature and potential enthalpy, is fixed to the same
composition. So a solute anomaly does not enter this formulation as a
perturbation to a coefficient; it invalidates the variable the polynomial is a
function of. This is exactly the argument decision 0017 already makes, now
confirmed from an implementation: the saline limb is `Irreducible` because the
composition is upstream of the fit, not inside it.

**The Roquet coefficient sets are Earth twice over.** The docstring is explicit
that the six sets are "optimized for the 'current' oceanic temperature and
salinity distribution", and that the optimisation minimises the error in the
horizontal density gradient estimated from climatological temperature and
salinity fields against full TEOS-10. So they carry Earth's ocean composition and
Earth's present-day ocean state. A world with the same solute inventory but a
different temperature range is outside the fit on the second count even if it
passes on the first. That distinction is worth keeping: the anomaly tolerance
decision 0017 names is a composition tolerance, and these particular coefficients
would need a state tolerance too.

## Are the coefficients supplied by the caller? Two different answers

This is the question the row asks, and the package answers it twice.

**For the TEOS-10 fit, no, and the package says so in a comment at the top of the
file it would have to be changed in:**

> this implementation codes the polynomial weights as `const`, thus capturing the
> polynomial weights implicitly in function closures. As a result of this design,
> the polynomial weights cannot be modified without changing this file. To
> implement a polynomial approximation with settable weights, the struct
> `TEOS10SeawaterPolynomial` should be modified to carry the weights explicitly.

And `struct TEOS10SeawaterPolynomial{FT} <: AbstractSeawaterPolynomial end` is
indeed a zero-field singleton: it carries a float type and nothing else. Naming
the limitation and naming the change that would lift it is better practice than
most trees in this survey manage, and it is still a closed door for a
configuration whose composition is not Earth's.

**For the second-order form, yes, every one of them.**
`SecondOrderSeawaterPolynomial` is a `@kwdef` struct with seven fields, one per
term of a quadratic in salinity, temperature and depth, each defaulting to zero.
The density anomaly and both sensitivity functions read those fields directly, so
a caller who supplies seven numbers gets an equation of state with no Earth in it
at all, and a caller who supplies zeros gets a constant-density ocean. The six
Roquet sets are then just named constructors that fill the struct.

That split is the useful finding. The package demonstrates, in one small
interface, both halves of what decision 0017 wants: a standard formulation fenced
to the composition it was fitted to, and a general parameterised form behind the
same functions for everything outside that fence. The general form here is only
quadratic, which is not enough for the door's full obligations, but the shape is
right and the cost of the general route is visibly small.

## The reference density, and what it defaults to

`BoussinesqEquationOfState(seawater_polynomial, reference_density)` takes the
reference density as a positional argument, which agrees with decision 0017,
where that density is `Derived` as the volume-mean in-situ density of the initial
state. The convenience constructors then supply defaults, and there are two
different ones:

- `TEOS10EquationOfState(FT=Float64; reference_density=1020)`, documented as the
  value Roquet used when fitting the coefficients.
- `RoquetEquationOfState(FT, coefficient_set; reference_density=1024.6)`,
  documented as "the average density of seawater at the surface of the world
  ocean".

Both are keyword defaults with their provenance written down, which is the honest
form of a default, and the TEOS-10 docstring goes further and quotes Roquet
saying the choice "varies significantly among OGCMs, as it is a matter of
personal preference". For this project both are still silent defaults across a
boundary: a density derived from the initial state is a different number, and
nothing here would notice the substitution. The same wrapper rule that the root
solver record names applies, one line long: the call site supplies the reference
density and never reaches a default.

## There is no refusal anywhere

Decision 0017 says the saline limb is refused beyond the Reference-Composition
anomaly tolerance. This package cannot refuse anything. A grep of `src/` for a
clamp, an error, an assertion, a bounds check or a NaN test returns nothing: the
three functions are straight polynomial evaluation with no validity domain, no
salinity range, no temperature range and no depth range. Pass it a brine, a
supercritical temperature or a positive geopotential height and it returns a
number.

That is the assumption this project would have to catch, and it is the reason no
adoption is proposed. The refusal is not something a wrapper adds around a
package that half-does it; it is the entire mechanism decision 0017 relies on,
and it would have to live in this project's door with the package, if used at
all, behind it.

One smaller note. `RoquetSeawaterPolynomial` dispatches on its coefficient-set
argument by `eval(Symbol(coefficient_set, :RoquetSeawaterPolynomial))(FT)`, a
runtime `eval` into module scope keyed on a symbol or string. It is
construction-time only and never in a kernel, so it costs nothing at runtime, but
it is a convention travelling by name through the compiler rather than through
dispatch, and it is the kind of thing that cannot be checked at the point of
reading.

## Assumptions it carries

**Earth defaults (A2, A3).** Present but confined, and every one of them is
seawater rather than planet. The Reference-Composition salinity `35.16504`, the
reference heat capacity `3991.86795711963`, the normalisations `Theta_u = 40`,
`dS = 32`, `Z_u = 1e4`, the two reference densities, and the fitted
coefficients of both families. No gravity, no radius, no rotation rate, no solar constant: a grep
for the usual Earth literals returns nothing. `Z_u = 1e4` metres is a depth
normalisation sized to Earth's ocean and is the one constant that is about the
planet rather than the water.

**Calendar and time (A1).** Clean negative. The package has no notion of time at
all; every function is a pointwise algebraic evaluation.

**Grid and index base (A6).** Clean negative. Pointwise and scalar; there is no
array, no grid and no index anywhere in the package.

**Precision.** Parameterised on `FT` throughout, with a `with_float_type`
converter for both polynomial families, and the test suite runs every case in
Float64 and Float32. The TEOS-10 coefficients are `const` Float64 literals
converted at the call site, so a Float32 evaluation carries Float64 constants
into single-precision arithmetic, which is the right way round.

**Threading and GPU model.** None declared and none needed. Every function is
`@inline`, scalar, allocation-free and branch-free, so it is kernel-safe by
construction; that is a property of the code rather than a demonstrated
capability, since the package has no device test.

**Mutable global state (C5).** Clean negative for mutable state. The `const`
coefficient bindings in `TEOS10.jl` are a second authority in the sense that they
are unreachable and unoverridable, which is the complaint above, not a duplicate
live copy.

**Declared against demonstrated (C3).** Good for its size. `test/runtests.jl`
instantiates every coefficient set in both float types, checks the second-order
form's zero-point identity and its two sensitivities against the struct fields
directly, and checks the TEOS-10 evaluation against published check values from
Roquet: at conservative temperature 10 C, absolute salinity 30 g/kg and 1000 m
depth, density 1027.45140 kg/m3, with the two sensitivity coefficients checked at
the same point. That is a right answer from a primary source rather than a
regression against itself, which is what this project asks of a test. It is one
point, and the float-32 case runs at the default `isapprox` tolerance, which for
Float32 is a few tenths of a kilogram per cubic metre.

**Conservation identity (D4).** Not applicable and not run. An equation of state
conserves nothing; the identity that stands in its place is the check-value
comparison above, which the tree does perform.

## What carries

1. **Confirmation, from an implementation, that the saline limb is
   `Irreducible`.** The Reference Composition sits in the salinity coordinate and
   in the definition of conservative temperature, upstream of every fitted
   coefficient. Decision 0017 reached that conclusion from the literature; this
   is the code agreeing with it, and worth citing in the record rather than
   re-deriving later.
2. **The two-family interface is the shape the door wants.** One set of
   functions, one abstract polynomial type, a standard fit fenced to its
   composition behind it, and a fully parameterised general form beside it. This
   project's door has to do the same thing at the tolerance boundary, handing off
   to the brine activity model of decision 0022 beyond it.
3. **A negative result on the pure-water limb.** Zero salinity is not the
   fresh-water limit of this fit, so the two limbs of decision 0017 cannot be
   served by one polynomial family. That is an argument for the decision's
   existing split and against any later shortcut that would collapse it.
4. **Nothing on the refusal.** No adjacent package in this survey refuses outside
   its validity domain, and this one is the cleanest example yet of the pattern:
   a careful, well-tested, well-documented fit with no domain at all.

## If an adopt were ever proposed

It is not. Were the second-order form proposed as the general-composition route,
the decision it would need is an amendment to 0017 naming a quadratic equation of
state as the declared form outside the Reference-Composition tolerance, with the
seven coefficients carrying dispositions of their own. The leak tests are already
mostly registered. `ocean.teos10_check_values` covers both halves of what this
package lacks: it checks density, thermal expansion, haline contraction, heat
capacity and sound speed against the manual's published check points, and it
requires a refusal by name outside the declared domain and outside the
Reference-Composition tolerance, with its threshold naming a planted
out-of-domain state and a planted out-of-tolerance composition as the positive
controls. A package with no validity domain cannot pass the second half of that
oracle on its own, which is the argument for the refusal living in this
project's door. The one test not yet registered is a lint refusing any
construction of an equation of state that does not pass the reference density
explicitly, matching the rule the root solver record names for tolerances.

## Checklist

| item | result |
| --- | --- |
| A1 day and year | clean negative; no time of any kind |
| A2 planetary constant block | none; the constants are seawater properties, listed above |
| A3 Earth literals | clean negative for the usual set; the Earth content is `35.16504`, `3991.86795711963`, `Z_u = 1e4`, the reference densities `1020` and `1024.6`, and the fitted coefficients |
| A6 grid and index base | clean negative; pointwise scalar functions, no array |
| B4 comment against value | comments are accurate throughout, and the file's own header comment correctly states that the TEOS-10 weights cannot be changed without editing it |
| B5 clamps and limiters | none, which is the finding: no validity domain, no range check, no refusal |
| C1 use site of every constant | the salinity normalisation is read in `s(S_A)` before any coefficient; the reference densities are read at construction |
| C3 declared against demonstrated | every coefficient set instantiated in both float types; TEOS-10 checked against published values from Roquet at one state point; no device test |
| C4 fail-open branches | the whole package is fail-open by construction: it evaluates a polynomial wherever it is asked. Two documented keyword defaults for the reference density |
| C5 duplicate state and second constant sets | no mutable global state; the `const` weights are unreachable rather than duplicated |
| D2 boundary field by field | four scalars in (conservative temperature in C, absolute salinity in g/kg, geopotential height in m negative downwards, an equation-of-state struct), one scalar out; the sign convention on height is stated in every docstring |
| D4 conservation identity | not applicable; the check-value comparison stands in its place and the tree runs it |

## References

- The organisation sweep that flagged this package:
  `docs/imports/clima-organisation-sweep.md`, which recorded the licence as
  Apache 2.0; it is MIT.
- The plan this record answers to: `docs/plans/clima-survey.md`, the ocean and ice
  group.
- Decision 0017 (the water door's two limbs, the Reference-Composition anomaly
  tolerance, the Boussinesq reference density as `Derived`), decision 0004 (the
  declared ocean solute inventory), decision 0022 (the brine activity model
  beyond the tolerance), decision 0012 (the adopt, borrow and reject lists this
  verdict feeds).
- Roquet, F., et al. "Accurate polynomial expressions for the density and
  specific volume of seawater using the TEOS-10 standard." Ocean Modelling (2015),
  the source of the 55-term fit, and "Defining a Simplified yet 'Realistic'
  Equation of State for Seawater." Journal of Physical Oceanography (2015), the
  source of the six second-order coefficient sets. The first is held in
  `docs/references/INDEX.md`; the second is not, and is filed for ingest. The
  fence in decision 0017 rests on Millero et al. (2008), which is held.
