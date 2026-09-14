#!/usr/bin/env python
"""Stream MCD43C3 v061 daily CMG granules and reduce them to monthly accumulators.

Usage: mcd43c3_reduce.py --out DIR --start YYYY-MM-DD --end YYYY-MM-DD [--months M,M,...]
                         [--qa-max-all N] [--qa-max-snowfree N] [--workdir DIR] [--batch N] [--max-granules N]
       mcd43c3_reduce.py --out DIR --dry-run GRANULE.hdf

Keeps, per calendar month over the window:
  0.05 degree: sum and count of BSA/WSA shortwave, vis, nir, in two variants (all valid; snow-free),
               plus sum/count of Percent_Snow.
  0.25 degree: sum and count of BSA/WSA bands 1-7 (5x5 block mean of valid 0.05 cells), same two variants.
A granule is reduced when its nominal date (the AYYYYDDD field of its name) lies in the window and, when
--months is given, in one of those calendar months. The window, the months and the two variants are written to
DIR/rules.json before the first granule and read back on every later start; an argument that disagrees with
DIR/rules.json is refused. Accumulators are float32 sums and uint16 counts in memmaps, one slot per month.

Granules are reduced a batch at a time into DIR/.stage, a reflink copy of the accumulators. A batch is
committed by writing its manifest records to DIR/.commit.json, replacing each accumulator in DIR with its staged
copy, appending the records to DIR/manifest.jsonl, then removing DIR/.stage and DIR/.commit.json. A start that
finds DIR/.commit.json completes that commit; a start that finds DIR/.stage without it discards the stage.
Every granule's id, size, sha256, QA histogram and snow-free fraction go to manifest.jsonl, and the granule
file is deleted after reduction. Exits 1 when a granule could not be fetched; the same command run again
fetches only what is missing.
"""
import argparse, hashlib, json, os, shutil, subprocess, sys, time, datetime as dt
import numpy as np
from pyhdf.SD import SD, SDC

BROAD = ['shortwave', 'vis', 'nir']; BANDS = [f'Band{i}' for i in range(1, 8)]; KINDS = ['BSA', 'WSA']
NY, NX = 3600, 7200; CY, CX = 720, 1440
STAGE, COMMIT, MANIFEST, RULES = '.stage', '.commit.json', 'manifest.jsonl', 'rules.json'

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

def nominal(name):
    return dt.datetime.strptime(name.split('.')[1][1:], '%Y%j').date()

def fsync_path(p):
    fd = os.open(p, os.O_RDONLY)
    try: os.fsync(fd)
    finally: os.close(fd)

def write_atomic(path, text):
    tmp = path + '.tmp'
    with open(tmp, 'w') as f:
        f.write(text); f.flush(); os.fsync(f.fileno())
    os.replace(tmp, path); fsync_path(os.path.dirname(os.path.abspath(path)))

def accumulator_files(d):
    return sorted(n for n in os.listdir(d) if n.endswith('.mm'))

def recorded(out):
    p = os.path.join(out, MANIFEST)
    return [json.loads(l) for l in open(p)] if os.path.exists(p) else []

def begin_stage(out):
    """DIR/.stage as a reflink copy of every accumulator in DIR."""
    stage = os.path.join(out, STAGE)
    os.makedirs(stage)
    for n in accumulator_files(out):
        subprocess.run(['cp', '--reflink=always', os.path.join(out, n), os.path.join(stage, n)], check=True)
    return stage

def finish(out):
    """Complete the commit DIR/.commit.json records: replace each accumulator still in DIR/.stage, append the
    records DIR/manifest.jsonl lacks, remove DIR/.stage and DIR/.commit.json."""
    stage = os.path.join(out, STAGE)
    records = json.load(open(os.path.join(out, COMMIT)))
    if os.path.isdir(stage):
        for n in accumulator_files(stage):
            os.replace(os.path.join(stage, n), os.path.join(out, n))
        fsync_path(out)
    have = {r['granule'] for r in recorded(out)}
    with open(os.path.join(out, MANIFEST), 'a') as mf:
        for r in records:
            if r['granule'] not in have: mf.write(json.dumps(r) + '\n')
        mf.flush(); os.fsync(mf.fileno())
    if os.path.isdir(stage): shutil.rmtree(stage)
    os.remove(os.path.join(out, COMMIT)); fsync_path(out)

def commit(out, records):
    """Commit DIR/.stage with the manifest records of the granules reduced into it."""
    stage = os.path.join(out, STAGE)
    for n in accumulator_files(stage): fsync_path(os.path.join(stage, n))
    write_atomic(os.path.join(out, COMMIT), json.dumps(records))
    finish(out)

def recover(out):
    """Complete an interrupted commit, or discard an uncommitted stage. Returns what it did, or None."""
    if os.path.exists(os.path.join(out, COMMIT)):
        finish(out); return 'completed an interrupted commit'
    if os.path.isdir(os.path.join(out, STAGE)):
        shutil.rmtree(os.path.join(out, STAGE)); return 'discarded an uncommitted batch'
    return None

def refuse(msg):
    print('REFUSED:', msg, flush=True); sys.exit(1)

