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

# Flush WAL into the main DB to minimize the live -wal that gets copied. This is
# a non-exclusive (hot) copy: a writer active during the cp may leave the
# snapshot slightly behind, but SQLite recovers a partial WAL on open, so the
# backup is still usable. Stop the agents first if you want an exact snapshot.
if [ -f "$DBDIR/messages.db" ]; then
    sqlite3 "$DBDIR/messages.db" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1 || true
fi

# The DB copy is the critical artifact — fail loudly so a half-made backup can't
# be mistaken for a good one (e.g. before a prune). teams/ is secondary.
cp -r "$DBDIR" "$DEST/db" || { echo "agmsg-kit: backup FAILED — could not copy $DBDIR -> $DEST/db" >&2; exit 1; }
[ -d "$SK/teams" ] && { cp -r "$SK/teams" "$DEST/teams" 2>/dev/null || true; }

# Count from the BACKUP, not the live DB, so the number reflects what was captured.
count="$(sqlite3 "$DEST/db/messages.db" 'SELECT count(*) FROM messages;' 2>/dev/null || echo '?')"
echo "agmsg-kit: backed up store ($count messages) + teams -> $DEST"
