# The ulp-ensemble envelope needs 766 members and a field-scale ulp, and a pair measures no envelope at all on the stand-in case

Measured on 2026-09-11 on yggdrasil, through `qrun -p gpu-share` (one share of the RTX
4090), Julia 1.12.7, `CUDA.jl` 6.3.1, `GPUCompiler.jl` 2.6.0, `KernelAbstractions.jl`
0.9.42, `Adapt.jl` 4.7.0, Fiddlybits at branch `fiddlybits-52v.7.4` cut from
`36379f57a381ae31b090eecfdf6e6a9daa8ec958`. Every number below is exhaustive or
deterministic; nothing here is a draw.

Decision 0029 makes the ulp-ensemble envelope the tolerance of fast mode and of the
single-precision certification, and says of the ensemble only that its members "each
have one field perturbed by one ulp in one cell" and that "the registry states the miss
rate the repeat count can detect". This row had to turn that into a member count and a
miss rate. Two questions had to be answered with measurements before either number could
be written down: what "one ulp" is measured against, and how many members the maximum
over members needs.

## The stand-in case

`test/certify/fixtures.jl`. The plan
(`docs/plans/fiddlybits-52v.7-kernels.md`, section "Oracles") declares the stand-in the
two envelope oracle rows run on until the short coupled case exists: a synthetic `4^k`
layout with a stencil-shaped gather over flat index tables, built without `Mesh`, which
sits above `Backends`.

`4^5 = 1024` cells, two fields, so 2048 sites. Each cell gathers the other three cells of
its own quad and the cell at the same position in the next quad, with weights from a
fixed formula normalised so every column sums to one, and the two gathered fields are
then mixed by a rotation of angle `1/64`. One step therefore sums five terms per cell.
The initial fields are the house formulas `mod(31i + 7, 97)/20 - 2` and
`mod(53i + 11, 89)/30 - 1`, whose largest absolute values are 2.8 and 1.9333333333333331
and which take the value zero at 22 of the 2048 sites. The measurements below run 20
steps.

## What "one ulp" is measured against

Two readings of decision 0029's phrase were implemented and the per-site amplification
measured exhaustively at step 20 under each, over every one of the 2048 sites.
Amplification is the one norm of the difference from the unperturbed trajectory divided
by the perturbation the member was given.

| reading | usable sites | max | median | sites at zero | sites within a factor of 2 of the max |
|---|---|---|---|---|---|
| one ulp of the value in the perturbed cell | 2026 | 332.0 | 0.0 | 1471 | 1 |
| one ulp of the perturbed field's own scale | 2048 | 19.0 | 0.0 | 1026 | 34 |

The per-cell reading is degenerate and the reason is visible in the numbers. The response
to any perturbation is quantised to an ulp of the state, which here is an ulp of a value
of order one; the perturbation at a cell holding a small value is an ulp of that small
value. At the smallest usable value in these fields the two differ by a factor of order
100, so the ratio measured there is the ratio of the two scales and not the case's own
amplification. That is where the 332.0 comes from, and only one site of 2026 is within a
factor of two of it. Under that reading the maximum is a property of the initial data's
smallest nonzero entry rather than of the dynamics, and 1471 of 2026 members measure
exactly zero.

The field-scale reading gives every member the same perturbation, `nextfloat(m) - m` for
`m` the largest absolute value in the field. Members then differ in where the
perturbation is and not in how large it is, which is what lets the maximum over members
be attributed to a site. The implementation takes this reading, in
`Backends.field_ulp`, and the docstring says so.

Both readings satisfy the decision's words. The choice is recorded here rather than in a
comment (decision 0039), and `src/Backends/certify.jl` names this finding by path.

## Why a pair is not an ensemble, measured

Under the field-scale reading, the exhaustive envelope at step 20 is 19.0 and the
distribution behind it is heavy:

| within a factor of the exhaustive maximum | sites | share of the 2048 |
|---|---|---|
| 2 | 34 | one in 60.2 |
| 4 | 217 | one in 9.44 |
| 8 | 542 | one in 3.78 |
| 16 | 751 | one in 2.73 |

Half the sites (1026 of 2048) leave the trajectory bit-for-bit unchanged at every one of
the 20 steps: the perturbation is rounded away before it reaches the next step. The
shortfall of an ensemble that stops at `m` members, taken in the order
`Backends.bit_reversed_order` fixes, is the exhaustive maximum divided by the maximum
over those `m`:

| members | shortfall |
|---|---|
| 2 | infinite, both members measure zero |
| 3 | 11.69 |
| 4 | 4.00 |
| 16 | 4.00 |
| 32 | 2.95 |
| 47 | 1.95 |
| 64 | 1.95 |
| 128 | 1.73 |
| 256 | 1.73 |
| 412 | 1.33 |
| 766 | 1.32 |
| 1765 | 1.00 |
| 2048 | 1.00 |

