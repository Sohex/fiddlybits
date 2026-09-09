import sys, glob, time, pathlib
from chandra.model import InferenceManager
from chandra.model.schema import BatchInputItem
from chandra.output import parse_markdown
from PIL import Image
imgs = sorted(glob.glob(sys.argv[1] + '/*.png'))[:8]
m = InferenceManager(method='vllm')
for bs in (1, 8):
    batch = [BatchInputItem(image=Image.open(p), prompt_type='ocr_layout') for p in imgs[:bs]]
    t0 = time.time(); res = m.generate(batch); dt = time.time() - t0
    print(f'vllm batch {bs}: {dt:.1f}s total, {dt/bs:.1f}s/page, {sum(len(r.markdown or "") for r in res)} chars', flush=True)
out = pathlib.Path(sys.argv[1]) / 'vllm-check.md'; out.write_text(res[0].markdown or ''); print('sample written', out)
