+++
id = "REQ-TER-014"
title = "A guard on a function's domain is not a physical ceiling; every map from a state to a physical quantity is defined and monotone over the whole range the state reaches"
old_path = ["/home/cfutro/git/vesper/notes/audits/relief-curve-domain.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's `precarve-craton` and `precarve-craton-10m`
builds: the generator's land height was `6 km * s(t)` with `s(t) = t^4 (5 - 4t)`,
a Hermite interpolant whose four defining conditions all sit at the endpoints
of [0, 1]; `s'(t) < 0` above 1, the polynomial returns to zero at t = 1.25 and
is below sea level beyond, and `min(elev, 1)` guarded that inversion. Nothing
bounded the elevation parameter at 1: rank normalisation, then noise, warping,
erosion and creep all ran afterwards, and it reached 1.3687 and 1.4280, with
0.26 and 0.25 per cent of land by area (2,953 and 11,251 cells) published at
ONE height, 4.5933 km, converged across a fourfold change in region count.
Unclamped, 2,949 of 2,953 would have published below the join and 49 below sea
level: the guard was load-bearing. A linear branch `s(t) := t` above 1
introduced no new constant, was continuous at the join with the curve's own
mean gradient, and restored strict monotonicity: 2,952 distinct heights where
there had been one, maxima of 6.29 and 6.56 km, the median affected cell
gaining 239 and 206 m. Both maxima fell under Earth's maximum relief divided
by the planet's gravity ratio, a check on the branch rather than a criterion
it was chosen to meet. The change moved terrain through basin selection (108
and 390 depressions crossed the depth floor, one-directionally) because the
curve fed the selection depth. The physical ceiling on relief was a different
object in the same code, the strength argument `sigma / (rho g)` applied after
the curve; reading the domain edge as a ceiling "double-counts one and
misattributes the other". Elsewhere the generator refused to invert the same
polynomial at 0.99 with the reason recorded (NaN propagation), so the domain
was already known to it.

## Why it carries

A shaping curve with a clamp is a device of the old stack; the lesson is
general. Any map from a prognostic state to a physical quantity (a hypsometric
transform, a lookup table, a saturation function, an albedo ramp, a
smoothstep) that saturates silently collapses distinct states to one value, a
Jensen loss concentrated at the tail where the interesting terrain lives, and
gets mistaken for physics. In this design the ceiling on relief is a computed
strength process (REQ-TER-013), so there is no curve for a clamp to hide in;
the requirement is what keeps that true for every other map.

## What this system must do

- Every function mapping a state to a physical quantity declares its domain
  and is strictly monotone wherever the physics is; the range the state
  actually reaches in a run is measured and recorded on the array, and the
  function is tested over that range plus margin.
- A clamp exists only as a `Sourced` physical limit carrying its source and
  the process it stands for, or as a refusal that names the value; a silent
  `min`/`max` on a physical quantity does not exist.
- An interpolant's endpoints are interpolation nodes, never physical bounds;
  the behaviour outside the nodes is declared (extrapolation rule) and tested.
- The terrain's relief ceiling is the strength-limited relief process,
  computed; no curve caps height.
- A property test asserts, for every such map, strict monotonicity over the
  declared domain and that the count of distinct states mapped to one output
  is zero unless declared.

## Enforced by

- Lint: `min`, `max` and `clamp` on physical quantities outside a
  `Sourced`-limit wrapper are refused.
- Property tests on every state-to-quantity map, registered with the map.
- The store records observed min and max per array (A6), so the tested domain
  is the reached domain.
- M1 gate: hypsometry with a spike at one elevation fails.

## References

- Schmidt, K. M., Montgomery, D. R. (1995). "Limits to Relief". Science
  270(5236), 617-620. DOI: 10.1126/science.270.5236.617. The ceiling that is
  physical.
- Jensen, J. L. W. V. (1906). "Sur les fonctions convexes et les inegalites
  entre les valeurs moyennes". Acta Mathematica 30, 175-193.
  DOI: 10.1007/BF02418571. The collapse a saturation causes.
- Fritsch, F. N., Carlson, R. E. (1980). "Monotone Piecewise Cubic
  Interpolation". SIAM Journal on Numerical Analysis 17(2), 238-246.
  DOI: 10.1137/0717021. Interpolants that are monotone by construction.
