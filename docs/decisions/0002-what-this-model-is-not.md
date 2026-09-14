+++
id = "0002"
title = "The scope fence: what this model is not, and the rule for adding a process"
status = "accepted"
date = 2026-09-08
+++

## Decision

The single largest risk to a from-scratch Earth-system-class model is that it grows
toward the models it was built to avoid. This record is the fence. Every item below
is a declared absence: its interface exists where another subsystem needs to read or
write it, its physics does not, and a record here says so. A declared absence is not
a defect and is not a task; it becomes one only by the rule at the end.

Declared absences at the founding:

- **No aerosol-cloud microphysics beyond activation.** Aerosol activation to cloud
  droplet number from the dust and sea-salt tracers is in scope, because the
  droplet number sets the cloud optics. Two-moment microphysics, aerosol ageing,
  coagulation, secondary organic aerosol and the chemistry that feeds it are not.
- **No atmospheric chemistry beyond a Chapman ozone column.** Ozone is a diagnostic
  column driven by the declared ultraviolet flux with parameterised catalytic loss.
  Methane, nitrous oxide and other trace gases are prescribed or budgeted as
  inventories with declared lifetimes; there is no photochemical mechanism.
- **No higher-order ice dynamics.** Ice flow is shallow-ice with a sliding law. No
  higher-order or full-Stokes stress balance, no subglacial hydrology.
- **No ice shelves and no calving** until a configuration that has marine ice sheets
  needs them. The grounding line is a coastline for the ice model.
- **No plate advection during the surface-clock terrain integration.** Plates are
  laid out by the tectonic seed with ages; the landscape integration runs on a fixed
  plate configuration. Material does not move laterally with plates.
- **No tides** (ocean or solid body), no tidal mixing, no rotation-state evolution,
  until the absence declared in decision 0004 is lifted. The system struct carries
  the moons and their orbits from the start; the physics that reads them does not
  exist yet.
- **A resolution ceiling per profile.** Each profile declares the finest level each
  component may reach, including under local refinement. Refinement below the
  hydrostatic validity limit refuses until the general (non-hydrostatic) solver of
  decision 0013 exists.
- **No imposed land use** until the driven mode of the managed biosphere exists. The
  first mode computes what the planet could support, not what a population does with
  it.
- **No marine ecosystem beyond a trait-based plankton community with N, P, Fe and
  light limitation**, export and remineralisation. No higher trophic levels beyond
  what the managed-biosphere potential mode derives from primary productivity.
- **No sediment transport in the ocean**, no coastal morphodynamics, no deltas as
  dynamic features beyond what the terrain model's deposition writes at the coast.
- **No atmospheric escape, no interior evolution, no magnetic field.** The volatile
  inventory is a declared input.

## The rule for adding a process

A process is added to the model when, and only when, one of two things is recorded:

1. **An oracle fails for its absence.** A test with a right answer (an identity, a
   conservation law, an Earth distance report with a pre-registered bar, a published
   inter-model spread) fails, and the finding names the absent process as the cause.
2. **A configuration needs it.** A declared system configuration reaches a regime
   where the absence is not defensible (a large close moon and no tides; a marine ice
   sheet and no shelves), and the finding says which regime and why.

In both cases the addition gets a decision record that supersedes the relevant line
of this fence. A process added because it would improve an agreement with Earth, or
because it exists in another model, or because it seems like it should be there, is
refused in review. Physics is not a knob: a process belongs in the model because it
exists in the system being modelled, and its absence is a recorded decision, not an
oversight.

## Alternatives considered

- **No fence; add what seems needed.** This is how every model in the class grew,
  and the predecessor's survey records the result: models whose constants, grids and
  calendars are welded to one planet, with dormant modules that carry that planet's
  physics when switched on. Lost.
- **A tighter fence** (no marine ecosystem, no managed biosphere, no in-line dust).
  Each of these is a coupling the predecessor identified as missing and paid for in
  bracket width (dust, carbon) or could not scope at all (managed land, aquaculture).
  They are in because the design exists to close them.

## Consequences

- Every subsystem decision record (0015 onward) names its declared absences and
  points here.
- The interfaces for every absence are complete at the founding, per the first
  founding principle (decision 0003): a subsystem may be absent, its interface may
  not.
- The oracle registry records, for each absence, which oracle would fail if the
  absence mattered, where such an oracle exists.

## References

- The predecessor's survey of model families and their dormant, planet-welded
  modules: `/home/cfutro/docs/world/notes/external-model-survey.md`, and its
  dormant-module audit `/home/cfutro/docs/world/notes/audits/dormant-exoplasim-modules.md`.
- The "physics is not a knob" rule and its argument:
  `/home/cfutro/docs/world/docs/src/practice/failure-modes.md`, class 16.

## Amendments

- 2026-09-13: the archive this record cites now resolves at /home/cfutro/git/vesper; /home/cfutro/docs/world no longer exists on disk, from notes/findings/2026-09-13-predecessor-archive-relocated-to-vesper.md.
