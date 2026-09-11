#!/usr/bin/env python
"""Cross-encoder rerank stage for ask.py.

Bi-encoder retrieval scores a query against a page vector computed without seeing the
query. A cross-encoder reads both together, so it separates a page that states a result
from one that cites it, which is the distinction this archive turns on. It is too slow
to run over a corpus and fast enough to run over a shortlist, so the retrieval pulls a
broader set than it needs and this discards most of it.

Sized to stay resident beside the served chat model: Qwen3-Reranker-0.6B in fp16 is
about a gigabyte, against the roughly six the 4bpw 27B leaves free on the card. It
falls back to CPU when the card is busy, on the same rule as the embedding model, and
a shortlist is small enough that the fallback is slow rather than unusable.

Configured in paperqa.toml: rerank_path, rerank_kind, rerank_fetch_k,
rerank_instruction. Set rerank_path empty to turn the stage off.
"""
import pathlib, sys, tomllib

ROOT = pathlib.Path(__file__).resolve().parents[2]
CFG = tomllib.loads((ROOT / 'tools' / 'references' / 'paperqa.toml').read_text())

# Enough headroom for the reranker itself plus its activations, and no more: the point
# of a 0.6B model here is that it does not have to wait for the card to be empty.
VRAM_NEEDED_GIB = float(CFG.get('rerank_vram_gib', 3.0))


class Reranker:
    """Lazily loaded cross-encoder. Built on first use so --build and a bare query pay nothing."""

    def __init__(self, path, kind='qwen3', instruction='', max_seq=2048, batch_size=4,
                 quant='none'):
        self.path, self.kind, self.instruction, self.quant = path, kind, instruction, quant
        self.max_seq, self.batch_size, self._ce = max_seq, batch_size, None

    def _model(self):
        if self._ce is None:
            import torch
            from sentence_transformers import CrossEncoder
            free = torch.cuda.mem_get_info()[0] / 2**30 if torch.cuda.is_available() else 0
            self.device = 'cuda' if free > VRAM_NEEDED_GIB else 'cpu'
            # Announced, never silent, for the reason the embedder's line exists. This stage on the CPU cost 60
            # seconds of an 83 second query and said nothing about it, so the only symptom was a slow answer
            # (notes/findings/2026-09-10-rerank-stage-on-the-cpu.md). Same shape as ask.py's line, deliberately.
            print(f'rerank model on {self.device} ({free:.1f} GiB free on the card, '
                  f'threshold {VRAM_NEEDED_GIB}; rerank_vram_gib)', file=sys.stderr, flush=True)
            dt = torch.float16 if self.device == 'cuda' else torch.bfloat16
            mk = {'torch_dtype': dt}
            if self.quant != 'none' and self.device == 'cuda':
                from transformers import BitsAndBytesConfig
                mk['quantization_config'] = (
                    BitsAndBytesConfig(load_in_8bit=True) if self.quant == 'int8' else
                    BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type='nf4',
                                       bnb_4bit_compute_dtype=dt))
                mk['device_map'] = 'cuda'
            kw = dict(max_length=self.max_seq, device=self.device, model_kwargs=mk)
            # Qwen3-Reranker wants its instruction through the model's own chat template.
            # CrossEncoder truncates the document rather than the template; a hand-rolled
            # prompt gets that backwards on a long page (tools/references/rerank_ab.py).
            if self.kind == 'qwen3' and self.instruction:
                kw.update(prompts={'locate': self.instruction}, default_prompt_name='locate')
            self._ce = CrossEncoder(self.path, **kw)
        return self._ce

    def score(self, query, documents):
        ce = self._model()
        pairs = [(query, d) for d in documents]
        return [float(x) for x in ce.predict(pairs, batch_size=self.batch_size,
                                             show_progress_bar=False)]

    def top(self, query, items, k, text_of=lambda x: x):
        """The k best of items, best first. Fewer than k in, all of them back, reordered."""
        if not items:
            return []
        scores = self.score(query, [text_of(i) for i in items])
        ranked = sorted(zip(items, scores), key=lambda p: -p[1])
        return [i for i, _ in ranked[:k]]


def from_config():
    """The reranker paperqa.toml declares, or None when the stage is off."""
    path = CFG.get('rerank_path', '')
    if not path:
        return None
    if not pathlib.Path(path).exists():
        print(f' !! rerank_path does not exist, running without the rerank stage: {path}',
              file=sys.stderr)
        return None
    return Reranker(path, CFG.get('rerank_kind', 'qwen3'),
                    CFG.get('rerank_instruction', ''), CFG.get('max_seq', 2048),
                    CFG.get('rerank_batch_size', 4), CFG.get('rerank_quant', 'none'))


def reranked_docs_class(reranker, fetch_k):
    """Docs subclass whose retrieval pulls fetch_k and hands back the k the cross-encoder likes.

    PaperQA2 has no rerank hook, so this overrides the one method that chooses what the
    summary calls will see. Everything downstream is unchanged: it still receives
    evidence_k texts, just a better-chosen evidence_k.
    """
    from paperqa import Docs

    class RerankedDocs(Docs):
        async def retrieve_texts(self, query, k, settings=None, embedding_model=None,
                                 partitioning_fn=None, **kwargs):
            import asyncio
            broad = max(k, fetch_k)
            matches = await super().retrieve_texts(query, broad, settings, embedding_model,
                                                   partitioning_fn=partitioning_fn, **kwargs)
            if reranker is None or len(matches) <= k:
                return matches[:k]
            return await asyncio.to_thread(
                reranker.top, query, matches, k, lambda m: m.text)

    return RerankedDocs
