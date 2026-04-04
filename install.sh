#!/bin/bash
set -euo pipefail

REPO="stoutput/cmd-tab-max"
BINARY_NAME="CmdTabMax"
INSTALL_DIR="/usr/local/bin"
BINARY="$INSTALL_DIR/$BINARY_NAME"
PLIST_LABEL="com.stoutput.cmdtabmax"
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

FRESH_INSTALL=false
[ ! -f "$BINARY" ] && FRESH_INSTALL=true

# ── install binary ─────────────────────────────────────────────────────────────

echo "Installing to $BINARY..."
if [ -w "$INSTALL_DIR" ]; then
  cp "$TMP/$BINARY_NAME" "$BINARY"
else
  sudo cp "$TMP/$BINARY_NAME" "$BINARY"
fi
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
    <string>/tmp/CmdTabMax.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/CmdTabMax.log</string>
</dict>
</plist>
EOF

# Stop any running instance, then start the new one.
launchctl bootout "gui/$(id -u)" "$PLIST_FILE" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_FILE"

# ── done ──────────────────────────────────────────────────────────────────────

echo ""
if [ "$FRESH_INSTALL" = true ]; then
  echo "✅ CmdTabMax installed and running."
  echo ""
  echo "One last step: grant Accessibility permission when the dialog appears."
  echo "If it doesn't appear, go to System Settings → Privacy & Security → Accessibility."
  echo ""
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
else
  echo "✅ CmdTabMax updated and restarted."
fi
