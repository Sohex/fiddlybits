# The kernel layer's six oracles all pass or report on stand-in cases, and all six are still provisional

Measured on 2026-09-11 on yggdrasil, through `qrun -p gpu-share` (one share of the RTX
4090), Julia 1.12.7, `CUDA.jl` 6.3.1, `KernelAbstractions.jl` 0.9.42, Fiddlybits at
`166b59bf229e733dff88a77288eda15cbda64ec8` on `main` (merged), run as `./tools/gate/gate.sh`
(`julia --startup-file=no --project=. -e 'using Pkg; Pkg.test()'`). This is the verify row
`fiddlybits-52v.7.7` against `docs/plans/fiddlybits-52v.7-kernels.md`'s oracle set. The whole
suite ran: `Test Summary: Fiddlybits | Pass 1476 Total 1476`, no failures, no errors.

## The six oracles, by name

| id | verdict | how run | threshold judged against |
|---|---|---|---|
| `repro.thread_count_bitwise` | REPORT | `test/backends/thread_bitwise.jl` (`axpy!`, `stencil_gather!`) and `test/reductions/thread_bitwise.jl` (`pairwise_sum`, `compensated_sum`, `segmented_sum`), each run at 1 and 16 Julia threads in fresh processes and compared as raw bytes | registry: "bitwise identical" |
| `repro.backend_ulp_envelope` | REPORT | `test/certify/envelope.jl`, CPU-vs-GPU divergence against the ensemble envelope at every step | registry: "inside the envelope at every step; bitwise in debug mode", 766 members, detectable miss rate `3.9032401194668553e-3` |
| `repro.fp32_kernel_certification` | PASS | `test/certify/certification.jl`, `test/certify/gpu_certification.jl`, `test/certify/obligation.jl` (`certify.case_certification_runs_every_arm`) | registry: "inside the envelope; reservoirs never FP32", same member count and miss rate, obligation-coverage clause below |
| `kernels.reduction_partition_independent` | PASS | `test/reductions/partition_independent.jl` | registry: bitwise across thread counts and block partitions; residual within `k*N*eps*M` |
| `kernels.segmented_quantile_exact` | PASS | `test/reductions/quantiles.jl` | registry: bitwise against the exactly sorted answer; inverse identity to roundoff |
| `kernels.memory_budget` | PASS | `test/backends/budget.jl` | registry: exact against declared sizes; refuses before allocation, fields named in descending size |

## The two REPORT oracles name the stand-in case

`docs/plans/fiddlybits-52v.7-kernels.md`, section "Oracles": `repro.thread_count_bitwise`
and `repro.backend_ulp_envelope` name the short coupled case, which does not exist until a
later milestone. Both ran instead on the stand-in this area can build without `Mesh`: the
synthetic `4^k` layout with a stencil-shaped gather over flat index tables,
`CertifyFixtures` in `test/certify/fixtures.jl` (`4^5 = 1024` cells) for the certification
suite and the analogous fixtures in `test/backends/fixtures.jl` and
`test/reductions/fixtures.jl` for the thread-count suites. This is the same stand-in
`notes/findings/2026-09-11-ulp-ensemble-member-count.md` measured, section "The stand-in
case". A bitwise claim evidenced on arithmetic alone is not the claim the registry row
states, so both are recorded REPORT and not PASS. `docs/oracles/registry.toml` carries no
mark of this by itself; the two rows still awaiting the short coupled case are
`repro.thread_count_bitwise` and `repro.backend_ulp_envelope`.

`repro.fp32_kernel_certification` is not named by that paragraph and its threshold does not
tie it to one case: it ran to PASS on the same stand-in (`certification.jl`,
`gpu_certification.jl`) and, separately, on a real-mesh case built from
`Mesh.hierarchy(5)` (`test/certify/mesh_fixture.jl`'s `CertifyMeshFixture.real_mesh_case`,
used by `degree_five.jl` and `obligation.jl`) that declares decision 0005's twelve
degree-five vertices as an `Obligation`. `Backends.case_certification` on that case runs
the sampled arm and the exhaustive obligation arm and both come back PASS
(`report.sampled.verdict == PASS()`, `report.obligated[1].verdict == PASS()`), which is
what the two registry rows' shared threshold text means by "not admissible from the
sampled arm alone". The real-mesh case is real geometry, not the stand-in, but it is also
not the short coupled case the plan says does not exist yet: its fields are the same house
formula the stand-in uses, not a physics kernel's output. Neither of `certify_case`'s two
witnesses is the case `repro.thread_count_bitwise` and `repro.backend_ulp_envelope` are
waiting on.

## Every one of the six is provisional

`docs/oracles/registry.toml` carries `provisional = true` and `registered_at = ""` on all
six entries (`repro.thread_count_bitwise` line 1419, `repro.backend_ulp_envelope` line
1432, `repro.fp32_kernel_certification` line 1445, `kernels.reduction_partition_independent`
line 361, `kernels.segmented_quantile_exact` line 374, `kernels.memory_budget` line 387).
Decision 0025's registration rule is that a provisional entry may run and report but may
not fail a milestone gate. This verify's four PASS verdicts and two REPORT verdicts are
therefore what the suite currently shows, not yet a gate-enforceable result: none of the
six carries the weight of a registered threshold until it is registered.

## The tree does not yet obey its own fusion rule, in three named places

`lint_fused_multiply_add` (decision 0044, `test/lint/lint_fused_multiply_add.jl`) ran
clean over `src/` as part of the same suite (`test/lint/runtests.jl`, testset "the tree"),
because `test/lint/lists/fused_multiply_add.toml` exempts three sites by name rather than
because the sites are absent. The oracle set passing and the tree obeying decision 0044 are
two different statements. The three exemptions, each a bare multiply feeding a bare add in
source that bitwise mode compiles, each still `OPEN` in `bd`:

- `fiddlybits-52v.7.30`: `src/Backends/transcendentals.jl`, `cube_root_poly`'s `Float64`
  Newton step, `2.0t + y / (t * t)`.
- `fiddlybits-52v.7.31`: `src/Backends/certify.jl`, `admissible`'s envelope bound assembly,
  `carried + injected * Float64(roundoff)`.
- `fiddlybits-52v.7.32`: `src/Mesh/refinement.jl`, `hanging_flux`'s two-child assembly,
  `density[1] * length[1] + density[2] * length[2]`.

None changes a number today, per each row's own description. The lint's own live-check
(`test/lint/lint_fused_multiply_add.jl`, "exemption named nothing" refusal) ran in the same
suite, so a stale entry among these three would itself have failed the gate; it did not.

## The positive controls fired

Every control the acceptance criteria name is present in the suite and passed along with
the rest: `test/reductions/partition_independent.jl` ("positive control: an atomic
accumulation substituted for the fixed-order tree differs across thread counts") and
`test/reductions/compensated.jl` ("positive control: the naive Float32 accumulation is the
one that stagnates" / the alternating-magnitude case); `test/reductions/quantiles.jl`
("positive control: a quantile interpolated rather than selected breaks the inverse
identity"); `test/backends/budget.jl` ("Positive control: ceiling one byte below estimate
must refuse"); `test/certify/certification.jl` and `gpu_certification.jl` (injected
relative defects of `1.0e-5` and `1.0e-4` FAIL, `1.0e-6` PASS as the boundary control). No
control failed to fire.

## What this changes

Nothing in `src/`. This finding is `fiddlybits-52v.7.7`'s record; the row's `bd` notes
carry the same six verdicts by name.
