#!/bin/bash
# Find the pages that were read sideways, and write the list the repair pass consumes.
#
#   tools/references/ocr_audit_rotation.sh
#
# Examines every page of every file recorded as read before the reading recipe turned pages upright, and writes
# references/work/repair_list.txt as `filename<TAB>page,page,...`. Needs no GPU, so it runs alongside the reading
# rather than after it; the reading chain waits on the references/work/audit_done marker this script writes.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
PY=${CHANDRA_PYTHON:-$HOME/.venvs/chandra-vllm/bin/python}
WORK="$ROOT/references/work"; mkdir -p "$WORK"
# Rendered pages go to disk, not to RAM. /tmp here is a tmpfs, and since the audit renders every page of every file it examines,
# the default temporary directory turns a large book into gigabytes of resident memory and the machine
# swaps: throughput fell to a third of its rate with the card still reading 100 percent busy.
export TMPDIR="$WORK/tmp"; mkdir -p "$TMPDIR"
CORES=${AUDIT_CORES:-8}
rm -f "$WORK/audit_done"
qrun -p light -m 12G -c "$CORES" -t 8:00:00 -- "$PY" tools/references/audit_orientation.py \
  "$WORK/repair_list.txt" --workers "$CORES" 2>&1 | grep -iE 'sideways|were read before|done|Traceback|Error'
touch "$WORK/audit_done"
echo "=== $(date +%H:%M:%S) rotation audit complete"
