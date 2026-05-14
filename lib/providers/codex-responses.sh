#!/usr/bin/env bash
# Codex/New Responses API provider — https://api.dogexorg.com
# llm-translate-stream: yes
set -euo pipefail

: "${OPENAI_API_KEY:?OPENAI_API_KEY is not set}"
: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_SYSTEM:?missing system prompt}"

# shellcheck source=../stream.sh
PROVIDER_DIR="$(cd -P "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck disable=SC1091
. "$PROVIDER_DIR/../stream.sh"

MODEL="${LLM_TRANSLATE_MODEL:-gpt-5.5}"
[ -n "$MODEL" ] || MODEL="gpt-5.5"
ENDPOINT="${OPENAI_API_BASE:-https://api.dogexorg.com/v1}/responses"

payload="$(jq -n \
  --arg model  "$MODEL" \
  --arg system "$LLM_TRANSLATE_SYSTEM" \
  --arg user   "$LLM_TRANSLATE_INPUT" \
  '{
    model: $model,
    input: [
      {
        role: "system",
        content: [
          {type: "input_text", text: $system}
        ]
      },
      {
        role: "user",
        content: [
          {type: "input_text", text: $user}
        ]
      }
    ],
    stream: true
  }')"

set -o pipefail
curl -sS -N "$ENDPOINT" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d "$payload" \
  | llm_translate_stream_responses_sse "codex-responses"
