#!/usr/bin/env python
"""Rerank stage for the embedding A/B: take the top-K pages from a saved embedding run, score (query, page) with a
cross-encoder reranker, and report document recall, MRR and page hit at 10 before and after, plus latency per query.

    rerank_ab.py <embed-ab dir> <embedding model name> <reranker path> [kind: qwen3|bge] [K] [quant: none|int8|nf4]

Peak VRAM is reported because it is half the decision: the reranker has to sit beside the served chat model on
one card, so a 4B arm is only interesting at a quantization that leaves the generator its weights and cache.
"""
import json, pathlib, sys, time
import numpy as np, torch
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import embed_ab as E
def load_reranker(path, kind, quant='none'):
    """Cross-encoder scorer. For Qwen3-Reranker the sentence-transformers CrossEncoder applies the model's chat
    template and truncates the document, not the template, which a hand-rolled prompt can get wrong on long pages.
    quant is bitsandbytes: int8 keeps the scores essentially intact and roughly halves the weights, nf4 quarters
    them and is here to be measured rather than assumed, since the score IS the output of a reranker."""
    from sentence_transformers import CrossEncoder
    inst = 'Given a question about a physical law, numerical scheme, dataset or constant, judge whether the page of a scientific paper or book states it'
    mk = {'torch_dtype': torch.float16}
    if quant != 'none':
        from transformers import BitsAndBytesConfig
        mk['quantization_config'] = (BitsAndBytesConfig(load_in_8bit=True) if quant == 'int8' else
                                     BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type='nf4',
                                                        bnb_4bit_compute_dtype=torch.float16))
        mk['device_map'] = 'cuda'
    kw = dict(max_length=E.MAX_SEQ, device='cuda', model_kwargs=mk)
    if kind == 'qwen3': kw.update(prompts={'locate': inst}, default_prompt_name='locate')
    ce = CrossEncoder(path, **kw)
    return lambda q, docs: [float(x) for x in ce.predict([(q, d) for d in docs], batch_size=4, show_progress_bar=False)]
def main():
    out, emb_name, rpath = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]; kind = sys.argv[4] if len(sys.argv) > 4 else 'qwen3'; K = int(sys.argv[5]) if len(sys.argv) > 5 else 50; quant = sys.argv[6] if len(sys.argv) > 6 else 'none' 
    pages, meta = E.load_corpus(); all_stems = E.stems(); D = np.load(out / f'{emb_name}.npy')
    # re-embed queries with the same model (cheap) to get Q
    qcache = out / f'{emb_name}.queries.npy'
    if qcache.exists(): Q = np.load(qcache)
    else:
        _, Q, _ = E.encode(emb_name, {'bge-m3': '/home/cfutro/models/bge-m3', 'jina-v5-small': '/home/cfutro/models/jina-embeddings-v5-text-small', 'qwen3-8b': '/home/cfutro/models/Qwen3-Embedding-8B'}[emb_name], pages[:1], [q for q, _, _ in E.QUERIES]); np.save(qcache, Q)
    torch.cuda.reset_peak_memory_stats() if torch.cuda.is_available() else None
    score = load_reranker(rpath, kind, quant); S = Q @ D.T
    def metrics(orders):
        r5 = r10 = mrr = 0; ph = pn = 0; per = []
        for qi, (q, pre, pgs) in enumerate(E.QUERIES):
            want = E.resolve(pre, all_stems); seen = []; rank = None
            for j in orders[qi]:
                s = meta[j][0]
                if s not in seen: seen.append(s)
                if rank is None and s in want: rank = len(seen)
            top10 = [(meta[j][0], meta[j][1]) for j in orders[qi][:10]]
            r5 += rank is not None and rank <= 5; r10 += rank is not None and rank <= 10; mrr += (1 / rank) if rank else 0
            for sp, pp in pgs.items(): pn += 1; ph += any(s.startswith(sp) and p in pp for s, p in top10)
            per.append({'query': q[:60], 'rank': rank, 'top3': [f'{s} p.{p}' for s, p in top10[:3]]})
        n = len(E.QUERIES); return {'doc_recall@5': r5 / n, 'doc_recall@10': r10 / n, 'mrr': mrr / n, 'page_hit@10': (ph / pn) if pn else None, 'per_query': per}
    base = [np.argsort(-S[qi])[:K] for qi in range(len(E.QUERIES))]
    t0 = time.time(); rer = []
    for qi, (q, _, _) in enumerate(E.QUERIES):
        cand = base[qi]; sc = score(q, [pages[j] for j in cand]); rer.append(cand[np.argsort(-np.array(sc))])
    lat = (time.time() - t0) / len(E.QUERIES)
    peak = (torch.cuda.max_memory_allocated() / 2**30) if torch.cuda.is_available() else None
    res = {'embedding': emb_name, 'reranker': rpath, 'quant': quant, 'K': K, 'before': metrics(base), 'after': metrics(rer), 'rerank_seconds_per_query': lat, 'peak_vram_gib': peak}
    json.dump(res, open(out / f'rerank_{emb_name}_{pathlib.Path(rpath).name}_{quant}.json', 'w'), indent=1)
    b, a = res['before'], res['after']
    print(f"| stage | doc recall@5 | doc recall@10 | MRR | page hit@10 |\n|---|---|---|---|---|\n| {emb_name} alone | {b['doc_recall@5']:.2f} | {b['doc_recall@10']:.2f} | {b['mrr']:.2f} | {b['page_hit@10']} |\n| + {pathlib.Path(rpath).name} {quant} (top {K}) | {a['doc_recall@5']:.2f} | {a['doc_recall@10']:.2f} | {a['mrr']:.2f} | {a['page_hit@10']} |\nrerank latency {lat:.1f} s/query, peak VRAM {peak:.1f} GiB")
if __name__ == '__main__': main()
