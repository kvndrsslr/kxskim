# kxskim

Release builds of a personal fork of [Skim](https://skim-app.sourceforge.io/), the PDF reader and
note-taking app, installed through the `kxskim` cask in
[kvndrsslr/homebrew-formulae](https://github.com/kvndrsslr/homebrew-formulae). This repository hosts
the built `.dmg` artifacts only; the source lives locally in the development checkout.

## Fork change

The window title bar — background, separator, title, and all window controls — is hidden until the
pointer rests briefly at the top of the window, fading in and out over a quarter second. Enable it in
**Settings → General → "Hide window title bar unless hovered"** (default `SKHideWindowTitleBar`, also
settable with
`defaults write net.sourceforge.skim-app.skim SKHideWindowTitleBar -bool YES`). While it is enabled
the title bar reserves no space, so the first row of the PDF is drawn at the first row of the window.
The toolbar hides with it, and the side panes and the find bar keep their top inset clear of that
strip, so the contents pane's tab buttons and search field, and the find bar's search field,
Find Previous/Next and Done, all stay clickable while the chrome is hidden. Viewport padding and
page gap settings live in **Settings → General**; the page gap separates pages in the single-page
continuous modes, and in the two-up continuous mode it only separates spreads, so the two pages of a
spread touch. The non-continuous modes show one page or one spread at a time, so they ignore the gap:
there it would only pad the pane around the page. In horizontal continuous display mode the
Contents pane's destinations keep the start of the target page clear of the pane, and a jump
briefly highlights the destination. Page edges stay clean: PDFKit fills every page rect with a
view-global page color underneath the page content, and where the scaled page rect misses the
device-pixel grid that fill shows as a 1px antialiasing line along the page edges. The fill follows
the pane color only for documents whose pages paint their own background — then the fill never shows
except in that line, which it hides on dark panes — while documents with transparent page
backgrounds keep PDFKit's white paper. An overlay repaints the outermost device pixels of every page
edge with the page's own content, so the line also stays hidden between light pages, in every display
mode. One page cannot be papered differently from its document, because the page color is per view:
in a document of full-bleed pages, a page that paints no background of its own — a blank filler
page, say — shows that page color and reads as a dark sheet.

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
- the current `Skim-1.7.19.2.dmg` (fork rebased onto upstream r16789, which is upstream's 1.7.19)
  has `sha256 bfe4c4ed8cdbd2836bd3a24e23377be8505781374934b2e3a98ee236bbd1e1d3`
- the first `Skim-1.7.17.dmg` published had invalidated nested code signatures: the embedded
  frameworks are signed when copied in and the release build then stripped their headers, leaving
  seals that referenced files which no longer existed, so Gatekeeper reported `"Skim" is damaged and
  can't be opened`. The current payload is re-signed and verifies clean.

## Tracking upstream

Upstream Skim lives in Subversion; `./sync-upstream.sh` rebases this fork onto the latest revision.
