+++
id = "REQ-SYS-002"
title = "Every derived quantity is read from its producer or re-derived inside a loop that refuses on disagreement"
old_path = ["/home/cfutro/docs/world/notes/audits/frozen-derived-quantities.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

A frozen derived quantity is a value that some other artifact, script or measurement
computes, copied into a place with no path back to the computation. The test is one
question asked of any number: what re-runs when this changes? If nothing, the quantity
will drift from what it describes without anything objecting, because a stale number is
an ordinary number and the artifact carrying it is a real artifact. The test is about
the path back, not correctness today: agreement is what a number looks like the day
before it drifts.

The sweep of 2026-08-27 found sixty-four instances on the predecessor's tree and eleven
demonstrably stale. Measured there:

- The convergence constants that sized every commissioning run had been wrong by about
  a factor of two, and by a factor of five in the production span they set, for as
  long as they stood; the declared scatter and memory time produced the window, the
  window produced the assessment, and nothing carried the assessment's own reading
  back.
- A flux-to-kelvin slope declared at 202.0 was reproduced by its own `verify()` on
  every consistency run while both runs it named had been deleted and belonged to a
  build no longer configured; re-derived on the active build it was 159.7. A
  re-derivation check is not a currency check, and the difference is invisible from
  inside the file that recomputes.
- A producer named without its arguments is the same defect: the slope's two arms
  named a run and a report but not the assessment window, so when a rule change moved
  one arm's default assessment onto a different block of orbits the slope silently
  moved 1.7 per cent.
- A land-mean emissivity declared to four decimals moved by more than ten times its
  written precision when the terrain changed, because the key is defined as an area
  weighting over the build's land.
- An ozone band weight went stale when the spectrum file it was derived from was
  rewritten in place by a flux-conserving rebin; every other spectrum-derived number
  was re-derived and this one was not.
- A gate that regenerated its own reference from the frozen value upstream of it could
  catch a retyping error and could not catch the climatology moving under the value.
- Three sensitivities differing by a factor of 2.2 were in simultaneous use
  (`lib/sensitivity.py`); Earth's 6.5 K/km lapse rate was hardcoded in three places and
  a reference height computed at Earth's gravity was high by the gravity ratio, moving
  a bulk exchange coefficient by 14 per cent (`lib/lapse.py`); three values of the
  stellar band-1 fraction were in circulation from three integrations and none was the
  model's (`lib/stellar.py`); a year length of 189.6145 d was still in the hydrography
  scripts when the baseline had moved to 180.655 d, and a component that counts whole
  days has a counted year distinct from the true orbit (`lib/orbit.py`).

The boundary matters as much as the class. A decision (a threshold fixed before its
runs, a design preference, a bracket) is an input and is supposed to stay put. A
physical constant or a paper-sourced value cannot drift in the tree. A dated
measurement in a finding is supposed to be frozen and enters the class only when
something consumes it as live input or restates it as current. The two acceptable
dispositions: the consumer reads the emitted value, so there is nothing to freeze; or
the declaration lives inside a loop that re-derives it with a check that fires on
disagreement. A declared constant with neither is a drift with a timer on it.

## Why it carries

Any builder computes thousands of derived values, and the predecessor's record is that
every quantity that drifted was a derived value somebody wrote down and every quantity
that stayed right was one inside a loop. One clock in SI seconds (A4), one `System`
struct with `Derived` fields (A3) and content-addressed artifacts whose keys include the
parameter subset a component read (A6) make most of the class unrepresentable. What
they do not remove is the copy of a measured statistic into a threshold, a bracket
anchor, a comment or a config, and the currency of what a declaration names.

## What this system must do

- A consumer reads a derived value from the producer or from the artifact the store
  names; a literal copy of a producible number is refused by lint outside a test
  fixture.
- `Derived` fields of `System` are computed from their inputs and refuse a disagreeing
  caller value. Day, year, orbital phase and every calendar quantity are pure functions
  of `System`; no literal period exists anywhere, and where a component counts in
  whole steps its counted period is a second derived quantity from the same
  declaration, never a second literal.
- Where a declaration must exist (a bracket anchored on a measurement, a threshold
  derived from a measured statistic), it names its producer and every argument the
  producer ran with: window, support identity, instrument or I/O regime, code version,
  input keys. A check re-derives it and refuses on disagreement, and separately refuses
  when the named producer artifact is absent, superseded, or on a support other than
  the configured one.
- Every such check is exercised against a superseded declaration so that its ability
  to return no is tested, not asserted.
- A check never regenerates its reference from the value it is checking.
- "What re-runs when this changes" is answered for every quantity by the measured
  dependency graph, not by a hand-maintained list.
- A prediction registered through a derived conversion is amended in place with a
  note when the conversion moves; it never silently changes.
- A comment or docstring that restates a derived magnitude names the artifact and the
  support it was measured on, or does not state the magnitude.

## Enforced by

Decision A3's dependency tracking (`recorded` is a subset of `declared` as a test, and the measured
graph for invalidation); A6 artifact keys; the refusal of `Derived` fields; the M0 gate
"derived Earth quantities from their own inputs"; per-declaration currency tests with a
superseded fixture; the doc lint of REQ-PROC-001.

## References

- /home/cfutro/docs/world/notes/audits/frozen-derived-quantities.md
- /home/cfutro/docs/world/docs/src/pipeline/loops.md, section "The corollary: a field update has to be able to carry"
- /home/cfutro/docs/world/lib/sensitivity.py, /home/cfutro/docs/world/lib/lapse.py, /home/cfutro/docs/world/lib/stellar.py, /home/cfutro/docs/world/lib/orbit.py (module docstrings: the four instances of computing at call time from the artifact the config names)
- Plan decisions A3, A4, A6.
- Related: REQ-SYS-102 (one clock; no day constant as a time unit), REQ-SYS-103 (a value's derivation is reachable from the value; nothing is retyped from an artifact).
