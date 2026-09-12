+++
id = "0049"
title = "The gate runs its suites as concurrent processes, and its wall time is a correctness property bounded by the remote's idle timeout"
status = "accepted"
date = 2026-09-12
amends = [{ record = "0043", what = "how the gate runs the suite: every suite in its own process, as many at once as the job has CPUs, rather than every suite in one process in order; and why the gate's wall time is now a bounded property rather than a convenience" }]
+++

## Decision

**The gate runs each suite in its own process.** `tools/gate/run.jl` discovers the
suites, starts one `julia` per suite, and runs as many at once as the job was given
CPUs. `julia --project -e 'using Pkg; Pkg.test()'` still runs the same suites in one
process in order and is the door a person reaches for. Both read their suite list from
`test/suites.jl`, so a suite cannot exist for one door and not the other.

**The worker count is stated, never inferred.** `tools/gate/gate.sh` passes
`$SLURM_CPUS_PER_TASK` and the driver refuses a missing, unparseable or non-positive
count rather than reading the machine. A job is given whole physical cores and `nproc`
reports both SMT siblings of each, so a driver that sized itself would oversubscribe
every core it was given.

**The gate's wall time is a correctness property with a stated bound.** `git push`
opens its connection to the remote before running `pre-push` and holds it for the
hook's whole duration; the remote closes an idle session at about six minutes, and a
gate slower than that makes every push die on SIGPIPE with nothing printed
(`notes/findings/2026-09-12-a-pre-push-gate-longer-than-the-idle-timeout.md`). The gate
is therefore bounded by that window, not merely preferred to be fast, and every run
prints its per-suite wall times so the bound can be watched rather than assumed.

**A suite may not depend on what ran before it.** Process isolation makes that true by
construction, and the measurement says it is also most of the speedup: `certify` fell
from 360.6 seconds to 151.0 by being moved into its own process, before any parallelism
was applied to it, because its collection cost was a function of thirteen prior suites'
live fixtures (`notes/findings/2026-09-12-the-gate-in-parallel.md`).

**Parallelism never reaches a result.** This is decision 0029's rule, applied to the
gate and to the kernels it runs. The driver's schedule cannot change which suites run
or how many times, and each suite is a process that shares nothing. Inside
`Backends.measure_envelope`, one task per injection step writes one row of the gain
matrix and no other, so there is no shared accumulator; a refusal raised in a task is
held and rethrown after every task finishes, lowest injection step first, so which
refusal a caller sees is a function of the case. The equality is asserted, not argued:
`certify.envelope_does_not_depend_on_its_partition`.

**A case's step must be safe to call concurrently on distinct states.** That is a new
line in the `EnsembleCase` contract, and a step that reads only its own argument and
allocates its own temporaries already satisfies it.

## Alternatives considered

- **Narrow the gate to the suites a branch's changed paths reach.** The original shape
  of the row. Not taken, and now not needed: a selection spends trust to buy time, since
  a map that misses the one suite a change breaks fails silently, which is worse than a
  slow gate because it is invisible. Parallelism costs nothing in trust and was enough.
  If the gate ever outgrows the window again, this is still the next thing to consider,
  and it would then be built on a parallel suite rather than to rescue a serial one.
- **Reduce what is tested.** Shortening the mesh certification case would have bought
  the same minute by checking a shorter trajectory. Rejected: the row exists because the
  suite is slow, not because it checks too much.
- **A keepalive on the push.** `ssh -o ServerAliveInterval=30` keeps the session warm
  across a slow hook and would have made the symptom go away without touching the cause.
  Rejected: a hook that holds a remote connection open for the length of a full test run
  is the defect.
- **Move the whole-suite backstop to `pre-commit`, or delete it.** Both were put to the
  user on 2026-09-12 and declined: the first makes every commit that stages source pay
  the full wall time and inverts the economics `docs/workflow.md` is written around, and
  the second leaves no hook-level backstop. Both were answers to the gate being slow,
  and this record removes the premise.
- **Classify which suites take the card and give them a lane of their own.** Prepared
  and not built: all seven card-touching suites ran concurrently at the profile's default
  video memory cap with no refusal, so the classification would have bought nothing and
  gone stale silently.
- **A thread budget shared out across workers.** Rejected for giving every worker the
  whole budget. An unused thread costs a stack, only one suite spends them, and that
  suite is the last to finish and has the machine to itself for most of its run.

## Consequences

- The gate is 89.2 seconds against a 507.4-second serial run, four times inside the
  window rather than 1.41 times outside it. The interim arrangement of pushing with
  `--no-verify` ends: `pre-push` runs the gate again and completes inside the window.
- Every gate run prints its per-suite wall times, so a suite that starts to dominate is
  visible in the run that first pays for it rather than in a later investigation.
- A new suite is a new directory with a `runtests.jl`, as before, and now also a new
  process. A suite that leaks state into another can no longer be written by accident.
- The cost of a suite is now measured with its own process start, 4.7 seconds of package
  load, included. Small suites read as more expensive than they were and that number is
  real: it is what running them in isolation costs.
- `EnsembleCase` carries one more line of contract, and a step that captures a shared
  buffer is now a defect rather than a working oddity.
