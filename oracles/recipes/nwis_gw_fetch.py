#!/usr/bin/env python
"""USGS Water Data for the Nation: groundwater sites and discrete depth-to-water measurements (parameter 72019),
conterminous US, via the OGC API (api.waterdata.usgs.gov). The legacy NWIS web services were decommissioned in 2025.

Output under oracles/data/nwis-gw/:
  pages/monitoring-locations/NNNNN.json.gz  raw pages, resumable
  pages/field-measurements/NNNNN.json.gz
  sites.csv        one row per GW site: id, lon, lat, altitude, vertical_datum, well_constructed_depth, hole_constructed_depth,
                   aquifer_code, aquifer_type_code, national_aquifer_code, state_name
  levels.csv       one row per site with 72019 measurements: n, first, last, mean_depth_m, median_depth_m, sd_depth_m,
                   n_static, n_approved  (feet converted to metres; only unit 'ft' rows counted)
  manifest.jsonl   page counts, hashes, fetch window
The API key is read from ~/.usgs_key at call time and is never written or printed. 429 responses are honoured (Retry-After).
"""
import gzip, hashlib, json, os, sys, time, statistics, csv, pathlib
import requests
BASE = 'https://api.waterdata.usgs.gov/ogcapi/v0/collections'
BBOX = '-125,24,-66,50'; LIMIT = 10000
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'oracles/data/nwis-gw')
def key():
    p = pathlib.Path.home() / '.usgs_key'; return p.read_text().strip() if p.is_file() else os.environ.get('USGS_API_KEY', '')
def get(session, url, params=None, tries=10):
    for att in range(tries):
        try:
            r = session.get(url, params=params, headers={'X-Api-Key': key()}, timeout=600)
            if r.status_code == 429:
                w = float(r.headers.get('Retry-After', 0) or 0) or min(30 * 2 ** att, 900); print(f'429, waiting {w:.0f}s', flush=True); time.sleep(w); continue
            r.raise_for_status(); return r.json()
        except Exception as e:
            if att == tries - 1: raise
            w = min(10 * 2 ** att, 300); print(f'retry in {w}s: {type(e).__name__}', flush=True); time.sleep(w)
def page_collection(session, coll, params):
    d = OUT / 'pages' / coll; d.mkdir(parents=True, exist_ok=True)
    state = d / 'state.json'; st = json.load(open(state)) if state.exists() else {'next': None, 'n': 0, 'done': False}
    if st['done']: print(coll, 'already complete', st['n'], 'pages'); return st['n']
    url = st['next'] or f'{BASE}/{coll}/items'; p = None if st['next'] else dict(params, f='json', limit=LIMIT)
    while True:
        t0 = time.time(); data = get(session, url, p); p = None
        fn = d / f'{st["n"]:05d}.json.gz'
        with gzip.open(fn, 'wt') as f: json.dump(data, f)
        st['n'] += 1; nxt = [l['href'] for l in data.get('links', []) if l.get('rel') == 'next']
        got = len(data.get('features', []))
        print(f'{coll} page {st["n"]} features={got} {time.time()-t0:.1f}s', flush=True)
        if not nxt or got < LIMIT: st['done'] = True; st['next'] = None; json.dump(st, open(state, 'w')); return st['n']
        st['next'] = url = nxt[0]; json.dump(st, open(state, 'w')); time.sleep(1.0)
def aggregate():
    keep = ['id', 'agency_code', 'state_name', 'site_type_code', 'altitude', 'vertical_datum', 'well_constructed_depth', 'hole_constructed_depth', 'aquifer_code', 'aquifer_type_code', 'national_aquifer_code']
    with open(OUT / 'sites.csv', 'w', newline='') as f:
        w = csv.writer(f); w.writerow(['id', 'lon', 'lat'] + keep[1:])
        for fn in sorted((OUT / 'pages' / 'monitoring-locations').glob('*.json.gz')):
            for ft in json.load(gzip.open(fn, 'rt')).get('features', []):
                pr = ft['properties']; g = ft.get('geometry') or {}; c = g.get('coordinates') or [None, None]
                w.writerow([pr.get('id'), c[0], c[1]] + [pr.get(k) for k in keep[1:]])
    acc = {}
    for fn in sorted((OUT / 'pages' / 'field-measurements').glob('*.json.gz')):
        for ft in json.load(gzip.open(fn, 'rt')).get('features', []):
            pr = ft['properties']
            if pr.get('unit_of_measure') != 'ft' or pr.get('value') in (None, ''): continue
            try: v = float(pr['value']) * 0.3048
            except ValueError: continue
            a = acc.setdefault(pr['monitoring_location_id'], {'v': [], 'first': None, 'last': None, 'static': 0, 'approved': 0})
            a['v'].append(v); t = pr.get('time') or ''
            a['first'] = min(a['first'] or t, t); a['last'] = max(a['last'] or t, t)
            a['static'] += 'Static' in (pr.get('qualifier') or []); a['approved'] += pr.get('approval_status') == 'Approved'
    with open(OUT / 'levels.csv', 'w', newline='') as f:
        w = csv.writer(f); w.writerow(['id', 'n', 'first', 'last', 'mean_depth_m', 'median_depth_m', 'sd_depth_m', 'n_static', 'n_approved'])
        for sid, a in acc.items():
            v = a['v']; w.writerow([sid, len(v), a['first'], a['last'], statistics.fmean(v), statistics.median(v), statistics.pstdev(v) if len(v) > 1 else 0.0, a['static'], a['approved']])
    return len(acc)
def main():
    OUT.mkdir(parents=True, exist_ok=True); s = requests.Session()
    n1 = page_collection(s, 'monitoring-locations', {'site_type_code': 'GW', 'bbox': BBOX})
    n2 = page_collection(s, 'field-measurements', {'parameter_code': '72019', 'bbox': BBOX})
    nsites = aggregate()
    rec = {'fetched': time.strftime('%Y-%m-%d'), 'bbox': BBOX, 'pages_sites': n1, 'pages_measurements': n2, 'sites_with_levels': nsites,
           'sites_csv_sha256': hashlib.sha256((OUT / 'sites.csv').read_bytes()).hexdigest(), 'levels_csv_sha256': hashlib.sha256((OUT / 'levels.csv').read_bytes()).hexdigest()}
    with open(OUT / 'manifest.jsonl', 'a') as f: f.write(json.dumps(rec) + '\n')
    print('done', rec, flush=True)
if __name__ == '__main__': main()
