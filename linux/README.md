# Linux Desktop

[简体中文](./README.zh-CN.md) · English

Linux desktop integration has two layers:

- `LLMTranslateLinux/`: a GTK app with buttons for translating selection,
  translating clipboard, speaking selection, test translation, and diagnostics.
- `llm-translate-linux`: a lightweight shortcut helper for binding directly to
  desktop keyboard shortcuts.

One-command GUI and shortcut install:

```bash
curl -fsSL https://raw.githubusercontent.com/MarsDoge/llm-translate/main/install.sh | bash -s -- --linux-desktop --install-linux-deps
```

For the GUI app, see [LLMTranslateLinux/README.md](./LLMTranslateLinux/README.md).

For the shortcut helper:

```bash
linux/llm-translate-linux test
linux/llm-translate-linux translate-selection
linux/llm-translate-linux speak-selection
linux/llm-translate-linux diagnostics
```

X11 works best with `xclip` and `xdotool`. Wayland works best with
`wl-clipboard` and `wtype`, though compositor policy may require using
clipboard translation instead of synthetic copy shortcuts.
