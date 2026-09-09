#!/usr/bin/env python3
"""
Stage 3: sample the trace from the unquantized model.

exllamav3's own sc_trace.py cannot do this. Its loader takes exl3 or fp16 safetensors
resident on the GPU, and this model is 51.7 GiB against a 24 GiB card; the swap_cpu
hooks in the codebase belong to the conversion pipeline, not to inference. So the
sampling runs under transformers with the weights split across the card and system
RAM, which is slow per token and does not matter: PaperQA2's token stream is almost
all context, so only about a sixth of the calibration set is ever generated.

Three phases. Derived questions widen the curated bank. Summaries are the evidence
call PaperQA2 makes evidence_k times per question. Answers are the single call it
makes over the surviving summaries. Every record keeps the exact model-visible token
stream, prompt and response, for pack_cal.py to slice into rows.

Heavy: run under qrun, with RAM for the CPU-resident half of the weights.

    qrun -p gpu -m 44G --vram 21G -t 12:00:00 -- python gen_trace.py

The whole card is taken, not a share: the GPU-resident half of the weights needs
about 19 GiB, so leaving shares free would only invite a job that cannot fit.
"""
import argparse, json, pathlib, random, re, sys, time, tomllib

import torch
from transformers import AutoTokenizer

import build_seeds, retrieve

HERE = pathlib.Path(__file__).parent
CFG = tomllib.loads((HERE / 'calib.toml').read_text())
PQ = tomllib.loads((HERE.parents[2] / 'tools' / 'references' / 'paperqa.toml').read_text())

QUESTION_ASK = (
    'Below is an excerpt from a scientific paper.\n\n---\n\n{text}\n\n---\n\n'
    'Write one question that a researcher building a planetary simulation would ask a '
    'literature search tool, that this excerpt helps answer. Ask about a physical law, a '
    'numerical scheme, a dataset or a constant. Write the question alone, no preamble.'
)


def load_model(model_dir, gpu_gib, cpu_gib):
    from transformers import AutoModelForCausalLM, AutoModelForImageTextToText
    kw = dict(dtype=torch.bfloat16, device_map='auto',
              max_memory={0: f'{gpu_gib}GiB', 'cpu': f'{cpu_gib}GiB'})
    for cls in (AutoModelForCausalLM, AutoModelForImageTextToText):
        try:
            m = cls.from_pretrained(model_dir, **kw)
            print(f' -- loaded via {cls.__name__}', flush=True)
            return m.eval()
        except Exception as e:
            print(f' !! {cls.__name__}: {type(e).__name__}: {str(e)[:160]}', flush=True)
    raise SystemExit(' ## could not load the model under either auto class')


def render(tok, system, user, role='summary'):
    """Render one call exactly as the server would, thinking mode included."""
    th = CFG['thinking'][role]
    msgs = ([{'role': 'system', 'content': system}] if system else []) + \
           [{'role': 'user', 'content': user}]
    return tok.apply_chat_template(msgs, tokenize=False, add_generation_prompt=True,
                                   enable_thinking=th['enable'], reasoning_effort=th['effort'])


def trim(ids, eos):
    """Cut the sampled row at the first end token, keeping it: that is the real stream."""
    for i, t in enumerate(ids):
        if t in eos:
            return ids[:i + 1]
    return ids


@torch.inference_mode()
def generate(model, tok, prompts, max_new, batch_size, label, temperature, top_p):
    """Batched sampling. Returns (prompt_ids, response_ids) per prompt, in input order."""
    eos = set(getattr(model.generation_config, 'eos_token_id', None) or [tok.eos_token_id])
    order = sorted(range(len(prompts)), key=lambda i: -len(prompts[i]))
    out = [None] * len(prompts)
    t0, done = time.time(), 0
    for start in range(0, len(order), batch_size):
        idx = order[start:start + batch_size]
        enc = tok([prompts[i] for i in idx], return_tensors='pt',
                  padding=True, padding_side='left', add_special_tokens=False)
        enc = {k: v.to(model.device) for k, v in enc.items()}
        gen = model.generate(**enc, max_new_tokens=max_new, do_sample=temperature > 0,
                             temperature=temperature, top_p=top_p,
                             pad_token_id=tok.pad_token_id or tok.eos_token_id)
        plen = enc['input_ids'].shape[1]
        for j, i in enumerate(idx):
            keep = enc['attention_mask'][j].bool()
            prompt_ids = enc['input_ids'][j][keep].tolist()
            out[i] = (prompt_ids, trim(gen[j][plen:].tolist(), eos))
        done += len(idx)
        rate = sum(len(out[i][1]) for i in order[:done]) / max(1e-9, time.time() - t0)
        print(f'    {label}: {done}/{len(prompts)}  {rate:.1f} gen tok/s', flush=True)
    return out


def questions_needed(tok, seeds):
    """How many questions the pack's trace budget actually needs. Generation is the cost."""
    pack = CFG['pack']
    weights = {k: v for k, v in pack.items() if k not in ('rows', 'cols')}
    target = pack['rows'] * pack['cols'] * weights['trace'] / sum(weights.values())
    target *= CFG['trace']['margin']
    sample = [(s, e) for s in seeds[:4] for e in s['evidence'][:3]]
    prompt = sum(len(tok(render(tok, *build_seeds.summary_prompt(s['question'], e), 'summary'),
                         add_special_tokens=False)['input_ids']) for s, e in sample) / len(sample)
    # a summary response runs well short of its cap; half the cap is the honest expectation
    per_summary = prompt + CFG['trace']['max_new_summary'] / 2
    per_question = PQ.get('evidence_k', 12) * per_summary + CFG['trace']['max_new_answer']
    n = max(1, int(target / per_question + 0.5))
    print(f' -- trace budget {target:,.0f} tokens, ~{per_question:,.0f} per question '
          f'-> {n} questions', flush=True)
    return n


