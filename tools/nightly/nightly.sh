#!/usr/bin/env sh
# The nightly bed of decision 0043, through the scheduler, on the machine that holds
# the data and the card. Blocks and exits with the run's own status.
#
# The whole tree under --check-bounds=yes, which decision 0050 keeps off the per-commit
# gate: the gate's wall time is bounded by the remote's idle timeout and nothing bounds
# a nightly. notes/findings/2026-09-12-what-the-gate-pays-for-each-of-pkg-test-s-flags.md
# has what the flag costs.
#
# The subject is main with a clean tree; the driver refuses anything else rather than
# running against a working tree nobody can compare with.
#
# Walltime is generous rather than tight: this is not the pre-push path, and a nightly
# killed at its limit tells you nothing about the night.
set -eu
root=$(git rev-parse --show-toplevel)
cd "$root"
exec qrun -p gpu-share -c 8 -m 16G -t 02:00:00 -n fiddlybits-nightly -- \
  sh -c 'julia --startup-file=no --project=. tools/nightly/run.jl "$SLURM_CPUS_PER_TASK"'
