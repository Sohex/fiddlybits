+++
epic = "fiddlybits-52v.9"
title = "The shallow-water go/no-go on the triangle C-grid, with the reference arm beside it and the fallback ladder declared"
decisions = ["0005", "0011", "0012", "0013", "0025", "0027", "0034"]
requirements = ["REQ-TER-011", "REQ-NUM-002", "REQ-NUM-005", "REQ-ATM-017"]
oracles = ["core.williamson_tc1", "core.williamson_tc2", "core.williamson_tc5_tc6", "core.checkerboard_divergence_mode", "core.hollingsworth_check", "core.laplacian_eigenvalues", "core.reference_arm_distance"]
status = "filed"
date = 2026-09-10
+++

## Scope

This plan builds the shallow-water equations on the triangle C-grid, the time
stepping around them, the standard test cases as registered oracles, the
SpeedyWeather reference arm, and the written verdict on whether the C-grid carries
the core.

This is the one M0 area that can return no. The gate of decision 0034 is a go/no-go
on the triangle C-grid, and decision 0013 declares the fallback ladder in advance: a
Z-grid formulation on the same triangles, then a cubed-sphere finite-volume core, and
never a spectral core. Declaring the ladder before the gate runs is what stops a
failing gate from becoming a negotiation about the gate.

Two things follow from that and shape every row here:

- **The bounded effort is declared at the start of this milestone, not discovered
  during it.** Decision 0013 says the fallbacks apply "if it fails after a bounded
  effort declared at the start of that milestone". That declaration is a row of its
  own, `52v.9.7`, and it is written before 52v.9.2 begins. It is not an effort
  estimate, which this project does not carry; it is a statement of which remedies
  are in scope for the gate, in what order, and what evidence would end the attempt.
- **The verdict is a dated finding, whichever way it goes.** A gate that passes
  quietly and a gate that fails loudly should leave the same kind of record.

What this plan does not build: the three-dimensional core, the hybrid vertical
coordinate, the baroclinic cases and the idealised-forcing climatology, all of which
are M3 and are carried by `fiddlybits-84a.1`. Shallow water is built and validated
first; the three-dimensional core follows on the same operators.

## Module boundaries

| path | holds | row |
| --- | --- | --- |
| `src/ShallowWater/operators.jl` | the C-grid discretisation, the reconstruction, the filter | 52v.9.2 |
| `src/ShallowWater/step.jl` | the time scheme, the derived timestep ceiling | 52v.9.3 |
| `src/ShallowWater/cases.jl` | the standard cases as forcing structs owning their own times | 52v.9.4 |
| `test/shallowwater/` | the case suites, the mode suites, the convergence suite | 52v.9.2 to 52v.9.4 |
| `test/reference_arm/` | the SpeedyWeather arm and `no_defaults.jl`, in its own environment | 52v.9.5 |
| `notes/findings/` | the go/no-go verdict | 52v.9.6 |

`ShallowWater` is a new top-level submodule and the skeleton plan did not name it,
because no M0 area row asked for one at the time. It is added to
`src/Fiddlybits.jl` in group G, after `Fields` and before `Oracles`, and the
skeleton plan's table is amended rather than a second layout being kept here.

## Types and functions

### The discretisation

Mass and thermodynamic variables at triangle centres, normal velocity on the three
edges. The tangential velocity is reconstructed; the discretisation conserves
vorticity and divergence in the form decision 0013 names.

**The checkerboard mode is a named part of the discretisation, not a tuning.** On the
bisected icosahedron there are 1.5 edges per triangle, so the C-grid carries 1.5
normal-velocity degrees of freedom per mass cell, where the hexagonal C-grid carries
three. Too few and too many respectively; the consequence for triangles is a spurious
checkerboard divergence mode. The divergence-averaging filter is the operational
remedy and it enters as part of the scheme with its own oracle, run with and without
the filter so the mode is shown to exist before it is shown to be suppressed.

**The Hollingsworth check is separate and applies to any polygon.** It arises from an
inconsistency between the kinetic-energy gradient and the vorticity-flux terms of the
vector-invariant momentum equation, and the remedy is an energy-consistent
formulation of those terms rather than a filter. Two different pathologies with two
different remedies, and the plan keeps them apart because conflating them would let
the filter be credited with a cure it does not effect.

**No thermodynamic literal enters the core.** The reference core's published
formulation carries the gas constant, the heat capacities, `kappa` and `epsilon` as
literals of the one atmosphere it was built for, and those literals are
dimensionless, so `lint_literals` does not catch them. They are `Derived` from the
declared composition through the property group of REQ-ATM-017, and the Exner
reference pressure is a declared field of the system struct. Shallow water needs
none of the property group: its two constants are the gravity, which is `System`'s
`Derived` `g(r, phi)`, and the layer depth, which the case declares. So this plan
does not depend on M3's property group, and the door it reads gravity through is the
one the three-dimensional core will read `kappa` through, which is what makes that
core a continuation rather than a rewrite.

### The step

The timestep is a `Bracketed` numeric in the profile with a `Derived` ceiling: a
Courant condition from the radius, the level and the wave speed that binds, the wave
speed evaluated over the profile's state brackets per REQ-NUM-005. The constructor
refuses a step above its ceiling, which is decision 0008's rule and not a new one.

Whether the scheme is semi-implicit or split-explicit is decided inside 52v.9.3 with
its argument recorded, because the choice turns on which wave speed binds and that is
a property of the configuration rather than of the scheme.

### The cases

