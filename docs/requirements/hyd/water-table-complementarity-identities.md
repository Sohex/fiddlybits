+++
id = "REQ-HYD-004"
title = "The steady water table is a box-constrained complementarity problem certified by identities that can fail"
old_path = ["/home/cfutro/git/vesper/hydrography/notes/water-table-convergence.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

With transmissivity independent of head the discrete steady water table is
`sum_j T_ij (h_j - h_i) + R_i A_i = S_i`, `h_i <= z_i`, `S_i >= 0`: a box-constrained
linear complementarity problem with a symmetric positive definite matrix. It converged
in 20 passes with closure at 1.7e-16 against a declared 1e-10, with no relaxation and no
damping. The depth-decaying transmissivity of Fan et al. (2007), `T = A exp(h/f)`, is
convex, so its cell mean carries `exp(sigma^2 / 2 f^2)`, which at 100 m of sub-grid
relief against the 0.95 m `f` that curve reaches on steep bedrock is `exp(5000)`: the
parameterisation has no cell-mean value at that spacing. Two solvers built on it
failed, and the failures are the lesson: Picard limit-cycled and held its water balance
residual flat at 1.9e-4 from pass 100 to pass 599 while the head step fell thirtyfold,
which is why the convergence bar is the residual and never the head step; the
Kirchhoff transform exponentiates elevation over `f` and overflowed double precision on
3.3% of land.

Four defects were invisible to every check but one. Negative seepage on a pinned cell
clipped to zero created 740 m3/s while the free-cell residual read 3e-18; closure
caught it, and the cause was that complementarity was never re-tested on the head
actually returned. Feasibility tested as a count of cells let four cells hold 1e-18
m3/s forever; the bar must be the mass such cells would invent over total recharge. A
leak bar at 1e-8 reported convergence at a leak of 2.53e-9 and then failed closure at
2.47e-9, the same number, so the leak bar must be tighter than the closure bar it
feeds. Permanent anchors made a bad choice unfixable, and an isolated block with zero
supply is dry rather than anchored.

The uniqueness identity (two active-set trajectories, from all-free and all-pinned,
must reach the one solution) first failed at 12.76 m because the dry set was
discovered mid-iteration and depended on which cells were free at the moment; made a
static connected-components property of the conductive graph, the identity passed
bit-identically. Controls that must be rejected were run beside it: a re-solve missing
the sink (1.25e-2 relative), a re-solve missing the baselevels (1.47e-1), and a
mutated solver seeding pinned cells below their surface (1.05e-2). The identity had
been measured on an earlier equation and was silently comparing two models until the
re-solve took the primary solve's argument list whole.

A flux trace on the water table cannot reproduce a priority flood's catchments (79.3%,
declared bar 95%, left as a miss): the two routing rules disagree on identical terrain
by construction. The exact check is that the trace machinery, handed a receiver-only
flux, reproduces every terminal (100.0000%), and that check caught the module reading
its own sign convention backwards and following water uphill. The free set is
partitioned by coastlines into thousands of independent blocks (largest 15% of land);
a block solved alone is bitwise the block inside the whole under one column ordering
and is not under another, which is the licence for the partition. The direct-solve
work exponent measured 1.235, not the textbook 1.5; an ordering keyword that won on a
lattice synthetic was 286x slower and erratic on the real operator. The unconfined form
`T = K (h - z_b)` is linear in head, so it has an exact cell mean; it was material by
its own pre-registered bar (5.5% of the column drained) and limit-cycled on the real
mesh with arithmetic face averaging, with 16% of cells on the thickness floor, which is
the failure Niswonger, Panday and Ibaraki (2011) name and prescribe upstream weighting
for; it was refused.

## Why it carries

B5 specifies the steady unconfined water table as a box-constrained LCP solved by
multigrid-preconditioned iteration on the hierarchy. Every identity here is a property
of any complementarity solve on any mesh; the cell-mean argument is the A3 rule for a
Closure; the synthetic-versus-real-operator lesson is the C6 rule that benchmarks are
measured on the production operator. Nothing here depends on the old mesh or the old
world.

## What this system must do

- Formulate the water table as a complementarity problem with a fixed matrix where
  transmissivity is independent of head; where it depends on head, weight the face
  saturated thickness upstream and declare the uniqueness check a measurement against a
  bar, not an identity.
- Certify by identities, each with a control that must be rejected: reduction to the
  surface-only balance at zero permeability (bitwise); closure of recharge against
  seepage, baseflow, lake leakage and sink at a floating-point-derived tolerance, with
  the leak bar tighter than the closure bar and feasibility measured as mass; a static
  dry set; uniqueness from two active-set trajectories (bitwise for the linear form);
  trace exactness on a receiver-only flux.
- Take the convergence bar on the residual, never on the head step.
- Solve connected components independently and assert that a component solved alone
  equals the component inside the whole, bitwise, under the ordering used.
- Measure cost and ordering on the production operator at production size; a synthetic
  benchmark sizes nothing.

## Enforced by

C3 analytic oracles (Dupuit parabola, spherical Laplacian eigenvalues at two levels);
C4 naive serial reference path and the weekly mutation run with the named breaks
(clipped seepage, count feasibility, permanent anchor, mid-iteration dry set,
inverted receiver sign, dropped term in one trajectory); C6 thread and backend
invariance on the solve.

## References

- Incorporating water table dynamics in climate modeling: 1. Water table observations
  and equilibrium water table simulations. Fan, Miguez-Macho, Weaver, Walko, Robock
  (2007), Journal of Geophysical Research 112, D10125. DOI: 10.1029/2006JD008111
- MODFLOW-NWT, A Newton formulation for MODFLOW-2005. Niswonger, Panday, Ibaraki (2011),
  U.S. Geological Survey Techniques and Methods 6-A37. DOI: 10.3133/tm6A37
- Mapping permeability over the surface of the Earth. Gleeson et al. (2011),
  Geophysical Research Letters 38, L02401. DOI: 10.1029/2010GL045565
- The Linear Complementarity Problem. Cottle, Pang, Stone (2009), SIAM Classics in
  Applied Mathematics 60. DOI: 10.1137/1.9780898719000