The first row is the measurement the plan's sentence asks for. A two-member ensemble on
this case does not measure a small envelope; it measures no envelope at all, because both
of its members are among the 1026 sites whose perturbation dies. `Backends.envelope`
refuses such a case by name rather than returning a zero envelope, which is what would
make every later certification pass vacuously.

## The member count

The count is fixed by a requirement stated over sub-populations, not by the table above,
because the table is one case and the count has to serve cases that do not exist yet. A
case concentrates its amplification on some part of its sites; an ensemble holding none
of that part measures an envelope short by the whole of the difference, and a short
envelope refuses a correct kernel.

Let `p` be the relative size of the sub-population the ensemble must hold at least one
site of, and `alpha` the probability it is allowed to miss it. For `m` sites drawn with
replacement the miss probability is `(1 - p)^m`, so

    m = ceil(log(alpha) / log(1 - p)).

The ensemble draws without replacement, for which the miss probability is smaller, so
this is an upper bound on the count the draw actually needs. The sites are taken in the
radix-2 van der Corput order of the site index, which is a function of the site count
alone, so an envelope measured twice on one case is the same envelope; the probability
above is then over the position of the sub-population in the site list, which must not be
correlated with that order, and the ensemble makes no claim about a sub-population
constructed to sit in its gaps.

`ENSEMBLE_MISS_RATE_RECIPROCAL = 256`, so `p = 1/256`. `ENSEMBLE_CONFIDENCE_RECIPROCAL =
20`, so `alpha = 1/20`. Together they give `ENSEMBLE_MEMBERS = 766` and a detectable miss
rate of `1 - (1/20)^(1/766) = 3.9032401194668553e-3`, one part in 256.1974076390131. That
is the number the registry rows this envelope serves state.

Both inputs are Bracketed, with the measured consequence at each edge.

| constant | bracket | at the bottom | at the top |
|---|---|---|---|
| `ENSEMBLE_MISS_RATE_RECIPROCAL` | `[16, 4096]` | 47 members, shortfall 1.95 on the stand-in, which is a full binary exponent | 12270 members, 16.0 times the declared count, exhausting the stand-in's 2048 sites |
| `ENSEMBLE_CONFIDENCE_RECIPROCAL` | `[5, 1000]` | 412 members, shortfall 1.33 | 1765 members, shortfall 1.00 |

What pushes each down is the same mechanism: a short envelope refuses a correct kernel,
and at 47 members this case's envelope is short by a factor of two. What pushes them up
is cost, which is linear in the member count and logarithmic in the confidence
reciprocal: the whole three-order-of-magnitude confidence bracket moves the count by 4.3
and the measured shortfall by 0.33, while the miss-rate bracket moves the count by a
factor of 261. The declared point sits where the shortfall on the stand-in case has
flattened (1.73 at 256 members, 1.32 at 766, 1.00 at 1765) and the count is still under a
second of work.

The declared rate is finer than the stand-in case needs by a factor of 4.3: the sites
that reach within one binary exponent of its exhaustive envelope are one in 60.2, and at
that rate 766 members would miss them with probability `(1 - 1/60.2)^766 = 3.0e-6`. The
margin is there for a case whose high-amplification sites are rarer than this one's.

The count costs 0.646 s for the stand-in case's 766 members at 20 steps, single-threaded.

## What the ensemble cannot see

The declared miss rate is a relative size, so what it corresponds to in cells shrinks as
a case grows. On the stand-in's 2048 sites one part in 256 is 8 sites. On an icosahedral
mesh at a level with 163842 cells it is 640 sites, which is far larger than the 12 cells
of degree five that decision 0005 puts at every level. An ensemble sized by a relative
miss rate cannot see the pentagons, and a check that they are not a special case has to
be exhaustive over them rather than sampled. That is filed as `fiddlybits-52v.7.17`.

The member set is nevertheless spread rather than clustered, and that part is exact
rather than probabilistic: over a 2048-site population the 766 members taken in
bit-reversed order leave a largest gap of 4 consecutive site indices, so every run of
four consecutive sites holds a member. The first two members leave a gap of 1024. Both
numbers are asserted in `test/certify/member_count.jl`, the second as the control.

## The certification, and the smallest defect it catches

`Backends.certification` runs the candidate at `Float32` and at `Float64` from the same
initial state and compares the two at every step against

    bound(s) = E(s) * initial + sum_{j=1}^{s} E(s - j) * roundoff,   E(0) = 1,

with `E` the measured envelope, `initial` the divergence the initial state already
carries from being rounded to `Float32`, and `roundoff` the divergence one step at
`Float32` injects. `roundoff` has no default and is not defined here: it is
`Reductions.error_bound`, which has exactly one definition in this tree and sits above
`Backends` in the include order, so the caller reads it there and passes it in. For the
stand-in case the caller declares five terms per cell and a magnitude of
`2.8 * (1 + 1/64)`, giving `2048 * error_bound(Float32, 5, 2.84375) = 3.4713745e-3`. The
term count is checked against `Reductions.validity_limit(Float32) = 2^24` before it is
read.

