+++
id = "0059"
title = "The shallow-water gate's bounded effort is two closed remedy ladders, one per pathology, each rung ended by named oracle evidence, and a no hands to the Z-grid on the same triangles"
status = "accepted"
date = 2026-09-13
amends = [{ record = "0013", what = "declares the bounded effort its fallback ladder waits on, and reads its divergence-averaging filter as an average of the velocities entering the divergence, never an average of the divergence after it is computed" }]
+++

## Decision

Decision 0013 hands the triangle C-grid to its fallback ladder if the shallow-water gate
"fails after a bounded effort declared at the start of that milestone". This record is
that declaration: which remedies are in scope, in what order, what evidence ends each,
and where a no goes. It is fixed before `fiddlybits-52v.9.2` is claimed. A remedy not
listed here is not tried inside this gate.

The two pathologies of 0013 get two ladders. No remedy on one ladder is credited against
the other's oracle.

### What each oracle has to be able to show

A rung is ended only by evidence, and two gate oracles can give it only at particular
configurations.

- The checkerboard divergence mode is faint at the layer depths of the standard
  shallow-water suite and pronounced where the Rossby deformation radius is comparable to
  the spacing (Gassmann 2011, section 8, p. 2719, and section 9, p. 2720; Wan et al. 2013,
  section 4.3, p. 741). An averaged divergence hides the mode while the triangle
  divergences under it still carry it, and it returns once the flow is nonlinear
  (Gassmann 2011, section 7.2, p. 2717). `core.checkerboard_divergence_mode` is therefore
  judged at a deformation radius comparable to the spacing, in a nonlinear run, on the
  unaveraged triangle divergence.
- The Hollingsworth instability is internal: a one-level model does not show it at the
  depth of the external mode (Hollingsworth et al. 1983, section 1, p. 417, and section
  5, pp. 422-423), and its growth rate scales as f u / c (eq. (7), p. 424). A shallow-water
  model shows it at the small equivalent depth of an internal mode (Bell et al. 2017,
  abstract and section 1; Peixoto et al. 2018, sections 1 and 4), and at the depths of
  the standard suite it grows too slowly to be seen (Peixoto et al. 2018, section 5.1,
  p. 6). The operational triangle C-grid scheme is among the least stable in that test
  (Lapolli et al. 2023, section 4.5.1, p. 32). `core.hollingsworth_check` is therefore
  judged on the zonal balanced flow of Peixoto et al. 2018 section 4, over a declared
  bracket of Froude number and grid Rossby number.

Both configurations are stated in dimensionless groups, so no planet's layer depth enters
them. `fiddlybits-52v.9.9` fixes them in the registry with anchors and positive controls,
and registers `core.fsphere_normal_modes`: the normal modes of the linearised equations
on the f-sphere on the production mesh, whose geostrophic frequencies are zero and whose
counts of geostrophic and inertia-gravity modes equal the vorticity and the
mass-plus-divergence degrees of freedom (Thuburn et al. 2009, section 4.5, p. 8332). That
row merges before 52v.9.2 is claimed.

Each ladder starts with its control: the discretisation without that ladder's remedies
must show its pathology at the declared configuration. A control that does not fire makes
the oracle no evidence, and the gate neither passes nor hands off on it; the
configuration is corrected in the registry first.

The fourth-order filter of 0013 has its coefficient at zero in every run that judges C1,
C2, H1 or H2. C3 is the only rung under which it is non-zero, and the Hollingsworth
oracle is never judged with it on.

### The checkerboard ladder, judged by `core.checkerboard_divergence_mode`

Applied in this order. A remedy ended because the oracle still FAILs stays in place under
the next; a remedy ended because it breaks another gate item is withdrawn before the
next.

