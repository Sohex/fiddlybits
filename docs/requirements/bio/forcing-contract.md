+++
id = "REQ-BIO-002"
title = "Forcing reaching the biosphere is a list of intervals with explicit bounds in absolute seconds, one code path for any cadence, and every field declares unit, time base, kind, area basis, sign and converting side"
old_path = ["/home/cfutro/git/vesper/biosphere/notes/ecological-forcing-field-contract.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor passed weather from a climate model to a vegetation model
through a fixed twelve-bin binary that the project itself had invented, and
audited what that cost (measured on the old world's ExoPlaSim-to-LPJ-GUESS
driver at the archived commit):

- The bins were not the calendar. The producer's bins spanned 15.08 days
  except two of 16.09, and the consumer assigned each `year_length // 12`
  days with the remainder on the last; one bin's precipitation total was
  inflated by 1.119 and another deflated by 0.932. The annual mean moved by
  0.03 percent, which is exactly why it survived: the defect was a seasonal
  redistribution of up to 12 percent, largest at the year boundary.
- Five things had each been the whole of a real defect: a unit with no
  multiplier ("1" for a percentage), a time base (rate per second, total per
  day, mean per interval are three numbers), whether a record is a mean, a
  total, an extremum or an instantaneous sample (the regular stream was a
  mean; extrema were extrema of a different variable; one accumulator was
  never reset), an area basis (ground, leaf, tile, cell), and a sign (upward
  fluxes negative, said nowhere). The sixth is which side converts, and a
  field whose row does not name a converting side is not in the contract.
- The temperature extrema shipped were extrema of the SURFACE temperature
  and were read as a diurnal AIR range; the check that caught it was that an
  extremum brackets the mean of the variable it is an extremum of and of no
  other (tas fell outside [mint, maxt] in 15561 of 24576 cell-bins, by up to
  28.3 K).
- `spd` was the speed of the interval-mean vector, one-sided low against the
  mean speed; relative humidity was a nonlinear function of interval means,
  in percent, on the wrong saturation branch below freezing. Specific humidity
  is linear and is what the atmosphere carries.
- Net surface shortwave is right for the energy balance and wrong for the
  photon supply, because it has already had the canopy's own reflection
  removed at the albedo the atmosphere ran with; incident, upward and net must
  travel separately.
- Precipitation phase was rederived by the consumer at 0 C from a daily mean,
  turning a mixed interval into all one phase, while the producer already
  resolved it.
- The replacement transport carried a table of intervals with explicit start,
  end and duration in absolute seconds plus the local solar phase and orbital
  position of each, any count, and the consumer took each of its own steps'
  duration-weighted mean over the overlapping intervals; twelve intervals a
  year, one per day and one per atmospheric timestep became one code path,
  and the integration is the identity when an interval equals the step.
- Chronology matters: interception, snow, drought stress, phenology, fire
  weather and lightning cannot be reconstructed from independent monthly
  means (Richardson 1981 conditioned temperature and radiation on the wet or
  dry state for that reason), and a smooth curve manufactured between bin
  centres has no source, since the producer states an interval mean and
  nothing about the shape inside it.
- When a block of forcing was replayed to cover a spin-up longer than the
  archive, the seam, the block length, the choice of block and the order of
  orbits within it were each pre-registered tests with a bar of one fifth of
  the smallest effect to be resolved; an Earth-trained weather generator and
  Earth bias correction were refused outright.

## Why it carries

The seam moves but does not vanish. In one process (A5) the atmosphere, the
land column and the vegetation still run on different tiers with different
call intervals (B9 and 0023: fast; the daily tier on the mean solar day of the
dominant source, with a `Bracketed` fallback where that is undefined; orbital;
slow), so
every crossing is an interval reduction, and B9's slow tier accumulates climate
statistics over the statistics window of 0023, which is a replay
of a block by another name. The eight identities that can fail are what
separates a transport that carries agreed bytes from one that carries agreed
meanings, and they are cheap. The requirement is A2 (semantics and time
semantics on the `Field` type) and A5 (`Exchange` objects close ledgers at every
boundary) stated for the biosphere's inputs.

## What this system must do

1. Every quantity handed to the biosphere tier is a `Field` on a declared list
   of `Interval{t0, t1}` in SI seconds (A4) with both bounds and the duration
   carried, never inferred from a record index. Any cadence takes one code
   path: the consumer forms its own step's duration-weighted mean (intensive)
   or sum (extensive) over the overlapping intervals, and that operator is the
   identity when the interval equals the step.
2. Each field's contract row states unit with multiplier, time base, kind
   (interval mean, interval integral, extremum, instantaneous), area basis
   (ground, leaf, tile, cell), sign convention and converting side. The
   `Field` type carries the first four; the refusal table refuses a reduction
   whose kind is unknown.
3. The atmosphere supplies: incident, upward and net shortwave per band the
   canopy declares (REQ-BIO-003), net and upward longwave, near-surface air
   temperature with its interval extrema, surface temperature with its own
   extrema named apart, pressure, specific humidity (never relative
   humidity), wind speed accumulated as a speed at every fast step (never the
   speed of the mean vector), total precipitation with phase and convective
   partition from the atmosphere's own microphysics, lightning potential
   synchronous with convective precipitation (REQ-BIO-015), and per interval
   the orbital phase and local solar phase derived from the bounds and
   `System`. The land column (B4) supplies its state per REQ-BIO-019.
4. Identities that can fail are checked on every exchange: the phase and
   convective partitions close on the total; every component is non-negative;
   incident minus upward equals net and both are non-negative; each extremum
   brackets the mean of its own variable and is not required to bracket any
   other; the intervals tile the block with no gap or overlap; the consumer's
   per-step series reproduces the producer's per-interval values; every
   declared field is present, finite and on the declared support, and no
   undeclared field is present.
5. Nonlinear processes on the daily tier's step (0023) (interception, snow,
   drought, phenology, fire) are never driven by a climatological mean; they
   read the chronological sequence. Where any tier replays a block (slow-tier
   statistics, an accelerated segment), the seam is tested by phasing the
   replay, the block length is swept, the between-block spread is reported as
   construction uncertainty, and an orbit is never split; a stellar cycle is
   replayed whole in physical order.
