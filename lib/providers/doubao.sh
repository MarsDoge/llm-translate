#!/usr/bin/env bash
# ByteDance Doubao (豆包) via Volcengine Ark — https://www.volcengine.com/docs/82379
# NOTE: Ark uses endpoint IDs (e.g. "ep-20250101-xxxxx"), not model names.
# Create an endpoint in the Volcengine console and pass it via -m or env.
set -euo pipefail

: "${ARK_API_KEY:?ARK_API_KEY is not set}"
: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_SYSTEM:?missing system prompt}"

# shellcheck source=../openai_compat.sh
. "$(dirname "$(readlink -f "$0")")/../openai_compat.sh"

MODEL="${LLM_TRANSLATE_MODEL:-}"
if [ -z "$MODEL" ]; then
  echo "doubao: -m / LLM_TRANSLATE_MODEL is required (Volcengine Ark endpoint ID, e.g. ep-20250101-xxxxx)" >&2
  exit 1
fi
ENDPOINT="${ARK_API_BASE:-https://ark.cn-beijing.volces.com/api/v3}/chat/completions"

llm_translate_openai_compat \
  "$ENDPOINT" \
  "Authorization: Bearer $ARK_API_KEY" \
  "$MODEL" \
  "doubao"
