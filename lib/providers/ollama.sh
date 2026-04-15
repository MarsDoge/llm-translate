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

response="$(curl -sS --fail-with-body "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "$payload")" || {
    echo "ollama: request failed: $response" >&2
    exit 1
  }

echo "$response" | jq -r '.message.content'
