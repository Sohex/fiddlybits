+++
id = "REQ-TER-007"
title = "A nonlinear law is evaluated on the fine support and reduced afterward; a conservation gate cannot see this loss, and refinement does not remove it"
old_path = ["/home/cfutro/docs/world/notes/audits/nonlinear-spatial-reductions.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's `precarve-craton-10m` and `canonical-10m-base`
builds at every truncation from T21 to T170, each case judged against the
instrument its own consuming step already declared. A regolith depth law
`depth = max * P / (P + E)`, convex in the erodibility (a rock property
spanning a factor of fourteen in the class table), evaluated once on the
area-mixed erodibility gave a land-mean gap of 0.19 to 0.28 m against a 0.02 m
bar on 63 to 87 per cent of land area, one-signed at every ratio and every
truncation, and refinement from T21 to T170 shrank it by only 1.5x, leaving
9.4 times the bar at the finest. A surface roughness averaged as a length,
where the model consumed `ce = k^2 / ln(z_ref/z0)^2` and the flux is linear in
`ce`, was -10.3 to -8.1 per cent at the land mean against a 5.1 per cent
instrument and -24 per cent in the top decile of barren share, the flat basin
floors whose evaporation a verdict integrated; the operator that fixed it
reduces in `ce` at the blending height. A dry and a saturated albedo, each an
exact area mean, mixed per cell through a law concave in the pair, cost 0.147
W m-2 of global absorbed shortwave against a 0.12 W m-2 bar, peaking on the
model's own evaporation knee; the pre-registered repair (stage in the
transform the mixing is linear in) was a hundred times worse, because the two
staged fields are pinned at the ends of the saturation axis by boundary
conditions, and the repair that cleared the bar was a third exact area mean at
the knee. A coefficient relating within-cell relief to roughness, solved per
grid, moved by 1.98x across the ladder because the relation was linear in
relief amplitude where the physics is quadratic in slope, so the coefficient
carried the cell size inside itself; derived from slope with no constant, the
land mean spread 0.9 per cent end to end. Two candidates were not defects:
texture-through-weathering was affine wherever a clip did not bind (gap
exactly 0.0), and a geometric mean of roughness was exact for a drag partition
affine in ln z0, though the reason given for it generalised wrongly to the
exchange coefficient. Pre-registered sign invariants held on the population
and failed on 0.14 to 0.47 per cent of mixed cells, reported rather than
rounded. And, from the land-mosaic audit: "a gate that asks only for
conservation cannot see this loss, because the affine quantity passes it
exactly".

## Why it carries

This is Jensen's inequality, and it is the reduction-across-scales problem the
plan lists as not eliminated by design. With one hierarchy, every coarsening of
a quantity that feeds a nonlinear law faces it; refinement reduces it and does
not remove it; the sign of the curvature is not always pre-registrable; and the
evidence names both the right operator (the expectation of the law over the
fine cells, or the distribution) and the wrong repairs. The lesson that a
coefficient carrying a cell size is a closure in disguise is what the `Closure`
disposition (decision A3) exists for.

## What this system must do

- Every field declares its nonlinear order (`not_applicable |
  process_then_aggregate | aggregate_then_process`) and the operator; the
  attribute is required, never defaulted.
- A coarse-level parameter consumed by a nonlinear law is the expectation of
  the law over the fine cells, or a distribution (REQ-TER-009), never the law
  evaluated at the mean, unless the reduction is proven affine and the proof
  (including the clip bounds it depends on) is declared with the field.
- A coefficient relating a within-cell statistic to a process is dimensionally
  explicit (a slope variance, not a relief amplitude times a per-level
  constant); a coefficient that moves with the level is a `Closure` and must
  be swept across at least two levels with a convergence oracle (A3).
- Orographic drag reads the hierarchy's exact sub-grid slope statistics (B2);
  the exchange-coefficient reduction is taken in the coefficient at the
  blending height (B4).
- Each case is judged against the instrument of its consumer; a sign invariant
  is pre-registered, and the test reports violations rather than rounding them
  away.
- A repair is priced against the same truth before it is adopted; an invariant
  that fails moves the repair, not the bar.

## Enforced by

- The operator-order required test (REQ-TER-004) with its identical-inputs
  control.
- Store refusal on a missing `nonlinear_order` attribute (A6).
- A3 `Closure` two-level sweep with convergence-with-level oracle.
- M1 gate: scale-matched hypsometry and denudation-versus-relief across two
  levels.

## References

- Jensen, J. L. W. V. (1906). "Sur les fonctions convexes et les inegalites
  entre les valeurs moyennes". Acta Mathematica 30, 175-193.
  DOI: 10.1007/BF02418571.
- Mason, P. J. (1988). "The formation of areally-averaged roughness lengths".
  Quarterly Journal of the Royal Meteorological Society 114, 399-420.
  DOI: 10.1002/qj.49711448007. The blending height.
- Wood, N., Mason, P. (1993). "The pressure force induced by neutral, turbulent
  flow over hills". Quarterly Journal of the Royal Meteorological Society 119,
  1233-1267. DOI: to confirm.
- Beljaars, A. C. M., Brown, A. R., Wood, N. (2004). "A new parametrization of
  turbulent orographic form drag". Quarterly Journal of the Royal
  Meteorological Society 130, 1327-1347. DOI: 10.1256/qj.03.73.
- Marticorena, B., Bergametti, G. (1995). "Modeling the atmospheric dust cycle:
  1. Design of a soil-derived dust emission scheme". Journal of Geophysical
  Research 100(D8), 16415-16430. DOI: 10.1029/95JD00690. The affine case.
- Sadeghi, M., Jones, S. B., Philpot, W. D. (2015). "A linear physically-based
  model for remote sensing of soil moisture using short wave infrared bands".
  Remote Sensing of Environment 164, 66-76. DOI: 10.1016/j.rse.2015.04.007. The
  concave mixing.
- The two-flux reflectance theory the concave mixing rests on originates in
  Kubelka and Munk (1931), Zeitschrift fuer technische Physik 12, 593-601, which
  is not held: Sadeghi et al. (2015), held and read, restates the two-flux form
  this record uses, and the requirement takes nothing from the original.
