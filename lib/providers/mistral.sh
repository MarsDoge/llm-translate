#!/usr/bin/env bash
# Mistral AI — https://docs.mistral.ai
# llm-translate-stream: yes
set -euo pipefail

: "${MISTRAL_API_KEY:?MISTRAL_API_KEY is not set}"
: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_SYSTEM:?missing system prompt}"

# shellcheck source=../openai_compat.sh
. "$(dirname "$(readlink -f "$0")")/../openai_compat.sh"

MODEL="${LLM_TRANSLATE_MODEL:-mistral-small-latest}"
[ -n "$MODEL" ] || MODEL="mistral-small-latest"
ENDPOINT="${MISTRAL_API_BASE:-https://api.mistral.ai/v1}/chat/completions"

llm_translate_openai_compat \
  "$ENDPOINT" \
  "Authorization: Bearer $MISTRAL_API_KEY" \
  "$MODEL" \
  "mistral"
