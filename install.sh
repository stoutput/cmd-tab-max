#!/bin/bash
set -euo pipefail

REPO="stoutput/cmd-tab-max"
BINARY_NAME="CmdTabMaximizer"
INSTALL_DIR="/usr/local/bin"
BINARY="$INSTALL_DIR/$BINARY_NAME"
PLIST_LABEL="com.cmdtabmaximizer"
PLIST_FILE="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

# ── download ───────────────────────────────────────────────────────────────────

echo "Fetching latest release..."
DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep '"browser_download_url"' | grep 'universal\.zip' | cut -d'"' -f4)

if [ -z "$DOWNLOAD_URL" ]; then
  echo "Error: could not find a release asset. Check https://github.com/$REPO/releases" >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

curl -fsSL "$DOWNLOAD_URL" -o "$TMP/release.zip"
unzip -q "$TMP/release.zip" "$BINARY_NAME" -d "$TMP"

# ── install binary ─────────────────────────────────────────────────────────────

echo "Installing to $BINARY..."
if [ -w "$INSTALL_DIR" ]; then
  cp "$TMP/$BINARY_NAME" "$BINARY"
else
  sudo cp "$TMP/$BINARY_NAME" "$BINARY"
fi
chmod +x "$BINARY"
xattr -dr com.apple.quarantine "$BINARY" 2>/dev/null || true

# ── install LaunchAgent ────────────────────────────────────────────────────────

mkdir -p "$(dirname "$PLIST_FILE")"
cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINARY</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/CmdTabMaximizer.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/CmdTabMaximizer.log</string>
</dict>
</plist>
EOF

# Unload any existing instance before bootstrapping.
launchctl bootout "gui/$(id -u)" "$PLIST_FILE" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_FILE"

# ── accessibility permission ───────────────────────────────────────────────────

echo ""
echo "✅ CmdTabMax installed and running."
echo ""
echo "One last step: grant Accessibility permission when the dialog appears."
echo "If it doesn't appear automatically, go to:"
echo "  System Settings → Privacy & Security → Accessibility"
echo "and enable CmdTabMaximizer."
echo ""
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
