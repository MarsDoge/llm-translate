#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -P "$(dirname "$0")/.." >/dev/null 2>&1 && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/curl" <<'FAKE_CURL'
#!/usr/bin/env bash
set -euo pipefail
payload=''
endpoint=''
headers=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -d)
      shift
      payload="$1"
      ;;
    -H)
      shift
      headers="${headers}${1}
"
      ;;
    http://*|https://*)
      endpoint="$1"
      ;;
  esac
  shift || true
done
printf '%s' "$endpoint" >"$CODEX_RESPONSES_ENDPOINT_FILE"
printf '%s' "$headers" >"$CODEX_RESPONSES_HEADERS_FILE"
printf '%s' "$payload" >"$CODEX_RESPONSES_PAYLOAD_FILE"
printf '%s\n' 'event: response.output_text.delta'
printf '%s\n' 'data: {"type":"response.output_text.delta","delta":"你"}'
printf '%s\n' ''
printf '%s\n' 'data: {"delta":"好"}'
printf '%s\n' ''
printf '%s\n' 'data: {"text":"！"}'
printf '%s\n' ''
printf '%s\n' 'data: [DONE]'
FAKE_CURL
chmod +x "$tmp_dir/curl"

export PATH="$tmp_dir:$PATH"
export CODEX_RESPONSES_ENDPOINT_FILE="$tmp_dir/endpoint"
export CODEX_RESPONSES_HEADERS_FILE="$tmp_dir/headers"
export CODEX_RESPONSES_PAYLOAD_FILE="$tmp_dir/payload"
export OPENAI_API_KEY='test-key-not-secret'
export LLM_TRANSLATE_SYSTEM='Translate to Chinese.'
export LLM_TRANSLATE_INPUT='Hello.'
unset OPENAI_API_BASE LLM_TRANSLATE_MODEL

[ -x "$repo_dir/lib/providers/codex-responses.sh" ]

output="$("$repo_dir"/lib/providers/codex-responses.sh)"
[ "$output" = '你好！' ]
[ "$(cat "$CODEX_RESPONSES_ENDPOINT_FILE")" = 'https://api.dogexorg.com/v1/responses' ]
grep -qx 'Authorization: Bearer test-key-not-secret' "$CODEX_RESPONSES_HEADERS_FILE"
grep -qx 'Accept: text/event-stream' "$CODEX_RESPONSES_HEADERS_FILE"

jq -e '
  .model == "gpt-5.5" and
  .stream == true and
  .input[0].role == "system" and
  .input[0].content[0].type == "input_text" and
  .input[0].content[0].text == "Translate to Chinese." and
  .input[1].role == "user" and
  .input[1].content[0].type == "input_text" and
  .input[1].content[0].text == "Hello."
' "$CODEX_RESPONSES_PAYLOAD_FILE" >/dev/null

"$repo_dir/bin/llm-translate" --list-providers | grep -qx 'codex-responses'
