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
The toolbar hides with it, and the side panes and the find bar keep their top inset clear of that
strip, so the contents pane's tab buttons and search field, and the find bar's search field,
Find Previous/Next and Done, all stay clickable while the chrome is hidden. Viewport padding and
page gap settings live in **Settings → General**; the page gap separates pages in the single-page
continuous modes, and in the two-up and book modes it only separates spreads, so the two pages of a
spread touch. In horizontal continuous display mode
the Contents pane's destinations keep the start of the target page clear of the pane, and a jump
briefly highlights the destination. Page edges stay clean: on dark backgrounds the page fill follows
the pane color, and an overlay repaints the outermost device pixels of every page edge with the
page's own content, so PDFKit's 1px antialiasing line no longer shows on dark art pages or between
light pages, in every display mode.

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
- the current `Skim-1.7.17.1.dmg` (fork rebased onto upstream r16706, upstream trunk still reports
  1.7.17) has `sha256 4dbb78204d684b46f9168dbf3ed53fe34bf57e52aa650adc4b5bf04e892d438a`
- the first `Skim-1.7.17.dmg` published had invalidated nested code signatures: the embedded
  frameworks are signed when copied in and the release build then stripped their headers, leaving
  seals that referenced files which no longer existed, so Gatekeeper reported `"Skim" is damaged and
  can't be opened`. The current payload is re-signed and verifies clean.

## Tracking upstream

Upstream Skim is developed in Subversion at `svn://svn.code.sf.net/p/skim-app/code`
(`trunk`, `branches`, `tags`); there is no maintained Git mirror. This fork tracks it through a
local git-svn clone, so upstream history stays queryable in Git:

```sh
brew install git-svn
git svn clone --log-window-size=5000 -r 16690:HEAD -T trunk \
  https://svn.code.sf.net/p/skim-app/code ~/src/skim-upstream

cd ~/repos/private/skim
git remote add upstream ~/src/skim-upstream
git fetch upstream
```

Branch roles:

- `main` carries only the fork's own commits, rebased on top of upstream; `git log
  upstream/main..main` lists exactly the fork's delta.
- `upstream/main` is the git-svn mirror, fetched read-only. Its commit hashes are rewritten by
  git-svn, so they are never referenced from published history.

Sync with `./sync-upstream.sh`: it runs `git svn fetch` in the mirror, updates `upstream/main`,
saves the fork commits as patches to `$TMPDIR/skim-fork-patches`, rebases `main`, and prints a
`git range-diff` of the rebase. Rebase conflict resolutions are reused through `git rerere`
(`git config rerere.enabled true`). The rebase rewrites history, so publish with
`git push --force-with-lease origin main`; the cask consumes release artifacts, not commits.

The clone starts at r16690 rather than r1: rebasing needs a base whose tree is upstream's current
state, not twenty years of binary churn, and the full import takes hours. Later `git svn fetch`
calls pick up new revisions incrementally.
