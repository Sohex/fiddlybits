+++
id = "REQ-SYS-004"
title = "A dormant parameterisation is recorded with the switch that arms it, and \"off\" is asserted by the system rather than inherited"
old_path = ["/home/cfutro/git/vesper/notes/audits/tuned-values.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

A tuning that no run reaches costs nothing today and costs everything on the day
someone throws its switch, and it is invisible to any sweep of values in use. The
predecessor recorded each such knob with the switch that arms it and where that pairing
is written in the tree (`tuned-values.md` sections 18 and 19, re-read against the
source on 2026-09-05):

- A longwave "tuning opportunity" factor shipped at 1.00, the value that makes it drop
  out, while the manual in the same tree recommended 0.15; a reader consulting the
  documentation to decide would be told to arm it.
- A compiled carbon-weathering switch defaulted to on in the model source and was held
  off only by a library keyword default in the run staging; the model source and the
  staging disagreed and the staging won silently. The roughness field was derived on
  the stated ground that the vegetation switch was off, so a change to that switch
  would silently replace a derived field with Earth-fitted terms.
- A vendored weathering module shipped four calibration factors at 1.583, 1.178, 0.8548
  and 0.8878 where its own comment said "leave as 1.0 for uncalibrated", behind a
  single logical named for calibration; its two-dimensional Earth reference patterns
  were protected only by the files being absent, which is the right outcome by the
  wrong mechanism.
- An Atlantic-Pacific freshwater flux adjustment was compiled into every executable and
  held off by a flag that read as a choice of atmosphere rather than as a calibration
  switch.
- An ocean-module Earth radius sat dormant under a scheduled A/B that would have come
  back wrong by a factor of 1.44 with nothing in the output to say so.

## Why it carries

Every imported component (A8) and every declared absence (F2) has dormant paths, and a
generic builder will turn switches on for configurations the original authors never
ran. A switch inherited from a default is a silent default across a component boundary,
which design idea 6 forbids: check at the read. Dormancy changes priority, not
disposition.

## What this system must do

- Every switch that arms a parameterisation or a calibration path is a field of
  `System` or `Profile` with no default; the off state is asserted at `assemble` and is
  part of the run identity.
- The constants behind a dormant path carry their disposition (REQ-SYS-001) while
  dormant, and the record beside the switch names them.
- An import review (REQ-PROC-008) lists every calibration factor, flux correction and
  Earth reference pattern in the dependency with its arming switch and its shipped
  state, before the dependency is wired to anything.
- A path protected only by a missing file or an unreachable branch is not protected;
  the absence is declared and asserted, and restoring the file cannot silently arm it.
- Where a parameter's effect depends on another switch (a derived field valid only
  under one setting), the dependency is declared and `assemble` refuses the
  combination.

## Enforced by

Decision A3 (keyword-only `System`, no defaults); A5 `assemble` checks; the
import-review record's leak test (A8); the `EarthRatios` lint that forbids physical use
of Earth denominators.

## References

- /home/cfutro/git/vesper/notes/audits/tuned-values.md, sections 18 and 19
- /home/cfutro/git/vesper/docs/src/practice/conventions.md, "A tuning that no run reaches is a trap"
- Plan decisions A3, A5, A8, F2.
- Related: REQ-SYS-104 (a dormant Earth-fitted process names its re-derivation at the switch), REQ-SYS-101 (an absent input is never filled from Earth).
