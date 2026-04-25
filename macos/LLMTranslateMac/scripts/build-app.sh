#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
REPO_DIR="$(cd -P "$ROOT_DIR/../.." >/dev/null 2>&1 && pwd)"
APP_NAME="LLMTranslateMac"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
INSTALL_DIR="/Applications/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
CLI_RESOURCES_DIR="$RESOURCES_DIR/llm-translate"
INSTALL=0

usage() {
  cat <<EOF
usage: $0 [--install]

Builds dist/$APP_NAME.app.

Options:
  --install   Also replace $INSTALL_DIR with the signed app bundle.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --install) INSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

swift build -c release --package-path "$ROOT_DIR"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$CLI_RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp -R "$REPO_DIR/bin" "$CLI_RESOURCES_DIR/bin"
cp -R "$REPO_DIR/lib" "$CLI_RESOURCES_DIR/lib"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>LLMTranslateMac</string>
  <key>CFBundleIdentifier</key>
  <string>com.marsdoge.llmtranslate.mac</string>
  <key>CFBundleName</key>
  <string>LLMTranslateMac</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"

if [ "$INSTALL" -eq 1 ]; then
  pkill -x "$APP_NAME" 2>/dev/null || true
  rm -rf "$INSTALL_DIR"
  cp -R "$APP_DIR" "$INSTALL_DIR"
  echo "Installed $INSTALL_DIR"
fi
