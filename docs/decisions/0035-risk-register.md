+++
id = "0035"
title = "Risk register with a mitigation and a tripwire for each risk"
status = "accepted"
date = 2026-09-08
+++

## Decision

Each risk carries a mitigation that is part of the design and a tripwire that is a
measurable event, so that a risk materialising is detected rather than discovered.
The register is revised when a tripwire fires or a milestone gate is passed.

| risk | mitigation | tripwire |
|---|---|---|
| dynamical core written from scratch | shallow water first; the published test suite as acceptance; the independent reference arm; the fallback ladder in decision 0013 (Z-grid on triangles, then cubed sphere, never spectral) | the baroclinic steady state not at its designed order, or the idealised-forcing climatology outside the published band, after the bounded effort declared at M3's start |
| GPU debugging | CPU first through portable kernels; the bitwise debug mode; the ulp-ensemble envelope; small-planet cases that run in seconds | any kernel outside its envelope blocks merge |
| FP32 on consumer hardware | mixed precision by declaration; FP64 accumulators for ledgers and reservoirs; per-kernel certification | an uncertified FP32 kernel in a production profile; a reservoir drifting under FP32 |
| Earth-fitted schemes with no non-Earth form | prefer dimensionally explicit schemes; every constant has a disposition; every bracket and closure swept | growth in the `Irreducible` count reviewed at every milestone |
| small features lost to resolution | mosaic tiles, the explicit connectivity graph, instrument-triggered graded refinement (decision 0031) | a declared feature absent from a coarse-level artifact |
| scope creep toward a full Earth-system model | the scope-fence record; a process is added only when an oracle FAILs for its absence or a configuration needs it | a process added without a decision record |
| one developer with agents | the oracle suite and the mutation run as the reviewer; briefs name the oracle and the file boundary; the `answers:` discipline | a reference hash changed without `answers:`; an Earth metric moved without a mechanism; a mutation nothing catches |
| imported assumptions in dependencies | an import-review record per dependency with a leak test (decision 0012) | a dependency without a record |
| language toolchain latency | precompile workloads, a persistent development session, a system image for CI, a small core dependency graph | per-commit CI beyond its declared budget |
| device memory | a budget computed from the field registry per profile; diagnostics streamed rather than accumulated on the device | high-water memory above the profile's declared ceiling |
| oracle data availability and licences | tracked hashed extracts with fetch recipes; missing data reports `NotEvaluable` by name | any `NotEvaluable` at a gate blocks it |
| silent over-fit to Earth | one parameter set; the hold-out set; the second oracle tier in the non-Earth direction | an Earth metric improving while a non-Earth sweep worsens |
| a loop that never converges | every exit declared before the loop runs, with an instrument that can evaluate it; antitone loops return brackets, never convergence | a `NotEvaluable` exit at M8 |
| wave reflection at refinement boundaries | graded transition rings with divergence damping for the fluids (decision 0031) | reflected-wave growth in the M3 refinement case |
| grid-scaled closures treated as universal constants | the `Closure` disposition with a scaling law and a convergence-with-level oracle (decision 0006) | a closure coefficient that does not converge across two mesh levels |
| free-boundary solvers on an unpaved road | the water table and the ice margin are both obstacle problems, and the reference-tree survey found that the adjacent codebases clip rather than solve them, which they can afford because they close no ledger and this project cannot; fallback ladders and tripwires now stated in decisions 0019 and 0020, an open device-capable complementarity solver and a bounded direct solver identified as arms (docs/surveys/terrain-ice-and-solvers.md, docs/surveys/sciml.md) | the registered residual bar unmet within the declared pass count on the production operator at two mesh levels, or a ledger residual whose time signature classifies as a leak while the closed-form margin still matches |
| a limiter that hides its own cost | REQ-HYD-004 and REQ-CRY-001 make water or ice invented by any limiter a refusal rather than a rebooked balance term, and the ledgers of REQ-HYD-012 and the ice-volume identity are what enforce it; whether a limiter that reports its residual and refuses above a registered tolerance is admissible in the fast profile, while the free-boundary solver is being earned, is an open consideration to settle at implementation and not a licence to clip | any limiter reaching a production profile without a ledger entry, or a fast-profile result quoted without the residual its limiter reported |

## Alternatives considered

- *A risk list without tripwires.* Rejected: a risk with no measurable event is
  discovered late, which is the predecessor's most repeated finding.
- *Tripwires stated as schedule slippage.* Rejected: no schedule exists to slip.

## Consequences

- Each tripwire is either an oracle in the registry or a lint, so firing is
  automatic.
- A fired tripwire files an issue citing this record and the risk row.
- New risks are added with both columns filled or not at all.

## References

- Decisions 0011, 0012, 0025, 0026, 0029, 0031, 0034.
- Predecessor failure classes on late discovery and on instruments too blunt to
  produce a number: `/home/cfutro/docs/world/docs/src/practice/failure-modes.md`.

## Amendments

- 2026-09-09: two rows added, for free-boundary solvers on an unpaved road and for a
  limiter that hides its own cost, after the reference-tree survey showed that the
  adjacent codebases clip where this project's requirements refuse to. The open
  consideration about a reporting limiter in the fast profile is recorded here and in
  decisions 0019 and 0020, to be settled when those solvers are built, never before.
- 2026-09-13: the archive this record cites now resolves at /home/cfutro/git/vesper; /home/cfutro/docs/world no longer exists on disk, from notes/findings/2026-09-13-predecessor-archive-relocated-to-vesper.md.