**C1. The tangential reconstruction stencil.** The tangential velocity at an edge is the
weighted sum of Thuburn et al. 2009, eq. (33), p. 8327, with the cell-to-vertex remapping
weights Derived from the mesh areas. On the triangular geodesic grid on the f-sphere those
weights give geostrophic modes of exactly zero frequency (section 4.5 and Fig. 10, pp.
8331-8333), and Coriolis terms that do no work (section 3, eq. (39), p. 8328). It comes
first because every later rung sits on it: how far the reconstruction leaves the
trivariate constraint unslaved sets how strong the checkerboard is, a four-point
reconstruction giving a stronger pattern than an eight-point one (Gassmann 2011, section
7.2, p. 2716, and section 8 with Figs. 5 and 6, pp. 2718-2720); and the kinetic energy of
H1 is derived for the vorticity-flux stencil the reconstruction fixes.

One alternative is in scope: the reconstruction from the edge inner product of Gassmann
2011, section 6, pp. 2713-2714, used only if the first FAILs `core.fsphere_normal_modes`.
Out of scope: a radial basis function reconstruction, which carries a kernel and a shape
parameter with no derivation and with which the kinetic-energy gradient and vorticity
flux do not conserve energy (Wan et al. 2013, sections 5.2 and 5.9, pp. 743-744); and a
projection reconstruction, whose geostrophic modes are not stationary (Thuburn et al.
2009, Fig. 11, p. 8334).

C1 ends when `core.checkerboard_divergence_mode` FAILs with it in place, and the ladder
moves to C2 with C1 kept. If both in-scope reconstructions FAIL
`core.fsphere_normal_modes` on the production mesh, the grid cannot hold stationary
geostrophic modes, the prerequisite for its Rossby modes (Thuburn et al. 2009, section
5, p. 8334), and that is a no by itself.

**C2. Averaging the velocities that enter the divergence.** The divergence of a cell is
taken from normal velocities averaged over one ring, the cell and its three edge
neighbours, so the flux through each edge stays single-valued and local mass
conservation holds (Zaengl et al. 2015, section 2.3, p. 565, and Appendix A2, p. 575),
with tracer transport taking the dynamical core's time-averaged mass fluxes (section
2.4, p. 566), which keeps the tracer-and-air-mass consistency a wider divergence stencil
otherwise breaks (Wan et al. 2013, section 4.3, p. 741). The width is one ring because a
triangle and its three neighbours is the stencil that gives a second-order divergence on
a regular grid (Wan et al. 2013, section 4.3, p. 741); it is not a free width, and a wider
stencil is not in scope. The weights are Derived from the mesh geometry by the moment
conditions (A1) and (A2) and the mass-conservation condition (A3) of Zaengl et al. 2015,
Appendix A1, p. 575. The empirically relaxed iteration that source uses to reconcile
those conditions on the sphere is not carried; if the conditions cannot be met without
it, C2 is out.

Out of scope: averaging the divergence after it is computed, which gives up local mass
conservation and tracer-mass consistency (Zaengl et al. 2015, Appendix A, p. 575) and
continuity (Wolfram and Fringer 2013, section 3.1, pp. 67-68); and the implicit elliptic
filter, which removes energy and adds a curl-of-vorticity term with no counterpart in the
equations (Wolfram and Fringer 2013, section 3.5, p. 71, and section 4.1, eq. (18), p.
72).

C2 ends when `core.checkerboard_divergence_mode` FAILs with C1 and C2 in place (C2 kept);
or C2 is withdrawn when any of these shows: `core.fsphere_normal_modes` finds a
non-geostrophic mode of zero frequency at the shortest resolved scale, which an averaged
divergence produces by coupling each triangle only to triangles of its own orientation
(Gassmann 2011, section 7.2, p. 2717); local mass conservation to rounding, the identity
of the flux form, no longer holds; or the same Williamson case run with and without C2
shows C2 costing `core.williamson_tc1` or `core.williamson_tc5_tc6` its bar or its
designed convergence order, or `core.williamson_tc2` its steadiness.

