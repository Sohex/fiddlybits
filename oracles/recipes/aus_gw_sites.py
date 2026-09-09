#!/usr/bin/env python
"""Australian Groundwater Explorer state packages -> one per-site water-table table.

Reads oracles/data/aus-groundwater/gw_gdb_<STATE>.zip (extracted beside it), joins each state's level_<state>.csv
readings to the NGIS_Bore layer of its geodatabase, converts every reading to depth below ground in metres by its
declared datum (DTW as is; RSWL = LandElev - result; SWL = result - stickup, stickup = TsRefElev - LandElev, dropped
where no reference elevation), and writes sites.csv with one row per hydroid: lat, lon, land_elev_m, purpose
(FTypeClass), bore_depth_m, aquifer (HGUName), state, n, first, last, mean_depth_m, median_depth_m, sd_depth_m,
frac_qualityA, n_by_datum. Nothing is filtered here beyond a sanity window on depth (-50 to 1500 m) and missing
coordinates: production bores, quality flags and depth-consistency are labels the oracle applies at scoring time.
"""
import glob, json, os, pathlib, subprocess, sys, time, zipfile, hashlib
import numpy as np, pandas as pd, pyogrio
ROOT = pathlib.Path(__file__).resolve().parents[2]; D = ROOT / 'oracles' / 'data' / 'aus-groundwater'
BORE_COLS = ['HydroID', 'Latitude', 'Longitude', 'LandElev', 'TsRefElev', 'FTypeClass', 'BoreDepth', 'HGUName']
def main():
    frames = []; stats = {}
    for z in sorted(D.glob('gw_gdb_*.zip')):
        state = z.stem.split('_')[-1]; d = D / f'gdb_{state}'
        if not d.exists(): zipfile.ZipFile(z).extractall(D)
        lv_path = glob.glob(str(d / 'level_*.csv'))[0]; gdb = glob.glob(str(d / '*.gdb'))[0]
        t0 = time.time()
        lv = pd.read_csv(lv_path, usecols=['hydroid', 'bore_date', 'obs_point_datum', 'result', 'quality_flag'], dtype={'hydroid': 'int64', 'obs_point_datum': 'category', 'quality_flag': 'category'})
        bores = pyogrio.read_dataframe(gdb, layer='NGIS_Bore', columns=BORE_COLS, read_geometry=False).rename(columns={'HydroID': 'hydroid'})
        bores['hydroid'] = bores['hydroid'].astype('int64')
        lv = lv.merge(bores, on='hydroid', how='left')
        datum = lv['obs_point_datum'].astype(str); depth = pd.Series(np.nan, index=lv.index)
        m = datum == 'DTW'; depth[m] = lv.loc[m, 'result']
        m = datum == 'RSWL'; depth[m] = lv.loc[m, 'LandElev'] - lv.loc[m, 'result']
        m = datum == 'SWL'; stick = lv['TsRefElev'] - lv['LandElev']; depth[m] = lv.loc[m, 'result'] - stick[m]
        lv['depth_m'] = depth; lv['datum'] = datum
        raw = len(lv); lv = lv[lv.depth_m.notna() & lv.Latitude.notna() & lv.Longitude.notna()]; lv = lv[(lv.depth_m > -50) & (lv.depth_m < 1500)]
        lv['is_a'] = (lv['quality_flag'].astype(str) == 'quality-A')
        g = lv.groupby('hydroid')
        site = g.agg(lat=('Latitude', 'first'), lon=('Longitude', 'first'), land_elev_m=('LandElev', 'first'), purpose=('FTypeClass', 'first'), bore_depth_m=('BoreDepth', 'first'), aquifer=('HGUName', 'first'),
                     n=('depth_m', 'size'), first=('bore_date', 'min'), last=('bore_date', 'max'), mean_depth_m=('depth_m', 'mean'), median_depth_m=('depth_m', 'median'), sd_depth_m=('depth_m', 'std'), frac_qualityA=('is_a', 'mean'))
        nd = lv.groupby(['hydroid', 'datum']).size().unstack(fill_value=0); site['n_by_datum'] = nd.apply(lambda r: json.dumps({k: int(v) for k, v in r.items() if v}), axis=1)
        site['state'] = state; frames.append(site.reset_index())
        stats[state] = {'raw_readings': int(raw), 'usable_readings': int(len(lv)), 'sites': int(len(site)), 'by_datum': {k: int(v) for k, v in lv['datum'].value_counts().items()}}
        print(state, stats[state], f'{time.time()-t0:.0f}s', flush=True)
        del lv, bores
    out = pd.concat(frames, ignore_index=True); out.to_csv(D / 'sites.csv', index=False)
    rec = {'generated': time.strftime('%Y-%m-%d'), 'sites': int(len(out)), 'readings_usable': int(sum(s['usable_readings'] for s in stats.values())), 'per_state': stats, 'sites_csv_sha256': hashlib.sha256((D / 'sites.csv').read_bytes()).hexdigest()}
    with open(D / 'manifest.jsonl', 'a') as f: f.write(json.dumps(rec) + '\n')
    print('done', {k: v for k, v in rec.items() if k != 'per_state'}, flush=True)
if __name__ == '__main__': main()
