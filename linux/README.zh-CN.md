# Linux Desktop

简体中文 · [English](./README.md)

Linux 桌面集成分两层：

- `LLMTranslateLinux/`：GTK 图形应用，提供翻译选区、翻译剪贴板、朗读选区、测试翻译和诊断按钮。
- `llm-translate-linux`：轻量快捷键 helper，适合直接绑定到桌面自定义快捷键。

一键安装 GUI 和快捷键：

```bash
curl -fsSL https://raw.githubusercontent.com/MarsDoge/llm-translate/main/install.sh | bash -s -- --linux-desktop --install-linux-deps
```

GUI 应用说明见 [LLMTranslateLinux/README.zh-CN.md](./LLMTranslateLinux/README.zh-CN.md)。

快捷键 helper 可这样运行：

```bash
linux/llm-translate-linux test
linux/llm-translate-linux translate-selection
linux/llm-translate-linux speak-selection
linux/llm-translate-linux diagnostics
```

X11 推荐安装 `xclip` 和 `xdotool`。Wayland 推荐安装 `wl-clipboard` 和 `wtype`，
但具体 compositor 策略可能会限制模拟复制快捷键，这种情况下优先使用剪贴板翻译。
