# Decision index

Generated from the front matter of every record in this directory by
`tools/records/decisions.py`, and rewritten by the pre-commit hook whenever a record
changes. Do not edit: an edit here is lost on the next commit, and the record itself is
the primitive. The schema is in `README.md`.

`amends` and `supersedes` are read from the acting record. `superseded by` is derived
from those, and is the only place that back-edge is written down.

| id | title | status | date | amends | supersedes | superseded by |
| --- | --- | --- | --- | --- | --- | --- |
| [0001](0001-build-from-scratch.md) | Build a holistic exoplanet builder from scratch in Julia rather than continue the chained-model stack | accepted | 2026-09-08 | - | - | - |
| [0002](0002-what-this-model-is-not.md) | The scope fence: what this model is not, and the rule for adding a process | accepted | 2026-09-08 | - | - | - |
| [0003](0003-founding-principles.md) | Four founding principles | accepted | 2026-09-08 | - | - | - |
| [0004](0004-foundational-free-parameters.md) | Foundational free parameters are only those that cannot be derived and sit upstream of everything | accepted | 2026-09-08 | - | - | - |
| [0005](0005-one-mesh-icosahedral-triangles.md) | One mesh: an icosahedral bisection hierarchy with triangle cells, sub-grid structure for small features, and graded local refinement | accepted | 2026-09-08 | - | - | - |
| [0006](0006-field-semantics-as-types.md) | Field semantics, time semantics, dimension and support are type parameters of every field | accepted | 2026-09-08 | - | - | - |
| [0007](0007-system-struct-and-five-dispositions.md) | One immutable System struct, keyword-only with no defaults, and exactly five constant dispositions | accepted | 2026-09-08 | - | - | - |
| [0008](0008-one-clock-si-seconds.md) | One clock in SI seconds; every temporal quantity derived from the system; the epoch declared | accepted | 2026-09-08 | - | - | - |
| [0009](0009-single-process-coupling-and-ownership.md) | Coupling in one process, with declared ownership, ledgers at every exchange, and loops as values | accepted | 2026-09-08 | - | - | - |
| [0010](0010-content-addressed-artifacts.md) | Content-addressed artifacts, runs as UUIDs, one chunked store format, and the index base at each boundary | accepted | 2026-09-08 | - | - | - |
| [0011](0011-gpu-first-mixed-precision.md) | GPU-first through a portable kernel layer, CPU backend for sequential algorithms, and mixed precision by declaration | accepted | 2026-09-08 | - | - | - |
| [0012](0012-ecosystem-verdicts-and-import-review.md) | Julia ecosystem verdicts, an import review for every dependency, and an external dynamical core as a reference arm | accepted | 2026-09-08 | - | - | - |
| [0013](0013-atmosphere-core-triangle-cgrid.md) | The atmosphere core: finite volume on the triangle C-grid, formulated non-hydrostatic and deep, with the hydrostatic limit implemented first | accepted | 2026-09-08 | - | - | - |
| [0014](0014-profiles-fast-and-full.md) | Two named profiles, fast and full, as one struct; the same code at different declared settings | accepted | 2026-09-08 | - | - | - |
| [0015](0015-terrain-snapshot-two-clocks.md) | Terrain and lithology are a snapshot carrying two declared clocks | accepted | 2026-09-08 | - | - | - |
| [0016](0016-atmosphere-physics-scope.md) | Atmosphere physics scope, with radiation generated per composition and spectrum | accepted | 2026-09-08 | - | - | - |
| [0017](0017-ocean-sea-ice-marine-ecosystem.md) | Ocean, sea ice and marine ecosystem on the shared mesh, coupled synchronously | accepted | 2026-09-08 | - | - | - |
| [0018](0018-one-land-column.md) | One land column, shared by climate and vegetation, on a tile mosaic | accepted | 2026-09-08 | - | - | - |
| [0019](0019-hydrology-and-carve-as-process.md) | Hydrology on the terrain mesh, with drainage change as a process rather than a verdict | accepted | 2026-09-08 | - | - | - |
| [0020](0020-cryosphere-scope.md) | Cryosphere: shallow-ice flow on the terrain level, mass balance from the land column | accepted | 2026-09-08 | - | - | - |
| [0021](0021-trait-based-vegetation.md) | Vegetation as a trait-based community filtered by the planet, with the biology assumption declared | accepted | 2026-09-08 | - | - | - |
| [0022](0022-pedology-aeolian-minerals-carbon.md) | Pedology with a clock, dust in line, minerals as an age-aware overlay, and pCO2 solved | accepted | 2026-09-08 | - | - | - |
| [0023](0023-coupled-loop-and-exit-criteria.md) | The coupled loop: five timestep tiers, asynchronous terrain coupling, exits declared before the run | accepted | 2026-09-08 | - | - | - |
| [0024](0024-managed-biosphere.md) | Managed biosphere: agriculture, grazing, forestry, irrigation, fisheries and aquaculture, potential mode first | accepted | 2026-09-08 | - | - | - |
| [0025](0025-three-oracle-tiers.md) | Three oracle tiers, trusted in order, with anti-tuning mechanised | accepted | 2026-09-08 | - | - | - |
| [0026](0026-analytic-and-conservation-oracles.md) | Analytic and conservation oracles, with tolerances derived rather than chosen | accepted | 2026-09-08 | - | - | - |
| [0027](0027-reference-paths-and-mutation-run.md) | Every optimised kernel keeps a naive reference path, and a mutation run proves the oracles can fail | accepted | 2026-09-08 | - | - | - |
| [0028](0028-failure-classes-as-tests.md) | The predecessor's failure classes become tests or process rules, each on its merits | accepted | 2026-09-08 | - | - | - |
| [0029](0029-reproducibility-policy.md) | Reproducibility policy across threads, backends and precisions | accepted | 2026-09-08 | - | - | - |
| [0030](0030-references-discipline.md) | Every law, scheme and constant is anchored to a read primary source with a locator | accepted | 2026-09-08 | - | - | - |
| [0031](0031-small-feature-strategy.md) | Small features are carried by tiles and an explicit connectivity graph, with instrument-triggered local refinement | accepted | 2026-09-08 | - | - | - |
| [0032](0032-moons-and-multiple-stars.md) | Moons and multiple stars are in the system struct from the start; light is derived now, tides declared absences with complete interfaces | accepted | 2026-09-08 | - | - | - |
| [0033](0033-differentiability-deferred.md) | Design for differentiability and defer it; the trigger is a non-chaotic subsystem's sensitivity report | accepted | 2026-09-08 | - | - | - |
| [0034](0034-build-order-and-gates.md) | Build order is by dependency, each milestone has a gate with a right answer, and no schedule is attached | accepted | 2026-09-08 | - | - | - |
| [0035](0035-risk-register.md) | Risk register with a mitigation and a tripwire for each risk | accepted | 2026-09-08 | - | - | - |
| [0036](0036-toml-throughout.md) | TOML for every configuration, manifest, registry and record header | accepted | 2026-09-08 | - | - | - |
| [0037](0037-tiered-agentic-execution.md) | Tiered agentic execution: plans by frontier models, implementation rows sized to an executor class, one worktree per row | accepted | 2026-09-08 | - | - | - |
| [0038](0038-concurrency-from-the-outset.md) | Concurrency is designed in from the outset, and a stage is never the unit of waiting | accepted | 2026-09-10 | - | - | - |
| [0039](0039-comments-say-what-the-code-does.md) | A comment says what the code does; the argument for it lives in the durable record | accepted | 2026-09-10 | - | - | - |
| [0040](0040-records-carry-their-edges.md) | A decision record names the records it amends or supersedes, in its front matter, as data | accepted | 2026-09-10 | - | - | - |
| [0041](0041-fast-tier-integrator.md) | The fast tier integrates with ClimaTimeSteppers under five conditions, and the alternative is excluded by its own dependency graph | proposed | 2026-09-10 | 0012 (takes the ClimaTimeSteppers.jl candidacy it left open, and closes the four points it named for that decision) | - | - |
| [0042](0042-run-event-journal.md) | Every run writes an append-only event journal beside its plan, from a closed event vocabulary | accepted | 2026-09-10 | 0010 (the run record gains a third element beside the plan and the system struct: an append-only event journal) | - | - |
| [0043](0043-where-the-gate-runs.md) | The gate runs on the machine that holds the data and the card; a hosted job runs only the clean-room subset | accepted | 2026-09-10 | - | - | - |
| [0045](0045-precision-pinned-constants-are-named-not-whole-files.md) | The literal lint is widened for named constants of a pinned precision, never for a whole file | accepted | 2026-09-11 | - | - | - |

44 records; 43 accepted, 1 proposed, 0 superseded.
