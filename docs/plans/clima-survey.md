+++
epic = "fiddlybits-1cq"
title = "Survey the CliMA ecosystem: what to adopt, what to borrow, what to refuse"
decisions = ["0003", "0005", "0006", "0008", "0012", "0013", "0016", "0017", "0018", "0021", "0023", "0033"]
requirements = ["REQ-ATM-017", "REQ-SYS-101", "REQ-PROC-008"]
oracles = []
status = "filed"
date = 2026-09-09
+++

## Scope

Decision 0012 judged three CliMA packages and adopted none of them. The organisation
hosts many more, and several sit exactly where this project's next decisions are
being fixed. This plan surveys them all and records a verdict for each.

It does not adopt anything. A survey produces evidence: one import-review record per
package, and an amendment to decision 0012 where a verdict moves. Adoption of any
package is a separate decision taken against its record, because the founding rule is
that a dependency enters only where it is exactly the right fit and only with a named
test that catches the assumption it carries.

Out of scope: packages with no bearing on Parts A or B (visualisation, continuous
integration helpers, organisation tooling), which the survey lists once and dismisses
with the reason.

## Why now

Four of these packages bear on decisions that are not yet built, and the cost of
learning about them after M0 is a rewrite rather than a reading:

- `Thermodynamics.jl` is a parameter-struct treatment of moist thermodynamics, which
  is the shape REQ-ATM-017 just declared for the gas-mixture property group. Either it
  generalises past one condensable in one bulk gas or it does not, and the answer
  changes what M0 writes.
- `ClimaTimeSteppers.jl` supplies implicit-explicit integrators for exactly the
  stiff-fast, non-stiff-slow split decision 0023 describes.
- `RRTMGP.jl` is a solver whose shipped k-distributions are Earth-fitted but whose
  two-stream machinery is not; this project generates its own tables (0016), so the
  question is whether the solver can read them.
- `CGDycore.jl` refines a triangular sphere grid by projecting edge midpoints onto
  the unit sphere and records connectivity in explicit tables, which is where
  decisions 0005 and 0006 sit. The organisation sweep found it after this plan's
  first draft; it is read before the mesh module is written, not after.

## Groups, and the question each must answer

| group | packages | the question |
| --- | --- | --- |
| thermodynamics and gas properties | Thermodynamics.jl, ClimaParams.jl | Does the parameter set generalise beyond one condensable in air, and does the read-logging design match the tracking wrapper of decision 0007? |
| mesh and connectivity | CGDycore.jl | Does the triangular refinement nest exactly the way decision 0005 requires, and is connectivity a derived record or an emergent property of the loop that walks it? |
| numerics and time | ClimaTimeSteppers.jl, ClimaCore.jl, ClimaComms.jl, RootSolvers.jl | Do the integrators depend on the discretisation, or take a tendency function? Is the communication layer separable from the cubed sphere? Does the scalar solve run inside a device kernel without allocating, and what does its automatic-differentiation dependency imply for decision 0033? |
| radiation | RRTMGP.jl | Can the solver read k-distributions generated here for an arbitrary spectrum and composition, or does it require the shipped Earth data? |
| surface and column | SurfaceFluxes.jl, CloudMicrophysics.jl, ClimaLand.jl | Are the universal functions and microphysics parameterised by struct, and what is dimensionless against what is fitted at one gravity and one air density? |
| ocean and ice | Oceananigans.jl, ClimaOcean.jl, ClimaSeaIce.jl, SeawaterPolynomials.jl | Beyond the grid verdict already recorded, what of the operator and boundary-condition design carries to a triangle mesh, and what does the sea-ice thermodynamics assume about seawater composition? |
| geometry and forcing | Insolation.jl | Is the orbital geometry general, or a Milankovitch series for one planet around one star? |
| coupling and output | ClimaCoupler.jl, ClimaDiagnostics.jl, ClimaAnalysis.jl, ClimaUtilities.jl | Does the coupling model admit one writer per quantity and closed exchange ledgers, or does it assume its own component set? |

## What each record must state

The format in `docs/imports/README.md`, with these additions for this survey:

- The verdict, in the vocabulary of decision 0012: adopt as infrastructure, borrow
  ideas only, run as a reference arm, or do not adopt, with the reason in one
  sentence.
- The checklist of assumptions applied item by item, naming a clean negative where
  the package is innocent rather than leaving it silent.
- For any adopt verdict, the named test in this repository that would catch the
  assumption leaking, and the version pinned or `to pin`.
- Licence, and the commit or release the reading was done against, because a survey
  of a moving target is worthless without one.
- Where the package is Earth-fitted in its data but general in its code, say which
  half is which, since that is the common case here and the useful one.

## Rows filed

| row | tier | boundary | acceptance |
| --- | --- | --- | --- |
| thermodynamics and gas properties | frontier | docs/imports/thermodynamics-jl.md, climaparams-jl.md | both records complete; the generalisation question answered against the source, not the documentation |
| numerics and time | frontier | docs/imports/climatimesteppers-jl.md, climacore-jl.md, climacomms-jl.md | records complete; the integrator interface quoted |
| radiation | frontier | docs/imports/rrtmgp-jl.md | record complete; the table-loading path named by function |
| surface and column | frontier | docs/imports/surfacefluxes-jl.md, cloudmicrophysics-jl.md, climaland-jl.md | records complete; dimensionless separated from fitted |
| ocean and ice | frontier | docs/imports/oceananigans-jl.md, climaocean-jl.md, climaseaice-jl.md | records complete; the existing Oceananigans idea-borrow in 0012 reconciled |
| geometry, coupling, output | frontier | docs/imports/insolation-jl.md, climacoupler-jl.md, clima-tooling.md | records complete; out-of-scope packages listed once with the reason |
| `fiddlybits-1cq.5` verdicts | frontier | docs/decisions/0012 | 0012's three lists match the records; every moved verdict carries its reason. The survey's verify row: it depends on every review above and cannot be written before they exist |

Filed after the organisation sweep (`docs/imports/clima-organisation-sweep.md`), which
read the repositories this plan's first draft did not name:

| row | tier | milestone | boundary | acceptance |
| --- | --- | --- | --- | --- |
| `fiddlybits-1cq.2` mesh and connectivity | frontier | M0 | docs/imports/cgdycore-jl.md | record complete, read at a pinned commit; the nesting question answered from source, not from the documentation; the connectivity representation classified as derived record or emergent property |
| `fiddlybits-1cq.3` root solvers | frontier | M0 | docs/imports/rootsolvers-jl.md | record complete; the in-kernel and allocation questions answered from source; the `ForwardDiff` implication for decision 0033 stated |
| `fiddlybits-1cq.4` seawater properties | frontier | M6 | docs/imports/seawaterpolynomials-jl.md | record complete; the composition question answered against decision 0017's two limbs; the fitted coefficients separated from the general evaluation |

The mesh and root-solver rows are timed to M0 because the mesh module and the clock
are written there and a reading afterwards is a rewrite. The seawater row is timed to
M6, where the ocean block is built; nothing before it reads an equation of state.

## Refusals this survey must not commit

- No package is adopted in this pass. A record that recommends adoption states the
  decision it would need.
- No record is written from a README alone. Every assumption claim cites a file and,
  where it matters, a function or constant by name.
- Nothing is vendored, and no source tree is copied into this repository. External
  trees are recorded with a pinned commit, as decision 0012 requires.
