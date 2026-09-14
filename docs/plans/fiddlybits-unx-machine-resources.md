+++
epic = "fiddlybits-unx"
title = "The clean room and the local gate split on a declared vocabulary of machine resources, so the clean room runs every check it can and names every check it cannot"
decisions = ["0043", "0030", "0025", "0039", "0048", "0049", "0050", "0012"]
requirements = []
oracles = ["build.resource_vocabulary", "build.not_evaluated_accounting", "oracles.dataset_extracts", "build.references_payload_hashes", "oracles.dataset_links", "build.lint_positive_controls"]
status = "filed"
date = 2026-09-14
+++

## Scope

The clean-room job of decision 0043 runs `Pkg.test()` on a hosted runner that has no
card, no dataset payload and no references payload. Nothing in the tree says which checks
need which of those, so every check that reaches the card errors there, and the job has
failed on every completed run since the first card arms merged
(`notes/findings/2026-09-14-the-clean-room-fails-on-the-card-and-on-two-causes-of-its-own.md`).

This plan builds, in order:

- a closed vocabulary of machine resources and one helper that every resource-bound check
  calls, which names a check it could not evaluate rather than erroring or skipping it;
- the accounting in both doors: the one-process door the clean room runs accepts a check
  not evaluated only for a resource the workflow declares absent, and the gate and the
  nightly refuse any;
- the declaration in `.github/workflows/clean-room.yml`;
- the conversion of every device arm;
- distilled dataset extracts, committed where a licence allows, re-derived on the gate;
- a tracked hash manifest of the references payload, which `fiddlybits-f1x`'s lint reads.

It does not move any check off the gate: the gate holds every resource and evaluates
every check. It gives the card no substitute. It fetches no dataset and writes no check
that reads one; those belong to the oracle rows, and this plan fixes the form each takes.
Two clean-room failures have causes of their own, and are carried here because this
plan's acceptance is a green clean room.

## What the clean room shows

Every failing site in the finding is one of three kinds:

- a device arm reaching the card;
- `test/coupling/state.jl` reading a constant the connectivity suite bound earlier in the
  same process;
- `Mesh.arc_length` giving a different last place for a view than for an `SVector` on the
  hosted processor.

No check in the tree reads `oracles/data/`, `inputs/data/` or `references/`. The first
that will are `fiddlybits-f1x`'s `lint_index_files`, the statistics of the tier-2 and
tier-3 entries that name datasets, and `system.gas_mixture_properties`.

Two device arms today are silent skips: an `if CUDA.functional() ... else @info` in
`test/orbit/runtests.jl` and in `test/mesh/stencil_valence.jl`. No runner counts an
`@info`.

## The vocabulary

| name | the resource | the probe finds it present when |
| --- | --- | --- |
| `card` | a CUDA device this process can use | `CUDA.functional()` |
| `oracle_data` | the payload of a manifest under `docs/oracles/data/` | `oracles/data/` exists at the main checkout; for one dataset, the `local_path` its manifest names |
| `input_data` | the payload of a manifest under `docs/inputs/data/` | `inputs/data/` exists at the main checkout; for one dataset, its `local_path` |
| `references` | the untracked payload under `references/` that `docs/references/INDEX.md` names: `references/pdf/` and the source-tree directories index rows name | `references/pdf/` exists at the main checkout |

The vocabulary is closed. A fifth name is an amendment to decision 0043.

**The main checkout** is the parent of `git rev-parse --path-format=absolute
--git-common-dir`. For a worktree under `.beads/worktrees/` that is the checkout the
worktree belongs to, which is where `docs/workflow.md` already says payload is read. For
the clean room's checkout it is the checkout itself. There is one location, so there is
nothing to fall back to.

`references` names the PDFs and the index-named source trees together, because an index
row names either and `lint_index_files` resolves both.

**A probe says only whether a resource is there.** It does not validate it. What a check
reads is validated by the check that reads it: an extract's re-derivation holds its source
files to their sha256, and the hash manifest's disk clauses hold the references payload
to its entries.

## The helper

