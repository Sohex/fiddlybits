#!/usr/bin/env python
"""Seed retrieval from the real PaperQA2 index, rather than from a reconstruction of it.

build_chunks.py + retrieve.py approximate what PaperQA2 does: they re-cut the reference
text at the same geometry and rank it lexically. That was the right thing while no index
existed. Once one does, the index is strictly better, because it holds the actual chunks,
the actual citation strings and the actual context keys that appear in the answer prompt's
valid-keys list, none of which a reconstruction gets exactly right.

Chunk embeddings are cached in the index, so this costs one query embedding per question
and no corpus pass. Set the index by name; it is not derived from settings here, because
PaperQA2 keys the index name on parsing and embedding configuration and a calibration run
should read the index that exists rather than the one the current config would build.

    python retrieve_index.py "a question" -k 12
"""
import argparse, asyncio, pathlib, sys, tomllib

import numpy as np

HERE = pathlib.Path(__file__).parent
ROOT = HERE.parents[2]
PQ = tomllib.loads((ROOT / 'tools' / 'references' / 'paperqa.toml').read_text())
CFG = tomllib.loads((HERE / 'calib.toml').read_text())

INDEX_DIR = ROOT / PQ.get('index_directory', 'references/index')
INDEX_NAME = CFG.get('index', {}).get('name', '')
FIELDS = ['file_location', 'body', 'title', 'year']


def _index(name=None):
    from paperqa.agents.search import SearchIndex
    name = name or INDEX_NAME
    if not name:
        avail = sorted(p.name for p in INDEX_DIR.glob('pqa_index_*') if p.is_dir())
        raise SystemExit(f' ## set index.name in calib.toml. Present in {INDEX_DIR}: {avail}')
    return SearchIndex(fields=FIELDS, index_name=name, index_directory=str(INDEX_DIR))


class IndexRetriever:
    """Tantivy for candidate documents, then cosine over the index's cached chunk vectors.

    This is PaperQA2's own shape minus the MMR diversification, which exists to spread a
    long answer over sources; for calibration what matters is that the excerpt is one the
    service would really have put in front of the model.
    """

    def __init__(self, embed, docs_per_query=30, index_name=None):
        self.idx, self.embed, self.docs_per_query = _index(index_name), embed, docs_per_query

    async def _texts(self, question):
        hits = await self.idx.query(query=question, top_n=self.docs_per_query)
        out = []
        for d in hits:
            for t in getattr(d, 'texts', None) or []:
                if getattr(t, 'embedding', None) is not None:
                    out.append(t)
        return out

    def sample(self, n, rng):
        """Random excerpts for question derivation: a few broad queries, pooled and drawn from."""
        import asyncio
        probes = ['model equation parameterization', 'dataset observations measurements',
                  'numerical scheme discretization', 'constant coefficient value',
                  'energy balance flux', 'rate law kinetics']
        texts = []
        for probe in probes:
            texts += [t.text for t in asyncio.get_event_loop().run_until_complete(self._texts(probe))]
        rng.shuffle(texts)
        return texts[:n]

    async def evidence(self, question, k):
        texts = await self._texts(question)
        if not texts:
            return []
        M = np.asarray([t.embedding for t in texts], dtype=np.float32)
        M /= np.linalg.norm(M, axis=1, keepdims=True) + 1e-9
        q = np.asarray(await self.embed(question), dtype=np.float32)
        q /= np.linalg.norm(q) + 1e-9
        order = np.argsort(-(M @ q))[:k]
        return [{
            'name': texts[i].name,
            'citation': texts[i].doc.citation,
            'doc': getattr(texts[i].doc, 'docname', '') or str(getattr(texts[i].doc, 'dockey', '')),
            'page': '',
            'text': texts[i].text,
            'score': float((M[i] @ q)),
        } for i in order]


def query_embedder():
    """The embedding model paperqa.toml names, in query mode, reusing ask.py's own class."""
    sys.path.insert(0, str(ROOT / 'tools' / 'references'))
    import ask
    from lmi.embeddings import EmbeddingModes
    m = ask.embedding_from_config()
    m.set_mode(EmbeddingModes.QUERY)
    return m.embed_document


async def _main():
    ap = argparse.ArgumentParser()
    ap.add_argument('question')
    ap.add_argument('-k', type=int, default=PQ.get('evidence_k', 12))
    ap.add_argument('--index-name', default=None)
    a = ap.parse_args()
    r = IndexRetriever(query_embedder(), index_name=a.index_name)
    for e in await r.evidence(a.question, a.k):
        print(f'  {e["score"]:.4f}  {e["name"][:60]}\n            {e["text"][:110].strip()}')


if __name__ == '__main__':
    asyncio.run(_main())
