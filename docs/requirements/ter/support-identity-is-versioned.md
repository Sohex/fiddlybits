+++
id = "REQ-TER-002"
title = "A spatial support has a versioned identity that includes its geometry, coordinates and measures; shape is never identity"
old_path = ["/home/cfutro/git/vesper/config/spatial_support.yaml"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's support declaration states the rule verbatim: "Shape is
never an identity. A support identity includes its kind, dimensions, geometry
digest, coordinate digest, native measures, and any effective fraction or
explicit measure used by a field", with the digest a sha256 over canonical
sorted JSON. The cases that forced it were all same-shape, different-support.
Measured on the predecessor's exports: a T170 Gauss-Legendre grid and a uniform
512 by 256 grid share a shape and are not interchangeable; a partition built on
midpoints between Gaussian rows closes to 4 pi R^2 exactly and reports a global
mean the spectral model does not take, 22 per cent wider than the quadrature
interval in the polar row at every truncation, and exports written before a
certain date carried that partition under the same variable name as the
correct one. One export carried two radii, 6371 km at the top level and the
planet's 7645.2 km one level down. A build was identified by its terrain hash
rather than by seed and parameters because a generator fix moved mean land
elevation by a factor of four under a fixed seed; and the hash was still
insufficient, because gravity was applied at export, so a build from another
gravity passed the allowlist with every vertical quantity off by the ratio.
`lib/nc_geometry.py` records the reader-side traps: a NetCDF file with no
coordinate system is given a 6371 km sphere by every standard reader, and a
`lat` axis with no quadrature weight gets an unweighted mean wrong by about 1.8
per cent in the polar row, converging to that rather than to zero.

## Why it carries

Every one of those cases is a support that looked like another support to
anything that checked shape, and each returned an ordinary-looking number.
In a hierarchy with local refinement, tiles, several vertical ladders, a
declared radius per system, NetCDF export and external datasets, the number of
distinct supports that share a shape only grows. Identity has to be a digest
over what the support is, versioned so that a changed constructor changes the
identity.

## What this system must do

- A support identity is a digest over: kind, hierarchy level, refinement
  region set, geometry constructor version, coordinate digest, native measures
  (primal and dual areas, edge lengths) including the radius they were formed
  from, and any effective fraction a field uses. Two supports with the same
  shape and different geometry have different identities.
- Ancestry between two levels of one hierarchy is a separate question from
  identity and is answered by a lineage digest, carried on every `Support`
  alongside its identity digest and compared by a door of its own: two levels
  bisected from the same base icosahedron carry the same lineage digest
  whatever their own level, and two bisected from different base icosahedra
  carry different ones even where their kind, radius, element type and
  refinement region set all agree, which those four fields alone cannot tell
  apart.
- Every array in the content store carries its support identity, semantics,
  time semantics, dimension, owner and interval as attributes; the store
  refuses an array missing any (decision A6).
- A consumer holding two arrays compares two support identities, never two
  axes or two shapes.
- A NetCDF export carries a declared geometry (radius, convention name, cell
  weights or areas, CRS) stamped with the declaration version; the reader
  reconstructs the geometry from the declaration and refuses a file whose axes
  do not match it.
- The planetary radius reaches a measure through exactly one function; no
  Earth radius is a physical parameter anywhere (decision A3, `EarthRatios`).
- A run's identity includes profile, backend and precision (decision C6).

## Enforced by

- Content store refusal on missing attributes (A6); M0 gate: area and nesting
  identities per level.
- Test: a support identity changes when radius, level, refinement set or
  geometry version changes, and does not change when only a human tag does.
- Test: `require_ancestor` refuses two supports with the same kind, radius,
  element type and refinement region set when they were bisected from
  different base icosahedra, and accepts two levels of one hierarchy.
- Import review for the NetCDF dependency naming its Earth-sphere default and
  the test that catches it leaking.
- Lint: the Earth radius denominator is unusable as a length.

## References

- National Institute of Standards and Technology (2015). "Secure Hash Standard
  (SHS)". FIPS PUB 180-4. DOI: 10.6028/NIST.FIPS.180-4. The digest.
- Hortal, M., Simmons, A. J. (1991). "Use of Reduced Gaussian Grids in Spectral
  Models". Monthly Weather Review 119, 1057-1074.
  DOI: 10.1175/1520-0493(1991)119<1057:UORGGI>2.0.CO;2. Gaussian rows are
  quadrature abscissae, not cell centres.
- Eaton, B. et al. "NetCDF Climate and Forecast (CF) Metadata Conventions".
  Locator: https://cfconventions.org (version to be pinned at export design).
  DOI: to confirm. The declared-geometry vocabulary an export must speak.

## Amendments

- 2026-09-13: ancestry given its own field, a lineage digest over the base
  level's vertices, in place of a hierarchy identity a `Support` would name.
  The two were weighed against this record's own "shape is never identity"
  argument rather than against present demand: `bisect` carries every
  existing vertex forward unchanged, so a level's first `nvertices(0)`
  columns hold the base icosahedron's own vertices at every level one
  hierarchy produces, and a digest over those columns is content, derived
  from what the hierarchy is, the same way the identity digest above is. A
  hierarchy identity a `Support` would name instead is a token stamped at
  construction, not derived from content, and it fails the property
  `mesh.support_identity` already holds identity to: two independent builds
  from one recipe carry the same identity digest because their content is
  bit for bit the same, and an opaque per-build identity would tell those two
  builds apart for ancestry while the identity digest calls them the same
  support, one fact stated two ways. `Fields.require_same_family` is removed
  and `Fields` calls `Mesh.require_ancestor` in its place. From
  `fiddlybits-52v.2.14`.
