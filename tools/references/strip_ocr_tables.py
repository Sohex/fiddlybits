#!/usr/bin/env python
"""Remove every table from the text of a source that was read by OCR. The cells go; the caption and the page
stay as a marker, so retrieval can still find the table and the reader opens the scan for its numbers.

    strip_ocr_tables.py                 # dry run over every OCR-read source in references/text
    strip_ocr_tables.py --apply

Why: OCR prose comes back faithful and OCR tables do not. On the one source whose columns check each other,
the NIST-JANAF fourth edition, 493 of 1071 table pages were silently wrong; across the corpus the reader
invented 255 tables by reading values off figures (notes/findings/2026-09-09-janaf-table-identities.md,
notes/findings/2026-09-09-tables-invented-from-figures.md). A re-read at a higher pixel budget fixed some and
left the rest unverifiable, and a number that cannot be verified must not be quotable with a page citation.
Sources with a real text layer are not touched: their tables were never OCR'd.

Runs as the last step of tools/references/ocr_read_chain.sh so a fresh read cannot reintroduce them.
"""
import argparse, json, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parents[2]
TXT = ROOT / 'references' / 'text'
MAN = TXT / 'manifest.jsonl'
TABLE = re.compile(r'<table\b.*?</table>', re.S)
CAPTION = re.compile(r'<caption>(.*?)</caption>', re.S | re.I)
ROW = re.compile(r'<tr\b', re.I)
MARKED = re.compile(r'^\[table on page \d+', re.M)


def ocr_sources():
    """Stems of every source whose text came from Chandra, by the manifest's last word on each file."""
    eng = {}
    for l in MAN.read_text().splitlines():
        if l.strip():
            r = json.loads(l)
            eng[pathlib.Path(r['file']).stem] = r.get('engine')
    return {s for s, e in eng.items() if e == 'chandra-ocr-2'}


def marker(tb, page):
    cap = CAPTION.search(tb)
    text = re.sub(r'<[^>]+>', '', cap.group(1)).strip() if cap else ''
    rows = len(ROW.findall(tb))
    head = f'[table on page {page}, {rows} rows, not transcribed'
    return (head + (f': "{text}"' if text else '') +
            '. Cells read by OCR are not reproduced; open the scan for the numbers.]')


def strip_page(text, page):
    n = 0
    def sub(m):
        nonlocal n; n += 1
        return marker(m.group(0), page)
    new = TABLE.sub(sub, text)
    new = re.sub(r'\n{4,}', '\n\n\n', new)
    return new, n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true')
    a = ap.parse_args()
    srcs = ocr_sources()
    n_src = n_pages = n_tab = 0
    for d in sorted(TXT.iterdir()):
        if not d.is_dir() or d.name not in srcs:
            continue
        hit = False
        for p in sorted(d.glob('*.txt')):
            text = p.read_text(errors='replace')
            if '<table' not in text:
                continue
            new, n = strip_page(text, int(p.stem))
            if not n:
                continue
            hit = True; n_pages += 1; n_tab += n
            if a.apply:
                p.write_text(new)
        n_src += hit
    verb = 'removed' if a.apply else 'would remove'
    print(f'{verb} {n_tab} tables from {n_pages} pages across {n_src} OCR-read sources '
          f'({len(srcs)} such sources in the manifest)')
    if not a.apply:
        print('dry run; pass --apply to write')


if __name__ == '__main__':
    main()
