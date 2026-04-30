#!/usr/bin/env bash
# Install Linux desktop integration for llm-translate.
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local/bin}"
UNINSTALL=0
BIND_SHORTCUTS=1
INSTALL_DEPS=0
TRANSLATE_BINDING="${LLM_TRANSLATE_HOTKEY_TRANSLATE:-<Super><Alt>t}"
SPEAK_BINDING="${LLM_TRANSLATE_HOTKEY_SPEAK:-<Super><Alt>s}"

info() { printf '\033[1;34m▸\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
install-desktop.sh - install Linux GUI and shortcuts for llm-translate

USAGE
  install-desktop.sh [--prefix DIR] [--no-shortcuts] [--install-deps]
  install-desktop.sh --uninstall

OPTIONS
  --prefix DIR       where to put wrapper commands (default: ~/.local/bin)
  --no-shortcuts     install launchers only; do not bind desktop shortcuts
  --install-deps     install distro packages via sudo before building
  --uninstall        remove wrappers, .desktop files, and known shortcuts
  -h, --help         show this help

DEFAULT SHORTCUTS
  ${TRANSLATE_BINDING}  translate current selection
  ${SPEAK_BINDING}  speak current selection
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)       PREFIX="${2:?--prefix needs a value}"; shift 2 ;;
    --prefix=*)     PREFIX="${1#*=}"; shift ;;
    --no-shortcuts) BIND_SHORTCUTS=0; shift ;;
    --install-deps)  INSTALL_DEPS=1; shift ;;
    --uninstall)    UNINSTALL=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

