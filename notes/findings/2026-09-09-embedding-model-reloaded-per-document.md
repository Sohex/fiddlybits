# The index build loaded the embedding model once per document, and all but the first went to the CPU

Measured on 2026-09-09 during the first `ask.py --rebuild` after the OCR text was cleaned up.

The symptom was a card that looked busy and was not. `nvidia-smi` showed the build process holding
17,662 MiB of VRAM, while `nvidia-smi pmon` showed its SM column empty in every sample; the only
process doing GPU work was a video player. Meanwhile the process held 13 cores at 100 percent and
the index grew by 41 files in 13 minutes, against 736 to do.

## The cause

`Settings.get_embedding_model()` was overridden to return `InstructedSTEmbedding(...)`, a fresh
instance on every call. PaperQA calls it once per document, in `aadd_texts`, and the indexer adds
one document per file. So the build asked for 736 embedding models.

Each instance builds its `SentenceTransformer` lazily, and the device is chosen at that moment
from the free VRAM:

    free = torch.cuda.mem_get_info()[0] / 2**30
    dev = 'cuda' if free > 18 else 'cpu'

The first instance saw about 23 GiB free, loaded to the card, and took 17.6 GB of it. Every
instance after that saw about 6 GiB free, failed the test, and loaded on the CPU in bfloat16. The
first model stayed resident and unused; the work ran on the host at bfloat16 across every core.

Two ordinary decisions combined into this. Returning a new object from a getter is normal. Choosing
a device from free memory is normal. Together they make a loop whose first iteration guarantees the
rest take the slow path, and the slower it runs the more it looks like it is working.

## The fix

The embedding model is now a single instance for the life of the process, and the device choice is
printed once with the free VRAM that decided it and the setting that overrode it. `paperqa.toml`
gains `embedding_device`, which is `auto`, `cuda` or `cpu`.

An 8B embedder on the CPU is roughly fifty times slower than on this card. Nothing in the run said
so. That is the part worth keeping: a fallback that is never announced is indistinguishable from
the thing it falls back from, except in wall-clock, and wall-clock is exactly what nobody has a
baseline for on a first build.
