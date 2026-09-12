+++
id = "0050"
title = "The gate carries the flags that change what a suite reports and not the one that changes what it compiles, that one goes to the nightly bed, and a warning the gate was not told to accept refuses the run"
status = "proposed"
date = 2026-09-12
amends = [{ record = "0049", what = "what a suite process carries beyond the defaults, and what the gate does with a warning from a suite that passed: the two doors are made to report the same things, and the one flag they still differ on is named with its cost" }, { record = "0043", what = "the first tenant of the nightly row, and what the row is worth: the whole tree under --check-bounds=yes, which is checks inside the dependencies now that this tree elides none of its own" }]
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

**A suite process does not carry `--check-bounds=yes`. The nightly bed runs the whole
tree with it, against `main`.** This is the one flag that changes what is compiled
rather than what is reported: it forces bounds checks on where `@inbounds` elides
them, so the gate would stop exercising the form of the code that actually runs. It
also costs a factor of 2.2, essentially all of it in `certify`
(`notes/findings/2026-09-12-what-the-gate-pays-for-each-of-pkg-test-s-flags.md`).
Decision 0049 makes the gate's wall time a correctness property bounded by the six
minutes the remote leaves an idle connection open, and that bound has been crossed
once already
(`notes/findings/2026-09-12-a-pre-push-gate-longer-than-the-idle-timeout.md`).
Nothing bounds a nightly, so the coverage goes to the row decision 0043 already
declares for what is too slow per commit, rather than nowhere. `tools/nightly/run.jl`
runs it; the subject is `main` with a clean tree and the driver refuses anything else,
because a run against a working tree is not one the next night can be compared with.

**This tree elides no bounds check of its own.** The seven `@inbounds` annotations in
`src/Mesh`, three of them unchecked writes at a counter-derived index, were measured
and bought nothing: their removal is inside the run-to-run spread of the suite that
exercises them hardest
(`notes/findings/2026-09-12-what-seven-inbounds-annotations-buy.md`). They are gone,
so the shipped form is checked at those sites on every run rather than under a test
flag, which no configuration of the two doors could have given. `nightly` asserts that
no source file carries the annotation, so the position is held rather than assumed.

That also settles what the flag is now for. Of what `--check-bounds=yes` cost on
`certify`, 96 per cent was checks inside Base, StaticArrays and CUDA, not this tree.
Worth having, worth much less per second than a check in code being written here, and
correctly placed on a nightly.

## Alternatives considered

- **Carry all three flags on the gate, so the doors agree completely.** The cleanest
  rule, and the one the row was filed expecting. Rejected on the budget: the flag
  spends 109 seconds of a 360 second bound, taking the margin from 270 seconds to 161,
  on a tree at milestone m0 whose suite list grows with every component. The margin is
  for the suites not yet written, not for a constant factor.
- **Decline the flag and leave it at that.** The first version of this record did
  exactly that, which left the coverage on a door nobody opens by default. A decision
  that declines something has to say where the thing it declined goes.
- **Keep the seven annotations and rely on the flag to check them.** Rejected once
  they were measured: they buy nothing, and removing them protects the running binary
  rather than a test configuration. An optimisation nobody measured, with no record
  arguing for it, is what this tree calls tuned.
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
- The gate and the nightly compile differently, and that is now the point rather than
  an accident: the gate exercises the form that ships, the nightly exercises the form
  with every check restored, and each is run where its cost fits.
- A bug inside a dependency that only bounds checking catches is caught a night late
  rather than at the push. That is the trade the wall-time bound forces.
- The gate runs each suite against the project and `Pkg.test()` runs them in a sandbox
  built from `[targets]`, so the gate cannot see a test that imports a package the
  test target does not declare. It passed on one while this record was being written.
  Nothing here changes that: the clean-room job of decision 0043 runs `Pkg.test()` on
  every push and is what catches it. Making the gate see it would mean running the
  sandbox per suite, which is the cost decision 0049 removed.
- The nightly bed exists as of this record and has other tenants coming: thread-count
  bitwise and the backend envelope from decision 0043, and JET from its own row.
  Adding one is adding a call, not standing up a bed.
- If the gate's wall time is ever brought well under the bound, or `certify` is made
  cheap, carrying `--check-bounds=yes` on the gate becomes affordable and this record
  is the thing to revisit.
