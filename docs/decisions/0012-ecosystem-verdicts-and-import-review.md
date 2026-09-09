+++
id = "0012"
title = "Julia ecosystem verdicts, an import review for every dependency, and an external dynamical core as a reference arm"
status = "accepted"
date = 2026-09-08
+++

## Decision

External code is adopted only where it is exactly the right fit, and everything
adopted is examined for the assumptions it carries. The line: infrastructure that has
no planetary content (kernel abstraction, GPU arrays, adaptation, chunked storage,
hashing, a dimension algebra) may be adopted; a model core, a grid, a parameter
library or a clock built for another planet's concerns may not, however good it is.

### Verdicts

Adopt as infrastructure, each with an import review:

- KernelAbstractions.jl (portable kernels; CPU and CUDA backends).
- CUDA.jl and Adapt.jl (the GPU backend and device adaptation of structs).
- Zarr.jl (chunked, compressed, language-neutral arrays; version 2 until the
  version 3 path is complete).
- NCDatasets.jl (NetCDF, for export only, with a declared geometry).
- DynamicQuantities.jl (a runtime dimension algebra behind the field dimension
  type; not used inside kernels).
- SHA and UUIDs from the standard library.
- Julia 1.12, pinned. Static compilation with trimming is not depended on.
- ClimaTimeSteppers.jl, subject to a decision: implicit-explicit and
  strong-stability-preserving integrators that take a tendency function and an
  opaque state, with no grid, no column layout, no calendar and no planetary
  constant, which is the split decision 0023's fast tier describes with the
  implicit linear algebra left to the caller
  (`docs/imports/climatimesteppers-jl.md`).

ClimaTimeSteppers.jl is the CliMA survey's one adopt verdict, and it is a
candidacy rather than an adoption: this record does not take it, and it is not a
dependency until a decision does. That decision has these to settle. ClimaComms.jl
is a hard dependency of the integrators rather than a weak one, so the device and
context abstraction refused below arrives transitively, and the decision has to
say that the device is constructed from the profile and that
`ClimaComms.device()` and `ClimaComms.context()` are never called with no
argument, so that the environment variables they read are never consulted.
Without a convergence checker the Newton solve runs its iteration count and
reports nothing, so a non-converged implicit stage passes silently, and the
decision has to require a checker that refuses in the verdict vocabulary of
decision 0009. It has also to fix which tableau the fast tier uses, and to set the
tableau's element type against the state's explicitly rather than leave a
mixed-precision step to the default.

Borrow ideas, never code:

- Oceananigans.jl: location-typed fields with the location on the type and extent
  derived from it, the boundary condition classified in the type with a continuous
  or discrete form, metric-in-named-accessor finite-volume operators, stencil
  composition by putting a function in the field slot, `Flat` as a compile-time
  degenerate dimension, and the output writers
  (`docs/imports/oceananigans-jl.md`).
- ClimaCore.jl: axis-tensor vectors (covariant and contravariant components), the
  origin of the named-basis vector semantics in decision 0006; `LocalGeometry` as
  the only geometry an operator reads; and the named strict conversion `transform`
  beside the lossy `project`, so dropping a component has to be asked for by name
  (`docs/imports/climacore-jl.md`).
- ClimaParams.jl: logging every parameter read, the origin of the tracking wrapper
  in decision 0007, with the qualification the survey turned up: what it logs is
  what a component's constructor pulled out of a dictionary, against a name map
  that is at once the declaration and the reader, so decision 0007's subset test
  cannot fail under that design and the measurement has to be built here; the
  replayable log and the check for an override nothing read are the parts worth
  keeping (`docs/imports/climaparams-jl.md`).
- SpeedyWeather.jl: composable parameterisations and fused column kernels.
- Thermodynamics.jl: the saturation curve as a Clausius-Clapeyron integration over
  supplied heat capacities anchored at a declared triple point, and the
  molar-mass ratio derived from the two gas constants rather than stored, which is
  the shape REQ-ATM-017 asks for; the package itself covers one condensable in one
  lumped bulk gas at constant heat capacities and none of the transport half
  (`docs/imports/thermodynamics-jl.md`).
