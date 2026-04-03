# CmdTabMax

Automatically maximizes windows when you Cmd-Tab to them.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/stoutput/CmdTabMax/main/install.sh | bash
```

The script will:
1. Download the latest universal binary
2. Install it to `/usr/local/bin`
3. Register a LaunchAgent so it starts automatically on login
4. Open Accessibility settings — enable CmdTabMaximizer there to allow it to observe keystrokes

## Uninstall

```sh
launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.cmdtabmaximizer.plist
rm ~/Library/LaunchAgents/com.cmdtabmaximizer.plist /usr/local/bin/CmdTabMaximizer
```

## Build from source

Requires Xcode command-line tools.

```sh
git clone https://github.com/stoutput/CmdTabMax.git
cd CmdTabMax
make install
```

## How it works

CmdTabMax installs a global keyboard event tap. When it detects that Cmd is released after a Cmd-Tab sequence, it resizes the frontmost window to fill the visible area of its screen (respecting the menu bar and Dock). It uses the macOS Accessibility API — no private frameworks.

## Releasing

Bump the version in `VERSION` and push to `main` — a release is created automatically.

```sh
echo "1.2.0" > VERSION
git commit -am "1.2.0" && git push
```
