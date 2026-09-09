+++
id = "REQ-HYD-007"
title = "The water balance decides a basin's fate: open-water evaporation is a physical scheme with no floor, evaluated at one reference height over the resolved cycle, and runoff is the closed balance"
old_path = ["/home/cfutro/docs/world/notes/audits/carve-criterion-terms.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured 2026-08-17 on the predecessor's generated world (build `precarve-craton`,
baseline climatology), fixing what it found:

1. A floor `E_lake = max(E_penman, E_land)`, added to catch a failing estimate on 43
   basins, bound on 60.2% of land cells and decided 73% of the overflowing basins
   (1,252 of 2,543) by pinning their aridity index at exactly -1.0. It fired where the
   soil was wet (mean wetness 0.597 against 0.121), because land carried a roughness
   with median `z0` 0.521 m against open water's 1.5e-4 m, a transfer coefficient 6.4
   times larger: a smooth lake in a rough, wet, vegetated landscape genuinely
   evaporates less than the land beside it. The nesting the floor assumed holds only
   where the ground is moisture-limited. The floor also bounded the ocean validation
   from below, so the check could not fall under 1 whatever the estimate did.
2. Saturation vapour pressure was taken at the 2 m temperature and actual vapour
   pressure at the lowest model level (about 300 m). The 2 m air was 1.85 K warmer
   over land, 13.7% on `e_s`, one-signed. Evaluating every term at one reference height
   moved the ocean ratio from 1.0845 to 0.9672, with sign change; the residual is the
   method's and was not tuned to 1.
3. A humidity floor for the sub-grid dry column over a lake was worth 1 to 35 basins,
   not the 144 to 235 priced with the floor of finding 1 in place, and stays a
   Bracketed sensitivity because a floor chosen to move the answer is a knob.
4. Over a closed cycle at steady state the annual mean of `P - E` equals the runoff a
   cell generated exactly, because storage returns to where it started; clamping per
   season counts the wet season's refill twice (114.6 against 63.3 mm), and the store's
   seasonal range equalled the dry-season deficit cell by cell (median ratio 0.988).
   Negative annual `P - E` on pure land is residual non-periodicity (mean -3.1 mm/yr),
   clamped after aggregation. The lake's own seasonal rectification (a lake pushed over
   its spill by a wet season while its annual balance sits below) reached 8 of 1,752
   basins.
5. Corrections interact: two evaporation corrections worth +49 and +18 basins alone
   were worth +69 together, and a correction that lowered evaporation drove more cells
   onto the floor, so the clamp absorbed the correction. 243 basins with no catchment
   runoff at a median latitude of 70 degrees fill from their own surface (185 mm/yr
   evaporated against 269 precipitated); the discharge form
   `Q = r (C - A_spill) - (E - P) A_spill` handles them with no guard where the ratio
   form was undefined.
6. The tolerance on the criterion is set by the dominant uncertainty (the assumed
   biosphere, 3.7 to 7.1 K; dust, 10 to 20%), not by the method's smallest term.
