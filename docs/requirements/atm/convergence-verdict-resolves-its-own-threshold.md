+++
id = "REQ-ATM-015"
title = "A convergence verdict is an upper-bound statistic over an autocorrelation-corrected window sized to resolve its own threshold; the estimator is chosen by whether it can decide the criterion; memory time and relaxation time are two quantities"
old_path = ["/home/cfutro/docs/world/notes/audits/flux-slope-bracket.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's convergence instrument across its run record, and
on synthetic series with known answers.

- Two arms identical in build, surface, executable, structure and window,
  differing only in the flux they were given, passed the same criterion on
  opposite windows and on nothing else. The criterion's statistic was
  `|offset| + standard error`, and the estimator selection accepted an
  exponential fit whose half-width (0.19 K) exceeded the 0.15 K threshold while
  its fitted relaxation time was indistinguishable from zero at one sigma. A fit
  that collapsed outright routed to the drift form and passed; a fit that half-
  succeeded failed. The criterion was easier to pass the worse the fit was, and
  the two arms were on opposite sides of a coin flip in an estimator the report
  itself declined to trust (this audit, "What decided which estimator was
  used"). The repair introduced no number: the fit decides only where its half-
  width is at most a third of the threshold and its relaxation time is
  identifiable; otherwise the drift form, whose error the window is derived to
  resolve. Extending the cold arm was the wrong move because a more settled run
  has less curvature and drives the fit toward collapse.
- The variance of a window mean is `sigma^2 tau / n`; at the measured lag-1
  correlation of 0.615 the count-based standard error was understated by 1.8 to
  2.0, and tau cannot be recovered from inside the window it corrects (a
  10-orbit span returned 1.46 of a true 4.2). The offset criterion needed a
  window of 21 to 44 orbits, estimate 34, against the 10 in use; the storage
  criterion's estimator at 10 orbits had a standard error larger than its own
  threshold, so it passed or failed on its own noise (`convergence-lengths.md`).
- Five of six criteria had been point estimates, which pass a state sitting on
  its threshold half the time; all became `|statistic| + SE < threshold` with the
  thresholds unmoved, and the change of form was made while nothing canonical
  had been run, which is the window in which a criterion's form can still be
  settled honestly.
- Memory time (how long the stationary wobble stays correlated; prices a mean's
  interval) and relaxation time (the e-folding of an approach; prices a decay)
  are two quantities both called tau. Fixing a memory time by direct estimation
  needs 300 to 500 tau and is out of reach; bounding a mean by batch means needs
  a span of 20 tau and no tau value. A reconvergence after a step change is a
  different question from trendlessness (a decay with a derived relaxation time
  fixed, conservative only while that time is a ceiling, which was not
  established) and costs 21 orbits against a cold start's 61.
- Fitting a memory time across a change of output regime read a 0.16 K step as
  a long correlation and quadrupled the production span the ladder would have
  been bought in; the declared scatter, memory and relaxation constants were
  anchored to the reports they were read from so that a report reading
  otherwise refuses the declaration.
- Both arms of the flux pair were the noisiest settled runs on record, so the
  default window grew from 55 to 61 orbits and the pair as bought could not hold
  it; the window follows the scatter as the two-thirds power.

## Why it carries

Decision 0009 makes every loop exit a predicate returning `Converged`,
`Bracketed`, `Refused` or `NotEvaluable`, and the coupled-loop scope fixes exit
criteria before the run over autocorrelation-corrected windows. This audit is the
evidence for what those predicates must contain: an upper-bound form, an error
that accounts for memory, a window derived per run from the run's own scatter to
resolve the threshold, and an estimator chosen by resolving power. Design ideas 9
and 10 of the plan (two timescales; standard errors account for autocorrelation)
are this record. The class is statistical, not a property of the old model.

## What this system must do

1. Every loop exit criterion is `|statistic| + SE(statistic) < threshold`, with
   the SE from an autocorrelation-corrected variance whose integrated
   autocorrelation time is estimated over a span longer than the window it
   corrects, and labelled a lower bound where the record does not allow that
   (decision 0009).
2. The verdict window is derived per run from the run's own residual scatter and
   memory time so that the SE of the bounding statistic is at most a third of
   its threshold; a window that cannot resolve a threshold returns
   `NotEvaluable` for that criterion by name (decision 0025).
3. Where two estimators exist, the one used is the one whose own error resolves
   the threshold; a fitted time constant is a measurement only where the series
   determines it, and a degenerate fit is reported as such rather than as a
   number.
4. Memory time and relaxation time are distinct typed quantities; run length is
   a floor decided before the run as approach plus a declared multiple of the
   memory-time bracket, an interval on a climatological mean comes from batch
   means over a span of at least twenty memory times, and a settling length after
   a step change is `tau_relax ln(A / allowance)` with the relaxation time taken
   from its bracket.
5. No statistic is fitted across a change of output regime, profile or
   estimator; segments are declared and a window may not span a join.
6. Every declared scatter, memory time and relaxation time is anchored to the
   artifact it was read from and refuses when that artifact changes (REQ-SYS-103).
7. The finalizer re-evaluates every exit at the final state, and a run that
   reaches its declared length while still refused is not finished (decision
   0009).

## Enforced by

- Decision 0009 (`FixedPointLoop` and `Ladder` as values with typed exits; the
  finalizer); the coupled-loop decision record's exit criteria.
- A synthetic-series oracle with closed-form memory and relaxation times, run per
  commit, that fails if the corrected SE stops covering the empirical spread
  (decision 0026).
- Decision 0025: a bar is fixed before the value it judges has been seen; a
  criterion that differs from its registration is unregistered until it is
  registered again.

## References

- Geyer, C. J. (1992). *Practical Markov Chain Monte Carlo.* Statistical Science
  7(4), 473-483. DOI: 10.1214/ss/1177011137 (to confirm). The initial monotone
  sequence estimator of the integrated autocorrelation time, and batch means.
- Zwiers, F. W., von Storch, H. (1995). *Taking Serial Correlation into Account in
  Tests of the Mean.* J. Climate 8(2), 336-351.
  DOI: 10.1175/1520-0442(1995)008<0336:TSCIAI>2.0.CO;2 (to confirm). The
  effective-sample-size correction for a climate time-series mean.
