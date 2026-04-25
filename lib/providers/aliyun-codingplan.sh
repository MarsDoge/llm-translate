#!/usr/bin/env bash
# Alibaba Cloud Model Studio Coding Plan via OpenAI-compatible mode
# https://help.aliyun.com/zh/model-studio/coding-plan
# llm-translate-stream: yes
set -euo pipefail

ALIYUN_CODING_PLAN_KEY="${ALIYUN_CODING_PLAN_API_KEY:-${CODING_PLAN_API_KEY:-${BAILIAN_CODING_PLAN_API_KEY:-}}}"
: "${ALIYUN_CODING_PLAN_KEY:?ALIYUN_CODING_PLAN_API_KEY or CODING_PLAN_API_KEY or BAILIAN_CODING_PLAN_API_KEY is not set}"
: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_SYSTEM:?missing system prompt}"

# shellcheck source=../openai_compat.sh
PROVIDER_DIR="$(cd -P "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck disable=SC1091
. "$PROVIDER_DIR/../openai_compat.sh"

MODEL="${LLM_TRANSLATE_MODEL:-qwen3.5-plus}"
[ -n "$MODEL" ] || MODEL="qwen3.5-plus"
ENDPOINT="${ALIYUN_CODING_PLAN_API_BASE:-${CODING_PLAN_API_BASE:-${BAILIAN_CODING_PLAN_API_BASE:-https://coding.dashscope.aliyuncs.com/v1}}}/chat/completions"

llm_translate_openai_compat \
  "$ENDPOINT" \
  "Authorization: Bearer $ALIYUN_CODING_PLAN_KEY" \
  "$MODEL" \
  "aliyun-codingplan"
