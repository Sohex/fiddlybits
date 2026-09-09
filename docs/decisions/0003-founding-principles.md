+++
id = "0003"
title = "Four founding principles"
status = "accepted"
date = 2026-09-08
+++

## Decision

Four principles govern every design decision in this tree. A proposal that violates
one is refused in review, and a decision record that invokes one names it.

### 1. Nail every interface out of the gate so extension is painless later

A subsystem may be a declared absence; its interface may not. The system struct
carries moons before tides exist; the ocean reads a tidal-forcing field that is zero
before the tidal model exists; the land column exposes an irrigation withdrawal before
the managed biosphere's driven mode exists; the atmosphere's radiation reads a
multi-source instellation before any configuration has two stars. The cost of an
interface is small when it is designed with the system and large when it is
retrofitted. Every interface is typed, owned by exactly one writer, and closed by a
ledger where a conserved quantity crosses it.

### 2. Build the cheap route on the general formulation; buy the expensive route when an instrument says a configuration needs it

The cheap solver is a limit case of the general equations, never a different model.
The hydrostatic atmosphere is the non-hydrostatic system with one term removed, on the
same prognostic variables and vertical coordinate (decision 0013). Sub-grid tiles and
a connectivity graph carry small features until a sensitivity probe shows a feature's
effect exceeds its bracket, and only then is the mesh refined around it (decision
0005). The trigger to buy the expensive route is always a measured sensitivity or a
validity check, never a hunch or a preference for fidelity. This keeps the first
runnable system small and keeps its every extension additive.

### 3. Everything carried from the predecessor is evaluated on its own merits

The predecessor project is an archive of findings, not a template. A rule, a
constant, a reference, a test, a failure class or a convention is carried only when
its merit for a generic exoplanet builder is written down. Old-stack tooling defects
are not requirements; configuration-specific numbers are not requirements;
Earth-normative couplings are not requirements, though the lesson that no coupling
may be assumed is. Every one of the predecessor's audits has exactly one recorded
disposition: a requirement record with its merit argument, or a not-carried line with
its reason.

### 4. Every law, scheme and constant is anchored to a primary source, read, with a locator

Nothing drifts from accepted science by accident because nothing is taken from a
secondhand citation. A `Sourced` constant requires the identifier of the work (a DOI
where one exists, otherwise a stable locator) and the table or equation the value
comes from. The references index records `read` versus `held` honestly; `held` is an
open exposure, not a resource. A needed paper is requested by verbatim title and
identifier after the index has been checked, so nothing is fetched twice. The
predecessor lost real work twice to numbers taken from citations rather than papers;
this principle is that lesson made structural.

## Alternatives considered

- **Principles as advice rather than review criteria.** The predecessor's experience
  is that a rule which is not enforced somewhere is not a rule. Each principle above
  is enforced: 1 by the ownership check at assembly and the interface-completeness
  review of every scope decision; 2 by the instrument-triggered refinement and the
  validity check in the solver; 3 by the disposition count over the audit archive;
  4 by the references lint on `Sourced` dispositions and oracle bars.

## Consequences

- Decisions 0004 to 0014 (architecture), 0015 onward (physics scope) and the
  verification decisions each cite the principle they rest on.
- The practice book carries the four as its first four lines.

## References

- The predecessor's two incidents of numbers taken from citations rather than papers:
  `/home/cfutro/docs/world/references/INDEX.md` (preamble) and
  `/home/cfutro/docs/world/docs/src/practice/failure-modes.md`, class 9.
- The predecessor's working agreement "ask whether the thing should exist before
  building it": `/home/cfutro/docs/world/docs/src/practice/working-agreements.md`.
