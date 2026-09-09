#!/bin/bash
# Rebuild the two tool environments the references instruments and the data recipes run in. Environments live
# outside the tree (~/.venvs); everything needed to rebuild them is here. Models live in ~/models by name
# (tools/references/models.toml); datasets live IN the tree under oracles/data and inputs/data with manifests.
set -e
uv venv -q ~/.venvs/fiddlybits-tools --python 3.14
uv pip install -q --python ~/.venvs/fiddlybits-tools/bin/python -r "$(dirname "$0")/requirements-tools.txt"
uv venv -q ~/.venvs/chandra-vllm --python 3.12
uv pip install -q --python ~/.venvs/chandra-vllm/bin/python -r "$(dirname "$0")/requirements-chandra-vllm.txt"
echo "environments rebuilt: ~/.venvs/fiddlybits-tools (recipes, PaperQA2, embeddings, OCR via transformers), ~/.venvs/chandra-vllm (Chandra OCR served by vLLM)"
