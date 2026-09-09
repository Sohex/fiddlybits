+++
epic = "fiddlybits-bon"
title = "What the reference-tree survey found, and when each thing is due"
status = "filed"
date = 2026-09-09
+++

## Coverage

Eight hundred and ninety-nine cloned repositories across seven groups, every one named
in a record. Verdicts follow the vocabulary in `README.md`.

| group | repositories | earned a verdict | import review | algorithmic reference | oracle arm |
| --- | --- | --- | --- | --- | --- |
| sciml | 225 | 11 | 3 | 8 | 0 |
| gpu-and-arrays | 186 | 22 | 5 | 17 | 0 |
| dycores-and-frameworks | 153 | 5 | 0 | 3 | 2 |
| mesh-and-discretisation | 124 | 5 | 0 | 4 | 1 |
| biogeochemistry-and-conceptual | 102 | 11 | 0 | 10 | 1 |
| orbits-and-stellar | 67 | 6 | 0 | 6 | 0 |
| terrain-ice-and-solvers | 42 | 10 | 0 | 9 | 1 |

Eight plausible dependencies out of nearly nine hundred repositories. The ratio is the
result: this is a project that writes its own kernels and owns its own loop, and the
survey confirms that most of the ecosystem is built for a different arrangement.

## What the survey changed

**A fence was confirmed by two unrelated codebases.** The implicit-Earth audit had just
fenced the runoff-and-temperature weathering law and the seawater composition behind
the carbonate constants. A deep-time biogeochemistry tree implements that weathering
law with Earth's own mean temperature as its kinetic reference, and two independent
carbonate implementations compute boron, sulfate and fluoride as literal ratios to
salinity. Independent codebases making the same assumption is the strongest available
evidence that a fence was aimed at something real.

**A hazard was found before it could be inherited.** The parallel primitives package
chunks its default processor reduction by the thread count, so its default sum is not
thread-count invariant, which is a design property this project tests by repeats.
Adopting it as it stands would have broken that silently.

**An open requirement already has an answer.** A closed-form scalar solve of Kepler's
equation valid across the whole elliptic range sits in two files of a package whose
remainder is keyed to Julian dates and is dismissed with the rest of the ephemeris
cluster. Read as an algorithm, not adopted as a dependency.

**A cross-group finding that neither surveyor could see alone.** The terrain group
settled on a licence-encumbered complementarity solver as the oracle arm for the water
table, noting its free tier is bounded. The SciML group independently found an open
complementarity solver with native GPU-batched projected relaxation. That is a better
answer to the same requirement, and only reading across the records surfaces it.

**Two gaps that were assumed filled turned out not to be.** The subdivision in the
discrete-exterior-calculus tree places new vertices at flat chordal midpoints without
renormalising onto the sphere, which is not the great-circle bisection the exact-nesting
argument rests on. And the parallel flow-routing tree fills every depression to its
spill unconditionally, with no water volume in the construction, so it never produces
the partially filled basin that decides whether a basin is closed.

**What is genuinely harder than it looks, stated plainly.** The active-set formulation
this project's hydrology and cryosphere requirements demand is not paved: the mature
reference codebases clip instead, a shallow-ice solver with a plain conditional on
thickness and a bound-constrained sample solver the same way. Against that, gravity and
density are already carried as explicit overridable struct fields in the ice and
geodynamics packages, so the discipline this project asks for is achievable rather than
idiosyncratic.

## Timing

Rows are filed under the epic and timed against the build order of decision 0034. What
falls at M0 is what bears on a decision that is open or on the first code: the mesh
operators and the subdivision gap, the array layout and broadcast machinery, the
in-kernel root solvers and the integrator choice, the thread-count invariance hazard,
and the instruments for the coupled loop's exit criteria. Hydrology reading falls at M2,
the dynamical-core oracle arms at M3, radiation and stellar geometry at M4, ocean
chemistry at M6, and the terrain thermal structure at M1.

## The records

- `gpu-and-arrays.md`, `mesh-and-discretisation.md`, `dycores-and-frameworks.md`,
  `orbits-and-stellar.md`, `terrain-ice-and-solvers.md`,
  `biogeochemistry-and-conceptual.md`, `sciml.md`.
- `BRIEF.md` holds the method and the group split; `README.md` the verdict vocabulary.
- The CliMA organisation is surveyed separately, in `docs/imports/` and decision 0012.
