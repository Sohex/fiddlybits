+++
id = "REQ-PROC-005"
title = "A price is taken in the currency of the decision it gates, as a secant between converged points, against the surface it acts on"
old_path = ["/home/cfutro/git/vesper/docs/src/reference/design-intent.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's design-intent chapter kept five lessons that generalise. The orbit
and the biosphere were one choice, not two, because the stellar-flux windows that put
the world in its design temperature range did not overlap between a vegetated and a
bare-rock surface, and the endmember spread near the target was wider than the target
band, so no single flux was robust to the vegetation question. A sensitivity measured in
one regime is not reused in another: bracket between two converged points that span
the target rather than extrapolate from one, because extrapolating across the ice
transition predicted 291.9 K for a run that converged at 287.47 K. A correction's size
depends on how much of the surface it acts on, so it is estimated against the state
the system is in, not the state it was first measured in (a spectrum error was
negligible on sea ice covering a couple of per cent of the world and not on seasonal
snow). A band-resolved radiation scheme was refused on price with the criterion fixed
before the measurement (the candidate cost 8.6 times the present scheme per column on
the cloudy corner the model actually ran), and the three holes the refusal declined to
close were kept open by name so that a future proposal must beat the measurement
rather than restate the holes.

The companion audit (`missed-couplings.md`, finding 1) found the error budget priced
every item in kelvin or W/m2 and none in runoff, evaporation or basins, while the one
irreversible decision (the carve list) read runoff as its denominator; a kelvin-priced
item nearly cancels in runoff, about one per cent per kelvin, while a water-cycle
perturbation at fixed temperature is amplified by the full P/R of over six. "The budget
has one currency and the irreversible decision reads another." The sensitivity module
(`lib/sensitivity.py`) records three sensitivities in simultaneous use differing by a
factor of 2.2, a denominator that must be absorbed flux per unit flux ratio rather than
incident, and the rule that a registered prediction is amended in place with a note
when its conversion moves. The external survey (section 2) kept a cost table with its
own error stated: it had compared a bare atmosphere against coupled suites, and
CPU-hours per simulated century is undefined for a system whose components advance on
different clocks.

## Why it carries

Every sensitivity report, error budget and cost estimate in a builder is a price, and a
price is wrong in a way nothing objects to when it is in the wrong currency, taken
across a regime boundary, or scaled from a different surface. The plan's profiles
(A10), its distance report (C1), its benchmarks with A/A scatter measured before any bar
(C6) and its F1 sensitivity probe ("the parameterised transport is run at the ends of
its declared bracket, and if a declared metric moves beyond its own bracket the feature
is flagged") are all prices of this kind.

## What this system must do

- An error budget or sensitivity report prices each item in every currency a
  downstream decision reads and names the decision; a decision that cannot be undone
  by re-running (a terrain state, a parameter moving into a profile) has its own budget
  in its own currency.
- A sensitivity is a local secant between two converged points on the current
  configuration, declared with its window, support, instrument and regime, and refused
  outside the regime it was measured in.
- A correction is sized against the share of the surface it acts on in the current
  state.
- A design target that depends on a coupled state is bracketed over that state; a
  target reached at one state is not a target.
- A refusal on price registers its criterion before the measurement, records the
  measurement with the load it was taken under, and keeps the holes it declines to
  close open as declared absences.
- A registered prediction that changes is amended in place and says it moved.
- Costs are reported per tier unit at a named profile; a comparison between unlike
  objects states what each figure covers or is not made; a table kept with a known
  error states the error.

## Enforced by

Sensitivity artifacts with currency checks (REQ-SYS-002); F1's sensitivity probe; C6
benchmarks and A/A scatter; decision records for refusals on price; the M-1
verification that no document names effort estimates.

## References

- /home/cfutro/git/vesper/docs/src/reference/design-intent.md
- /home/cfutro/git/vesper/notes/audits/missed-couplings.md, finding 1
- /home/cfutro/git/vesper/lib/sensitivity.py (module docstring)
- /home/cfutro/git/vesper/notes/external-model-survey.md, section 2
- Plan decisions A10, C1, C6, F1.
