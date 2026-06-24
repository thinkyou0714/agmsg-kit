#!/usr/bin/env bash
set -euo pipefail

# bump-version.sh — bump VERSION and seed a CHANGELOG section.
# Usage: scripts/bump-version.sh <patch|minor|major|X.Y.Z>
# Does NOT commit or tag.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
arg="${1:?Usage: bump-version.sh <patch|minor|major|X.Y.Z>}"
cur="$(tr -d '[:space:]' < "$ROOT/VERSION")"
IFS=. read -r MA MI PA <<<"$cur"

case "$arg" in
    major) new="$((MA + 1)).0.0" ;;
    minor) new="$MA.$((MI + 1)).0" ;;
    patch) new="$MA.$MI.$((PA + 1))" ;;
    [0-9]*.[0-9]*.[0-9]*) new="$arg" ;;
    *) echo "bump: invalid arg '$arg'" >&2; exit 1 ;;
esac

printf '%s\n' "$new" > "$ROOT/VERSION"

# Seed a CHANGELOG section under the title if not already present.
if ! grep -q "^## \[$new\]" "$ROOT/CHANGELOG.md"; then
    tmp="$(mktemp)"
    awk -v ver="$new" '
        /^# / && !done { print; print ""; print "## [" ver "] - UNRELEASED"; print ""; print "### Added"; print ""; print "### Changed"; print ""; print "### Fixed"; print ""; done=1; next }
        { print }
    ' "$ROOT/CHANGELOG.md" > "$tmp"
    mv "$tmp" "$ROOT/CHANGELOG.md"
fi

echo "bumped $cur -> $new (fill the CHANGELOG section, then commit + tag v$new)"
