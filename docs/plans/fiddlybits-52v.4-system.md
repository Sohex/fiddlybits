+++
epic = "fiddlybits-52v.4"
title = "The System struct, the five dispositions, the Earth quarantine, and the measured dependency graph"
decisions = ["0004", "0007", "0009", "0010", "0030", "0034"]
requirements = ["REQ-SYS-001", "REQ-SYS-002", "REQ-SYS-003", "REQ-SYS-008", "REQ-SYS-101", "REQ-SYS-103", "REQ-NUM-001"]
oracles = ["system.gravity_and_figure", "system.disposition_refusals", "system.derived_fields_reproduce", "system.dependency_subset", "build.lint_positive_controls"]
status = "filed"
date = 2026-09-10
+++

## Scope

This plan builds the only place a quantity describing the system can live: the five
disposition types, the `System{FT}` struct that carries them, the strip to isbits
constants that is the one route to a device, the quarantined Earth denominators, the
measured dependency graph, and the five test instances of the M0 deliverable.

It also builds `Profile`, which the M0 deliverable of decision 0034 names and which
no row carried: a value, never a code path, holding each component's level, ladder
and cadence, the precision of the fast fields, the memory ceiling and every loop's
exit bracket. It sits here rather than with the kernels because it is declared data
with refusals, like `System`, and because the run identity of decision 0010 hashes
both. Carried by `fiddlybits-52v.4.8`. Two things about it are decided here rather
than left to the row. The spacing a level gives is the closed form
`sqrt(4 pi R^2 / (20 * 4^L))`, so `Profile` chooses a level from a target spacing
without reaching into `Mesh`, which sits above it; the mesh's area identity is what
checks that closed form. And the ratio of that spacing to the deformation radius,
which decision 0014 wants reported in the profile record, needs the first-guess
column of REQ-ATM-017, which is M3's; at M0 the record carries it as a declared
absence by name, never as a number.

It does not build the clock, the orbit solve or the instellation, which read `System`
and belong to `fiddlybits-52v.5`. It does not build the gas-mixture property group of
REQ-ATM-017: the condensable and the composition are declared fields of `System` here,
and the property group derived from them is the atmosphere's, carried by the M3 plan
`fiddlybits-84a.1`.

The fields this plan declares are the foundational set of decision 0004 and nothing
else. A quantity that the model can derive is `Derived` or is a state of the run, and
a quantity the model has no mechanism for is a `Bracketed` initial condition. The
struct is the boundary that makes that distinction enforceable, so a field added here
without one of the five dispositions is the failure the whole plan exists to prevent.

## Module boundaries

| path | holds | row |
| --- | --- | --- |
| `src/Dispositions/` | the five types, the locator, the sweep specification, the one accessor | 52v.4.2 |
| `src/Systems/` except `tracking.jl` and `profile.jl` | `System{FT}` and its blocks, the constructor refusals, `strip` | 52v.4.3 |
| `src/Systems/tracking.jl` | `TrackingSystem`, the declared graph, `affected` | 52v.4.6 |
| `src/Systems/profile.jl` | `Profile`, its `Derived` cadence ceilings and their refusals | 52v.4.8 |
| `src/EarthRatios/` | the quarantined unit denominators | 52v.4.4 |
| `test/dispositions/` | the disposition suite and its refusal fixtures | 52v.4.2 |
| `test/system/` | the struct suite and the derived-field identities; `graph.jl` and `profile.jl` are their rows' | 52v.4.3, 52v.4.6, 52v.4.8 |
| `test/lint/lint_sourced.jl`, `test/lint/lists/sourced.toml` | the references lint, beside the other lints | 52v.4.2 |
| `test/planets/` | the five test instances, each constructed and checked | 52v.4.5 |

`Dispositions` references `Verdicts` for its refusals and `Dimensions` for the
dimension a value carries; it references nothing else, so it sits in group B of the
skeleton plan's include order. `Systems` references `Dispositions`, `Dimensions`,
`Reductions` for `error_bound`, the rounding bound of a `Derived` rule, and `Verdicts`,
and nothing below it; `Reductions` references `Backends` and `Verdicts`, so it is
included before `Systems`. `EarthRatios` references `Dispositions` only, and
is read by `Render` and by no physics module, which is what `lint_earth` decides.

