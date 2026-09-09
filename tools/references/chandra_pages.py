#!/usr/bin/env python
"""Replace the per-page text of OCR-layered PDFs with Chandra OCR 2 output (Markdown, equations as LaTeX).

    chandra_pages.py <list of pdf filenames> [--method vllm|hf] [--long-side 3300] [--resume] [--batch N]
    chandra_pages.py <repair list: filename TAB page,page,...> --repair    # re-read only those pages

vllm (default): talks to the server started by tools/references/serve_chandra_vllm.sh (127.0.0.1:8000); every page
of a file is submitted as one batch and the client fans out up to 16 concurrent requests. hf: transformers in-process.
For each PDF: render every page, OCR it, write references/text/<stem>/<page>.txt, and append
{file, engine: chandra-ocr-2, method, pages, sha256} to references/text/manifest.jsonl so extract_text.py leaves the
file alone. A file is written only when all its pages are done; --resume skips files already recorded as chandra.

Pages are turned upright before they are read. Chandra does read sideways text, but on a rotated wide table it
drops columns and rows silently: on one JANAF page the sideways read lost the enthalpy column of every row and
one row entirely, while the same page turned upright matched the printed table (measured 2026-09-09,
notes/findings/2026-09-09-chandra-page-orientation.md). Orientation comes from tesseract's own detector, applied
from the quarter turn tesseract reads most confidently, snapped to the file's own majority where a page is
undecided, and --no-orient skips the step.
"""
import argparse, os, hashlib, json, pathlib, subprocess, time, tempfile
from concurrent.futures import ThreadPoolExecutor
ROOT = pathlib.Path(__file__).resolve().parents[2]; PDF = ROOT / 'references' / 'pdf'; TXT = ROOT / 'references' / 'text'; MAN = TXT / 'manifest.jsonl'
MODEL = '/home/cfutro/models/chandra-ocr-2'
def _conf_mass(img):
    """Total word confidence tesseract reports for one image: high when the text is the right way up."""
    with tempfile.TemporaryDirectory() as td:
        f = f'{td}/c.png'; img.save(f)
        subprocess.run(['tesseract', f, f'{td}/o', 'tsv'], capture_output=True, text=True)
        try: rows = open(f'{td}/o.tsv').read().splitlines()[1:]
        except FileNotFoundError: return 0.0
    total = 0.0
    for l in rows:
        c = l.split('\t')
        if len(c) > 11 and c[10] not in ('conf', '-1') and c[11].strip():
            try: total += float(c[10])
            except ValueError: pass
    return total

def osd(png):
    """Tesseract's own orientation detector, at the resolution the page was rendered: the quarter turn it says the
    page needs, and how sure it is. Cheap, and right about the eight true rotations of the labelled set, but it
    calls an upright figure page rotated when the plots carry turned axis titles, so its non-zero verdicts are
    referred to the arbiter below. Downscaling it first is what made it look unreliable (14 of 21 at 1200 pixels
    against 18 at the native render)."""
    r = subprocess.run(['tesseract', png, '-', '--psm', '0'], capture_output=True, text=True)
    deg = conf = 0.0
    for l in r.stdout.splitlines():
        if l.startswith('Rotate:'): deg = float(l.split(':')[1])
        elif l.startswith('Orientation confidence:'): conf = float(l.split(':')[1])
    return int(deg) % 360, conf

def page_scores(png, side=900):
    """Confidence mass at each quarter turn, on a downscaled centre crop. The crop drops running heads, which on a
    rotated table page point the other way from the body and are not what the reader wants upright."""
    from PIL import Image
    im = Image.open(png); im.thumbnail((side, side))
    w, h = im.size; crop = im.crop((int(w * .12), int(h * .12), int(w * .88), int(h * .88)))
    return {d: _conf_mass(crop.rotate(-d, expand=True)) for d in (0, 90, 180, 270)}

def page_turn(png, min_ratio=3.0, min_mass=1500.0, min_conf=1.0):
    """The quarter turn one page needs, in two stages: tesseract's orientation detector decides whether the page is
    worth a second look, and only a page it calls turned, or one it cannot judge, pays for the arbiter. The arbiter
    turns a page only when the winning quarter turn beats leaving it alone by `min_ratio` and reads as a page of
    text rather than a few axis labels (`min_mass`): measured 2026-09-09, true rotations beat upright by five times
    and up on thousands of words, while a figure page's turned axis titles clear any ratio on tens of words."""
    deg, conf = osd(png)
    if deg == 0 and conf >= min_conf: return 0
    sc = page_scores(png); d = max(sc, key=sc.get)
    return d if d and sc[d] >= min_ratio * max(sc[0], 1.0) and sc[d] >= min_mass else 0

