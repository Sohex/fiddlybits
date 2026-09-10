#!/usr/bin/env python
"""Which pages of the NIST-JANAF read carry a table that no longer adds up? Every data page of that source prints
eight columns bound by two exact relations, so the page is its own oracle: no external table is consulted and no
sampling is involved.

    -[G(T) - H(Tr)]/T  =  S(T) - [H(T) - H(Tr)]/T      column 4 from columns 3 and 5
    log Kf(T)          =  -dfG(T) / (R T ln 10)        column 8 from column 7

A page whose columns were dropped, duplicated or slid by a row still reads as a well-formed table
(notes/findings/2026-09-09-chandra-page-orientation.md); these relations are what makes that visible. A row of the
data table that is not eight cells wide is counted too, since a dropped cell moves every value to its left.
Writes a repair list of `filename<TAB>page,page,...` for chandra_pages.py --repair.

    audit_janaf_tables.py <text dir> <out list> [--pdf <name>] [--tol-gef 0.06] [--tol-log 0.03]
    audit_janaf_tables.py --self-test [<text dir>]   positive control: break a clean page four ways, catch each
"""
import argparse, math, pathlib, re, sys

R = 8.31451                      # J K-1 mol-1, the gas constant of the fourth edition's own tables
LN10 = math.log(10)
CELL = re.compile(r'<td[^>]*>(.*?)</td>')
ROW = re.compile(r'<tr>(<td.*?)</tr>', re.S)
TABLE = re.compile(r'<table.*?</table>', re.S)
DATA_ROWS = 20                   # a table with this many temperature-led rows is the page's thermochemical table
MIN_CELLS = 5                    # a data row narrower than this is a caption or a stray, not a mangled table row


def data_row(markup):
    """One table row as its cell texts with trailing blanks dropped, or None if it does not begin with a
    tabulated temperature. The rows below 100 K carry INFINITE in the Gibbs energy function and constrain
    neither relation. Width is not part of the test: a page whose every row lost a cell is the case this audit
    exists for, and gating the table on eight-wide rows let exactly that page through as clean."""
    cs = [re.sub(r'<[^>]+>', '', c).strip().replace(',', '') for c in CELL.findall(markup)]
    while cs and cs[-1] == '':
        cs.pop()
    if not cs:
        return None
    try:
        T = float(cs[0])
    except ValueError:
        return None
    return cs if 100 <= T <= 6000 else None


def num(s):
    try:
        return float(s)
    except ValueError:
        return None


def failures(text, tol_gef=0.06, tol_log=0.03):
    """The rows of one page that break a relation or lost a cell, as (temperature, which, printed, implied)."""
    bad = []
    for table in TABLE.findall(text):
        rows = [r for r in (data_row(m.group(1)) for m in ROW.finditer(table)) if r and len(r) >= MIN_CELLS]
        if len(rows) < DATA_ROWS:
            continue                                    # not the thermochemical table
        for cs in rows:
            T = float(cs[0])
            if len(cs) != 8:
                bad.append((T, 'width', len(cs), 8))
                continue
            _, cp, S, gef, dH, fH, fG, logK = (num(c) for c in cs)
            if None not in (S, gef, dH):
                implied = S - dH * 1000.0 / T
                if abs(implied - gef) > tol_gef:
                    bad.append((T, 'gef', gef, implied))
            if None not in (fG, logK):
                implied = -fG * 1000.0 / (R * T * LN10)
                if abs(implied - logK) > tol_log:
                    bad.append((T, 'logKf', logK, implied))
    return bad


def self_test(text):
    """A check that cannot fail is not a check. Take a page the audit passes, break it the four ways this OCR
    actually breaks a table, and require every one to be caught."""
    if failures(text):
        sys.exit('the self-test needs a page that passes; this one does not')
    rows = [m.group(0) for m in ROW.finditer(text) if data_row(m.group(1))]
    victim, before = rows[len(rows) // 2], rows[len(rows) // 2 - 1]
    cs, prev = CELL.findall(victim), CELL.findall(before)
    def rebuilt(cells):
        return '<tr>' + ''.join(f'<td>{c}</td>' for c in cells) + '</tr>'
    probes = {
        'a dropped column': rebuilt(cs[:3] + cs[4:]),
        'a column slid by one row': rebuilt([cs[0], cs[1], cs[2], prev[3]] + cs[4:]),
        'a duplicated column': rebuilt(cs[:6] + [cs[5]] + cs[7:]),
        'a lost decimal point': rebuilt(cs[:3] + [cs[3].replace('.', '', 1)] + cs[4:]),
    }
    ok = True
    for name, broken in probes.items():
        n = len(failures(text.replace(victim, broken, 1)))
        print(f'  {"caught" if n else "MISSED":>6}: {name}')
        ok &= bool(n)
    if not ok:
        sys.exit('positive control failed')
    print('  self-test passed: every probe was caught')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('textdir', nargs='?',
                    default='references/text/chase1998-nist-janaf-thermochemical-tables-fourth-edition')
    ap.add_argument('out', nargs='?')
    ap.add_argument('--pdf', default='')
    ap.add_argument('--tol-gef', type=float, default=0.06)
    ap.add_argument('--tol-log', type=float, default=0.03)
    ap.add_argument('--self-test', action='store_true')
    a = ap.parse_args()
    d = pathlib.Path(a.textdir)
    if a.self_test:
        for p in sorted(d.glob('*.txt')):
            t = p.read_text(errors='replace')
            if len([r for tb in TABLE.findall(t) for r in (data_row(m.group(1)) for m in ROW.finditer(tb)) if r]) > 50 \
                    and not failures(t):
                print(f'positive control on {p.stem}, a page the audit passes:')
                return self_test(t)
        sys.exit('no clean page to use as the control')
    if not a.out:
        ap.error('give an output list, or --self-test')
    pdf = a.pdf or d.name + '.pdf'
    pages, tabled, n_rows, n_bad = [], 0, 0, 0
    for p in sorted(d.glob('*.txt')):
        text = p.read_text(errors='replace')
        rows = [r for tb in TABLE.findall(text)
                for r in (data_row(m.group(1)) for m in ROW.finditer(tb)) if r and len(r) >= MIN_CELLS]
        if len(rows) < DATA_ROWS:
            continue
        tabled += 1
        n_rows += len(rows)
        bad = failures(text, a.tol_gef, a.tol_log)
        if bad:
            n_bad += len(bad)
            pages.append(int(p.stem))
            share = len({b[0] for b in bad}) / len(rows)
            print(f'{p.stem}: {len(bad):3d} broken relations over {len(rows)} rows ({share:4.0%} of rows), '
                  f'first at {bad[0][0]:g} K: {bad[0][1]} printed {bad[0][2]}, implied {bad[0][3]:.3f}', flush=True)
    pathlib.Path(a.out).write_text(f'{pdf}\t{",".join(str(x) for x in pages)}\n' if pages else '')
    print(f'done: {n_bad} broken relations over {n_rows} rows; {len(pages)} of {tabled} table pages need '
          f're-reading; repair list at {a.out}')


if __name__ == '__main__':
    main()