`test/resources.jl` defines module `Resources`. It is included into `Main` once per
process: by `test/runtests.jl` in the one-process door, and by a suite's own
`isdefined(Main, :Resources)` guard in a suite process. So each process keeps one record,
whichever door started it.

```
VOCABULARY                  (:card, :oracle_data, :input_data, :references)
NotEvaluated                check::String, resource::Symbol, detail::String
requiring(f, resource, check; dataset = nothing)
                            f() once when the probe finds the resource present; otherwise
                            one NotEvaluated recorded, one line written, nothing returned
not_evaluated()             every NotEvaluated this process recorded, in order
parse_line(line)            the NotEvaluated a printed line names, or nothing
declared_absent(value)      the set a whitespace-separated declaration names
probe(resource)             the kind-level probe of the table above
probe(resource, dataset)    the per-dataset probe
main_checkout(root)         as above
with_probes(f, probes)      f with the named probes replaced; positive controls only
```

The line is `not evaluated: <resource>: <check>`, with the dataset id after the resource
for `oracle_data` and `input_data`. It is written to standard output and flushed at the
moment of recording, so a suite process's log carries it whatever happens after.

**Refusals**, each naming what it refused:

- a resource outside `VOCABULARY`;
- a `dataset` on `card` or `references`, or none on `oracle_data` or `input_data`;
- a dataset id with no manifest;
- a check name already used in this process;
- an unknown or repeated name in a declaration;
- git finding no checkout.

A check body that throws under a present resource fails the ordinary way. Recording adds
no `Test` result: the accounting belongs to the runner, which is where it can be judged
against the declaration.

A call looks like this:

```julia
@testset "bitwise mode (decision 0029)" begin
    Resources.requiring(:card, "backends: bitwise mode (decision 0029)") do
        # the arm
    end
end
```

A suite, a file or a lint that needs a resource throughout calls it once at its top, around
the whole of its body.

**The name is `NotEvaluated`, not `Verdicts.NotEvaluable`.** `NotEvaluable` is a
`LoopVerdict`, the closed set a fixed-point loop's exit predicate returns (decision 0009).
`loop_verdicts()` enumerates it and a verdict event carries it, and
`src/Backends/certify.jl` already keeps it out of certification for that reason. A check
not evaluated for want of a machine resource says nothing about the loop, oracle or kernel
it would have checked: it is a fact about the host. Reusing the loop verdict would let a
harness state reach the loop vocabulary and its events. It would also give one name two
meanings: "the criterion is undefined at this state" and "this machine lacks the card".
`NotEvaluated` lives in `test/` because nothing in `src/` has a use for it.

## The runners

### `test/runtests.jl`, the door `Pkg.test()` and the clean room run

1. It includes `test/resources.jl` into `Main` before any suite.
2. It reads `FIDDLYBITS_ABSENT_RESOURCES` once through `declared_absent` and prints the
   declared set. An unset variable declares nothing absent. That is the strictest
   reading, so a missing declaration can only refuse more checks, never excuse one.
3. It refuses a declared resource whose kind-level probe finds it present. A declaration
   that no longer describes the machine is stale, and a stale declaration would excuse a
   check the machine could run.
4. It includes each suite into a module of its own, so no binding one suite makes reaches
   another. `tools/gate/run.jl` already has this isolation from processes
   (decision 0049). This removes the `test/coupling/state.jl` failure. The function that
   runs one suite this way lives in `test/suites.jl` beside `suites`, so a test can run it
   on a scratch root.
5. After the suites, it prints every check not evaluated, under its resource. A testset
   fails naming each check whose resource the declaration does not name.

The per-suite wall-time table stays.

### `tools/gate/run.jl` and `tools/nightly/run.jl`

- Each refuses to start when `FIDDLYBITS_ABSENT_RESOURCES` is set, naming it. These doors
  declare nothing absent.
- `report` reads every suite log for the lines `Resources.parse_line` accepts and prints
  them under their suite and resource. It returns non-zero on any, the way it already
  treats an unaccepted warning.

The gate refuses rather than excuses because it runs on the machine decision 0043 names as
the holder of every resource. A check not evaluated there means a resource went missing on
the one machine that must hold it. A gate run from a shell without a card share, or from
a checkout whose main checkout lacks a payload, is refused by name. That is the point.

