# Embedding model A/B/C for page-level retrieval over the held papers

Measured on 2026-09-08, on the RTX 4090 under one GPU share, with
`tools/references/embed_ab.py` (tracked). Corpus: every page of the 646 held PDFs
after OCR, one chunk per page capped at 1200 words, 24,602 non-empty pages, sequence
cap 2048 tokens for every model, fp16. Queries: 18 questions whose right answer is a
locator established by hand earlier the same day (document; page for one of them).
Scores at the document level, deduplicated by document; page hit at 10 on the one
query with a known page. Models loaded from `/home/cfutro/models`.

| model | dim | doc recall@5 | doc recall@10 | MRR | page hit@10 | pages/s | full index |
|---|---|---|---|---|---|---|---|
| bge-m3 (568M) | 1024 | 0.83 | 0.83 | 0.81 | 1.0 | 121 | 3 min |
| jina-embeddings-v5-text-small (677M) | 1024 | 0.94 | 1.00 | 0.89 | 1.0 | 21 | 20 min |
| Qwen3-Embedding-8B | 4096 | 1.00 | 1.00 | 0.97 | 1.0 | 7.4 | 56 min |

What decided it is which queries each model missed, not the means:

- bge-m3 ranked the primary source 36th for Stefan (1891, German), 30th for Courant
  et al. (1928, German) and 14th for Glen (1955, scanned), returning modern textbooks
  that restate each result. Those are exactly the cases this archive exists for: the
  Sourced disposition needs the original page, not a restatement.
- jina v5 small ranked Glen 1955 third behind Greve's lecture notes and Courant 1928
  sixth behind two textbooks; it found Stefan 1891 first.
- Qwen3-Embedding-8B ranked every primary source first except the Kok 2011
  fragmentation paper, which sat second behind Kok's own 2012 review of the same
  theory. Its instruction-prefixed queries and 4096-dimensional vectors are what the
  other two lack.

Decision: Qwen3-Embedding-8B is the embedding model behind `tools/references/ask.py`
(`tools/references/paperqa.toml`, `embedding_path`). Indexing time is accepted; the
user said so before the run. Query embedding runs on the CPU in bf16 when the GPU is
held by the chat model.

Not measured here: a reranking stage. `tools/references/rerank_ab.py` is written for
it and will be run against the same 18 queries once a cross-encoder is on disk, with
the precision gain and the latency per query reported side by side.

Raw results: `results.json` and the per-model page-embedding matrices are in the
session scratchpad and are not kept; the script regenerates them.
