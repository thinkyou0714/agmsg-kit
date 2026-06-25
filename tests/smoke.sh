#!/usr/bin/env bash
# smoke.sh — agmsg-kit integration smoke.
#
# Clones the pinned upstream, applies the kit patch set, and exercises a real
# send -> inbox -> history roundtrip plus the patch regressions. Needs network
# for the clone unless AGMSG_SMOKE_CLONE points at an existing v1.1.0 checkout.
#
# No `set -e`: every check runs so the full picture prints; exit code = #fails.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib/paths.sh
. "$ROOT/scripts/lib/paths.sh"

fail=0
pass() { printf '  ok   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "== syntax =="
for f in "$ROOT"/install.sh "$ROOT"/uninstall.sh "$ROOT"/scripts/*.sh "$ROOT"/scripts/lib/*.sh "$ROOT"/tests/*.sh; do
    [ -f "$f" ] || continue
    if bash -n "$f" 2>/dev/null; then pass "bash -n $(basename "$f")"; else bad "bash -n $(basename "$f")"; fi
done

echo "== secret_redact =="
if python3 "$ROOT/home/lib/secret_redact.py" --selftest >/dev/null 2>&1; then
    pass "secret_redact --selftest"
else
    bad "secret_redact --selftest"
fi

echo "== upstream clone + patches =="
CLONE="${AGMSG_SMOKE_CLONE:-}"
if [ -z "$CLONE" ]; then
    CLONE="$(mktemp -d)/agmsg"
    if git -c advice.detachedHead=false -c core.autocrlf=false clone -q --depth 1 --branch v1.1.1 "$AGMSG_UPSTREAM" "$CLONE" 2>/dev/null; then
        pass "clone upstream v1.1.1"
    else
        bad "clone upstream (network unavailable?)"
        echo; echo "smoke: $fail FAIL"; exit "$fail"
    fi
fi
git -C "$CLONE" config core.autocrlf false 2>/dev/null || true

for p in "$ROOT"/patches/*.patch; do
    [ -f "$p" ] || continue
    n="$(basename "$p")"
    if git -C "$CLONE" apply --check "$p" 2>/dev/null; then
        if git -C "$CLONE" apply "$p" 2>/dev/null; then pass "apply $n"; else bad "apply $n"; fi
    elif git -C "$CLONE" apply --reverse --check "$p" 2>/dev/null; then
        pass "apply $n (already applied)"
    else
        bad "apply $n (does not fit the pinned commit)"
    fi
done

echo "== roundtrip (patched send.sh -> DB) =="
# Assert delivery by querying the DB directly: this tests what the KIT changes
# (send.sh's INSERT + escaping). inbox.sh's *display* uses upstream's char(31)
# rendering, whose byte-handling varies by sqlite version/OS — so we assert it
# RUNS, not its exact formatting.
AGMSG_STORAGE_PATH="$(mktemp -d)"
export AGMSG_STORAGE_PATH
SKS="$CLONE/scripts"
DB="$AGMSG_STORAGE_PATH/messages.db"
bash "$SKS/send.sh" t cc codex "hello roundtrip" >/dev/null 2>&1 || bad "send.sh exited non-zero"
if [ -f "$DB" ] && sqlite3 "$DB" "SELECT body FROM messages WHERE team='t' AND to_agent='codex';" 2>/dev/null | grep -qF "hello roundtrip"; then
    pass "send.sh inserted message (DB roundtrip)"
else
    bad "send.sh did not insert the message"
fi
if bash "$SKS/inbox.sh" t codex >/dev/null 2>&1; then pass "inbox.sh runs"; else bad "inbox.sh errored"; fi
if bash "$SKS/history.sh" t >/dev/null 2>&1; then pass "history.sh runs"; else bad "history.sh errored"; fi

echo "== 0010 regression: quoted from_agent stored intact (no SQL break) =="
if bash "$SKS/send.sh" t "O'Brien" codex "quoted-ok" >/dev/null 2>&1 \
    && sqlite3 "$DB" "SELECT from_agent FROM messages WHERE body='quoted-ok';" 2>/dev/null | grep -qF "O'Brien"; then
    pass "single-quote in from_agent escaped + stored"
else
    bad "0010: a single-quote in from_agent broke the INSERT"
fi

echo "== 0011 regression: suggest= guard (portable + behavioral) =="
if grep -qF 'grep -Eq "not_joined=true|suggest=true"' "$CLONE/scripts/check-inbox.sh" \
    && grep -qF "sed -n 's/^agent=" "$CLONE/scripts/check-inbox.sh"; then
    pass "check-inbox uses portable suggest= guard + ^agent= anchor"
else
    bad "0011: suggest= guard non-portable (BSD grep) or ^agent= anchor missing"
fi
# The alternation must actually fire with THIS platform's grep (catches the BSD
# vs GNU '\|' trap that a static file check would mask).
if printf '%s' 'suggest=true agents=a,b teams=lab' | grep -Eq "not_joined=true|suggest=true"; then
    pass "suggest= alternation fires (portable ERE)"
else
    bad "suggest= alternation does not fire on this platform's grep"
fi

echo "== 0012 regression: rename* escape SQL identifiers =="
if grep -qF '_agmsg_sqlesc "$NEW_NAME"' "$CLONE/scripts/rename.sh" \
    && grep -qF '_agmsg_sqlesc "$NEW_TEAM"' "$CLONE/scripts/rename-team.sh"; then
    pass "rename/rename-team escape SQL identifiers"
else
    bad "0012: rename SQL-escape missing"
fi
if bash -n "$CLONE/scripts/rename.sh" 2>/dev/null && bash -n "$CLONE/scripts/rename-team.sh" 2>/dev/null; then
    pass "patched rename* syntax OK"
else
    bad "patched rename* syntax error"
fi

echo "== 0013 body-size guard =="
big="$(head -c 20000 /dev/zero | tr '\0' x)"
if AGMSG_MAX_BODY_BYTES=16000 bash "$SKS/send.sh" t cc codex "$big" >/dev/null 2>&1; then
    bad "0013: oversized body not rejected"
else
    pass "0013: rejects oversized body"
fi
if bash "$SKS/send.sh" t cc codex "ok small body" >/dev/null 2>&1; then pass "0013: allows normal body"; else bad "0013: blocked a normal body"; fi

echo "== 0014 agent-name validation =="
vproj="$(mktemp -d)"
if bash "$SKS/join.sh" t cc claude-code "$vproj" >/dev/null 2>&1; then pass "0014: accepts valid name"; else bad "0014: rejected a valid name"; fi
if bash "$SKS/join.sh" t "bad.name" codex "$vproj" >/dev/null 2>&1; then bad "0014: accepted dotted name"; else pass "0014: rejects dotted (JSON-path) name"; fi

echo "== prune.sh (behavioral) =="
PDB="$AGMSG_STORAGE_PATH/messages.db"
sqlite3 "$PDB" "INSERT INTO messages (team,from_agent,to_agent,body,created_at,read_at) VALUES ('t','cc','codex','OLD-READ',strftime('%Y-%m-%dT%H:%M:%SZ','now','-100 days'),strftime('%Y-%m-%dT%H:%M:%SZ','now','-100 days'));" 2>/dev/null
sqlite3 "$PDB" "INSERT INTO messages (team,from_agent,to_agent,body,created_at) VALUES ('t','cc','codex','NEW-UNREAD',strftime('%Y-%m-%dT%H:%M:%SZ','now'));" 2>/dev/null
bash "$ROOT/scripts/prune.sh" 30 >/dev/null 2>&1
gone="$(sqlite3 "$PDB" "SELECT count(*) FROM messages WHERE body='OLD-READ';" 2>/dev/null)"
kept="$(sqlite3 "$PDB" "SELECT count(*) FROM messages WHERE body='NEW-UNREAD';" 2>/dev/null)"
if [ "$gone" = 0 ] && [ "$kept" = 1 ]; then pass "prune deletes old READ, keeps recent UNREAD"; else bad "prune wrong (old-read=$gone unread=$kept)"; fi
if bash "$ROOT/scripts/prune.sh" 0 >/dev/null 2>&1; then bad "prune did not reject DAYS=0"; else pass "prune rejects DAYS=0"; fi

echo
if [ "$fail" = 0 ]; then echo "smoke: PASS"; else echo "smoke: $fail FAIL"; fi
exit "$fail"
