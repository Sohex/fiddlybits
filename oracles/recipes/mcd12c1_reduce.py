#!/usr/bin/env python
"""Stream MCD12C1 v061 yearly CMG granules; keep the IGBP majority class, its assessment, and the 17 per-class
percents per year as compressed npz, plus a modal class over the window. Raw granules are deleted. manifest.jsonl records each."""
import argparse, hashlib, json, os, sys
import numpy as np
from pyhdf.SD import SD, SDC
def sha256(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for c in iter(lambda: f.read(1 << 22), b''): h.update(c)
    return h.hexdigest()
def reduce_granule(path, out):
    h = SD(path, SDC.READ); year = int(os.path.basename(path).split('.')[1][1:5])
    maj = h.select('Majority_Land_Cover_Type_1')[:].astype(np.uint8)
    ass = h.select('Majority_Land_Cover_Type_1_Assessment')[:].astype(np.uint8)
    pct = h.select('Land_Cover_Type_1_Percent')[:].astype(np.uint8)   # (3600, 7200, 17)
    np.savez_compressed(os.path.join(out, f'mcd12c1_igbp_{year}.npz'), majority=maj, assessment=ass, percent=pct)
    h.end()
    return {'granule': os.path.basename(path), 'year': year, 'bytes': os.path.getsize(path), 'sha256': sha256(path)}, maj
def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--out', required=True); ap.add_argument('--start'); ap.add_argument('--end')
    ap.add_argument('--dry-run'); ap.add_argument('--workdir', default='.'); a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    if a.dry_run:
        rec, _ = reduce_granule(a.dry_run, a.out); print(json.dumps(rec)); return
    import earthaccess; earthaccess.login(strategy='netrc')
    res = earthaccess.search_data(short_name='MCD12C1', version='061', temporal=(a.start, a.end)); res.sort(key=lambda g: g.data_links()[0])
    counts = None
    with open(os.path.join(a.out, 'manifest.jsonl'), 'a') as mf:
        for g in res:
            p = str(earthaccess.download([g], local_path=a.workdir, threads=1)[0]); rec, maj = reduce_granule(p, a.out); os.remove(p)
            if counts is None: counts = np.zeros((17,) + maj.shape, np.uint8)
            for c in range(17): counts[c] += (maj == c)
            mf.write(json.dumps(rec) + '\n'); mf.flush(); print(rec['year'], flush=True)
    modal = counts.argmax(axis=0).astype(np.uint8); nvalid = counts.sum(axis=0).astype(np.uint8)
    np.savez_compressed(os.path.join(a.out, 'mcd12c1_igbp_modal.npz'), modal=modal, years_valid=nvalid, class_counts=counts)
    print('done')
if __name__ == '__main__': main()
