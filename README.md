# llm-translate

English · [简体中文](./README.zh-CN.md)

A tiny, dependency-light tool for the terminal and Vim, backed by large
language models. One CLI, three tasks — **translate** text, **optimize**
code, or **bugfix** a snippet — with swappable providers (**DeepSeek**,
**OpenAI**, **Anthropic Claude**, local **Ollama**, **Aliyun Coding Plan**,
plus zero-config **MyMemory** for translation) and a Vim plugin that runs
any task on the current selection or buffer.

```text
┌────────────┐     ┌──────────────┐     ┌───────────────┐
│ vim visual │ ──▶ │ llm-translate│ ──▶ │  provider API │
│ selection  │     │    (CLI)     │     │ (deepseek/…)  │
└────────────┘     └──────────────┘     └───────────────┘
```

## Features

- **Pure bash** — only `curl` and `jq` required.
- **Multi-provider** — DeepSeek / OpenAI / Claude / Ollama / Aliyun Coding Plan / MyMemory, pick per invocation.
- **Three tasks, one pipeline** — `--task translate` (default), `--task optimize`
  for code rewrite, `--task bugfix` for edge-case defect patches.
- **Streaming-friendly CLI** — reads from stdin, writes to stdout. Pipe anything.
- **Vim plugin** — `<leader>t` / `<leader>o` / `<leader>b` run translate / optimize
  / bugfix on the visual selection. Code tasks open a two-pane diff in a fresh tab.
- **Format-preserving prompt** — code blocks, paths, identifiers, and markdown are kept intact.

## Install

