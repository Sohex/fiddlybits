#!/usr/bin/env python
"""Replace the per-page text of OCR-layered PDFs with Chandra OCR 2 output (Markdown, equations as LaTeX).

    chandra_pages.py <list of pdf filenames> [--method vllm|hf] [--long-side 3300] [--resume] [--batch N]

vllm (default): talks to the server started by tools/references/serve_chandra_vllm.sh (127.0.0.1:8000); every page
of a file is submitted as one batch and the client fans out up to 16 concurrent requests. hf: transformers in-process.
For each PDF: render every page, OCR it, write references/text/<stem>/<page>.txt, and append
{file, engine: chandra-ocr-2, method, pages, sha256} to references/text/manifest.jsonl so extract_text.py leaves the
file alone. A file is written only when all its pages are done; --resume skips files already recorded as chandra.
"""
import argparse, hashlib, json, pathlib, subprocess, time, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[2]; PDF = ROOT / 'references' / 'pdf'; TXT = ROOT / 'references' / 'text'; MAN = TXT / 'manifest.jsonl'
MODEL = '/home/cfutro/models/chandra-ocr-2'
def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for c in iter(lambda: f.read(1 << 22), b''): h.update(c)
    return h.hexdigest()
def main():
    ap = argparse.ArgumentParser(); ap.add_argument('list'); ap.add_argument('--method', default='vllm'); ap.add_argument('--batch', type=int, default=16); ap.add_argument('--long-side', type=int, default=3300); ap.add_argument('--resume', action='store_true'); a = ap.parse_args()
    from chandra.model.schema import BatchInputItem
    from PIL import Image
    Image.MAX_IMAGE_PIXELS = None   # our own rendered pages, not untrusted uploads
    if a.method == 'vllm':
        from chandra.model import InferenceManager
        mgr = InferenceManager(method='vllm')
        def ocr(imgs): return [r.markdown or '' for r in mgr.generate([BatchInputItem(image=Image.open(x), prompt_type='ocr_layout') for x in imgs])]
    else:
        import torch
        from transformers import AutoModelForImageTextToText, AutoProcessor
        from chandra.model.hf import generate_hf
        from chandra.output import parse_markdown
        model = AutoModelForImageTextToText.from_pretrained(MODEL, dtype=torch.bfloat16, device_map='cuda'); model.eval()
        model.processor = AutoProcessor.from_pretrained(MODEL); model.processor.tokenizer.padding_side = 'left'
        def ocr(imgs):
            out = []
            for i in range(0, len(imgs), a.batch): out += [parse_markdown(r.raw) for r in generate_hf([BatchInputItem(image=Image.open(x), prompt_type='ocr_layout') for x in imgs[i:i + a.batch]], model)]
            return out
    done = {}
    if MAN.exists():
        for l in open(MAN): r = json.loads(l); done[r['file']] = r
    files = [l.strip() for l in open(a.list) if l.strip()]
    if a.resume: files = [f for f in files if done.get(f, {}).get('engine') != 'chandra-ocr-2']
    out = open(MAN, 'a'); total = 0; t_all = time.time()
    for fn in files:
        p = PDF / fn; t0 = time.time()
        with tempfile.TemporaryDirectory() as td:
            subprocess.run(['pdftoppm', '-scale-to', str(a.long_side), '-png', str(p), f'{td}/p'], check=True)   # bounded long side: a page's declared size no longer decides the raster
            imgs = sorted(pathlib.Path(td).glob('p-*.png'), key=lambda x: int(x.stem.split('-')[-1]))
            texts = {}
            for i in range(0, len(imgs), a.batch):
                chunk = imgs[i:i + a.batch]
                for x, t in zip(chunk, ocr(chunk)): texts[int(x.stem.split('-')[-1])] = t
        d = TXT / p.stem
        for f in d.glob('*.txt'): f.unlink()
        d.mkdir(exist_ok=True)
        for n, t in texts.items(): (d / f'{n:04d}.txt').write_text(t)
        out.write(json.dumps({'file': fn, 'sha256': sha(p), 'pages': len(texts), 'chars': sum(len(t) for t in texts.values()), 'engine': 'chandra-ocr-2', 'method': a.method, 'long_side_px': a.long_side, 'extracted': time.strftime('%Y-%m-%dT%H:%M:%S')}) + '\n'); out.flush()
        total += len(texts); print(f'{fn}: {len(texts)} pages in {time.time()-t0:.0f}s ({total} pages, {total/(time.time()-t_all):.2f} p/s)', flush=True)
    print('done')
if __name__ == '__main__': main()
