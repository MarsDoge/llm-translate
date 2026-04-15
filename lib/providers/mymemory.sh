#!/usr/bin/env bash
# MyMemory provider — https://mymemory.translated.net
# Zero-config fallback: no API key required. Free tier allows ~5000 words/day
# per IP; set MYMEMORY_EMAIL to raise the quota to ~50000 words/day.
set -euo pipefail

: "${LLM_TRANSLATE_INPUT:?missing input}"
: "${LLM_TRANSLATE_TARGET_CODE:?missing target code; pass -t as ISO (e.g. zh-CN)}"

TARGET="$LLM_TRANSLATE_TARGET_CODE"
SOURCE="${LLM_TRANSLATE_SOURCE_CODE:-auto}"

# MyMemory has no real auto-detect; default to English as source. Users
# translating from non-English should pass -s explicitly.
if [ "$SOURCE" = "auto" ]; then
  SOURCE="en-GB"
fi

if [ "$SOURCE" = "$TARGET" ]; then
  echo "mymemory: source and target are both '$TARGET'; pass -s to set source" >&2
  exit 1
fi

ENDPOINT="${MYMEMORY_API_BASE:-https://api.mymemory.translated.net}/get"

body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT

# -G + --data-urlencode safely encodes q (including newlines, quotes, CJK)
# and appends params to the URL as a query string.
curl_args=(-sS -G -o "$body_file" -w '%{http_code}' "$ENDPOINT"
  --data-urlencode "q=$LLM_TRANSLATE_INPUT"
  --data-urlencode "langpair=${SOURCE}|${TARGET}")
if [ -n "${MYMEMORY_EMAIL:-}" ]; then
  curl_args+=(--data-urlencode "de=$MYMEMORY_EMAIL")
fi

http_code="$(curl "${curl_args[@]}")" || {
  echo "mymemory: curl failed: $(cat "$body_file")" >&2
  exit 1
}

if [ "$http_code" -ge 400 ]; then
  echo "mymemory: HTTP $http_code: $(cat "$body_file")" >&2
  exit 1
fi

# Even on HTTP 200, MyMemory may return a JSON-level error (bad langpair, quota).
status="$(jq -r '.responseStatus // empty' < "$body_file")"
if [ "$status" != "200" ]; then
  detail="$(jq -r '.responseDetails // "unknown error"' < "$body_file")"
  echo "mymemory: API error (status=$status): $detail" >&2
  exit 1
fi

jq -r '.responseData.translatedText' < "$body_file"
