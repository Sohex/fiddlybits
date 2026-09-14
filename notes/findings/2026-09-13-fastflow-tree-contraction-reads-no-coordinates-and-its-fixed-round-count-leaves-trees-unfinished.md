# FastFlow's tree contraction reads no coordinates and carries to any single-receiver forest; its fixed round count of ceil(log2 n) leaves some trees unfinished

Measured on 2026-09-13 on yggdrasil. The source read is FastFlow at
`/home/cfutro/git/fastflow`, commit `67be3c3` (`gitlab.inria.fr/landscapes/fastflow`),
with its paper, Jain, Kerbl, Gain, Finley and Cordonnier 2024 (DOI 10.1111/cgf.15243),
read in the authors' version held as
`references/pdf/jain2024-fastflow-gpu-acceleration-flow-and-depression.pdf`; page numbers
below are that version's printed "N of 13". The CUDA kernels were not built or run. The
round-count and summation-order measurements are from a Python 3 transcription of
`rake_compress_accum` run on the CPU under `qrun` with this repository's defaults
(section "What was run"). The row is `fiddlybits-bon.16`; the survey entry it reads for
is `docs/surveys/terrain-ice-and-solvers.md`, closer look "fastflow".

## What was read

- `src/cuda/core/tree_accum_up.cu`: `rcv2donor` (lines 43-63), `rake_compress_accum`
  (66-134), `fuse` (32-40), the host driver `flow_cuda_tree_accum_upward_rake_compress`
  (137-176).
- `src/cuda/core/tree_accum_down.cu`: `flow_cuda_tree_accum_downward_kernel` (6-22) and
  its driver (25-56); `src/cuda/core/tree_max_down.cu`, the kernel (6-19) and its driver
  (from 22).
- `src/cuda/core/rcv.cu`: `make_rcv` (6-63), `make_rcv_rand` (85-138).
- `src/cuda/core/lakeflow.cu`, every kernel and `lakeflow_cuda` (279-415);
  `src/cuda/core/scatter_min.cu` (9-114); `src/cuda/core/erode_deposit.cu` (6-57).
- `src/lakeflow.py`, `src/simulation.py`, `src/cuda/flow_cuda.cpp`, `src/cuda/setup.py`.
- The paper: related work on flow routing (pp. 2-3), section 3 (pp. 3-4), section 4 with Algorithm 1 (pp. 4-5), section 5 with
  Algorithms 2 to 5 (pp. 5-8), Algorithm 6 (p. 8).
- Cordonnier, Bovy and Braun 2019 (DOI 10.5194/esurf-7-549-2019), section 2 (pp. 550-554),
  the minimum-spanning-tree formulation FastFlow's depression routing follows (paper p. 6).
- Braun and Willett 2013 (DOI 10.1016/j.geomorph.2012.10.008), pp. 171-175: the receiver
  and donor arrays (p. 171), the stack order (p. 172, eq. 12), the accumulation over the
  inverted stack (p. 173), and the routing of local minima (pp. 174-175).

## The accumulation: rake and compress over a donor table

`rcv2donor` inverts the receiver array into a donor table of four slots per cell,
`dnr[rcv[tid]*4 + assumed]` (line 61), taking the slot index from a compare-and-swap loop
on the donor count (lines 53-59); the table is allocated as `n*4` with no bound check on
the count (lines 150-151). Roots are the cells with `rcv[tid] == tid` (line 52); the
`res` argument is not read.

`rake_compress_accum` visits every cell each round. For each donor whose donor count, read
from the start-of-round state, is zero, it adds the donor's value and removes the donor
from its list (rake); for a donor whose count is one, it adds the donor's value and
replaces the donor by that donor's single donor (compress) (lines 101-124). The
start-of-round state is read through a per-cell sign-and-round byte that selects one of
two buffers (`getSrc`, lines 15-22; `updateSrc`, 25-28), the ping-pong scheme of paper
p. 5. The kernel reads only `dnr`, `ndnr`, `p` and that byte. It holds at most four
donors in a fixed local array (line 98).

