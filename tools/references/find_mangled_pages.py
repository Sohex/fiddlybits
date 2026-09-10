#!/usr/bin/env python
"""Find pages whose extracted text carries the broken-font-encoding signature, and write a repair list.

    tools/references/find_mangled_pages.py                 # report and write references/work/mangled_repair_list.txt
    tools/references/find_mangled_pages.py --list-only     # write the list and print nothing else

Some publishers ship subsetted Type1 fonts whose glyph mapping does not match the encoding they declare, with a
ToUnicode table that is absent or wrong. Every reader of the text layer then produces the same wrong characters:
pdftotext, pypdf and pdfium agree, and installing fontTools does not help (measured 2026-09-10,
notes/findings/2026-09-10-retrieval-without-naming-the-source.md). Body prose survives, because the text fonts
happen to be encoded correctly; what breaks is the display-math font, so the damage falls on equations,
coefficients, exponents and units. That is the content a Sourced constant is transcribed from.

This is worth catching per page rather than per paper: on the papers affected, fewer than half the pages carry any
math, and re-reading a whole book to fix two equations is waste. The output is in the format
chandra_pages.py --repair takes, so the fix runs through the machinery that already exists for the pages an
earlier pass read sideways.

It detects damage, not mathematics. A page whose equations came through clean has nothing to repair and is not
listed, and a page with no math at all can still be listed if its degree signs are wrong.
"""
import argparse, pathlib, re, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]
TXT = ROOT / 'references' / 'text'; PDF = ROOT / 'references' / 'pdf'
OUT = ROOT / 'references' / 'work' / 'mangled_repair_list.txt'

# The gate is the vulgar fraction standing in for an operator. How it is used, not how often: a paper that
# genuinely prints one quarter writes it against a sign or a digit, as the IEEE floating-point standard does with
# plus-or-minus one quarter, while the substitution appears where an equals sign belongs, after a letter or a
# space. The digit six before it is the other half of the same damage, stranded from a not-equal sign.
#
# Counting occurrences instead was tried and is wrong: at three or more it dropped twelve papers whose equations
# are plainly broken, to exclude one that is not. Eth and thorn cannot gate at all, because this archive holds
# glaciology and Icelandic place names are spelled with them.
GATE = re.compile('(?<=[A-Za-z\\s])\u00bc|6\u00bc')
# Inside a document the gate has condemned, these are damage too. On their own they are not: a colon between
# digits is a time of day, a map scale of 1:250,000 or a 1:1 line, and reading the archive that way flagged 238
# further papers with nothing wrong with them. They count only where the encoding is known to be broken.
SIGNATURE = re.compile('[\u00bc\u00f0\u00de]|(?<=[0-9]):(?=[0-9])|(?<=[0-9]) ?jC\\b')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--list-only', action='store_true', help='write the list and print nothing else')
    a = ap.parse_args()
    rows, n_pages, n_hit, n_papers = [], 0, 0, 0
    for d in sorted(TXT.iterdir()):
        if not d.is_dir(): continue
        pdf = PDF / (d.name + '.pdf')
        if not pdf.is_file(): continue
        pages = {f: f.read_text(errors='ignore') for f in sorted(d.glob('*.txt'))}
        n_pages += len(pages)
        if not any(GATE.search(t) for t in pages.values()): continue
        hits = sorted(int(f.stem) for f, t in pages.items() if SIGNATURE.search(t))
        if not hits: continue
        n_papers += 1; n_hit += len(hits)
        rows.append(pdf.name + '\t' + ','.join(str(p) for p in hits))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text('\n'.join(rows) + ('\n' if rows else ''))
    if not a.list_only:
        print(f'{n_hit} pages in {n_papers} papers carry the signature, of {n_pages} pages read')
        print(f'repair list written to {OUT.relative_to(ROOT)}')
        print('read them again with:')
        print('  $HOME/.venvs/chandra-vllm/bin/python tools/references/chandra_pages.py \\')
        print(f'      {OUT.relative_to(ROOT)} --repair --method vllm --batch 16')
    return 0

if __name__ == '__main__': sys.exit(main())
