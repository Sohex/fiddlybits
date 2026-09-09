#!/usr/bin/env python3
"""
Stage 4: trace + bundled corpus -> the packed rows exllamav3's --cal_data expects.

The trace alone would be a mistake. exllamav3's bundled mix is not just text: a fifth
of it is uniform random token rows, there to exercise the whole vocabulary. This model
carries 248320 tokens, and a trace drawn from one archive of one field touches a small
corner of that, leaving most embedding and head rows cold through the calibration
forwards. So the trace is blended, at the weights in calib.toml, against exllamav3's
own corpus processors rather than a reimplementation of them.

    python pack_cal.py [-o cal.safetensors]
"""
import argparse, json, pathlib, random, sys, tomllib

import torch
from safetensors.torch import save_file

HERE = pathlib.Path(__file__).parent
CFG = tomllib.loads((HERE / 'calib.toml').read_text())
EXL3 = pathlib.Path('/home/cfutro/git/exllamav3')
sys.path.insert(0, str(EXL3))

from exllamav3 import Config, Tokenizer                                   # noqa: E402
from exllamav3.conversion import calibration_data as cd                   # noqa: E402

SOURCES = {
    'wiki': ('wiki.utf8', cd.split_wiki),
    'c4': ('c4.utf8', cd.shuffle_lines),
    'code': ('code.utf8', cd.split_raw),
    'technical': ('technical.utf8', cd.split_raw),
    'multilingual': ('multilingual.utf8', cd.shuffle_lines),
    'random': (None, cd.random_data),
}


def trace_rows(path, rows, cols, seed):
    """Each record's exact model-visible stream, shuffled, concatenated, sliced to width."""
    recs = [json.loads(l) for l in open(path) if l.strip()]
    order = list(range(len(recs)))
    random.Random(seed).shuffle(order)
    stream = []
    for i in order:
        stream += recs[i]['input_ids'] + recs[i]['response_ids']
    have = len(stream) // cols
    if have < rows:
        print(f' !! trace holds {have} rows of {cols}, wanted {rows}; '
              f'short by {(rows - have) * cols:,} tokens', file=sys.stderr)
    n = min(rows, have)
    t = torch.tensor(stream[:n * cols], dtype=torch.long).view(n, cols)
    return [t[i:i + 1] for i in range(n)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-t', '--trace', default=str(HERE / 'trace.jsonl'))
    ap.add_argument('-o', '--out', default=str(HERE / 'cal.safetensors'))
    ap.add_argument('--rows', type=int, default=CFG['pack']['rows'])
    ap.add_argument('--cols', type=int, default=CFG['pack']['cols'])
    a = ap.parse_args()

    tokenizer = Tokenizer.from_config(Config.from_directory(CFG['model']['dir']))
    weights = {k: v for k, v in CFG['pack'].items() if k not in ('rows', 'cols')}
    total = sum(weights.values())
    data_dir = EXL3 / 'exllamav3' / 'conversion' / 'standard_cal_data'

    # Largest remainder, so the shares sum to exactly --rows and no source is starved.
    exact = {k: v / total * a.rows for k, v in weights.items()}
    share = {k: max(1, int(v)) for k, v in exact.items()}
    for k in sorted(weights, key=lambda k: exact[k] - int(exact[k]), reverse=True):
        if sum(share.values()) >= a.rows:
            break
        share[k] += 1
    while sum(share.values()) > a.rows:
        k = max(share, key=lambda k: share[k])
        share[k] -= 1

    out, report = [], []
    got = trace_rows(a.trace, share['trace'], a.cols, CFG['trace']['seed'])
    out += got
    report.append(('trace', len(got)))

    for name, want in share.items():
        if name == 'trace':
            continue
        filename, proc = SOURCES[name]
        text = (data_dir / filename).read_text(encoding='utf8') if filename else None
        out += proc(text, want, a.cols, tokenizer)
        report.append((name, want))

    random.Random(CFG['trace']['seed']).shuffle(out)
    out = out[:a.rows]
    packed = torch.cat(out, dim=0).to(torch.long).contiguous()
    assert packed.max().item() < tokenizer.actual_vocab_size, 'token id outside the vocab'
    save_file({'input_ids': packed}, a.out)
    print(' -- rows by source: ' + ', '.join(f'{n}={c}' for n, c in report))
    print(f' -- packed {packed.shape[0]} x {packed.shape[1]} '
          f'({packed.numel():,} tokens) -> {a.out}')


if __name__ == '__main__':
    main()
