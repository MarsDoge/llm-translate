# LLMTranslateLinux

[简体中文](./README.zh-CN.md) · English

A Linux GTK app for translating or speaking selected text on the desktop. It only handles the GUI and selection / clipboard access; translation still goes through the repository CLI, `bin/llm-translate`.

## Features

- `Translate Selection`: read the current selection and translate it.
- `Translate Clipboard`: read the clipboard and translate it; this is the most reliable path on Wayland.
- `Speak Selection`: read the current selection and call local TTS.
- `Test`: translate `Hello, world!` to verify provider configuration.
- `Diagnostics`: show CLI, provider, and desktop helper availability.

## Build

Recommended one-command install from the repository root installs the GUI,
desktop launchers, and best-effort global shortcuts:

```bash
curl -fsSL https://raw.githubusercontent.com/MarsDoge/llm-translate/main/install.sh | bash -s -- --linux-desktop --install-linux-deps
```

Debian / Ubuntu:

```bash
sudo apt install build-essential pkg-config libgtk-3-dev jq curl
```

Build and run:

```bash
cd linux/LLMTranslateLinux
make
./build/LLMTranslateLinux
```

Default shortcuts after install:

- `Super+Alt+T`: translate current selection
- `Super+Alt+S`: speak current selection

If the current desktop is not GNOME / Xfce, the installer still installs
launchers and prints the command to bind manually.

## Desktop Dependencies

Install selection / clipboard helpers for your session type:

```bash
# X11 / Xorg
sudo apt install xclip xdotool

# Wayland
sudo apt install wl-clipboard wtype
```

Speech is optional:

```bash
sudo apt install speech-dispatcher
```

If your Wayland compositor blocks synthetic key events, copy the text first and use `Translate Clipboard`.

## Provider Config

GUI apps usually do not load shell rc files. Put provider config in:

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