The measured envelope over the 20 steps is

    3.0, 5.0, 5.75, 6.015625, 7.53125, 6.5625, 6.75, 8.5, 8.125, 11.0,
    11.5, 13.0, 11.75, 12.75, 13.75, 15.0, 16.5, 13.75, 13.0, 14.375

and the initial divergence is 4.253610957849485e-5.

The correct `Float32` candidate, which is the case's own step at `Float32`, stays at
0.0237 of the bound at step 1 and falls to 1.16e-4 of it by step 20: PASS with a factor
of 42 in hand at its worst step. The same candidate with its gathers launched through
`Backends.stencil_gather!` on the CUDA backend and its field mixing broadcast on the
device arrays stays at 0.0177 of the bound: PASS, with the whole of both trajectories
computed on the card.

The defect this oracle can see is one the two precisions do not share, because it
compares a kernel against its own double-precision self. Scaling every weight by
`1 + g` in the `Float32` path alone and bisecting on `g`:

| injected relative defect | verdict |
|---|---|
| 1.0e-6 | PASS |
| 2.801418304314791e-6 | PASS |
| 2.8014183043382583e-6 | FAIL |
| 1.0e-5 | FAIL |
| 1.0e-4 | FAIL |

The threshold is 2.8014183e-6, which is 23.5 times `eps(Float32)`. The certification of
this case therefore catches any systematic per-step relative defect above 23.5 single
precision unit roundoffs and does not claim to catch one below it. The same defect at
1.0e-4 applied to the GPU candidate's `Float32` path also fails, which is that suite's
control.

A defect both precisions share is invisible here and passes: scaling every weight by
`1 + 1.0e-4` in both paths certifies PASS. That is not a hole in this oracle but its
boundary, and the reference path of decision 0027 is what stands opposite it. It is
asserted as a control in `test/certify/certification.jl` so the boundary is stated by a
test rather than by prose.

## Every constant, with its disposition

| constant | disposition | derivation |
|---|---|---|
| `ENSEMBLE_MISS_RATE_RECIPROCAL` | Bracketed | 256, in `[16, 4096]`, pushed down by a short envelope refusing a correct kernel and up by a cost linear in the member count, swept above with the measured shortfall at each edge |
| `ENSEMBLE_CONFIDENCE_RECIPROCAL` | Bracketed | 20, in `[5, 1000]`, the same mechanism down and a cost logarithmic in it up, swept above |
| `ENSEMBLE_MEMBERS` | Derived | `ceil(log(1/20) / log(1 - 1/256)) = 766`, from the two above and nothing else |
| `ENSEMBLE_MISS_RATE` | Derived | `1 - (1/20)^(1/766) = 3.9032401194668553e-3`, the inverse of the count rule at the declared count |
| the perturbation size | Derived | `nextfloat(m) - m` for `m` the largest absolute value in the perturbed field, computed per case and never written down |
| the member order | Derived | the radix-2 van der Corput order of the site index, a function of the site count alone |

No number in `src/Backends/certify.jl` is transcribed from a published result, so none is
Sourced. The order-statistic identity `(1 - p)^m` behind the count is elementary and is
derived above rather than cited. `references/pdf/karp2025-robustness-and-uncertainty-direct-numerical-simulation.pdf`
is the one entry in `docs/references/INDEX.md` that bears on this row, and it is marked
`held` and not `read`, so nothing here is anchored to it.

## What this changes

`src/Backends/certify.jl` carries `EnsembleCase`, `Envelope`, `Certification`,
`envelope`, `certification` and `certify`, with `certify` returning `Verdicts.PASS` or
`Verdicts.FAIL` and never a boolean, and `envelope` raising `Verdicts.Refusal` on a case
it cannot measure. `Verdicts.NotEvaluable` is not reachable from either: it is a
`LoopVerdict` and this is an `OracleVerdict` vocabulary, and
`test/certify/envelope.jl` asserts that neither the refusal nor `NotEvaluable` is an
`OracleVerdict`, so a certification that could not be evaluated cannot be read as a pass.

The declared member count and its detectable miss rate belong in the
`repro.backend_ulp_envelope` and `repro.fp32_kernel_certification` rows of
`docs/oracles/registry.toml`, which is outside this row's file boundary. That is filed as
`fiddlybits-52v.7.16`.

## The probes

`/tmp/fb74/probe_norm.jl` measures the two readings of "one ulp" exhaustively;
`/tmp/fb74/probe_full.jl` measures the amplification distribution, the prefix shortfall
sweep, the member set's gaps and the coarse injected-defect sweep;
`/tmp/fb74/probe_gpu.jl` bisects the injected-defect threshold, sweeps the two brackets
and runs the GPU candidate. All three were invoked as
`qrun -p gpu-share -- julia --startup-file=no --project=. <probe>` from the worktree
root. The suite at `test/certify/` carries the same case, the same bound and the
controls named above.
