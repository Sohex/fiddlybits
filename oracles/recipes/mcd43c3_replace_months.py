#!/usr/bin/env python
"""Replace whole months of the MCD43C3 extract with the same months reduced from zero in a second directory.

Usage: mcd43c3_replace_months.py --out DIR --from SRC

Refuses unless:
  SRC/rules.json declares months, and the window and both variants of DIR/rules.json;
  SRC holds neither .stage nor .commit.json;
  the granules of SRC/manifest.jsonl are exactly the granules of DIR/manifest.jsonl dated in the window and in
  those months, with the same bytes and sha256;
  SRC passes mcd43c3_count_ceiling.
Then reflinks every accumulator of DIR to DIR-premonths, copies those months of every accumulator from SRC into
DIR, removes DIR/climatology.jsonl and every DIR/climatology_*.npz, writes DIR/replaced_months.json, and runs
mcd43c3_count_ceiling on DIR, exiting 1 when it fails.
Refuses to start when DIR/replaced_months.json or DIR-premonths exists.
"""
import argparse, datetime as dt, json, os, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcd43c3_reduce import Acc, nominal, accumulator_files, sha256, write_atomic
from mcd43c3_count_ceiling import over_ceiling


def refuse(msg):
    print('REFUSED:', msg, flush=True); sys.exit(1)


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--out', required=True); ap.add_argument('--from', dest='src', required=True)
    a = ap.parse_args()
    out, src = os.path.abspath(a.out), os.path.abspath(a.src)
    record = os.path.join(out, 'replaced_months.json')
    snapshot = out + '-premonths'
    if os.path.exists(record): refuse(record + ' exists; months have been replaced')
    if os.path.exists(snapshot): refuse(snapshot + ' exists')

    dst_rules = json.load(open(os.path.join(out, 'rules.json')))
    src_rules = json.load(open(os.path.join(src, 'rules.json')))
    if 'months' not in src_rules: refuse(src + '/rules.json declares no months')
    for k in ('window', 'all_variant', 'snowfree_variant'):
        if src_rules[k] != dst_rules[k]: refuse(k + ' differs between the two rules.json')
    months = sorted(src_rules['months'])
    for n in ('.stage', '.commit.json'):
        if os.path.exists(os.path.join(src, n)): refuse(os.path.join(src, n) + ' exists; the reduction has not finished a commit')

    lo, hi = (dt.date.fromisoformat(x) for x in dst_rules['window'])
    key = lambda r: (r['bytes'], r['sha256'])
    dst = {r['granule']: key(r) for r in map(json.loads, open(os.path.join(out, 'manifest.jsonl')))
           if lo <= nominal(r['granule']) <= hi and nominal(r['granule']).month in months}
    got = {r['granule']: key(r) for r in map(json.loads, open(os.path.join(src, 'manifest.jsonl')))}
    if got != dst:
        refuse(f'granules differ: {len(set(dst) - set(got))} of the extract absent from the source, '
               f'{len(set(got) - set(dst))} of the source absent from the extract, '
               f'{sum(1 for n in set(got) & set(dst) if got[n] != dst[n])} with different bytes or sha256')
    per, found = over_ceiling(src)
    if found: refuse('the source fails the count ceiling: ' + json.dumps(found))
    print('source granules per month', per, flush=True)

    os.makedirs(snapshot)
    for n in accumulator_files(out):
        subprocess.run(['cp', '--reflink=always', os.path.join(out, n), os.path.join(snapshot, n)], check=True)
    print('snapshot', snapshot, flush=True)

    s, d = Acc(src, 'r'), Acc(out, 'r+')
    for k in sorted(d.f):
        for m in months:
            d.f[k][m - 1] = s.f[k][m - 1]
    d.flush(); del d

    for n in sorted(os.listdir(out)):
        if n == 'climatology.jsonl' or (n.startswith('climatology_') and n.endswith('.npz')):
            os.remove(os.path.join(out, n))
    write_atomic(record, json.dumps({'months': months, 'source': src, 'granules': len(got),
                                     'source_manifest_sha256': sha256(os.path.join(src, 'manifest.jsonl')),
                                     'source_rules_sha256': sha256(os.path.join(src, 'rules.json'))}, indent=1))
    per, found = over_ceiling(out)
    print('extract granules per month', per)
    for name, over in found.items(): print('ABOVE CEILING', name, over)
    print('FAIL' if found else 'PASS', 'count ceiling on', out)
    sys.exit(1 if found else 0)


if __name__ == '__main__': main()
