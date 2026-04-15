# llm-translate

A tiny, dependency-light translation tool for the terminal and Vim, backed by
large language models. One CLI, swappable providers — **DeepSeek**, **OpenAI**,
**Anthropic Claude**, and local **Ollama** — with a Vim plugin that translates
the current selection or buffer into a split window.

```text
┌────────────┐     ┌──────────────┐     ┌───────────────┐
│ vim visual │ ──▶ │ llm-translate│ ──▶ │  provider API │
│ selection  │     │    (CLI)     │     │ (deepseek/…)  │
└────────────┘     └──────────────┘     └───────────────┘
```

## Features

- **Pure bash** — only `curl` and `jq` required.
- **Multi-provider** — DeepSeek / OpenAI / Claude / Ollama, pick per invocation.
- **Streaming-friendly CLI** — reads from stdin, writes to stdout. Pipe anything.
- **Vim plugin** — `<leader>t` on a visual selection opens the translation in a split.
- **Format-preserving prompt** — code blocks, paths, identifiers, and markdown are kept intact.

## Install

`jq` and `curl` are the only runtime deps — install via your package manager
(`sudo apt install jq curl`). If you have no sudo, drop the `jq` static binary
into `~/.local/bin` from the [jq releases page](https://github.com/jqlang/jq/releases).

Then pick **one** of the two tracks below.

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
export OLLAMA_HOST=http://localhost:11434   # only if non-default
```

Optional defaults:

```bash
export LLM_TRANSLATE_PROVIDER=deepseek
export LLM_TRANSLATE_MODEL=deepseek-chat
export LLM_TRANSLATE_TARGET="Simplified Chinese"
```

## CLI usage

```bash
echo "Hello, world!" | llm-translate -t "Japanese"

llm-translate -p openai -m gpt-4o-mini < README.md

llm-translate -p claude -t "English" < notes.zh.md > notes.en.md

llm-translate -p ollama -m qwen2.5:7b -t English < manpage.txt
```

Full option list: `llm-translate --help`.

## Vim usage

Visual-select a region, then press `<leader>t` (default mapping). The translated
text opens in a scratch split with filetype `markdown`.

Commands:

| Command               | Scope                     |
| --------------------- | ------------------------- |
| `:LLMTranslate`       | current visual selection  |
| `:LLMTranslateBuffer` | whole buffer              |

Per-buffer or per-session overrides:

```vim
let g:llm_translate_provider = 'claude'
let g:llm_translate_model    = 'claude-haiku-4-5-20251001'
let g:llm_translate_target   = 'French'
let g:llm_translate_map      = 0    " disable default <leader>t
```

## Providers

| Provider  | Env var             | Default model                  | Type   |
| --------- | ------------------- | ------------------------------ | ------ |
| deepseek  | `DEEPSEEK_API_KEY`  | `deepseek-chat`                | LLM    |
| openai    | `OPENAI_API_KEY`    | `gpt-4o-mini`                  | LLM    |
| claude    | `ANTHROPIC_API_KEY` | `claude-haiku-4-5-20251001`    | LLM    |
| ollama    | *(none — local)*    | `qwen2.5:7b`                   | LLM    |
| mymemory  | *(none — free tier)*| n/a                            | MT API |

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

### Language codes

LLM providers accept natural-language targets (`-t "Japanese"`), but hosted
MT providers like MyMemory need BCP 47 codes (`-t ja-JP`). The CLI maps ~12
common names automatically — both of these work:

```bash
llm-translate -p mymemory -t "Simplified Chinese" < input.txt
llm-translate -p mymemory -t zh-CN               < input.txt
```

Unknown languages pass through unchanged, so you can always provide the exact
code the provider expects.

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
