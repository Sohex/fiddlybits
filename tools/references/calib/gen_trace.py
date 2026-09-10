#!/usr/bin/env python3
"""
Stage 3: sample the trace from the unquantized model.

exllamav3's own sc_trace.py cannot do this. Its loader takes exl3 or fp16 safetensors
resident on the GPU, and this model is 51.7 GiB against a 24 GiB card; the swap_cpu
hooks in the codebase belong to the conversion pipeline, not to inference. So the
sampling runs under transformers with the weights split across the card and system
RAM, which is slow per token and does not matter: PaperQA2's token stream is almost
all context, so only about a sixth of the calibration set is ever generated.

Two phases. Summaries are the evidence call PaperQA2 makes evidence_k times per
question; answers are the single call it makes over the summaries that survive. Every
record keeps the exact model-visible token stream, prompt and response, for pack_cal.py
to slice into rows.

Seeds come from build_seeds.py, which runs in the venv holding paperqa; this stage runs
wherever torch and the model are. They are separate processes on purpose: the retrieval
side and the generation side do not share a dependency set.

Heavy: run under qrun, with RAM for the CPU-resident half of the weights.

    qrun -p gpu -m 44G --vram 21G -t 12:00:00 -- python gen_trace.py

The whole card is taken, not a share: the GPU-resident half of the weights needs
about 19 GiB, so leaving shares free would only invite a job that cannot fit.
"""
import argparse, json, os, pathlib, random, re, sys, time, tomllib

import torch
from transformers import AutoTokenizer

import build_seeds

HERE = pathlib.Path(__file__).parent
CFG = tomllib.loads((HERE / 'calib.toml').read_text())
PQ = tomllib.loads((HERE.parents[2] / 'tools' / 'references' / 'paperqa.toml').read_text())

class _BlockImport:
    """Import hook that makes a package look absent."""

    def __init__(self, *names):
        self.names = names

    def find_spec(self, name, path=None, target=None):
        if name in self.names or any(name.startswith(n + '.') for n in self.names):
            raise ImportError(f'{name} blocked: no GPU in this job')
        return None


def block_triton_kernels():
    """Force the pure-torch gated-delta path.

    The 48 linear-attention layers dispatch through flash-linear-attention, which is
    Triton, which needs a CUDA driver and dies with "0 active drivers" in a CPU-only job.
    transformers carries torch implementations of the same functions and falls back to
    them, but only when the accelerated package fails to import, and that choice is made
    once when the modeling module is first imported. So the import has to fail before
    then. The torch path is correct but slower than the kernel; whether it is slower than
    streaming the weights across PCIe is the thing worth measuring.
    """
    for mod in [m for m in sys.modules if m == 'fla' or m.startswith('fla.')]:
        del sys.modules[mod]
    sys.meta_path.insert(0, _BlockImport('fla'))
    print(' -- flash-linear-attention blocked; using the torch gated-delta path', flush=True)


def load_model(model_dir, gpu_gib, cpu_gib, device='auto'):
    """Split across card and RAM, or run wholly on the CPU.

    The split is not the obvious win it looks like. accelerate treats every module mapped
    to the CPU as offloaded when the main device is a GPU: the weights stay in host RAM and
    are copied across PCIe on every forward pass, and compute happens on the card. Measured
    here that saturates a PCIe 4.0 x16 link at about 22 GB/s, which is far below what this
    CPU can read from its own memory, so the bus is the bottleneck and the cores sit idle.
    device='cpu' takes the card out of the path entirely and reads the weights in place.
    """
    from transformers import AutoModelForCausalLM, AutoModelForImageTextToText
    if device == 'cpu':
        block_triton_kernels()
        # whole physical cores, from the allocation rather than from nproc, which counts
        # both SMT siblings and would oversubscribe every core
        n = int(os.environ.get('SLURM_CPUS_PER_TASK', torch.get_num_threads()))
        torch.set_num_threads(n)
        print(f' -- CPU execution, {n} threads', flush=True)
        kw = dict(dtype=torch.bfloat16)
    else:
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


def load_seeds(path):
    recs = [json.loads(l) for l in open(path) if l.strip()]
    if not recs:
        raise SystemExit(f' ## {path} is empty; run build_seeds.py first')
    return recs


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




def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-o', '--out', default=str(HERE / 'trace.jsonl'))
    ap.add_argument('-s', '--seeds', default=str(HERE / 'seeds.jsonl'),
                    help='from build_seeds.py, which runs in the venv that holds paperqa')
    ap.add_argument('--device', choices=('auto', 'cpu'), default='auto',
                    help="'cpu' runs wholly on the CPU; 'auto' splits across card and RAM")
    ap.add_argument('--gpu-gib', type=int, default=19, help='weight budget on the card')
    ap.add_argument('--cpu-gib', type=int, default=36, help='weight budget in system RAM')
    ap.add_argument('--batch-size', type=int, default=8)
    ap.add_argument('--max-questions', type=int, default=None, help='cap, for a smoke run')
    ap.add_argument('--temperature', type=float, default=CFG['trace']['temperature'])
    ap.add_argument('--top-p', type=float, default=CFG['trace']['top_p'])
    a = ap.parse_args()

    torch.manual_seed(CFG['trace']['seed'])
    model_dir = CFG['model']['dir']
    tok = AutoTokenizer.from_pretrained(model_dir)
    seeds = load_seeds(a.seeds)
    print(f' -- {len(seeds)} seeds from {a.seeds}', flush=True)

    want = a.max_questions or questions_needed(tok, seeds)
    if want > len(seeds):
        print(f' !! seeds hold {len(seeds)} questions, budget wants {want}; '
              f'add to questions.toml and rerun build_seeds.py', flush=True)
    seeds = seeds[:want]
    print(f' -- using {len(seeds)} questions x {PQ.get("evidence_k", 12)} evidence', flush=True)

    model = load_model(model_dir, a.gpu_gib, a.cpu_gib, a.device)

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
