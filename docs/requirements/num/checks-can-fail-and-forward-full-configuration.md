+++
id = "REQ-NUM-008"
title = "A check can fail, forwards its full configuration, and a bar that is printed is a bar that exits non-zero"
old_path = ["/home/cfutro/docs/world/notes/audits/checks-that-forward-too-few-arguments.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Swept across every check, round trip and self-test in the predecessor's project
scripts. Three shapes recurred. The short arm: a re-solve or reference recomputation
built from a shorter argument list than the thing it checked, so it passed for as
long as the omitted terms were absent and silently stopped testing the moment one
landed (a groundwater uniqueness identity measured before a sink and a base level
existed; a spectral partition check that ran over the Sun when the star was the
point, and had never run over the star; a pedology scoring arm lacking the model's
own caps, whose measured clay bias inverted from +0.062 overstating to +0.004
understating once the arm went through the model). The fixture that agrees with
itself: a comparison built by the code it checks, admissible only in the form that
asserts the fixture green first and then breaks exactly one thing per case with the
verdict named in advance. The verdict nobody acts on: a bar declared, evaluated,
printed, written to a report and then dropped with exit 0, which was the most
common form by a wide margin, so a past green result from those scripts was
evidence that the script ran and not that the bar was met. A control offered as
proof of reproducibility compared a window in which no output had been written. A
bar chosen after the run it judges was refused as not a bar.

## Why it carries

Ideas 3, 12 and 18: a finite output is not acceptance, registries are
self-checking, and a test needs a right answer rather than a comparison that can
only differ. C2 registers thresholds before the artifact they judge; C4 runs a
mutation suite that fails if any deliberate break goes uncaught. A generic builder
has a large configuration space (any star, gravity, rotation, spectrum), so a check
that silently drops one axis of it passes forever on the axis it never saw. The
three shapes are language-independent and each has a mechanical form.

## What this system must do

1. A check's comparison arm is built from the same configuration value as the path
   it checks: one `System` and one `Profile` passed whole. A check that constructs a
   partial configuration for its arm is refused by a test that diffs the recorded
   parameter subsets of the two arms (the A3 tracking wrapper).
2. Every registered check has a positive control: a named deliberate break in the
   mutation registry that it must catch. A check with no mutation it catches is not
   admitted to the registry.
3. A verdict is an exit. A registered bar evaluates to PASS, FAIL, REPORT or
   NotEvaluable, and FAIL fails the job; printing or writing a report is not a
   verdict.
4. A bar is registered before the first artifact it judges, with `provisional` and
   `registered_at` (C2); a bar changed after a result is a new bar with its own
   registration.
5. A fixture built by the code under test is admitted only in the green-first,
   break-one-thing form.
6. A control must be able to observe: a comparison over a window with no
   observations, or a round trip that exercises no branch, returns NotEvaluable and
   never PASS.

## Enforced by

The oracle registry schema (bar, positive-control mutation id, `registered_at`); the
weekly mutation run (C4); CI exit semantics; the recorded-parameter-subset diff
test; decision records C2 and C4.

## References

- DeMillo, R. A., Lipton, R. J., Sayward, F. G. 1978. Hints on Test Data Selection: Help for the Practicing Programmer. Computer 11(4). DOI: 10.1109/C-M.1978.218136
- Jia, Y., Harman, M. 2011. An Analysis and Survey of the Development of Mutation Testing. IEEE Transactions on Software Engineering 37(5). DOI: 10.1109/TSE.2010.62
