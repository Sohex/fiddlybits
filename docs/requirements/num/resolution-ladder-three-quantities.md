+++
id = "REQ-NUM-005"
title = "A ladder's timestep is three quantities, and what changes with level is declared as a function of level, never a branch"
old_path = ["/home/cfutro/git/vesper/notes/audits/resolution-ladder.md", "/home/cfutro/git/vesper/notes/audits/resolution-ladder-wall-clock.md", "/home/cfutro/git/vesper/notes/audits/resolution-divergence.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's spectral ladder of five truncations. Three per-rung
timesteps existed under one name and were three different facts: a stability
ceiling (the coarsest step each rung carried on short probes), an escalation route
(the step each rung was actually run at, chosen so resolution and step never moved
together and every conversion happened at constant step), and commissioning
evidence (what a run of the intended length had shown for one pair). A step
qualified on a 400-step probe and one full orbit failed in the 47th orbit at the
next rung, with nothing building toward it; only a run of the intended length
settles endurance. Priced per orbit, the route cost 28 times the coarsest rung at
the third rung, the ceilings 14 times, and a one-step-for-all-rungs choice 14 times
at twice the coarse cost.

Halving the step at one rung moved the equilibrium global-mean temperature by
-1.59 K; doubling the resolution at a fixed step moved it by -1.30 K; the core's
adiabatic non-conservation fell from 0.31 to 0.12 W/m2 when the step halved. Two
rungs compared at different steps therefore report truncation error as resolution
sensitivity. A conversion of state between rungs tolerated a factor of two in
truncation and trapped at a factor of four, from every initial state including the
target's own balanced checkpoint. Converted arms landed on the same thermal and
radiative state as cold arms but carried 22.5 per cent more sea ice at sixteen
sigma; a third arm handed an intermediate ice state showed the settled ice tracked
the ice handed over in one hemisphere and reached a single converted state in the
other, so a conversion leaves an imprint on a hysteretic field that a smaller jump
does not remove.

The convergence verdict flipped seven times after the state had been stationary,
because a ten-orbit window's fitted-offset standard error was 0.113 K against an
allowance of 0.075 K; a twenty-orbit window, with the "stable from" criterion fixed
before the sweep, removed the flicker and declared thirteen orbits sooner. Standard
errors taken on the raw orbit count understated by about a factor of two; the
integrated autocorrelation time measured on one settled run grew with the window
it was measured on (1.0 at 20 orbits, 6.3 at 140). Two timescales, the memory time
of stationary variability and the relaxation time of an approach, were both called
tau and are not interchangeable; a run length was a floor decided before the run,
not a stopping rule (`/home/cfutro/git/vesper/lib/run_lengths.py`,
`/home/cfutro/git/vesper/lib/autocorrelation.py`).

Silent resolution dependence was everywhere the code did not know it had it: a
filter's critical wavenumber was absolute, confining the spectral tail at the
coarsest rung and removing most of the resolved spectrum at the third; four global
means were unweighted cell averages; six per-cell thresholds (a storm size as a
cell count, a snow-cover depth scale, a critical relative humidity, a convective
cloud fit, a land mask cut, a glacier flag at a depth) encoded one cell size with no
spacing term; the ladder was restated in nine places and diverged in most; the
checkpoint carried its grid and no reader compared it, so a checkpoint from a finer
rung was resliced flat into the coarser one; a surface file on the wrong grid was
read without a header check; an absent land-mask file left the compiled default of
an all-land planet with one indistinguishable log line.

## Why it carries

Every component in this system runs on a level of one hierarchy chosen by a profile
from the planet's radius (A1, A10), with local refinement, and every Closure
constant must be swept across at least two levels with a convergence-with-level
oracle (A3). The three-quantity confusion is generic to any refined model: what a
level can take, what a profile runs it at, and what a commissioning run has shown
are three facts with three owners, and merging them is how a step gets qualified by
a probe. Cross-level comparison that varies two things at once is the operator
problem the plan lists as not eliminated by the rewrite, so the discipline around it
has to be mechanical. Sub-grid thresholds that encode a cell size are Closure
constants that were never declared as such. Support identity on the type (A2) makes
the wrong-grid read a type error, and field semantics make the unweighted mean
unrepresentable. Convergence statistics that ignore autocorrelation and run lengths
typed by whoever is watching the clock are what made a 40-orbit precision
comparison reverse sign at 85 (REQ-NUM-001).

## What this system must do

1. For every component and level a `Profile` carries three separately owned
   quantities: a stability ceiling derived from the scheme's stability bound at the
   level's spacing over the profile's state brackets, with the wave speed that
   binds (acoustic, external gravity wave) computed from the gas-mixture group of
   REQ-ATM-017 and the declared gravity, and confirmed by a probe; the
   operating step the profile runs; and commissioning evidence, a registry row
   naming the run id, its length, the level and the step. A profile step above the
   ceiling refuses; evidence is never inferred from a probe or from another level.
2. A comparison across levels holds the step, the parameter set (by hash) and the
   initial-state family fixed; the comparison tool refuses arms that differ in more
   than the named factor, and records the truncation-error term separately where
   the step cannot be held.
3. Every quantity that scales with spacing (a filter scale, a sub-grid threshold, a
   diffusivity, a fraction-of-cell criterion) is a `Closure` with its declared
   scaling law in spacing and resolved state (A3) and a convergence-with-level
   oracle. Branching on level or on cell count in a physics module is lint-banned.
   Global reductions go through `Field` semantics with area weights.
4. The support id is a type parameter and an attribute of every stored array; a read
   across supports names its operator; an array or checkpoint on the wrong support
   is a type error or a store refusal. There is one declaration of the level ladder
   and no restatement.
5. A level conversion of state is an operator returning a ledger. Its imprint on
   fields with hysteresis is measured with at least three initial states before the
   conversion is admitted to a route, and every loop exit predicate is evaluated on
   the converted arm, never inherited from the donor.
6. Convergence and comparison statistics use autocorrelation-corrected standard
   errors: the integrated autocorrelation time is estimated by the initial monotone
   sequence on a span that supports it, the upper end of its interval is used
   wherever understating the error is the dangerous direction, stationarity is
   tested before the estimate, and windows and criteria are registered before the
   run (C2). Memory time and relaxation time are two quantities with two names, and
   a run length is a floor derived from the memory-time bracket and decided before
   the run.

## Enforced by

The `Profile` type with three per-component fields; the level-branch lint; `Field`
semantics for reductions; the `Ladder` value with exit predicates (A5); the oracle
registry with `provisional` rows; the autocorrelation module tested against AR(1)
series of known memory time; decision records A1, A3, A5, A10, B9, C2 and C6.

## References

- Courant, R., Friedrichs, K., Lewy, H. 1928. Uber die partiellen Differenzengleichungen der mathematischen Physik. Mathematische Annalen 100. DOI: 10.1007/BF01448839
- Roache, P. J. 1998. Verification of Codes and Calculations. AIAA Journal 36(5). DOI: 10.2514/2.457
- Roache, P. J. 1994. Perspective: A Method for Uniform Reporting of Grid Refinement Studies. Journal of Fluids Engineering 116(3). DOI: 10.1115/1.2910291
- Geyer, C. J. 1992. Practical Markov Chain Monte Carlo. Statistical Science 7(4). DOI: 10.1214/ss/1177011137
- Madras, N., Sokal, A. D. 1988. The pivot algorithm: A highly efficient Monte Carlo method for the self-avoiding walk. Journal of Statistical Physics 50. DOI: 10.1007/BF01022990
- von Storch, H., Zwiers, F. W. 1999. Statistical Analysis in Climate Research. Cambridge University Press. DOI: 10.1017/CBO9780511612336

## Amendments

- 2026-09-08: named the binding wave speed of the stability ceiling as computed from the gas-mixture group of REQ-ATM-017 (audit row 34), from notes/findings/2026-09-08-implicit-earth-audit.md
