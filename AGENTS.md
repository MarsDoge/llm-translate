# Repository Guidelines

## Project Structure & Module Organization

`bin/llm-translate` is the main Bash CLI entrypoint. Provider backends live in `lib/providers/*.sh`; each provider is a small executable script that reads environment variables and writes only the result to stdout. Shared OpenAI-compatible request logic lives in `lib/openai_compat.sh`. Vim integration is split between `plugin/llm-translate.vim` for startup-time commands and mappings, and `autoload/llm_translate.vim` for lazy-loaded implementation. The macOS menu-bar app lives in `macos/LLMTranslateMac/` as a SwiftPM AppKit target; it shells out to the CLI for translation and uses macOS speech synthesis for speaking selected text. Repository docs live in `README.md`, `README.zh-CN.md`, `docs/`, `CHANGELOG.md`, and `.github/workflows/`.

## Build, Test, and Development Commands

Run syntax checks before anything else:

```bash
bash -n bin/llm-translate
bash -n install.sh scripts/render-readme-diagrams.sh linux/install-desktop.sh linux/llm-translate-linux lib/openai_compat.sh lib/providers/*.sh
```

Lint with the same tool used in CI:

```bash
shellcheck bin/llm-translate install.sh scripts/render-readme-diagrams.sh linux/install-desktop.sh linux/llm-translate-linux lib/openai_compat.sh lib/providers/*.sh macos/LLMTranslateMac/scripts/build-app.sh
```

Smoke-test the CLI locally:

```bash
echo "Hello" | ./bin/llm-translate -p mymemory -t zh-CN
./bin/llm-translate --list-providers
```

Verify Vim autoload wiring without calling an API:

```bash
vim -N -u NONE -i NONE --cmd 'set runtimepath+=.' --cmd 'runtime! plugin/llm-translate.vim' --cmd 'runtime! autoload/llm_translate.vim' -c 'echo exists("*llm_translate#selection")' -c 'qa!'
```

Build the macOS app after touching `macos/LLMTranslateMac/`:

```bash
cd macos/LLMTranslateMac
swift build
./scripts/build-app.sh
```

Build the Linux GTK app after touching `linux/LLMTranslateLinux/`:

```bash
cd linux/LLMTranslateLinux
make
```

## Coding Style & Naming Conventions

Keep the core CLI and provider layer in Bash; do not add Python or Node runtime dependencies. Prefer portable shell patterns compatible with macOS and older distro `curl` versions; avoid GNU-only assumptions such as `readlink -f` or `find -printf`, and avoid `curl --fail-with-body`. Build JSON with `jq --arg` / `--argjson`, never string concatenation. Keep provider scripts small and executable, named `lib/providers/<provider>.sh`. Vim autoload functions must stay in `autoload/llm_translate.vim`; do not define `llm_translate#...` functions under `plugin/`. Keep macOS app code in `macos/LLMTranslateMac/` using Swift/AppKit, and do not duplicate provider logic there; call the existing CLI instead.

## Testing Guidelines

There is no unit-test suite yet, so contributors should rely on `bash -n`, `shellcheck`, and one end-to-end smoke test for any changed provider or task path. For provider additions, verify `--list-providers` discovers the new script and confirm one real request when credentials are available. For macOS changes, run `swift build`; run `./scripts/build-app.sh` when packaging, but do not commit `.build/` or `dist/` outputs.

## Commit & Pull Request Guidelines

Recent history uses Conventional Commit style such as `feat: ...`, `fix(cli): ...`, and `docs(readme): ...`. Keep subjects imperative and scoped when useful. PRs should explain user-visible behavior, list verification commands run, and link the relevant issue. Include screenshots or terminal/Vim output when changing UX, mappings, or install flow.