## The clean-room declaration

In `.github/workflows/clean-room.yml`, the suite step carries:

```yaml
env:
  FIDDLYBITS_ABSENT_RESOURCES: card oracle_data input_data references
```

The step's `JULIA_CUDA_SOFT_MEMORY_LIMIT` goes, since it configures a device the job does
not have. So do the header's two claims: that device arms check for a card and say so,
and that a check needing a dataset moves to the local gate. The header that replaces them
says what the job runs and names decision 0043 and this plan, as a comment does under
decision 0039. The job's log ends with the declared set and the named list of checks not
evaluated.

## Device arms

How an arm changes:

- The `@test CUDA.functional()` at an arm's head is removed, and the arm's body goes
  inside `Resources.requiring(:card, check)`. On the gate, the runner's refusal of any
  check not evaluated is what now requires the card.
- An `if CUDA.functional() ... else @info ... end` becomes the same call.
- A card read at file top level moves inside the arm that uses it. An example is
  `CUDA.device()` in `test/backends/launch_workgroup.jl`.
- Processor checks that share a testset with a card arm stay outside the call, so the
  clean room evaluates them.
- An arm that runs its card work in a child `julia` calls the helper in the parent, around
  the child's launch. `test/backends/kernel_fault.jl` and `test/backends/bounds_reach.jl`
  are the two such arms.
- The check name is `<suite>: <testset description>`. Where a testset repeats, the loop
  value is added.
- A `Backends.GPU()` built as a declared value that reaches no device is not an arm, as
  in `test/coupling/state.jl`.

| suite | files | row |
| --- | --- | --- |
| backends | `backend_agreement.jl`, `bitwise_mode.jl`, `bounds_reach.jl`, `cross_task_ordering.jl`, `dispatch_refusal.jl`, `host_copy.jl`, `kernel_fault.jl`, `launch_completion.jl`, `launch_workgroup.jl`, `move_adapt.jl`, `move_events.jl`, `transcendentals.jl` | `fiddlybits-d47` |
| reductions | `class_forms.jl`, `column_forms.jl`, `edge_shapes.jl`, `gpu_agreement.jl`, `mixed_precision.jl`, `no_input_sized_temporary.jl`, `partition_independent.jl`, `quantiles.jl`, `segment_moves.jl`, `shared_block_kernels.jl` | `fiddlybits-8we` |
| certify, coupling, fields, kernels, mesh, orbit, provenance | `certify/gpu_certification.jl`, `coupling/exchange.jl`, `fields/adapt_roundtrip.jl`, `fields/inference.jl`, `fields/reduce.jl`, `fields/vectors.jl`, `kernels/body_types.jl`, `mesh/stencil_valence.jl`, `orbit/runtests.jl`, `provenance/rng.jl`, `provenance/run.jl` | `fiddlybits-6xt` |

The clean room itself enforces the rule that every card arm calls the helper: an arm that
reaches the card without it errors there. A clean-room run can be reproduced on the gate
host for one suite:

```
qrun -p light -- julia --project=. -e 'include("test/<suite>/runtests.jl")'
```

`-p light` holds no card share. Under it, every card arm prints its not-evaluated line and
nothing errors.

## Dataset extracts

### What an extract is

- A check that reads a dataset reads a committed extract of exactly the part it reads, in
  both doors. Only the extract's re-derivation reads the payload.
- An extract lives under `oracles/extracts/<manifest id>/` or
  `inputs/extracts/<manifest id>/`, tracked, as plain text, so a diff shows what moved.
  Beside it is a `NOTICE` that its recipe writes, carrying the attribution, the licence
  and the statement of modification the licence requires.
- Every manifest carries three keys:
  - `licence`, the licence by name;
  - `licence_locator`, where it was read;
  - `extract`, either `permitted` or `gate_only`.
- A manifest whose extract is committed also carries a block:

```toml
[extract]
recipe = "oracles/recipes/extracts/<id>.jl"
recipe_sha256 = "<sha256>"
sources = [{ path = "<a path from this manifest's file list>", sha256 = "<its sha256 there>" }]
files = [{ path = "<file under the extract directory>", bytes = 0, sha256 = "<sha256>" }]
```

