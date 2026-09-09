import sys, pathlib, time, torch, glob
from transformers import AutoModelForImageTextToText, AutoProcessor
from chandra.model.hf import generate_hf
from chandra.model.schema import BatchInputItem
from PIL import Image
M = '/home/cfutro/models/chandra-ocr-2'
imgs = sorted(glob.glob(sys.argv[1] + '/*.png'))[:8]
model = AutoModelForImageTextToText.from_pretrained(M, dtype=torch.bfloat16, device_map='cuda'); model.eval()
model.processor = AutoProcessor.from_pretrained(M); model.processor.tokenizer.padding_side = 'left'
for bs in (1, 4, 8):
    batch = [BatchInputItem(image=Image.open(p), prompt_type='ocr_layout') for p in imgs[:bs]]
    torch.cuda.synchronize(); t0 = time.time(); res = generate_hf(batch, model); torch.cuda.synchronize(); dt = time.time() - t0
    print(f'batch {bs}: {dt:.1f}s total, {dt/bs:.1f}s/page, {sum(len(r.raw) for r in res)} chars, peak {torch.cuda.max_memory_allocated()/2**30:.1f} GB', flush=True)
