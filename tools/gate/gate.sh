#!/usr/bin/env sh
# The whole suite, through the scheduler, on the machine that holds the data and the
# card. Decision 0043. Blocks and exits with the suite's own status.
set -eu
root=$(git rev-parse --show-toplevel)
cd "$root"
exec qrun -p gpu-share -c 8 -m 16G -t 00:30:00 -n fiddlybits-gate -- \
  julia --startup-file=no --project=. -e 'using Pkg; Pkg.test()'
