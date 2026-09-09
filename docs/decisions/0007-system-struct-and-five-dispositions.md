+++
id = "0007"
title = "One immutable System struct, keyword-only with no defaults, and exactly five constant dispositions"
status = "accepted"
date = 2026-09-08
+++

## Decision

Every quantity that describes the system being simulated is a field of one immutable
struct, `System{FT}`, with the shape of decision 0004: stars, planet (with its
lithosphere block), orbits, moons, inventories, and the numerics that are facts about
a run. The constructor is keyword-only and has no defaults; a missing field is an
error naming the field. Gravity is the canonical `Derived` field: `g(r, phi)` from
the mass, the radial distance and the rotation vector with the centrifugal term, and
a surface value passed by a caller is checked, never stored.
There is no Earth instance in the source tree. Earth exists as a constructor call in
a test file, and Earth's numbers exist in one quarantined module as unit-conversion
denominators whose names forbid physical use, enforced by a lint over the physics
modules.

### The five dispositions

Every constant, in the system struct and in every component, is wrapped in exactly
one of five types. There is no sixth constructor, so a "tuned" value is
unrepresentable.

- `Sourced{T}`: a measured or laboratory value with a citation that includes the
  identifier of the work and the table or equation the value comes from.
- `Derived{T}`: computed by a named rule from other fields. The constructor computes
  it; a caller who also passes a value is refused on disagreement. The rule is
  code, never a number written down.
- `Bracketed{T}`: a declared value inside a declared interval with both mechanisms
  named (what pushes it down, what pushes it up), and a sweep specification. The
  value is a point in a bracket, and the bracket is swept.
- `Irreducible{T}`: a value with no derivation available to this system, recorded
  with the argument for why none exists and a reference to the sensitivity finding
  that says what it moves.
- `Closure{T}`: a coefficient that stands for truncated sub-grid variance (an eddy
  diffusivity, a hyperdiffusion coefficient, a convective entrainment rate, a
  sub-grid distribution width, a hillslope diffusivity used as a closure). It is
  declared as a sourced scaling law in the grid spacing and the resolved state, with
  a bracketed dimensionless coefficient, and it must be swept across at least two
  mesh levels with a convergence-with-level oracle. A closure that does not scale with
  the level is wrong at every level but the one it was fitted at, and a fixed
  coefficient forced to be `Sourced` from a paper fitted at one resolution would
  either blow up or behave unphysically at another.

The `Closure` disposition is what keeps the "physics is not a knob" rule honest for
fluid closures: the law is sourced, the coefficient is bracketed and swept, and the
resolution dependence is stated rather than hidden.

### Strip and track

`strip(system)` produces an isbits struct of plain floats for kernels; it is the only
route from parameters to a device. A tracking wrapper logs every field access during
a dry run of each component on a tiny mesh, and a test asserts that the recorded
dependency set is a subset of the set the component declares. The declared sets are
what artifact keys are computed from (decision 0010), so "what depends on this
parameter" is a computed property of the build: changing one field changes the keys
of exactly the artifacts whose components declared it.

## Alternatives considered

- **Four dispositions** (no `Closure`). Reviewed and rejected: a diffusion
  coefficient that is right for one cell size is wrong for another by construction,
  and forcing it into `Sourced` would either forbid the resolution ladder or invite a
  hidden retune. The predecessor already treated its hyperdiffusion and its cloud
  fraction width as derived from resolution; this names that class.
- **A configuration file with defaults, overridden per body.** This is how
  parameter libraries in the ecosystem work, and it is exactly the implicit-Earth
  pattern: a default is an assumption that nothing declares. Lost; the constructor
  has no defaults, and the read-logging idea from those libraries is kept as the
  tracking wrapper.
- **Constants as plain numbers with a comment.** The predecessor's audit of its
  compiled models found dozens of constants with no configuration key that could not
  be bracketed, swept or declared, and four copies of one lapse rate in three
  languages. Lost.
- **A `Tuned` disposition that names itself.** The predecessor's rule: a tuning that
  names itself is still a tuning. Its disposition space is exactly the four ways a
  constant can have a usable origin; `Closure` adds the fifth way, not a sixth.

## Consequences

- `Sourced` values are refused by the references lint unless the cited work is
  marked `read` in the references index (decision 0003, principle 4).
- Every `Bracketed` and `Closure` value is swept at the milestone that first runs the
  coupled system, and the spread is reported beside every result that depends on it.
- The count of `Irreducible` values is reviewed at every milestone.
- Reports that quote a value relative to Earth's (a flux as a fraction of the solar
  constant) do the division in the rendering layer using the quarantined
  denominators, never in physics.
- Oracles implied: the derived-versus-given refusal fires; the recorded dependency
  set is a subset of the declared set for every component; a lint finds no use of the
  quarantined Earth module outside rendering and unit conversion; every per-band,
  per-layer or per-class parameter array either has differing elements or carries a
  recorded argument for uniformity; every `Derived` field reproduces its closed form
  on `Earth()` and on a synthetic non-Earth instance (decision 0034, M0), so that a
  derivation right on one configuration by coincidence has a test that can fail.

## References

- The predecessor's four-way disposition vocabulary and the enumeration of tuned
  values: `/home/cfutro/docs/world/docs/src/reference/vocabulary.md`,
  `/home/cfutro/docs/world/notes/audits/tuned-values.md`.
- The predecessor's audit of constants with no configuration key:
  `/home/cfutro/docs/world/notes/audits/model-earth-centrism.md`, mechanism IV.
- The predecessor's audit of derived quantities written down and drifted:
  `/home/cfutro/docs/world/notes/audits/frozen-derived-quantities.md`.
- ClimaParams.jl, for the read-logging idea (decision 0012).

## Amendments

- 2026-09-08: the struct shape names the lithosphere block and the orbits block of decision 0004, gravity is named as the canonical Derived field g(r, phi), and the M0 gate validates every Derived field on a synthetic non-Earth instance as well as Earth(), from notes/findings/2026-09-08-implicit-earth-audit.md.
