# CmdTabMax
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Y8Y81X7LER)

MacOS, annoyingly, does not restore windows when you Cmd-Tab to them. This fixes that.

## Install/Update

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

CmdTabMax installs a global keyboard event tap to detect Cmd-Tab releases, then watches `NSWorkspace` for the resulting app activation. When the switched-to app activates, it inspects the app's windows via the Accessibility API and:

- if a non-minimized window already exists, does nothing (normal app activation brings it to the front);
- if every window is minimized, unminimizes one;
- if no windows exist at all, posts Cmd+N to the app to open a new one.

No private frameworks.

## Build from source

Requires Xcode command-line tools.

```sh
git clone https://github.com/stoutput/cmd-tab-max.git
cd cmd-tab-max
make install
```

## Releasing

Bump the `Version` key in `com.stoutput.cmdtabmax.plist` and push to `main` — a release is created automatically.
