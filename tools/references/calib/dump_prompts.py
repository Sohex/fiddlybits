#!/usr/bin/env python3
"""
Copy PaperQA2's own prompt templates out of the installed package into prompts.json,
so the calibration seeds are rendered from the same strings PaperQA2 serves with and
nothing is transcribed by hand. Run under the venv that holds paperqa:

    /home/cfutro/.venvs/fiddlybits-tools/bin/python dump_prompts.py
"""
import json, pathlib
import paperqa, paperqa.prompts as pr
from paperqa.settings import Settings

s = Settings()
out = {
    'paperqa_version': paperqa.__version__,
    'use_json': bool(getattr(s.prompts, 'use_json', True)),
    'evidence_summary_length': getattr(s.answer, 'evidence_summary_length', 'about 100 words'),
    'answer_length': getattr(s.answer, 'answer_length', 'about 200 words, but can be longer'),
    'summary_json_system_prompt': pr.summary_json_system_prompt,
    'summary_json_prompt': pr.summary_json_prompt,
    'summary_prompt': pr.summary_prompt,
    'qa_prompt': pr.qa_prompt,
    'default_system_prompt': pr.default_system_prompt,
    'context_inner': getattr(s.prompts, 'context_inner', '{name}: {text}\nFrom {citation}'),
    'context_outer': getattr(s.prompts, 'context_outer', '{context_str}\n\nValid Keys: {valid_keys}'),
    'EXAMPLE_CITATION': getattr(pr, 'EXAMPLE_CITATION', '(pqac-abcd1234)'),
}
p = pathlib.Path(__file__).parent / 'prompts.json'
p.write_text(json.dumps(out, indent=2))
print(f'paperqa {paperqa.__version__}: {len(out) - 3} templates -> {p}')
