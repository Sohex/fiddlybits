+++
id = "REQ-TER-011"
title = "A mesh carries both its tiling measure and its operator measure explicitly, and every reduction names which it integrates over"
old_path = ["/home/cfutro/docs/world/notes/audits/mesh-dual-area.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's `precarve-craton` export (2,500,001 regions,
radius 7645.2 km): the terrain generator's regions were a spherical Voronoi
tessellation (adjacency equal to the Delaunay edge set on all but 47 cospherical
quadrilaterals of 7,499,997 pairs), but the polygon whose spherical excess it
published as `cell_area` had triangle CENTROIDS as corners, under a comment
saying they were Voronoi vertices. The circumcentre dual summed to 4 pi R^2 to
ten significant figures; the centroidal dual summed to 1.0006809744 of it
(1.0006854371 at ten million regions), its own tiling error. Splitting one
triangle from an interior point tiles that triangle, but each dual piece spans
both triangles either side of a face, and the three pieces meeting in a
triangle reassemble it only when the corner is the circumcentre. Two earlier
versions of the note were wrong in opposite directions because a near-regular
synthetic mesh, on which centroid and circumcentre nearly coincide, could not
see the effect: measure on the production mesh. Per cell the two duals differed
by more than 10 per cent on 69 per cent of regions; per basin they agreed to 1.5
per cent, which is why every aggregating consumer had been fine.

The area was not the reason a solver needed the Voronoi dual. A two-point flux
approximation is valid only on faces perpendicular to the line joining the two
generators: centroidal faces had a median face-to-generator angle of 75.7
degrees with 3.8 per cent within one degree of perpendicular; circumcentre
faces 90.000 degrees and 100 per cent. The discrete Laplacian missed its
analytic Legendre eigenvalue by factors of 165, 95, 67 and 52 at degrees one to
four on centroidal faces and by 0.11 on Voronoi faces. The published area was
left alone because it was the denomination of the generator's own basin
catalogue and changing it meant a new build; the solver reconstructed Voronoi
faces from the generators.

## Why it carries

On the icosahedral triangle hierarchy (decision A1) the primal triangles tile
exactly, and the C-grid core (decision A9) carries mass on triangles and
vorticity on the dual around vertices; the Laplacians in groundwater (B5),
flexure (B1), hillslope diffusion and the ocean's free surface (B3) all need
the dual edges to be perpendicular bisectors of the primal edges. Whether a dual
vertex is a circumcentre or a centroid decides that, and a mesh that carries
one number called "area" hides the choice. Any grid module that publishes a
single area invites the same trap.

## What this system must do

- The mesh module carries, at every level and inside every refinement region:
  primal cell area by spherical excess (exact), dual cell area, primal edge
  length, dual edge length, the dual vertex definition by name (circumcentre),
  and the primal-to-dual edge angle as a tested property.
- Both area sums close to 4 pi R^2 within a tolerance derived from the
  floating-point type, at every level; both are native measures in the support
  identity (REQ-TER-002).
- Every reduction and every operator names the measure it integrates over; no
  function accepts "area" without saying which.
- Orthogonality and the operator built on it are tested against the analytic
  spherical Laplacian eigenvalues on the production mesh at the production
  level, never only on a synthetic near-regular mesh.
- Hanging edges at a refinement boundary carry their own flux-conserving
  measure, tested by the refinement balance identity.
- The radius enters both measures through one function.

## Enforced by

- M0 gate: area and nesting identities; refinement balance identity.
- C3 mesh oracles: spherical Laplacian eigenvalues per level; area sums;
  constant-field and extensive-integral preservation.
- REQ-TER-002: native measures in the support identity, so a mesh with a
  changed dual definition is a different support.

## References

- Ringler, T. D., Thuburn, J., Klemp, J. B., Skamarock, W. C. (2010). "A unified
  approach to energy conservation and potential vorticity dynamics for
  arbitrarily-structured C-grids". Journal of Computational Physics 229,
  3065-3090. DOI: 10.1016/j.jcp.2009.12.007. The Voronoi-Delaunay dual pair a
  C-grid requires.
- Augenbaum, J. M., Peskin, C. S. (1985). "On the construction of the Voronoi
  mesh on a sphere". Journal of Computational Physics 59, 177-192.
  DOI: 10.1016/0021-9991(85)90140-8.
- Eymard, R., Gallouet, T., Herbin, R. (2000). "Finite volume methods". In
  Handbook of Numerical Analysis, volume 7, 713-1018.
  DOI: 10.1016/S1570-8659(00)07005-8. The orthogonality condition of the
  two-point flux approximation.
- Heikes, R., Randall, D. A. (1995). "Numerical Integration of the Shallow-Water
  Equations on a Twisted Icosahedral Grid. Part I: Basic Design and Results of
  Tests". Monthly Weather Review 123, 1862-1880.
  DOI: 10.1175/1520-0493(1995)123<1862:NIOTSW>2.0.CO;2.
- Wan, H. et al. (2013). "The ICON-1.2 hydrostatic atmospheric dynamical core
  on triangular grids - Part 1: Formulation and performance of the baseline
  version". Geoscientific Model Development 6, 735-763.
  DOI: 10.5194/gmd-6-735-2013.
