#!/usr/bin/env python
"""Extract per-page text from every PDF in references/pdf/ into references/text/<stem>/<page>.txt (untracked),
with references/text/manifest.jsonl recording each PDF's sha256, page count, extraction mode and time, so a paper
is re-extracted when its bytes change or when the mode it was extracted under is no longer the one asked for.

Default mode is reading order, which rejoins hyphenated line breaks and does not interleave the columns of a
two-column page; --mode layout and --mode raw select pdftotext's other two. A page whose tables matter is read by
chandra_pages.py instead, which returns real table markup. See
notes/findings/2026-09-09-text-extraction-layout.md.

Two manifest fields make this script leave a source alone, and both are set by whatever wrote the text:
`engine` naming an OCR reader, and `policy = "pointer"` for a source whose text directory is maintained by hand
(docs/references/README.md, "Sources whose text is a pointer"). Everything else is extracted, and re-extracted when
its bytes or the requested mode change.
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
        if prev.get('policy') == 'pointer': n_skip += 1; continue   # text maintained by hand, not extracted
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