The host driver takes a weight tensor `W` (line 139) and never passes it to the kernel
(line 170): the accumulation is the unweighted sum `q_c = p_c + sum over donors q_d` of
paper eq. 1 (p. 4) over a forest with one receiver per cell. The paper states that the
logarithmic round count rests on that tree and "is not trivially extendable to the
Directed Acyclic Graph" a multiple-flow-direction split forms (p. 3).

Every value is `float32` (lines 69, 154) and the extension is compiled with
`--use_fast_math` (`setup.py` line 22).

## The fixed round count

The driver runs exactly `ceil(log2(n))` rounds, `n` being the number of cells in the whole
forest (lines 144, 148, 168-171), then merges the two buffers with `fuse` (line 173). No
step checks that every donor list is empty. The paper states that pointer jumping
restores the worst case "to log2(n) parallel iterations" (p. 5) and gives no proof.

The transcription counts the rounds after which every donor list is empty, and holds the
value at each cell to its subtree size with unit inputs.

| trees | sizes | result |
| --- | --- | --- |
| positive control: the enumerator's count of unrestricted rooted trees | n = 1 to 12 | matches OEIS A000081 |
| paths | n = 2, 3, 5, 9, 17, 33, 1025 | rounds needed equal `ceil(log2 n)` |
| every unlabelled rooted tree with in-degree at most 4 | n = 2 to 7, 9 to 12 | none needs more than `ceil(log2 n)` |
| the same | n = 8 | 2 of 106 trees need 4 rounds against 3 |
| the same | n = 13, 14, 15, 16 | 4 of 10683, 74 of 27790, 700 of 72917, 4807 of 192548 need 5 against 4 |
| a stem of `c` cells above a cell with two chains of `a` and `b` cells, `a, b` in `2^k - 1, 2^k, 2^k + 1` up to 1025, `c` 1 to 4 | n up to 2054 | 93 configurations need one round more; the smallest needing `r` rounds has `3 * 2^(r-3) + 2` cells, for `r` = 4 to 12 |
| hill-climb over reattached subtrees, 1500 steps from a path | n = 16, 32, 64, 128, 256 | best found needs one round more at every size |
| random trees, in-degree at most 4, three each | n = 100, 1000, 4000 | none needs more |

No tree needing two rounds more than `ceil(log2 n)` was found. The smallest failure is the
tree `rcv = [0, 0, 1, 2, 3, 4, 1, 6]`: cell 1 has a chain of four and a chain of two
above it. After the kernel's three rounds the root holds 7 of the 8 unit inputs and still
lists cell 5 as a donor; the fourth round completes it. A tree fails only when its own
count exceeds `ceil(log2)` of the forest it sits in, because the count is taken from the
forest's cell total: in a forest of `2^k` cells, a tree of the two-chain family fails
from `3 * 2^(k-2) + 2` cells.

## Donor slot order reaches the float32 sum

A cell adds its donors' values in slot order (line 118), and the slot order is the order
in which the compare-and-swap loop in `rcv2donor` succeeded. With the slots filled in five
shuffled orders on one random tree of 2000 cells and uniform `float32` inputs, 113, 82,
104, 91 and 107 cells differed bitwise from the unshuffled order after `ceil(log2 n)`
rounds. With every input 1, no cell differed.

## The two pointer-jumping scans

`flow_cuda_tree_accum_downward_kernel` writes `p_ = p + W * p[rcv]`, `W_ = W * W[rcv]`,
`rcv_ = rcv[rcv]` (lines 18-20) into copies that are written back after each round, for
`ceil(log2 n)` rounds (lines 34, 48). It is the parallel prefix of the implicit
stream-power update `z[c] = alpha z[rcv c] + beta` (paper eq. 4, p. 8), called from
`erode_deposit_cuda` (`erode_deposit.cu` line 55). A path of `d` edges is finished after
`ceil(log2 d)` rounds and `d <= n - 1`, so the round count suffices. The kernel has no
root guard: at a root `rcv = self` and the value is kept only because the weight there is
zero, which `erode_deposit_kernel` sets for boundary cells (lines 22-25) and which holds at
every root only when depression routing has left no interior root.

