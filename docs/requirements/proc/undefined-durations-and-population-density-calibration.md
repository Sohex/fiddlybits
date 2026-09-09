+++
id = "REQ-PROC-011"
title = "A duration a component has no clock for is undefined, not unmeasured; an Earth calibration reads a population's density at matched size class, never its survivors"
old_path = ["/home/cfutro/docs/world/docs/src/reference/no-time-axis.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's terrain generator had no time axis at all: its erosion intensities
were dimensionless sliders, its lithology module stated "no ages, no stratigraphy and no
unconformities, because there are no timesteps to hang them on", and its basin infill
had "no sediment budget or timescale". The consequence the chapter fixed: a duration was
undefined there, not unmeasured, so asking the generator how old a surface was asked
for a concept it did not have, and anything wanting a duration had to supply one. The
move that worked was to stop asking "when" and ask what a randomly chosen moment looks
like: a landscape, a volcanic province and a lake population are stationary populations
with a turnover, the terrain is one sample, so the question has an answer although the
duration does not, and Earth is the calibration because Earth is also one randomly
chosen moment. Used three times: flood-basalt provinces excluded from andic soils
because a random moment finds one erupting with probability of order one per cent; a
deposit class whose defining control is an absolute age declared as something the world
cannot have rather than approximated; an incision coefficient solved against the
density of Earth's standing through-flowing basins per run with a Poisson bracket. Two
ways it goes wrong: declaring a duration and then reasoning as though it were measured
(a declared window "should be labelled as calibrated to an outcome, not as a
duration"), and calibrating against Earth's survivors instead of Earth's density, which
gave an answer 300 times away, with a size-class mismatch between Earth's small lakes
and the mesh's large basins flipping the sign once on top of that. A rigorous factor
multiplying a heuristic reads as more trustworthy than it is.

## Why it carries

The fact is superseded: decision B1 gives the terrain snapshot two declared clocks, a
deep clock from the tectonic seed and an integrated surface clock, so ages and rates are
state on the SI clock (A4) and downstream derivatives have a real clock. The lessons
carry to every component: a component that has no clock for a quantity may not emit it,
a stationary-population expectation is the form where a process is not integrated, and
any calibration or oracle bar taken from an Earth population statistic must be a
density at the size class the mesh resolves, with the size floor declared and swept
(REQ-SYS-001, row 5 of the tuned-values audit).

## What this system must do

- Every rate and age in any component's state carries the clock it is on; a component
  with no clock for a quantity refuses to emit it, and no declared number stands in for
  a duration a process does not integrate.
- Where a process is not integrated, its form is an expected value over a declared
  stationary population with the population, its turnover and their brackets
  declared; the record labels the result as an outcome calibration, never a duration.
- A class whose defining control is an absolute age outside the range the deep clock
  spans is a declared absence, not an approximation.
- An Earth population statistic used as a calibration target or an oracle bar is a
  density per unit area at the size class the mesh resolves, with a Poisson bracket on
  the count and the size floor declared and swept; the identity of any individual
  survivor is never the target.
- A rigorous factor multiplying a heuristic is labelled as the heuristic's disposition,
  not the factor's.

## Enforced by

Decision B1's clocks and A4; the `Sourced` and `Bracketed` disposition records for any
Earth population target; the M1 gate's age-times-rate identity; the oracle registry.

## References

- /home/cfutro/docs/world/docs/src/reference/no-time-axis.md
- /home/cfutro/docs/world/notes/audits/tuned-values.md, section 5 (the size floor)
- Plan decisions A4, B1.