- The recipe is a Julia file defining `extract(source_dir, out_dir)`, run in the project
  environment. It is deterministic: its output bytes are a function of the named sources
  alone, with no clock, no host and no iteration over an unordered collection. A source in
  a format the project's dependencies cannot read has no extract until a dependency
  admitted through decision 0012's import review can read it. Its checks are `gate_only`
  until then, and are named.
- `oracles.dataset_extracts` re-derives the extract. It calls
  `requiring(:oracle_data or :input_data, ...; dataset = id)`, runs the recipe in a scratch
  directory on the named sources at the main checkout, refuses a source whose sha256
  differs from the block, and compares every output file byte for byte. The clean room
  names that check; the gate runs it.
- Where a manifest says `gate_only`, a check reading that dataset wraps its payload read
  in the helper and is named not evaluated in the clean room.

### The size bound

- **Per extract:** the files of one extract directory hold at most 262144 bytes together.
- **In total:** every extract in the tree holds at most 4194304 bytes.

Both bounds are declared once, in `docs/oracles/extracts.toml`.

`oracles.dataset_extracts` counts bytes from the files on disk, not from the manifests. It
refuses any file under an extracts directory that no block names, so nothing escapes the
count.

The per-extract bound admits a table of a few thousand short rows. That is the shape the
registry's statistics read: a zonal profile, per-class means, a site list, a set of
thermochemical records. It refuses a raster. The total keeps the extracts a small part of
the tracked tree, which every clone carries. An extract changes only with its recipe or its
sources, because the re-derivation holds it to both, so its history grows only when what
it distils does.

Raising either bound is an amendment to decision 0043, not an edit to the TOML alone.

### Per manifest

No check in the tree reads any of these yet. The entries column names the registry entries
whose statistics will. The row that writes one of those statistics also writes its
extract, or wraps its payload read, as the manifest's `extract` key says.
`fiddlybits-a0z` transcribes the three keys into every manifest.

| manifest | entries that read it | licence | locator | extract |
| --- | --- | --- | --- | --- |
| `aus-groundwater` | `earth.fan_water_table` | per data owner: the Bureau of Meteorology's material is CC BY 4.0; each state agency sets its own terms, some Creative Commons, some requiring contact | each zip's `gw_state_README.txt`, section COPYRIGHT, which defers to https://www.bom.gov.au/water/groundwater/explorer/copyright.shtml | `gate_only` until the per-owner licence table is read |
| `copernicus-dem-90m` | `earth.hydrolakes_terminal_lakes` | Copernicus DEM licence, annex for COP-DEM-GLO-90-F | https://dataspace.copernicus.eu/sites/default/files/media/files/2025-06/copernicus_contributing_mission_data_access_v2_cop_dem_licenses.pdf, GLO-90-F annex, Articles 3, 4 and 6 | `permitted`; the NOTICE carries Article 6's adapted-product notice, its no-liability sentence, and the obligations that pass to a recipient |
| `etopo2022` | `terrain.hypsometry_scale_matched`, `terrain.hypsometry_profile`, `terrain.channel_concavity`, `terrain.hypsometric_integral_distribution` | CC0-1.0 | NCEI ISO metadata record `gov.noaa.ngdc.mgg.dem:etopo_2022`, fields License and Use Constraints | `permitted`; the NOTICE carries the recommended citation |
| `mcd12c1` | `earth.modis_albedo_by_class` | CC0, under the EOSDIS Data Use and Citation Guidance | https://www.earthdata.nasa.gov/data/catalog/lpcloud-mcd12c1-061, Use Constraints | `permitted`; the NOTICE carries the requested citation |
| `mcd43c3` | `earth.modis_albedo_by_class` | CC0, under the EOSDIS Data Use and Citation Guidance | https://www.earthdata.nasa.gov/data/catalog/lpcloud-mcd43c3-061, Use Constraints | `permitted`; the NOTICE carries the requested citation |
| `nwis-gw` | `earth.fan_water_table` | US public domain for USGS-authored or USGS-produced data | https://www.usgs.gov/information-policies-and-instructions/copyrights-and-credits | `permitted` for records whose agency is USGS; records other agencies supplied stay out of an extract |
| `rgi-v7` | `earth.rgi_glacier_area` | CC BY 4.0 | https://www.glims.org/rgi_user_guide/01_introduction.html, data distribution policy | `permitted`; the NOTICE carries the attribution, the citation, the licence link and the statement of modification |
| `seaice-index-v4` | `earth.sea_ice_extent` | NSIDC use constraints: available to use without restrictions, provided the recommended citation is given; no named licence | https://nsidc.org/data/g02135/versions/4, citation and use; CMR UseConstraints of G02135 | `permitted`; the NOTICE carries the citation and the subset's description |
| `burcat-ruscic-thermochemical` | `system.gas_mixture_properties` | the database's own terms: free of charge with proper quotation; sale and listing in any commercial publication forbidden without the author's written agreement | payload `READ.ME.txt`, lines 45 to 50 and 210 | `gate_only`: a public repository cannot carry the non-commercial condition onward |
| `ecostress-spectral-library` | none yet; a model input | Copyright California Institute of Technology, all rights reserved; no grant of redistribution | https://speclib.jpl.nasa.gov/, the copyright and citation text of the home page | `gate_only` |
| `nasa-cea-thermo` | none yet; a model input | Apache-2.0 | payload `NOTICE.txt` lines 1 to 10, `LICENSE.txt` section 4 | `permitted`; the extract carries the licence, the NOTICE text and a statement of modification |
| `usgs-splib07` | none yet; a model input | US public domain; the use constraint requires a description of any modification | payload `USGS_Spectral_Library_Version_7_Data.xml`, `useconst` | `permitted`; the NOTICE states the selection rule |

