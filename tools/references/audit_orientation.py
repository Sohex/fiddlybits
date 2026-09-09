#!/usr/bin/env python
"""Which pages of the already-read files were read sideways? Scores every page of every file recorded as
chandra-ocr-2 with the same two-stage test the reading recipe uses, and writes a repair list of
`filename<TAB>page,page,...` for chandra_pages.py --repair. Every page is examined: a single landscape table in an
otherwise upright paper is exactly the case a sample would miss (notes/findings/2026-09-09-chandra-page-orientation.md).

    audit_orientation.py <out list> [--workers 8] [--only <substring>]
"""
import argparse, json, pathlib, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from chandra_pages import page_turn, MAN, PDF
def main():
    ap = argparse.ArgumentParser(); ap.add_argument('out'); ap.add_argument('--workers', type=int, default=8); ap.add_argument('--only', default=''); a = ap.parse_args()
    done = {}
    for l in open(MAN):
        r = json.loads(l)
        if r.get('engine') == 'chandra-ocr-2': done[r['file']] = r
    files = sorted(f for f in done if a.only in f)
    out_lines = []; n_pages = n_turned = 0
    for i, fn in enumerate(files, 1):
        p = PDF / fn
        if not p.exists(): print('missing', fn, flush=True); continue
        with tempfile.TemporaryDirectory() as td:
            subprocess.run(['pdftoppm', '-scale-to', '3300', '-png', str(p), f'{td}/p'], check=True)
            imgs = sorted(pathlib.Path(td).glob('p-*.png'), key=lambda x: int(x.stem.split('-')[-1]))
            with ThreadPoolExecutor(max_workers=a.workers) as ex: verdicts = list(ex.map(page_turn, [str(x) for x in imgs]))
        turned = [int(x.stem.split('-')[-1]) for x, d in zip(imgs, verdicts) if d]
        n_pages += len(imgs); n_turned += len(turned)
        if turned:
            out_lines.append(f'{fn}\t{",".join(str(t) for t in turned)}')
            print(f'{len(turned):4d} of {len(imgs):4d} pages sideways: {fn}', flush=True)
        if i % 20 == 0: print(f'  ... {i}/{len(files)} files, {n_pages} pages', flush=True)
    pathlib.Path(a.out).write_text('\n'.join(out_lines) + ('\n' if out_lines else ''))
    print(f'done: {n_turned} sideways pages in {len(out_lines)} of {len(files)} files, {n_pages} pages examined; repair list at {a.out}')
if __name__ == '__main__': main()
