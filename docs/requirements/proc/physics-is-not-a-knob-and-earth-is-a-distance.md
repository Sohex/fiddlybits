+++
id = "REQ-PROC-004"
title = "Physics is not a knob, and Earth is a distance to report, never a target to solve onto"
old_path = ["/home/cfutro/docs/world/docs/src/practice/conventions.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's rule was that a process is in the model because it exists, and its
vocabulary added the half that is read backwards: establishing that a constant is
Earth's own number is what proves it wrong on another planet, and the repair is a
value the planet's own physics produces, with Earth's figure kept as a comparison to
report the distance from; solving onto it reports that distance as zero by
construction. The worked case was a land roughness fallback proven to be Earth's own
area-averaged roughness recovered from a boundary dataset, after which a derived field
on the modelled world's own slope came out at 0.18 to 0.34 of it, and that distance was
the finding. The external survey (section 59) eliminated a coupling architecture
because it would have meant re-tuning an energy-balance atmosphere's diffusivity
coefficients, calibrated for Earth, until the coupled answer came out; it recorded that
the published coupling needed an Atlantic-Pacific moisture flux adjustment of 0 to 0.32
Sv set against basin freshwater budgets and sea-ice energy flux corrections diagnosed
against observed thickness, and that a world with no such basins and no such
observations has those routes to "reasonable" closed rather than expensive; and it
settled that a wind-stress scaling varied over a fifty-member tuning ensemble is a
knob, so if the component were adopted the value would be a bracket. The tuned-values
audit found a weathering module that is a calibration subsystem (options to rescale
modelled temperature, runoff and productivity to Earth observations, reference patterns
shipped as data) and required that an adoption decision state the calibration state
before wiring. Against these, an Earth validation harness that fits a bias and scale
inside a split loop and discards them, returning only a held-out score against a bar
declared in advance, is a validation and not a knob; and a dust scheme was chosen at the
point of choice for deriving its size distribution from fragmentation physics rather
than fitting it.

## Why it carries

A generic builder's only external comparison is Earth, and every pressure runs toward
making Earth look right. The plan mechanises the refusal (C2: one parameter set shared
by every configuration by hash, `answers:` lines for a moved Earth metric in either
direction, pattern metrics, hold-outs, no `Tuned` disposition) and defines the Earth
tier of oracles as a distance report whose PASS is evidence of indistinguishability,
not correctness (C1). This record is the rule those mechanisms serve, stated so a
future process, flux correction or calibration path is recognised for what it is.

## What this system must do

- A process is added to the model because an oracle fails for its absence or a
  configuration needs it, and never toggled to move a metric; a process added without a
  decision record is a tripwire.
- No flux correction, restoring term, bias correction or calibration factor against
  Earth observations exists in any production profile; `Earth()` is one test
  constructor, and Earth constants appear only as `EarthRatios` denominators whose
  names forbid physical use.
- One parameter set, identified by hash, is shared by every configuration run; a
  parameter that differs between configurations is a `System` input, not a tuning.
- A moved Earth metric requires an `answers: <mechanism>` commit line whether it
  moved toward or away from observation; a pre-registered hold-out set is scored only
  at milestone gates.
- A fit inside a validation harness discards its fitted parameters and reports a
  held-out score against a bar registered in advance.
- At the point a scheme is chosen, the record states why the form with fewer
  unconstrained coefficients was or was not chosen.
- An imported component's calibration machinery is enumerated and declared off with
  its shipped state recorded (REQ-SYS-004) before the component is wired to anything.

## Enforced by

C2 as mechanised; the `EarthRatios` lint; the hold-out set and milestone gates; the
import-review record (REQ-PROC-008); the risk-register tripwire "Earth improving while
a non-Earth sweep worsens".

## References

- /home/cfutro/docs/world/docs/src/practice/conventions.md, "No tuned values"
- /home/cfutro/docs/world/docs/src/reference/vocabulary.md, "implicit-Earth"
- /home/cfutro/docs/world/notes/external-model-survey.md, sections 59b, 59d, 59e
- /home/cfutro/docs/world/notes/audits/tuned-values.md, section 19
- Holden et al. (2016). *PLASIM-GENIE v1.0: a new intermediate complexity AOGCM.* DOI 10.5194/gmd-9-3347-2016 (the moisture flux adjustment and the tuned wind-stress scaling)
- Kok et al. (2014). *An improved dust emission model - Part 1: Model description and comparison against measurements.* DOI 10.5194/acp-14-13023-2014
- Plan decisions C1, C2, A3.