`src/Systems/tracking.jl` and `src/Systems/profile.jl` are called out as their own
boundaries because three rows write into `src/Systems/` and a row never widens into
another's paths: 52v.4.6 owns `tracking.jl`, 52v.4.8 owns `profile.jl`, and 52v.4.3
owns every other file there.

## Types and functions

### The five dispositions

```
abstract type Disposition{T,D<:Dim} end

Sourced{T,D}      value, locator
Derived{T,D,N}    value, from::NTuple{N,Symbol}, rule::Symbol
Bracketed{T,D}    value, low, high, pushes_down, pushes_up, sweep
Irreducible{T,D}  value, argument, sensitivity
Closure{T,D,N}    law::Symbol, coefficient::Bracketed{T,D}, levels::NTuple{N,Int}
```

`value(d)` is the one door out of every disposition, so a consumer reads a quantity
without knowing how it was justified, and a quantity has one declaration site
(REQ-SYS-103). `dimension(d)` returns the `Dim` the value carries.

`Locator` carries the work's identifier and the table or equation the value is taken
from, both required. There is no constructor that takes an identifier alone: a value
quoted from a secondhand citation is not `Sourced` (REQ-SYS-001), and the table is
what distinguishes the two.

The set is closed the way the verdict vocabularies are closed, by a test rather than
by the language: `dispositions()` enumerates the five, and `test/dispositions/`
asserts that the subtypes of `Disposition` are exactly that enumeration. There is no
sixth constructor, so a tuned value is unrepresentable, and the test is what keeps it
so when someone adds a struct.

Each type refuses construction without its required fields, and the refusal names
the field. The refusals, each with the control that must fire:

| refusal | control |
| --- | --- |
| `Sourced` without a locator, or with a locator naming no table or equation | a locator built from an identifier alone |
| `Derived` whose `from` names a field the system does not have | a `from` naming an invented field |
| `Bracketed` whose value lies outside its own bracket, or whose two mechanisms are not both named | a value above its high end, and a bracket with one mechanism |
| `Irreducible` without an argument or without a bounded sensitivity | each omitted in turn |
| `Closure` whose coefficient is not `Bracketed`, or that names fewer than two levels | a `Sourced` coefficient, and a single level |

**The reference check is a lint, not a constructor refusal.** Decision 0007 says
`Sourced` values are refused by the references lint unless the cited work is marked
`read`, and a lint is the right shape: a constructor that read a Markdown table at
runtime would make a package's behaviour depend on a documents directory being
present. `lint_sourced` walks every `Sourced` locator in `src/` and `test/planets/`
and refuses one whose identifier is not marked `read` in `docs/references/INDEX.md`.
It lives in the lint suite beside the others, with a dirty fixture citing a `held`
row and a clean one citing a `read` row, and joins the table
`build.lint_positive_controls` walks. The index is a live document and the lint
re-reads it, so a paper moving from `held` to `read` arms every value citing it with
no value edited.

### The struct

`System{FT}` carries the blocks of decision 0004 and no others, and beside them the
root seed decision 0010 places in the system:

```
System{FT}(; stars, planet, orbits, moons, inventories, numerics, root_seed)
  stars        NTuple{N,Star},  N >= 1
  planet       Planet           bulk and lithosphere
  orbits       OrbitHierarchy   one Orbit per body pair, each naming its reference plane
  moons        NTuple{M,Moon},  M >= 0
  inventories  Inventories      volatiles, crustal composition, ocean solutes
  numerics     Numerics         facts about a run, not about the system
  root_seed    Irreducible      a dimensionless UInt64, the root seed of the counter-based generator
```

`Star` declares mass, age and metallicity as its primaries, with luminosity,
effective temperature, radius and spectrum `Derived` from a carried stellar model or
`Bracketed` where none is carried. The radius is never absent, because the eclipse
and transit geometry of decision 0032 reads it. Variability is zero or more cycle
components; a component of zero amplitude is admissible, and its period is never read
as a window.

`Planet` carries the bulk and the lithosphere block. The bulk is the mass, the radius
or a composition vector, the sidereal rotation period, the obliquity, and
`sub_primary_longitude_at_epoch`. Every member of the lithosphere block is `Bracketed`,
with both ends argued from the declared mass, age and bulk composition.

Decision 0004, section The spin axis and the rotation phase in the orbit frame, defines
the two angles:

- `obliquity` is the angle from the planet's orbit normal to the positive pole of
  rotation of decision 0005, admitted in `[0, pi]`, with the dispositions of any
  declared angle.
