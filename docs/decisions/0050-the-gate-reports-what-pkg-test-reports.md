+++
id = "0050"
title = "The gate carries the flags that change what a suite reports and not the one that changes what it compiles, and refuses on a warning it has not been told to accept"
status = "proposed"
date = 2026-09-12
amends = [{ record = "0049", what = "what a suite process carries beyond the defaults, and what the gate does with a warning from a suite that passed: the two doors are made to report the same things, and the one flag they still differ on is named with its cost" }]
+++

## Decision

**A suite process carries `--warn-overwrite=yes` and `--depwarn=yes`.** `Pkg.test()`
sets both and the gate set neither, so a method silently overwritten in `Main` was
reported by the door a person reaches for and not by the door every commit and every
push goes through
(`notes/findings/2026-09-12-the-overwrite-warning-reaches-one-door-of-two.md`). Both
flags are in `SUITE_FLAGS` in `tools/gate/run.jl` and are carried by the warm-up load
as well as the suites, so the configuration precompiled is the configuration run.

**A warning refuses the run unless `tools/gate/warnings.toml` accepts it with a
reason.** Raising more warnings changes nothing on a door that prints a suite's output
only when the suite fails, so `report` scans every suite's log, pass or fail. An entry
in the record carries a pattern and the reason the warning stands; an entry missing
either refuses, because an exclusion nobody can review is not an exclusion. This is
the shape the lints already use for what they exempt.

**A suite process does not carry `--check-bounds=yes`, and the two doors therefore
compile differently.** This is the one flag that changes what is compiled rather than
what is reported: it forces bounds checks on where `@inbounds` elides them, so the
gate would stop exercising the form of the code that actually runs. It also costs the
gate a factor of 2.2, essentially all of it in `certify`
(`notes/findings/2026-09-12-what-the-gate-pays-for-each-of-pkg-test-s-flags.md`).
Decision 0049 makes the gate's wall time a correctness property bounded by the six
minutes the remote leaves an idle connection open, and that bound has been crossed
once already
(`notes/findings/2026-09-12-a-pre-push-gate-longer-than-the-idle-timeout.md`). The
difference between the doors is written here so that it is a decision rather than an
oversight, which is what it was until this record.

## Alternatives considered

- **Carry all three flags, so the doors agree completely.** The cleanest rule, and
  the one the row was filed expecting. Rejected on the budget: the flag spends 109
  seconds of a 360 second bound, taking the margin from 270 seconds to 161, on a tree
  at milestone m0 whose suite list grows with every component. The margin is for the
  suites not yet written, not for a constant factor. It covers seven `@inbounds`
  sites, all in `src/Mesh`, and the serial door still exercises them.
- **Carry `--check-bounds=yes` on some suites and not others.** Would buy most of the
  coverage for a few seconds, since the cost is almost entirely one suite. Rejected
  for the reason decision 0049 rejected selecting suites by changed paths: a map from
  suite to semantics is a thing that can be wrong silently, and a suite would then be
  compiled one way by the gate and another way by the door beside it with nothing
  saying which.
- **Print warnings rather than refusing on them.** Rejected: a warning printed on a
  passing run is the state this record exists to leave. The gate prints fourteen
  suites and their times, and a line among them is a line nobody reads.
- **Refuse on any warning, with no record of accepted ones.** Not possible today.
  CUDA.jl warns once per process that this is a non-official build of Julia, which is
  about the distribution and not about this tree, so the gate would refuse every run.

## Consequences

- A dependency that starts warning stops the gate until someone reads the warning and
  either fixes it or writes down why it stands. That is the intended weight: the gate
  is the pre-push hook.
- The two doors compile differently, so a bug that only bounds checking catches is
  caught by `Pkg.test()` and not by the gate. Anyone who runs only the gate does not
  have that coverage.
- If the gate's wall time is ever brought well under the bound, or `certify` is made
  cheap, carrying `--check-bounds=yes` becomes affordable and this record is the thing
  to revisit.
