#!/usr/bin/env python
"""Divide the MCD43C3 monthly accumulators into a monthly climatology, with the count beside every mean.

Usage: mcd43c3_climatology.py --out DIR

For every accumulator pair <name>_sum.mm and <name>_cnt.mm that mcd43c3_reduce.Acc declares, writes
DIR/climatology_<name>.npz holding
  mean:  float32, (month, row, column), sum over count, NaN where the count is zero;
  count: uint16, the same shape, the number of valid daily values behind each mean;
and appends its name, bytes and sha256 to DIR/climatology.jsonl. A name already recorded there,
with its file present, is skipped.
Refuses to start while a granule in DIR/manifest.jsonl dated outside the window of DIR/rules.json
is not also in DIR/excluded.jsonl.
"""
import argparse, datetime as dt, json, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcd43c3_reduce import Acc, sha256


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--out', required=True)
    out = os.path.abspath(ap.parse_args().out)

    lo, hi = (dt.date.fromisoformat(x) for x in json.load(open(os.path.join(out, 'rules.json')))['window'])
    nominal = lambda name: dt.datetime.strptime(name.split('.')[1][1:], '%Y%j').date()
    reduced = [json.loads(l)['granule'] for l in open(os.path.join(out, 'manifest.jsonl'))]
    path = os.path.join(out, 'excluded.jsonl')
    removed = {json.loads(l)['granule'] for l in open(path)} if os.path.exists(path) else set()
    left = sorted(n for n in reduced if not lo <= nominal(n) <= hi and n not in removed)
    if left:
        print('REFUSED: granules outside the window are still in the accumulators:', ', '.join(left)); sys.exit(1)

    record = os.path.join(out, 'climatology.jsonl')
    done = {json.loads(l)['name'] for l in open(record)} if os.path.exists(record) else set()
    acc = Acc(out, 'r')
    names = sorted(k[:-len('_sum')] for k in acc.f if k.endswith('_sum'))
    with open(record, 'a') as rf:
        for name in names:
            final = os.path.join(out, f'climatology_{name}.npz')
            if name in done and os.path.exists(final): continue
            s, c = acc.f[name + '_sum'], acc.f[name + '_cnt']
            mean = np.full(s.shape, np.nan, dtype=np.float32)
            for m in range(s.shape[0]):
                np.divide(s[m], c[m], out=mean[m], where=c[m] > 0)
            part = final + '.part'
            with open(part, 'wb') as f:
                np.savez_compressed(f, mean=mean, count=np.asarray(c))
            os.replace(part, final)
            rf.write(json.dumps({'name': name, 'file': os.path.basename(final), 'shape': list(s.shape),
                                 'bytes': os.path.getsize(final), 'sha256': sha256(final)}) + '\n'); rf.flush()
            print('wrote', final, flush=True)
    print('done')


if __name__ == '__main__': main()
