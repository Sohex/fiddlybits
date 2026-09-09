#!/bin/bash
# Read the scanned originals with Chandra, in order, through the scheduler.
#
#   tools/references/ocr_read_chain.sh            # the whole chain, blocking
#
# Pass 2 is the scanned originals whose publisher text layer this project replaces; pass 3 the scans that arrived
# later; the repair pass re-reads only the pages tools/references/audit_orientation.py found sideways in files read
# before the recipe turned pages upright. Each pass is resumable from references/text/manifest.jsonl, so an
# interrupted chain is restarted by running it again.
#
# The reader is an HTTP client of a Chandra server that must already answer on 127.0.0.1:8000; the chain waits for
# it rather than starting one, because the server may be run outside the scheduler. Orientation is tesseract on the
# job's own cores (see chandra_pages.py), which is why the passes ask for many: with too few, the card idles while
# a file's pages are being turned.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
PY=${CHANDRA_PYTHON:-$HOME/.venvs/chandra-vllm/bin/python}
WORK="$ROOT/references/work"; mkdir -p "$WORK"
# Rendered pages go to disk, not to RAM. /tmp here is a tmpfs, and since the reader renders every page of a file before sending it,
# the default temporary directory turns a large book into gigabytes of resident memory and the machine
# swaps: throughput fell to a third of its rate with the card still reading 100 percent busy.
export TMPDIR="$WORK/tmp"; mkdir -p "$TMPDIR"
CORES=${OCR_CORES:-20}; MEM=${OCR_MEM:-20G}
say() { echo "=== $(date +%H:%M:%S) $*"; }

say "waiting for the Chandra server on 127.0.0.1:8000"
until curl -s --max-time 5 127.0.0.1:8000/metrics >/dev/null; do sleep 60; done

say "pass 2: the scanned originals"
qrun -p light -m "$MEM" -c "$CORES" -t 12:00:00 -- "$PY" tools/references/chandra_pages.py \
  tools/references/scanned_native_layer_files.txt --method vllm --batch 16 --resume 2>&1 |
  grep -iE 'pages \(|Traceback|Error|done|OOM'

say "pass 3: the scans that arrived later"
qrun -p light -m "$MEM" -c "$CORES" -t 10:00:00 -- "$PY" tools/references/chandra_pages.py \
  tools/references/chandra_pass3_files.txt --method vllm --batch 16 --resume 2>&1 |
  grep -iE 'pages \(|Traceback|Error|done|OOM'

say "waiting for the rotation audit's repair list"
until [ -f "$WORK/audit_done" ]; do sleep 60; done
if [ -s "$WORK/repair_list.txt" ]; then
  say "repair pass: the pages read sideways"
  qrun -p light -m "$MEM" -c "$CORES" -t 8:00:00 -- "$PY" tools/references/chandra_pages.py \
    "$WORK/repair_list.txt" --repair --method vllm --batch 16 2>&1 | grep -iE 'repaired|Traceback|Error|done'
else
  say "no sideways pages to repair"
fi
say "reading chain complete"
