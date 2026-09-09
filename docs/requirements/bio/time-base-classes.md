+++
id = "REQ-BIO-001"
title = "Every biological rate carries a declared time-base class, and a physical-kinetic rate is never rescaled to the planet's day or orbit"
old_path = ["/home/cfutro/docs/world/biosphere/notes/time-base-unit-contract.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Every rate in a vegetation model calibrated on Earth is published per day or per
year, and on Earth the calibration day, the solar day, 86400 s and the orbit
coincide, so a published number does not say which of them it meant. The
predecessor project found this out by porting an Earth vegetation model to a
configuration whose rotation was 30 h and whose orbit was about half an Earth
year (measured on the old world's port of LPJ-GUESS-CNP at the archived
commit). What it recorded:

- The same symbol was read in two units in one binary: a leaf lifespan was
  simulation years where growth read it and Earth years where a regression
  fitted in absolute months read it. A unit declared only at the declaration
  cannot catch that; the registry it built names the file where each quantity
  is READ.
- Four classes were needed and no fewer: absolute-rate (decomposition,
  deposition, weathering, a mortality hazard, tissue turnover), annual-sum
  (degree-day thresholds, annual production per unit leaf area), seasonal-cycle
  (leaf-out, an establishment attempt, a count of orbits used to smooth
  interannual variation), and diagnostic. Only the class decides the
  conversion.
- A fraction is not a rate. A fraction r per interval T1 becomes
  1 - (1 - r)^(T2/T1) per interval T2, which leaves 1.0 at 1.0; a linear
  multiplier quietly turns "all of it" into "half of it". A duration in years
  scales the reciprocal way from an annual sum, so confusing the directions is
  worse than doing neither.
- The fire operator's burned fraction, a fitted output per Earth year, was
  applied to a 183-day model year and burned 1.996 times too fast per unit
  absolute time, while the ARGUMENT going in needed no conversion because it
  was a mean daily probability. A per-Earth-year rate converts; an
  absolute-time threshold that happens to be quoted per Earth month
  (a leaching threshold in cm per month) must not.
- Two other models carry the same ambiguity by construction: FATES holds
  365.0 as a compile-time constant in 146 places and the host's year in 21, and
  the two meet inside one process (cohort density decremented on one, litter
  from those deaths on the other), a mass-balance defect unreachable on Earth;
  a fire danger accumulator adds once per model day with no rate constant, so
  its magnitude scales with days per year; a one-day fire duration is anchored
  to a diurnal drying cycle rather than to a count (measured in
  /home/cfutro/docs/world/notes/external-model-survey.md sections 51 and 54).
- The port chose 24-hour steps rather than the planet's solar day so that per-day
  physiological and chemical rates kept the absolute time they were calibrated
  against, confining the rotation error to daylength, where it has a known
  sign. That choice was verified: annual evapotranspiration on identical
  forcing fell to 0.492 of the unpatched value against an expected 0.496.

## Why it carries

A generic builder declares any rotation and any orbit (A0, A4), so the
coincidence that hides the ambiguity on Earth is gone for every configuration
it runs. Every rate taken from an Earth source must therefore be classified
before it is used, and the class is a property of the mechanism, not of the
number: physics and chemistry do not know the orbit, while a phenological event
does. This is A4 (one clock in SI seconds; day and orbit are pure functions of
the System) applied to biology, and it is the reason B9 runs vegetation growth,
fire and routing on the planet's own day while decomposition runs in SI time.

## What this system must do

1. Every rate constant, threshold, duration or accumulation in the biosphere
   carries exactly one time-base class in its parameter struct, and the class is
   a type, not a comment:
   - `PhysicalKinetic`: a rate per SI second (decomposition, gas diffusion,
     sorption, weathering, a mortality hazard, tissue turnover). Stored per
     second. The 86400 s in a published per-day value is a unit conversion
     performed once, and the stored rate is never rescaled to the planet's day
     or orbit.
   - `BiologicallyEntrained`: a rate or integral whose calibration assumes a
     24-hour light/dark cycle because the mechanism follows the cycle (the
     daily photosynthetic integral, dark respiration over the night, a fire
     duration anchored to a diurnal drying cycle). Such a quantity carries the
     planet's rotation period explicitly (B4 resolves the planet's day) and the
     decision of how it follows the cycle is a Bracketed model-form choice
     recorded at the constant; it is a modelling decision, never a silent
     multiplier.
   - `AccumulatedSum`: a threshold on an integral over an interval named on the
     clock (a degree-day sum over one orbit). Stored as an integral with the
     interval it was accumulated over.
   - `SeasonalEvent`: happens once at the seasonal event the orbital tier fires (0023)
     by mechanism (leaf shedding, an establishment attempt, a memory expressed as a
     count of orbits). Unchanged under a change of orbit length. A hazard that is
     applied at the event (mortality) is a `PhysicalKinetic` rate per second
     integrated over the interval since the last event, never a fraction per orbit.
   - `NotTemporal`: a temperature limit, a stoichiometric ratio, a shape
     parameter.
