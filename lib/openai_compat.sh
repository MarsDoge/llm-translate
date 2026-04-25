#!/usr/bin/env bash
# Shared implementation for OpenAI-compatible chat-completions providers.
#
# Provider scripts call:
#   llm_translate_openai_compat <endpoint> <auth_header> <model> <label>
#
# The endpoint is the full URL ending in /chat/completions. auth_header is
# the full header line, e.g. "Authorization: Bearer $KEY". label is a short
# identifier used in error messages.

# shellcheck shell=bash

# shellcheck source=stream.sh
OPENAI_COMPAT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck disable=SC1091
. "$OPENAI_COMPAT_DIR/stream.sh"

llm_translate_openai_compat() {
  local endpoint="$1"
  local auth_header="$2"
  local model="$3"
  local label="${4:-provider}"
  local temp="${LLM_TRANSLATE_TEMPERATURE:-0.2}"
  local stream="${LLM_TRANSLATE_STREAM:-0}"

  local payload
  payload="$(jq -n \
    --arg model  "$model" \
    --arg system "$LLM_TRANSLATE_SYSTEM" \
    --arg user   "$LLM_TRANSLATE_INPUT" \
    --argjson temp "$temp" \
    --argjson stream "$([ "$stream" = "1" ] && echo true || echo false)" \
    '{
      model: $model,
      messages: [
        {role: "system", content: $system},
        {role: "user",   content: $user}
      ],
      temperature: $temp,
      stream: $stream
    }')"

  if [ "$stream" = "1" ]; then
    set -o pipefail
    curl -sS -N "$endpoint" \
      -H "$auth_header" \
      -H "Content-Type: application/json" \
      -H "Accept: text/event-stream" \
      -d "$payload" \
      | llm_translate_stream_openai_sse "$label"
    return $?
  fi

  local body_file
  body_file="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$body_file'" EXIT

  local http_code
  http_code="$(curl -sS -o "$body_file" -w '%{http_code}' "$endpoint" \
    -H "$auth_header" \
    -H "Content-Type: application/json" \
    -d "$payload")" || {
      echo "$label: curl failed: $(cat "$body_file")" >&2
      return 1
    }

  if [ "$http_code" -ge 400 ]; then
    echo "$label: HTTP $http_code: $(cat "$body_file")" >&2
    return 1
  fi

  jq -r '.choices[0].message.content' < "$body_file"
}
