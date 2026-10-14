# skim

Release builds of a personal fork of [Skim](https://skim-app.sourceforge.io/), the PDF reader and
note-taking app. This repository hosts the built `.dmg` artifacts only; the source lives locally in
the development checkout.

## Fork change

The window title bar — background, separator, title, and all window controls — is hidden until the
pointer enters the top of the window. Enable it in **Settings → General → "Hide window title bar
unless hovered"** (default `SKHideWindowTitleBar`, also settable with
`defaults write net.sourceforge.skim-app.skim SKHideWindowTitleBar -bool YES`). While it is enabled
the title bar reserves no space, so the first row of the PDF is drawn at the first row of the window.

## Installation

```sh
brew install --cask --no-quarantine kvndrsslr/formulae/skim-nobar
```

`--no-quarantine` is required: the build is ad-hoc signed (no Developer ID), so Gatekeeper rejects
the quarantined download. The cask conflicts with the upstream `skim` cask — both install
`Skim.app` — so uninstall `skim` first if it is present.

## Build characteristics

- arm64, macOS 27 (Golden Gate) or later
- ad-hoc signed; Sparkle updater is a Debug/adhoc build and is not a supported update path
