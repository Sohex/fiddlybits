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

### Verdicts, as of the founding

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

Borrow ideas, never code:

- Oceananigans.jl: location-typed fields, boundary-condition design, output
  writers.
- ClimaCore.jl: axis-tensor vectors (covariant and contravariant components), the
  origin of the named-basis vector semantics in decision 0006.
- ClimaParams.jl: logging every parameter read, the origin of the tracking wrapper
  in decision 0007.
- SpeedyWeather.jl: composable parameterisations and fused column kernels.

Do not adopt as components, with the reason:

- SpeedyWeather.jl: a spectral core on ring grids only, so it reinstates the grid
  crossing; a calendar clock with a fixed day and year and Earth defaults.
- Oceananigans.jl: no icosahedral grid; an ocean on a cubed sphere under an
  icosahedral atmosphere is the crossing again; radius defaults to Earth's.
- ClimaCore.jl and ClimaAtmos: cubed sphere; a parameter library that defaults to
  Earth with other bodies as override files, which is the implicit-Earth pattern.
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

- `docs/imports/` holds one record per dependency at the founding.
- The reference-arm comparison is an oracle at the dynamical-core milestone
  (decision 0034).
- Any future proposal to adopt a model component must show the import review and
  argue the fit against the one-mesh rule.

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
