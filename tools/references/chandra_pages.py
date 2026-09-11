#!/usr/bin/env python
"""Replace the per-page text of OCR-layered PDFs with Chandra OCR 2 output (Markdown, equations as LaTeX).

    chandra_pages.py <list of pdf filenames> [--method vllm|hf] [--long-side 3300] [--resume] [--batch N]
    chandra_pages.py <repair list: filename TAB page,page,...> --repair    # re-read only those pages

vllm (default): talks to the server started by tools/references/serve_chandra_vllm.sh (127.0.0.1:8000); every page
of a file is submitted as one batch and the client fans out up to 16 concurrent requests. hf: transformers in-process.
For each PDF: render every page, OCR it, write references/text/<stem>/<page>.txt, and append
{file, engine: chandra-ocr-2, method, pages, sha256} to references/text/manifest.jsonl so extract_text.py leaves the
file alone. A file is written only when all its pages are done; --resume skips files already recorded as chandra.

Pages are turned upright before they are read, because a rotated wide table loses columns and rows silently.
Orientation comes from tesseract's own detector, applied from the quarter turn it reads most confidently and
snapped to the file's own majority where a page is undecided; --no-orient skips the step. See
notes/findings/2026-09-09-chandra-page-orientation.md.
"""
import argparse, os, hashlib, json, pathlib, shutil, subprocess, time, tempfile
from concurrent.futures import ThreadPoolExecutor
ROOT = pathlib.Path(__file__).resolve().parents[2]; PDF = ROOT / 'references' / 'pdf'; TXT = ROOT / 'references' / 'text'; MAN = TXT / 'manifest.jsonl'
# Rendered pages are large and there are many of them; on this machine /tmp is a tmpfs, so the default
# temporary directory would hold a whole book in RAM and the machine would swap. Render to disk unless
# the caller has already chosen somewhere.
os.environ.setdefault('TMPDIR', str(ROOT / 'references' / 'work' / 'tmp'))
# One thread per tesseract. It spawns one OpenMP thread per visible CPU by default, so a pool of them
# oversubscribes every core and each process gets a fraction of one: the pool size is the parallelism.
os.environ.setdefault('OMP_THREAD_LIMIT', '1')

def cores(): return max(4, int(os.environ.get('SLURM_CPUS_PER_TASK', '4')))
pathlib.Path(os.environ['TMPDIR']).mkdir(parents=True, exist_ok=True)
tempfile.tempdir = os.environ['TMPDIR']
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

def render_pages(pdf, outdir, long_side, workers, chunk=8):
    """Render a whole document to `outdir` across the job's cores. pdftoppm is one process on one page at a time,
    so a long book rendered by a single call leaves every other core and the card idle for minutes; page ranges
    split cleanly and poppler numbers the files by page, so the chunks reassemble by name."""
    n = pages_of(pdf)
    ranges = [(a, min(a + chunk - 1, n)) for a in range(1, n + 1, chunk)]
    def one(r):
        subprocess.run(['pdftoppm', '-f', str(r[0]), '-l', str(r[1]), '-scale-to', str(long_side), '-png',
                        str(pdf), f'{outdir}/p'], check=True)
    with ThreadPoolExecutor(max_workers=workers) as ex: list(ex.map(one, ranges))
    return sorted(pathlib.Path(outdir).glob('p-*.png'), key=lambda x: int(x.stem.split('-')[-1]))

def pages_of(pdf):
    info = subprocess.run(['pdfinfo', str(pdf)], capture_output=True, text=True).stdout
    return int(next((l.split()[1] for l in info.splitlines() if l.startswith('Pages:')), '0') or 0)

def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for c in iter(lambda: f.read(1 << 22), b''): h.update(c)
    return h.hexdigest()
