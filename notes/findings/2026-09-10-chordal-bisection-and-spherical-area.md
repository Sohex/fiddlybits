# Unrenormalised bisection freezes the mesh at its base level, and the area formula sets a floor of one epsilon per cell

Measured on 2026-09-10 on yggdrasil, one core, Julia 1.12.7 and NumPy 2.5.3, all in
software floating point with no GPU involved. The subject is the bisection hierarchy
decision 0005 declares and the spherical area every cell of it carries. The external
tree read alongside is `CombinatorialSpaces.jl` at commit
`6ed8acf4a88c2d4940ef62cdb99f2617bf375c75` in `/home/cfutro/git/AlgebraicJulia/`; the
record of what it holds is `docs/imports/combinatorialspaces-jl.md`.

## The shipped icospheres are on the sphere; the runtime subdivision is not

`CombinatorialSpaces.jl` loads its spheres from a downloaded artifact of Wavefront
files, `UnitIcosphere1.obj` through `UnitIcosphere8.obj`, whose generator is not in the
tree. The artifact was fetched and measured directly (sha256
`bcf045eb8ad0a1ede2db366a4740587e36ce099bb74b2b17010181da7e83c698`, matching the tree's
`Artifacts.toml`). Every vertex of every file is on the unit sphere, so the offline
generator does project:

| file | vertices | max abs(1 - r) | rms abs(1 - r) |
|---|---|---|---|
| UnitIcosphere1.obj | 12 | 1.083e-05 | 8.581e-06 |
| UnitIcosphere4.obj | 642 | 7.038e-07 | 2.889e-07 |
| UnitIcosphere8.obj | 163842 | 8.953e-07 | 2.920e-07 |

The deviation is the file format, not the construction: the header says `Blender 3.3.0`
and every coordinate is written to six decimal places, which puts the radius error at
half an ulp of the sixth decimal. A mesh loaded from this artifact starts with a vertex
position error of about 1e-6, some nine orders of magnitude above the double-precision
rounding the identities below are measured at.

The runtime path is separate and does not project. `propagate_points(::BinarySubdivision,
...)` in `src/Multigrid.jl` places each new vertex at `(p0 + p1) / 2` and returns, and
nothing downstream renormalises. Starting from a level-2 mesh and refining five times by
that rule, against the same topology with a normalisation added:

| refinements | vertices | flat midpoint: max abs(1 - r) | its total area / 4 pi - 1 | projected: max abs(1 - r) | its total area / 4 pi - 1 |
|---|---|---|---|---|---|
| 1 | 642 | 1.3285e-02 | -1.888e-02 | 2.22e-16 | -4.782e-03 |
| 2 | 2562 | 1.6634e-02 | -1.888e-02 | 2.22e-16 | -1.199e-03 |
| 3 | 10242 | 1.7474e-02 | -1.888e-02 | 2.22e-16 | -3.000e-04 |
| 4 | 40962 | 1.7683e-02 | -1.888e-02 | 2.22e-16 | -7.503e-05 |
| 5 | 163842 | 1.7736e-02 | -1.888e-02 | 2.22e-16 | -1.876e-05 |

Both columns of the flat-midpoint half are constant. Every new vertex lands inside the
plane of the parent triangle it was born in, so the surface never leaves the polyhedron
the base level already described: the total area stays at the base level's value and the
worst radial defect converges to that level's sagitta rather than to zero. Refinement
buys resolution and no convergence. The projected half converges at the expected second
order, four times per level.

The correction is one operation and it is exact. For two unit vectors the chord midpoint
lies in the plane through them and the origin and bisects their angle, so normalising it
gives the great-circle midpoint itself, not an approximation to it: the projected column
above sits at 2.22e-16, which is the rounding of the normalisation and nothing else.

## The area formula sets an absolute floor of about one epsilon per cell

