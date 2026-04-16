#!/usr/bin/env bash
# Alibaba Tongyi Qianwen (Qwen) via DashScope OpenAI-compatible mode
# https://help.aliyun.com/zh/model-studio/developer-reference/compatibility-of-openai-with-dashscope
set -euo pipefail

: "${DASHSCOPE_API_KEY:?DASHSCOPE_API_KEY is not set}"
: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_SYSTEM:?missing system prompt}"

# shellcheck source=../openai_compat.sh
. "$(dirname "$(readlink -f "$0")")/../openai_compat.sh"

MODEL="${LLM_TRANSLATE_MODEL:-qwen-plus}"
[ -n "$MODEL" ] || MODEL="qwen-plus"
ENDPOINT="${DASHSCOPE_API_BASE:-https://dashscope.aliyuncs.com/compatible-mode/v1}/chat/completions"

llm_translate_openai_compat \
  "$ENDPOINT" \
  "Authorization: Bearer $DASHSCOPE_API_KEY" \
  "$MODEL" \
  "qwen"