# A source whose numbers have a machine-readable home keeps a one-page stub naming that home instead of its text
# (see ask.py, parse_from_extracted_text). The stub is not a partial read waiting to be finished: reading the book
# would replace a deliberate pointer with 1961 pages of numbers transcribed from a photograph of a table, which is
# what the stub exists to prevent. Its manifest row was deleted with its text, so --resume cannot tell it from a
# file that was never read, and until now only its absence from a hand-kept list protected it.
STUB_MARK = 'THIS SOURCE IS DELIBERATELY NOT INDEXED'

def is_stub(fn):
    d = TXT / pathlib.Path(fn).stem
    pages = sorted(d.glob('*.txt')) if d.is_dir() else []
    if len(pages) != 1: return False
    if STUB_MARK not in pages[0].read_text(errors='ignore'): return False
    print(f'{fn}: pointer stub, left alone', flush=True)
    return True


# ---------------------------------------------------------------------------------------------------------------
# Reading is three stages with different bottlenecks: pdftoppm and tesseract are CPU, the card is the model, and
# writing is neither. Done a file at a time they run in series, and measured on the 2026-09-10 repair pass that
# cost 36 seconds of fixed CPU per file with the card idle through all of it, against 3.4 seconds a page of
# actual reading. Worse, a batch was one file's pages, and 84 of those 88 files held fewer pages than the fan-out,
# so the card ran 4 or 5 requests deep where it had room for 16. Generation throughput tracks that depth almost
# linearly, 70 to 90 tokens a second at one request against 800 and up at fourteen, so a small file is not a small
# job, it is the same job run at a third of the rate.
#
# So: prepare ahead on the CPU while the card reads, and draw each batch from every page prepared rather than from
# one file. Orientation stays per file, because its majority-snapping rule is about a document and means nothing
# across two.

class _Prepared:
    """One file's pages, rendered and turned upright, waiting to be read. Holds its own temporary directory open
    until the last of its pages comes back, which is why this is a class and not a tuple."""
    __slots__ = ('key', 'td', 'nums', 'imgs', 'turned', 'texts', 'nbytes')
    def __init__(self, key, td, nums, imgs, turned):
        self.key, self.td, self.nums, self.imgs, self.turned = key, td, nums, imgs, turned
        self.texts = {}
        # What it costs to be held: the rendered pages themselves, which is what the budget below is spent on.
        self.nbytes = sum(os.path.getsize(i) for i in imgs)
    def done(self): return len(self.texts) == len(self.nums)
    def close(self): shutil.rmtree(self.td, ignore_errors=True)


def _prepare(key, pdf, pages, long_side, orient, workers):
    """Render the pages wanted and turn them upright. Whole document when `pages` is None."""
    td = tempfile.mkdtemp()
    if pages is None:
        imgs = [str(x) for x in render_pages(pdf, td, long_side, workers)]
        nums = [int(pathlib.Path(x).stem.split('-')[-1]) for x in imgs]
    else:
        nums, imgs = list(pages), []
        # One pdftoppm per page here, unlike render_pages: a repair list is a handful of scattered pages, and a
        # range that spanned them would render everything in between.
        with ThreadPoolExecutor(max_workers=workers) as ex:
            def one(pg):
                subprocess.run(['pdftoppm', '-f', str(pg), '-l', str(pg), '-scale-to', str(long_side), '-png',
                                '-singlefile', str(pdf), f'{td}/{pg:05d}'], check=True)
                return f'{td}/{pg:05d}.png'
            imgs = list(ex.map(one, nums))
    turned = 0
    if orient: turned, _ = turn_upright(imgs, workers)
    return _Prepared(key, td, nums, imgs, turned)


def bytesize(x):
    """A size with an optional K, M or G suffix, so a budget reads like the memory it stands for."""
    x = x.strip()
    mult = {'K': 1024, 'M': 1024 ** 2, 'G': 1024 ** 3}.get(x[-1:].upper())
    return int(float(x[:-1]) * mult) if mult else int(x)


