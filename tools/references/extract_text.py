#!/usr/bin/env python
"""Extract per-page text from every PDF in references/pdf/ into references/text/<stem>/<page>.txt (untracked),
with references/text/manifest.jsonl recording each PDF's sha256, page count, extraction mode and time, so a paper
is re-extracted when its bytes change or when the mode it was extracted under is no longer the one asked for.

Text comes out in reading order, not in page layout. Measured 2026-09-09 on a sample of the held papers: with
pdftotext's -layout, 38 percent of non-empty lines on a two-column paper carry text from both columns side by side,
so a sentence is interrupted mid-clause by an unrelated one; in reading order that figure is zero and hyphenated
line breaks are rejoined. The flag's usual defence is that it preserves table alignment, and on these papers it does
not: a two-column page aligns the page's columns, not the table's, so a table is interleaved with the prose beside
it. A page whose tables matter is read by chandra_pages.py instead, which returns real table markup.

Files read by Chandra are never touched here: their manifest entry names the engine, and this script skips them. This is the first instrument of the references archive: it makes
`rg` across every held paper a page-cited search. Retrieval returns locators, never values (docs/references/README.md).
"""
import argparse, hashlib, json, pathlib, subprocess, sys, time, shutil
ROOT = pathlib.Path(__file__).resolve().parents[2]
PDF = ROOT / 'references' / 'pdf'; TXT = ROOT / 'references' / 'text'; MAN = TXT / 'manifest.jsonl'
def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for c in iter(lambda: f.read(1 << 22), b''): h.update(c)
    return h.hexdigest()
MODE = {'reading-order': [], 'layout': ['-layout'], 'raw': ['-raw']}

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--mode', choices=sorted(MODE), default='reading-order'); a = ap.parse_args()
    TXT.mkdir(parents=True, exist_ok=True)
    done = {}
    if MAN.exists():
        for l in open(MAN): r = json.loads(l); done[r['file']] = r
    out = open(MAN, 'a'); n_new = n_skip = 0
    for p in sorted(PDF.glob('*.pdf')):
        h = sha(p)
        prev = done.get(p.name, {})
        if prev.get('engine') == 'chandra-ocr-2': n_skip += 1; continue   # never overwrite a page a model read
        if prev.get('sha256') == h and prev.get('mode') == a.mode and (TXT / p.stem).is_dir(): n_skip += 1; continue
        d = TXT / p.stem
        if d.exists(): shutil.rmtree(d)
        d.mkdir()
        info = subprocess.run(['pdfinfo', str(p)], capture_output=True, text=True).stdout
        pages = int(next((l.split()[1] for l in info.splitlines() if l.startswith('Pages:')), '0') or 0)
        for i in range(1, pages + 1):
            t = subprocess.run(['pdftotext'] + MODE[a.mode] + ['-f', str(i), '-l', str(i), str(p), '-'], capture_output=True, text=True).stdout
            (d / f'{i:04d}.txt').write_text(t)
        chars = sum(len((d / f'{i:04d}.txt').read_text()) for i in range(1, pages + 1))
        out.write(json.dumps({'file': p.name, 'sha256': h, 'pages': pages, 'chars': chars, 'mode': a.mode, 'extracted': time.strftime('%Y-%m-%dT%H:%M:%S')}) + '\n'); out.flush(); n_new += 1
        if n_new % 50 == 0: print(n_new, 'extracted', flush=True)
    print(f'done: extracted={n_new} unchanged={n_skip}')
if __name__ == '__main__': main()
