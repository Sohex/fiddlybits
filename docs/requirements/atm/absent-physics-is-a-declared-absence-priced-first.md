+++
id = "REQ-ATM-013"
title = "Absent physics is a declared absence with a complete interface, a priced sign and bound, and a buy criterion fixed before the price; a process is in the model because it exists"
old_path = ["/home/cfutro/git/vesper/notes/audits/absent-and-inherited-physics.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's coupled pipeline, asking what physics was absent
and whether each absence was a decision or a default nobody had read.

- The error budget recorded ocean heat transport as structural with "no cheap
  version"; a diffusive transport was one namelist key on the binary already
  built, satisfying every condition for a trustworthy paired A/B (finding 1). The
  cheap version was a bound on the missing physics, not the physics, and that
  was the argument to bracket it rather than call it unreachable. Two things
  moved afterwards: the arms had run mislabelled by an Earth radius (REQ-SYS-101),
  and the real q-flux mechanism relaxed toward an observed sea-surface
  climatology that a modelled world cannot have, so the term became structurally
  permanent by a different route than the budget had claimed.
- Dust deposition reached neither the snow nor the soil: a flux in g/m2 per
  year with no receiver that holds a load (finding 2; REQ-ATM-011).
- Ocean salinity was undeclared, compiled into a freezing point, and after
  declaration remained a bracket because no salt budget existed; the drainage
  topology could not even select which side of Earth's value the world sat on
  (finding 3).
- The one pedology field that reached the climate model was uncited; the
  source, once read, excluded the endmembers the values were read at, so the
  values became declared with brackets and the component reported the spread
  (finding 4).
- Two greenhouse gases were absent and the absence read as a composition
  decision; once the band existed the abundances were declared as an assumption
  and priced (finding 5; REQ-ATM-003).
- Elsewhere the same shape: sea salt unpriced beside a carefully priced dust
  term (`unpriced-terms.md`); the aerosol indirect effect priced against a
  criterion declared before the size was computed (`aerosol-indirect-effect-cost.md`);
  nine compiled modules that never ran, three by decision and the rest by
  defaults nobody had read, with Earth constants inside each waiting at the
  switch (`dormant-exoplasim-modules.md`).
- The rule the audits converged on: a process belongs in the model because it
  exists; if enabling it makes an agreement worse, that is information and not a
  reason to switch it off.

## Why it carries

Decision 0002 fences what the model is not, decision 0003 states that a
subsystem may be a declared absence but its interface may not, and the risk
register's tripwire is a process added without a record. This audit supplies the
positive form those need: an absence is a record with an interface, a sign, a
bound, a method and a trigger, and its price is read against a criterion written
before the price existed. Every configuration of a generic builder will find
different terms first-order, so the discipline is what carries, not the list.

## What this system must do

1. Every process not in the model is a declared absence carrying: the complete
   interface (types, exchanges, owner) it would occupy; the sign of the omitted
   term where physics fixes it; a bound on its size by a named method (a closed-
   form estimate, an offline sensitivity through the model's own operators, or
   a cheap limit-case implementation on the general formulation); and the
   trigger that buys it, an oracle FAIL or a configuration need (decisions 0002,
   0003).
2. The buy criterion for an absent term is registered before its price is
   computed, in the currency the project reopens questions in, and the verdict
   is read against that criterion and nothing else (decision 0025).
3. Where a cheap version on the general formulation exists, it is the first
   implementation and is labelled a bound; the expensive route is bought when
   an instrument says a configuration needs it (decision 0003, second
   principle).
4. A quantity that reaches one component from another is `Sourced`, `Derived` or
   `Bracketed` with its spread reported; an undeclared inherited value at a
   component boundary is refused at the read (decision 0009).
5. A mechanism that needs an observation a modelled world cannot have (a
   relaxation toward an observed climatology) is not an option in this builder;
   its absence is recorded with that reason.
6. The `Exchange` refuses a flux offered to a receiver whose semantics is a load,
   and a load offered where a flux is expected (decision 0006).

## Enforced by

- Decisions 0002, 0003, 0009, 0025; the absence registry as a section of the
  oracle registry with one row per declared absence.
- Decision 0035's tripwire: a process added without a record, and a
  `NotEvaluable` exit at a gate.
- The failure-classes review (decision 0028): rows for "unpriced absence" and
  "undeclared inherited value at a boundary".

## References

- Rugheimer, S., Kaltenegger, L., Zsom, A., Segura, A., Sasselov, D. (2013).
  *Spectral Fingerprints of Earth-like Planets Around FGK Stars.* Astrobiology
  13(3), 251-269. DOI: 10.1089/ast.2012.0888. The source the undeclared trace-gas
  absence was priced from once the band existed.
- Saxton, K. E., Rawls, W. J. (2006). *Soil Water Characteristic Estimates by
  Texture and Organic Matter for Hydrologic Solutions.* Soil Sci. Soc. Am. J.
  70(5), 1569-1578. DOI: 10.2136/sssaj2005.0117 (to confirm). The regression
  whose stated exclusion of high-clay samples turned three cited values into
  declared brackets.
- Twomey, S. (1977). *The Influence of Pollution on the Shortwave Albedo of
  Clouds.* J. Atmos. Sci. 34(7), 1149-1152.
  DOI: 10.1175/1520-0469(1977)034<1149:TIOPOT>2.0.CO;2 (to confirm). The absent
  term whose pricing is the model of the method.