`flow_cuda_tree_max_downward_kernel` stops updating a cell once its pointer's own receiver
is itself (line 15), so the root's value never enters the maximum. `simulation.py` takes
the lake surface as that maximum of elevation along the receiver path and marks a lake
where it exceeds the terrain (lines 82-83), the pointer-jumping form of paper Algorithm 6
(p. 8) without its slope term.

Both kernels read only `rcv`, `W` and `p`.

## Depression routing

`lakeflow()` repeats `lakeflow_cuda` for at most `ceil(log2 n)` passes, stopping when no
interior cell is its own receiver (`lakeflow.py` lines 33-37). `lakeflow_cuda` takes no
runoff, water volume or evaporation argument (lines 279-302). Each pass:

- labels every cell with its root by pointer jumping over `basin_route`, `ceil(log2 N)`
  jumps on the first pass and one on later passes (`propag_basin_route_all`, lines 226-233;
  346-349), paper Algorithm 2 (p. 6);
- scores each basin-border cell as the maximum of its elevation and its lowest foreign
  neighbour's (`comp_basin_edgez`, lines 57-95), takes each basin's minimum with an atomic
  compare-and-swap (`scatter_min.cu` lines 18-39) and the smallest neighbouring basin id
  with `atomicMin` (line 83), then records the attaining cell with a plain unsynchronised
  write, `argminh[basin[tid]] = tid` (line 53), so among cells tied on both keys the cell
  kept is the last thread to write;
- picks the outlet across the saddle (`compute_p_b_rcv`, lines 98-137, ties to the lower
  basin id at line 126) and drops the edge of the lower-id basin of any mutually pointing
  pair (`set_keep_b`, line 147), the cycle rule of paper Algorithm 3 (p. 7);
- routes a basin whose outlet is the outflow collection (basin 0) by setting its pit's
  label to 0 (`update_basin_route`, lines 269-273), and every other kept basin's pit to
  the neighbouring basin's pit, compressed over `ceil(log2 S)` jumps (lines 382-385);
- with carving, marks the receiver path from saddle to pit by pointer jumping (lines
  399-402), reverses it (`final1`, lines 175-189) and points the saddle across the pass
  (`final2`, lines 191-200); with jumping, `lakeflow.py` points the pit at the outlet
  directly (line 52), an edge between cells that are not neighbours.

Basin ids are compared after conversion to `float`, `float ref = basin[loc]` (lines 67-71),
which is exact only for ids up to 2^24.

Cordonnier, Bovy and Braun define the basin graph with one link per pair of adjacent basins
weighted by the pass elevation `max(z_n1, z_n2)`, add an external basin linked to every
boundary basin, and route across basins by the minimum spanning tree of that graph (section
2.2, p. 552). Their filling and carving change receivers only and never elevations
(p. 550, section 2.3 p. 554), and every depression is connected to the boundary on every
call (p. 550, properties 1 and 2). Braun and Willett leave to the user the choice between
keeping a local minimum as a sink and routing it out (p. 174); routed, a minimum takes as
receiver the lowest neighbour of a catchment that reaches the boundary, repeated over
passes whose maximum number is "likely bounded by sqrt(n_p)" on rectangular grids
(p. 175).

## What reads the raster and what does not

