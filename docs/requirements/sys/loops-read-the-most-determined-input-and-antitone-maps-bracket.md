+++
id = "REQ-SYS-007"
title = "Every step reads its most determined input, every field update belongs to a loop, and an antitone coupling is bracketed rather than converged"
old_path = ["/home/cfutro/git/vesper/docs/src/pipeline/loops.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's loop chapter held every step to one invariant: bootstrapping and
looping are the process of moving from the least determined state to the most
determined one, so a step reads the most determined input available at the point it
runs, not the one its first pass happened to have. The corollary is what catches
defects: an input pinned to an earlier stage's artifact when a better determined one
exists does not converge more slowly, it converges to the wrong place, silently,
because the artifact it reads is a real artifact of a real world. The case: a soil
builder took its runoff from the terrain-only bootstrap climatology, which carries no
lakes on any iteration, while taking its vegetation from a run that reached the
baseline; the split was a leftover, and what it cost was the arid tail of the soil,
which sits exactly where the inland water is. Where the invariant does not bite: a
quantity that depends on the calendar or the geometry rather than the climate state is
equally determined at either stage. And it is not the silent fallback the no-fallback
rule forbids, because the two stages are the same world on one build, the choice is
made on what the configuration declares rather than what is on disk, and the choice is
stamped on the product.

The second half: the terrain-carve verdict map is antitone. Carving removes closed-basin
fill, the brightest lithology, so the land darkens, the world warms, open-water
evaporation rises, and basins that were marginal now stay closed: a larger carve set
produces a smaller next verdict. An antitone map does not approach a fixed point from
one side; it oscillates, and successive verdicts bracket the answer. The procedure that
followed: take the verdict at both bounding climates (bare-rock and vegetated arms, at
one flux, on the same terrain) and carve only the intersection, so everything between
is the bracketed set by construction rather than by a tolerance chosen afterwards. The
bracket is over the vegetation state and does not cover the antitone overshoot (an
overshooting basin is one both arms cut, so it is never in the disagreement set), so
the honest uncertainty is the width and the overshoot side by side, and the overshoot
is measured by holding the geometry still and moving only the climate. A bound arm is a
bound, not a world, and is said to be one wherever its numbers appear. A wide bracket is
the correct answer to a genuinely uncertain question, not a failure. Two further loops
were recorded as cut (dust, one iteration deep) or deliberately open (the carbon
cycle, with the cost of the assumption measured and the note that the requirement is
driven by land area, not weathering intensity, and by the exorheic share alone).

## Why it carries

In one process with a single `WorldState` (A5) the two-stage confusion is
unrepresentable, but the invariant survives in two forms: a component reads the
current owner-written field, never a cached earlier one, and the slow tier reads
climate statistics accumulated over declared cycles rather than a snapshot. The
antitone lesson is general to any slow process whose feedback on the fast system is
opposite-signed: alternating it to a fixed point does not converge. The plan's answer is
to make the carve a process integrated on the slow tier (B5, incision by overflow
discharge against the time fraction spent overflowing) and, where a verdict must
remain, to bracket it and say so in the type.

## What this system must do

- A component reads a quantity from the `WorldState` field its declared owner wrote;
  reading an artifact from an earlier iteration or a coarser level is a refusal unless
  the read is declared as a bracket arm, and then the product records which arm.
- Every field update belongs to a loop: a quantity computed and written down that no
  loop re-reads is a frozen derived quantity (REQ-SYS-002).
- Loops are `FixedPointLoop` values whose exit predicate returns `Converged`,
  `Bracketed`, `Refused` or `NotEvaluable`; an `Antitone` loop cannot return
  `Converged`, and its `Bracketed` verdict reports the width and the overshoot
  separately.
- A bound arm (an endmember run that exists to produce one end of a bracket) is
  labelled a bound in its identity and wherever its numbers are rendered.
- A verdict on a slow process is replaced by the process where one can be written
  (the carve as overflow incision integrated against the fast tier), and the exit
  criterion becomes stationarity of the slow state rather than agreement of successive
  verdicts.
- A loop left open on purpose (a cycle the system does not yet close) is a declared
  absence whose cost is measured and reported, never an assumption read as a result.

## Enforced by

Decision A5 (`WorldState`, `FixedPointLoop`, `Antitone`); B5 and B9; the finalizer of
REQ-PROC-007; the `assemble` check that every read names its writer.

## References

- /home/cfutro/git/vesper/docs/src/pipeline/loops.md
- /home/cfutro/git/vesper/docs/src/reference/vocabulary.md (bracketed versus marginal versus disputed)
- Plan decisions A5, B5, B9.
