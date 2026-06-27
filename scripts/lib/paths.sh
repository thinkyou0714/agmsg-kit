#!/usr/bin/env bash
# paths.sh — single source of truth for agmsg-kit parameter/path resolution.
# Source me; do not execute. Resolution order: existing env > .env file > default.
#
# All knobs are AGMSG_*; install.sh and the tests source this so there is one
# place where defaults live and one place .env is loaded.

# Repo root (this file is at scripts/lib/paths.sh).
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    AGMSG_KIT_ROOT="${AGMSG_KIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
else
    AGMSG_KIT_ROOT="${AGMSG_KIT_ROOT:-$PWD}"
fi

# Load .env if present (simple KEY=VALUE lines; never committed). Existing
# environment wins, so per-invocation overrides are not clobbered by the file.
if [ -f "$AGMSG_KIT_ROOT/.env" ]; then
    while IFS='=' read -r _k _v; do
        case "$_k" in ''|\#*) continue ;; esac
        _k="${_k%"${_k##*[![:space:]]}"}"   # rtrim key
        [ -n "${!_k:-}" ] || printf -v "$_k" '%s' "$_v"
        export "${_k?}"
    done < "$AGMSG_KIT_ROOT/.env"
    unset _k _v
fi

AGMSG_CMD="${AGMSG_CMD:-agmsg}"
AGMSG_TEAM="${AGMSG_TEAM:-team}"
AGMSG_CC="${AGMSG_CC:-cc}"
AGMSG_CO="${AGMSG_CO:-codex}"
AGMSG_PROJECT="${AGMSG_PROJECT:-$PWD}"
AGMSG_UPSTREAM="${AGMSG_UPSTREAM:-https://github.com/fujibee/agmsg.git}"
# Pinned upstream commit (fujibee/agmsg v1.1.2). See VENDORED.md.
AGMSG_PIN="${AGMSG_PIN:-9110be3154c4b00cfaebd8c91dcd393e1b59be5d}"
AGMSG_SKILL_DIR="${AGMSG_SKILL_DIR:-$HOME/.agents/skills/$AGMSG_CMD}"

export AGMSG_KIT_ROOT AGMSG_CMD AGMSG_TEAM AGMSG_CC AGMSG_CO AGMSG_PROJECT \
    AGMSG_UPSTREAM AGMSG_PIN AGMSG_SKILL_DIR
