#!/usr/bin/env bash
# Anthropic Claude provider — https://docs.anthropic.com
# llm-translate-stream: yes
set -euo pipefail

: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY is not set}"
: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_SYSTEM:?missing system prompt}"

MODEL="${LLM_TRANSLATE_MODEL:-claude-haiku-4-5-20251001}"
[ -n "$MODEL" ] || MODEL="claude-haiku-4-5-20251001"
ENDPOINT="${ANTHROPIC_API_BASE:-https://api.anthropic.com/v1}/messages"
ANTHROPIC_VERSION="${ANTHROPIC_VERSION:-2023-06-01}"
TEMPERATURE="${LLM_TRANSLATE_TEMPERATURE:-0.2}"
MAX_TOKENS="${LLM_TRANSLATE_MAX_TOKENS:-4096}"
STREAM="${LLM_TRANSLATE_STREAM:-0}"

payload="$(jq -n \
  --arg model  "$MODEL" \
  --arg system "$LLM_TRANSLATE_SYSTEM" \
  --arg user   "$LLM_TRANSLATE_INPUT" \
  --argjson temp "$TEMPERATURE" \
  --argjson maxtok "$MAX_TOKENS" \
  --argjson stream "$([ "$STREAM" = "1" ] && echo true || echo false)" \
  '{
    model: $model,
    max_tokens: $maxtok,
    temperature: $temp,
    system: $system,
    stream: $stream,
    messages: [
      {role: "user", content: $user}
    ]
  }')"

if [ "$STREAM" = "1" ]; then
  # shellcheck source=../stream.sh
  . "$(dirname "$(readlink -f "$0")")/../stream.sh"
  set -o pipefail
  curl -sS -N "$ENDPOINT" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: $ANTHROPIC_VERSION" \
    -H "Content-Type: application/json" \
    -H "Accept: text/event-stream" \
    -d "$payload" \
    | llm_translate_stream_anthropic_sse "claude"
  exit $?
fi

body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT
http_code="$(curl -sS -o "$body_file" -w '%{http_code}' "$ENDPOINT" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: $ANTHROPIC_VERSION" \
  -H "Content-Type: application/json" \
  -d "$payload")" || {
    echo "claude: curl failed: $(cat "$body_file")" >&2
    exit 1
  }

if [ "$http_code" -ge 400 ]; then
  echo "claude: HTTP $http_code: $(cat "$body_file")" >&2
  exit 1
fi

jq -r '.content[0].text' < "$body_file"