DEFAULT_RENDER_BUDGET = 1024 ** 3
"""How many bytes of rendered pages may wait to be read at once.

A gigabyte is about 1700 pages at the 0.6 MB a page renders to here, which is more runway than any repair list
needs and still holds the largest book in the archive, 966 pages at about 580 MB, with room to start the next.
The pages are written to TMPDIR, which the reading chain puts on disk precisely because /tmp here is a tmpfs;
where that has not been done they are resident, so this is a memory bound as much as a disk one. --render-budget
moves it.
"""


def read_files(specs, ocr, inflight, long_side, orient, workers, budget=None):
    """Read every page of every spec, yielding (key, {page: text}, pages_turned) as each file completes.

    specs: (key, pdf_path, pages or None). Files come out as they finish, not in the order they went in.

    Three stages with different bottlenecks, run at once instead of in series. Preparing is pdftoppm and tesseract
    and belongs on the cores; reading is the card; neither should wait on the other, and neither should wait on a
    file boundary, which is an artefact of how the work was listed rather than anything the hardware cares about.

      preparers (one per core)  ->  pool of prepared pages  ->  readers (one per request in flight)

    The readers submit one page each and take the next the moment it returns, so the server always has `inflight`
    requests to schedule and never drains between batches. That is what saturation means here: vllm batches across
    concurrent requests itself, and its generation throughput tracks how many are running, so the client's job is
    to keep the number up rather than to assemble batches of its own.

    How far preparing runs ahead is bounded by bytes, not by a count of files, because a file is not a unit of
    anything: one spec is two pages of a paper and the next is a 966-page book. A preparer stops before starting a
    file whenever the pages already waiting exceed the budget, so the overshoot is at most one file per preparer,
    nothing being able to know what a book renders to until it is rendered.
    """
    import queue, threading
    budget = budget or DEFAULT_RENDER_BUDGET
    pool = queue.Queue()                       # prepared pages: (prepared, page number, image path)
    outq = queue.Queue()                       # finished files, and the errors that stopped one
    lock = threading.Condition(); held = [0]   # bytes of prepared pages not yet read
    src = iter(specs); src_lock = threading.Lock()
    live = threading.Semaphore(0)              # counts pages in the pool, so readers can be told to stop

    def release(pre):
        with lock: held[0] -= pre.nbytes; lock.notify_all()
        pre.close()

    def prepare_loop():
        while True:
            with src_lock: spec = next(src, None)
            if spec is None: return
            key, pdf, pages = spec
            try:
                with lock:
                    while held[0] >= budget: lock.wait()
                pre = _prepare(key, pdf, pages, long_side, orient, 1)
            except BaseException as e:
                outq.put(('!', e)); return
            with lock: held[0] += pre.nbytes
            if not pre.nums:                   # a spec naming no pages
                release(pre); outq.put(('.', (pre.key, {}, pre.turned))); continue
            for n, i in zip(pre.nums, pre.imgs):
                pool.put((pre, n, i)); live.release()

    def read_loop():
        while True:
            live.acquire()
            item = pool.get()
            if item is None: return            # the stop token, one per reader
            pre, n, img = item
            try:
                text = ocr([img])[0]
            except BaseException as e:
                outq.put(('!', e)); return
            with lock:
                pre.texts[n] = text
                finished = pre.done()
            if finished:
                texts, turned = pre.texts, pre.turned; release(pre)
                outq.put(('.', (pre.key, texts, turned)))

    # One preparer per core, because pdftoppm and tesseract are each one process on one page and a file is too
    # small a unit to fill a machine; page rotation inside a file therefore takes one thread, not a pool of its own.
    preparers = [threading.Thread(target=prepare_loop, daemon=True) for _ in range(max(1, workers))]
    readers = [threading.Thread(target=read_loop, daemon=True) for _ in range(max(1, inflight))]
    for t in preparers + readers: t.start()

    def wind_down():
        for t in preparers: t.join()
        for _ in readers: pool.put(None); live.release()
        for t in readers: t.join()
        outq.put(None)
    threading.Thread(target=wind_down, daemon=True).start()

    while True:
        item = outq.get()
        if item is None: break
        kind, payload = item
        if kind == '!': raise payload
        yield payload