def derive_questions(model, tok, chunks, n_extra, args):
    """Widen the curated bank with questions the model asks of sampled excerpts."""
    rng = random.Random(CFG['trace']['seed'])
    # ask for more than needed; the shape filter below rejects some
    picks = rng.sample(range(len(chunks)), min(len(chunks), int(n_extra * 1.6) + 4))
    prompts = [render(tok, None, QUESTION_ASK.format(text=chunks[i]['text'][:3000]), 'question')
               for i in picks]
    pairs = generate(model, tok, prompts, CFG['trace']['max_new_question'],
                     args.batch_size, 'questions', args.temperature, args.top_p)
    derived = []
    for (_, resp), i in zip(pairs, picks):
        text = tok.decode(resp, skip_special_tokens=True).strip().split('\n')[0].strip()
        text = re.sub(r'^["\'\s]*(?:Question:)?\s*', '', text).strip(' "\'')
        if 20 < len(text) < 400 and text.endswith('?'):
            derived.append({'text': text, 'area': '', 'kind': '', 'origin': 'derived'})
    print(f' -- {len(derived)} derived questions kept of {len(picks)} attempted', flush=True)
    return derived[:n_extra]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-o', '--out', default=str(HERE / 'trace.jsonl'))
    ap.add_argument('--gpu-gib', type=int, default=19, help='weight budget on the card')
    ap.add_argument('--cpu-gib', type=int, default=36, help='weight budget in system RAM')
    ap.add_argument('--batch-size', type=int, default=8)
    ap.add_argument('--max-questions', type=int, default=None, help='cap, for a smoke run')
    ap.add_argument('--temperature', type=float, default=CFG['trace']['temperature'])
    ap.add_argument('--top-p', type=float, default=CFG['trace']['top_p'])
    ap.add_argument('--no-derive', action='store_true', help='curated questions only')
    a = ap.parse_args()

    torch.manual_seed(CFG['trace']['seed'])
    model_dir = CFG['model']['dir']
    tok = AutoTokenizer.from_pretrained(model_dir)
    chunks, bm = retrieve.load()
    print(f' -- {len(chunks)} chunks indexed', flush=True)

    model = load_model(model_dir, a.gpu_gib, a.cpu_gib)

    curated = build_seeds.curated()
    want = a.max_questions or questions_needed(tok, build_seeds.build(curated, chunks, bm))
    questions = curated[:want]
    if not a.no_derive and want > len(curated):
        questions += derive_questions(model, tok, chunks, want - len(curated), a)
    seeds = build_seeds.build(questions, chunks, bm)
    print(f' -- {len(seeds)} questions x {PQ.get("evidence_k", 12)} evidence', flush=True)

    # Phase B: the evidence-summary calls, the bulk of what PaperQA2 asks of the model
    jobs = [(s, e) for s in seeds for e in s['evidence']]
    prompts = [render(tok, *build_seeds.summary_prompt(s['question'], e), 'summary') for s, e in jobs]
    summaries = generate(model, tok, prompts, CFG['trace']['max_new_summary'],
                         a.batch_size, 'summaries', a.temperature, a.top_p)

    rows, by_question = [], {}
    for (s, e), (pids, rids) in zip(jobs, summaries):
        text = tok.decode(rids, skip_special_tokens=True).strip()
        rows.append({'role': 'summary', 'question': s['question'], 'name': e['name'],
                     'citation': e['citation'], 'input_ids': pids, 'response_ids': rids})
        score = 0
        try:
            score = int(json.loads(re.search(r'\{.*\}', text, re.S).group(0))['relevance_score'])
            body = json.loads(re.search(r'\{.*\}', text, re.S).group(0))['summary']
        except Exception:
            body = text
        by_question.setdefault(s['question'], []).append(
            {'name': e['name'], 'citation': e['citation'], 'summary': body, 'score': score})

    # Phase C: one answer call per question over the highest-scoring summaries
    keep = PQ.get('answer_max_sources', 6)
    a_jobs = []
    for q, ctxs in by_question.items():
        top = [c for c in sorted(ctxs, key=lambda c: -c['score']) if c['summary']][:keep]
        if top:
            a_jobs.append((q, top))
    prompts = [render(tok, *build_seeds.answer_prompt(q, c), 'answer') for q, c in a_jobs]
    answers = generate(model, tok, prompts, CFG['trace']['max_new_answer'],
                       a.batch_size, 'answers', a.temperature, a.top_p)
    for (q, _), (pids, rids) in zip(a_jobs, answers):
        rows.append({'role': 'answer', 'question': q, 'input_ids': pids, 'response_ids': rids})

    with open(a.out, 'w') as f:
        for r in rows:
            f.write(json.dumps(r) + '\n')
    ctx = sum(len(r['input_ids']) for r in rows)
    gen = sum(len(r['response_ids']) for r in rows)
    print(f' -- {len(rows)} rows, {ctx:,} context + {gen:,} response tokens '
          f'({gen / max(1, ctx + gen):.0%} generated) -> {a.out}')


if __name__ == '__main__':
    main()
