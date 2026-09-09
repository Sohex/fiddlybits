+++
id = "0025"
title = "Three oracle tiers, trusted in order, with anti-tuning mechanised"
status = "accepted"
date = 2026-09-08
+++

## Decision

The system has no upstream implementation to compare against, so it earns trust
from three kinds of oracle, trusted in this order and never interchanged.

**Tier 1: identity and analytic oracles.** Exact answers: conservation identities,
analytic solutions, manufactured solutions, quantities the other side already knows.
Failure means the implementation is wrong. These are the only tests that run per
commit. Their content is decision 0026.

**Tier 2: Earth as a distance report.** Because the builder is generic, an Earth
instance is one constructor call against the same parameter set every other
configuration uses. The Earth suite produces a *distance report*: for each metric,
the model value, the observed value, the observation's own uncertainty, the distance
in units of that uncertainty, and a verdict. Verdicts are three-valued and fixed per
metric before the run:

| verdict | meaning | consequence |
|---|---|---|
| FAIL | outside a bar taken from a published model's own residual statistics or from a physical constraint | a defect; blocks the milestone that registered it |
| REPORT | no bar exists that is not a preference; the distance is recorded | none; the number is a property of the model, recorded in the report and never in prose |
| PASS | inside the bar | recorded; evidence only that the model is indistinguishable from the bar, never evidence of correctness |

A FAIL bar is taken from a published model's own residual (the way a groundwater
solver is judged against the residual statistics its authors reported), never from a
number chosen to be reachable. Where no comparable published residual exists, the
metric is REPORT. A bar narrower than the observation's own uncertainty is refused by
the registry check.

Every Earth metric is scored on pattern (zonal-mean structure, seasonal-cycle
amplitude, land/ocean contrast), not only on a global mean, because a model whose
global mean is right by compensation does not carry to a configuration with a
different rotation, gravity or star.

**Tier 3: published non-Earth results.** For each one-parameter-away sweep with a
published multi-model record (aquaplanet intercomparison, rotation-rate sweeps,
obliquity sweeps, gravity identities at fixed column mass, exoplanet
intercomparisons across stellar types, reduced-radius dynamical-core cases), the
inter-model spread is the bar. Landing inside a spread is evidence of not being
distinguishable from the published models, which is the most this tier can give; the
report header says so. Each published sweep is anchored to a protocol system: the
registry entry names the protocol's system as a `Sourced` constructor call (the
protocol paper supplies every field, with its spectrum an input manifest under
`docs/inputs/`); the protocol instances at the founding are `APE()`, `THAI_Hab1()`,
`THAI_Hab2()` and `HeldSuarez()`, each a `Sourced` instance whose every field
comes from its protocol paper, states which normalisation the protocol held fixed (equal total
instellation or equal semi-major axis; column mass or surface pressure; a prescribed
surface or a free one), and applies its bar only to a run of that instance; any other
configuration run through the same case is REPORT. A published aquaplanet or
exoplanet intercomparison is therefore a literal configuration with every parameter a
field, never a case whose radius, gravity, surface pressure or rotation are left to
be understood.

**Anti-tuning, mechanised.** These rules exist so Earth is a comparison to report
distance from and never a target to solve onto. Each carries the check that enforces it.

1. *One parameter set.* The Earth suite reads the same parameter set every other
   configuration reads, by hash. There is no Earth-only override of any physics
   parameter; the only difference between two runs is the system struct. The
   milestone gate refuses an Earth report whose parameter hash differs from the
   configuration run it is paired with.
2. *No `Tuned` disposition exists.* A constant is `Sourced`, `Derived`, `Bracketed`,
   `Irreducible` or `Closure` (decision 0007). A parameter change is a commit that
   changes a parameter block, and the smoke test requires the block's source,
   derivation or bracket argument to change in the same commit. A value that moves
   with no change of provenance is refused at commit.
3. *A moved Earth metric requires a named mechanism, in either direction.* The
   nightly regression compares the distance report with the previous one. Any metric
   that moved by more than its own run-to-run scatter (measured by an A/A arm) must be
   matched by a commit-message line `answers: <mechanism>`. An improvement without a
   mechanism is flagged exactly as a regression is: it is the signature of fitting.
4. *Pattern, not global mean* (above).
5. *A hold-out set.* A pre-registered subset of metrics is scored only at milestone
   gates and never in the nightly, so iteration cannot converge on the visible
   metrics. The subset is named in the oracle registry before the first Earth run.
6. *Physics is not a knob.* A process is added or removed on the argument that it
   exists or does not, with a decision record. A change whose only justification is an
   Earth metric is refused in review. This rule is epistemic and lives in the practice
   book as well.

**Registration.** Every metric, threshold, verdict semantics and hold-out membership
lives in the oracle registry (`docs/oracles/`) with the commit that registered it. The
registry check refuses a result whose threshold hash does not match its registry
entry, and refuses a registry edit in the same commit as a result it judges. A
threshold is fixed before the first artifact it judges exists.

## Alternatives considered

- *Tune to Earth and validate on the sweeps.* Rejected: it produces a model that is
  right on Earth by compensation, and the compensation breaks silently under another
  rotation, gravity or star. The predecessor recorded this class as its most expensive.
- *Two-valued verdicts (pass/fail) for every metric.* Rejected: for most metrics no
  bar exists that is not a preference, and calling a preference a failure invites
  tuning to it. REPORT is the honest third value.
- *Bitwise comparison against a vendored reference model.* Not available; there is no
  upstream. Decision 0027 supplies the replacement (a reference path per kernel and a
  mutation run).

## Consequences

- The oracle registry is infrastructure and exists before any physics.
- An Earth run is part of every milestone gate from the first coupled column onward.
- Reports carry three columns the reader must not collapse: distance, verdict, and
  the bar's provenance.
- Green Earth tables are not evidence of correctness and the report says so in its
  header, so a reader cannot take a table of PASS rows as a verdict on the physics.
- The `answers:` line is a commit convention enforced by CI from the first coupled
  case onward (decision 0029).

## References

- The observational products, statistics and provisional bars per subsystem are
  enumerated in `docs/oracles/README.md` and its registry; each product's paper is
  indexed in `docs/references/INDEX.md` before its bar is registered.
- Predecessor records establishing the pattern of a bar taken from a published
  model's own residual, registered before the run:
  `/home/cfutro/docs/world/hydrography/notes/earth-calibration-criterion.md`,
  `/home/cfutro/docs/world/hydrography/notes/lake-solver-validation.md`.
- The predecessor's rule that thresholds are fixed before results are seen:
  `/home/cfutro/docs/world/docs/src/practice/conventions.md`.

## Amendments

- 2026-09-08: every tier-3 entry names its protocol system as a Sourced constructor call and the normalisation the protocol held fixed, applies its bar to that instance only, and reports any other configuration, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-08: cross-area review: the protocol constructors APE(), THAI_Hab1(), THAI_Hab2() and HeldSuarez() named as the Sourced protocol instances, from notes/findings/2026-09-08-implicit-earth-audit.md
