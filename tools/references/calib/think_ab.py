#!/usr/bin/env python
"""Same answer prompt, thinking off vs low vs medium, printed side by side.

The calibration only cares whether the answer text differs in kind, not whether the
reasoning is good: an answer written after reasoning is a different object from one
written cold, and if it is not, thinking can be turned off for the trace and the run
gets shorter. Summaries are reused from an existing trace so all three arms see exactly
the same evidence.

    qrun -p gpu -m 52G --vram 22G -- python -u think_ab.py -t smoke.jsonl
"""
import argparse, json, pathlib, re, sys, tomllib
import torch
from transformers import AutoTokenizer

import build_seeds, gen_trace

HERE = pathlib.Path(__file__).parent
CFG = tomllib.loads((HERE / 'calib.toml').read_text())
PQ = tomllib.loads((HERE.parents[2] / 'tools' / 'references' / 'paperqa.toml').read_text())


def contexts_from(trace, tok):
    """Rebuild each question's surviving summaries, exactly as gen_trace does."""
    by_q = {}
    for r in (json.loads(l) for l in open(trace)):
        if r['role'] != 'summary':
            continue
        text = tok.decode(r['response_ids'], skip_special_tokens=True).strip()
        try:
            blob = json.loads(re.search(r'\{.*\}', text, re.S).group(0))
            body, score = blob['summary'], int(blob['relevance_score'])
        except Exception:
            body, score = text, 0
        by_q.setdefault(r['question'], []).append(
            {'name': r['name'], 'citation': r['citation'], 'summary': body, 'score': score})
    keep = PQ.get('answer_max_sources', 6)
    out = {}
    for q, ctxs in by_q.items():
        top = [c for c in sorted(ctxs, key=lambda c: -c['score']) if c['summary']][:keep]
        if top:
            out[q] = top
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-t', '--trace', default=str(HERE / 'smoke.jsonl'))
    ap.add_argument('--gpu-gib', type=int, default=10)
    ap.add_argument('--cpu-gib', type=int, default=46)
    ap.add_argument('-n', type=int, default=2, help='questions to compare')
    ap.add_argument('--max-new', type=int, default=450,
                    help='low-effort thinking is brief, so the answer lands well inside this')
    a = ap.parse_args()

    tok = AutoTokenizer.from_pretrained(CFG['model']['dir'])
    qs = contexts_from(a.trace, tok)
    qs = dict(list(qs.items())[:a.n])
    print(f' -- {len(qs)} questions from {a.trace}', flush=True)

    model = gen_trace.load_model(CFG['model']['dir'], a.gpu_gib, a.cpu_gib)

    # off and low in ONE batch: the arms are independent prompts, so batching them halves
    # the wall time. medium is read from the trace rather than regenerated.
    arms = [('off', False, 'low'), ('low', True, 'low')]
    prompts, tags = [], []
    for label, enable, effort in arms:
        # render() reads gen_trace's config, not this module's; setting the local copy
        # silently left every arm at the calibration default
        gen_trace.CFG['thinking']['answer'] = {'enable': enable, 'effort': effort}
        for q, c in qs.items():
            prompts.append(gen_trace.render(tok, *build_seeds.answer_prompt(q, c), 'answer'))
            tags.append(label)
    pairs = gen_trace.generate(model, tok, prompts, a.max_new, len(prompts),
                               'answer[off+low]', 0.0, 1.0)
    results = {label: [] for label, _, _ in arms}
    for tag, (_, r) in zip(tags, pairs):
        raw = tok.decode(r, skip_special_tokens=False)
        n_think = len(raw.split('</think>')[0].split('<think>')[-1]) if '</think>' in raw else 0
        print(f'    [{tag}] response {len(r)} tok, thinking block {n_think} chars', flush=True)
        results[tag].append(tok.decode(r, skip_special_tokens=True).strip())

    # the medium arm as already generated, truncated at its 700-token cap
    results['medium'] = []
    for r in (json.loads(l) for l in open(a.trace)):
        if r['role'] == 'answer' and len(results['medium']) < len(qs):
            results['medium'].append(tok.decode(r['response_ids'], skip_special_tokens=True).strip())
    arms = arms + [('medium', True, 'medium')]

    for i, q in enumerate(qs):
        print('\n' + '=' * 100)
        print('Q:', q)
        for label, _, _ in arms:
            body = results[label][i]
            body = body.split('</think>')[-1].strip() if '</think>' in body else body
            print(f'\n--- thinking={label}  ({len(tok(body, add_special_tokens=False)["input_ids"])} answer tokens) ---')
            print(body)


if __name__ == '__main__':
    main()
