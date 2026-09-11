#!/usr/bin/env python
"""Check the decision records' front matter and regenerate docs/decisions/INDEX.md from it.

    decisions.py                 check, then write the index; what the pre-commit hook runs
    decisions.py --check         check only; exit 1 and print each problem
    decisions.py --index         write the index only
    decisions.py --self-test     run each check against a fixture that must fail it

Reads the TOML header of every docs/decisions/NNNN-*.md. Schema and the meaning of the
edges: docs/decisions/README.md and decision 0040.
"""
import argparse, datetime, pathlib, re, sys, tempfile, tomllib

ROOT = pathlib.Path(__file__).resolve().parents[2]
DECISIONS = ROOT / 'docs' / 'decisions'
INDEX = DECISIONS / 'INDEX.md'
STATUSES = ('accepted', 'proposed', 'superseded')
EDGES = ('amends', 'supersedes')
NAME = re.compile(r'^(\d{4})-.*\.md$')


def read(d):
    """Return (records, problems). records maps id -> dict with the header's fields plus 'file'."""
    records, problems = {}, []
    for f in sorted(d.iterdir()):
        m = NAME.match(f.name)
        if not m:
            continue
        text = f.read_text()
        if not text.startswith('+++'):
            problems.append(f'{f.name}: no +++ front matter'); continue
        parts = text.split('+++', 2)
        if len(parts) < 3:
            problems.append(f'{f.name}: front matter is not closed by +++'); continue
        try:
            h = tomllib.loads(parts[1])
        except tomllib.TOMLDecodeError as e:
            problems.append(f'{f.name}: front matter does not parse: {e}'); continue

        for k in ('id', 'title', 'status', 'date'):
            if k not in h:
                problems.append(f'{f.name}: front matter has no {k}')
        if 'id' not in h:
            continue
        rid = h['id']
        if not isinstance(rid, str) or not re.fullmatch(r'\d{4}', rid):
            problems.append(f'{f.name}: id {rid!r} is not a four-digit string'); continue
        if rid != m.group(1):
            problems.append(f'{f.name}: id {rid} does not match the filename')
        if rid in records:
            problems.append(f'{f.name}: id {rid} is also used by {records[rid]["file"]}'); continue
        if h.get('status') not in STATUSES:
            problems.append(f'{f.name}: status {h.get("status")!r} is not one of {", ".join(STATUSES)}')
        if not isinstance(h.get('date'), datetime.date):
            problems.append(f'{f.name}: date is not a bare TOML date')

        for key in EDGES:
            if key not in h:
                continue
            if not isinstance(h[key], list):
                problems.append(f'{f.name}: {key} is not an array'); h[key] = []; continue
            for e in h[key]:
                if not isinstance(e, dict):
                    problems.append(f'{f.name}: {key} entry {e!r} is not a table'); continue
                for k in ('record', 'what'):
                    if not e.get(k):
                        problems.append(f'{f.name}: {key} entry {e!r} has no {k}')
        h['file'] = f.name
        records[rid] = h
    return records, problems


def check(records):
    problems = []
    superseded_by = {}
    for rid, h in sorted(records.items()):
        for key in EDGES:
            for e in h.get(key, []):
                if not isinstance(e, dict) or not e.get('record'):
                    continue
                target = e['record']
                if target == rid:
                    problems.append(f'{h["file"]}: {key} itself'); continue
                if target not in records:
                    problems.append(f'{h["file"]}: {key} record {target}, which does not exist'); continue
                if target > rid:
                    problems.append(f'{h["file"]}: {key} record {target}, which is later than it')
                if key == 'supersedes':
                    superseded_by.setdefault(target, []).append(rid)

    for target, actors in sorted(superseded_by.items()):
        if len(actors) > 1:
            problems.append(f'{records[target]["file"]}: superseded by more than one record: {", ".join(actors)}')
        if records[target].get('status') != 'superseded':
            problems.append(f'{records[target]["file"]}: superseded by {actors[0]} but its status is '
                            f'{records[target].get("status")!r}')
    for rid, h in sorted(records.items()):
        if h.get('status') == 'superseded' and rid not in superseded_by:
            problems.append(f'{h["file"]}: status is superseded but no record supersedes it')
    return problems, superseded_by


def write_index(records, superseded_by):
    def cell(s):
        return str(s).replace('|', '\\|')

    lines = [
        '# Decision index',
        '',
        'Generated from the front matter of every record in this directory by',
        '`tools/records/decisions.py`, and rewritten by the pre-commit hook whenever a record',
        'changes. Do not edit: an edit here is lost on the next commit, and the record itself is',
        'the primitive. The schema is in `README.md`.',
        '',
        '`amends` and `supersedes` are read from the acting record. `superseded by` is derived',
        'from those, and is the only place that back-edge is written down.',
        '',
        '| id | title | status | date | amends | supersedes | superseded by |',
        '| --- | --- | --- | --- | --- | --- | --- |',
    ]
    for rid, h in sorted(records.items()):
        edge = {k: ', '.join(f'{e["record"]} ({e["what"]})' for e in h.get(k, [])
                             if isinstance(e, dict) and e.get('record')) for k in EDGES}
        lines.append('| [{id}]({file}) | {title} | {status} | {date} | {amends} | {supersedes} | {by} |'.format(
            id=rid, file=h['file'], title=cell(h.get('title', '')), status=h.get('status', ''),
            date=h.get('date', ''), amends=cell(edge['amends']) or '-',
            supersedes=cell(edge['supersedes']) or '-',
            by=', '.join(superseded_by.get(rid, [])) or '-'))
    lines += ['', f'{len(records)} records; '
                  f'{sum(1 for h in records.values() if h.get("status") == "accepted")} accepted, '
                  f'{sum(1 for h in records.values() if h.get("status") == "proposed")} proposed, '
                  f'{sum(1 for h in records.values() if h.get("status") == "superseded")} superseded.', '']
    INDEX.write_text('\n'.join(lines))
    return INDEX


