# CmdTabMax

Automatically maximizes windows when you Cmd-Tab to them.

## Requirements

- macOS 11+
- Accessibility permission (prompted on first run)

## Install

### From a release

1. Download `CmdTabMaximizer-<version>-universal.zip` from the [latest release](../../releases/latest) and unzip it.

2. Copy the binary to `/usr/local/bin`:
   ```sh
   sudo cp CmdTabMaximizer /usr/local/bin/
   ```

3. Remove the quarantine flag (required for unsigned binaries):
   ```sh
   xattr -dr com.apple.quarantine /usr/local/bin/CmdTabMaximizer
   ```

4. Install the LaunchAgent so it starts automatically on login:
   ```sh
   sed "s|__BINARY__|/usr/local/bin/CmdTabMaximizer|g" \
       com.cmdtabmaximizer.plist \
       > ~/Library/LaunchAgents/com.cmdtabmaximizer.plist
   launchctl load -w ~/Library/LaunchAgents/com.cmdtabmaximizer.plist
   ```

5. Grant Accessibility permission when prompted, or manually via:\
   **System Settings → Privacy & Security → Accessibility**

### From source

```sh
git clone https://github.com/stoutput/CmdTabMax.git
cd CmdTabMax
make install
```

`make install` builds a universal binary, copies it to `/usr/local/bin`, and installs the LaunchAgent.

## Uninstall

```sh
make uninstall
```

Or manually:

```sh
launchctl unload -w ~/Library/LaunchAgents/com.cmdtabmaximizer.plist
rm ~/Library/LaunchAgents/com.cmdtabmaximizer.plist /usr/local/bin/CmdTabMaximizer
```

## How it works

CmdTabMax installs a global keyboard event tap. When it detects that Cmd is released after a Cmd-Tab sequence, it resizes the frontmost window to fill the visible area of its current screen (accounting for the menu bar and Dock). It uses the macOS Accessibility API — no private frameworks.

## Releasing

Push a version tag to trigger the GitHub Actions build:

```sh
git tag v1.0.0 && git push origin v1.0.0
```

This produces a universal (arm64 + x86_64) binary and publishes it as a GitHub release.
