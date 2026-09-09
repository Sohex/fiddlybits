+++
id = "REQ-PROC-003"
title = "A check has a right answer fixed before the result, can fail, and refuses rather than backfills"
old_path = ["/home/cfutro/docs/world/docs/src/practice/conventions.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's conventions: thresholds are fixed before results are seen (an albedo
bracket's convergence and marginality criteria were written into a docstring before any
run finished and then applied against a result that cleared one of them by 0.05 K); a
bracket's direction is a claim needing its own argument (an assertion that a canopy
treatment gives a smaller ratio than a leaf one held for one of three leaf classes and
failed for the other two); claims are checked against the artifact rather than the
documentation, which is how almost every failure class was found; a miss is labelled a
miss ("quasi-equilibrated" for 0.004 W/m2). Its lapse-rate module deliberately did not
floor the measured rate at the moist adiabat, because a floor would silently decide the
answer instead of checking it, the same failure as a Penman floor that once decided 73
per cent of a carve verdict; what it did check, raised on rather than warned about, was
that the rate is positive and below the dry adiabat and that the fit's rms is under
1 K. Its stellar module held itself to one identity with a right answer (the scheme's
own stated solar partition of 0.517, reproduced through both code routes) and checked
the file separately from the code. The external survey (section 55) found that ESMF
tests itself against a conservation identity at about 1e-9 relative that the
predecessor's gridding had never had, refuses unmapped destination cells by default,
checks the weight matrix rather than the search, names the offending element, and
forbids artificial pole cells because invented area breaks conservation, where the
predecessor silently backfilled from the nearest region with no threshold at which it
refused. Its design-intent chapter added: a judgment made while a class is absent is
not a judgment (three values surfaced at once when one tectonic bug was fixed), so
when a rule starts firing for the first time, audit everything it controls. And the
plan's own inheritance: tests need a right answer, not a comparison that can only
differ; refuse rather than snap, interpolate or backfill.

## Why it carries

A test whose failure condition was chosen after seeing the result, or that can only
report a difference, or that substitutes a plausible value where it should refuse, is
the mechanism by which an Earth-fitted or stale number passes unnoticed. The plan's
oracle tiers (C1), registered thresholds (C2), conservation ledgers with floating-point
tolerances (C3) and the mutation run (C4) are the mechanised form; this record is the
rule they mechanise, and it binds every check written by hand as well.

## What this system must do

- Every oracle threshold is registered with the commit that registered it before the
  first artifact it judges; a threshold derived from floating point or from a
  published model's residual is preferred to a chosen one, and a chosen one carries
  the argument for its direction.
- Identities are the first tier (area sums, a reference spectrum reproducing the
  published partition, conservation integrals, analytic solutions); a comparison that
  can only differ is reported, never passed.
- Refusal is the default at every crossing: an unmapped cell, a missing input, a
  spectrum absent from a run, a ledger that does not close; a fallback is an explicit
  opt-in with a registered threshold and a count in provenance.
- A floor, clamp or limiter that would decide an answer is not a check; where a
  limiter is physically required its binding regime at this configuration is
  reported (cf. the import-review item on limiters, REQ-PROC-008).
- A miss is reported as a miss with the criterion it missed; results are never rounded
  into passes.
- When a refusal or a rule fires for the first time, everything the rule controls is
  audited before the run proceeds.
- Every check is proven able to fail: a superseded or mutated input drives it in a test
  (C4).

## Enforced by

`docs/oracles/registry.toml` with `provisional` and `registered_at`; C3 ledgers on
in-memory state; C4 mutation run; A2's refusal table and enumeration test; the `Refused`
verdict of A5 loops.

## References

- /home/cfutro/docs/world/docs/src/practice/conventions.md
- /home/cfutro/docs/world/lib/lapse.py and /home/cfutro/docs/world/lib/stellar.py (module docstrings: "the two checks that can fail")
- /home/cfutro/docs/world/notes/external-model-survey.md, section 55
- /home/cfutro/docs/world/docs/src/reference/design-intent.md ("A judgment made while a class is absent is not a judgment")
- Plan decisions C1 to C4.