## The references hash manifest

- **The file.** `docs/references/payload.toml` holds:
  - `[[file]]` entries, `path` (relative to `references/`), `bytes` and `sha256`, for every
    regular file under `references/pdf/`, in path order;
  - `[[tree]]` entries, `path`, `files`, `bytes` and `digest`, for every directory under
    `references/` that an index row names. `digest` is the sha256 of the sorted lines
    `<path> <bytes> <sha256>` of every regular file beneath the directory, leaving out a
    `.git` directory. A directory that is a git checkout also carries `commit`, which its
    `HEAD` must equal.
- **No content.** A filename, a size and a digest are not the work. The index already
  publishes the filename and the verbatim title. The payload stays untracked, as decision
  0030 decides.
- **The writer.** `tools/references/payload_manifest.jl` writes the file from the main
  checkout's payload, in the project environment. At ingest (`docs/references/README.md`)
  it runs, and the manifest is committed with the index row that moves to `held`.
- **The check.** `build.references_payload_hashes` runs the manifest clauses everywhere.
  The disk clauses run inside one `requiring(:references, ...)` around the part of the file
  that holds them, so the clean room names them and the gate runs them.
- **The cost.** The gate compares bytes and sha256 through a digest cache under the main
  checkout's git directory, keyed by path, bytes, modification time, change time and
  inode. It re-hashes a file whose key moved. No ordinary write leaves change time where
  it was, and that is the trust git's own index extends to a working tree. The check is as
  strict as re-hashing every file, and does not spend the gate's bounded wall time
  (decision 0049) re-reading a payload that did not change.
- **With `fiddlybits-f1x`.** `lint_index_files` resolves each `held` or `read` row's
  filename against `payload.toml`:
  - a `[[file]]` entry for a name under `references/pdf/`;
  - a `[[tree]]` entry for a directory;
  - the manifest under `docs/oracles/data/` or `docs/inputs/data/` for a dataset row.
  It never reads the disk, so it runs in both places with nothing to excuse. The disk half
  of that row's question is this check's gate clause. So "a run without the references
  payload is refused by name" is carried by `build.references_payload_hashes` through the
  helper, and `fiddlybits-f1x` depends on `fiddlybits-0b5`.

## The two failures with another cause

