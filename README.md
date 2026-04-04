# CmdTabMax

Automatically maximizes windows when you Cmd-Tab to them.

## Install/Update

Open a terminal window and run:
```sh
curl -fsSL https://raw.githubusercontent.com/stoutput/cmd-tab-max/main/install.sh | bash
```
then enter your password (to strip the quarantine attribute) & enable CmdTabMaximizer in Accessibility settings

The script will:
1. Download the latest universal binary
2. Install it to `/usr/local/bin`
3. Register a LaunchAgent so it starts automatically on login
4. Open Accessibility settings — enable CmdTabMaximizer there to allow it to observe keystrokes

## Uninstall

```sh
launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.stoutput.cmdtabmax.plist
rm ~/Library/LaunchAgents/com.stoutput.cmdtabmax.plist /usr/local/bin/CmdTabMaximizer
```

## How it works

CmdTabMax installs a global keyboard event tap. When it detects that Cmd is released after a Cmd-Tab sequence, it resizes the frontmost window to fill the visible area of its screen (respecting the menu bar and Dock). It uses the macOS Accessibility API — no private frameworks.

## Build from source

Requires Xcode command-line tools.

```sh
git clone https://github.com/stoutput/cmd-tab-max.git
cd cmd-tab-max
make install
```

## Releasing

Bump the `Version` key in `com.stoutput.cmdtabmax.plist` and push to `main` — a release is created automatically.
