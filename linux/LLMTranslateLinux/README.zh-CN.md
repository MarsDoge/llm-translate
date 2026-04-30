# LLMTranslateLinux

简体中文 · [English](./README.md)

一个 Linux GTK 图形应用，用来在桌面环境里翻译或朗读选中文字。它只负责图形界面和选区/剪贴板读取，翻译仍然复用仓库里的 `bin/llm-translate`。

## 功能

- `Translate Selection`：读取当前选区并翻译。
- `Translate Clipboard`：读取剪贴板并翻译，Wayland 下最稳。
- `Speak Selection`：读取当前选区并调用本机 TTS。
- `Test`：翻译 `Hello, world!`，用于验证 provider 配置。
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
