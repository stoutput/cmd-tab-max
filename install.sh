#!/bin/bash
set -euo pipefail

REPO="stoutput/cmd-tab-max"
BINARY_NAME="CmdTabMax"
APP_BUNDLE="$HOME/Applications/CmdTabMax.app"
BINARY="$APP_BUNDLE/Contents/MacOS/$BINARY_NAME"
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

if [ -d "$APP_BUNDLE" ]; then FRESH_INSTALL=false; else FRESH_INSTALL=true; fi

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

# ── install app bundle ─────────────────────────────────────────────────────────

echo "Installing to $APP_BUNDLE..."

mkdir -p "$APP_BUNDLE/Contents/MacOS"

# Info.plist gives TCC a stable CFBundleIdentifier to track across updates,
# so the accessibility grant survives binary changes.
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.stoutput.cmdtabmax</string>
    <key>CFBundleName</key>
    <string>CmdTabMax</string>
    <key>CFBundleVersion</key>
    <string>$LATEST_VERSION</string>
    <key>CFBundleExecutable</key>
    <string>$BINARY_NAME</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

cp "$TMP/$BINARY_NAME" "$BINARY"
xattr -dr com.apple.quarantine "$APP_BUNDLE" 2>/dev/null || true
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

# Migrate: remove old bare binary if present from a previous install.
rm -f "/usr/local/bin/$BINARY_NAME" 2>/dev/null || true

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

# ── restart & accessibility ────────────────────────────────────────────────────

launchctl bootout "gui/$(id -u)" "$PLIST_FILE" 2>/dev/null || true
sleep 1
launchctl bootstrap "gui/$(id -u)" "$PLIST_FILE"

echo ""
echo "✅ CmdTabMax $LATEST_VERSION installed."
echo ""

if [ "$FRESH_INSTALL" = false ]; then
  # Each binary update changes the code signature, invalidating the old TCC
  # grant. Reset it so a fresh prompt appears for the new binary.
  if tccutil reset Accessibility "$PLIST_LABEL" 2>/dev/null; then
    echo "Accessibility permission reset for the new version."
    echo "Grant it when the System Settings prompt appears."
    echo "CmdTabMax will start working immediately — no logout required."
  else
    echo "Action required: open System Settings → Privacy & Security → Accessibility,"
    echo "click − to remove the existing CmdTabMax entry, then re-add it."
    echo "CmdTabMax will start working as soon as you grant access — no logout required."
  fi
else
  echo "One last step: grant Accessibility permission when the dialog appears."
fi

echo ""
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