**C3. Fourth-order dissipation with a Closure coefficient.** The filter 0013 already
declares: a fourth-order operator on the velocity whose coefficient is a `Closure`, a
sourced scaling in the spacing and the eddy velocity, swept across levels. The vector
biharmonic built from the discrete divergence and curl carries a term that cancels part
of the first-order divergence error (Wan et al. 2013, section 4.3, eqs. (16) to (19), p.
742), which is why dissipation is on this ladder. It is last because it damps the flow
along with the mode (Wan et al. 2013, section 8, p. 757), and added diffusion has not in
general mitigated the mode (Wolfram and Fringer 2013, section 2.1, p. 65).

Out of scope: the coefficient of Wan et al. 2013, eq. (20), p. 742, which removes the
error within one step and so has the time step as its damping time; second-order
diffusion, which is anisotropic in common implementations, has not in general mitigated
the mode (Wolfram and Fringer 2013, section 2.1, p. 65) and lowers the effective Reynolds
number (section 3.3, p. 68); and orders above fourth, the filter one order above the
hyperviscous one (section 3.3, eq. (11), p. 69) having been oscillatory where it was
compared (section 5.4.1, p. 76, and section 6, p. 77).

C3 ends when `core.checkerboard_divergence_mode` FAILs at every level of the Closure
sweep with C1, C2 if kept, and C3 in place; or it PASSes only at a coefficient outside
the Closure's bracket; or the passing coefficient costs `core.williamson_tc1` or
`core.williamson_tc5_tc6` its bar or designed order. C3 is the last rung of this ladder.

### The Hollingsworth ladder, judged by `core.hollingsworth_check`

Starts once C1 is fixed, because H1 is derived for C1's stencil; if C1 is replaced by its
alternative, H1 is derived again before it is judged.

**H1. A kinetic-energy gradient consistent with the vorticity flux.** The kinetic energy
is taken on a stencil enlarged to match the vorticity-flux stencil, blending cell and
vertex kinetic energies (Hollingsworth et al. 1983, section 8, p. 427; Gassmann 2013,
section 3.3, eq. (27)). The blend is fixed before any run, from the condition that the
linearised vorticity-flux and kinetic-energy-gradient terms cancel on the equilateral
limit of the mesh: exactly, where the stencil admits it, which makes the linear stability
matrix Hermitian and the scheme stable to all perturbations (Bell et al. 2017, abstract
and section 6); by least squares where it does not (Gassmann 2013, Appendix B, eqs.
(B11), (B20) and (B21)). The blend is a Derived property of the stencil, and a different
Coriolis stencil gives a different blend (Gassmann 2013, Appendix B).

Out of scope: choosing the blend per equivalent depth, since the best blend moves with the
depth (Peixoto et al. 2018, section 5.1, p. 8), which would make it a coefficient tuned to
the configuration; more accurate operators as the remedy, which did not stabilise
(Peixoto et al. 2018, section 5.1, p. 8, and section 7, p. 15); dissipation, under which
the jets still lost energy (Hollingsworth et al. 1983, section 3, p. 418); and weighting
the vorticity term by the depth, which stabilises one scheme and destabilises another
(Peixoto et al. 2018, section 7, p. 15).

H1 ends when `core.hollingsworth_check` shows growth anywhere in its declared bracket with
H1 in place, or when H1 costs `core.williamson_tc2` its steadiness.

**H2. A density-weighted mass matrix.** The kinetic energy is taken with a mass matrix
weighted by the density, the layer depth in shallow water (Korn 2026, section 1, p. 4),
which conserves total energy exactly in the vector-invariant form and makes the scheme
linearly stable about constant-flow stratified states whatever the kinetic-energy
reconstruction (Korn 2026, Theorem 2.6, p. 8, and Corollary 5.20, p. 32). Its stated cost
is a defect in Kelvin's circulation theorem at the order of the convergence rate
(abstract, p. 1). The source is a preprint. H2 does not depend on H1's blend.

H2 ends when `core.hollingsworth_check` shows growth anywhere in the bracket with H2 in
place, or when the circulation defect shows as a loss of steadiness in
`core.williamson_tc2` or a miss of the `core.williamson_tc5_tc6` band. H2 is the last
rung of this ladder.

