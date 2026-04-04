#!/bin/bash
set -euo pipefail

REPO="stoutput/cmd-tab-max"
BINARY_NAME="CmdTabMax"
INSTALL_DIR="/usr/local/bin"
BINARY="$INSTALL_DIR/$BINARY_NAME"
PLIST_LABEL="com.stoutput.cmdtabmax"
PLIST_FILE="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

# ── version check ──────────────────────────────────────────────────────────────

echo "Checking latest release..."
LATEST_JSON=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")
LATEST_VERSION=$(echo "$LATEST_JSON" | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')

if [ -f "$PLIST_FILE" ]; then
  INSTALLED_VERSION=$(/usr/libexec/PlistBuddy -c "Print :Version" "$PLIST_FILE" 2>/dev/null || echo "")
  if [ "$INSTALLED_VERSION" = "$LATEST_VERSION" ]; then
    echo "✅ CmdTabMax $LATEST_VERSION is already up to date."
    exit 0
  fi
fi

FRESH_INSTALL=true
[ -f "$BINARY" ] && FRESH_INSTALL=false

# ── download ───────────────────────────────────────────────────────────────────

echo "Downloading v$LATEST_VERSION..."
DOWNLOAD_URL=$(echo "$LATEST_JSON" \
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
if ! cp "$TMP/$BINARY_NAME" "$BINARY" 2>/dev/null; then
  sudo </dev/tty cp "$TMP/$BINARY_NAME" "$BINARY"
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
    <key>Version</key>
    <string>$LATEST_VERSION</string>
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
  echo "✅ CmdTabMax $LATEST_VERSION installed and running."
  echo ""
  echo "One last step: grant Accessibility permission when the dialog appears."
  echo "If it doesn't appear, go to System Settings → Privacy & Security → Accessibility."
  echo ""
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
else
  echo "✅ CmdTabMax updated to $LATEST_VERSION and restarted."
fi
