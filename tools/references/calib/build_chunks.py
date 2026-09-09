#!/usr/bin/env python3
"""
Stage 1 of the calibration pipeline: reference text -> PaperQA2-geometry chunks.

Concatenates each document's pages in order, normalises what the extraction leaves
behind, and cuts chunks at the same chunk_chars/overlap PaperQA2 serves with, so a
calibration excerpt has the same shape as one the generator will really see. The
geometry is read from tools/references/paperqa.toml and is not redeclared here.

    python build_chunks.py [-o chunks.jsonl] [--min-chars 500]
"""
import argparse, json, pathlib, re, sys, tomllib

ROOT = pathlib.Path(__file__).resolve().parents[3]
CFG = tomllib.loads((ROOT / 'tools' / 'references' / 'paperqa.toml').read_text())
TEXT_DIR = ROOT / 'references' / 'text'

# A line carrying almost no letters is a rule, a dot leader or a table gutter, not prose.
SPARSE = re.compile(r'^[^A-Za-z]*$')
DOTS = re.compile(r'\.{4,}')


def page_lines(path):
    return [ln.rstrip() for ln in path.read_text(errors='replace').splitlines()]


def running_heads(pages, floor=0.30):
    """Lines repeated at the top or bottom of many pages: journal furniture, not content."""
    if len(pages) < 4:
        return set()
    seen = {}
    for lines in pages:
        body = [ln for ln in lines if ln.strip()]
        for ln in body[:2] + body[-2:]:
            key = re.sub(r'\d+', '#', ln.strip())
            if len(key) > 3:
                seen[key] = seen.get(key, 0) + 1
    return {k for k, n in seen.items() if n >= max(3, floor * len(pages))}


def normalise(lines, heads):
    out = []
    for ln in lines:
        s = ln.strip()
        if not s:
            out.append('')
            continue
        if re.sub(r'\d+', '#', s) in heads:
            continue
        if SPARSE.match(s) or DOTS.search(s):
            continue
        out.append(re.sub(r'[ \t]{2,}', ' ', s))
    text = '\n'.join(out)
    return re.sub(r'\n{3,}', '\n\n', text).strip()


def document(slug_dir):
    """Return (text, page_index) where page_index maps a character offset to a page number."""
    paths = sorted(p for p in slug_dir.glob('*.txt'))
    pages = [page_lines(p) for p in paths]
    heads = running_heads(pages)
    parts, index, pos = [], [], 0
    for path, lines in zip(paths, pages):
        body = normalise(lines, heads)
        if not body:
            continue
        page_no = int(path.stem)
        parts.append(body)
        index.append((pos, page_no))
        pos += len(body) + 2
    return '\n\n'.join(parts), index


def page_at(index, offset):
    page = index[0][1] if index else 0
    for start, no in index:
        if start > offset:
            break
        page = no
    return page


def chunk(text, size, overlap):
    step = size - overlap
    for start in range(0, max(1, len(text)), step):
        piece = text[start:start + size]
        if piece.strip():
            yield start, piece
        if start + size >= len(text):
            break


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-o', '--out', default=str(pathlib.Path(__file__).parent / 'chunks.jsonl'))
    ap.add_argument('--min-chars', type=int, default=500, help='drop chunks shorter than this')
    a = ap.parse_args()

    size, overlap = CFG.get('chunk_chars', 4000), CFG.get('overlap', 200)
    titles = {}
    mf = TEXT_DIR / 'manifest.jsonl'
    if mf.is_file():
        for line in mf.read_text().splitlines():
            if line.strip():
                rec = json.loads(line)
                titles[pathlib.Path(rec['file']).stem] = rec

    slugs = sorted(d for d in TEXT_DIR.iterdir() if d.is_dir())
    n_chunks = 0
    with open(a.out, 'w') as f:
        for i, d in enumerate(slugs):
            text, index = document(d)
            if not text:
                continue
            for start, piece in chunk(text, size, overlap):
                if len(piece) < a.min_chars:
                    continue
                page = page_at(index, start)
                f.write(json.dumps({
                    'doc': d.name,
                    'page': page,
                    'start': start,
                    'citation': f'{titles.get(d.name, {}).get("file", d.name)} p.{page}',
                    'text': piece,
                }) + '\n')
                n_chunks += 1
            if (i + 1) % 100 == 0:
                print(f'  {i + 1}/{len(slugs)} documents, {n_chunks} chunks', file=sys.stderr)
    print(f'{n_chunks} chunks from {len(slugs)} documents -> {a.out}')


if __name__ == '__main__':
    main()
