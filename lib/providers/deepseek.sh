#!/usr/bin/env bash
# DeepSeek provider — https://platform.deepseek.com
set -euo pipefail

: "${DEEPSEEK_API_KEY:?DEEPSEEK_API_KEY is not set}"
: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_SYSTEM:?missing system prompt}"

MODEL="${LLM_TRANSLATE_MODEL:-deepseek-chat}"
[ -n "$MODEL" ] || MODEL="deepseek-chat"
ENDPOINT="${DEEPSEEK_API_BASE:-https://api.deepseek.com}/chat/completions"
TEMPERATURE="${LLM_TRANSLATE_TEMPERATURE:-0.2}"

payload="$(jq -n \
  --arg model  "$MODEL" \
  --arg system "$LLM_TRANSLATE_SYSTEM" \
  --arg user   "$LLM_TRANSLATE_INPUT" \
  --argjson temp "$TEMPERATURE" \
  '{
    model: $model,
    messages: [
      {role: "system", content: $system},
      {role: "user",   content: $user}
    ],
    temperature: $temp,
    stream: false
  }')"

body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT
http_code="$(curl -sS -o "$body_file" -w '%{http_code}' "$ENDPOINT" \
  -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$payload")" || {
    echo "deepseek: curl failed: $(cat "$body_file")" >&2
    exit 1
  }

if [ "$http_code" -ge 400 ]; then
  echo "deepseek: HTTP $http_code: $(cat "$body_file")" >&2
  exit 1
fi

jq -r '.choices[0].message.content' < "$body_file"
