#!/usr/bin/env python
"""Remove the tables the reader invented by reading values off a figure. There was no table on those pages, so
retrieval must not be able to quote one with a page citation (notes/findings/2026-09-09-tables-invented-from-figures.md).

    strip_invented_tables.py references/text            # dry run: what would go
    strip_invented_tables.py references/text --apply

Each removed table leaves a marker naming the figure, so a page still reads as prose and the removal is visible
rather than silent. The reader's own caption is the handle: it says the numbers were estimated from a figure.
"""
import argparse, pathlib, re, sys

TABLE = re.compile(r'<table\b.*?</table>', re.S)
CAPTION = re.compile(r'<caption>(.*?)</caption>', re.S | re.I)
INVENTED = re.compile(r'estimat|approximat|data\s+points|read\s+from|digitiz|extracted\s+from', re.I)
FROM_FIGURE = re.compile(r'\bfig(ure)?\b|\bgraph\b|\bplot\b|\bchart\b', re.I)
MARKER = '[a table of values read off a figure by the reader was removed here: {}]'


def caption_of(tb):
    m = CAPTION.search(tb)
    return re.sub(r'<[^>]+>', '', m.group(1)).strip() if m else ''


def invented(tb):
    c = caption_of(tb)
    return bool(c) and bool(INVENTED.search(c)) and bool(FROM_FIGURE.search(c))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('root'); ap.add_argument('--apply', action='store_true')
    a = ap.parse_args()
    files = sorted(pathlib.Path(a.root).glob('*/*.txt'))
    n_tab = n_row = 0
    touched = []
    for f in files:
        text = f.read_text(errors='replace')
        hits = [tb for tb in TABLE.findall(text) if invented(tb)]
        if not hits:
            continue
        new = text
        for tb in hits:
            n_tab += 1
            n_row += len(re.findall(r'<tr>', tb))
            new = new.replace(tb, MARKER.format(caption_of(tb)), 1)
        # a removed table can leave three blank lines where it stood
        new = re.sub(r'\n{4,}', '\n\n\n', new)
        touched.append((f, len(hits)))
        if a.apply:
            f.write_text(new)
    for f, n in touched[:12]:
        print(f'  {n} from {f.parent.name}/{f.name}')
    if len(touched) > 12:
        print(f'  ... and {len(touched)-12} more pages')
    verb = 'removed' if a.apply else 'would remove'
    print(f'{verb} {n_tab} tables, {n_row} rows, from {len(touched)} pages of {len(files)}')
    if not a.apply:
        print('dry run; pass --apply to write')


if __name__ == '__main__':
    main()