Williamson cases 1, 2, 5 and 6, each a forcing struct that owns its own times in
seconds, with the core reading none of them. That ownership is the pattern the
registry's baroclinic rows already use: the published case's day is written as its
seconds on the arm where the published bar applies, and on spread arms the elapsed
time scales with the rotation period and the verdict is REPORT.

Each case runs at Earth parameters and at two other planetary parameter sets. The
published error norms are the bar on the Earth arm only. This is the tier-3 rule
applied at tier 1: a published norm is a statement about one configuration, and a
different configuration through the same case is REPORT.

### The reference arm

SpeedyWeather.jl runs the same cases with the same `System`, compared as a distance
report and never as a target. It is not a component, it does not run in the coupled
system, and it restores the second implementation the predecessor lost when it
removed its models' alternate code paths.

The arm lives in its own environment, `test/reference_arm/Project.toml`, and is not
an extra of the package. It is not a component and does not run in the coupled
system, so it does not belong in the package's manifest, and the hosted clean-room
job of decision 0043 does not install it: the arm runs in the local gate only,
where the card and the data are. Its import record already exists and its heading
resolves for the harness, should it ever enter the manifest.

`test/reference_arm/no_defaults.jl` is the leak test
`docs/imports/speedyweather-reference-arm.md` names: the arm must be driven from the
declared `System` with no package default reaching a result. SpeedyWeather carries a
calendar clock with a fixed day and year and Earth defaults, which is why decision
0012 refuses it as a component, and the arm is only trustworthy if those defaults are
shown not to arrive.

### The verdict

A written finding in `notes/findings/` naming, for each gate item, the verdict and
the evidence; and the go/no-go against the fallback ladder. A pass says which
remedies were needed. A fail names the ladder rung it hands to and why.

## Oracles

Five registry entries exist. Two are added.

| id | right answer | the mutation that must make it fail |
| --- | --- | --- |
| `core.williamson_tc1` | the cosine bell's error norms after one revolution | a tangential reconstruction shifted by one edge |
| `core.williamson_tc2` | steady geostrophic flow does not grow beyond roundoff accumulation | the same, and a Coriolis term dropped |
| `core.williamson_tc5_tc6` | norms against reference solutions for the mountain and the Rossby-Haurwitz wave | a mass flux counted twice |
| `core.checkerboard_divergence_mode` | the grid-scale divergence mode is bounded and not growing with the filter, and present without it | the filter removed, which must show the mode, so the oracle is not evidenced only by the passing arm |
| `core.hollingsworth_check` | no growth of the spurious mode under the standard trigger | the energy-consistent form replaced by the naive one, which must grow |
| `core.laplacian_eigenvalues` | the discrete Laplacian's spectrum against the analytic spherical eigenvalues, on the production mesh at the production level | the same test on a synthetic near-regular mesh only, which REQ-TER-011 forbids as sufficient |
| `core.reference_arm_distance` | the distance between the two arms on each case, reported with no bar | a default from the reference package reaching a result, which `no_defaults.jl` must catch |

`core.laplacian_eigenvalues` is the check the mesh plan deferred here. REQ-TER-011
requires orthogonality and the operator built on it to be tested on the production
mesh at the production level and never only on a synthetic near-regular one, and this
is the first plan that has an operator to test.

`core.reference_arm_distance` carries no bar and says so in its own threshold. The
arm is an independent implementation, not a truth, and a bar against it would make it
one.

## Rows filed

| row | tier | boundary | acceptance |
| --- | --- | --- | --- |
| 52v.9.7 | frontier | `docs/decisions/0013` amendment, or a new record | the bounded effort of decision 0013 is declared before 52v.9.2 begins: which remedies are in scope, in what order, and what evidence ends the attempt |
| 52v.9.2 | frontier | `src/ShallowWater/operators.jl`, `test/shallowwater/operators.jl` | `core.checkerboard_divergence_mode`, `core.hollingsworth_check` and `core.laplacian_eigenvalues` pass, each with its control firing; no thermodynamic literal in the module, asserted |
| 52v.9.3 | frontier | `src/ShallowWater/step.jl`, `test/shallowwater/step.jl` | the scheme choice is recorded with its argument; a step above the `Derived` ceiling refuses, naming the wave speed that bound it |
| 52v.9.4 | sonnet | `src/ShallowWater/cases.jl`, `test/shallowwater/cases.jl` | the four Williamson cases pass at Earth parameters against the published norms, and run at two other parameter sets as REPORT; each case's forcing struct owns its times and the core reads none |
| 52v.9.5 | sonnet | `test/reference_arm/` including its own `Project.toml` and `Manifest.toml` | `core.reference_arm_distance` reports; `no_defaults.jl` passes, with a fixture arm built without the declared `System` as its control; the arm's environment is separate from the package's and the clean-room job does not install it |
| 52v.9.6 | frontier | `notes/findings/` | the go/no-go verdict is a dated finding naming every gate item, its verdict and its evidence, and the ladder rung if it is no |
| 52v.9.8 | local | `src/Fiddlybits.jl`, `docs/plans/fiddlybits-52v.1-skeleton.md` | `ShallowWater` is added to the include order in group G and to the skeleton plan's table; `build.module_order_acyclic` still passes |

52v.9.2 depends on 52v.9.7, 52v.9.8 and on `fiddlybits-52v.4.8`, since the production
level `core.laplacian_eigenvalues` runs at is a profile setting; 52v.9.3 and 52v.9.4
depend on 52v.9.2;
52v.9.5 depends on 52v.9.4; 52v.9.6 depends on all of them. The area depends on the
mesh, fields and kernel areas entire.
