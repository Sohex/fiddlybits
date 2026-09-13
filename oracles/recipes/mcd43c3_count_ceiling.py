#!/usr/bin/env python
"""Check that no MCD43C3 accumulator count exceeds the number of granules behind it.

Usage: mcd43c3_count_ceiling.py --out DIR

The ceiling of a cell's count in month m is the number of granules recorded in DIR/manifest.jsonl, less those in
DIR/excluded.jsonl, whose nominal date falls in month m: once per granule on the 0.05 degree grid, 25 times per
granule on the 0.25 degree bands. A month with no granule has a ceiling of zero. Prints the granules per month,
then every accumulator with a month holding a cell above its ceiling, with the number of such cells, the largest
count and the ceiling. Exits 1 when any cell is above its ceiling.
"""
import argparse, json, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcd43c3_reduce import Acc, nominal


def granules_per_month(out):
    excluded = os.path.join(out, 'excluded.jsonl')
    removed = {json.loads(l)['granule'] for l in open(excluded)} if os.path.exists(excluded) else set()
    per = [0] * 12
    for l in open(os.path.join(out, 'manifest.jsonl')):
        n = json.loads(l)['granule']
        if n not in removed: per[nominal(n).month - 1] += 1
    return per


def over_ceiling(out):
    """Accumulator name to {month: (cells above the ceiling, largest count, ceiling)}, for every name with one."""
    per = granules_per_month(out)
    acc = Acc(out, 'r')
    found = {}
    for key in sorted(k for k in acc.f if k.endswith('_cnt')):
        name = key[:-len('_cnt')]
        c = acc.f[key]
        ceiling = [p * (25 if 'Band' in name else 1) for p in per]
        over = {}
        for m in range(12):
            cells = int((c[m] > ceiling[m]).sum())
            if cells: over[m + 1] = (cells, int(c[m].max()), ceiling[m])
        if over: found[name] = over
    return per, found


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--out', required=True)
    out = os.path.abspath(ap.parse_args().out)
    per, found = over_ceiling(out)
    print('granules per month', per)
    for name, over in found.items(): print('ABOVE CEILING', name, over)
    print('FAIL' if found else 'PASS', 'count ceiling on', out)
    sys.exit(1 if found else 0)


if __name__ == '__main__': main()
