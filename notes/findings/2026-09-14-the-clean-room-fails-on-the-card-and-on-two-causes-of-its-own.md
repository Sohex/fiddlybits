# The clean room fails on the card, on a name one suite binds for another in one process, and on a one-ulp disagreement of Mesh.arc_length on the hosted processor

Measured on 2026-09-14 with `gh run list --workflow "clean room"` and
`gh run view <id> --log-failed`, against the GitHub-hosted `ubuntu-latest` runner, Julia
1.12.7, CUDA.jl 6.3.1. The row is `fiddlybits-unx`; the plan it informs is
`docs/plans/fiddlybits-unx-machine-resources.md`.

## The runs

- Last success: run 34583324506, 2026-09-11 09:16, on `02908e977`.
- First failure after it: run 34584177429, 2026-09-11 09:26, on `6428cd0` (the device
  layer row's close). Its failing sites are all card arms, in
  `test/backends/backend_agreement.jl`, `bitwise_mode.jl` and `move_events.jl`.
- Every completed run on `main` since has failed or been cancelled by the next push
  (`concurrency.cancel-in-progress`). The four most recent completed failures are runs
  34805326422, 34821948536, 34843535233 and 34858254535.
- Run 34858254535, on `421037e55` (the merge of fiddlybits-52v.8.14), is the one tabled
  below. Its summary line: 32087 passed, 231 failed, 631 errored, 32949 total, 21m07.6s.

## Every failing site of run 34858254535, by suite, file and cause

A site is one `Test Failed at` or `Error During Test at` line. The cause is read from the
lines that follow it. "card" means the refusal `CUDA reports no functional device on this
host`, `CUDA driver not functional`, a failed `@test CUDA.functional()`, or a child
process's expected card output missing.

| suite | file | sites | cause |
| --- | --- | --- | --- |
| backends | backend_agreement.jl | 6 | card |
| backends | bitwise_mode.jl | 7 | card |
| backends | bounds_reach.jl | 14 | card (the `_gpu` probe arms and the parent's `CUDA.functional()`) |
| backends | cross_task_ordering.jl | 2 | card |
| backends | dispatch_refusal.jl | 9 | card |
| backends | host_copy.jl | 2 | card |
| backends | kernel_fault.jl | 18 | card (a child julia's printed outcome lines absent) |
| backends | launch_completion.jl | 2 | card |
| backends | launch_workgroup.jl | 8 | card (one a `CUDA.device()` at file top level) |
| backends | move_adapt.jl | 2 | card |
| backends | move_events.jl | 13 | card |
| backends | transcendentals.jl | 25 | card |
| certify | gpu_certification.jl | 2 | card |
| coupling | exchange.jl | 5 | card |
| coupling | state.jl | 20 | one-process name collision (below) |
| fields | adapt_roundtrip.jl | 2 | card |
| fields | inference.jl | 32 | card (the GPU entry of `BACKENDS`; a `Refusal` thrown where `@inferred`'s error was expected) |
| fields | reduce.jl | 10 | card |
| fields | vectors.jl | 2 | card |
| kernels | body_types.jl | 3 | card |
| mesh | location.jl | 152 | one-ulp disagreement of `Mesh.arc_length` (below) |
| orbit | runtests.jl | 8 | card |
| provenance | rng.jl | 2 | card |
| provenance | run.jl | 6 | card |
| reductions | class_forms.jl | 8 | card |
| reductions | column_forms.jl | 7 | card |
| reductions | edge_shapes.jl | 403 | card |
| reductions | gpu_agreement.jl | 5 | card |
| reductions | mixed_precision.jl | 2 | card |
| reductions | no_input_sized_temporary.jl | 8 | card |
| reductions | partition_independent.jl | 6 | card |
| reductions | quantiles.jl | 12 | card |
| reductions | segment_moves.jl | 2 | card |
| reductions | shared_block_kernels.jl | 57 | card |

The sites sum to 862, the run's 231 failed and 631 errored. No site names a missing
dataset payload or a missing references payload: no check in the tree reads
`oracles/data/`, `inputs/data/` or `references/` at this commit. The suites with no
failing site are build, connectivity, datasets, dimensions, dispositions, events, gate,
imports, io, lint, nightly, oracles, planets, system, time and verdicts.

## The two causes that are not a missing resource

**`test/coupling/state.jl`: a constant bound by an earlier suite in the same process.**
Every one of its sites is an `UndefVarError` in `Main.ConnectivityFixtures` (`writing`,
`reading`, `triad`, `at_level`) or follows from one. `test/connectivity/topology_event.jl`
binds `const CF = ConnectivityFixtures` in `Main`; `test/coupling/state.jl` later writes
`import .CouplingFixtures as CF`, which does not rebind a constant already bound, so `CF`
still names the connectivity fixtures. `test/runtests.jl` includes every suite into `Main`
in one process; `tools/gate/run.jl` runs each suite in a process of its own
(decision 0049), which is why the gate never sees it.

**`test/mesh/location.jl`: `Mesh.arc_length` on a view against the stored edge length.**
Every site is `Mesh.arc_length(pa, pb) == geom.primal_edge_length[e]` in the testset
`Mesh.edge_vertices`, for example `0.3141592653589794 == 0.3141592653589795`.
`Mesh.geometry` computes `primal_edge_length` with `pa = column(vertices, a)`, an
`SVector{3,Float64}` (`src/Mesh/geometry.jl`); the test passes `view(level.vertices, :, a)`.
`arc_length(u, v) = atan(norm(cross(u, v)), dot(u, v))` therefore runs different methods
of `dot`, `cross` or `norm` for the two argument types, and on the hosted processor their
results differ in the last place. The test passes on the gate host. Which of the three
operations differs, and why only there, is not established here.

## What was not measured

- Whether any check passes in the clean room only because an earlier card error ended
  its testset first. A testset that errors stops at the error, so a processor check
  after a card arm in the same testset is not reached there.
- The local reproduction of the `Mesh.arc_length` disagreement.
