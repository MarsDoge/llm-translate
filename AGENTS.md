# Repository Guidelines

## Project Structure & Module Organization

`bin/llm-translate` is the main Bash CLI entrypoint. Provider backends live in `lib/providers/*.sh`; each provider is a small executable script that reads environment variables and writes only the result to stdout. Shared OpenAI-compatible request logic lives in `lib/openai_compat.sh`. Vim integration is split between `plugin/llm-translate.vim` for startup-time commands and mappings, and `autoload/llm_translate.vim` for lazy-loaded implementation. Repository docs live in `README.md`, `README.zh-CN.md`, `CHANGELOG.md`, and `.github/workflows/`.

## Build, Test, and Development Commands

Run syntax checks before anything else:

```bash
bash -n bin/llm-translate
bash -n lib/providers/*.sh
```

Lint with the same tool used in CI:

```bash
shellcheck bin/llm-translate lib/providers/*.sh
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

## Coding Style & Naming Conventions

Use Bash throughout; do not add Python or Node runtime dependencies. Prefer portable shell patterns compatible with older distro `curl` versions; avoid `curl --fail-with-body`. Build JSON with `jq --arg` / `--argjson`, never string concatenation. Keep provider scripts small and executable, named `lib/providers/<provider>.sh`. Vim autoload functions must stay in `autoload/llm_translate.vim`; do not define `llm_translate#...` functions under `plugin/`.

## Testing Guidelines

There is no unit-test suite yet, so contributors should rely on `bash -n`, `shellcheck`, and one end-to-end smoke test for any changed provider or task path. For provider additions, verify `--list-providers` discovers the new script and confirm one real request when credentials are available.

## Commit & Pull Request Guidelines

Recent history uses Conventional Commit style such as `feat: ...`, `fix(cli): ...`, and `docs(readme): ...`. Keep subjects imperative and scoped when useful. PRs should explain user-visible behavior, list verification commands run, and link the relevant issue. Include screenshots or terminal/Vim output when changing UX, mappings, or install flow.
