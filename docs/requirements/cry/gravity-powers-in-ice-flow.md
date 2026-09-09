+++
id = "REQ-CRY-002"
title = "Gravity enters ice flow, sliding, strain heating and pressure melting at four different powers; every occurrence is explicit in the system's g, no per-metre constant hides one, and no dimensional limiter truncates the effect"
old_path = ["/home/cfutro/docs/world/notes/external-model-survey.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

`notes/external-model-survey.md` section 45 read a large thermomechanical ice-sheet model
at source: one compile-time gravity, seventeen occurrences of it, and four
different powers in the algebra. Driving stress `rho g H grad z_S` is g^1; the
shallow-ice velocity and diffusivity through Glen's creep are g^3; strain
heating, creep times stress squared, is g^4; Weertman sliding
`C tau_b^p / N^q` with p = 3 and q = 2 is g^(p-q) = g^1, so the ratio of
deformation to sliding shifts as g^2 and the mode of flow changes, not merely
its speed; the sliding coefficient carries units m a-1 Pa^-(p-q), so its
Earth-tuned value is wrong at another gravity by exactly that factor. Measured
on the predecessor's declared gravity (12.81 m s-2): 1.31x, 2.23x, 2.91x,
1.31x and 1.71x. Because strain heating outruns flow, the ice goes temperate
more readily than the velocity scaling suggests, and the enthalpy method's
corrector cost rises with the temperate fraction (45e). Two Earth gravities
appeared with no g on the line: a Clausius-Clapeyron gradient of 8.7e-4 K per
metre of ice (dTm/dp times rho_i g; 1.136e-3 K/m at that gravity), which
propagates into five derived coefficients and moves the pressure-melting
point, the cold-temperate transition and temperate drainage; and a sub-shelf
freezing gradient of 7.64e-4 K per metre of depth (dT/dp times rho_w g).
Dimensional Earth-tuned limiters on g^3 and g^4 quantities (a maximum
diffusivity of 500 m2 s-1 and a maximum velocity of 3000 m a-1) bind about 2.2
times more often at that gravity, silently truncating the effect being
studied. The rate-factor table is specific to n = 3 in units of s-1 Pa-3, so
selecting n = 4 leaves a Pa-3 table feeding a sigma^3 creep function. A
second candidate welded `(rho g)^n` with 9.8 into a module literal
(`shallow-ice-solver-cost.md`). `notes/glacier-rough-pass.md` confirmed by a
consistency check that the terrain export scaled relief as 1/g.

## Why it carries

Ice flow, sliding, strain heating, pressure melting and basal melt scale with
gravity at different powers, and a generic builder must carry every power
explicitly so that a gravity sweep (M4b) moves each term correctly and the
mode of flow is an outcome. The two failure classes are general beyond ice: a
coefficient stated per unit length that is physically per unit pressure, and
a limiter in dimensional units fitted to one planet that binds silently on
another.

## What this system must do

- Glen's law with `(rho g)^n` explicit, rho and g from `System`, and n a
  declared parameter whose rate factor carries the dimension Pa^-n s-1 so
  that a rate factor stated for one n is refused by dimension for another.
- The sliding law declares its exponents and its coefficient's dimension
  (m s-1 Pa^-(p-q)); the coefficient is `Bracketed`, and the dimension check
  enforces its gravity scaling. The field fits that set the bracket's ends were
  made where basal water pressure lowers `N` below overburden; under this system's
  overburden convention for `N` (B6, a declared absence of subglacial hydrology)
  the ends are re-read as the hard-bed and soft-bed fits under that convention and
  named as such.
- Glacial erosion's pressure limb `N^r` (B1, REQ-TER-013) reads the same `N`, its
  exponent `r` distinct from the sliding exponent `p`; the erosion coefficient's
  dimension `Pa^-r m^(1-l) s^(l-1)` is checked by the same
  dimension type, so a coefficient quoted per metre of sliding per year without its
  exponents is refused here as it is in terrain.
- Strain heating and frictional basal heating are computed from the stress
  and strain-rate fields of the solver, never through a separate
  gravity-scaled coefficient.
- The pressure-melting point and every freezing-point depression are stated
  per pascal and converted through the hydrostatic pressure at the declared
  g and the local density (REQ-OCN-003); a per-metre form is a dimension
  error.
- No dimensional limiter on diffusivity, velocity or thickness change. Where
  the explicit substep of B6 needs a bound, it is derived from the stability
  condition at the current state, and the cells where it binds are a reported
  diagnostic.
- Relief and the isostatic response scale with gravity through the physics
  (B1: strength-limited relief, flexure) and never through an export scaling.

## Enforced by

- B6 and B1 decision records; A3 dispositions.
- A2 dimension types: Pa^-n in the rate factor; per-pascal gradients; a
  sliding coefficient with the wrong power of Pa is a JET failure.
- C3 gravity identities: the Halfar timescale t0 scales as g^-n across a
  gravity sweep; the pressure-melting depth scales as 1/(rho g).
- M4b gravity sweep across the coupled cryosphere.
- Lint: no constant with dimension K m-1 in a cryosphere module.

## References

- Glen, J. W. (1955). "The creep of polycrystalline ice". Proceedings of the
  Royal Society of London A 228, 519-538. DOI: 10.1098/rspa.1955.0066.
- Weertman, J. (1957). "On the Sliding of Glaciers". Journal of Glaciology
  3(21), 33-38. DOI: to confirm.
- Greve, R. (2005). "Dynamics of ice sheets and glaciers", lecture notes, held
  (the shallow-ice formulation); Aschwanden et al. (2012), held (the enthalpy
  formulation); Cuffey and Paterson (2010), held (the Clausius-Clapeyron
  gradient per pascal). These replace the Greve and Blatter (2009) monograph,
  which is not held.
- Aschwanden, A., Bueler, E., Khroulev, C. and Blatter, H. (2012). "An
  enthalpy formulation for glaciers and ice sheets". Journal of Glaciology
  58(209), 441-457. DOI: 10.3189/2012JoG11J088.
- Cuffey, K. M. and Paterson, W. S. B. (2010). "The Physics of Glaciers", 4th
  edition. Butterworth-Heinemann. ISBN: to confirm.
- Bueler, E. and Brown, J. (2009). "Shallow shelf approximation as a "sliding
  law" in a thermomechanically coupled ice sheet model". Journal of
  Geophysical Research 114, F03008. DOI: 10.1029/2008JF001179.
- Halfar, P. (1983). "On the dynamics of the ice sheets 2". Journal of
  Geophysical Research 88(C10), 6043-6051. DOI: 10.1029/JC088iC10p06043.
  (The similarity timescale's dependence on Gamma and hence on g^3.)

## Amendments

- 2026-09-08: sliding-coefficient bracket ends re-read under the overburden convention (row 31); glacial erosion's pressure limb and coefficient dimension tied to the same `N` and dimension check (row 3), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: the glacial-erosion pressure exponent renamed `r`; the Halfar scaling stated as g^-n for the declared `n`, from notes/findings/2026-09-08-implicit-earth-audit.md
