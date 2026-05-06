# LLMTranslateLinux

简体中文 · [English](./README.md)

一个 Linux GTK 图形应用，用来在桌面环境里翻译或朗读选中文字。它只负责图形界面和选区/剪贴板读取，翻译仍然复用仓库里的 `bin/llm-translate`。

## 功能

- `Translate Selection`：读取当前选区并翻译。
- `Translate Clipboard`：读取剪贴板并翻译，Wayland 下最稳。
- 源语言下拉框：默认自动识别，也可手动指定给 MyMemory 等非 LLM provider。
- 目标语言下拉框：临时切换本次 GUI 翻译目标，不改配置文件。
- `Speak Selection`：读取当前选区并调用本机 TTS。
- `Test`：翻译 `Hello, world!`，用于验证 provider 配置。
- `Version`：显示 Linux GUI 和底层 CLI 版本。
- `Diagnostics`：显示 CLI、provider、桌面 helper 可用性。

## 构建

推荐直接走顶层一键安装，它会构建 GUI、安装桌面启动项，并尽量自动绑定快捷键：

```bash
curl -fsSL https://raw.githubusercontent.com/MarsDoge/llm-translate/main/install.sh | bash -s -- --linux-desktop --install-linux-deps
```

Debian / Ubuntu:

```bash
sudo apt install build-essential pkg-config libgtk-3-dev jq curl
```

构建并运行：

```bash
cd linux/LLMTranslateLinux
make
./build/LLMTranslateLinux
```

安装完成后的默认快捷键：

- `Super+Alt+T`：翻译当前选区
- `Super+Alt+S`：朗读当前选区

如果当前桌面不是 GNOME / Xfce，安装脚本会安装启动项并打印需要手动绑定的命令。

## 桌面依赖

按会话类型安装选区/剪贴板工具：

```bash
# X11 / Xorg
sudo apt install xclip xdotool

# Wayland
sudo apt install wl-clipboard wtype
```

朗读功能可选：

```bash
sudo apt install speech-dispatcher
```

如果 Wayland compositor 禁止模拟按键，先复制文本，再点 `Translate Clipboard`。

## 目标语言

GUI 会读取 `LLM_TRANSLATE_SOURCE` 作为默认源语言，未设置时使用 `Auto Detect`。
LLM provider 通常保持自动识别即可；MyMemory 这类 provider 翻译非英文源文时建议手动指定源语言。

GUI 会读取 `LLM_TRANSLATE_TARGET` 作为默认目标语言，并在窗口里提供常用目标语言下拉框：

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

下拉框只影响当前 GUI 进程里的翻译调用，不会写入 `~/.config/llm-translate/env`。

## Provider 配置

图形应用通常不会加载 shell rc 文件。建议把配置写到：

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

如果应用找不到仓库里的 CLI，请设置：

```bash
export LLM_TRANSLATE_CLI=/absolute/path/to/bin/llm-translate
```