| kernel | reads coordinates, offsets or a grid side | fixed four |
| --- | --- | --- |
| `rake_compress_accum`, `fuse`, `rcv2donor` | no (`res` passed, unread) | donor slots (line 98, 150-151) |
| `flow_cuda_tree_accum_downward_kernel`, `flow_cuda_tree_max_downward_kernel` | no | no |
| `propag_basin_route_all`, `propag_basin_route_lm`, `update_all_basins`, `update_basin_route`, `set_keep_b`, `set_keep`, `indexed_set_id` | no | no |
| carving: `init_reverse`, `flow_cuda_path_accum_upward_kernel1` and `2`, `final1`, `final2` | no | no |
| `make_rcv`, `make_rcv_rand` | `x = id % res`, `y = id / res`, offsets `-1, +1, -res, +res` (`rcv.cu` lines 12-13, 27-30) | yes |
| `comp_basin_edgez` | a two-dimensional thread grid skipping the outer ring, offsets `loc +- 1`, `loc +- res` (lines 59-92) | yes |
| `compute_p_b_rcv` | `pn_arr = {loc + 1, loc - 1, loc + res, loc - res}` (line 115) | yes |
| `scatter_argbasin_atomic` | offsets `tid +- res`, `tid +- 1` (`scatter_min.cu` lines 72-79); `res = sqrt(n)` (line 101) | yes |

The paper states the method is "equally well-suited to TINs and 4- and 8-connectivity
grids" and that the implementation targets 4-connectivity (p. 2), and that outflow cells
may sit inside the domain, at "groundwater sinks, estuaries, and sea shores" (p. 3).
`make_rcv_rand` draws the receiver with one random number per cell (line 127) from an array
drawn once per simulation (`simulation.py` line 38); across iterations the pick moves only
with the terrain, which is jittered by a uniform draw each iteration (line 47).

## Against this project's records

- Decision 0005 gives every cell three edge neighbours and twelve vertex neighbours, eleven
  at the cells touching the base vertices. A donor table sized to the in-degree bound of the
  receiver stencil is twelve slots on the vertex stencil and three on the edge stencil; a
  jump edge between non-neighbours (`lakeflow.py` line 52) is outside either bound.
- Decision 0015, section "Routing on triangles", accumulates discharge and sediment by
  slope-weighted multiple flow direction, a graph with more than one receiver per cell, and
  solves implicit incision along the steepest receiver, a forest. The contraction applies
  to the second as read, and to the first only through a change the paper names as not
  trivial (p. 3).
- Decision 0019 routes runoff through the depression hierarchy by fill-spill-merge, with a
  lake that stays closed below its spill; `lakeflow_cuda` has no water argument and
  connects every depression.
- Decision 0011 runs depression-hierarchy construction on the CPU backend and its
  consequences exclude atomics from the physics path; `rcv2donor`, `atomic_min` and
  `atomicMin` are atomics, and the unsynchronised argmin write (line 53) and the donor slot
  order are arrival orders that decision 0029 excludes from any result.
- Decision 0031 names, for basins, the drainage terminal of the connectivity graph's bodies;
  `propag_basin_route_all` computes every cell's root by pointer jumping over the receiver
  array alone.
- No kernel in the tree uses more than one level: nothing in FastFlow corresponds to the
  hierarchy of decision 0005.

## What was run

A probe in the session scratchpad, `rake_emul.py`, transcribing `rcv2donor` and
`rake_compress_accum` as synchronous rounds over the start-of-round state: donor lists
filled in cell order or a seeded shuffle of it, rake by swap with the last entry and
re-examination of the slot, compress by replacement without re-examination, `float32`
accumulation in slot order. Modes `control`, `families`, `exhaustive 12`, `random 3 3`
and `order` ran directly, the five together in under one second of wall time;
`exhaustive 16`, `branch` and `search 5 1500` ran from the worktree root as
`qrun -- ~/.venvs/fiddlybits-tools/bin/python <scratchpad>/rake_emul.py <mode>`; `order`
used tree seed 7, input seed 11 and slot seeds 0 to 5.

## Where it goes

The plan rows that decide these kernels on the mesh are `fiddlybits-bqz.1` (hydrology:
accumulation, depression routing, the drainage terminal) and `fiddlybits-37w.1` (terrain:
the implicit incision along receivers); both carry this finding in their notes.
