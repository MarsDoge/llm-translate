# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

`llm-translate` is a **stdin → CLI dispatcher → provider backend → stdout** pipeline, plus a thin Vim plugin that shells out to the CLI.

```
stdin ─▶ bin/llm-translate ─▶ lib/providers/<name>.sh ─▶ API ─▶ stdout
                │
                └─ exports LLM_TRANSLATE_INPUT, LLM_TRANSLATE_SYSTEM,
                         LLM_TRANSLATE_MODEL, LLM_TRANSLATE_TEMPERATURE
                         then execs the chosen provider script
```

Three boundaries to respect:

1. **CLI ↔ provider contract** (`bin/llm-translate` → `lib/providers/*.sh`): the dispatcher parses flags, builds the system prompt, and passes everything via environment variables. Providers read the subset they need and write the translation to stdout — nothing else. Any new provider is a single ~30-line file in `lib/providers/` and needs no changes elsewhere; the dispatcher auto-discovers it via `--list-providers`.

   Exported env vars:
   - `LLM_TRANSLATE_INPUT` — raw user text (always set)
   - `LLM_TRANSLATE_SYSTEM` — pre-built system prompt (LLM providers)
   - `LLM_TRANSLATE_MODEL` / `LLM_TRANSLATE_TEMPERATURE` — LLM tuning
   - `LLM_TRANSLATE_TARGET_CODE` / `LLM_TRANSLATE_SOURCE_CODE` — BCP 47-ish codes for non-LLM MT APIs (e.g. `zh-CN`, `ja-JP`). The dispatcher's `normalize_lang_code()` maps natural names ("Simplified Chinese") to these codes; unknowns pass through unchanged so users can always give a raw ISO code. When adding a new MT-API provider, extend `normalize_lang_code()` only if the provider's code scheme matches mymemory's (BCP 47); providers with their own scheme (baidu uses `zh` not `zh-CN`, `jp` not `ja-JP`) should map internally.

2. **Vim plugin split** (`plugin/` vs `autoload/`): `plugin/llm-translate.vim` runs at Vim startup and only sets config defaults, `:command` definitions, and the default `<leader>t` mapping. The real implementation (`llm_translate#selection`, `llm_translate#buffer`, private helpers) lives in `autoload/llm_translate.vim` and loads lazily on first invocation. **Do not define `funcname#with#hashes` in `plugin/`** — Vim enforces that autoload-named functions live in `autoload/<prefix>.vim` and throws `E746` otherwise (fixed in 657b73f; easy to re-break).

3. **Vim ↔ CLI boundary**: the plugin constructs a shell command via `shellescape()` and pipes the selection through `system(cmd, text)`. If `$PATH` is different inside Vim from the shell, users must set `g:llm_translate_cmd` to the absolute path — do not try to hardcode paths in the plugin.

## Hard portability constraints

- **Only `bash`, `curl`, `jq`** are allowed as runtime dependencies. The value proposition is "no Python, no Node, runs on any Linux box." Don't reach for `python -c 'json.loads(...)'` or similar.
- **`curl --fail-with-body` is banned** — it's curl 7.76+ (2021) and breaks on LTS/enterprise distros. Use the `mktemp` + `-o` + `-w '%{http_code}'` pattern already in every provider (see `lib/providers/deepseek.sh:29-42` as the reference template). Applies to any new provider.
- **`jq --arg` / `--argjson` for all JSON construction** — never string-concatenate JSON bodies. User text routinely contains quotes, backslashes, and newlines that would break naive interpolation.

## Common commands

```bash
# Syntax-check everything (no network)
bash -n bin/llm-translate
bash -n lib/providers/*.sh

# Lint (same config as CI — see .github/workflows/shellcheck.yml)
shellcheck bin/llm-translate lib/providers/*.sh

# End-to-end smoke test (requires the corresponding API key env var)
echo "Hello, world." | ./bin/llm-translate -p deepseek -t "Japanese"
./bin/llm-translate --list-providers   # discovers lib/providers/*.sh

# Vim plugin verification (no live API)
vim -N -u NONE -i NONE --cmd 'set runtimepath+=.' \
    --cmd 'runtime! plugin/llm-translate.vim' \
    --cmd 'runtime! autoload/llm_translate.vim' \
    -c 'echo exists("*llm_translate#selection")' -c 'qa!'
# Expect: 1
```

## Adding a new provider

Copy `lib/providers/deepseek.sh`, adjust:

1. The required env-var guard at the top (`: "${XXX_API_KEY:?...}"`).
2. `MODEL` default, `ENDPOINT`, and request headers.
3. The final `jq -r '...'` selector to match the provider's response schema (e.g. OpenAI uses `.choices[0].message.content`, Anthropic uses `.content[0].text`, Ollama uses `.message.content`).

Keep the `mktemp` + `http_code` block intact — that's the portable error-handling pattern. Make the file executable (`chmod +x`). The CLI picks it up with no other wiring; `--list-providers` will show it automatically.

## Release flow

- Single `main` branch, push directly (solo maintainer).
- Bump `VERSION` in `bin/llm-translate` when cutting a tagged release.
- CI is `shellcheck` on push/PR only — there are no unit tests, so local smoke-testing against at least one provider before pushing is the real gate.
