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

```bash
git clone https://github.com/MarsDoge/llm-translate.git ~/.local/share/llm-translate
ln -s ~/.local/share/llm-translate/bin/llm-translate ~/.local/bin/llm-translate
chmod +x ~/.local/share/llm-translate/bin/llm-translate
```

Make sure `~/.local/bin` is on your `$PATH`.

### Vim / Neovim plugin

With [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'MarsDoge/llm-translate'
```

Or point directly at the cloned directory:

```vim
set runtimepath+=~/.local/share/llm-translate
```

Neovim's `packer`, `lazy.nvim`, and friends all work the same way.

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

| Provider  | Env var             | Default model                  |
| --------- | ------------------- | ------------------------------ |
| deepseek  | `DEEPSEEK_API_KEY`  | `deepseek-chat`                |
| openai    | `OPENAI_API_KEY`    | `gpt-4o-mini`                  |
| claude    | `ANTHROPIC_API_KEY` | `claude-haiku-4-5-20251001`    |
| ollama    | *(none — local)*    | `qwen2.5:7b`                   |

Adding a new provider is one file in `lib/providers/`. It receives the text on
`$LLM_TRANSLATE_INPUT` and the system prompt on `$LLM_TRANSLATE_SYSTEM`, and
prints the translation on stdout. See `lib/providers/deepseek.sh` for a ~30-line
template.

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