2. A fraction per interval converts by 1 - (1 - r)^(T2/T1); a duration scales
   inversely to a sum; the conversion functions are the only place the
   arithmetic lives.
3. No literal 365, 24, 86400 or 12 appears in a biosphere module outside a
   unit-conversion denominator quarantined in `EarthRatios` (A3). Day, solar
   day and orbit are read from `System`.
4. A quantity crossing from another tier or component carries its time
   semantics in the `Field` type (A2) so a per-second flux cannot be integrated
   over the wrong interval and an interval mean cannot be read as a total.
5. Every published calibration adopted into the strategy space (REQ-BIO-006)
   records the calibration interval it was measured over, so its class can be
   assigned from the source rather than from the symbol name.
6. The classes apply beyond the biosphere to every pedology, aeolian and
   surface-class threshold (REQ-PED-001, REQ-PED-009, REQ-PED-011): a deposition,
   precipitation or denudation threshold quoted per Earth year or per Earth month
   is `PhysicalKinetic`, stored per second and converted once; only a threshold
   whose mechanism is seasonal is `AccumulatedSum` or `SeasonalEvent`, and the
   record that adopts it says which.

## Enforced by

- Type: a `TimeClass` type parameter on the biosphere parameter struct; the
  `Field` time-semantics parameter; a refusal table entry for integrating an
  intensive field without a duration.
- Lint: bare 365, 24, 86400 and 12 literals banned in biosphere modules except
  inside `EarthRatios`; `Dates` banned from physics modules (A4).
- Unit test: the fraction conversion leaves 1.0 at 1.0 and reduces to the
  linear form for small r; the duration and sum conversions are reciprocal.
- Oracle: the same biosphere run at two declared rotation periods on identical
  absolute-time forcing changes only `BiologicallyEntrained` quantities; the
  same run at two orbit lengths changes only `AccumulatedSum` and
  `SeasonalEvent` quantities. The C4 mutation run flips one class and must be
  caught.

## References

- Haxeltine, A. and Prentice, I. C. (1996). A general model for the light-use
  efficiency of primary production. Functional Ecology 10, 551-561.
  DOI: 10.2307/2390165. The daily integral whose 24-hour assumption is the
  canonical `BiologicallyEntrained` case.
- Thonicke, K., Venevsky, S., Sitch, S. and Cramer, W. (2001). The role of fire
  disturbance for global vegetation dynamics: coupling fire into a Dynamic
  Global Vegetation Model. Global Ecology and Biogeography 10, 661-677.
  DOI: to confirm. Equation 9, a burned fraction per Earth year whose argument is
  scale-invariant.
- Li, F., Zeng, X. D. and Levis, S. (2012). A process-based fire
  parameterization of intermediate complexity in a Dynamic Global Vegetation
  Model. Biogeosciences 9, 2761-2780. DOI: 10.5194/bg-9-2761-2012. The one-day
  fire duration anchored to a diurnal cycle.
- Sitch, S. et al. (2003). Evaluation of ecosystem dynamics, plant geography
  and terrestrial carbon cycling in the LPJ dynamic global vegetation model.
  Global Change Biology 9, 161-185. DOI: 10.1046/j.1365-2486.2003.00569.x.
  The per-year mortality and turnover conventions the ambiguity lives in.
- /home/cfutro/docs/world/notes/external-model-survey.md sections 51 and 54
  (the FATES two-calendar defect; the Nesterov per-day accumulator).
- /home/cfutro/docs/world/biosphere/notes/lpj-guess-porting-audit.md (the
  24-hour-step decision and its verification).

## Amendments

- 2026-09-08: SeasonalEvent wording moved to the orbital tier of 0023 and the
  mortality hazard made a per-second rate integrated to the event (audit row
  34), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: item 6 extends the time-base classes to pedology, aeolian and
  surface-class thresholds (audit row 38), from
  notes/findings/2026-09-08-implicit-earth-audit.md
