#!/usr/bin/env bash
# install.sh — one-step installer for llm-translate.
# https://github.com/MarsDoge/llm-translate
#
# Modes:
#   --mode manual     clone to ~/.local/share/llm-translate, runtimepath+= in vimrc
#   --mode vim-plug   bootstrap vim-plug if missing, Plug 'MarsDoge/llm-translate',
#                     run :PlugInstall headlessly
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/MarsDoge/llm-translate/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/MarsDoge/llm-translate/main/install.sh | bash -s -- --mode vim-plug
#   ./install.sh --uninstall
set -euo pipefail

REPO_URL="https://github.com/MarsDoge/llm-translate.git"
PLUG_URL="https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"

MODE="manual"
PREFIX="${PREFIX:-$HOME/.local/bin}"
SHARE_DIR_DEFAULT="$HOME/.local/share/llm-translate"
SHARE_DIR="${LLM_TRANSLATE_DIR:-$SHARE_DIR_DEFAULT}"
UNINSTALL=0
SKIP_VIM=0

info() { printf '\033[1;34m▸\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
install.sh — one-step installer for llm-translate

USAGE
  install.sh [--mode manual|vim-plug] [--prefix DIR] [--dir DIR]
  install.sh --uninstall

OPTIONS
  --mode MODE     manual (default) or vim-plug
  --prefix DIR    where to put the CLI symlink (default: ~/.local/bin)
  --dir DIR       where to clone/find the repo
                  (default: ~/.local/share/llm-translate in manual mode,
                            ~/.vim/plugged/llm-translate in vim-plug mode)
  --skip-vim      install the CLI only, don't touch vimrc
  --uninstall     remove symlink and config blocks this script added
  -h, --help      show this help

EXAMPLES
  # One-liner via curl (manual mode)
  curl -fsSL https://raw.githubusercontent.com/MarsDoge/llm-translate/main/install.sh | bash

  # vim-plug users
  ./install.sh --mode vim-plug

  # CLI only, I'll wire up Vim myself
  ./install.sh --skip-vim
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)       MODE="${2:?--mode needs a value}"; shift 2 ;;
    --mode=*)     MODE="${1#*=}"; shift ;;
    --prefix)     PREFIX="${2:?--prefix needs a value}"; shift 2 ;;
    --prefix=*)   PREFIX="${1#*=}"; shift ;;
    --dir)        SHARE_DIR="${2:?--dir needs a value}"; shift 2 ;;
    --dir=*)      SHARE_DIR="${1#*=}"; shift ;;
    --skip-vim)   SKIP_VIM=1; shift ;;
    --uninstall)  UNINSTALL=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

check_deps() {
  local missing=()
  command -v curl >/dev/null || missing+=(curl)
  command -v jq   >/dev/null || missing+=(jq)
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "missing runtime deps: ${missing[*]} — install via your package manager (e.g. sudo apt install ${missing[*]})"
  fi
}

# If we're running from inside a checkout, reuse it instead of cloning.
detect_local_checkout() {
  local self_dir
  self_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
  if [[ -x "$self_dir/bin/llm-translate" && -d "$self_dir/lib/providers" ]]; then
    printf '%s' "$self_dir"
  fi
}

fetch_repo() {
  local target="$1" local_checkout
  local_checkout="$(detect_local_checkout)"
  if [[ -n "$local_checkout" && "$local_checkout" != "$target" ]]; then
    info "using local checkout at $local_checkout (skipping clone)"
    SHARE_DIR="$local_checkout"
    return
  fi
  if [[ -d "$target/.git" ]]; then
    info "updating existing repo at $target"
    git -C "$target" pull --ff-only || warn "git pull failed — continuing with existing files"
    return
  fi
  command -v git >/dev/null || die "git is required to fetch the repo (or run from a local checkout)"
  info "cloning $REPO_URL → $target"
  mkdir -p "$(dirname "$target")"
  git clone --depth 1 "$REPO_URL" "$target"
}