- RRTMGP.jl: the shape of the g-point loop, the separation of the per-g-point
  spectral fraction from the caller's total flux, and the two-stream coefficient
  forms with their numerical guards; the lookup struct is the RRTMGP data model
  rather than a table format, and out of range the solver clamps where this
  project must refuse (`docs/imports/rrtmgp-jl.md`).
- SurfaceFluxes.jl: the universal functions dispatched jointly on a parameter
  struct, a transport type and a scheme type, with the coefficients as struct
  fields; its roughness and gustiness surface is a set of fits at one gravity and
  one air density (`docs/imports/surfacefluxes-jl.md`).
- CloudMicrophysics.jl: one struct per scheme with an explicit name map, and the
  one-moment fall speed written as a drag balance in gravity and both densities;
  the condensable is water in the function names rather than in a declaration
  (`docs/imports/cloudmicrophysics-jl.md`).
- ClimaUtilities.jl: an exact integer clock whose epoch refuses rather than
  defaults, and a record of which inputs a run actually read; its regridders and
  readers assume a longitude-latitude source and a ClimaCore target
  (`docs/imports/clima-output-and-tooling.md`).

Do not adopt, with the reason:

- SpeedyWeather.jl: a spectral core on ring grids only, so it reinstates the grid
  crossing; a calendar clock with a fixed day and year and Earth defaults.
- Oceananigans.jl: no icosahedral grid, and none addable, since the fields are
  indexed by a triple of integers into a structured array; an ocean on that under
  an icosahedral atmosphere is the crossing again; gravity, radius, rotation rate
  and float type come from a mutable process-global defaults object
  (`docs/imports/oceananigans-jl.md`).
- ClimaCore.jl: the element topology is welded into the data layout, quadrilateral
  faces and vertices in the mesh interface against a tensor-product node index
  beneath every operator and every kernel launch, so a triangle mesh is a
  different library rather than a new mesh subtype; the cubed sphere is the
  symptom rather than the disease (`docs/imports/climacore-jl.md`).
- ClimaAtmos.jl: a model core on ClimaCore's cubed sphere, with a parameter
  library that defaults to Earth and carries other bodies as override files, which
  is the implicit-Earth pattern.
- ClimaComms.jl: its device model duplicates KernelAbstractions plus CUDA with a
  narrower backend set and separate CPU and GPU code paths, so the CPU fallback is
  not the same kernel text the device runs, and its distributed half serves a
  multi-process design decision 0009 does not have
  (`docs/imports/climacomms-jl.md`).
- ClimaLand.jl: no tile mosaic and therefore no island, a bulk single-layer
  snowpack where decision 0018 needs a grain-size and impurity pack, one planet's
  oxygen and sea-level pressure inside the photosynthesis kernels, and a Gregorian
  calendar across the driver boundary (`docs/imports/climaland-jl.md`).
- ClimaOcean.jl: a set of Earth configurations and Earth dataset readers over
  Oceananigans, with no component that survives Oceananigans' removal
  (`docs/imports/climaocean-jl.md`).
- ClimaSeaIce.jl: a single-layer slab thermodynamics with a constant
  freshwater-ice conductivity where decision 0017 names the three-layer scheme, a
  two-parameter linear liquidus in practical salinity with no validity domain to
  refuse against, and an ice salinity that defaults silently to fresh
  (`docs/imports/climaseaice-jl.md`).
- Insolation.jl: the true anomaly comes from a series truncated at third order in
  eccentricity, which decision 0008 forbids by name and this package does not
  guard, and the hour angle advances a full turn per Julian day rather than per
  the declared sidereal rotation period (`docs/imports/insolation-jl.md`).
- ClimaCoupler.jl: a flat symbol-keyed exchange of one planet's surface quantities
  on a cubed-sphere boundary space with no declared writer, and an endpoint drift
  test against a chosen tolerance in place of a ledger closed at each exchange
  (`docs/imports/climacoupler-jl.md`).
