#!/usr/bin/env python
"""OCR page images with Chandra OCR 2 (Datalab) via transformers, writing one Markdown file per image.
    chandra_ocr.py <out dir> <image.png> [image.png ...]
Used by the OCR A/B against the tesseract text layer (notes/findings). Runs on the GPU under qrun.
"""
import sys, pathlib, time, torch
from transformers import AutoModelForImageTextToText, AutoProcessor
from chandra.model.hf import generate_hf
from chandra.model.schema import BatchInputItem
from chandra.output import parse_markdown
from PIL import Image
MODEL = '/home/cfutro/models/chandra-ocr-2'
def main():
    out = pathlib.Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True); imgs = sys.argv[2:]
    t0 = time.time(); model = AutoModelForImageTextToText.from_pretrained(MODEL, dtype=torch.bfloat16, device_map='cuda'); model.eval()
    model.processor = AutoProcessor.from_pretrained(MODEL); model.processor.tokenizer.padding_side = 'left'
    print(f'loaded in {time.time()-t0:.0f}s', flush=True)
    for p in imgs:
        t1 = time.time(); r = generate_hf([BatchInputItem(image=Image.open(p), prompt_type='ocr_layout')], model)[0]
        md = parse_markdown(r.raw); (out / (pathlib.Path(p).stem + '.chandra.md')).write_text(md)
        print(f'{pathlib.Path(p).name}: {len(md)} chars in {time.time()-t1:.1f}s', flush=True)
if __name__ == '__main__': main()
