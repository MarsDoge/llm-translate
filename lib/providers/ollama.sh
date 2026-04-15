#!/usr/bin/env bash
# Ollama provider — https://ollama.com (local inference)
set -euo pipefail

: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_SYSTEM:?missing system prompt}"

MODEL="${LLM_TRANSLATE_MODEL:-qwen2.5:7b}"
[ -n "$MODEL" ] || MODEL="qwen2.5:7b"
HOST="${OLLAMA_HOST:-http://localhost:11434}"
ENDPOINT="$HOST/api/chat"
TEMPERATURE="${LLM_TRANSLATE_TEMPERATURE:-0.2}"

payload="$(jq -n \
  --arg model  "$MODEL" \
  --arg system "$LLM_TRANSLATE_SYSTEM" \
  --arg user   "$LLM_TRANSLATE_INPUT" \
  --argjson temp "$TEMPERATURE" \
  '{
    model: $model,
    stream: false,
    options: { temperature: $temp },
    messages: [
      {role: "system", content: $system},
      {role: "user",   content: $user}
    ]
  }')"

body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT
http_code="$(curl -sS -o "$body_file" -w '%{http_code}' "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "$payload")" || {
    echo "ollama: curl failed: $(cat "$body_file")" >&2
    exit 1
  }

if [ "$http_code" -ge 400 ]; then
  echo "ollama: HTTP $http_code: $(cat "$body_file")" >&2
  exit 1
fi

jq -r '.message.content' < "$body_file"