### What is a no, and where it goes

The attempt ends with a no when any of these holds:

- the checkerboard ladder is exhausted with `core.checkerboard_divergence_mode` still FAIL;
- the Hollingsworth ladder is exhausted with `core.hollingsworth_check` still FAIL;
- both in-scope reconstructions FAIL `core.fsphere_normal_modes`;
- a Williamson case FAILs and the failure is traced to the triangle C-grid: to a ladder
  remedy, by the same case run with and without it, or to the first-order divergence of
  a single triangle (Wan et al. 2013, section 4.2, eq. (10), p. 740) with C2 withdrawn.

A no hands to rung 1 of 0013, a Z-grid formulation on the same triangles, with mass,
vorticity and divergence all at cell centres. Vorticity stays at the cells: a
vorticity-divergence formulation with vorticity in the dual cells is equivalent to the
velocity C-grid and carries its modes (Thuburn et al. 2009, section 4.6, footnote 2, p.
8332). The unstaggered form's linear dispersion stays well behaved when the deformation
radius is small against the spacing, where the C-grid's does not (Randall 1994, section 3
and Fig. 2, pp. 1374-1376). That analysis is linear and leaves the nonlinear terms open
(Randall 1994, section 4, p. 1376), so rung 1 carries both pathology oracles in its own
acceptance, and its bounded effort is declared by a record like this one before its core
is written. Rung 2, the cubed-sphere finite-volume core, follows only a no at rung 1.
Never a spectral core.

These are not evidence against the triangle C-grid and hand to no rung: a Williamson FAIL
not traced as above; a FAIL of `core.laplacian_eigenvalues`, a defect in the mesh or the
operator under REQ-TER-011; `core.reference_arm_distance`, which is REPORT; a timestep
refusal in 52v.9.3. Each is a defect worked in its own row.

A pass names which of C1 to C3 and H1 to H2 were in place.

## Alternatives considered

- **H2 before H1.** Every density-independent form keeps an energy residual no choice of
  operators removes (Korn 2026, Theorem 4.6, p. 16), so the theorem predicts H1 slows the
  instability without removing it, which is what the least-squares blend did on hexagons
  (Peixoto et al. 2018, section 7, p. 15). H2 first would skip a rung the theorem expects
  to fail. Lost because the theorem and its corollary are in a preprint, because H2
  changes the mass matrix of the horizontal operators the ocean core shares (0013), and
  because it trades Kelvin's theorem for energy; H1 keeps the density-free operators and
  has reviewed support on quadrilaterals (Bell et al. 2017).
- **C3 before C2.** 0013 carries the fourth-order filter in every run, and the
  operational triangle core controls the two-delta noise with the velocity average and a
  fourth-order divergence damping together (Zaengl et al. 2015, section 2.5, p. 568).
  Lost because a pass reached by damping first could not say whether the operator's own
  truncation needed C2, and a verdict has to name the remedies that were needed.
- **An open list**, to which a remedy found during 52v.9.2 could be added by a record
  superseding this one. Lost: that is the negotiation 0013 declares the ladder in advance
  to prevent. A candidate found mid-gate is recorded in the verdict finding and carried to
  rung 1's declaration or a later record.
- **The per-step coefficient of Wan et al. 2013, eq. (20), on C3.** It is derived from the
  truncation error rather than fitted. Lost because its damping time is the time step, so
  the filter's strength follows a `Bracketed` numeric rather than a sourced scaling, and
  the source itself says it removes the freedom to set the diffusion by physical argument
  (section 4.3, p. 742); 0013 fixes the coefficient as a `Closure`.
- **Averaging the computed divergence, the literal reading of 0013's filter.** Lost on
  local mass conservation (Zaengl et al. 2015, Appendix A, p. 575) and on hiding rather
  than removing the mode (Gassmann 2011, section 7.2, p. 2717).
- **Judging both pathology oracles at the standard suite's layer depth.** Lost: neither
  control would fire there.