link_cli() {
  mkdir -p "$PREFIX"
  chmod +x "$SHARE_DIR/bin/llm-translate"
  ln -sf "$SHARE_DIR/bin/llm-translate" "$PREFIX/llm-translate"
  ok "linked $PREFIX/llm-translate → $SHARE_DIR/bin/llm-translate"
}

ensure_path() {
  if printf '%s' ":$PATH:" | grep -q ":$PREFIX:"; then
    return
  fi
  local added=0
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f "$rc" ]] || continue
    if ! grep -q "llm-translate:path" "$rc"; then
      {
        printf '\n# llm-translate:path (added by install.sh)\n'
        # $PATH must stay literal — it expands when the user's shell sources the rc.
        # shellcheck disable=SC2016
        printf 'export PATH="%s:$PATH"\n' "$PREFIX"
      } >> "$rc"
      ok "added $PREFIX to PATH in $rc"
      added=1
    fi
  done
  (( added )) && warn "open a new shell or run: export PATH=\"$PREFIX:\$PATH\""
}

# Idempotent injection between markers. Args: file, comment-prefix, body.
inject_block() {
  local file="$1" cp="$2" body="$3"
  local begin="${cp} llm-translate:begin (added by install.sh)"
  local end="${cp} llm-translate:end"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if grep -Fq "llm-translate:begin" "$file"; then
    return  # already present — keep idempotent, user can --uninstall to reset
  fi
  {
    printf '\n%s\n%s\n%s\n' "$begin" "$body" "$end"
  } >> "$file"
  ok "updated $file"
}

config_vim_manual() {
  (( SKIP_VIM )) && { info "skipping Vim config (--skip-vim)"; return; }
  local body="set runtimepath+=$SHARE_DIR"
  inject_block "$HOME/.vimrc" '"' "$body"
  # Only touch Neovim's init.vim if it already exists — don't create one for
  # users on init.lua (would shadow their lua config).
  if [[ -f "$HOME/.config/nvim/init.vim" ]]; then
    inject_block "$HOME/.config/nvim/init.vim" '"' "$body"
  elif [[ -f "$HOME/.config/nvim/init.lua" ]]; then
    warn "detected init.lua — add this to your Lua config yourself:"
    printf "    vim.opt.runtimepath:append('%s')\n" "$SHARE_DIR"
  fi
}

bootstrap_plug() {
  local vim_plug="$HOME/.vim/autoload/plug.vim"
  local nvim_plug="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim"
  if [[ ! -f "$vim_plug" ]]; then
    info "bootstrapping vim-plug for Vim"
    curl -fLo "$vim_plug" --create-dirs "$PLUG_URL"
  fi
  if command -v nvim >/dev/null && [[ ! -f "$nvim_plug" ]]; then
    info "bootstrapping vim-plug for Neovim"
    curl -fLo "$nvim_plug" --create-dirs "$PLUG_URL"
  fi
}

has_plug_block() {
  # detect an existing plug#begin call anywhere in the file
  [[ -f "$1" ]] && grep -Eq '^\s*call\s+plug#begin' "$1"
}

