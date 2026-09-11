#!/usr/bin/env python
"""Screen the tables of an OCR-read source on shape alone, for pages worth opening by eye.

    audit_tables_by_shape.py references/text/<source> [<source> ...]

Reports four conditions per table: a row narrower than its neighbours, two adjacent columns that agree
everywhere, a value breaking the smoothness of an otherwise smooth column, and a caption stating the numbers
were estimated from a figure. Only the last is conclusive; the first three are noisy and say which pages to
render and look at, not which are damaged.

See notes/findings/2026-09-09-tables-invented-from-figures.md.
"""
import collections, glob, os, re, sys
TABLE = re.compile(r'<table.*?</table>', re.S)
ROW = re.compile(r'<tr>(.*?)</tr>', re.S)
CELL = re.compile(r'<t[dh][^>]*>(.*?)</t[dh]>', re.S)
NUM = re.compile(r'^[-+−]?[\d.,]+(?:[eE][-+]?\d+)?$')
CAPTION = re.compile(r'<caption>(.*?)</caption>', re.S | re.I)
INVENTED = re.compile(r'estimat|approximat|data\s+points|read\s+from|digitiz|extracted\s+from', re.I)
FROM_FIGURE = re.compile(r'\bfig(ure)?\b|\bgraph\b|\bplot\b|\bchart\b', re.I)


def cells(rowmarkup):
    cs = [re.sub(r'<[^>]+>', '', c).replace('&nbsp;', ' ').strip() for c in CELL.findall(rowmarkup)]
    while cs and cs[-1] == '':
        cs.pop()
    return cs


def num(s):
    s = s.replace('−', '-').replace(',', '')
    if not NUM.match(s):
        return None
    try:
        return float(s)
    except ValueError:
        return None


def screen(tb):
    rows = [c for c in (cells(m.group(1)) for m in ROW.finditer(tb)) if c]
    out = []
    cap = CAPTION.search(tb)
    if cap:
        text = re.sub(r'<[^>]+>', '', cap.group(1)).strip()
        if INVENTED.search(text) and FROM_FIGURE.search(text):
            out.append(('invented', f'no table on the page; {len(rows)} rows read off a figure: "{text}"'))
    if len(rows) < 4:
        return out
    w = collections.Counter(len(r) for r in rows)
    dom, n_dom = w.most_common(1)[0]
    if n_dom / len(rows) >= 0.6:
        odd = [i for i, r in enumerate(rows) if len(r) != dom]
        if 0 < len(odd) <= max(3, len(rows) // 4):
            out.append(('ragged', f'{len(odd)} of {len(rows)} rows are not {dom} cells wide: '
                                  + ', '.join(f'row {i+1} has {len(rows[i])}' for i in odd[:4])))
    body = [r for r in rows if len(r) == dom]
    cols = [[num(r[j]) for r in body] for j in range(dom)]
    for j in range(dom - 1):
        a, b = cols[j], cols[j + 1]
        both = [(x, y) for x, y in zip(a, b) if x is not None and y is not None]
        if len(both) >= 4 and all(x == y for x, y in both) and len({x for x, _ in both}) > 1:
            out.append(('twinned', f'columns {j+1} and {j+2} are identical on all {len(both)} numeric rows'))
    for j, col in enumerate(cols):
        v = [x for x in col if x is not None]
        if len(v) < 6 or len(v) / max(1, len(col)) < 0.9:
            continue
        d = [v[i+1] - v[i] for i in range(len(v) - 1)]
        if sum(1 for x in d if x > 0) < 0.8 * len(d) and sum(1 for x in d if x < 0) < 0.8 * len(d):
            continue                                    # not a monotone column; smoothness says nothing
        mag = sorted(abs(x) for x in d)[len(d) // 2]
        if mag == 0:
            continue
        for i, x in enumerate(d):
            if abs(x) > 12 * mag:
                out.append(('jump', f'column {j+1} steps by {x:g} between rows {i+1} and {i+2}, '
                                    f'against a typical step of {mag:g}'))
                break
    return out


for book in sys.argv[1:]:
    hits = 0
    print(f'=== {os.path.basename(book)}')
    for f in sorted(glob.glob(book + '/*.txt')):
        text = open(f, errors='replace').read()
        for k, tb in enumerate(TABLE.findall(text), 1):
            for kind, msg in screen(tb):
                hits += 1
                print(f'  page {os.path.basename(f)[:-4]} table {k}: [{kind}] {msg}')
    print(f'  {hits} things to look at\n')
