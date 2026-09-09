+++
id = "0001"
title = "Build a holistic exoplanet builder from scratch in Julia rather than continue the chained-model stack"
status = "accepted"
date = 2026-09-08
+++

## Decision

This project replaces a pipeline of four vendored scientific models (a terrain
generator in JavaScript, a spectral general circulation model in Fortran, a dynamic
vegetation model in C++, an intermediate-complexity ocean in Fortran) and the
project-owned code that crossed grids between them, with one system written from the
ground up in Julia. Nothing is ported. The predecessor project at
`/home/cfutro/docs/world` (archived at commit
`6aa93489d233d4e9d531d6479d338c643e34bc5e`) is an archive of findings and lessons,
and every item carried from it is judged on its own merits.

The system is a generic exoplanet builder. It is not built around any planetary or
stellar configuration, and no document in this tree frames it as such.

The argument rests on the predecessor's own audit record. Of its 85 audited findings,
roughly two fifths were language, build, or grid-convention overhead rather than
science: constants with no configuration key that could not be bracketed or swept; a
planetary radius compiled into a model twice with two different values;
non-dimensionalisation that carried another planet's scales so that wrong numbers
looked plausible; a longitude-convention shift across a model seam that changed the
verdict on a third of the drainage basins; an export that shipped two answers about
its own cell areas; a day constant used both as a day and as the model's unit of time;
a fixed-length calendar; per-day empirical regressions evaluated on a different
clock; precision set by a mis-parsed compiler flag; a category of defects around
binary registries and provenance; masked-lane floating-point faults; implicit static
state under threads; memory-safety defects; and duplicated declarations that
silently diverged. A design that runs in one language, on one mesh, with one
parameter struct and one clock in SI seconds makes every one of those classes
unrepresentable rather than merely detected.

The predecessor's largest known physics hole was a coupling, not a component: the
model that produced land runoff carried no stomatal, leaf-area, root or interception
term, so vegetation reached the climate through albedo and roughness but not through
water, while transpiration was worth roughly the whole land runoff and runoff was the
denominator of an irreversible terrain decision. Only a single land column shared by
climate and vegetation closes that hole, and only a single-process design can hold a
single land column.

## What this does not fix

Stated plainly so that nobody expects it.

- Every parameterisation fitted on Earth data stays Earth-fitted. A parameter struct
  makes such a value nameable and sweepable; it does not make it correct for another
  world. Convective entrainment, cloud droplet relations, saltation constants,
  weathering rate tables and decomposition rates are the examples that will recur.
- Earth's statistics are not Earth's numbers. A biological tolerance calibrated as an
  index over Earth's climate covariance carries that covariance with it. Removing it
  needs new biology (a trait space filtered by the declared planet), not new software.
- Sub-grid physics that is absent stays absent until written. A boundary layer with
  no turbulent kinetic energy cannot activate aerosols; a column with one level below
  a kilometre cannot hold a nocturnal jet. This design includes those, and each is
  work.
- Nonlinear reduction across scales is an operator problem, not a convention problem.
  One mesh removes the remap; it does not make the mean of a nonlinear function equal
  the function of the mean. Reductions must still declare their operator.
- A rewrite loses every independent reference implementation the predecessor
  compared against bitwise. That loss is replaced deliberately: a never-deleted naive
  reference path for every optimised kernel, a mutation run, an external reference
  arm for the dynamical core, and Earth as an oracle (decision 0025 and its
  siblings).
- A minority of the predecessor's recorded failure classes are epistemic (a claim
  recorded as settled that measurement contradicts; a number taken from a citation
  rather than the paper; a defect offered as a decision). They survive any language
  and are carried as process rules.

## Alternatives considered

- **Continue maintaining the forks.** The predecessor's own standing policy was that
  an external model becomes a maintained fork and that the fork is the expected end
  state. It paid that cost several hundred commits deep on the climate model alone
  and declared it a hard fork with no path back to upstream. The cost of ownership had
  been paid without the benefits of ownership: constants still lived in compile-time
  parameters, the grid was still a second grid, and the transpiration coupling was
  still architecturally impossible. Lost on that record.
- **Adopt a modern Julia model stack as the base** (a spectral GCM, a GPU ocean, a
  cubed-sphere atmosphere). Each imports a discretisation that is not the one mesh
  this design needs, and each carries defaults and a clock built for Earth. They are
  drawn on for ideas and used as reference arms; they are not adopted as components.
  Decision 0012 records the per-package verdicts.
- **Rewrite in a different language.** The requirement is one language for physics,
  kernels and analysis, with first-class GPU support, generic programming strong
  enough to make field semantics a type parameter, and a numerical ecosystem. Julia
  satisfies all four; the alternatives considered satisfied at most three.

## Consequences

- The predecessor becomes a requirements archive. Its audits are dispositioned one by
  one into `docs/requirements/` or into a recorded not-carried list.
- Every physical subsystem is written here, on the shared mesh, with the couplings the
  predecessor could not have (transpiration, in-line dust, a solved carbon balance,
  synchronous ocean transport, vegetation acting on erosion).
- Verification has to be designed rather than inherited: decisions 0025 to 0029.
- No schedule and no size estimate is attached to any of this. The work is ordered by
  dependency and gated by tests with right answers.

## References

- The predecessor's audit corpus: `/home/cfutro/docs/world/notes/audits/` (85 files),
  and its failure-mode catalogue `/home/cfutro/docs/world/docs/src/practice/failure-modes.md`.
- The missed-coupling finding on transpiration:
  `/home/cfutro/docs/world/notes/audits/missed-couplings.md`.
- The predecessor's survey of the two model families and the gap between them:
  `/home/cfutro/docs/world/notes/external-model-survey.md`, section 1.