- The sense of rotation relative to the orbit normal is `Derived` from it and is never a
  keyword. `rotation_sense(planet)` is `:prograde` where `cos(obliquity)` exceeds its
  rounding, `:retrograde` where `-cos(obliquity)` does, and `NotEvaluable` by name
  between. The threshold comes from `Reductions.error_bound`, as the equinox kind's does.
- `sub_primary_longitude_at_epoch` is the body-fixed longitude, in `(-pi, pi]` (the
  range `Mesh.longitude` returns), of the direction from the planet toward
  `orbits.planet.primary` at `t = 0`. It is `Irreducible` on a generated configuration
  and `Sourced` on one standing for a body with a published orientation model.
- `strip` carries both angles as plain `FT`.

The readers are `Orbit.positive_pole`, `Orbit.body_orientation`,
`Orbit.sub_source_longitude` and `Orbit.hour_angle`, all in the time plan's section The
orbit. `fiddlybits-52v.4.13` adds the fields after `fiddlybits-52v.4.3` merges.

`Numerics` and `Profile` both describe a run, and the plan has to say where the line
is or they become two homes for one quantity. `Numerics` holds declared conventions
that are facts about how this system is represented and that no profile may vary:
the epoch reference of decision 0008 (event kind, source index, offset in seconds),
the reference pressure of the Exner function (decision 0013), and the precision the
geometry is formed in, which the mesh finding fixes at double. Everything a profile
may vary between two runs of one system, which is every level, ladder, cadence,
fast-field precision, ceiling and exit bracket, is `Profile`'s and appears in
`Numerics` nowhere. The suite asserts the two structs' field names are disjoint,
which is the mechanical form of that rule. `Numerics` is a field of `System` so the
run identity of decision 0010 hashes one object; `Profile` is hashed beside it.

The root seed of the counter-based generator sits on neither side of that line. It is
not a convention of how the system is represented, so it is not a member of
`Numerics`; and it is not a setting a profile resolves the system with, because decision
0010 (amendment of 2026-09-13, sections Stochastic streams and What the key names) makes
it a field of the system: it chooses which realisation of the system's stochastic
processes a run draws, so an ensemble over seeds is a sweep over systems, and a
stochastic output reaches its seed through the parameter subset of the component that
draws, exactly as a sweep member reaches its swept value. It is therefore `root_seed`, a
top-level field of `System` beside the blocks, a required keyword like every other. Its
value is a `UInt64`, the word `Provenance.philox_key128` reads, and `strip` carries it as
a plain `UInt64`, so a kernel keys `philox_draw` on `strip(system).root_seed`.

A seed is not a physical constant, and it still carries one of the five dispositions,
because every constant does. It is `Irreducible`, and the constructor admits no other.
Read against each definition of decision 0007:

- `Sourced` is a measured or laboratory value with the table or equation it comes from.
  Nothing measures a seed; a seed copied from a publication cites someone's arbitrary
  choice, not a measurement.
- `Derived` is computed by a named rule from other fields. A rule over the system's
  other fields would tie the realisation to the parameters: two sweep members that
  differ in one constant would draw unrelated streams, so the constant's effect and a
  seed's would be confounded, and an ensemble of realisations of one system could not be
  declared, because every member would derive the same seed.
- `Bracketed` is a value inside an interval with the mechanism that pushes it down and
  the one that pushes it up. Every word from 0 to `typemax(UInt64)` is equally
  admissible and nothing pushes a seed either way, so both mechanisms would be invented,
  and an invented mechanism is the tuning the disposition exists to exclude.
- `Closure` stands for truncated sub-grid variance and scales with the spacing. A seed
  stands for nothing under the grid and does not scale.
- `Irreducible` is a value with no derivation available to this system, with the
  argument for why none exists and the sensitivity finding that says what it moves. A
  seed meets it exactly. Philox output is a pseudo-random function of its key (Salmon et
  al. 2011, the construction `src/Provenance/rng.jl` cites), so any seed fixed without
  reference to the results it serves is as good as any other and none can be derived;
  that is the argument decision 0052 makes for `Backends.ENSEMBLE_SEED`. What a seed
  moves is the realisation of every process that draws from it, and its sensitivity
  names the finding that measures the spread of those outputs over an ensemble of seeds.
  As decision 0052 says of its own seed, a seed chosen or changed after the result it
  moves has been seen is a tuned value.

