#!/usr/bin/env python
"""Extract per-page text from every PDF in references/pdf/ into references/text/<stem>/<page>.txt (untracked),
with references/text/manifest.jsonl recording each PDF's sha256, page count and extraction time, so a paper is
re-extracted only when its bytes change. This is the first instrument of the references archive: it makes
`rg` across every held paper a page-cited search. Retrieval returns locators, never values (docs/references/README.md).
"""
import hashlib, json, pathlib, subprocess, sys, time, shutil
ROOT = pathlib.Path(__file__).resolve().parents[2]
PDF = ROOT / 'references' / 'pdf'; TXT = ROOT / 'references' / 'text'; MAN = TXT / 'manifest.jsonl'
def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for c in iter(lambda: f.read(1 << 22), b''): h.update(c)
    return h.hexdigest()
def main():
    TXT.mkdir(parents=True, exist_ok=True)
    done = {}
    if MAN.exists():
        for l in open(MAN): r = json.loads(l); done[r['file']] = r
    out = open(MAN, 'a'); n_new = n_skip = 0
    for p in sorted(PDF.glob('*.pdf')):
        h = sha(p)
        if p.name in done and done[p.name]['sha256'] == h and (TXT / p.stem).is_dir(): n_skip += 1; continue
        d = TXT / p.stem
        if d.exists(): shutil.rmtree(d)
        d.mkdir()
        info = subprocess.run(['pdfinfo', str(p)], capture_output=True, text=True).stdout
        pages = int(next((l.split()[1] for l in info.splitlines() if l.startswith('Pages:')), '0') or 0)
        for i in range(1, pages + 1):
            t = subprocess.run(['pdftotext', '-layout', '-f', str(i), '-l', str(i), str(p), '-'], capture_output=True, text=True).stdout
            (d / f'{i:04d}.txt').write_text(t)
        chars = sum(len((d / f'{i:04d}.txt').read_text()) for i in range(1, pages + 1))
        out.write(json.dumps({'file': p.name, 'sha256': h, 'pages': pages, 'chars': chars, 'extracted': time.strftime('%Y-%m-%dT%H:%M:%S')}) + '\n'); out.flush(); n_new += 1
        if n_new % 50 == 0: print(n_new, 'extracted', flush=True)
    print(f'done: extracted={n_new} unchanged={n_skip}')
if __name__ == '__main__': main()
