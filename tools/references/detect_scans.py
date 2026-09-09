#!/usr/bin/env python
"""Find scanned originals among PDFs that carry a text layer: a page that is one full-page raster is a scan whatever
its layer says, and a scan's layer is somebody's OCR. Prints file, pages, scan fraction (first 30 pages) and year.
    detect_scans.py [--min-frac 0.6] [--max-year 2004]
"""
import argparse, json, pathlib, re, subprocess
ROOT = pathlib.Path(__file__).resolve().parents[2]; PDF = ROOT / 'references' / 'pdf'
def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--min-frac', type=float, default=0.6); ap.add_argument('--max-year', type=int, default=2004); a = ap.parse_args()
    for pdf in sorted(PDF.glob('*.pdf')):
        info = subprocess.run(['pdfinfo', str(pdf)], capture_output=True, text=True).stdout
        pages = int(next((l.split()[1] for l in info.splitlines() if l.startswith('Pages:')), '0') or 0); lim = min(pages, 30)
        if not lim: continue
        big = set()
        for l in subprocess.run(['pdfimages', '-list', '-f', '1', '-l', str(lim), str(pdf)], capture_output=True, text=True).stdout.splitlines()[2:]:
            c = l.split()
            if len(c) > 5 and c[2] in ('image', 'stencil', 'smask'):
                try:
                    if int(c[3]) * int(c[4]) >= 1_500_000: big.add(int(c[0]))
                except ValueError: pass
        frac = len(big) / lim; m = re.search(r'(1[89]\d\d|20[0-2]\d)', pdf.stem); year = int(m.group(1)) if m else 0
        if frac >= a.min_frac and year <= a.max_year: print(f'{pdf.name}\t{pages}\t{frac:.2f}\t{year}')
if __name__ == '__main__': main()