def turn_upright(imgs, workers, snap_scores=False):
    """Turn every page of one file upright. The per-page test is right about the axis and can still mistake a
    quarter turn for its opposite, so a page whose turn disagrees with the rest of the file is snapped to the
    file's own majority. Returns (pages turned, the applied turn per page)."""
    from PIL import Image
    with ThreadPoolExecutor(max_workers=workers) as ex: best = list(ex.map(page_turn, imgs))
    turned_dirs = [d for d in best if d]
    if turned_dirs:
        major = max(set(turned_dirs), key=turned_dirs.count)
        best = [major if d else 0 for d in best]
    n = 0
    for f, d in zip(imgs, best):
        if d: Image.open(f).rotate(-d, expand=True).save(f); n += 1
    return n, best

def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for c in iter(lambda: f.read(1 << 22), b''): h.update(c)
    return h.hexdigest()
def repair(a, ocr, done):
    """Read again only the pages a list names, and rewrite only those page files. A file whose one landscape table
    was read sideways does not need its other pages read a second time."""
    out = open(MAN, 'a')
    for line in open(a.list):
        if not line.strip(): continue
        fn, pages = line.rstrip('\n').split('\t'); pages = [int(x) for x in pages.split(',')]
        p = PDF / fn; t0 = time.time()
        with tempfile.TemporaryDirectory() as td:
            imgs = []
            for pg in pages:
                subprocess.run(['pdftoppm', '-f', str(pg), '-l', str(pg), '-scale-to', str(a.long_side), '-png', '-singlefile', str(p), f'{td}/{pg:05d}'], check=True)
                imgs.append(f'{td}/{pg:05d}.png')
            turned, _ = turn_upright(imgs, max(4, int(os.environ.get('SLURM_CPUS_PER_TASK', '4'))))
            texts = {}
            for i in range(0, len(imgs), a.batch):
                chunk = imgs[i:i + a.batch]
                for x, t in zip(chunk, ocr(chunk)): texts[int(pathlib.Path(x).stem)] = t
        d = TXT / p.stem
        for n, t in texts.items(): (d / f'{n:04d}.txt').write_text(t)
        prev = done.get(fn, {})
        out.write(json.dumps({'file': fn, 'sha256': prev.get('sha256') or sha(p), 'pages': prev.get('pages') or len(texts),
                              'chars': sum(len(x.read_text()) for x in sorted(d.glob('*.txt'))), 'engine': 'chandra-ocr-2', 'method': a.method,
                              'long_side_px': a.long_side, 'repaired_pages': pages, 'pages_turned_upright': turned,
                              'extracted': time.strftime('%Y-%m-%dT%H:%M:%S')}) + '\n'); out.flush()
        print(f'{fn}: repaired {len(texts)} pages ({turned} turned) in {time.time()-t0:.0f}s', flush=True)
    print('done: repair pass')

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('list'); ap.add_argument('--repair', action='store_true'); ap.add_argument('--method', default='vllm'); ap.add_argument('--batch', type=int, default=16); ap.add_argument('--long-side', type=int, default=3300); ap.add_argument('--resume', action='store_true'); ap.add_argument('--no-orient', action='store_true'); a = ap.parse_args()
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
    if a.repair:
        return repair(a, ocr, done)
    files = [l.strip() for l in open(a.list) if l.strip()]
    if a.resume: files = [f for f in files if done.get(f, {}).get('engine') != 'chandra-ocr-2']
    out = open(MAN, 'a'); total = 0; t_all = time.time()
    for fn in files:
        p = PDF / fn; t0 = time.time()
        with tempfile.TemporaryDirectory() as td:
            subprocess.run(['pdftoppm', '-scale-to', str(a.long_side), '-png', str(p), f'{td}/p'], check=True)   # bounded long side: a page's declared size no longer decides the raster
            imgs = sorted(pathlib.Path(td).glob('p-*.png'), key=lambda x: int(x.stem.split('-')[-1]))
            turned = 0
            if not a.no_orient:
                turned, _ = turn_upright([str(x) for x in imgs], max(4, int(os.environ.get('SLURM_CPUS_PER_TASK', '4'))))
            texts = {}
            for i in range(0, len(imgs), a.batch):
                chunk = imgs[i:i + a.batch]
                for x, t in zip(chunk, ocr(chunk)): texts[int(x.stem.split('-')[-1])] = t
        d = TXT / p.stem
        for f in d.glob('*.txt'): f.unlink()
        d.mkdir(exist_ok=True)
        for n, t in texts.items(): (d / f'{n:04d}.txt').write_text(t)
        out.write(json.dumps({'file': fn, 'sha256': sha(p), 'pages': len(texts), 'chars': sum(len(t) for t in texts.values()), 'engine': 'chandra-ocr-2', 'method': a.method, 'long_side_px': a.long_side, 'pages_turned_upright': turned, 'extracted': time.strftime('%Y-%m-%dT%H:%M:%S')}) + '\n'); out.flush()
        total += len(texts); print(f'{fn}: {len(texts)} pages ({turned} turned) in {time.time()-t0:.0f}s ({total} pages, {total/(time.time()-t_all):.2f} p/s)', flush=True)
    print('done')
if __name__ == '__main__': main()
