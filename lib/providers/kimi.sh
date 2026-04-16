#!/usr/bin/env bash
# Moonshot AI (Kimi) — https://platform.moonshot.cn
set -euo pipefail

: "${MOONSHOT_API_KEY:?MOONSHOT_API_KEY is not set}"
: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_SYSTEM:?missing system prompt}"

# shellcheck source=../openai_compat.sh
. "$(dirname "$(readlink -f "$0")")/../openai_compat.sh"

MODEL="${LLM_TRANSLATE_MODEL:-moonshot-v1-8k}"
[ -n "$MODEL" ] || MODEL="moonshot-v1-8k"
ENDPOINT="${MOONSHOT_API_BASE:-https://api.moonshot.cn/v1}/chat/completions"

llm_translate_openai_compat \
  "$ENDPOINT" \
  "Authorization: Bearer $MOONSHOT_API_KEY" \
  "$MODEL" \
  "kimi"
