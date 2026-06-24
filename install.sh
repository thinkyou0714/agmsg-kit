#!/usr/bin/env bash
set -euo pipefail

# agmsg-kit installer — reproducible, hardened agmsg setup.
#
# Pins fujibee/agmsg at a known commit, applies the kit's PR-ready patch set,
# runs the upstream installer, then joins the team and wires turn-mode delivery.
# Re-runnable: an existing install is updated in place (DB and teams preserved).
#
# Usage:
#   ./install.sh [--dry-run] [--cmd NAME] [--team T] [--cc NAME] [--co NAME]
#                [--project PATH] [--pin SHA] [--from CLONE_DIR] [--no-wire]
#
# Parameters resolve from: flags > .env > defaults (see .env.example).

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/paths.sh
. "$ROOT/scripts/lib/paths.sh"

DRY_RUN=0
FROM=""
WIRE=1

say() { printf '  %s\n' "$*"; }
die() { printf 'agmsg-kit: %s\n' "$*" >&2; exit 1; }
run() {
    local desc="$1"; shift
    if [ "$DRY_RUN" = 1 ]; then say "[dry-run] $desc"; else say "$desc"; "$@"; fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --cmd) AGMSG_CMD="$2"; AGMSG_SKILL_DIR="$HOME/.agents/skills/$2"; shift 2 ;;
        --team) AGMSG_TEAM="$2"; shift 2 ;;
        --cc) AGMSG_CC="$2"; shift 2 ;;
        --co) AGMSG_CO="$2"; shift 2 ;;
        --project) AGMSG_PROJECT="$2"; shift 2 ;;
        --pin) AGMSG_PIN="$2"; shift 2 ;;
        --from) FROM="$2"; shift 2 ;;
        --no-wire) WIRE=0; shift ;;
        -h|--help) sed -n '4,16p' "$0"; exit 0 ;;
        *) die "unknown arg: $1 (try --help)" ;;
    esac
done

say "agmsg-kit: cmd=$AGMSG_CMD team=$AGMSG_TEAM cc=$AGMSG_CC co=$AGMSG_CO"
say "           project=$AGMSG_PROJECT pin=${AGMSG_PIN:0:12}"

# --- Phase 0: dependency checks ---
command -v git >/dev/null 2>&1 || die "git not found"
command -v sqlite3 >/dev/null 2>&1 || die "sqlite3 not found — agmsg requires it (scoop install sqlite / brew install sqlite)"
SQLV="$(sqlite3 --version 2>/dev/null | awk '{print $1}')"
if [ -n "$SQLV" ]; then
    _min="$(printf '%s\n%s\n' "$SQLV" 3.51.3 | sort -V | head -n1)"
    [ "$_min" = 3.51.3 ] || say "WARN: sqlite3 $SQLV < 3.51.3 — the WAL multi-writer corruption fix landed in 3.51.3; upgrade recommended."
fi

# --- Phase 1: clone the pinned upstream (or reuse --from) ---
if [ -n "$FROM" ]; then
    [ -d "$FROM/.git" ] || die "--from $FROM is not a git checkout"
    CLONE="$FROM"
    say "using existing clone: $CLONE"
else
    CLONE="$(mktemp -d)/agmsg"
    run "clone $AGMSG_UPSTREAM @ ${AGMSG_PIN:0:12}" \
        git -c advice.detachedHead=false -c core.autocrlf=false clone -q "$AGMSG_UPSTREAM" "$CLONE"
    run "checkout pinned commit" git -C "$CLONE" -c advice.detachedHead=false checkout -q "$AGMSG_PIN"
fi

# --- Phase 2: apply the kit's patch set (idempotent) ---
if [ "$DRY_RUN" != 1 ]; then
    for p in "$ROOT"/patches/*.patch; do
        [ -f "$p" ] || continue
        name="$(basename "$p")"
        if git -C "$CLONE" apply --check "$p" 2>/dev/null; then
            say "patch $name"; git -C "$CLONE" apply "$p"
        elif git -C "$CLONE" apply --reverse --check "$p" 2>/dev/null; then
            say "patch $name (already applied — skipping)"
        else
            die "patch failed to apply: $name — upstream drift at this pin? See VENDORED.md / 'make refresh-patches'."
        fi
    done
else
    say "[dry-run] would apply $(find "$ROOT"/patches -name '*.patch' 2>/dev/null | wc -l | tr -d ' ') patch(es)"
fi

# --- Phase 3: run the upstream installer against the patched source ---
if [ -f "$AGMSG_SKILL_DIR/.agmsg" ]; then
    run "upstream install --update ($AGMSG_CMD)" bash "$CLONE/install.sh" --cmd "$AGMSG_CMD" --update
else
    run "upstream install ($AGMSG_CMD)" bash "$CLONE/install.sh" --cmd "$AGMSG_CMD"
fi

SK="$AGMSG_SKILL_DIR"
if [ "$DRY_RUN" != 1 ]; then
    [ -d "$SK/scripts" ] || die "upstream install did not produce $SK/scripts"
fi

# --- Phase 4: join + wire turn-mode delivery ---
if [ "$WIRE" = 1 ]; then
    run "join $AGMSG_CC (claude-code)" bash "$SK/scripts/join.sh" "$AGMSG_TEAM" "$AGMSG_CC" claude-code "$AGMSG_PROJECT"
    run "join $AGMSG_CO (codex)"       bash "$SK/scripts/join.sh" "$AGMSG_TEAM" "$AGMSG_CO" codex "$AGMSG_PROJECT"
    run "delivery: turn (claude-code)" bash "$SK/scripts/delivery.sh" set turn claude-code "$AGMSG_PROJECT"
    run "delivery: turn (codex)"       bash "$SK/scripts/delivery.sh" set turn codex "$AGMSG_PROJECT"
    # Born-ignore the machine-local Codex hook so it is never committed.
    if [ "$DRY_RUN" != 1 ]; then
        GD="$(git -C "$AGMSG_PROJECT" rev-parse --absolute-git-dir 2>/dev/null || true)"
        if [ -n "$GD" ]; then
            mkdir -p "$GD/info"
            grep -qxF '.codex/hooks.json' "$GD/info/exclude" 2>/dev/null || echo '.codex/hooks.json' >> "$GD/info/exclude"
        fi
    fi
fi

# --- Phase 5: smoke (cc -> co roundtrip) ---
if [ "$DRY_RUN" != 1 ] && [ "$WIRE" = 1 ]; then
    marker="agmsg-kit smoke $$"
    bash "$SK/scripts/send.sh" "$AGMSG_TEAM" "$AGMSG_CC" "$AGMSG_CO" "$marker" >/dev/null
    if bash "$SK/scripts/inbox.sh" "$AGMSG_TEAM" "$AGMSG_CO" 2>/dev/null | grep -qF "$marker"; then
        say "smoke OK: $AGMSG_CC -> $AGMSG_CO roundtrip"
        DB="${AGMSG_STORAGE_PATH:-$SK/db}/messages.db"
        [ -f "$DB" ] && sqlite3 "$DB" "DELETE FROM messages WHERE body LIKE 'agmsg-kit smoke%';" 2>/dev/null || true
    else
        die "smoke FAILED: $AGMSG_CC -> $AGMSG_CO message not delivered. Your previous install (if any) is unchanged in db/ + teams/."
    fi
fi

say "done."
