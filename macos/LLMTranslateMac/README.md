# LLMTranslateMac

macOS menu-bar MVP for translating or speaking selected text from any app.

It reuses the repository CLI (`bin/llm-translate`) instead of duplicating provider logic:

- `Option + Command + T`: copy the current selection, translate it, and show the result in a floating panel.
- `Option + Command + S`: copy the current selection and speak it with macOS speech synthesis.

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
