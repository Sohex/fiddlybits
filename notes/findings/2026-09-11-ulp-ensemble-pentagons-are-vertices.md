# The twelve degree-five elements are vertices, not cells, and level 7 has 163842 of the former against 327680 of the latter

Measured on 2026-09-11 on yggdrasil, one core, Julia 1.12.7, no GPU involved, Fiddlybits
at branch `fiddlybits-52v.7.20`, commit `229dc434c5f1744f1236dcdff20684b1a7fd7ca2`.

`notes/findings/2026-09-11-ulp-ensemble-member-count.md`, in its section "What the
ensemble cannot see", writes:

> On an icosahedral mesh at a level with 163842 cells it is 640 sites, which is far
> larger than the 12 cells of degree five that decision 0005 puts at every level.

Both uses of "cells" in that sentence are wrong. 163842 is the vertex count at level 7,
and the twelve are degree-five vertices, not cells. Decision 0005
(`docs/decisions/0005-one-mesh-icosahedral-triangles.md`) makes triangles the cells and
states: "Every cell has exactly three edge neighbours and twelve vertex neighbours,
except the cells touching the twelve base vertices, which have eleven and are padded
with self at zero weight." Cell degree on a triangle mesh is fixed at three by
construction, so there is no such thing as a cell of degree five to begin with; the
twelve base points of the icosahedron are vertices. A reader following the sentence as
written would look for twelve special cells among the 327680 cells at that level and
find nothing.

The arithmetic that follows the sentence is unaffected: 640 is 163842 divided by 256,
the miss-rate reciprocal `ENSEMBLE_MISS_RATE_RECIPROCAL`, and 163842 is the correct
vertex count for the level meant. Only the noun naming what is being counted is wrong,
in both places it appears in that one sentence.

## Both counts at level 7, verified against src/Mesh/hierarchy.jl

`src/Mesh/hierarchy.jl` defines `ncells(L) = 20 * 4^L` and `nvertices(L) = 10 * 4^L + 2`.
At `L = 7`:

| quantity | formula | value |
|---|---|---|
| cells | `20 * 4^7` | 327680 |
| vertices | `10 * 4^7 + 2` | 163842 |

Both were computed from the formulas in `src/Mesh/hierarchy.jl` and confirmed by loading
`Fiddlybits` and calling `Mesh.ncells(7)` and `Mesh.nvertices(7)` directly, which return
327680 and 163842.

## How the twelve are actually identified

Neither `ncells` nor `nvertices` names the twelve, and nothing in the `Level` struct or
its construction singles out an index for them. `test/certify/mesh_fixture.jl`
(`vertex_valence`) counts, for every vertex, how many cells in `level.cells` carry it,
which is the vertex's degree; `real_mesh_case` then takes
`findall(==(Int32(5)), valence)` as the pentagon set, rather than assuming which twelve
indices they are. `src/Backends/certify.jl` reads that set as one `Backends.Obligation`
the ensemble is required to hold a site of, over every field, so the check over the
twelve stays exhaustive rather than falling back to the sampled ensemble's relative miss
rate.

Loading `Fiddlybits` and running the same count at level 5, `Mesh.hierarchy(5)`, gives
`ncells(5) = 20480` and `nvertices(5) = 10242`, of which 12 vertices have valence 5 and
10230 have valence 6, accounting for all 10242. This matches the level-5 check
`fiddlybits-52v.7.17` built into `test/certify/mesh_fixture.jl`.

## What changes and what does not

- Changes: the noun in the one sentence quoted above, in both places it says "cells"
  where it means "vertices"; and, for a reader who takes the sentence's 163842 at face
  value as a cell count, the actual cell count to compare it against, which is 327680.
- Does not change: the conclusion that a relative miss rate cannot see the twelve, the
  766-member ensemble size, the declared miss rate
  `1 - (1/20)^(1/766) = 3.9032401194668553e-3`, and the exhaustive check over the
  degree-five vertices that `fiddlybits-52v.7.17` built on `test/certify/mesh_fixture.jl`
  in place of sampling them. That check was already exhaustive over vertices identified
  by computed valence, never over "cells of degree five", so it was correct before this
  correction and remains correct after it.

`notes/findings/2026-09-11-ulp-ensemble-member-count.md` is unedited by this record; its
diff against the tree is empty.
