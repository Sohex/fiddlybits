# The dual area sum carries six pieces per cell, and the circumcentre's floor doubles with every level

Measured on 2026-09-11 on yggdrasil, one core, Julia 1.12.7, all in double precision
with no GPU involved. The subject is the three quantities `fiddlybits-52v.2.3` has to
judge that `notes/findings/2026-09-10-chordal-bisection-and-spherical-area.md` did not
measure: the dual area sum, the primal-to-dual edge angle REQ-TER-011 names as a tested
property, and the circumcentre's equidistance from its own cell's three vertices. The
earlier finding measured the primal cell area alone, so `mesh.area_closure` in
`docs/oracles/registry.toml` carried a threshold for the primal sum and nothing else.

Every number below is taken on the renormalised hierarchy, levels 0 through 8, with cell
area by the Van Oosterom and Strackee vector form, the dual vertex the circumcentre, and
the dual cell at a primal vertex accumulated from the two spherical triangles each
incident cell contributes there. All are absolute, in units of the machine epsilon of
the working type.

## The dual sum needs six times the primal's bar, and only at the coarsest level

| level | cells | primal residual / eps | dual residual / eps | N | 6N |
|---|---|---|---|---|---|
| 0 | 20 | 0.0 | 24.0 | 20 | 120 |
| 1 | 80 | 16.0 | 32.0 | 80 | 480 |
| 2 | 320 | 32.0 | 0.0 | 320 | 1920 |
| 3 | 1280 | 8.0 | 0.0 | 1280 | 7680 |
| 4 | 5120 | 0.0 | 8.0 | 5120 | 30720 |
| 5 | 20480 | 0.0 | 0.0 | 20480 | 122880 |
| 6 | 81920 | 8.0 | 0.0 | 81920 | 491520 |
| 7 | 327680 | 48.0 | 0.0 | 327680 | 1966080 |
| 8 | 1310720 | 32.0 | 0.0 | 1310720 | 7864320 |

The primal sum is inside `N eps` at every level with a wide margin, which is the earlier
finding's result restated on this mesh. The dual sum is inside `N eps` at every level but
the coarsest, where it is 24 eps against a bar of 20. The residual is not growing with
level: it is the rounding of a sum whose total is `4 pi`, and at twenty cells `N eps` is
below two roundings of that total, so the bar rather than the measure is what fails.

A dual cell is assembled from sub-triangles, six per primal cell, where a primal cell is
one evaluation. By the same derivation the registry already uses, the per-piece floor
times the piece count, the dual sum's bar is `6 N eps R^2`. Every level measured is
inside it, the coarsest by a factor of five.

**The pieces are evaluated independently, and that is what makes this a second check.**
Taking the sixth piece of each cell as the remainder against that cell's primal area
makes the dual areas sum to the primal areas by construction, so the dual closure stops
being a check at all: a wrong circumcentre, a wrong midpoint or a wrong decomposition is
absorbed into the remainder and into whichever vertex holds it. It also lowers the
level-0 residual to 16 eps, which is how the shortcut presents itself as an improvement.

## The circumcentre's floor doubles with every level, and so does the right angle's

| level | right angle / eps | that over `eps 2^L` | circumcentre spread / eps | that over `eps 2^L` |
|---|---|---|---|---|
| 0 | 0.262 | 0.262 | 0.0 | 0.0 |
| 1 | 0.594 | 0.297 | 2.5 | 1.25 |
| 2 | 0.859 | 0.215 | 5.0 | 1.25 |
| 3 | 1.58 | 0.197 | 9.69 | 1.21 |
| 4 | 4.03 | 0.252 | 25.5 | 1.59 |
| 5 | 7.11 | 0.222 | 58.7 | 1.83 |
| 6 | 17.1 | 0.267 | 119.0 | 1.87 |
| 7 | 33.5 | 0.262 | 236.0 | 1.85 |
| 8 | 74.3 | 0.290 | 511.0 | 2.00 |

The right angle is the worst `abs(dot(edge_normal, unit primal chord))` over every edge,
which is zero for a dual edge that is the primal edge's perpendicular bisector. The
circumcentre spread is the worst difference between the largest and smallest of a cell's
three circumcentre-to-vertex arcs.

Neither is level-independent the way an area is, and the reason is the vertex
coordinates rather than either formula. A vertex is a unit vector stored to an absolute
rounding of about one epsilon. The circumcentre is built from the differences of a
cell's vertices, and those differences have magnitude `h`, the cell's edge, so they
carry a relative rounding of `eps / h`. The edge halves with every level, so the floor
doubles with every level. Both columns above confirm it: divided by `eps 2^L` the right
angle is flat between 0.20 and 0.30 across nine levels, and the circumcentre spread
settles near 2.

The better-conditioned arm was already chosen. `cross(b - a, c - a)` and
`cross(a, b) + cross(b, c) + cross(c, a)` are the same expression algebraically, but the
second cancels three terms of magnitude `h` to reach one of magnitude `h^2` and is worse
by `1 / h` again. The differences `b - a` are themselves exact for vertices this close,
so the floor above is the stored coordinate's own rounding read through a shrinking
triangle, and no rearrangement removes it. Carrying the mesh at higher precision, or
carrying each cell's vertices relative to its own centre, is what would, and neither is
in scope here.

## What this changes

`mesh.area_closure` in `docs/oracles/registry.toml` names the dual sum beside the primal
one and carries `6 N eps R^2` for it, derived above. The two properties REQ-TER-011 names
but the registry does not carry take bars of `eps 2^L` for the right angle and
`4 eps 2^L` for the circumcentre spread, each a factor of three or two above the worst
measured, and each stated in the level-scaled form rather than as a flat multiple of
epsilon, which would hold at one level and fail at the next. Geometry evaluates all six
sub-triangles of a cell independently; the remainder form is refused.
