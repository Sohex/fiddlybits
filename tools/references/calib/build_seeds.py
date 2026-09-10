#!/usr/bin/env python3
"""
Stage 2: questions + chunks -> seeds.jsonl, one record per question carrying the
evidence PaperQA2 would have retrieved for it.

A seed is not yet a prompt. The summary prompts can be rendered from it directly, but
the answer prompt needs the summaries themselves, so gen_trace.py renders that one
after sampling. Importable so gen_trace.py can fold in the questions the model derives
from the corpus without a second pass over the index.

    python build_seeds.py [-o seeds.jsonl]
"""
import argparse, hashlib, json, pathlib, tomllib

import retrieve

HERE = pathlib.Path(__file__).parent
ROOT = HERE.parents[2]
PQ = tomllib.loads((ROOT / 'tools' / 'references' / 'paperqa.toml').read_text())
PROMPTS = json.loads((HERE / 'prompts.json').read_text())


def citation_key(chunk):
    """A stable PaperQA2-shaped context key, so the answer prompt cites what it cites."""
    h = hashlib.sha256(f'{chunk["doc"]}:{chunk["page"]}:{chunk.get("start", 0)}'.encode()).hexdigest()[:8]
    return f'pqac-{h}'


def summary_prompt(question, chunk):
    """The evidence-summary call: one excerpt, one question, a JSON summary and score."""
    length = PROMPTS['evidence_summary_length']
    if PROMPTS['use_json']:
        system = PROMPTS['summary_json_system_prompt'].format(summary_length=length)
        user = PROMPTS['summary_json_prompt'].format(
            citation=chunk['citation'], text=chunk['text'], question=question)
    else:
        system = PROMPTS['default_system_prompt']
        user = PROMPTS['summary_prompt'].format(
            citation=chunk['citation'], text=chunk['text'],
            question=question, summary_length=length)
    return system, user


def answer_prompt(question, contexts):
    """The final answer call: the surviving summaries, their keys, and the question."""
    inner = '\n\n'.join(
        PROMPTS['context_inner'].format(name=c['name'], text=c['summary'], citation=c['citation'])
        for c in contexts)
    context = PROMPTS['context_outer'].format(
        context_str=inner, valid_keys=', '.join(c['name'] for c in contexts))
    user = PROMPTS['qa_prompt'].format(
        context=context, question=question, example_citation=PROMPTS['EXAMPLE_CITATION'],
        answer_length=PROMPTS['answer_length'], prior_answer_prompt='')
    return PROMPTS['default_system_prompt'], user


class BM25Retriever:
    """Fallback when no index is named: the reconstruction in build_chunks.py + retrieve.py."""

    def __init__(self, chunks=None, bm=None):
        self.chunks, self.bm = (chunks, bm) if chunks is not None else retrieve.load()

    def sample(self, n, rng):
        """Random excerpts, for deriving extra questions from the corpus."""
        picks = rng.sample(range(len(self.chunks)), min(n, len(self.chunks)))
        return [self.chunks[i]['text'] for i in picks]

    def evidence(self, question, k):
        out = []
        for idx, score in self.bm.query(question, k):
            c = self.chunks[idx]
            out.append({'name': citation_key(c), 'citation': c['citation'], 'doc': c['doc'],
                        'page': c['page'], 'text': c['text'], 'score': round(score, 3)})
        return out


def default_retriever():
    """The real index when calib.toml names one, else the BM25 reconstruction."""
    import tomllib
    cfg = tomllib.loads((HERE / 'calib.toml').read_text())
    if cfg.get('index', {}).get('name'):
        import retrieve_index
        return retrieve_index.IndexRetriever(retrieve_index.query_embedder())
    return BM25Retriever()


def build(questions, retriever=None, k=None):
    """Attach retrieved evidence to each question. Returns a list of seed records.

    The index retriever is async and the BM25 one is not, so both are driven through one
    coroutine and the caller does not have to know which calib.toml selected.
    """
    import asyncio, inspect

    async def gather(r, k):
        seeds = []
        for q in questions:
            ev = r.evidence(q['text'], k)
            if inspect.isawaitable(ev):
                ev = await ev
            if ev:
                seeds.append({'question': q['text'], 'area': q.get('area', ''),
                              'kind': q.get('kind', ''), 'origin': q.get('origin', 'curated'),
                              'evidence': ev})
        return seeds

    return asyncio.run(gather(retriever or default_retriever(), k or PQ.get('evidence_k', 12)))


def curated():
    q = tomllib.loads((HERE / 'questions.toml').read_text())['question']
    for x in q:
        x['origin'] = 'curated'
    return q


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-o', '--out', default=str(HERE / 'seeds.jsonl'))
    ap.add_argument('--bm25', action='store_true',
                    help='force the BM25 reconstruction even when calib.toml names an index')
    a = ap.parse_args()
    seeds = build(curated(), BM25Retriever() if a.bm25 else None)
    with open(a.out, 'w') as f:
        for s in seeds:
            f.write(json.dumps(s) + '\n')
    n_ev = sum(len(s['evidence']) for s in seeds)
    print(f'{len(seeds)} questions, {n_ev} evidence chunks '
          f'({n_ev // max(1, len(seeds))} per question) -> {a.out}')


if __name__ == '__main__':
    main()
