#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
cd "$ROOT_DIR"

START_MARKER='<!-- ARCHITECTURE_MERMAID:START -->'
END_MARKER='<!-- ARCHITECTURE_MERMAID:END -->'
ARCHITECTURE_DOC='docs/architecture.md'
ARCHITECTURE_DOC_ZH='docs/architecture.zh-CN.md'

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
  local group_id="$1"
  local title="$2"
  shift 2
  local providers=("$@")
  [ "${#providers[@]}" -gt 0 ] || return 0

  printf '  subgraph %s["%s"]\n' "$group_id" "$title"
  local provider provider_id
  for provider in "${providers[@]}"; do
    provider_id="${group_id}_$(node_id "$provider")"
    printf '    %s["lib/providers/%s.sh"]\n' "$provider_id" "$provider"
  done
  printf '  end\n'
}

print_edges() {
  local source="$1"
  local group_id="$2"
  shift 2
  local providers=("$@")
  local provider provider_id
  for provider in "${providers[@]}"; do
    provider_id="${group_id}_$(node_id "$provider")"
    printf '  %s --> %s\n' "$source" "$provider_id"
  done
}

generate_mermaid_block() {
  local terminal_label input_label plugin_label autoload_label mac_input_label mac_app_label speech_label
  local cli_label compat_label
  local direct_title compat_title local_title mt_title
  local direct_id='direct'
  local compat_id='compat_group'
  local local_id='local'
  local mt_id='translation'
  local locale="${1:-en}"

  classify_providers

  case "$locale" in
    zh)
      terminal_label='终端 stdin / 管线'
      input_label='Vim 可视选区 / 整个 buffer'
      plugin_label='plugin/llm-translate.vim\n命令与映射'
      autoload_label='autoload/llm_translate.vim\n选区 / buffer 执行入口'
      mac_input_label='macOS 选中文字\n任意 app'
      mac_app_label='macos/LLMTranslateMac\nSwift 菜单栏 app\ntranslate | speak'
      speech_label='macOS NSSpeechSynthesizer\n系统文本转语音'
      cli_label='bin/llm-translate\n任务分发\ntranslate | optimize | bugfix'
      compat_label='lib/openai_compat.sh\n共享 chat-completions helper'
      direct_title='直连 provider 脚本'
      compat_title='OpenAI 兼容 provider 脚本'
      local_title='本地推理'
      mt_title='翻译 API'
      ;;
    *)
      terminal_label='Terminal stdin / pipe'
      input_label='Vim selection / whole buffer'
      plugin_label='plugin/llm-translate.vim\ncommands + mappings'
      autoload_label='autoload/llm_translate.vim\nselection / buffer runners'
      mac_input_label='macOS selected text\nany app'
      mac_app_label='macos/LLMTranslateMac\nSwift menu-bar app\ntranslate | speak'
      speech_label='macOS NSSpeechSynthesizer\nsystem text-to-speech'
      cli_label='bin/llm-translate\ntask dispatcher\ntranslate | optimize | bugfix'
      compat_label='lib/openai_compat.sh\nshared chat-completions helper'
      direct_title='Direct provider scripts'
      compat_title='OpenAI-compatible provider scripts'
      local_title='Local inference'
      mt_title='Translation API'
      ;;
  esac

  printf '%s\n' '```mermaid'
  printf '%s\n' 'flowchart LR'
  printf '  Terminal["%s"]\n' "$terminal_label"
  printf '  Input["%s"]\n' "$input_label"
  printf '  Plugin["%s"]\n' "$plugin_label"
  printf '  Autoload["%s"]\n' "$autoload_label"
  printf '  MacInput["%s"]\n' "$mac_input_label"
  printf '  MacApp["%s"]\n' "$mac_app_label"
  printf '  Speech["%s"]\n' "$speech_label"
  printf '  CLI["%s"]\n' "$cli_label"

  if [ "${#compat_providers[@]}" -gt 0 ]; then
    printf '  Compat["%s"]\n' "$compat_label"
  fi

  printf '  Terminal --> CLI\n'
  printf '  Input --> Plugin --> Autoload --> CLI\n'
  printf '  MacInput --> MacApp --> CLI\n'
  printf '  MacApp --> Speech\n'
  print_group "$direct_id" "$direct_title" "${direct_providers[@]}"
  print_group "$compat_id" "$compat_title" "${compat_providers[@]}"
  print_group "$local_id" "$local_title" "${local_providers[@]}"
  print_group "$mt_id" "$mt_title" "${mt_providers[@]}"

  if [ "${#compat_providers[@]}" -gt 0 ]; then
    printf '  CLI --> Compat\n'
  fi
  print_edges "CLI" "$direct_id" "${direct_providers[@]}"
  print_edges "CLI" "$local_id" "${local_providers[@]}"
  print_edges "CLI" "$mt_id" "${mt_providers[@]}"
  if [ "${#compat_providers[@]}" -gt 0 ]; then
    print_edges "Compat" "$compat_id" "${compat_providers[@]}"
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
  local block_file block_file_zh
  block_file="$(mktemp)"
  block_file_zh="$(mktemp)"

  generate_mermaid_block > "$block_file"
  generate_mermaid_block "zh" > "$block_file_zh"

  case "${1:-}" in
    --stdout)
      cat "$block_file"
      ;;
    --stdout-zh)
      cat "$block_file_zh"
      ;;
    "")
      replace_block "$ARCHITECTURE_DOC" "$block_file"
      replace_block "$ARCHITECTURE_DOC_ZH" "$block_file_zh"
      ;;
    *)
      echo "usage: $0 [--stdout|--stdout-zh]" >&2
      rm -f "$block_file"
      rm -f "$block_file_zh"
      exit 1
      ;;
  esac

  rm -f "$block_file"
  rm -f "$block_file_zh"
}

main "$@"
