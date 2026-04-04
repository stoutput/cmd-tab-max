# CmdTabMax
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Y8Y81X7LER)

MacOS, annoyingly, does not restore windows when you Cmd-Tab to them. This fixes that.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/stoutput/cmd-tab-max/main/install.sh | bash
```

On first launch you'll be prompted to grant Accessibility permission — required for the keyboard event tap.

## Uninstall

```sh
launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.stoutput.cmdtabmax.plist
rm ~/Library/LaunchAgents/com.stoutput.cmdtabmax.plist /usr/local/bin/CmdTabMax
```

## How it works

CmdTabMax installs a global keyboard event tap. When it detects Cmd being released after a Cmd-Tab sequence, it injects the Option modifier into that event before the system processes it. This triggers macOS's built-in App Switcher behaviour for Option+Cmd-release, which restores any minimized windows of the switched-to app. The Option key is then released 50ms later so it doesn't bleed into the new app.

No private frameworks. No window resizing via Accessibility API.

## Build from source

Requires Xcode command-line tools.

```sh
git clone https://github.com/stoutput/cmd-tab-max.git
cd cmd-tab-max
make install
```

## Releasing

Bump the `Version` key in `com.stoutput.cmdtabmax.plist` and push to `main` — a release is created automatically.
