# LLMTranslateMac

[简体中文](./README.zh-CN.md) · English

macOS menu-bar MVP for translating or speaking selected text from any app.

It reuses the repository CLI (`bin/llm-translate`) instead of duplicating provider logic:

- `Option + Command + T`: copy the current selection, translate it, and show the result in a floating panel.
- `Option + Command + S`: copy the current selection and speak it with macOS speech synthesis.
- `Source Language` menu: keep source auto-detection or specify it manually for non-LLM providers such as MyMemory.
- `Target Language` menu: temporarily switch the app translation target without editing config files.
- `Show Version`: show the macOS app and underlying CLI versions.

The app restores the previous clipboard contents after reading the selection.

## Run

Install the CLI runtime dependencies first:

```bash
brew install jq curl
```

```bash
cd macos/LLMTranslateMac
swift run
```

On first use, macOS will ask for Accessibility permission. Enable the built executable in:

```text
System Settings > Privacy & Security > Accessibility
```

## Build an App Bundle

```bash
cd macos/LLMTranslateMac
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open dist/LLMTranslateMac.app
```

For a stable Accessibility permission entry, install and run the app from a fixed path:

```bash
./scripts/build-app.sh --install
open /Applications/LLMTranslateMac.app
```

When upgrading, rebuild with `--install` again so the app stays at the same path.

## Translation Provider

The app inherits the same environment variables as `llm-translate`.

For zero-configuration smoke tests it uses `mymemory` when neither `LLM_TRANSLATE_PROVIDER` nor `DEEPSEEK_API_KEY` is set. For better quality, configure a provider before launching:

```bash
export LLM_TRANSLATE_PROVIDER=openai
export OPENAI_API_KEY=sk-...
export LLM_TRANSLATE_MODEL=gpt-4o-mini
export LLM_TRANSLATE_TARGET="Simplified Chinese"
swift run
```

For a double-clicked `.app`, shell exports may not be visible. Put the same keys in:

```text
~/.config/llm-translate/env
```

Example:

```text
LLM_TRANSLATE_PROVIDER=openai
OPENAI_API_KEY=sk-...
LLM_TRANSLATE_MODEL=gpt-4o-mini
LLM_TRANSLATE_TARGET=Simplified Chinese
```

If the app cannot find the repository CLI, set:

```bash
export LLM_TRANSLATE_CLI=/absolute/path/to/bin/llm-translate
```

## Target Language

The menu-bar `Source Language` menu uses `LLM_TRANSLATE_SOURCE` as the default and falls back to `Auto Detect`.
LLM providers can usually stay on auto-detect; MyMemory-style providers should set the source language when translating from non-English text.

`Target Language` uses `LLM_TRANSLATE_TARGET` as the default and provides common languages:

- Simplified Chinese
- Traditional Chinese
- English
- Japanese
- Korean
- French
- German
- Spanish
- Russian
- Italian
- Portuguese
- Arabic

The menu selection affects translation calls from the current app process only. It does not write back to `~/.config/llm-translate/env`.