resolve_script_path() {
  local target="$1" dir link
  case "$target" in
    /*) ;;
    *) target="$PWD/$target" ;;
  esac
  while [[ -L "$target" ]]; do
    dir="$(cd -P "$(dirname "$target")" >/dev/null 2>&1 && pwd)" || return 1
    link="$(readlink "$target")"
    case "$link" in
      /*) target="$link" ;;
      *) target="$dir/$link" ;;
    esac
  done
  dir="$(cd -P "$(dirname "$target")" >/dev/null 2>&1 && pwd)" || return 1
  printf '%s/%s\n' "$dir" "$(basename "$target")"
}

SCRIPT_PATH="$(resolve_script_path "${BASH_SOURCE[0]}")"
LINUX_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$LINUX_DIR/.." && pwd)"
APP_DIR="$LINUX_DIR/LLMTranslateLinux"
APP_BIN="$APP_DIR/build/LLMTranslateLinux"
CLI_PATH="$ROOT_DIR/bin/llm-translate"
APPLICATIONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
DESKTOP_FILE="$APPLICATIONS_DIR/io.github.MarsDoge.LLMTranslateLinux.desktop"
TRANSLATE_DESKTOP_FILE="$APPLICATIONS_DIR/io.github.MarsDoge.LLMTranslateSelection.desktop"
GUI_WRAPPER="$PREFIX/llm-translate-linux-gui"
HELPER_WRAPPER="$PREFIX/llm-translate-linux"

require_linux() {
  [[ "$(uname -s)" == "Linux" ]] || die "Linux desktop integration can only be installed on Linux."
}

sudo_cmd() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    command -v sudo >/dev/null 2>&1 || die "sudo is required for --install-deps when not running as root"
    sudo "$@"
  fi
}

install_distro_deps() {
  (( INSTALL_DEPS )) || return 0

  if command -v apt-get >/dev/null 2>&1; then
    info "installing Linux desktop dependencies with apt"
    sudo_cmd apt-get update
    sudo_cmd apt-get install -y \
      build-essential pkg-config libgtk-3-dev jq curl \
      xclip xdotool wl-clipboard speech-dispatcher
    sudo_cmd apt-get install -y wtype || warn "optional package wtype was not installed"
    return 0
  fi

  if command -v dnf >/dev/null 2>&1; then
    info "installing Linux desktop dependencies with dnf"
    sudo_cmd dnf install -y \
      make gcc pkgconf-pkg-config gtk3-devel jq curl \
      xclip xdotool wl-clipboard speech-dispatcher
    sudo_cmd dnf install -y wtype || warn "optional package wtype was not installed"
    return 0
  fi

  if command -v pacman >/dev/null 2>&1; then
    info "installing Linux desktop dependencies with pacman"
    sudo_cmd pacman -S --needed --noconfirm \
      base-devel pkgconf gtk3 jq curl \
      xclip xdotool wl-clipboard speech-dispatcher
    sudo_cmd pacman -S --needed --noconfirm wtype || warn "optional package wtype was not installed"
    return 0
  fi

  warn "could not detect apt, dnf, or pacman; install GTK desktop dependencies manually"
}

check_gui_deps() {
  local missing=()
  command -v make >/dev/null 2>&1 || missing+=(make)
  command -v "${CC:-cc}" >/dev/null 2>&1 || missing+=(gcc)
  command -v pkg-config >/dev/null 2>&1 || missing+=(pkg-config)
  if ! pkg-config --exists gtk+-3.0 2>/dev/null; then
    missing+=(libgtk-3-dev)
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    cat >&2 <<EOF
Missing Linux GUI build dependencies: ${missing[*]}

Debian/Ubuntu:
  sudo apt install build-essential pkg-config libgtk-3-dev

Fedora:
  sudo dnf install make gcc pkgconf-pkg-config gtk3-devel

Arch:
  sudo pacman -S --needed base-devel pkgconf gtk3
EOF
    exit 1
  fi
}

build_gui() {
  info "building Linux GTK app"
  make -C "$APP_DIR"
}

write_wrappers() {
  mkdir -p "$PREFIX"
  chmod +x "$LINUX_DIR/llm-translate-linux"

  cat > "$GUI_WRAPPER" <<EOF
#!/usr/bin/env bash
export LLM_TRANSLATE_CLI="${CLI_PATH}"
exec "${APP_BIN}" "\$@"
EOF
  chmod +x "$GUI_WRAPPER"
  ok "installed $GUI_WRAPPER"

  ln -sf "$LINUX_DIR/llm-translate-linux" "$HELPER_WRAPPER"
  ok "installed $HELPER_WRAPPER"
}

write_desktop_files() {
  mkdir -p "$APPLICATIONS_DIR"

  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=LLM Translate
Comment=Translate or speak selected text with llm-translate
Exec=${GUI_WRAPPER}
Terminal=false
Categories=Utility;GTK;
StartupNotify=true
EOF

  cat > "$TRANSLATE_DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=LLM Translate Selection
Comment=Translate current selection with llm-translate
Exec=${GUI_WRAPPER} --translate-selection
Terminal=false
Categories=Utility;GTK;
StartupNotify=true
EOF

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPLICATIONS_DIR" >/dev/null 2>&1 || true
  fi

  ok "installed desktop launchers in $APPLICATIONS_DIR"
}

warn_runtime_helpers() {
  local session="${XDG_SESSION_TYPE:-}"
  case "$session" in
    wayland)
      if ! command -v wl-paste >/dev/null 2>&1 || ! command -v wl-copy >/dev/null 2>&1; then
        warn "Wayland clipboard helper missing; install wl-clipboard."
      fi
      if ! command -v wtype >/dev/null 2>&1 && ! command -v ydotool >/dev/null 2>&1; then
        warn "Wayland copy-shortcut helper missing; install wtype or ydotool, or use Translate Clipboard."
      fi
      ;;
    x11|"")
      if ! command -v xclip >/dev/null 2>&1 && ! command -v xsel >/dev/null 2>&1; then
        warn "X11 clipboard helper missing; install xclip or xsel."
      fi
      if ! command -v xdotool >/dev/null 2>&1; then
        warn "X11 copy-shortcut helper missing; install xdotool."
      fi
      ;;
  esac

  if ! command -v spd-say >/dev/null 2>&1 && ! command -v espeak-ng >/dev/null 2>&1 && ! command -v espeak >/dev/null 2>&1; then
    warn "speech helper missing; install speech-dispatcher or espeak-ng if you want speak-selection."
  fi
}

gsettings_append_path() {
  local schema="$1" key="$2" path="$3" current without_close
  current="$(gsettings get "$schema" "$key")"
  case "$current" in
    *"$path"*) return 0 ;;
    "@as []"|"[]")
      gsettings set "$schema" "$key" "['$path']"
      ;;
    *)
      without_close="${current%]}"
      gsettings set "$schema" "$key" "${without_close}, '$path']"
      ;;
  esac
}

bind_gnome_shortcuts() {
  command -v gsettings >/dev/null 2>&1 || return 1
  gsettings writable org.gnome.settings-daemon.plugins.media-keys custom-keybindings >/dev/null 2>&1 || return 1

  local base_schema="org.gnome.settings-daemon.plugins.media-keys"
  local child_schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
  local translate_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/llm-translate-translate/"
  local speak_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/llm-translate-speak/"

  gsettings_append_path "$base_schema" custom-keybindings "$translate_path"
  gsettings set "$child_schema:$translate_path" name "LLM Translate Selection"
  gsettings set "$child_schema:$translate_path" command "$GUI_WRAPPER --translate-selection"
  gsettings set "$child_schema:$translate_path" binding "$TRANSLATE_BINDING"

  gsettings_append_path "$base_schema" custom-keybindings "$speak_path"
  gsettings set "$child_schema:$speak_path" name "LLM Speak Selection"
  gsettings set "$child_schema:$speak_path" command "$GUI_WRAPPER --speak-selection"
  gsettings set "$child_schema:$speak_path" binding "$SPEAK_BINDING"

  ok "bound GNOME shortcuts: $TRANSLATE_BINDING translate, $SPEAK_BINDING speak"
  return 0
}

bind_xfce_shortcuts() {
  command -v xfconf-query >/dev/null 2>&1 || return 1

  xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$TRANSLATE_BINDING" \
    -n -t string -s "$GUI_WRAPPER --translate-selection" >/dev/null 2>&1 || return 1
  xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$SPEAK_BINDING" \
    -n -t string -s "$GUI_WRAPPER --speak-selection" >/dev/null 2>&1 || return 1

  ok "bound Xfce shortcuts: $TRANSLATE_BINDING translate, $SPEAK_BINDING speak"
  return 0
}

bind_shortcuts() {
  (( BIND_SHORTCUTS )) || return 0

  if bind_gnome_shortcuts; then
    return 0
  fi
  if bind_xfce_shortcuts; then
    return 0
  fi

  warn "could not auto-bind global shortcuts for this desktop."
  warn "Bind this command manually to $TRANSLATE_BINDING:"
  printf '  %s --translate-selection\n' "$GUI_WRAPPER" >&2
}

remove_gnome_shortcuts() {
  command -v gsettings >/dev/null 2>&1 || return 0
  gsettings writable org.gnome.settings-daemon.plugins.media-keys custom-keybindings >/dev/null 2>&1 || return 0

  local schema="org.gnome.settings-daemon.plugins.media-keys"
  local current
  current="$(gsettings get "$schema" custom-keybindings)"
  current="${current//\'\/org\/gnome\/settings-daemon\/plugins\/media-keys\/custom-keybindings\/llm-translate-translate\/\', /}"
  current="${current//, \'\/org\/gnome\/settings-daemon\/plugins\/media-keys\/custom-keybindings\/llm-translate-translate\/\'/}"
  current="${current//\'\/org\/gnome\/settings-daemon\/plugins\/media-keys\/custom-keybindings\/llm-translate-translate\/\'/}"
  current="${current//\'\/org\/gnome\/settings-daemon\/plugins\/media-keys\/custom-keybindings\/llm-translate-speak\/\', /}"
  current="${current//, \'\/org\/gnome\/settings-daemon\/plugins\/media-keys\/custom-keybindings\/llm-translate-speak\/\'/}"
  current="${current//\'\/org\/gnome\/settings-daemon\/plugins\/media-keys\/custom-keybindings\/llm-translate-speak\/\'/}"
  [[ "$current" == "[]" || "$current" == "@as []" ]] || gsettings set "$schema" custom-keybindings "$current" || true
}

uninstall() {
  require_linux
  remove_gnome_shortcuts
  rm -f "$GUI_WRAPPER" "$HELPER_WRAPPER" "$DESKTOP_FILE" "$TRANSLATE_DESKTOP_FILE"
  ok "removed Linux desktop integration"
}

main() {
  if (( UNINSTALL )); then
    uninstall
    exit 0
  fi

  require_linux
  [[ -x "$CLI_PATH" ]] || die "missing CLI at $CLI_PATH"
  install_distro_deps
  check_gui_deps
  build_gui
  write_wrappers
  write_desktop_files
  warn_runtime_helpers
  bind_shortcuts

  cat <<EOF

Linux desktop install complete.

Shortcuts:
  $TRANSLATE_BINDING  translate current selection
  $SPEAK_BINDING  speak current selection

Launcher:
  LLM Translate

EOF
}

main "$@"