- **The one-process collision.** `test/coupling/state.jl` reads `CF` as the connectivity
  fixtures because `test/connectivity/topology_event.jl` bound that constant in `Main`
  first. Running each suite in a module of its own removes the class, not only this case.
  `fiddlybits-zyo` carries it with the runner, since both change how `test/runtests.jl`
  runs a suite.
- **`Mesh.arc_length` on the hosted processor.** `Mesh.geometry` stores each primal edge
  length computed from `SVector{3,Float64}` columns, and `test/mesh/location.jl` compares
  it with `Mesh.arc_length` of views of the same columns. On the hosted processor the two
  differ in the last place. One definition gives one answer whatever vector type its
  caller holds. `fiddlybits-ssw` establishes which operation differs, reproduces the
  disagreement off the hosted runner, and makes `arc_length` and `great_circle_midpoint`
  compute through one arithmetic without moving what `Mesh.geometry` stores.

## Alternatives weighed

- **A suite-level declared list.** Under this alternative, a TOML or a constant in
  `test/suites.jl` names the suites or files the clean room skips. It lost on three
  counts:
  - Card arms sit inside the same files and testsets as processor checks (`quantiles.jl`,
    `orbit/runtests.jl`, `fields/inference.jl`), so a cut at the suite or file would drop
    processor checks from the clean room or force files to split by resource.
  - The list lives apart from the checks, so a new card arm in a listed-as-clean file
    passes unseen until the clean room fails, and a listed file keeps being skipped after
    its last card arm is gone.
  - It can name only what it skipped, never the checks inside, so the clean room cannot
    print what it did not evaluate at the grain a reader acts on. The gate gains nothing
    either: the list says nothing about a resource missing on the gate host.
- **Per-arm checks without a shared helper.** This is what the tree does today: a
  `@test CUDA.functional()` at an arm's head in most arms, and an `if ... else @info` in
  two. It lost because there is no single place to record a check not evaluated, to
  print it, or to judge it against a declaration. Each arm words its own message, the
  gate cannot refuse uniformly, and datasets and references would each grow a variant of
  their own.
- **A separate CI job.** A second job, or one job per resource, would run only the checks
  the hosted runner can run. It lost because a job still has to decide what it runs, which
  is the question the helper answers, so it needs the list or the helper anyway. It also
  pays package setup and precompilation once per job, and it still cannot separate a card
  arm from the processor checks beside it. A self-hosted card job is the alternative
  decision 0043 already rejected.
- **`Verdicts.NotEvaluable` as the result.** Lost for the reasons under The helper.
- **A probe with no declaration.** Under this alternative the clean room accepts any check
  not evaluated. It lost because a resource the clean room ought to have would go missing
  silently: an extract directory not checked out, or a probe broken by an edit.
  Declaring what the job lacks makes the excused set a thing that can be read, and the
  stale-declaration refusal checks it in the other direction.
- **The dataset payload fetched per run, or held in Git LFS.** Decision 0043 already
  rejected fetching per run. LFS redistributes the same bytes under the same licences,
  so it settles none of the licence question. It also puts the whole payload behind a
  transfer quota the clean room would draw on every run.

## Module boundaries

| path | holds | row |
| --- | --- | --- |
| `test/resources.jl`, `test/resources/` | the helper and its controls | `fiddlybits-qwi` |
| `test/runtests.jl`, `test/suites.jl`, `tools/gate/run.jl`, `tools/nightly/run.jl`, `test/gate/`, `.github/workflows/clean-room.yml`, `docs/workflow.md` | the accounting in both doors, the per-suite module, the declaration | `fiddlybits-zyo` |
| `test/backends/` | the backends suite's card arms | `fiddlybits-d47` |
| `test/reductions/` | the reductions suite's card arms | `fiddlybits-8we` |
| the files of the third device table row | the remaining card arms and the two silent skips | `fiddlybits-6xt` |
| `src/Mesh/geometry.jl`, `test/mesh/location.jl` | one answer from `arc_length` and `great_circle_midpoint` for any vector type | `fiddlybits-ssw` |
| `test/datasets/extracts.jl`, the manifests' licence keys, `docs/oracles/extracts.toml` (this plan) | extracts and their bound | `fiddlybits-a0z` |
| `docs/references/payload.toml`, `tools/references/payload_manifest.jl`, `test/references/` | the references hash manifest | `fiddlybits-0b5` |

