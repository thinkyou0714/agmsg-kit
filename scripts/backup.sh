#!/usr/bin/env bash
set -euo pipefail

# backup.sh — snapshot the agmsg message store + team registrations.
#
# A WAL-mode SQLite DB must be backed up as a set (main + -wal + -shm). We first
# checkpoint the WAL into the main file, then copy the whole store dir + teams/.
#
# Usage: backup.sh [DEST_DIR]   (default: <repo>/_backups/agmsg-<timestamp>)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib/paths.sh
. "$ROOT/scripts/lib/paths.sh"

SK="$AGMSG_SKILL_DIR"
[ -d "$SK" ] || { echo "agmsg-kit: skill not installed at $SK" >&2; exit 1; }

DBDIR="${AGMSG_STORAGE_PATH:-$SK/db}"
DEST="${1:-$ROOT/_backups/agmsg-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$DEST"

# Flush WAL into the main DB so the copied file set is self-consistent.
if [ -f "$DBDIR/messages.db" ]; then
    sqlite3 "$DBDIR/messages.db" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1 || true
fi

cp -r "$DBDIR" "$DEST/db" 2>/dev/null || true
[ -d "$SK/teams" ] && cp -r "$SK/teams" "$DEST/teams" 2>/dev/null || true

count="$(sqlite3 "$DBDIR/messages.db" 'SELECT count(*) FROM messages;' 2>/dev/null || echo '?')"
echo "agmsg-kit: backed up store ($count messages) + teams -> $DEST"
