#!/usr/bin/env sh
# The whole suite, through the scheduler, on the machine that holds the data and the
# card. Decision 0043. Blocks and exits with the suite's own status.
#
# Every suite runs in its own process, as many at once as the scheduler gave the job
# CPUs. $SLURM_CPUS_PER_TASK is passed rather than read inside the driver, and never
# nproc, which counts both SMT siblings of the whole physical cores a job is given
# (~/.claude/CLAUDE.md).
#
# The wall time is a correctness question and not a convenience one: git holds the
# remote connection open for the length of a pre-push hook and the far end closes an
# idle session at six minutes, so a gate slower than that makes every push fail.
# notes/findings/2026-09-12-a-pre-push-gate-longer-than-the-idle-timeout.md has the
# measurement and notes/findings/2026-09-12-the-gate-in-parallel.md has what this
# costs now.
#
# `julia --project -e 'using Pkg; Pkg.test()'` runs the same suites in one process in
# order and stays the door a person reaches for; both read their suite list from
# test/suites.jl, and both pass --warn-overwrite=yes and --depwarn=yes so that a
# warning reaches whichever door is run. Not --check-bounds=yes, which Pkg.test also
# sets: it costs the gate a factor of 2.2, measured in
# notes/findings/2026-09-12-what-the-gate-pays-for-each-of-pkg-test-s-flags.md.
#
# A warning no entry of tools/gate/warnings.toml accepts refuses the run, so a
# warning is read once and then either fixed or written down with its reason.
set -eu
root=$(git rev-parse --show-toplevel)
cd "$root"
exec qrun -p gpu-share -c 8 -m 16G -t 00:30:00 -n fiddlybits-gate -- \
  sh -c 'julia --startup-file=no --project=. tools/gate/run.jl "$SLURM_CPUS_PER_TASK"'
