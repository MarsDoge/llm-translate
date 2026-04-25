#!/usr/bin/env bash
# Moonshot AI (Kimi) — https://platform.moonshot.cn
# llm-translate-stream: yes
set -euo pipefail

: "${MOONSHOT_API_KEY:?MOONSHOT_API_KEY is not set}"
: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_SYSTEM:?missing system prompt}"

# shellcheck source=../openai_compat.sh
PROVIDER_DIR="$(cd -P "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck disable=SC1091
. "$PROVIDER_DIR/../openai_compat.sh"

MODEL="${LLM_TRANSLATE_MODEL:-moonshot-v1-8k}"
[ -n "$MODEL" ] || MODEL="moonshot-v1-8k"
ENDPOINT="${MOONSHOT_API_BASE:-https://api.moonshot.cn/v1}/chat/completions"

llm_translate_openai_compat \
  "$ENDPOINT" \
  "Authorization: Bearer $MOONSHOT_API_KEY" \
  "$MODEL" \
  "kimi"
