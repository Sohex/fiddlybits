# The rerank stage, not the embedder, is what a query waits on

Measured on 2026-09-10 on the RTX 4090 with TabbyAPI serving the generator and holding
18.3 GiB of the card, leaving about 2.3 GiB free. One query, "How does Millero 1995 give
the pressure dependence of K1?", through `tools/references/ask.py` against the 737-source
index. Phases timed by wrapping PaperQA's three tools and `rerank.Reranker.score`.

## Where the time goes

| phase | `rerank_vram_gib = 3.0` (CPU) | `= 1.5`, batch 1 (GPU) |
|---|---|---|
| startup and index open | 2.7 s | 2.7 s |
| paper_search, 3 calls | 0.3 s | 0.3 s |
| gather_evidence | 75.3 s | 17.6 s |
| of which rerank score, 50 chunks | 60.6 s | 2.3 s |
| gen_answer | 4.5 s | 4.5 s |
| **total wall** | **83 s** | **24 s** |

The embedder was never the cost. Measured on its own it is 3.7 s to load and 0.36 s to
encode one query, about 4 s of the 83. A query embeds one short string; the reranker reads
50 chunks of 4000 characters, and that asymmetry is the whole story.

## Why both were on the CPU

`embedding_device = auto` puts the 8B embedder on the card only above 18 GiB free, and
`rerank_vram_gib` did the same for the cross-encoder above 3.0 GiB. Both thresholds were
chosen for an idle card. Once the generator is up the card is not idle, so both fall back,
and the fallback for the reranker costs a minute per query.

## The threshold alone is not enough

Dropping `rerank_vram_gib` to 1.5 puts the reranker on the card and then it runs out of
memory mid-pass at the default batch size of 4. PaperQA catches the OutOfMemoryError inside
both `gather_evidence` and `gen_answer`, so the query returns an empty answer with no
evidence in 9 s. A fast query that answers nothing looks like a speedup in a wall-clock
number, which is how it was first misread here.

Peak PyTorch allocation for Qwen3-Reranker-0.6B at bf16, 50 chunks, sequence cap 2048,
against 2.30 GiB free:

| batch size | peak allocated | free after | 50 chunks |
|---|---|---|---|
| 1 | 1.24 GiB | 0.96 GiB | 1.06 s |
| 2 | 1.35 GiB | 0.83 GiB | 1.13 s |
| 4 | 1.59 GiB | 0.54 GiB | 1.15 s |

Those are synthetic chunks, which tokenize shorter than real pages; on real pages batch 4
exceeded the free memory while batch 1 did not. Larger batches buy nothing here anyway,
0.09 s across the whole shortlist, because 50 sequences of about 2000 tokens already
saturate the card.

Settings: `rerank_vram_gib = 1.5`, `rerank_batch_size = 1`. Three confirmation runs at
24.7 s, 23.8 s and 24.7 s, no OutOfMemoryError, the same two sources cited at the same
pages as the CPU run: millero1995 pages 15-16 and sarmiento2006 pages 388-390.

## What is left

The embedder still runs on the CPU, since 2.3 GiB free is nowhere near its 18 GiB
threshold, and still costs about 4 s per query in load and encode.

It is going to stay there. The card is 24 GiB, the generator holds 18.3, and this
embedder takes 17.6 at fp16: they do not both fit, and it makes no difference who loads
it. That TabbyAPI lists Qwen3-Embedding-8B among its models means the file is in its
models directory, not that it could serve it beside the generator. The reranker fits
because it is 1.2 GB, which is the whole of why the two cases came out differently.

What is actually wrong there is the reload rather than the device. A query encodes one
short string, 0.36 s of work, and pays 3.7 s to bring up a 15 GB model to do it; a build
embeds the whole archive in one process and already runs when the card is free. The fix
is residency, not hardware, and at 4 s of a 31 s query it is not urgent.

The reranker chose its device in silence, unlike the embedder, which is what made the CPU
fallback invisible for a day. It says so now.
