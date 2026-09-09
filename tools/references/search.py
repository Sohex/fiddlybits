#!/usr/bin/env python
"""Page-cited full-text search over the held papers.

    tools/references/search.py "carbonate equilibrium constant pressure"      # all words, any order, per page
    tools/references/search.py -e "K_1.*pressure"                              # regex
    tools/references/search.py -f millero1995 "pressure"                       # restrict to a file stem prefix

Searches references/text/<stem>/<page>.txt (built by extract_text.py) and prints locators in citation form:
    <filename> | p.<page> | <matching line>
It returns WHERE to look. A value or a scheme enters a record only after the page is opened and the table or
equation is named in the Sourced disposition (docs/references/README.md).
"""
import argparse, pathlib, re, subprocess, sys, json
ROOT = pathlib.Path(__file__).resolve().parents[2]; TXT = ROOT / 'references' / 'text'; IDX = ROOT / 'docs' / 'references' / 'INDEX.md'
def titles():
    t = {}
    if IDX.exists():
        for l in IDX.read_text().splitlines():
            m = re.match(r'\| `([^`]+)` \| (.+?) \|', l)
            if m: t[m.group(1)] = m.group(2)
    return t
def main():
    ap = argparse.ArgumentParser(); ap.add_argument('query'); ap.add_argument('-e', '--regex', action='store_true'); ap.add_argument('-f', '--file', default='')
    ap.add_argument('-n', '--max', type=int, default=60); ap.add_argument('--json', action='store_true'); a = ap.parse_args()
    if not TXT.exists(): sys.exit('no text index; run tools/references/extract_text.py')
    words = [a.query] if a.regex else [re.escape(w) for w in a.query.split()]
    paths = sorted(d for d in TXT.iterdir() if d.is_dir() and d.name.startswith(a.file))
    hits = []
    for d in paths:
        for pg in sorted(d.glob('*.txt')):
            txt = pg.read_text(errors='ignore'); low = txt.lower()
            if all(re.search(w, low, re.I) for w in words):
                line = next((ln.strip() for ln in txt.splitlines() if re.search(words[0], ln, re.I)), '')
                hits.append({'file': d.name + '.pdf', 'page': int(pg.stem), 'line': line[:160]})
                if len(hits) >= a.max: break
        if len(hits) >= a.max: break
    tt = titles()
    if a.json: print(json.dumps(hits, indent=1)); return
    for h in hits: print(f"{h['file']} | p.{h['page']} | {h['line']}")
    print(f"-- {len(hits)} page hits{' (capped)' if len(hits) >= a.max else ''}; open the page before citing")
if __name__ == '__main__': main()
