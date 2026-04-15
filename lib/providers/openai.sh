#!/usr/bin/env bash
# OpenAI provider — https://platform.openai.com
set -euo pipefail

: "${OPENAI_API_KEY:?OPENAI_API_KEY is not set}"
: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_SYSTEM:?missing system prompt}"

MODEL="${LLM_TRANSLATE_MODEL:-gpt-4o-mini}"
[ -n "$MODEL" ] || MODEL="gpt-4o-mini"
ENDPOINT="${OPENAI_API_BASE:-https://api.openai.com/v1}/chat/completions"
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
    temperature: $temp
  }')"

body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT
http_code="$(curl -sS -o "$body_file" -w '%{http_code}' "$ENDPOINT" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$payload")" || {
    echo "openai: curl failed: $(cat "$body_file")" >&2
    exit 1
  }

if [ "$http_code" -ge 400 ]; then
  echo "openai: HTTP $http_code: $(cat "$body_file")" >&2
  exit 1
fi

jq -r '.choices[0].message.content' < "$body_file"
