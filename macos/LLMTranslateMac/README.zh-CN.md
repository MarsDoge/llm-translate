# LLMTranslateMac

简体中文 · [English](./README.md)

一个 macOS 菜单栏 MVP，可以在任意 app 里对当前选中的文字进行翻译或发音。

它复用仓库里已有的 CLI（`bin/llm-translate`），不重复实现 provider 逻辑：

- `Option + Command + T`：复制当前选区，调用 CLI 翻译，并在浮动窗口里显示结果。
- `Option + Command + S`：复制当前选区，并用 macOS 自带语音合成读出来。

读取选区后，app 会恢复之前的剪贴板内容。

## 运行

先安装 CLI 的运行时依赖：

```bash
brew install jq curl
```

```bash
cd macos/LLMTranslateMac
swift run
```

首次使用时，macOS 会要求授予辅助功能权限。请在这里允许已构建的可执行程序：

```text
System Settings > Privacy & Security > Accessibility
```

## 构建 App Bundle

```bash
cd macos/LLMTranslateMac
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open dist/LLMTranslateMac.app
```

## 翻译 Provider

app 继承和 `llm-translate` 相同的环境变量。

为了方便零配置烟测，如果既没有设置 `LLM_TRANSLATE_PROVIDER`，也没有设置 `DEEPSEEK_API_KEY`，app 会使用 `mymemory`。如果需要更好的翻译质量，请在启动前配置 provider：

```bash
export LLM_TRANSLATE_PROVIDER=openai
export OPENAI_API_KEY=sk-...
export LLM_TRANSLATE_MODEL=gpt-4o-mini
export LLM_TRANSLATE_TARGET="Simplified Chinese"
swift run
```

如果是双击 `.app` 启动，shell 里的 `export` 通常不可见。可以把同样的配置写到：

```text
~/.config/llm-translate/env
```

示例：

```text
LLM_TRANSLATE_PROVIDER=openai
OPENAI_API_KEY=sk-...
LLM_TRANSLATE_MODEL=gpt-4o-mini
LLM_TRANSLATE_TARGET=Simplified Chinese
```

如果 app 找不到仓库里的 CLI，请设置：

```bash
export LLM_TRANSLATE_CLI=/absolute/path/to/bin/llm-translate
```
