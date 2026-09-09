#!/usr/bin/env python3
"""
BM25 retrieval over the chunks from build_chunks.py.

PaperQA2 retrieves with a Qwen3-Embedding-8B index, which would want the GPU and the
index build. For calibration the point of retrieval is only to put each question with
a realistic spread of chunks: a few that answer it, several that touch it, and some
near-misses the summariser is meant to score low and decline. Lexical retrieval
produces that spread on a corpus this size, on CPU, in seconds.

Importable (index once, query many) or run directly to eyeball a query.
"""
import argparse, json, math, pathlib, re
from collections import Counter

STOP = set('a an and are as at be by for from has have in into is it its of on or that the to '
           'was were what which with how does do can we our this these those than then use used '
           'using between over under during when where why value values set sets given'.split())
WORD = re.compile(r'[a-z0-9]+')


def tokens(text):
    return [w for w in WORD.findall(text.lower()) if w not in STOP and len(w) > 2]


class BM25:
    def __init__(self, docs, k1=1.5, b=0.75):
        self.k1, self.b, self.N = k1, b, len(docs)
        self.lens = [len(d) for d in docs]
        self.avg = sum(self.lens) / max(1, self.N)
        self.post = {}
        for i, d in enumerate(docs):
            for term, tf in Counter(d).items():
                self.post.setdefault(term, []).append((i, tf))
        self.idf = {t: math.log(1 + (self.N - len(p) + 0.5) / (len(p) + 0.5))
                    for t, p in self.post.items()}

    def query(self, text, k=12):
        scores = Counter()
        for term in set(tokens(text)):
            if term not in self.post:
                continue
            idf = self.idf[term]
            for i, tf in self.post[term]:
                norm = 1 - self.b + self.b * self.lens[i] / self.avg
                scores[i] += idf * tf * (self.k1 + 1) / (tf + self.k1 * norm)
        return scores.most_common(k)


def load(path=None):
    path = pathlib.Path(path or pathlib.Path(__file__).parent / 'chunks.jsonl')
    chunks = [json.loads(l) for l in path.open() if l.strip()]
    return chunks, BM25([tokens(c['text']) for c in chunks])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('query')
    ap.add_argument('-k', type=int, default=12)
    a = ap.parse_args()
    chunks, bm = load()
    print(f'{len(chunks)} chunks indexed')
    for i, s in bm.query(a.query, a.k):
        print(f'  {s:7.2f}  {chunks[i]["citation"]}\n           {chunks[i]["text"][:120].strip()}')


if __name__ == '__main__':
    main()
