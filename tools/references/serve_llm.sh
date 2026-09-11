#!/bin/bash
# Serve the local LLM PaperQA2 uses, on one GPU share, OpenAI-compatible on 127.0.0.1:5000.
# Blocks; run under qrun.
#   qrun -p gpu-share -s 1 --vram 21G -t 12:00:00 -- tools/references/serve_llm.sh
# The port, the model and the reasoning mode are set in the config, and paperqa.toml's
# api_base and thinking must agree with it.
TABBY=${TABBY_ROOT:-"$HOME/git/tabbyAPI"}
CONFIG=${TABBY_CONFIG:-"$TABBY/config_pqa.yml"}
exec "$TABBY/.venv/bin/python" "$TABBY/main.py" --config "$CONFIG"