def repair(a, ocr, done):
    """Read again only the pages a list names, and rewrite only those page files. A file whose one landscape table
    was read sideways does not need its other pages read a second time.

    --resume skips a file whose last manifest row already records the same repaired pages, so an interrupted pass
    picks up where it stopped instead of reading everything again from the top.
    """
    rows = []
    for line in open(a.list):
        if not line.strip(): continue
        fn, pages = line.rstrip('\n').split('\t')
        rows.append((fn, [int(x) for x in pages.split(',')]))
    if a.resume:
        before = len(rows)
        rows = [(fn, pg) for fn, pg in rows if done.get(fn, {}).get('repaired_pages') != pg]
        if before != len(rows): print(f'resuming: {before - len(rows)} of {before} files already repaired', flush=True)
    out = open(MAN, 'a'); t_all = time.time(); total = 0
    specs = [(fn, PDF / fn, pg) for fn, pg in rows]
    want = dict(rows)
    for fn, texts, turned in read_files(specs, ocr, a.batch, a.long_side, not a.no_orient, cores(), a.render_budget):
        p = PDF / fn; d = TXT / pathlib.Path(fn).stem
        for n, t in texts.items(): (d / f'{n:04d}.txt').write_text(t)
        prev = done.get(fn, {})
        out.write(json.dumps({'file': fn, 'sha256': prev.get('sha256') or sha(p), 'pages': prev.get('pages') or len(texts),
                              'chars': sum(len(x.read_text()) for x in sorted(d.glob('*.txt'))), 'engine': 'chandra-ocr-2', 'method': a.method,
                              'long_side_px': a.long_side, 'repaired_pages': want[fn], 'pages_turned_upright': turned,
                              'extracted': time.strftime('%Y-%m-%dT%H:%M:%S')}) + '\n'); out.flush()
        total += len(texts)
        print(f'{fn}: repaired {len(texts)} pages ({turned} turned) '
              f'[{total} pages, {total/(time.time()-t_all):.2f} p/s]', flush=True)
    print('done: repair pass')


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('list'); ap.add_argument('--repair', action='store_true'); ap.add_argument('--method', default='vllm'); ap.add_argument('--batch', type=int, default=16, metavar='N',
                    help='requests kept in flight against the reader. The server batches across concurrent requests itself, so this is what decides how deep it runs'); ap.add_argument('--long-side', type=int, default=3300); ap.add_argument('--resume', action='store_true'); ap.add_argument('--no-orient', action='store_true')
    ap.add_argument('--render-budget', type=bytesize, default=None, metavar='SIZE',
                    help='how many bytes of rendered pages may wait to be read at once, e.g. 6G. Default 1G, about 1700 pages')
    a = ap.parse_args()
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
    files = [f for f in files if not is_stub(f)]
    out = open(MAN, 'a'); total = 0; t_all = time.time()
    specs = [(fn, PDF / fn, None) for fn in files]
    for fn, texts, turned in read_files(specs, ocr, a.batch, a.long_side, not a.no_orient, cores(), a.render_budget):
        p = PDF / fn; d = TXT / p.stem
        for f in d.glob('*.txt'): f.unlink()
        d.mkdir(exist_ok=True)
        for n, t in texts.items(): (d / f'{n:04d}.txt').write_text(t)
        out.write(json.dumps({'file': fn, 'sha256': sha(p), 'pages': len(texts), 'chars': sum(len(t) for t in texts.values()), 'engine': 'chandra-ocr-2', 'method': a.method, 'long_side_px': a.long_side, 'pages_turned_upright': turned, 'extracted': time.strftime('%Y-%m-%dT%H:%M:%S')}) + '\n'); out.flush()
        total += len(texts); print(f'{fn}: {len(texts)} pages ({turned} turned) ({total} pages, {total/(time.time()-t_all):.2f} p/s)', flush=True)
    print('done')
if __name__ == '__main__': main()
