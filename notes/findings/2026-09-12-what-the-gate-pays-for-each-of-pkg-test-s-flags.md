# The two flags that change what the gate reports cost it nothing; the one that changes what it compiles costs it a factor of 2.2, all of it in certify

Measured on 2026-09-12 on yggdrasil through `qrun` with this repository's defaults
(profile `gpu-share`, one share of an NVIDIA GeForce RTX 4090, 8 CPUs, 16G), Julia
1.12.7, on branch `fiddlybits-52v.1.15` cut from `1406813`. The row is
`fiddlybits-52v.1.15`, raised by
`notes/findings/2026-09-12-the-overwrite-warning-reaches-one-door-of-two.md`, which
measured that `Pkg.test()` passes flags the gate does not.

The three `Pkg.test()` sets and the gate did not are `--warn-overwrite=yes`,
`--depwarn=yes` and `--check-bounds=yes`. The other five it prints are already the
gate's defaults or are about colour and coverage.

## What each configuration costs

Each run is `tools/gate/gate.sh`, eight suites at once, whole tree.

| configuration | wall | sum of suites | certify |
|---|---|---|---|
| the gate as it was | 92.0 s | 377.8 s | 90 s |
| `--warn-overwrite=yes --depwarn=yes` | 90.3 s | 376.7 s | 90.3 s |
| those two and `--check-bounds=yes`, first run | 195.5 s | 498.5 s | 195.5 s |
| the same, run again warm | 199.3 s | 507.2 s | 199.2 s |

The two reporting flags are free: 90.3 against 92.0 is inside the run-to-run spread.

`--check-bounds=yes` is not a precompilation cost. The second run is no cheaper than
the first, and the package warmed in 2.5 s in both.

## Where the bounds-checking cost is

Per suite, the two reporting flags against all three, first run:

| suite | reporting only | with bounds checks | change |
|---|---|---|---|
| certify | 90.3 s | 195.5 s | +105.2 s |
| fields | 19.8 s | 24.0 s | +4.2 s |
| orbit | 16.5 s | 19.8 s | +3.3 s |
| mesh | 28.5 s | 31.1 s | +2.6 s |
| events | 11.1 s | 13.2 s | +2.1 s |
| backends | 76.4 s | 78.6 s | +2.2 s |
| reductions | 60.9 s | 60.5 s | -0.4 s |

`certify` is the critical path in every configuration, so its increase is the whole
of the gate's increase. The seven `@inbounds` sites in the tree are all in
`src/Mesh/hierarchy.jl` and `src/Mesh/geometry.jl`, which is what `certify` exercises
hardest.

## What the gate carries

`--warn-overwrite=yes` and `--depwarn=yes`, in `SUITE_FLAGS` in `tools/gate/run.jl`,
on both the suite processes and the warm-up load.

`--check-bounds=yes` is not carried, and the gap between the doors is now written
down rather than accidental. Decision 0049 makes the gate's wall time a correctness
property bounded by the six minutes the remote leaves an idle connection open, and
`notes/findings/2026-09-12-a-pre-push-gate-longer-than-the-idle-timeout.md` records
that the bound has been crossed once already. Carrying the flag spends 109 seconds of
that budget, taking the margin from 270 seconds to 161, on a tree that is at
milestone m0 and will grow suites rather than shed them.

## What the flags made visible

A warning from a suite that passes goes into a log the gate does not print, so
raising more warnings would have changed nothing on its own. `report` now scans every
suite's log, pass or fail, and refuses the run on any warning line that
`tools/gate/warnings.toml` does not accept with a reason.

The tree writes one warning today, twenty-six times: CUDA.jl's note that this is a
non-official build of Julia, once per process that loads it. It is the one entry in
the record. Emptying the record and re-reporting the same run's logs refuses with all
twenty-six lines named by suite, which is the control that the scan reads real output
and not only its fixtures.