config_vim_plug() {
  if (( SKIP_VIM )); then
    info "skipping Vim config (--skip-vim); clone plugin dir yourself"
    return
  fi
  bootstrap_plug
  local vimrc="$HOME/.vimrc"
  local nvimrc="$HOME/.config/nvim/init.vim"
  local user_has_existing_block=0
  for rc in "$vimrc" "$nvimrc"; do
    # Only touch nvim init.vim if it already exists — don't create one for
    # Lua-config users.
    [[ "$rc" != "$nvimrc" ]] || [[ -f "$rc" ]] || continue
    if has_plug_block "$rc"; then
      user_has_existing_block=1
      warn "$rc already has a plug#begin block — add this line inside it yourself:"
      printf "    Plug 'MarsDoge/llm-translate'\n"
    else
      local body
      body="$(cat <<'VIMBODY'
call plug#begin()
Plug 'MarsDoge/llm-translate'
call plug#end()
VIMBODY
)"
      inject_block "$rc" '"' "$body"
    fi
  done

  # Pre-stage the clone so (a) the CLI symlink resolves right away, and
  # (b) vim-plug treats it as managed on the next :PlugUpdate.
  if [[ ! -d "$SHARE_DIR/.git" ]]; then
    info "cloning $REPO_URL → $SHARE_DIR"
    mkdir -p "$(dirname "$SHARE_DIR")"
    git clone --depth 1 "$REPO_URL" "$SHARE_DIR"
  fi

  if (( user_has_existing_block )); then
    info "skipping headless :PlugInstall (you already have a plug#begin block); add the Plug line and run :PlugInstall yourself"
    return
  fi
  if command -v vim >/dev/null; then
    info "running :PlugInstall (vim, headless)"
    vim -Nu "$vimrc" +PlugInstall +qa >/dev/null 2>&1 || \
      warn ":PlugInstall via vim failed — open Vim and run :PlugInstall manually"
  fi
  if command -v nvim >/dev/null && [[ -f "$nvimrc" ]]; then
    info "running :PlugInstall (nvim, headless)"
    nvim --headless +PlugInstall +qa >/dev/null 2>&1 || \
      warn ":PlugInstall via nvim failed — open Neovim and run :PlugInstall manually"
  fi
}

verify() {
  if ! [[ -x "$PREFIX/llm-translate" ]]; then
    warn "CLI not executable at $PREFIX/llm-translate — something went wrong"
    return
  fi
  info "smoke test: echo 'Hello, world!' | llm-translate -p mymemory -t zh-CN"
  local out
  if out="$("$PREFIX/llm-translate" -p mymemory -t zh-CN <<<"Hello, world!" 2>&1)"; then
    ok "translated → $out"
  else
    warn "smoke test failed (network? provider down?) — try again later"
  fi
}

remove_block() {
  # strip marker block from $1
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -Fq "llm-translate:begin" "$file" || return 0
  local tmp
  tmp="$(mktemp)"
  awk '
    /llm-translate:begin/ { skip=1; next }
    skip && /llm-translate:end/ { skip=0; next }
    !skip
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  ok "cleaned block from $file"
}

remove_path_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -Fq "llm-translate:path" "$file" || return 0
  local tmp
  tmp="$(mktemp)"
  # Drop the marker line plus the single `export PATH=...` line that follows it.
  awk '
    /# llm-translate:path/ { drop_next=1; next }
    drop_next             { drop_next=0; next }
                          { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  ok "cleaned PATH block from $file"
}

uninstall() {
  info "removing $PREFIX/llm-translate"
  rm -f "$PREFIX/llm-translate"
  for rc in "$HOME/.vimrc" "$HOME/.config/nvim/init.vim"; do
    remove_block "$rc"
  done
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    remove_path_block "$rc"
  done
  ok "uninstalled. Repo dir $SHARE_DIR left in place — rm -rf it manually if you want."
}

main() {
  if (( UNINSTALL )); then
    uninstall
    exit 0
  fi
  check_deps
  case "$MODE" in
    manual)
      [[ "$SHARE_DIR" == "$SHARE_DIR_DEFAULT" ]] || info "using custom repo dir: $SHARE_DIR"
      fetch_repo "$SHARE_DIR"
      link_cli
      ensure_path
      config_vim_manual
      ;;
    vim-plug)
      [[ "$SHARE_DIR" == "$SHARE_DIR_DEFAULT" ]] && SHARE_DIR="$HOME/.vim/plugged/llm-translate"
      config_vim_plug
      link_cli
      ensure_path
      ;;
    *)
      die "unknown --mode: $MODE (want manual or vim-plug)"
      ;;
  esac
  verify
  cat <<EOF

Next step — export an API key for a real LLM provider:
  export DEEPSEEK_API_KEY=sk-...       # https://platform.deepseek.com
  export OPENAI_API_KEY=sk-...         # https://platform.openai.com
  export ANTHROPIC_API_KEY=sk-ant-...  # https://console.anthropic.com

Then:  echo "Hello" | llm-translate -p deepseek -t Japanese

EOF
}

main