The constructor is keyword-only with no defaults. Its refusals:

| refusal | why | control |
| --- | --- | --- |
| a missing keyword, named | a default is an assumption nothing declares | each block omitted in turn |
| any field named `day` | the solar and mean solar day are derived (decision 0008) | a keyword spelled `day` |
| a `Derived` field supplied by the caller and disagreeing with the computed value | two values that can disagree | a supplied surface gravity off by more than the derivation's own tolerance |
| a planet orbit declared as top-of-atmosphere flux when more than one star is declared | the flux is then not a constant of the orbit | the flux form with two stars |
| a stellar model evaluated outside its declared mass, age and metallicity domain, named | a relation is silent about the sample it was not fitted on | a mass above the model's domain |
| a spectrum interpolated outside the grid's convex hull in its own axes | the same | a point outside the hull |
| a scalar assigned where the ladder's length is required | REQ-SYS-103 item 5 | a scalar for a per-level parameter |
| a `sense` keyword on a rotation | the sense is `Derived` from the obliquity (decision 0004), and a second declaration of it could disagree | a rotation declared with a sense |
| an obliquity outside `[0, pi]`, or a sub-primary longitude at the epoch outside `(-pi, pi]` | each is one angle with one range, and a value outside it is a second name for a value inside | an obliquity of 3.2, and a longitude of 3.5 |
| a synchronous rotation whose `Derived` sense is not prograde | a rotation turning against its orbit at the orbital period does not keep one face to the primary | a synchronous rotation at an obliquity of three quarters of pi, and at `pi / 2` |
| a `root_seed` that is not a dimensionless `Irreducible` over `UInt64` | the seed has one disposition and one word width, above | a plain `UInt64`, an `Int64` and a `Float64` value, a seed with a dimension, and a `Bracketed` and a `Sourced` seed |
| an orbital eccentricity outside the elliptic range `[0, 1)` | the Kepler solve refuses nothing itself, because a refusal inside a per-cell kernel has nowhere to go (decision 0008, amendment of 2026-09-10) | an eccentricity of one, and of one and a half |

`g(r, phi)` is the canonical `Derived` field: computed from the mass, the radial
distance and the rotation vector with the centrifugal term, never stored as a surface
value. The figure of the planet is a `Derived` hydrostatic figure from the rotation
and the interior model, or a declared absence with the equator-pole gravity
difference `Bracketed` and reported. The mesh radius of decision 0005 is the
volumetric mean radius of that figure, which is the one number `Mesh` is given and
the only coupling between these two plans.

The eccentricity guard is this constructor's and lives here. `Orbit` sits above
`Systems` in the include order, so the guard cannot be a call into `Orbit`; the
function `Orbit.check_eccentricity` that `fiddlybits-52v.10` merged is therefore a
second definition of this refusal, and `fiddlybits-52v.5.3` removes it and moves its
test here.

`strip(system)` returns an isbits struct of plain `FT` values, and the root seed as a
plain `UInt64`, and is the only route from parameters to a device. It is a function of the system alone, so two strips of
one system are identical, and `isbits(strip(system))` is asserted for every test
instance.

### The graph

`TrackingSystem` wraps a `System` and records every field read, per component, during
a dry run on the smallest mesh. What a component declares it reads is not this
module's to say: the component declaration is the coupling layer's (`declare` in
`fiddlybits-52v.11.1`), which sits above `Systems`. So this module takes the declared
graph as plain data, a name to a set of field symbols, and never a component. The
test is `recorded` is a subset of `declared`, run over every declaration it is given;
a declared edge with no recorded read in the coupled case is reported rather than
failed, because a component may legitimately not read a field on one configuration.

At M0 there are no components, so `system.dependency_subset` runs on fixture
declarations and fixture readers in `test/system/`, which decides the machinery, and
runs again on the real components from M1, which decides the graph. The verify row
records which.

`affected(field, graph)` answers "what re-runs when this changes" from the declared
graph it is handed, never from a list kept by hand (REQ-SYS-008). The declared sets are what artifact keys
are computed from (decision 0010), so changing one field changes the keys of exactly
the artifacts whose components declared it, and that is a property this plan makes
computable rather than a claim.

### The quarantine

