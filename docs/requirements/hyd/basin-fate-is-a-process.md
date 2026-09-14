+++
id = "REQ-HYD-008"
title = "Basin fate is a slow incision process integrated against a fast climate: the verdict map is antitone, the cut is irreversible, and an Earth density of standing through-flowing lakes is the report metric"
old_path = ["/home/cfutro/git/vesper/notes/audits/carve-overshoot.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor decided which closed basins to cut open as a verdict, handed the set
to its terrain generator, and iterated. Written 2026-08-24 against that loop:

- The verdict map is antitone in the carve set. Carving removes closed-basin fill, the
  brightest lithology on that world, so the land darkens, the world warms, open-water
  evaporation rises, and marginal basins that would have carved now stay closed. A
  larger carve set produces a smaller next verdict; successive verdicts alternate
  around a fixed point rather than approaching it.
- The loop exited by carving the intersection of verdicts taken at two bounding
  vegetation surfaces. An overshooting basin is one both arms cut, so it is never in
  the bracketed set: the bracket width carried no information about the carve's own
  feedback, in either direction, and reporting it as the uncertainty understated it by
  whatever the overshoot was. A bracket over one uncertainty axis is not a bound on
  another.
- The measurement that isolates the feedback holds the geometry still and moves only
  the climate: re-take the verdict on the pre-carve basin set under the carved build's
  climate, both arms, one-signed (an undershoot means something else moved). It could
  not be run because no verdict had yet been taken in the lineage. The one prior input
  measurement: a carve dropped closed-basin fill from 20.9% to 12.7% of land.
- Ties break toward not carving, because a basin carved in error has removed a
  depression from the terrain everything else is built on.

The retain mechanism the verdict carried is in
`/home/cfutro/git/vesper/hydrography/notes/retain-fraction.md`, and its findings are
evidence rather than a design: the retain once encoded the project's own uncertainty
and handed it to a landscape; it was replaced by an incision length,
`cut = C * erodibility * (S / S_ref)^n * Q^0.5`, over the depth at spill, with `C`
absorbing an incision coefficient and an undefined relaxation window because the
generator had no time axis. `C` was solved every run against Earth's density of
standing through-flowing impounded lakes (HydroLAKES natural lakes, mean depth above
5 m, pour point in a HydroBASINS level-5 basin a river crosses, within 35 degrees of
the equator, above 1,000 km2: 15 lakes over 77 Mkm2), because how many basins overflow
is a property of the climate and a literal cannot follow it (161 became 235.9 when the
verdict moved). The survivor edge (the minimum of depth over root discharge across
standing lakes) measured how recently a rift floor last dropped, not how slowly a sill
cuts, and was refused; the size class decided the density by a factor of 300 (495
lakes above 10 km2 against 15 above 1,000), and the size floor was a larger lever on
`C` (factor 8.2) than the Poisson error of the count (1.8). The expressed erodibility
contrast across a mountain belt (about a factor of 4, Zondervan et al.) is the one to
apply, not the intact-rock range (five orders, Stock and Montgomery). The outlet
channel's gradient correlates with the basin's depth (r = 0.735, exponent 1.04), so at
`n = 1` the depth cancels; a gravity factor on `C` and the slope exponent are one
question (`g^(1-n)`) and cannot be settled separately. The model carved the rift lakes
because it has no subsidence term: the density was matched, the identity of survivors
was not. The seasonal concavity of `Q^m` on an annual overflow was bounded by the bin
weights alone (`phi` in `[w_min^(1-m), 1]`), with a common level absorbed exactly by
the calibration, because the delivery phase was a declared absence.

## Why it carries

The verdict, the retain fraction, the intersection bracket and the Earth-calibrated
coefficient are a closure for a missing clock and are superseded: B1 makes incision a
process with `K` in SI on the surface clock, a sill incised only by overflow discharge,
and B5 reads the overflow discharge and the time fraction spent overflowing across the
stellar-cycle sample. What carries is what that process must respect: the feedback is
antitone and the cut is irreversible, so the slow tier cannot exit on a bracket over a
different axis and cannot apply a set; the Earth comparison survives as a REPORT metric
with the size-class and survivor-edge lessons; the erodibility contrast that enters
`k_e` is the expressed one; gravity enters once, through `K` in the incision law of
B1; and the concavity bound is unnecessary once overflow is a resolved series.
A5 says an antitone loop cannot say "converged"; B9 gives the stationarity exits.

## What this system must do

- Sill incision is integrated on the surface clock from the resolved overflow series
  with the incision law defined once in 0015, `dz/dt = U - K Q^m S^n` with
  `K = rho_w g k_e`, applied on the outlet channel below the saddle with `Q` the
  overflow (including groundwater exchange) and its time fraction over the statistics
  window of 0023; the law is not restated here. No verdict, no
  retain fraction, no coefficient solved against Earth counts, no bracket applied as
  a set.
- The slow tier's step and the climate-refresh criterion (B9) bound how much any basin's
  rim can be cut between refreshes, so the antitone feedback is resolved rather than
  bracketed; the loop exit includes re-evaluating the already-incised set under the
  refreshed climate and reporting the overshoot in the same currency (basins, area) as
  any bracket; lake area and closed-drainage share stationarity are exit criteria.
- `k_e`, `theta = m/n` and `n` are the `Bracketed` values of 0015, `m` its `Derived`
  one. There is no separate gravity factor on the coefficient: `K = rho_w g k_e`
  carries gravity exactly once, and the `g^(-1/n)` scaling of steady relief, and so
  of the sill's slope, is the C3 oracle's prediction, not an input. The predecessor's
  `g^(1-n)` factor belonged to its dimensionless slope `(S / S_ref)^n` with relief
  pre-scaled by gravity; on a physical slope in SI it would count gravity twice, so
  it is deleted rather than carried.
- Earth REPORT metric: the density of standing through-flowing impounded lakes per
  unit land, counted at a size class matched to the terrain level's resolvable
  depression size, with its Poisson bracket, never the survivor edge; the absence of
  tectonic subsidence is a declared absence, so identity mismatch on rift lakes is
  expected and stated.
- Uncertainty resolves toward not cutting within a step.

## Enforced by

B1 and B5 decision records; the stream-power steady-profile and relief-scaling
oracles (C3, M1); the M8 requirement that every loop exit be evaluable; the oracle
registry REPORT entry; C5: no interface exists through which a basin set can be applied
to the terrain.

## References

- A very efficient O(n), implicit and parallel method to solve the stream power
  equation governing fluvial incision and landscape evolution. Braun, Willett (2013),
  Geomorphology 180-181, 170-179. DOI: 10.1016/j.geomorph.2012.10.008
- Dynamics of the stream-power river incision model: Implications for height limits of
  mountain ranges, landscape response timescales, and research needs. Whipple, Tucker
  (1999), Journal of Geophysical Research 104, 17661-17674. DOI: 10.1029/1999JB900120
- Geologic constraints on bedrock river incision using the stream power law. Stock,
  Montgomery (1999), Journal of Geophysical Research 104, 4983-4993.
  DOI: 10.1029/98JB02139
- Rock strength and structural controls on fluvial erodibility: Implications for
  drainage divide mobility in a collisional mountain belt. Zondervan, Stokes, Boulton,
  Telfer, Mather (2020), Earth and Planetary Science Letters 538, 116221.
  DOI: to confirm (10.1016/j.epsl.2020.116221 believed)
- Estimating the volume and age of water stored in global lakes using a geo-statistical
  approach. Messager et al. (2016), Nature Communications 7, 13603.
  DOI: 10.1038/ncomms13603
- Global river hydrography and network routing: baseline data and new approaches to
  study the world's large river systems. Lehner, Grill (2013), Hydrological Processes
  27, 2171-2186. DOI: 10.1002/hyp.9740

## Amendments

- 2026-09-08: sill incision pointed to the single incision law of 0015 and the `g^(1-n)` clause deleted, with the explanation that `K` carries gravity once and `g^(-1/n)` relief scaling is the oracle (row 4), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: the overflow time fraction taken over the statistics window of 0023, from notes/findings/2026-09-08-implicit-earth-audit.md
