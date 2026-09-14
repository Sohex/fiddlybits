#!/usr/bin/env python
"""Remove granules dated outside the declared window from the MCD43C3 monthly accumulators.

Usage: mcd43c3_window_correction.py --out DIR --workdir DIR

Reads the window from DIR/rules.json and every reduced granule from DIR/manifest.jsonl. For each
granule whose nominal date lies outside the window:
  fetches it again by name, and refuses unless its bytes and sha256 are the recorded ones;
  reduces it with mcd43c3_reduce.reduce_granule into a scratch accumulator under WORKDIR, and
  refuses unless its QA histogram and snow-free fraction are the recorded ones.
Then refuses unless the scratch accumulator is zero outside the months those granules fall in
and no extract count is below the scratch count. Only after every check passes: reflinks every
accumulator file to DIR-precorrection, subtracts the scratch sums and counts from the extract's,
sets a sum to zero where its count reaches zero, writes DIR/excluded.jsonl with one record per
removed granule, and prints the counts removed and the largest residual set to zero.
Refuses to start when DIR/excluded.jsonl exists.
"""
import argparse, datetime as dt, json, os, re, shutil, subprocess, sys, time
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcd43c3_reduce import Acc, reduce_granule, sha256


def refuse(msg):
    print('REFUSED:', msg, flush=True)
    sys.exit(1)


def nominal(name):
    return dt.datetime.strptime(name.split('.')[1][1:], '%Y%j').date()


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--out', required=True); ap.add_argument('--workdir', required=True)
    a = ap.parse_args()
    out = os.path.abspath(a.out)
    excluded = os.path.join(out, 'excluded.jsonl')
    if os.path.exists(excluded): refuse(excluded + ' exists; the correction has been applied')

    rules = json.load(open(os.path.join(out, 'rules.json')))
    lo, hi = (dt.date.fromisoformat(x) for x in rules['window'])
    qa_all = int(re.search(r'<= (\d+)', rules['all_variant']).group(1))
    qa_sf = int(re.search(r'<= (\d+)', rules['snowfree_variant']).group(1))
    recs = [json.loads(l) for l in open(os.path.join(out, 'manifest.jsonl'))]
    outside = {r['granule']: r for r in recs if not lo <= nominal(r['granule']) <= hi}
    if not outside: refuse('no reduced granule lies outside the window ' + str((lo, hi)))
    months = sorted({nominal(n).month - 1 for n in outside})
    print('window', lo, hi, 'granules outside', len(outside), 'months', [m + 1 for m in months], flush=True)

    import earthaccess
    earthaccess.login(strategy='netrc')
    links = {}
    for side in ([n for n in outside if nominal(n) < lo], [n for n in outside if nominal(n) > hi]):
        if not side: continue
        first, last = min(nominal(n) for n in side), max(nominal(n) for n in side)
        for g in earthaccess.search_data(short_name='MCD43C3', version='061', temporal=(first.isoformat(), last.isoformat())):
            links[os.path.basename(g.data_links()[0])] = g
    absent = sorted(set(outside) - set(links))
    if absent: refuse('the archive no longer serves ' + ', '.join(absent))

    scratch = os.path.join(os.path.abspath(a.workdir), 'mcd43c3-outside-window')
    if os.path.exists(scratch): shutil.rmtree(scratch)
    delta = Acc(scratch, 'w+')
    fetched = os.path.join(os.path.abspath(a.workdir), 'granules')
    os.makedirs(fetched, exist_ok=True)
    reproduced = []
    for name in sorted(outside):
        want = outside[name]
        for attempt in range(4):
            try:
                files = earthaccess.download([links[name]], local_path=fetched, threads=1); break
            except Exception as e:
                print('retry', name, e, flush=True); time.sleep(30 * (attempt + 1))
        else:
            refuse('could not fetch ' + name)
        p = str(files[0])
        if os.path.getsize(p) != want['bytes'] or sha256(p) != want['sha256']:
            refuse(name + ' is not the recorded bytes')
        rec = reduce_granule(p, delta, qa_all, qa_sf); os.remove(p)
        if rec['qa_hist'] != want['qa_hist'] or rec['snow_zero_frac'] != want['snow_zero_frac']:
            refuse(name + ' does not reduce to the recorded QA histogram and snow-free fraction')
        reproduced.append(rec)
        print('reduced', name, flush=True)
    delta.flush()

    extract = Acc(out, 'r+')
    for key, d in delta.f.items():
        for m in range(12):
            if m not in months and d[m].any(): refuse(key + ' scratch is nonzero in month ' + str(m + 1))
        if key.endswith('_cnt'):
            for m in months:
                if (extract.f[key][m] < d[m]).any(): refuse(key + ' extract count is below the scratch count in month ' + str(m + 1))

    snapshot = out + '-precorrection'
    if os.path.exists(snapshot): refuse(snapshot + ' exists')
    os.makedirs(snapshot)
    for name in sorted(os.listdir(out)):
        if name.endswith('.mm'):
            subprocess.run(['cp', '--reflink=always', os.path.join(out, name), os.path.join(snapshot, name)], check=True)
    print('snapshot', snapshot, flush=True)

    worst = 0.0
    for key in sorted(k for k in delta.f if k.endswith('_sum')):
        cnt_key = key[:-len('_sum')] + '_cnt'
        for m in months:
            extract.f[key][m] -= delta.f[key][m]
            extract.f[cnt_key][m] -= delta.f[cnt_key][m]
            emptied = extract.f[cnt_key][m] == 0
            if emptied.any():
                worst = max(worst, float(np.abs(extract.f[key][m][emptied]).max()))
                extract.f[key][m][emptied] = 0.0
        print('removed', cnt_key, {m + 1: int(delta.f[cnt_key][m].sum(dtype=np.int64)) for m in months}, flush=True)
    extract.flush()

    with open(excluded, 'w') as f:
        for rec in reproduced: f.write(json.dumps(rec) + '\n')
    shutil.rmtree(scratch)
    print('largest residual set to zero', worst)
    print('done')


if __name__ == '__main__': main()