6. A weather generator trained on another planet's observations and a bias
   correction toward another planet's distribution are refused as inputs; a
   generator trained on this system's own accepted stream is admissible only
   as a labelled fallback validated on held-out data for spell lengths,
   amounts, extrema, serial and cross-variable dependence.

## Enforced by

- Type: `Field{S,T,D,L,A}` time semantics (A2); `Interval` (A4); `Exchange`
  ledgers (A5); the refusal table and its enumeration test.
- Fixtures built to be wrong in a named way (an extremum of the wrong
  variable, a rate read as a total, an overlapping interval, a sign flip), each
  of which must get the verdict it was built for.
- Oracle: constant-field and extensive-integral preservation across any
  cadence (C3 mesh and time identities); the replay seam test as a registered
  threshold before the first accelerated segment runs.
- Decision records for A2, A4, A5 and B9.

## References

- Richardson, C. W. (1981). Stochastic simulation of daily precipitation,
  temperature, and solar radiation. Water Resources Research 17, 182-190.
  DOI: 10.1029/WR017i001p00182. Why cross-variable and serial dependence
  must be preserved.
- Gerten, D., Schaphoff, S., Haberlandt, U., Lucht, W. and Sitch, S. (2004).
  Terrestrial vegetation and water balance - hydrological evaluation of a
  dynamic global vegetation model. Journal of Hydrology 286, 249-270.
  DOI: 10.1016/j.jhydrol.2003.09.029. Interception, soil water and runoff do
  not respond to a monthly total as if its timing were irrelevant.
- Sitch, S. et al. (2003). Evaluation of ecosystem dynamics, plant geography
  and terrestrial carbon cycling in the LPJ dynamic global vegetation model.
  Global Change Biology 9, 161-185. DOI: 10.1046/j.1365-2486.2003.00569.x.
  Interannually varying spin-up climate is required because fire and
  water-limited responses occur in dry years.
- /home/cfutro/git/vesper/biosphere/notes/ecological-climate-forcing-audit.md
  (the finding that the bin count was scaffolding and cadence follows
  processes).
- /home/cfutro/git/vesper/biosphere/notes/forcing-replay-preregistration.md
  (the seam, ladder, alternative-block and reordering tests and the generator
  prohibitions).

## Amendments

- 2026-09-08: cadence wording replaced by the tiers of 0023 (daily tier on the
  mean solar day of the dominant source with a Bracketed fallback), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: the slow tier's statistics accumulate over the statistics window of 0023, from notes/findings/2026-09-08-implicit-earth-audit.md