Spherical cell area was measured against a 400-bit reference: each Float64 vertex is
promoted, normalised at 400 bits, and the area taken by the Van Oosterom and Strackee
vector form. The control is l'Huilier's theorem evaluated at the same precision on the
same vertices, which agrees with the reference to 4.0e-115 or better at every level, so
the reference is the triangle's area and not one formula's opinion of it. Up to 3000
triangles are sampled per level. Maximum relative error over the sample:

| level | triangles | edge (deg) | l'Huilier Float64 | Van Oosterom Float64 | l'Huilier Float32 | Van Oosterom Float32 |
|---|---|---|---|---|---|---|
| 2 | 320 | 15.8587 | 4.96e-15 | 5.34e-16 | 1.29e-06 | 2.81e-07 |
| 3 | 1280 | 7.9294 | 2.37e-14 | 1.93e-15 | 8.24e-06 | 1.49e-06 |
| 4 | 5120 | 3.9647 | 8.25e-14 | 9.63e-15 | 2.77e-05 | 5.62e-06 |
| 5 | 20480 | 1.9823 | 3.59e-13 | 3.48e-14 | 1.05e-04 | 2.40e-05 |
| 6 | 81920 | 0.9912 | 1.64e-12 | 1.81e-13 | 4.43e-04 | 9.23e-05 |
| 7 | 327680 | 0.4956 | 5.55e-12 | 6.82e-13 | 2.11e-03 | 3.71e-04 |
| 8 | 1310720 | 0.2478 | 2.36e-11 | 2.67e-12 | 7.72e-03 | 1.50e-03 |
| 9 | 5242880 | 0.1239 | 1.03e-10 | 1.16e-11 | 3.34e-02 | 6.13e-03 |

The relative error rises by a factor of four per level because the cell it is relative to
shrinks by four. The absolute error does not move. In units of the machine epsilon of the
working type, the same maxima are:

| level | l'Huilier, abs error / eps | Van Oosterom, abs error / eps |
|---|---|---|
| 2 | 0.88 | 0.09 |
| 3 | 1.05 | 0.09 |
| 5 | 0.99 | 0.10 |
| 7 | 0.96 | 0.12 |
| 9 | 1.11 | 0.13 |

So the area of one cell of a unit sphere carries an absolute error of about one epsilon
under l'Huilier and about one eighth of an epsilon under the vector form, at every level
measured, and the choice of formula is worth an order of magnitude with no change of
cost. Two consequences follow for a threshold. A per-cell identity is bounded in absolute
area and never in relative area, because the relative bar would have to loosen by four
per level to stay true. And a sum over cells is bounded by the cell count times that
absolute floor: the measured total-area residual is far below it, 6.7e-16 relative over
the level-9 cells for the vector form, because the per-cell errors are of both signs and
cancel.

The nesting identity was measured the same way and behaves the same way. Summing the four
children's areas against the parent's, on the projected hierarchy, the worst residual is
1.2e-14 relative for level-2 parents and 1.0e-10 for level-8 parents under l'Huilier,
2.0e-15 and 1.4e-11 under the vector form, which is the same constant absolute error read
through a shrinking parent.

Float32 is not usable for cell area at any level of interest. At level 7 the vector form
is already wrong in the fourth digit, and at level 9 in the third. Whatever precision a
component runs at, the mesh geometry it reads has to have been built in double precision
and stored, which is a constraint on the support record rather than on any kernel.

## What this changes

`mesh.area_closure` and `mesh.nesting_identity` in `docs/oracles/registry.toml` carry the
derived absolute form above rather than the word roundoff alone. The mesh module takes the
Van Oosterom and Strackee form for cell area and keeps l'Huilier as the second arm of the
identity, since the two agree to the reference at 400 bits and disagree at working
precision by a known factor. Bisection renormalises at every level, and the shipped
icosphere artifact is not a source of vertex positions for this project: it is a Blender
export at six decimals, and the base icosahedron is constructed from the golden ratio in
the working type instead.