## Consequences

- `fiddlybits-52v.9.9` fixes the two oracle configurations in dimensionless groups and
  registers `core.fsphere_normal_modes`; it blocks `fiddlybits-52v.9.2`.
- The divergence-averaging filter of 52v.9.2 is C2 as defined here.
- The verdict of `fiddlybits-52v.9.6` is written against these two ladders: a pass names
  the rungs in place, a no names the condition above that ended the attempt.
- A no at this gate opens the declaration of rung 1's bounded effort as its first row.

## References

- Gassmann, A. "Inspection of hexagonal and triangular C-grid discretizations of the
  shallow water equations." Journal of Computational Physics 230 (2011).
  DOI: 10.1016/j.jcp.2011.01.014
- Wan, H., et al. "The ICON-1.2 hydrostatic atmospheric dynamical core on triangular
  grids - Part 1: Formulation and performance of the baseline version." Geoscientific
  Model Development 6 (2013). DOI: 10.5194/gmd-6-735-2013
- Zaengl, G., Reinert, D., Ripodas, P., Baldauf, M. "The ICON (ICOsahedral
  Non-hydrostatic) modelling framework of DWD and MPI-M: Description of the
  non-hydrostatic dynamical core." Quarterly Journal of the Royal Meteorological Society
  141 (2015). DOI: 10.1002/qj.2378
- Wolfram, P. J., Fringer, O. B. "Mitigating horizontal divergence checker-board
  oscillations on unstructured triangular C-grids for nonlinear hydrostatic and
  nonhydrostatic flows." Ocean Modelling 69 (2013). DOI: 10.1016/j.ocemod.2013.05.007
- Thuburn, J., Ringler, T. D., Skamarock, W. C., Klemp, J. B. "Numerical representation of
  geostrophic modes on arbitrarily structured C-grids." Journal of Computational Physics
  228 (2009). DOI: 10.1016/j.jcp.2009.08.006
- Hollingsworth, A., Kallberg, P., Renner, V., Burridge, D. M. "An internal symmetric
  computational instability." Quarterly Journal of the Royal Meteorological Society 109
  (1983). DOI: 10.1002/qj.49710946012
- Bell, M. J., Peixoto, P. S., Thuburn, J. "Numerical instabilities of vector-invariant
  momentum equations on rectangular C-grids." Quarterly Journal of the Royal
  Meteorological Society (2017). DOI: 10.1002/qj.2950. Pages cited from the unpaginated
  early-view copy by section.
- Peixoto, P. S., Thuburn, J., Bell, M. J. "Numerical instabilities of spherical
  shallow-water models considering small equivalent depths." Quarterly Journal of the
  Royal Meteorological Society (2018). DOI: 10.1002/qj.3191. Pages are those of the held
  accepted article.
- Gassmann, A. "A global hexagonal C-grid non-hydrostatic dynamical core (ICON-IAP)
  designed for energetic consistency." Quarterly Journal of the Royal Meteorological
  Society 139 (2013). DOI: 10.1002/qj.1960. Cited by section, equation and appendix.
- Korn, P. "A no-go theorem and its resolution for the discrete compressible barotropic
  Navier--Stokes equations." arXiv:2605.16554 (2026), preprint. Pages are those of v3.
- Lapolli, F. R., Peixoto, P. S., Korn, P. "Accuracy and stability analysis of horizontal
  discretizations used in unstructured grid ocean models." arXiv:2309.12832 (2023),
  preprint.
- Randall, D. A. "Geostrophic Adjustment and the Finite-Difference Shallow-Water
  Equations." Monthly Weather Review 122 (1994).
  DOI: 10.1175/1520-0493(1994)122<1371:gaatfd>2.0.co;2
- Decision 0013 (the core and its fallback ladder), decision 0034 (gates registered at a
  milestone's start), decision 0007 (the `Closure` and `Bracketed` dispositions);
  `docs/plans/fiddlybits-52v.9-dycore.md`, sections Scope and Oracles.
