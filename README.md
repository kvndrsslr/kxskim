# kxskim

Release builds of a personal fork of [Skim](https://skim-app.sourceforge.io/), the PDF reader and
note-taking app, installed through the `kxskim` cask in
[kvndrsslr/homebrew-formulae](https://github.com/kvndrsslr/homebrew-formulae). This repository hosts
the built `.dmg` artifacts only; the source lives locally in the development checkout.

## Fork change

The window title bar — background, separator, title, and all window controls — is hidden until the
pointer enters the top of the window. Enable it in **Settings → General → "Hide window title bar
unless hovered"** (default `SKHideWindowTitleBar`, also settable with
`defaults write net.sourceforge.skim-app.skim SKHideWindowTitleBar -bool YES`). While it is enabled
the title bar reserves no space, so the first row of the PDF is drawn at the first row of the window.
The toolbar hides with it, and the side panes keep their top inset clear of that strip, so the
contents pane's tab buttons and search field stay clickable while the chrome is hidden. Viewport
padding and page gap settings live in **Settings → General**. In horizontal continuous display mode
the Contents pane's destinations keep the start of the target page clear of the pane, and a jump
briefly highlights the destination.

## Installation

```sh
brew install --cask kvndrsslr/formulae/kxskim
```

A plain install works. The build is ad-hoc signed (no Developer ID, so it cannot be notarized) and
the cask clears the quarantine flag from the installed app afterwards; on a machine where you would
rather brew never touches that attribute:

```sh
HOMEBREW_CASK_OPTS="--no-quarantine" brew install --cask kvndrsslr/formulae/kxskim
```

The fork keeps upstream's bundle identifier on purpose, so `kxskim` conflicts with the upstream
`skim` cask — both install `Skim.app`; uninstall `skim` first if it is present.

## Build characteristics

- arm64, macOS 27 (Golden Gate) or later
- ad-hoc signed; the Sparkle feed still points at upstream's appcast, so "Check for Updates" offers
  plain Skim and would replace this build
- the current `Skim-1.7.17.dmg` has
  `sha256 191c343200f6269de2317534baef112f5f4d1f76076beb1e8b90136c240d549a`
- the first `Skim-1.7.17.dmg` published had invalidated nested code signatures: the embedded
  frameworks are signed when copied in and the release build then stripped their headers, leaving
  seals that referenced files which no longer existed, so Gatekeeper reported `"Skim" is damaged and
  can't be opened`. The current payload is re-signed and verifies clean.