- ClimaDiagnostics.jl: everything it writes is a ClimaCore field remapped onto a
  longitude-latitude raster, and no array it emits carries the support identity,
  semantics, owner or interval decision 0010 makes mandatory
  (`docs/imports/clima-output-and-tooling.md`).
- ClimaAnalysis.jl: a dimension's meaning is its English name matched against a
  fixed list with no member for an unstructured cell index, and the default
  latitude average is unweighted (`docs/imports/clima-output-and-tooling.md`).
- TrixiAtmo.jl: cubed sphere, early, no GPU.
- Terrarium.jl: bound to Oceananigans grids, early.
- ModelingToolkit.jl and the differential-equations stack for the columns: the
  columns are coupled through the mesh every step with an operator-split fixed
  timestep, and a hand-written tridiagonal implicit solve in a kernel is smaller,
  faster and backend-agnostic; the symbolic layer hides the discretisation.
- Unitful.jl on the device: mixed-unit arithmetic in kernels explodes compile time
  and breaks library calls.

Deferred, designed for: Enzyme.jl (decision 0033 on differentiability). Reactant.jl's
traced style is not adopted.

### What the survey found about this project's own decisions

Three of the survey's findings are about this project rather than about a
dependency, and a reader of these verdicts should meet them.

- RRTMGP.jl's solver takes its lookup tables by injection: the constructor builds
  them only when none is supplied, and the assertions that pin the gas list to one
  planet's species, by name and by slot, live in the NetCDF extension rather than
  in the solver. So generating a k-distribution here under decision 0016 and
  driving that solver with it is possible without touching the shipped data. It is
  also undemonstrated: every upstream test builds its bundle from the shipped
  artifacts, so the capability is declared and not tested, and the demonstration
  would have to be written here (`docs/imports/rrtmgp-jl.md`).
- Oceananigans.jl holds gravity, radius, rotation rate and float type in a mutable
  process-global object that every spherical grid constructor, every Coriolis
  constructor and the downstream sea-ice package read silently at construction.
  That is a sharper instance of the class this project forbids than a constructor
  default: the value is not overridden once by a caller but read at an unbounded
  number of sites, and two structs built either side of a mutation disagree with
  nothing recording which is authoritative (`docs/imports/oceananigans-jl.md`).
- ClimaCoupler.jl's conservation check fails open when a component reports no
  stock: the energy check credits that component zero and keeps it in the total,
  the water check substitutes the integral of net precipitation minus evaporation
  for the stock it could not read, and the assertion passes either way. That is
  the shape of failure decision 0009's assembly-time check exists to prevent, and
  the misspelled required-field symbol in the same package's error path is what a
  stringly-typed exchange surface costs (`docs/imports/climacoupler-jl.md`).

### Open questions from the organisation sweep

The sweep of the CliMA organisation (`docs/imports/clima-organisation-sweep.md`)
flagged three repositories that bear on decisions being fixed now and that no
record in this survey judges. Their verdicts are not taken here; a row is filed
for each under the survey's epic, and a verdict follows its record.

- CGDycore.jl: a triangular grid built as node, edge and face lists and refined by
  projecting edge midpoints back onto the sphere, beside hexagonal, kite, Healpix
  and equal-area grids, on KernelAbstractions. It is the one grid machinery in the
  organisation not welded to the cubed sphere, and it sits where decisions 0005
  and 0006 sit.
- RootSolvers.jl: bracketing and Newton scalar root finding, broadcastable inside
  a kernel, with the tolerance a type the caller supplies rather than a number the
  package chooses, which is what decision 0008's Kepler solve to rounding needs.
- SeawaterPolynomials.jl: polynomial approximations to the seawater equation of
  state, general in code and fitted in coefficient to one ocean, which bears on
  the composition fence decision 0017 carries.

### The reference arm

SpeedyWeather.jl is run beside this system's dynamical core as an independent
reference arm: the same system parameters, the same idealised test cases
(Held-Suarez, aquaplanet), compared statistically. It is not a component and it does
not run in the coupled system. This restores, deliberately, the second implementation
the predecessor lost when it removed its models' alternate code paths, and it is one
of the four replacements for a lost reference named in decision 0027.

### The import review

