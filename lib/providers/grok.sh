#!/usr/bin/env bash
# xAI Grok — https://docs.x.ai
# llm-translate-stream: yes
set -euo pipefail

: "${XAI_API_KEY:?XAI_API_KEY is not set}"
: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_SYSTEM:?missing system prompt}"

# shellcheck source=../openai_compat.sh
PROVIDER_DIR="$(cd -P "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck disable=SC1091
. "$PROVIDER_DIR/../openai_compat.sh"

MODEL="${LLM_TRANSLATE_MODEL:-grok-2-latest}"
[ -n "$MODEL" ] || MODEL="grok-2-latest"
ENDPOINT="${XAI_API_BASE:-https://api.x.ai/v1}/chat/completions"

llm_translate_openai_compat \
  "$ENDPOINT" \
  "Authorization: Bearer $XAI_API_KEY" \
  "$MODEL" \
  "grok"
