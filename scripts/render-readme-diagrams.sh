#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
cd "$ROOT_DIR"

START_MARKER='<!-- ARCHITECTURE_MERMAID:START -->'
END_MARKER='<!-- ARCHITECTURE_MERMAID:END -->'
ARCHITECTURE_DOC='docs/architecture.md'

node_id() {
  printf '%s' "$1" | tr -c '[:alnum:]' '_'
}

classify_providers() {
  compat_providers=()
  direct_providers=()
  local_providers=()
  mt_providers=()

  local provider_file provider
  for provider_file in lib/providers/*.sh; do
    provider="$(basename "$provider_file" .sh)"
    if grep -q 'llm_translate_openai_compat' "$provider_file"; then
      compat_providers+=("$provider")
    elif [ "$provider" = "ollama" ]; then
      local_providers+=("$provider")
    elif [ "$provider" = "mymemory" ]; then
      mt_providers+=("$provider")
    else
      direct_providers+=("$provider")
    fi
  done
}

print_group() {
  local title="$1"
  shift
  local providers=("$@")
  [ "${#providers[@]}" -gt 0 ] || return 0

  printf '  subgraph %s["%s"]\n' "$(node_id "$title")" "$title"
  local provider provider_id
  for provider in "${providers[@]}"; do
    provider_id="$(node_id "$title")_$(node_id "$provider")"
    printf '    %s["lib/providers/%s.sh"]\n' "$provider_id" "$provider"
  done
  printf '  end\n'
}

print_edges() {
  local source="$1"
  shift
  local title="$1"
  shift
  local providers=("$@")
  local provider provider_id
  for provider in "${providers[@]}"; do
    provider_id="$(node_id "$title")_$(node_id "$provider")"
    printf '  %s --> %s\n' "$source" "$provider_id"
  done
}

generate_mermaid_block() {
  classify_providers
  local input_label plugin_label autoload_label cli_label compat_label
  local direct_title compat_title local_title mt_title

  input_label='Vim selection / whole buffer'
  plugin_label='plugin/llm-translate.vim\ncommands + mappings'
  autoload_label='autoload/llm_translate.vim\nselection / buffer runners'
  cli_label='bin/llm-translate\ntask dispatcher\ntranslate | optimize | bugfix'
  compat_label='lib/openai_compat.sh\nshared chat-completions helper'
  direct_title='Direct provider scripts'
  compat_title='OpenAI-compatible provider scripts'
  local_title='Local inference'
  mt_title='Translation API'

  printf '%s\n' '```mermaid'
  printf '%s\n' 'flowchart LR'
  printf '  Input["%s"]\n' "$input_label"
  printf '  Plugin["%s"]\n' "$plugin_label"
  printf '  Autoload["%s"]\n' "$autoload_label"
  printf '  CLI["%s"]\n' "$cli_label"

  if [ "${#compat_providers[@]}" -gt 0 ]; then
    printf '  Compat["%s"]\n' "$compat_label"
  fi

  printf '  Input --> Plugin --> Autoload --> CLI\n'
  print_group "$direct_title" "${direct_providers[@]}"
  print_group "$compat_title" "${compat_providers[@]}"
  print_group "$local_title" "${local_providers[@]}"
  print_group "$mt_title" "${mt_providers[@]}"

  if [ "${#compat_providers[@]}" -gt 0 ]; then
    printf '  CLI --> Compat\n'
  fi
  print_edges "CLI" "$direct_title" "${direct_providers[@]}"
  print_edges "CLI" "$local_title" "${local_providers[@]}"
  print_edges "CLI" "$mt_title" "${mt_providers[@]}"
  if [ "${#compat_providers[@]}" -gt 0 ]; then
    print_edges "Compat" "$compat_title" "${compat_providers[@]}"
  fi

  printf '```\n'
}

replace_block() {
  local target_file="$1"
  local block_file="$2"
  local tmp_file skip marker_found

  tmp_file="$(mktemp)"
  skip=0
  marker_found=0

  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "$START_MARKER" ]; then
      marker_found=1
      skip=1
      printf '%s\n' "$line" >> "$tmp_file"
      cat "$block_file" >> "$tmp_file"
      continue
    fi

    if [ "$line" = "$END_MARKER" ]; then
      skip=0
      printf '%s\n' "$line" >> "$tmp_file"
      continue
    fi

    if [ "$skip" -eq 0 ]; then
      printf '%s\n' "$line" >> "$tmp_file"
    fi
  done < "$target_file"

  if [ "$marker_found" -ne 1 ]; then
    rm -f "$tmp_file"
    echo "missing marker in $target_file: $START_MARKER" >&2
    exit 1
  fi

  mv "$tmp_file" "$target_file"
}

main() {
  local block_file
  block_file="$(mktemp)"

  generate_mermaid_block > "$block_file"

  case "${1:-}" in
    --stdout)
      cat "$block_file"
      ;;
    "")
      replace_block "$ARCHITECTURE_DOC" "$block_file"
      ;;
    *)
      echo "usage: $0 [--stdout]" >&2
      rm -f "$block_file"
      exit 1
      ;;
  esac

  rm -f "$block_file"
}

main "$@"