def declared_rules(a, out):
    """DIR/rules.json, written from the arguments when absent; an argument disagreeing with it is refused."""
    path = os.path.join(out, RULES)
    months = sorted(int(m) for m in a.months.split(',')) if a.months else None
    if months is not None and not all(1 <= m <= 12 for m in months): refuse('--months must lie in 1 to 12')
    if not os.path.exists(path):
        if not (a.start and a.end): refuse('--start and --end are required before ' + path + ' exists')
        qa_all = 3 if a.qa_max_all is None else a.qa_max_all
        qa_sf = 1 if a.qa_max_snowfree is None else a.qa_max_snowfree
        rules = {'window': [a.start, a.end], 'months': months or list(range(1, 13)),
                 'all_variant': f'Albedo_Quality <= {qa_all}', 'snowfree_variant': f'Albedo_Quality <= {qa_sf} and Percent_Snow == 0',
                 'declared_before_first_granule': True}
        os.makedirs(out, exist_ok=True)
        write_atomic(path, json.dumps(rules, indent=1))
    rules = json.load(open(path))
    rules.setdefault('months', list(range(1, 13)))
    if a.start and a.start != rules['window'][0]: refuse('--start disagrees with ' + path)
    if a.end and a.end != rules['window'][1]: refuse('--end disagrees with ' + path)
    if months is not None and months != rules['months']: refuse('--months disagrees with ' + path)
    qa_all = int(rules['all_variant'].split('<=')[1].split()[0]); qa_sf = int(rules['snowfree_variant'].split('<=')[1].split()[0])
    if a.qa_max_all is not None and a.qa_max_all != qa_all: refuse('--qa-max-all disagrees with ' + path)
    if a.qa_max_snowfree is not None and a.qa_max_snowfree != qa_sf: refuse('--qa-max-snowfree disagrees with ' + path)
    return dt.date.fromisoformat(rules['window'][0]), dt.date.fromisoformat(rules['window'][1]), set(rules['months']), qa_all, qa_sf

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--out', required=True); ap.add_argument('--start'); ap.add_argument('--end')
    ap.add_argument('--months'); ap.add_argument('--qa-max-all', type=int); ap.add_argument('--qa-max-snowfree', type=int)
    ap.add_argument('--dry-run'); ap.add_argument('--workdir', default='.')
    ap.add_argument('--batch', type=int, default=50); ap.add_argument('--max-granules', type=int)
    a = ap.parse_args()
    if a.dry_run:
        acc = Acc(a.out, 'w+'); t0 = time.time(); rec = reduce_granule(a.dry_run, acc, a.qa_max_all or 3, a.qa_max_snowfree or 1); acc.flush()
        print(json.dumps(rec), 'seconds=%.1f' % (time.time() - t0)); return
    out = os.path.abspath(a.out)
    lo, hi, months, qa_all, qa_sf = declared_rules(a, out)
    did = recover(out)
    if did: print(did, flush=True)
    done = {r['granule'] for r in recorded(out)}
    if not accumulator_files(out):
        if done: refuse(os.path.join(out, MANIFEST) + ' records granules but ' + out + ' holds no accumulator')
        Acc(out, 'w+').flush()

    import earthaccess
    earthaccess.login(strategy='netrc')
    found = earthaccess.search_data(short_name='MCD43C3', version='061', temporal=(lo.isoformat(), hi.isoformat()))
    name = lambda g: os.path.basename(g.data_links()[0])
    wanted = sorted((g for g in found if lo <= nominal(name(g)) <= hi and nominal(name(g)).month in months), key=name)
    todo = [g for g in wanted if name(g) not in done]
    if a.max_granules is not None: todo = todo[:a.max_granules]
    print('granules returned', len(found), 'in the window and months', len(wanted), 'already recorded', len(done), 'to reduce now', len(todo), flush=True)

    os.makedirs(a.workdir, exist_ok=True)
    failed = []
    for i in range(0, len(todo), a.batch):
        stage = begin_stage(out); acc = Acc(stage, 'r+'); records = []
        for g in todo[i:i + a.batch]:
            n = name(g); target = os.path.join(a.workdir, n)
            if os.path.exists(target): os.remove(target)
            for attempt in range(4):
                try:
                    files = earthaccess.download([g], local_path=a.workdir, threads=1); break
                except Exception as e:
                    print('retry', n, e, flush=True); time.sleep(30 * (attempt + 1))
            else:
                print('GIVING UP', n, flush=True); failed.append(n); continue
            p = str(files[0]); records.append(reduce_granule(p, acc, qa_all, qa_sf)); os.remove(p)
        acc.flush(); del acc
        if records:
            commit(out, records)
        else:
            shutil.rmtree(stage)
        print('committed', len(records), 'through', records[-1]['date'] if records else '-', 'recorded', len(recorded(out)), flush=True)
    left = [name(g) for g in wanted if name(g) not in {r['granule'] for r in recorded(out)}]
    print('in the window and months', len(wanted), 'recorded', len(wanted) - len(left), 'not yet reduced', len(left), flush=True)
    if failed:
        print('not fetched, run the same command again:', ', '.join(failed), flush=True); sys.exit(1)
    print('done')

if __name__ == '__main__': main()