FIXTURES = {
    'edge to a record that does not exist': {
        '0001-a.md': 'id = "0001"\ntitle = "A"\nstatus = "accepted"\ndate = 2026-01-01\n'
                     'amends = [{ record = "0009", what = "x" }]\n'},
    'supersedes a record still marked accepted': {
        '0001-a.md': 'id = "0001"\ntitle = "A"\nstatus = "accepted"\ndate = 2026-01-01\n',
        '0002-b.md': 'id = "0002"\ntitle = "B"\nstatus = "accepted"\ndate = 2026-01-02\n'
                     'supersedes = [{ record = "0001", what = "all of it" }]\n'},
    'status superseded with nothing superseding it': {
        '0001-a.md': 'id = "0001"\ntitle = "A"\nstatus = "superseded"\ndate = 2026-01-01\n'},
    'edge pointing at a later record': {
        '0001-a.md': 'id = "0001"\ntitle = "A"\nstatus = "accepted"\ndate = 2026-01-01\n'
                     'amends = [{ record = "0002", what = "x" }]\n',
        '0002-b.md': 'id = "0002"\ntitle = "B"\nstatus = "accepted"\ndate = 2026-01-02\n'},
    'a record amending itself': {
        '0001-a.md': 'id = "0001"\ntitle = "A"\nstatus = "accepted"\ndate = 2026-01-01\n'
                     'amends = [{ record = "0001", what = "x" }]\n'},
    'an edge with no what': {
        '0001-a.md': 'id = "0001"\ntitle = "A"\nstatus = "accepted"\ndate = 2026-01-01\n',
        '0002-b.md': 'id = "0002"\ntitle = "B"\nstatus = "accepted"\ndate = 2026-01-02\n'
                     'amends = [{ record = "0001" }]\n'},
    'id not matching the filename': {
        '0003-a.md': 'id = "0001"\ntitle = "A"\nstatus = "accepted"\ndate = 2026-01-01\n'},
    'a status outside the vocabulary': {
        '0001-a.md': 'id = "0001"\ntitle = "A"\nstatus = "draft"\ndate = 2026-01-01\n'},
    'a date that is a string': {
        '0001-a.md': 'id = "0001"\ntitle = "A"\nstatus = "accepted"\ndate = "2026-01-01"\n'},
    'two records sharing an id': {
        '0001-a.md': 'id = "0001"\ntitle = "A"\nstatus = "accepted"\ndate = 2026-01-01\n',
        '0001-b.md': 'id = "0001"\ntitle = "B"\nstatus = "accepted"\ndate = 2026-01-02\n'},
    'front matter that does not parse': {
        '0001-a.md': 'id = "0001"\ntitle = A\n'},
}
CLEAN = {
    '0001-a.md': 'id = "0001"\ntitle = "A"\nstatus = "superseded"\ndate = 2026-01-01\n',
    '0002-b.md': 'id = "0002"\ntitle = "B"\nstatus = "accepted"\ndate = 2026-01-02\n'
                 'supersedes = [{ record = "0001", what = "all of it" }]\n'
                 'amends = [{ record = "0001", what = "not reachable, but well formed" }]\n',
}


def self_test():
    def run(files):
        with tempfile.TemporaryDirectory() as d:
            p = pathlib.Path(d)
            for name, fm in files.items():
                (p / name).write_text(f'+++\n{fm}+++\n\n## Decision\n')
            recs, probs = read(p)
            more, _ = check(recs)
            return probs + more

    bad = []
    for label, files in FIXTURES.items():
        if not run(files):
            bad.append(f'NOT CAUGHT: {label}')
        else:
            print(f'  caught: {label}')
    leftover = run(CLEAN)
    if leftover:
        bad.append(f'clean fixture flagged: {leftover}')
    else:
        print('  clean fixture passes')
    if bad:
        print('\n'.join(bad), file=sys.stderr); return 1
    print(f'self-test: {len(FIXTURES)} checks each fired on their fixture, clean fixture passed')
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--check', action='store_true', help='check only')
    ap.add_argument('--index', action='store_true', help='write the index only')
    ap.add_argument('--self-test', action='store_true', help='run each check against a fixture that must fail it')
    a = ap.parse_args()
    if a.self_test:
        return self_test()

    records, problems = read(DECISIONS)
    more, superseded_by = check(records)
    problems += more
    if problems and not a.index:
        for p in problems:
            print(f'docs/decisions/{p}', file=sys.stderr)
        print(f'{len(problems)} problem(s); see docs/decisions/README.md', file=sys.stderr)
        return 1
    if not a.check:
        out = write_index(records, superseded_by)
        print(f'{out.relative_to(ROOT)}: {len(records)} records')
    elif not problems:
        print(f'{len(records)} records, no problems')
    return 0


if __name__ == '__main__':
    sys.exit(main())