`Resources` depends on `CUDA` and `TOML` and on nothing in `src/`.

## Oracles

Each entry is in `docs/oracles/registry.toml`, merged with this plan ahead of its code.

- **`build.resource_vocabulary`.** The helper on every vocabulary name, under a present
  probe and an absent one, and every refusal.
  - Right answer: the body runs exactly when the probe finds the resource present, and an
    absent resource yields exactly one record and one line.
  - Mutation: the helper returning without recording must fail it.
- **`build.not_evaluated_accounting`.** Both doors on scratch roots of fixture suites.
  - Right answer: the one-process door fails exactly when a check not evaluated names an
    undeclared resource or the declaration is stale or unknown; the gate and the nightly
    fail on any check not evaluated; two suites binding one name both pass in one process.
  - Mutation: a runner that drops the printed list, or excuses an undeclared resource,
    must fail it.
- **`oracles.dataset_extracts`.** Licence keys, extract blocks, the files on disk, the
  bound and re-derivation.
  - Right answer: an extract matches its block byte for byte, and its recipe on the named
    sources reproduces it.
  - Mutation: one byte changed in an extract, or in a fixture payload, must fail it.
- **`build.references_payload_hashes`.** The manifest's shape everywhere, and the disk
  where the payload is.
  - Right answer: every entry's bytes and sha256 equal the file's.
  - Mutation: one byte of one fixture file changed, and a rewritten file with its size and
    modification time restored, must fail it.
- **`oracles.dataset_links`** and **`build.lint_positive_controls`** stay green through
  every row.

The plan as a whole is decided by `fiddlybits-hmt`:

- The clean-room run on `main` completes green.
- Its log prints the declaration it read and every check not evaluated, by name and under
  a declared resource.
- The gate on `main` evaluates every check.

## Rows filed

| row | tier | boundary | acceptance | depends on |
| --- | --- | --- | --- | --- |
| `fiddlybits-qwi` | sonnet | `test/resources.jl`, `test/resources/` | `build.resource_vocabulary` | none |
| `fiddlybits-zyo` | sonnet | `test/runtests.jl`, `test/suites.jl`, `tools/gate/run.jl`, `tools/nightly/run.jl`, `test/gate/`, `test/nightly/`, `.github/workflows/clean-room.yml`, `docs/workflow.md` | `build.not_evaluated_accounting`; the coupling suite passes after connectivity in one process | `fiddlybits-qwi` |
| `fiddlybits-d47` | sonnet | `test/backends/` | every card arm named under `qrun -p light`, none on the gate | `fiddlybits-qwi`, `fiddlybits-zyo` |
| `fiddlybits-8we` | sonnet | `test/reductions/` | as `fiddlybits-d47` | `fiddlybits-qwi`, `fiddlybits-zyo` |
| `fiddlybits-6xt` | sonnet | the eleven files of the third device table row and their suites' `runtests.jl` | as `fiddlybits-d47`, and no `@info` skip remains | `fiddlybits-qwi`, `fiddlybits-zyo` |
| `fiddlybits-ssw` | frontier | `src/Mesh/geometry.jl`, `test/mesh/location.jl`, one new test file, one finding | one answer for Vector, view and SVector, with the reproduction as positive control; geometry bytes unchanged | none |
| `fiddlybits-a0z` | sonnet | `test/datasets/`, the manifests' three licence keys, `docs/oracles/README.md`, `docs/inputs/README.md` | `oracles.dataset_extracts`, `oracles.dataset_links` | `fiddlybits-qwi` |
| `fiddlybits-0b5` | sonnet | `docs/references/payload.toml`, `docs/references/README.md`, `tools/references/payload_manifest.jl`, `test/references/` | `build.references_payload_hashes` | `fiddlybits-qwi` |
| `fiddlybits-hmt` (verify) | sonnet | notes, and a finding if a measurement is recorded | the clean-room run on `main` green and naming its checks not evaluated; the gate on `main` naming none | every row above |

`fiddlybits-f1x` depends on `fiddlybits-0b5`.
