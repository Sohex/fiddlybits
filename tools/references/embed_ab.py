#!/usr/bin/env python
"""A/B/C of embedding models for page-level retrieval over the held papers.

Corpus: every page in references/text (one chunk per page, capped at MAX_WORDS words). Queries: questions whose
right answer is a locator established by hand (document stem prefixes; page where known). Scores: document
recall@5 and @10, mean reciprocal rank of the first correct document, page hit@10 where a page is known, and
encode throughput. Results to <out>/results.json and a Markdown table on stdout. Run on a GPU share under qrun.
"""
import json, pathlib, sys, time, re, gc
import numpy as np, torch
ROOT = pathlib.Path(__file__).resolve().parents[2]; TXT = ROOT / 'references' / 'text'
OUT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path('embed-ab'); OUT.mkdir(parents=True, exist_ok=True)
MAX_WORDS = 1200; MAX_SEQ = 2048
QUERIES = [
 ("pressure dependence of the dissociation constants of carbonic acid in seawater", ["millero1995", "zeebe2001"], {"millero1995": [15]}),
 ("symmetric computational instability of the vector-invariant momentum equations on a C-grid", ["hollingsworth1983", "bell2017", "peixoto2018", "gassmann2011"], {}),
 ("fill-spill-merge algorithm for routing water through a hierarchy of depressions", ["barnes2021", "barnes2020"], {}),
 ("two-flux theory of soil reflectance as a function of soil moisture in the shortwave infrared", ["sadeghi2015"], {}),
 ("dependence of snow albedo on solar zenith angle expressed through an effective grain radius", ["dang2015", "marshall1986", "wiscombe1980a"], {}),
 ("similarity solution for a shallow ice sheet dome spreading under its own weight", ["halfar1981", "halfar1983", "bueler2005"], {}),
 ("hydraulic control of flow through a strait over a sill in a rotating fluid", ["whitehead1998"], {}),
 ("size distribution of mineral dust emitted by saltation explained by brittle fragmentation", ["kok_2010"], {}),
 ("growth of an ice layer whose thickness increases with the square root of time", ["stefan1891"], {}),
 ("priority-flood algorithm for filling depressions in a digital elevation model", ["barnes2014"], {}),
 ("creep of polycrystalline ice and the exponent of the flow law", ["glen1955"], {}),
 ("effective sample size of a time series with serial correlation", ["zwiers1995", "sokal1997", "vonstorch1999"], {}),
 ("closed-form equation for the unsaturated hydraulic conductivity from the water retention curve", ["genuchten1980"], {}),
 ("linear theory of orographic precipitation for moist airflow over terrain", ["smith2004"], {}),
 ("vertical datum and the bedrock versus ice-surface elevation surfaces of the ETOPO 2022 global relief model", ["macferrin2024"], {}),
 ("stomatal conductance model reconciling the optimal and the empirical approaches", ["medlyn2011"], {}),
 ("stability condition relating the time step to the grid spacing for partial difference equations of mathematical physics", ["courant1928"], {}),
 ("energy-conserving thermodynamic sea ice model with three layers", ["winton2000", "bitz1999"], {}),
]
def load_corpus():
    pages, meta = [], []
    for d in sorted(p for p in TXT.iterdir() if p.is_dir()):
        for pg in sorted(d.glob('*.txt')):
            t = pg.read_text(errors='ignore').strip()
            if len(t) < 40: continue
            w = t.split(); pages.append(' '.join(w[:MAX_WORDS])); meta.append((d.name, int(pg.stem)))
    return pages, meta
def stems(): return sorted(p.name for p in TXT.iterdir() if p.is_dir())
def resolve(prefixes, all_stems):
    r = {s for s in all_stems for p in prefixes if s.startswith(p)}
    assert r, f'no document for {prefixes}'; return r