7. Finding 8 (two more longitude-convention defects, a coupling matrix reading every
   basin's climate from its antipode) is a grid-convention class outside this area.

The evaluation interval is a second term of the same kind
(`/home/cfutro/docs/world/hydrography/notes/carve-verdict-interval.md`): the scheme is
nonlinear and carries two rectifiers, `max(R_n, 0)` and `max(e_s - e_a, 0)`, so its
per-bin mean was 1.57 times its value on annual-mean air over land; over the ocean,
where the model computes evaporation with real heat storage, the per-bin estimate ran
1.43 to 1.46 times the model in the three brightest bins and 0.89 to 0.96 in the two
dimmest, the signature of missing storage, not a constant bias. The two ends bracket
the water body's own heat capacity. The corrected overflowing set was a strict subset
of the old one (828 left, 0 entered), which is the sign check: the right-hand side of
the overflow condition is pure geometry, so raising `E` can only remove basins.

Findings 5 and 6 of the audit (the sill slope is the basin's depth; the incision
coefficient was stale) concern the retain mechanism and are dispositioned in
REQ-HYD-008.

## Why it carries

Open-water evaporation is a surface-energy and bulk-transfer calculation from the
state; the assumption that a wet surface never evaporates less than the land beside it
is a regime-dependent inference, not a bound, and any floor or clamp against another
surface's answer decides the outcome by fiat where it binds. Consistency of reference
height, the closed-cycle runoff identity, the Jensen error of a rectified nonlinear
scheme evaluated on a mean, the discharge form's freedom from a guard, and the subset
sign check are all planet-independent. B4 puts bulk aerodynamic evaporation everywhere
and gives lakes a 1-D column with ice, which is what makes the interval bracket
collapse into a state; B5 conserves water by construction; B9 resolves the stellar
cycle so overflow is a distribution rather than a mean.

## What this system must do

- Lake evaporation comes from the lake tile's own energy balance and bulk transfer with
  water's roughness at the column step (B4). Water's roughness is the open-water
  roughness decision 0016 defines once (Charnock's form with `g` explicit, its
  coefficient `Bracketed` there, joined to the smooth limit in the air viscosity of
  REQ-ATM-017); this record restates no form and no bracket end, and a roughness
  quoted as a length is refused. Air density, heat capacity and the
  vapour-to-air molar-mass ratio in the transfer scheme come from REQ-ATM-017; if a
  combination (Penman-type) form is ever used, its psychrometric constant is
  `Derived` from the column's surface pressure, `c_p` and that ratio, never quoted.
  No floor, ceiling or clamp against another surface's evaporation exists; a lint
  refuses `max(E_lake, E_land)` and its relatives.
- Every term of a transfer scheme is evaluated at one declared reference height; a
  scheme mixing heights does not assemble.
- Over a closed cycle, generated runoff equals `P - E - dS/dt` from the ledger
  (REQ-HYD-012); no per-interval clamp is applied at the cell.
- A basin overflows when its water balance at the spill says so, including a basin with
  no catchment supply whose own surface gains; the discharge form is the criterion, and
  supply includes groundwater exchange (REQ-HYD-003).
- Where any nonlinear scheme must be evaluated on a mean, the Jensen error is bounded
  from the resolved series and reported; with the lake column's heat storage on, the
  annual and per-step limits are an identity check that the column's evaporation lies
  between them.
- A monotone sign check is a test: a change that raises evaporation must leave the
  overflowing set a subset of the previous one.
- A validation of the evaporation scheme over the ocean must be able to fall below 1;
  the ocean ratio is reported as an upper bound on the scheme's accuracy inland.
- The tolerance on any basin-fate quantity is derived from the listed dominant
  uncertainty, never from the method's own residual.

## Enforced by

Lint on evaporation floors; A5 assemble check on reference heights; the M5 gate (land
`P - E` against runoff; ledgers closed at the seam); the subset identity in the
hydrology suite; the single-column lake oracle (REQ-HYD-010); the grid-convention class
is enforced by the `ter` area's records.

## References

- Natural evaporation from open water, bare soil and grass. Penman (1948), Proceedings
  of the Royal Society A 193, 120-145. DOI: 10.1098/rspa.1948.0037
- Evaporation into the Atmosphere: Theory, History, and Applications. Brutsaert (1982),
  Springer. DOI: 10.1007/978-94-017-1497-6
- Sur les fonctions convexes et les inegalites entre les valeurs moyennes. Jensen
  (1906), Acta Mathematica 30, 175-193. DOI: 10.1007/BF02418571
- Wind stress on a water surface. Charnock (1955), Quarterly Journal of the Royal
  Meteorological Society 81, 639-640. DOI: 10.1002/qj.49708135027

## Amendments

- 2026-09-08: water roughness derived from Charnock with `g` explicit and the smooth limit from REQ-ATM-017's air viscosity; air properties and any psychrometric constant pointed to REQ-ATM-017 (rows 20 and 41), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: the water roughness read from decision 0016's one definition, the restated form and bracket ends dropped, from notes/findings/2026-09-08-implicit-earth-audit.md