`jq` and `curl` are the only runtime deps — install via your package manager
(`sudo apt install jq curl`). If you have no sudo, drop the `jq` static binary
into `~/.local/bin` from the [jq releases page](https://github.com/jqlang/jq/releases).

### One-liner (manual mode — recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/MarsDoge/llm-translate/main/install.sh | bash
```

Or, if you use [vim-plug](https://github.com/junegunn/vim-plug):

```bash
curl -fsSL https://raw.githubusercontent.com/MarsDoge/llm-translate/main/install.sh | bash -s -- --mode vim-plug
```

The installer clones the repo to `~/.local/share/llm-translate` (or
`~/.vim/plugged/llm-translate` in vim-plug mode), symlinks `llm-translate`
into `~/.local/bin`, adds it to `$PATH` if missing, and wires up your
`~/.vimrc` (and `~/.config/nvim/init.vim` if present). It's idempotent, and
`install.sh --uninstall` rolls everything back. See `install.sh --help`
for `--prefix`, `--dir`, `--skip-vim`.

### Or do it by hand — pick **one** of the two tracks below.

### Option A — Manual (one clone covers CLI + Vim)

```bash
# 1. Clone
git clone https://github.com/MarsDoge/llm-translate.git ~/.local/share/llm-translate

# 2. Expose CLI on $PATH
mkdir -p ~/.local/bin
ln -sf ~/.local/share/llm-translate/bin/llm-translate ~/.local/bin/llm-translate
chmod +x ~/.local/share/llm-translate/bin/llm-translate

# 3. Ensure ~/.local/bin is on $PATH
echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/.local/bin" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 4. Hook up Vim
echo 'set runtimepath+=~/.local/share/llm-translate' >> ~/.vimrc
```

### Option B — vim-plug (auto-updating Vim plugin)

Use this if you already manage plugins with [vim-plug](https://github.com/junegunn/vim-plug).
You still need the CLI on `$PATH` — the plugin just shells out to it.

**First time only — bootstrap vim-plug itself:**

```bash
# Vim
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Neovim
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
```

**In `~/.vimrc`:**

```vim
call plug#begin()
Plug 'MarsDoge/llm-translate'
call plug#end()
```

Open Vim and run `:PlugInstall`. Then link the CLI that the plugin just
cloned into `$PATH`:

```bash
mkdir -p ~/.local/bin
ln -sf ~/.vim/plugged/llm-translate/bin/llm-translate ~/.local/bin/llm-translate
chmod +x ~/.vim/plugged/llm-translate/bin/llm-translate
echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/.local/bin" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

For Neovim's `lazy.nvim` / `packer`, do the same `ln -sf` in a `build =`
hook; the package layout is identical.

### Verify — no API key required

```bash
echo "Hello, world!" | llm-translate -p mymemory -t "Simplified Chinese"
# → 您好，世界！
```

If you see the translation, both the CLI and `$PATH` are wired correctly.
Next, configure an LLM provider below for higher-quality translations.

## Configure

Set the API key for whichever provider you use:

```bash
export DEEPSEEK_API_KEY=sk-...
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...
export ALIYUN_CODING_PLAN_API_KEY=sk-sp-...
export OLLAMA_HOST=http://localhost:11434   # only if non-default
```

Optional defaults:

```bash
export LLM_TRANSLATE_PROVIDER=deepseek
export LLM_TRANSLATE_MODEL=deepseek-chat
export LLM_TRANSLATE_TARGET="Simplified Chinese"
```

## CLI usage

### Options

| Flag                  | Default                | Notes                                                    |
| --------------------- | ---------------------- | -------------------------------------------------------- |
| `-p`, `--provider`    | `deepseek`             | `deepseek` / `openai` / `claude` / `ollama` / `aliyun-codingplan` / `mymemory` |
| `-m`, `--model`       | provider-specific      | e.g. `deepseek-chat`, `gpt-4o-mini`; unused for mymemory |
| `-t`, `--target`      | `Simplified Chinese`   | natural name (`"Japanese"`) or ISO code (`ja-JP`)        |
| `-s`, `--source`      | `auto`                 | required for mymemory when source is not English         |
| `--task`              | `translate`            | `translate` / `optimize` / `bugfix` — LLM-only for the last two |
| `--temperature`       | `0.2`                  | LLM providers only                                       |
| `--list-providers`    | —                      | print available providers and exit                       |
| `-v`, `--version`     | —                      | print version                                            |
| `-h`, `--help`        | —                      | show help                                                |

Override defaults via env vars: `LLM_TRANSLATE_PROVIDER`, `LLM_TRANSLATE_MODEL`,
`LLM_TRANSLATE_TARGET`, `LLM_TRANSLATE_TEMPERATURE`, `LLM_TRANSLATE_TASK`.

### Examples

```bash
# translate (default task)
echo "Hello, world!" | llm-translate -t "Japanese"
llm-translate -p openai -m gpt-4o-mini < README.md
llm-translate -p aliyun-codingplan -m qwen3.5-plus --task optimize < messy.py
llm-translate -p aliyun-codingplan -m kimi-k2.5 -t English < notes.zh.md
llm-translate -p aliyun-codingplan -m glm-5 --task bugfix < buggy.go
llm-translate -p claude -t "English" < notes.zh.md > notes.en.md
llm-translate -p ollama -m qwen2.5:7b -t English < manpage.txt
echo "Hello" | llm-translate -p mymemory -t zh-CN        # no API key

# optimize: rewrite as cleaner code in the same language
llm-translate --task optimize -p deepseek < messy.py

# bugfix: patch boundary / null / off-by-one / wrong-operator defects
llm-translate --task bugfix -p deepseek < buggy.go
```

## Vim usage

Visual-select a region, then press one of the default mappings.
Translate opens the result in a split; optimize and bugfix open a **two-pane
diff in a fresh tab** (left = original, right = rewritten) so you can
`:diffget` the bits you want and `:tabclose` to drop the rest.

Default mappings (visual mode):

| Mapping       | Task       | Result window                              |
| ------------- | ---------- | ------------------------------------------ |
| `<leader>t`   | translate  | scratch split, filetype `markdown`         |
| `<leader>o`   | optimize   | new tab, two-pane diff, source filetype    |
| `<leader>b`   | bugfix     | new tab, two-pane diff, source filetype    |

Commands:

| Command                | Scope                     |
| ---------------------- | ------------------------- |
| `:LLMTranslate`        | current visual selection  |
| `:LLMTranslateBuffer`  | whole buffer              |
| `:LLMOptimize`         | current visual selection  |
| `:LLMOptimizeBuffer`   | whole buffer              |
| `:LLMBugfix`           | current visual selection  |
| `:LLMBugfixBuffer`     | whole buffer              |

Per-buffer or per-session overrides:

```vim
let g:llm_translate_provider     = 'claude'
let g:llm_translate_model        = 'claude-haiku-4-5-20251001'
let g:llm_translate_target       = 'French'
let g:llm_translate_map          = 0    " disable default <leader>t
let g:llm_translate_map_optimize = 0    " disable default <leader>o
let g:llm_translate_map_bugfix   = 0    " disable default <leader>b
```

## Providers

| Provider  | Env var             | Default model                  | Type   |
| --------- | ------------------- | ------------------------------ | ------ |
| deepseek  | `DEEPSEEK_API_KEY`  | `deepseek-chat`                | LLM    |
| openai    | `OPENAI_API_KEY`    | `gpt-4o-mini`                  | LLM    |
| claude    | `ANTHROPIC_API_KEY` | `claude-haiku-4-5-20251001`    | LLM    |
| aliyun-codingplan | `ALIYUN_CODING_PLAN_API_KEY` | `qwen3.5-plus`    | LLM    |
| ollama    | *(none — local)*    | `qwen2.5:7b`                   | LLM    |
| mymemory  | *(none — free tier)*| n/a                            | MT API |

### Aliyun Coding Plan

`aliyun-codingplan` uses Aliyun Model Studio's OpenAI-compatible Coding Plan
endpoint: `https://coding.dashscope.aliyuncs.com/v1`. The key format is
`sk-sp-...`.
The provider also accepts `CODING_PLAN_API_KEY` and
`BAILIAN_CODING_PLAN_API_KEY` as compatibility fallbacks.
Documented supported models include `qwen3.5-plus`, `kimi-k2.5`, `glm-5`,
and other Coding Plan models; pass the desired model via `-m`.
Official docs describe Coding Plan as an interactive coding-tools offering, so
use it accordingly instead of generic batch backends or unrelated API tooling.

### Zero-config fallback: MyMemory

If you just want to try the tool without signing up for anything:

```bash
echo "Hello, world!" | llm-translate -p mymemory -t "Simplified Chinese"
# → 您好，世界！
```

MyMemory is a hosted translation service with a free tier (~5000 words/day
per IP, no account). Set `MYMEMORY_EMAIL=you@example.com` to raise the daily
quota to ~50000 words. Quality is lower than LLMs, and it has no real
source-auto-detect — pass `-s` explicitly when translating non-English input.

### Language aliases

The CLI normalizes natural names and common variants to BCP 47 codes for
non-LLM providers. Any row below accepts all listed forms interchangeably:

| Aliases                                                     | Normalized |
| ----------------------------------------------------------- | ---------- |
| Simplified Chinese, Chinese, zh, zh-CN, 中文, 简体中文        | `zh-CN`    |
| Traditional Chinese, zh-TW, 繁体中文                         | `zh-TW`    |
| English, en, en-US, en-GB, 英语, 英文                         | `en-US`    |
| Japanese, ja, ja-JP, 日语, 日本語                             | `ja-JP`    |
| Korean, ko, ko-KR, 韩语, 한국어                               | `ko-KR`    |
| French, fr, fr-FR, 法语                                     | `fr-FR`    |
| German, de, de-DE, 德语                                     | `de-DE`    |
| Spanish, es, es-ES, 西班牙语                                 | `es-ES`    |
| Russian, ru, ru-RU, 俄语                                    | `ru-RU`    |
| Italian, it, it-IT, 意大利语                                 | `it-IT`    |
| Portuguese, pt, pt-PT, 葡萄牙语                              | `pt-PT`    |
| Arabic, ar, ar-SA, 阿拉伯语                                  | `ar-SA`    |

Unknown input passes through unchanged, so any provider-specific code works.

LLM providers (`deepseek` / `openai` / `claude` / `ollama`) understand any
natural-language target directly and ignore the normalization table — it
mainly matters for `mymemory` and future MT providers that need strict codes.
For pairs not in the table, pass the ISO code explicitly:

```bash
llm-translate -p mymemory -s en-US -t vi-VN < input.txt   # English → Vietnamese
```

### Adding a new provider

Adding a new provider is one file in `lib/providers/`. It receives the text on
`$LLM_TRANSLATE_INPUT` and the system prompt on `$LLM_TRANSLATE_SYSTEM` (LLMs)
or `$LLM_TRANSLATE_TARGET_CODE` / `$LLM_TRANSLATE_SOURCE_CODE` (MT APIs), and
prints the translation on stdout. See `lib/providers/deepseek.sh` or
`lib/providers/mymemory.sh` for ~30-line templates.

## Roadmap

- `--stream` for live token output in the terminal.
- Glossary / terminology files (`--glossary path.tsv`).
- Neovim Lua port with floating window UI.
- Batch mode for translating whole directories while preserving structure.
- Additional providers: Gemini, Mistral, Azure OpenAI.

Contributions welcome — open an issue or PR.

## Development

If you want to hack on the plugin or CLI, point Vim at your clone directly
instead of installing via a plugin manager — edits take effect on `:source`
without needing a commit / push / `:PlugUpdate` cycle.

```bash
git clone git@github.com:MarsDoge/llm-translate.git ~/src/llm-translate
ln -sf ~/src/llm-translate/bin/llm-translate ~/.local/bin/llm-translate
```

`~/.vimrc`:

```vim
set runtimepath+=~/src/llm-translate
let g:llm_translate_provider = 'deepseek'
```

Run shellcheck before opening a PR:

```bash
shellcheck bin/llm-translate lib/providers/*.sh
```

## License

[MIT](./LICENSE)
