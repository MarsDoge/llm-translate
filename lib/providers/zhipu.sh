#!/usr/bin/env bash
# Zhipu AI (智谱 GLM) — https://open.bigmodel.cn
# llm-translate-stream: yes
set -euo pipefail

: "${ZHIPUAI_API_KEY:?ZHIPUAI_API_KEY is not set}"
: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_SYSTEM:?missing system prompt}"

# shellcheck source=../openai_compat.sh
PROVIDER_DIR="$(cd -P "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck disable=SC1091
. "$PROVIDER_DIR/../openai_compat.sh"

MODEL="${LLM_TRANSLATE_MODEL:-glm-4-flash}"
[ -n "$MODEL" ] || MODEL="glm-4-flash"
ENDPOINT="${ZHIPUAI_API_BASE:-https://open.bigmodel.cn/api/paas/v4}/chat/completions"

llm_translate_openai_compat \
  "$ENDPOINT" \
  "Authorization: Bearer $ZHIPUAI_API_KEY" \
  "$MODEL" \
  "zhipu"
