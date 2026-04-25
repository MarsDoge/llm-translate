#!/usr/bin/env bash
# Ollama provider — https://ollama.com (local inference)
# llm-translate-stream: yes
set -euo pipefail

: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_SYSTEM:?missing system prompt}"

MODEL="${LLM_TRANSLATE_MODEL:-qwen2.5:7b}"
[ -n "$MODEL" ] || MODEL="qwen2.5:7b"
HOST="${OLLAMA_HOST:-http://localhost:11434}"
ENDPOINT="$HOST/api/chat"
TEMPERATURE="${LLM_TRANSLATE_TEMPERATURE:-0.2}"
STREAM="${LLM_TRANSLATE_STREAM:-0}"

payload="$(jq -n \
  --arg model  "$MODEL" \
  --arg system "$LLM_TRANSLATE_SYSTEM" \
  --arg user   "$LLM_TRANSLATE_INPUT" \
  --argjson temp "$TEMPERATURE" \
  --argjson stream "$([ "$STREAM" = "1" ] && echo true || echo false)" \
  '{
    model: $model,
    stream: $stream,
    options: { temperature: $temp },
    messages: [
      {role: "system", content: $system},
      {role: "user",   content: $user}
    ]
  }')"

if [ "$STREAM" = "1" ]; then
  # shellcheck source=../stream.sh
  PROVIDER_DIR="$(cd -P "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
  # shellcheck disable=SC1091
  . "$PROVIDER_DIR/../stream.sh"
  set -o pipefail
  curl -sS -N "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    | llm_translate_stream_ollama_ndjson "ollama"
  exit $?
fi

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
