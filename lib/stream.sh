#!/usr/bin/env bash
# Streaming response parsers for LLM providers.
#
# Three wire formats are handled:
#   * OpenAI-compatible Chat Completions SSE (deepseek, openai, doubao, grok,
#     kimi, mistral, qwen, zhipu, aliyun-codingplan)
#   * Anthropic Messages SSE (claude)
#   * Ollama NDJSON (ollama)
#
# Each helper reads the raw HTTP body from stdin and writes only the model's
# text output to stdout, one delta at a time. They return non-zero if the
# response produced no content deltas and contained error-shaped bytes.

# shellcheck shell=bash

# OpenAI-compatible Chat Completions SSE.
#   data: {"choices":[{"delta":{"content":"..."}}]}
#   data: [DONE]
llm_translate_stream_openai_sse() {
  local label="${1:-provider}"
  local line data content got=0 err=''
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      'data: [DONE]') break ;;
      'data: '*)
        data="${line#data: }"
        content="$(printf '%s' "$data" | jq -j '.choices[0].delta.content // empty' 2>/dev/null || true)"
        if [ -n "$content" ]; then
          printf '%s' "$content"
          got=1
        fi
        ;;
      ''|:*|event:*) ;;
      *) err+="$line"$'\n' ;;
    esac
  done
  if [ "$got" -eq 0 ] && [ -n "$err" ]; then
    printf '%s: %s' "$label" "$err" >&2
    return 1
  fi
  printf '\n'
}

# Anthropic Messages SSE. Content lives in content_block_delta events:
#   event: content_block_delta
#   data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"..."}}
llm_translate_stream_anthropic_sse() {
  local label="${1:-claude}"
  local line data content got=0 err=''
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      'data: '*)
        data="${line#data: }"
        content="$(printf '%s' "$data" \
          | jq -j 'if .type=="content_block_delta" then (.delta.text // "") else empty end' \
            2>/dev/null || true)"
        if [ -n "$content" ]; then
          printf '%s' "$content"
          got=1
        fi
        ;;
      ''|:*|event:*) ;;
      *) err+="$line"$'\n' ;;
    esac
  done
  if [ "$got" -eq 0 ] && [ -n "$err" ]; then
    printf '%s: %s' "$label" "$err" >&2
    return 1
  fi
  printf '\n'
}

# Ollama NDJSON. Each line is a JSON object:
#   {"message":{"content":"..."},"done":false}
#   {"error":"..."}
llm_translate_stream_ollama_ndjson() {
  local label="${1:-ollama}"
  local line content err='' got=0
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    content="$(printf '%s' "$line" | jq -j '.message.content // empty' 2>/dev/null || true)"
    if [ -n "$content" ]; then
      printf '%s' "$content"
      got=1
    fi
    if [ "$got" -eq 0 ]; then
      local e
      e="$(printf '%s' "$line" | jq -r '.error // empty' 2>/dev/null || true)"
      [ -n "$e" ] && err="$e"
    fi
  done
  if [ "$got" -eq 0 ] && [ -n "$err" ]; then
    printf '%s: %s\n' "$label" "$err" >&2
    return 1
  fi
  printf '\n'
}
