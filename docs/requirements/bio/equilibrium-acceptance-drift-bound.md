+++
id = "REQ-BIO-014"
title = "A biosphere equilibrium is accepted only when an upper confidence bound on end-to-end relative drift over the whole retained record is inside a consumer-derived tolerance, with a per-cell trend refusal, memory time at the upper end of its window, an e-folding time measured without its asymptote, and a spin-up floor derived from the tolerance alone"
old_path = ["/home/cfutro/git/vesper/biosphere/notes/equilibrium-trend-null.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's rule for whether a vegetation run had settled changed four
times, each time because a measurement changed what the rule was rather than
a number in it (measured on the old world's LPJ-GUESS-CNP runs at the archived
commit, 1617 cells, records of 1000 to 1253 forcing cycles, and 2000
synthetic AR(1) trials per case):

- A trending-cell fraction limit of 0.25 had no derivation and sat BELOW the
  rate at which the test flagged cells with provably no trend (a per-field
  null spanning three orders of magnitude, 0.001 to 0.387, set by each
  field's own internal variability); its denominator was every cell, so a
  strategy present on a sixth of the grid could not reach the limit however
  hard it drifted.
- An empirical N-window null cannot express a probability finer than
  1/(N+1); over about 35 effective independent fields the family rate was
  0.34 against a declared 0.05, and reaching 0.05 empirically needed about
  7100 retained cycles. The repair is an analytic null, which needs a valid
  standard error.
- A trend fitted inside one memory time is not a trend. Integrated
  autocorrelation times ran 9.3 to 125.3 cycles on the record the window of 10
  cycles was tested over; no inflation of the slope error rescues a span
  shorter than its memory. Sizing the record at ten memory times read off a
  shorter record did not converge (the floor moved from 1253 to 2127 when the
  record grew 25 percent), because the span multiple asks whether the memory
  time can be established when the contract needs to know whether the
  tolerance can be resolved.
- The instrument that works points the other way: an acceptance gate asserts a
  run HAS settled, so its error is letting a drifting run through, and the
  test is an equivalence test. Split the record in half; double the difference
  of the half means (a half-to-half difference is half the end-to-end change
  of a steady drift); take memory time and scatter on the RAW halves so a real
  drift inflates the error it is judged against; degrees of freedom on the
  half as m/tau - 1 by Welch; memory time at the UPPER end of its
  Madras-Sokal window because the estimator is biased low exactly where the
  acceptance rate grows (returns 128.9 for a true 213 on 1253 samples); pass
  when |D|/scale + t(alpha, df) seD/scale is inside the limit. By
  intersection-union a run passes only when every quantity passes, so the
  per-quantity rate bounds the run rate with no multiplicity correction; a
  record too short gives a wide bound and refuses itself, so no separate
  memory guard exists; and the record floor computed by inverting the bound
  converges, because the standard error falls as the root of the record while
  the memory time grows sublinearly. Validated: the declared 0.05 held across
  memory times 1 to 400 at the shipped construction, and the significance
  form it replaced would have passed a run drifting at the tolerance 93 times
  in 100 on the slowest fields.
- The assessed set is the set of consumer quantities. A column entering a
  consumer only through a sum owes nothing beyond what the sum owes (the sum's
  own series carries every cancellation); a quantity's tolerance is the
  tightest among its consumers, each derived through that consumer's own chain
  (cover tolerance 0.05 derived through albedo, attenuation and flux-to-kelvin
  to 0.0776 K against a 0.05 K bar, retained because the chain's own bracket
  spans a factor of two); a column no consumer reads keeps a reported bound as
  a diagnostic; conservation identities impose no drift tolerance. The
  reported value a consumer reads is taken over the whole record with its
  standard error, because a ten-cycle mean at a memory time of hundreds is one
  effective sample.
- The per-cell half exists for the one case a spatial mean cannot see, a
  cancelling regional dipole (caught in 42 of 64 columns by the cell half and 0
  by the global half), on occupied cells, and its limit was still calibrated,
  erring toward refusal.
- The relaxation time is measured without its asymptote: for a + b exp(-t/tau)
  the difference between consecutive equal blocks decays by exp(-Q/tau) and a
  cancels, so four blocks give tau = -Q / ln(r) with declared admissibility
  (same sign, contraction in (0, 1), each difference above twice its
  memory-corrected error, the contraction resolvably below one, the second
  ratio inside a factor of two of the first). No field on any record survived
  the resolution condition, and a value read off a ratio of 0.992 +/- 0.344
  would have sized a spin-up thirty times what the record supported.
- The spin-up floor needs no relaxation time: exp(-S/tau)(1 - exp(-L/tau))
  <= tol is bounded over all tau, so its supremum, 6.86 retained records at a
  tolerance of 0.05 (17.9 at 0.02, 3.19 at 0.10), satisfies it at every tau;
  a measured admissible tau can only ask for less. An artifact from a
  superseded assessed set is not pooled.

## Why it carries

B9 fixes exit criteria before the run (land-carbon drift among them) over an
autocorrelation-corrected window; A5 makes loop exits values returning
Converged, Bracketed, Refused or NotEvaluable, with an antitone loop unable to
say "converged"; design idea 9 keeps memory time and relaxation time apart and
makes run length a floor decided before the run; idea 10 corrects standard
errors for autocorrelation. The equilibrium reducer above is the instrument
those decisions need, and every one of its load-bearing details was found by
a measurement that a plausible alternative failed. The vegetation and
biogeochemistry tier is where it binds hardest because its memory times are
the longest in the coupled system.

## What this system must do

1. The vegetation and biogeochemistry exit predicate (A5, B9) returns
   `Converged` for a quantity only when the upper confidence bound on its
   end-to-end relative drift over the whole retained record, constructed as
   above (doubled half difference, raw-half scatter and memory time, Welch
   degrees of freedom on the half, memory time at the upper end of its window),
   is inside that quantity's tolerance. No multiplicity correction is applied
   and none is needed. A record that cannot resolve the tolerance returns
   `Bracketed` with the record floor it needs, never `Converged`.
2. The assessed set is derived from the consumer graph (A3's measured
   dependencies): every quantity a consumer reads, judged as the sum the
   consumer forms; each tolerance derived through the consumer's own chain to
   the physical quantity it moves, with the chain's bracket recorded; a
   quantity with no consumer keeps a reported bound as a diagnostic;
   conservation identities (REQ-BIO-013) impose none. Adding a consumer adds a
   row.
3. A per-tile trend refusal on occupied tiles catches cancelling regional
   drift; its limit is derived analytically, not measured from the run's own
   windows, and until it is, it is labelled calibrated and errs toward
   refusal.
4. The reported value a consumer reads is the whole-record mean with its
   memory-corrected standard error; no last-year value and no short-window
   mean reaches a consumer.
5. The relaxation time is measured by the block-difference ratio with its
   admissibility conditions; a field failing any condition gets no relaxation
   time and no default. The spin-up floor is the tolerance minimax over all
   relaxation times unless an admissible measured value asks for less; the
   retained-record floor is inverted from the run's own scatter and memory
   time and written on the acceptance artifact whatever the verdict. Both
   floors are in complete forcing cycles on the system clock and are never
   pooled across a changed assessed set.
6. The statistic's size and cost are validated against synthetic series with
   known answers at every registered memory time, and the validation is a
   fixture that fails when the declared rate is missed.

## Enforced by

- Type: `FixedPointLoop` and `Ladder` exit predicates (A5) returning the
  four-valued verdict; the finalizer re-evaluates every exit at the final
  state.
- Fixtures: the AR(1) size-and-cost validation; the opposing-columns versus
  co-drifting-columns pair (same statistic, same tolerance, opposite verdicts
  when judged on the sum); the family-rate union bound computed per run.
- Registry: tolerances registered with their consumer chain before the first
  artifact (C2); `NotEvaluable` blocks a gate (Part E).

## References

- Madras, N. and Sokal, A. D. (1988). The pivot algorithm: A highly efficient
  Monte Carlo method for the self-avoiding walk. Journal of Statistical
  Physics 50, 109-186. DOI: 10.1007/BF01022990. The windowed integrated
  autocorrelation time estimator and its window.
- Sokal, A. D. (1997). Monte Carlo Methods in Statistical Mechanics:
  Foundations and New Algorithms. In: Functional Integration, NATO ASI Series
  B 361, 131-192. DOI: to confirm. Effective sample size under
  autocorrelation.
- Welch, B. L. (1947). The generalization of "Student's" problem when several
  different population variances are involved. Biometrika 34, 28-35.
  DOI: 10.1093/biomet/34.1-2.28.
- Schuirmann, D. J. (1987). A comparison of the two one-sided tests procedure
  and the power approach for assessing the equivalence of average
  bioavailability. Journal of Pharmacokinetics and Biopharmaceutics 15,
  657-680. DOI: 10.1007/BF01068419. The equivalence-test direction.
- Berger, R. L. and Hsu, J. C. (1996). Bioequivalence trials,
  intersection-union tests and equivalence confidence sets. Statistical
  Science 11, 283-319. DOI: 10.1214/ss/1032280304. Why a run passing only when
  every quantity passes needs no multiplicity correction.
- /home/cfutro/git/vesper/lib/lpj_output.py (`drift_bound`,
  `cycles_for_bound`, `record_cycles_for_bound`, `relaxation_time`,
  `_cell_fraction`, `_trend` docstrings; the reducer as implemented).
- /home/cfutro/git/vesper/biosphere/README.md, rows "equilibrium acceptance",
  "what a consumer reads" and "run lengths".
- /home/cfutro/git/vesper/biosphere/notes/modelling-gap-audit.md finding 2
  (the last output year is not an equilibrium statistic).
