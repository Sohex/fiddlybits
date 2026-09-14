+++
id = "REQ-OCN-005"
title = "Coupled atmosphere-ocean equilibrium is declared before the run on named axes: heat transport change, ocean heat inventory, SST and ice change, atmospheric storage, freshwater and salt closure, basin-classification stability"
old_path = ["/home/cfutro/git/vesper/ocean/config/transport_loop.yaml"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor declared the exit of its atmosphere-ocean loop before the
first pass, in `transport_loop.yaml`, as eight criteria each with a statistic,
a threshold and a derivation: the ocean-area-weighted RMS change in heat
transport (0.12 W m-2, derived from the atmosphere's storage threshold as the
largest unresolved forcing consistent with its remaining-offset allowance);
the absolute ocean-area mean of the transport convergence (1e-4 W m-2, the
resolution of the verified channel, over ocean area and never the globe); the
global ocean mean SST change (0.15 K); the planetary sea-ice area fraction
change (0.001); atmospheric energy storage (0.12 W m-2); freshwater and salt
inventory residuals (1e-10 of throughput and of inventory, float64
conservation identities one order looser than the remap bar); and the count of
drainage basins whose downstream classification changed (zero), because "the
loop has not settled the decision it feeds while any basin changes class". The
form: all criteria pass on two consecutive pass pairs; uncertainty as the
statistic plus its standard error below threshold; a maximum iteration count
whose exhaustion refuses and carries an unconverged bracket rather than a
value.

The channel verification behind those numbers (`ocean-and-marine-biosphere.md`
section 11) checked the instrument against synthetic streams that satisfy
every criterion and against each criterion broken in one named way, and found
that a tolerance stated as a fraction of the largest change with no floor
reported the storage format rather than the model on small windows (11g).
Section 8f: a plausible global productivity total cannot compensate for a
leaking or resolution-dependent ocean.

## Why it carries

Synchronous coupling (B3) removes the outer loop but not the question of when
the coupled state is at equilibrium, and the axes are properties of the
coupled system on any planet: the partition of poleward transport, the drift
of ocean heat content, the drift of the surface and ice state, the atmosphere's
storage, closed water and salt budgets, and the stability of the categorical
decisions downstream. B9 declares exit criteria before the run; this record
supplies the ocean's axes and the rules that make them criteria rather than
habits: every threshold derived from an instrument resolution or a downstream
tolerance, a floor above quantisation, autocorrelation-corrected errors,
categorical stability counted rather than averaged, and integrals evaluated on
the support they act on.

## What this system must do

- The coupled exit predicate (B9, via A5 `FixedPointLoop` and `Ladder`)
  evaluates at least: (1) the change in meridional ocean heat transport and
  in the atmosphere-ocean partition between successive windows; (2) ocean
  heat inventory drift, deep and full column, in FP64 accumulators; (3) global
  ocean mean SST change; (4) sea-ice area and volume change; (5) atmospheric
  energy storage; (6) the freshwater inventory residual and (7) the salt
  inventory residual as float-derived closure identities; (8) stability of the
  categorical state downstream: drainage terminals, the exorheic share, and
  the topology of the connectivity graph (REQ-OCN-009), counted as events.
- Each threshold is registered before the run with its derivation: an
  instrument's resolution, a downstream consumer's tolerance, or a float
  identity. A threshold with no floor above the storage quantisation of the
  quantity it judges is refused.
- Statistics carry autocorrelation-corrected standard errors (idea 10), and
  the verdict is one of `Converged | Bracketed | Refused | NotEvaluable`; an
  unconverged run carries its bracket rather than a value, and an `Antitone`
  loop cannot say `Converged`.
- Integral criteria state the support they hold on (ocean wet area versus the
  globe).
- The exit instrument is checked against synthetic states that satisfy every
  criterion and that break each in one named way before it judges any run.
- A finalizer re-evaluates every exit at the final state (A5).

## Enforced by

- B9 and A5 decision records; A10 profiles carrying the exit brackets.
- Oracle registry entries for each axis with `provisional = true` until
  registered at the milestone's start (C2, Part D).
- C6: the per-commit short coupled case whose state hash changes only with an
  `answers:` line.
- C4 mutation run against the exit instrument.
- M6, M7 and M8 gates: TOA and surface balance over an
  autocorrelation-corrected window, deep-ocean drift, ice volume drift, every
  ledger inside tolerance, every loop exit evaluable.

## References

- Bryan, K. (1984). "Accelerating the Convergence to Equilibrium of
  Ocean-Climate Models". Journal of Physical Oceanography 14, 666-673.
  DOI: to confirm. (What equilibrium of the deep ocean means and how it is
  approached.)
- Trenberth, K. E. and Caron, J. M. (2001). "Estimates of Meridional
  Atmosphere and Ocean Heat Transports". Journal of Climate 14, 3433-3443.
  DOI: to confirm. (The Earth oracle for the transport partition and its
  uncertainty, the bar for a distance report.)
- Griffies, S. M. et al. (2016). "OMIP contribution to CMIP6: experimental and
  diagnostic protocol for the physical component of the Ocean Model
  Intercomparison Project". Geoscientific Model Development 9, 3231-3296.
  DOI: 10.5194/gmd-9-3231-2016. (Heat, freshwater and salt inventory
  diagnostics and drift conventions.)
- Zwiers, F. W. and von Storch, H. (1995). "Taking Serial Correlation into Account
  in Tests of the Mean". Journal of Climate 8, 336-351. DOI:
  10.1175/1520-0442(1995)008<0336:TSCIAI>2.0.CO;2. Held. (Effective sample size
  under autocorrelation; with von Storch and Zwiers 1999 and Sokal 1997, both held,
  this replaces the Wilks textbook citation, which carried nothing the requirement
  takes.)