Every dependency, infrastructure included, has a record in `docs/imports/` stating:
the version pinned; what of it is used; what assumptions it carries (Earth defaults,
a calendar, a grid, a precision, a threading model, an index base, a coordinate
convention); which of those could leak into a result; and the test that would catch
the leak. A dependency without a record is refused by the smoke check. The review is
repeated when the pin moves.

A record also states the licence, and the CliMA survey put a second licence family
beside the MIT infrastructure listed above: the CliMA packages are Apache 2.0, with
Oceananigans.jl and ClimaOcean.jl under MIT, and RRTMGP.jl additionally carrying
the original RTE+RRTMGP Fortran under BSD 3-Clause. Any adoption from that
organisation brings Apache 2.0 into the tree with the notices it requires.

## Alternatives considered

- **Build on a modern Julia model stack.** Fastest route to a running atmosphere,
  and the route the predecessor's design-intent rule would have taken ("cost the
  fork, then decide on the physics"). Lost because each candidate's grid is not the
  one mesh, and the whole design rests on the one mesh.
- **Own everything, including transforms and solvers.** Maximum control, largest
  cost, and no benefit where the infrastructure carries no planetary content. Lost
  for infrastructure, kept for physics.
- **No reference arm.** Lost; the predecessor's record shows what an independent
  implementation caught (a planetary-vorticity race, a weight pre-scaling defect, a
  module that did nothing), and a from-scratch core has no upstream to compare
  against.

## Consequences

- `docs/imports/` holds one record per dependency at the founding, and one per
  package a survey judges thereafter, whether or not anything is adopted from it.
- The reference-arm comparison is an oracle at the dynamical-core milestone
  (decision 0034).
- Any future proposal to adopt a model component must show the import review and
  argue the fit against the one-mesh rule.
- The one adopt candidate the CliMA survey produced, ClimaTimeSteppers.jl, is not
  a dependency until its own decision is taken; until then decision 0023's fast
  tier has no external integrator behind it.
- The three flagged repositories carry no verdict, so these lists are incomplete
  in exactly that respect until their records exist.
- Adopting anything from the CliMA organisation puts a second licence family in
  the tree.

## References

- The predecessor's survey of external models and frameworks and its verdicts:
  `/home/cfutro/docs/world/notes/external-model-survey.md`,
  `/home/cfutro/docs/world/notes/orchestration-frameworks.md`.
- The predecessor's checklist of what to examine first in any external tree:
  `/home/cfutro/docs/world/notes/external-tree-checklist.md`.
- The predecessor's record of what removing a second code path cost:
  `/home/cfutro/docs/world/docs/src/reference/vendored-upstreams.md`.
- Project pages consulted at the founding: SpeedyWeather.jl, Oceananigans.jl,
  ClimaCore.jl, ClimaParams.jl, KernelAbstractions.jl, Zarr.jl, Enzyme.jl (versions
  and states recorded in the import reviews rather than here).
- The CliMA survey that produced the verdicts above: `docs/plans/clima-survey.md`,
  and the records it wrote, each read against a pinned commit and cited beside its
  verdict: `docs/imports/thermodynamics-jl.md`, `climaparams-jl.md`,
  `climatimesteppers-jl.md`, `climacore-jl.md`, `climacomms-jl.md`,
  `rrtmgp-jl.md`, `surfacefluxes-jl.md`, `cloudmicrophysics-jl.md`,
  `climaland-jl.md`, `oceananigans-jl.md`, `climaocean-jl.md`,
  `climaseaice-jl.md`, `insolation-jl.md`, `climacoupler-jl.md`,
  `clima-output-and-tooling.md`, `clima-organisation-sweep.md`.

## Amendments

2026-09-09: the three verdict lists extended to every package the CliMA survey
judged, with ClimaTimeSteppers.jl added as the one adopt candidate and the
decision it needs stated; the ClimaCore.jl, ClimaParams.jl and Oceananigans.jl
clauses sharpened against their records; the survey's three findings about this
project's own decisions and the sweep's three open questions recorded; the second
licence family noted in the import review, from the CliMA survey
(`docs/plans/clima-survey.md`).