`EarthRatios` holds Earth's numbers as unit-conversion denominators whose names
forbid physical use: a name says what it is a unit of and that it is a unit, so that
a physical use reads wrongly at the call site before any lint sees it. Each member is
`Sourced` with its locator. The module is read by `Render` and by nothing else, and
`lint_earth` decides that; the lint and its fixtures already exist, so this row adds
the members and the suite asserts the lint still passes with them present.

### The instances

`test/planets/` holds the five instances the M0 deliverable of decision 0034 names,
each one constructor call with every field declared:

| instance | declares |
| --- | --- |
| `Earth()` | IAU and CODATA values with `Sourced` locators; a comparison to report the distance from, never a target |
| `SyntheticNonEarth()` | a carbon-dioxide bulk atmosphere, higher gravity, prograde, high eccentricity, non-zero obliquity, one star, one moon |
| `SyntheticSynchronous()` | synchronous rotation, zero obliquity, an M-dwarf spectrum, no moon |
| `SyntheticRetrograde()` | retrograde spin, two stars, the epoch on the periapsis event |
| `SyntheticComposition2()` | a hydrogen-helium bulk with a different condensable declared absent |

None is a real body, and every field is a declared value chosen so that closed forms
exist for the derived quantities. That is what lets `system.derived_fields_reproduce`
run on all five: a derivation that is right on one configuration by coincidence has a
test that can fail.

## Oracles

`system.gravity_and_figure` is already in the registry and is this plan's central
identity. Three entries are added under the `system` subsystem, all tier 1, all
provisional until the verify row runs them.

| id | right answer | the mutation that must make it fail |
| --- | --- | --- |
| `system.disposition_refusals` | every disposition refuses construction without each of its required fields, and the subtypes of `Disposition` are exactly the five | a sixth subtype declared in a fixture, which the enumeration must report; each required field omitted in turn, each of which must refuse |
| `system.derived_fields_reproduce` | every `Derived` field of `System` recomputed from its own inputs equals the constructed value on all five instances, and a caller-supplied value that disagrees is refused | a `Derived` rule replaced by the Earth value it happens to equal, which the synthetic instances must catch |
| `system.dependency_subset` | the recorded read set of every component is a subset of its declared set, and `affected(field)` lists exactly the components declaring that field | a component reading a field it did not declare, which must fail; a declared edge removed, which `affected` must stop reporting |

`system.derived_fields_reproduce` is the M0 gate item "every `Derived` field of
`System` reproduced from its own inputs on `Earth()` and on the synthetic instances".
It enumerates the `Derived` fields from the struct rather than from a list, so a field
added without an identity fails the oracle instead of being skipped by it.

The Earth quarantine gate item is `lint_earth`, already carried by
`build.lint_positive_controls`; this plan adds the members the lint protects and does
not add a second oracle for the same question.

## Rows filed

| row | tier | boundary | acceptance |
| --- | --- | --- | --- |
| 52v.4.2 | sonnet | `src/Dispositions/`, `test/dispositions/`, `test/lint/lint_sourced.jl`, `test/lint/lists/sourced.toml` | `system.disposition_refusals` passes with every control firing, each named; `lint_sourced` joins the lint table and decides on both its fixtures |
| 52v.4.3 | frontier | `src/Systems/` except `tracking.jl` and `profile.jl`, `test/system/` except `graph.jl` and `profile.jl` | every constructor refusal fires on its control, each named, the eccentricity guard among them; `isbits(strip(system))`; `system.gravity_and_figure` passes; `Numerics` and `Profile` field names are disjoint |
| 52v.4.4 | local | `src/EarthRatios/` | every member is `Sourced` with a locator and named as a unit; `lint_earth` still passes on the tree and still flags its dirty fixture |
| 52v.4.5 | sonnet | `test/planets/` | all five instances construct with no refusal; `system.derived_fields_reproduce` passes on all five |
| 52v.4.6 | frontier | `src/Systems/tracking.jl`, `test/system/graph.jl` | `system.dependency_subset` passes on fixture declarations with both controls firing; `affected` takes the graph as data and reaches no component |
| 52v.4.8 | frontier | `src/Systems/profile.jl`, `test/system/profile.jl` | the cadence ceiling refuses with a control per bounding term; brackets are dimensionless; both profiles construct on all five instances |
| 52v.4.7 | sonnet | none; reports only | all five oracles ran; verdicts by name |

52v.4.5 depends on 52v.4.3 and 52v.4.4; 52v.4.6 depends on 52v.4.3; 52v.4.3 depends
on 52v.4.2.
