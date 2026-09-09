#!/usr/bin/env python
"""Stream MCD43C3 v061 daily CMG granules and reduce them to a monthly climatology.

Usage: mcd43c3_reduce.py --out DIR --start YYYY-MM-DD --end YYYY-MM-DD [--qa-max N] [--dry-run GRANULE.hdf]

Keeps, per calendar month over the window:
  0.05 degree: sum and count of BSA/WSA shortwave, vis, nir, in two variants (all valid; snow-free),
               plus sum/count of Percent_Snow.
  0.25 degree: sum and count of BSA/WSA bands 1-7 (5x5 block mean of valid 0.05 cells), same two variants.
Every granule's id, size and sha256 go to manifest.jsonl (later folded into the TOML manifest).
Granules are deleted after reduction. Accumulators are float32 memmaps on disk, one slot per month.
"""
import argparse, hashlib, json, os, sys, time, datetime as dt
import numpy as np
from pyhdf.SD import SD, SDC

BROAD = ['shortwave', 'vis', 'nir']; BANDS = [f'Band{i}' for i in range(1, 8)]; KINDS = ['BSA', 'WSA']
NY, NX = 3600, 7200; CY, CX = 720, 1440

def sha256(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for c in iter(lambda: f.read(1 << 22), b''): h.update(c)
    return h.hexdigest()

class Acc:
    def __init__(self, out, mode):
        os.makedirs(out, exist_ok=True); self.out = out
        def mm(name, shape, dtype): return np.memmap(os.path.join(out, name + '.mm'), dtype=dtype, mode=mode, shape=shape)
        self.f = {}
        for v in ('all', 'snowfree'):
            for k in KINDS:
                for b in BROAD:
                    self.f[f'{v}_{k}_{b}_sum'] = mm(f'{v}_{k}_{b}_sum', (12, NY, NX), np.float32)
                    self.f[f'{v}_{k}_{b}_cnt'] = mm(f'{v}_{k}_{b}_cnt', (12, NY, NX), np.uint16)
                for b in BANDS:
                    self.f[f'{v}_{k}_{b}_sum'] = mm(f'{v}_{k}_{b}_sum', (12, CY, CX), np.float32)
                    self.f[f'{v}_{k}_{b}_cnt'] = mm(f'{v}_{k}_{b}_cnt', (12, CY, CX), np.uint16)
        self.f['snowpct_sum'] = mm('snowpct_sum', (12, NY, NX), np.float32)
        self.f['snowpct_cnt'] = mm('snowpct_cnt', (12, NY, NX), np.uint16)
    def flush(self):
        for m in self.f.values(): m.flush()

def coarsen_sum(a, valid):
    """5x5 block: sum of valid values and count of valid cells."""
    s = np.where(valid, a, 0.0).reshape(CY, 5, CX, 5).sum(axis=(1, 3))
    c = valid.reshape(CY, 5, CX, 5).sum(axis=(1, 3))
    return s, c

def reduce_granule(path, acc, qa_all, qa_sf):
    h = SD(path, SDC.READ)
    day = os.path.basename(path).split('.')[1]  # A2015175
    date = dt.datetime.strptime(day[1:], '%Y%j'); m = date.month - 1
    qa = h.select('Albedo_Quality')[:]; snow = h.select('Percent_Snow')[:]
    good = (qa != 255) & (qa <= qa_all)
    snowfree = (qa != 255) & (qa <= qa_sf) & (snow == 0)
    sv = snow != 255
    acc.f['snowpct_sum'][m][sv] += snow[sv].astype(np.float32); acc.f['snowpct_cnt'][m][sv] += 1
    for k in KINDS:
        for b in BROAD + BANDS:
            raw = h.select(f'Albedo_{k}_{b}')[:]
            valid = (raw != 32767) & (raw >= 0) & (raw <= 32766)
            a = raw.astype(np.float32) * 0.001
            for v, mask in (('all', valid & good), ('snowfree', valid & snowfree)):
                if b in BROAD:
                    acc.f[f'{v}_{k}_{b}_sum'][m][mask] += a[mask]; acc.f[f'{v}_{k}_{b}_cnt'][m][mask] += 1
                else:
                    s, c = coarsen_sum(a, mask)
                    acc.f[f'{v}_{k}_{b}_sum'][m] += s; acc.f[f'{v}_{k}_{b}_cnt'][m] += c.astype(np.uint16)
    h.end()
    return {'granule': os.path.basename(path), 'date': date.strftime('%Y-%m-%d'), 'bytes': os.path.getsize(path), 'sha256': sha256(path),
            'qa_hist': np.bincount(qa[qa != 255].ravel(), minlength=6)[:6].tolist(), 'snow_zero_frac': float((snow[sv] == 0).mean())}

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--out', required=True); ap.add_argument('--start'); ap.add_argument('--end')
    ap.add_argument('--qa-max-all', type=int, default=3); ap.add_argument('--qa-max-snowfree', type=int, default=1); ap.add_argument('--dry-run'); ap.add_argument('--workdir', default='.')
    a = ap.parse_args()
    if a.dry_run:
        acc = Acc(a.out, 'w+'); t0 = time.time(); rec = reduce_granule(a.dry_run, acc, a.qa_max_all, a.qa_max_snowfree); acc.flush()
        print(json.dumps(rec), 'seconds=%.1f' % (time.time() - t0)); return
    import earthaccess
    earthaccess.login(strategy='netrc')
    manifest = os.path.join(a.out, 'manifest.jsonl'); done = set()
    if os.path.exists(manifest):
        done = {json.loads(l)['granule'] for l in open(manifest)}
    acc = Acc(a.out, 'r+' if done else 'w+')
    rules = os.path.join(a.out, 'rules.json')
    if not os.path.exists(rules):
        json.dump({'window': [a.start, a.end], 'all_variant': f'Albedo_Quality <= {a.qa_max_all}', 'snowfree_variant': f'Albedo_Quality <= {a.qa_max_snowfree} and Percent_Snow == 0', 'declared_before_first_granule': True}, open(rules, 'w'), indent=1)
    results = earthaccess.search_data(short_name='MCD43C3', version='061', temporal=(a.start, a.end))
    results.sort(key=lambda g: g.data_links()[0])
    print('granules', len(results), 'already done', len(done), flush=True)
    with open(manifest, 'a') as mf:
        for i, g in enumerate(results):
            name = os.path.basename(g.data_links()[0])
            if name in done: continue
            for attempt in range(4):
                try:
                    files = earthaccess.download([g], local_path=a.workdir, threads=1); break
                except Exception as e:
                    print('retry', name, e, flush=True); time.sleep(30 * (attempt + 1))
            else:
                print('GIVING UP', name, flush=True); continue
            p = str(files[0]); rec = reduce_granule(p, acc, a.qa_max_all, a.qa_max_snowfree); os.remove(p)
            mf.write(json.dumps(rec) + '\n'); mf.flush()
            if i % 50 == 0: acc.flush(); print(i, rec['date'], flush=True)
    acc.flush(); print('done')

if __name__ == '__main__': main()