def encode(model_name, path, pages, queries):
    from sentence_transformers import SentenceTransformer
    kw = dict(device='cuda')
    if model_name == 'bge-m3':
        m = SentenceTransformer(path, model_kwargs={'torch_dtype': torch.float16}, **kw); m.max_seq_length = MAX_SEQ
        enc_d = lambda x, bs: m.encode(x, batch_size=bs, normalize_embeddings=True, convert_to_numpy=True, show_progress_bar=False)
        enc_q = lambda x: m.encode(x, normalize_embeddings=True, convert_to_numpy=True)
    elif model_name == 'jina-v5-small':
        m = SentenceTransformer(path, trust_remote_code=True, model_kwargs={'torch_dtype': torch.float16}, **kw); m.max_seq_length = MAX_SEQ
        enc_d = lambda x, bs: m.encode(x, task='retrieval', prompt_name='document', batch_size=bs, normalize_embeddings=True, convert_to_numpy=True, show_progress_bar=False)
        enc_q = lambda x: m.encode(x, task='retrieval', prompt_name='query', normalize_embeddings=True, convert_to_numpy=True)
    else:
        m = SentenceTransformer(path, model_kwargs={'torch_dtype': torch.float16}, tokenizer_kwargs={'padding_side': 'left'}, **kw); m.max_seq_length = MAX_SEQ
        inst = 'Given a question about a physical law, numerical scheme, dataset or constant, retrieve the page of a scientific paper or book that states it'
        enc_d = lambda x, bs: m.encode(x, batch_size=bs, normalize_embeddings=True, convert_to_numpy=True, show_progress_bar=False)
        enc_q = lambda x: m.encode([f'Instruct: {inst}\nQuery:{q}' for q in x], normalize_embeddings=True, convert_to_numpy=True)
    bs = {'bge-m3': 32, 'jina-v5-small': 32, 'qwen3-8b': 4}[model_name]
    t0 = time.time(); D = []
    for i in range(0, len(pages), 512):
        D.append(enc_d(pages[i:i + 512], bs).astype(np.float32))
        if i % 5120 == 0: print(model_name, i, '/', len(pages), f'{(i or 1)/(time.time()-t0):.1f} pages/s', flush=True)
    D = np.concatenate(D); dt = time.time() - t0; Q = enc_q(queries).astype(np.float32)
    del m; gc.collect(); torch.cuda.empty_cache()
    return D, Q, dt
def score(D, Q, meta, all_stems):
    S = Q @ D.T; per = []; r5 = r10 = mrr = 0; ph = pn = 0
    for qi, (q, pre, pages) in enumerate(QUERIES):
        want = resolve(pre, all_stems); order = np.argsort(-S[qi]); seen = []; rank = None
        for j in order:
            s = meta[j][0]
            if s not in seen: seen.append(s)
            if rank is None and s in want: rank = len(seen)
            if len(seen) >= 10 and rank is not None: break
        top10 = [(meta[j][0], meta[j][1]) for j in order[:10]]
        r5 += rank is not None and rank <= 5; r10 += rank is not None and rank <= 10; mrr += (1 / rank) if rank else 0
        hit = None
        for stem_pre, pgs in pages.items():
            pn += 1; hit = any(s.startswith(stem_pre) and p in pgs for s, p in top10); ph += hit
        per.append({'query': q, 'first_correct_rank': rank, 'top3': [f'{s} p.{p}' for s, p in top10[:3]], 'page_hit': hit})
    n = len(QUERIES)
    return {'doc_recall@5': r5 / n, 'doc_recall@10': r10 / n, 'mrr': mrr / n, 'page_hit@10': (ph / pn) if pn else None, 'per_query': per}
def main():
    pages, meta = load_corpus(); all_stems = stems(); print('pages', len(pages), flush=True)
    models = [('bge-m3', '/home/cfutro/models/bge-m3'), ('jina-v5-small', '/home/cfutro/models/jina-embeddings-v5-text-small'), ('qwen3-8b', '/home/cfutro/models/Qwen3-Embedding-8B')]
    only = sys.argv[2].split(',') if len(sys.argv) > 2 else None
    prev = OUT / 'results.json'; results = json.load(open(prev)) if (only and prev.exists()) else {}
    for name, path in models:
        if only and name not in only: continue
        try:
            D, Q, dt = encode(name, path, pages, [q for q, _, _ in QUERIES]); np.save(OUT / f'{name}.npy', D)
            res = score(D, Q, meta, all_stems); res['encode_seconds'] = dt; res['pages_per_second'] = len(pages) / dt; res['dim'] = int(D.shape[1]); results[name] = res
            print(name, {k: v for k, v in res.items() if k != 'per_query'}, flush=True)
        except Exception as e:
            results[name] = {'error': repr(e)[:400]}; print(name, 'ERROR', repr(e)[:400], flush=True); gc.collect(); torch.cuda.empty_cache()
        json.dump(results, open(OUT / 'results.json', 'w'), indent=1)
    print('\n| model | dim | doc recall@5 | doc recall@10 | MRR | page hit@10 | pages/s |\n|---|---|---|---|---|---|---|')
    for n, r in results.items():
        if 'error' in r: print(f'| {n} | error | | | | | |'); continue
        print(f"| {n} | {r['dim']} | {r['doc_recall@5']:.2f} | {r['doc_recall@10']:.2f} | {r['mrr']:.2f} | {r['page_hit@10'] if r['page_hit@10'] is None else round(r['page_hit@10'],2)} | {r['pages_per_second']:.1f} |")
if __name__ == '__main__': main()
