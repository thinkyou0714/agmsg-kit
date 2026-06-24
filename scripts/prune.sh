#!/usr/bin/env bash
set -euo pipefail

# prune.sh — delete READ messages older than N days (default 30).
#
# UNREAD messages are NEVER touched (the WHERE clause is guarded on
# read_at IS NOT NULL). Run backup.sh first if you want an archive.
#
# Usage: prune.sh [DAYS]

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib/paths.sh
. "$ROOT/scripts/lib/paths.sh"

DAYS="${1:-30}"
case "$DAYS" in ''|*[!0-9]*) echo "usage: prune.sh [DAYS]" >&2; exit 1 ;; esac

DB="${AGMSG_STORAGE_PATH:-$AGMSG_SKILL_DIR/db}/messages.db"
[ -f "$DB" ] || { echo "agmsg-kit: no DB at $DB"; exit 0; }

before="$(sqlite3 "$DB" 'SELECT count(*) FROM messages;' 2>/dev/null || echo 0)"
sqlite3 "$DB" "DELETE FROM messages WHERE read_at IS NOT NULL AND created_at < strftime('%Y-%m-%dT%H:%M:%SZ','now','-$DAYS days');"
after="$(sqlite3 "$DB" 'SELECT count(*) FROM messages;' 2>/dev/null || echo 0)"

echo "agmsg-kit: pruned $((before - after)) read message(s) older than ${DAYS}d (${before} -> ${after})"
