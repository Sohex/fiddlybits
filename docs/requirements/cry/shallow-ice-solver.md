+++
id = "REQ-CRY-001"
title = "Shallow-ice flow on the mesh: the full surface gradient reconstructed, volume conserved by antisymmetric face fluxes, the margin solved as an active set, convergence declared on the nonlinear residual, and the Halfar dome as the exact test"
old_path = ["/home/cfutro/docs/world/notes/audits/shallow-ice-solver-cost.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

`notes/audits/shallow-ice-solver-cost.md` and the instrument it reports,
`analysis/shallow_ice_route_a.py`, measured on synthetic 20,000- and
80,000-region jittered-Fibonacci Voronoi meshes at the predecessor's declared
radius and gravity, with a 3000 m, 2500 km Halfar dome and criteria fixed
before the prototype existed:

- The diffusivity `D = Gamma H^(n+2) |grad z_S|^(n-1)` evaluated from the
  two-point (normal-only) face slope makes the Picard map non-contractive:
  undamped it diverges at every step size, the relative residual oscillating
  with growing amplitude (1.65e-3, 1.18e-3, 1.62e-3, 9.89e-4, 2.99e-3,
  1.04e-3, 4.93e-3 over seven passes) while the thickness step fell, so a
  step-size bar would have called the failure convergence. With a
  cell-centred least-squares gradient (the full slope) the same operator on
  the same mesh converges undamped in 7 and 5 passes at the explicit step.
  Damping at 0.5 recovers the normal-only arm (16 to 24 passes) and buys a
  step twenty times the explicit limit for both (21 to 49 passes); damping
  where it is not needed costs 20 passes against 7, so the disposition is a
  line search rather than a fixed weight.
- Volume changed by 0.0 to the last reported digit in all sixteen arms, by
  construction: the face fluxes are antisymmetric and the assembled
  operator's row sums are zero, so the implicit step conserves the sum of
  area times thickness; only the active set's clip could break it and it did
  not fire.
- The margin radius landed 0.35 to 0.91 cells beyond Halfar's closed form
  `R(t) = R0 (t/t0)^(1/18)`; the profile's relative RMS was 1.3 to 1.6 per
  cent at 20,000 regions and 0.20 to 0.23 per cent at 80,000, an order better
  for four times the cells, although the operator's own truncation error on
  that mesh family (12 per cent) had been measured not to converge with
  refinement.
- The gradient reconstruction was checked against an identity before it was
  quoted: `|grad(R cos theta)| = sin theta` on the sphere, reproduced to a
  median 0.30 per cent.
- The free boundary `H >= 0` handled as an active set (pin negatives,
  re-solve the reduced system, release a pinned cell whose balance turns
  positive) gets the margin by construction. Both ported candidates clip
  after an unconstrained solve; one lags the diffusivity a whole step and
  never iterates, with a dimensionless step literal and no stability check;
  the other rebooks the mass its clip destroys as a surface mass balance
  correction so the diagnostics balance (`notes/external-model-survey.md`
  section 45c).
- Every iteration count, profile error and margin position reproduced exactly
  across two runs at different host loads, so the verdict is arithmetic; a
  direct factorisation does not reach a ten-million-cell mesh, and the matrix
  is a symmetric M-matrix at every pass, so a preconditioned iterative solver
  is the production piece.
- The Halfar dome cannot discriminate slope accuracy, because its gradient is
  radial and the normal component across a face is nearly the whole of it; a
  test whose surface slope is not radial is needed for that.
- Glen's rate factor and exponent enter only through Gamma, which sets the
  timescale and cancels out of every relative error and iteration count.

## Why it carries

B6 adopts shallow-ice flow at the terrain level on the glaciated set with the
Halfar dome as the exact test. Every finding above is a property of the doubly
nonlinear diffusion on an unstructured mesh and not of the old tooling: a
two-point flux sees only the normal slope, the Picard map is not a contraction
without the transverse component, conservation is a structural property of
the assembled operator, the margin is a complementarity condition, convergence
is a statement about the nonlinear residual, and exact similarity solutions
are the tests that can fail.

## What this system must do

- The shallow-ice diffusivity uses the full surface-gradient magnitude
  reconstructed per cell (least squares over the icosahedral mesh's
  neighbour stencil, or an equivalent consistent reconstruction) averaged to
  faces; the reconstruction is certified against an analytic gradient on the
  sphere before any flow result is quoted.
- The flux form is finite-volume with antisymmetric face fluxes; the implicit
  operator's row sums vanish away from the domain boundary; ice volume, and
  the volume of the sub-grid tile ice stores, is a ledger closed to float
  tolerance at every step (A2, C3).
- The margin `H >= 0` is a free boundary solved as an active set or
  complementarity problem, never a clip; mass destroyed or invented by any
  limiter is a refusal, not a rebooked mass balance term.
- Convergence is declared on the nonlinear residual falling to a registered
  tolerance within a bounded pass count, with a line search or adaptive
  damping; the thickness step is not a criterion.
- Linear solves use a preconditioned iterative method on the GPU backend (A7)
  with the naive serial reference retained and agreed to a float-derived
  tolerance (C4).
- Oracles: the Halfar dome (volume identity, closed-form margin radius,
  closed-form profile) at no fewer than two mesh levels with the
  convergence-with-level requirement that every `Closure` carries; a
  non-radially-symmetric exact solution (the Bueler et al. family with
  compensatory accumulation) for slope accuracy; the spherical contamination
  of a planar solution reported beside each result.
- `(rho g)^n` explicit with rho and g from `System` (REQ-CRY-002).

## Enforced by

- B6 decision record.
- C3 analytic oracles (Halfar; the Bueler et al. exact solutions).
- C4: the serial reference path; the mutation run with a normal-only slope
  planted (must fail the convergence criterion) and a clipped margin planted
  (must fail the volume ledger).
- M10 gate: Halfar.
- A7: FP32 kernel certification by the ulp-ensemble test; reservoirs (ice
  volume) never in FP32.

## References

- Halfar, P. (1981). "On the dynamics of the ice sheets". Journal of
  Geophysical Research 86(C11), 11065-11072. DOI: 10.1029/JC086iC11p11065.
- Halfar, P. (1983). "On the dynamics of the ice sheets 2". Journal of
  Geophysical Research 88(C10), 6043-6051. DOI: 10.1029/JC088iC10p06043.
- Bueler, E., Lingle, C. S., Kallen-Brown, J. A., Covey, D. N. and Bowman,
  L. N. (2005). "Exact solutions and verification of numerical models for
  isothermal ice sheets". Journal of Glaciology 51(173), 291-306.
  DOI: 10.3189/172756505781829449.
- Bueler, E. and Brown, J. (2009). "Shallow shelf approximation as a "sliding
  law" in a thermomechanically coupled ice sheet model". Journal of
  Geophysical Research 114, F03008. DOI: 10.1029/2008JF001179.
- Jouvet, G. and Bueler, E. (2012). "Steady, shallow ice sheet as an obstacle
  problem: well-posedness and finite element approximation". SIAM Journal on
  Applied Mathematics 72, 1292-1314. DOI: to confirm. (The margin as a
  complementarity condition.)
- Glen, J. W. (1955). "The creep of polycrystalline ice". Proceedings of the
  Royal Society of London A 228, 519-538. DOI: 10.1098/rspa.1955.0066.
- Greve, R. (2005). "Dynamics of ice sheets and glaciers", lecture notes, held as
  `greve2005-dynamics-ice-sheets-glaciers-lecture-notes.pdf`; the shallow-ice
  formulation. The Greve and Blatter (2009) Springer monograph (DOI
  10.1007/978-3-642-03415-2) covers the same ground and is not held.
