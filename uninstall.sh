#!/usr/bin/env bash
set -euo pipefail

# agmsg-kit uninstaller — conservative. Disables delivery wiring for this
# project and points you at the upstream uninstaller for full removal.
# NEVER deletes the message DB or team registrations.
#
# Usage:
#   ./uninstall.sh [--dry-run] [--cmd NAME] [--project PATH]

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/paths.sh
. "$ROOT/scripts/lib/paths.sh"

DRY_RUN=0
say() { printf '  %s\n' "$*"; }
run() { local d="$1"; shift; if [ "$DRY_RUN" = 1 ]; then say "[dry-run] $d"; else say "$d"; "$@"; fi; }

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --cmd) AGMSG_CMD="$2"; AGMSG_SKILL_DIR="$HOME/.agents/skills/$2"; shift 2 ;;
        --project) AGMSG_PROJECT="$2"; shift 2 ;;
        -h|--help) sed -n '4,11p' "$0"; exit 0 ;;
        *) printf 'agmsg-kit: unknown arg: %s\n' "$1" >&2; exit 1 ;;
    esac
done

SK="$AGMSG_SKILL_DIR"
if [ -d "$SK/scripts" ]; then
    run "delivery: off (claude-code)" bash "$SK/scripts/delivery.sh" set off claude-code "$AGMSG_PROJECT"
    run "delivery: off (codex)"       bash "$SK/scripts/delivery.sh" set off codex "$AGMSG_PROJECT"
else
    say "skill not installed at $SK — nothing to unwire."
fi

cat <<EOF

Delivery wiring removed for: $AGMSG_PROJECT
Your messages (db/) and team registrations (teams/) are preserved.

To fully remove the skill (DB optionally kept), use the upstream uninstaller:
  ~/.agents/skills/$AGMSG_CMD/uninstall.sh        # if present
  # or, if installed as a Claude Code plugin:
  /plugin uninstall agmsg
EOF
