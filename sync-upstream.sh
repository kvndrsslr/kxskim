#!/bin/sh

# Rebase this fork onto the latest upstream Skim revision.
#
# Upstream lives in Subversion; the local mirror at $SKIM_UPSTREAM_MIRROR is a git-svn clone of it.
# See the "Tracking upstream" section of README.md for the one-time setup.

set -e

MIRROR="${SKIM_UPSTREAM_MIRROR:-$HOME/src/skim-upstream}"
FORK_DIR=$(cd "$(dirname "$0")" && pwd)
PATCHES="${TMPDIR:-/tmp}/skim-fork-patches"

if [ ! -d "$MIRROR/.git" ]; then
    echo "error: no upstream mirror at $MIRROR" >&2
    echo "create it with:" >&2
    echo "  git svn clone --log-window-size=5000 -T trunk -b branches -t tags \\" >&2
    echo "    https://svn.code.sf.net/p/skim-app/code $MIRROR" >&2
    exit 1
fi

cd "$FORK_DIR"

if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
    echo "error: a rebase is already in progress; finish or abort it first" >&2
    exit 1
fi

# untracked files are fine; a rebase only fails if one of them collides with an upstream addition
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "error: the working tree has uncommitted changes; commit or stash first" >&2
    exit 1
fi

BRANCH=$(git -C "$MIRROR" symbolic-ref --short HEAD 2>/dev/null || echo master)

echo "==> fetching upstream SVN into $MIRROR"
git -C "$MIRROR" svn fetch

echo "==> updating the upstream remote"
git fetch --quiet upstream

BEFORE=$(git rev-parse HEAD)
TARGET="upstream/$BRANCH"

if git merge-base --is-ancestor "$TARGET" HEAD; then
    echo "==> already up to date with $TARGET ($(git rev-parse --short "$TARGET"))"
    exit 0
fi

rm -rf "$PATCHES"
git format-patch --quiet -o "$PATCHES" "$TARGET..HEAD" >/dev/null
echo "==> saved fork patches to $PATCHES"

echo "==> rebasing onto $TARGET ($(git rev-parse --short "$TARGET"))"
if git rebase "$TARGET"; then
    echo "==> rebase complete"
else
    echo "error: rebase stopped; resolve the conflicts, then run 'git rebase --continue'" >&2
    echo "the fork patches are in $PATCHES" >&2
    exit 1
fi

echo "==> fork commits on top of upstream:"
git log --oneline "$TARGET..HEAD"

echo "==> comparing the rebase with the previous history:"
git range-diff "$TARGET..$BEFORE" "$TARGET..HEAD" || true

echo
echo "review and build, then push with: git push --force-with-lease origin main"
