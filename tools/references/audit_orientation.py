#!/usr/bin/env python
"""Which already-read files were read sideways? Samples pages of every file recorded as chandra-ocr-2, scores each
page's quarter turns the way the reading recipe does, and prints the files with turned pages so they can be read
again. Writes the list to the path given, one filename per line (see notes/findings/2026-09-09-chandra-page-orientation.md).

    audit_orientation.py <out list> [--sample 6] [--workers 8]
"""
import argparse, json, pathlib, subprocess, sys, tempfile
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from chandra_pages import turn_upright, MAN, PDF
def main():
    ap = argparse.ArgumentParser(); ap.add_argument('out'); ap.add_argument('--sample', type=int, default=6); ap.add_argument('--workers', type=int, default=8); a = ap.parse_args()
    done = {}
    for l in open(MAN):
        r = json.loads(l)
        if r.get('engine') == 'chandra-ocr-2': done[r['file']] = r
    hits = []
    for i, (fn, rec) in enumerate(sorted(done.items()), 1):
        p = PDF / fn
        if not p.exists(): print('missing', fn); continue
        n = rec.get('pages') or 1
        pages = sorted({max(1, round(n * k / (a.sample + 1))) for k in range(1, a.sample + 1)})
        with tempfile.TemporaryDirectory() as td:
            imgs = []
            for pg in pages:
                subprocess.run(['pdftoppm', '-f', str(pg), '-l', str(pg), '-scale-to', '3300', '-png', '-singlefile', str(p), f'{td}/p{pg}'], check=True)
                imgs.append(f'{td}/p{pg}.png')
            turned, best = turn_upright(imgs, a.workers)
        if turned:
            hits.append(fn); print(f'{turned}/{len(imgs)} sampled pages turned: {fn} {best}', flush=True)
        if i % 25 == 0: print(f'  ... {i}/{len(done)} files', flush=True)
    pathlib.Path(a.out).write_text('\n'.join(hits) + ('\n' if hits else ''))
    print(f'done: {len(hits)} of {len(done)} files have sideways pages; list at {a.out}')
if __name__ == '__main__': main()
