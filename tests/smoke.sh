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
    if git -c advice.detachedHead=false -c core.autocrlf=false clone -q --depth 1 --branch v1.1.0 "$AGMSG_UPSTREAM" "$CLONE" 2>/dev/null; then
        pass "clone upstream v1.1.0"
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

echo "== roundtrip (patched scripts) =="
AGMSG_STORAGE_PATH="$(mktemp -d)"
export AGMSG_STORAGE_PATH
SKS="$CLONE/scripts"
bash "$SKS/send.sh" t cc codex "hello roundtrip" >/dev/null 2>&1 || bad "send"
if bash "$SKS/inbox.sh" t codex 2>/dev/null | grep -qF "hello roundtrip"; then
    pass "send -> inbox roundtrip"
else
    bad "send -> inbox roundtrip"
fi
if bash "$SKS/history.sh" t >/dev/null 2>&1; then pass "history runs"; else bad "history"; fi

echo "== 0010 regression: quoted identity must not break the INSERT =="
if bash "$SKS/send.sh" t "O'Brien" codex "quoted-from-ok" >/dev/null 2>&1 \
    && bash "$SKS/inbox.sh" t codex 2>/dev/null | grep -qF "quoted-from-ok"; then
    pass "send from O'Brien (SQL-escaped) roundtrip"
else
    bad "0010: a single-quote in from_agent broke send/inbox"
fi

echo "== 0011 regression: suggest= guard present in patched check-inbox.sh =="
if grep -qF 'not_joined=true\|suggest=true' "$CLONE/scripts/check-inbox.sh" \
    && grep -qF "sed -n 's/^agent=" "$CLONE/scripts/check-inbox.sh"; then
    pass "check-inbox handles suggest= + anchors ^agent="
else
    bad "0011: suggest= guard or ^agent= anchor missing"
fi

echo
if [ "$fail" = 0 ]; then echo "smoke: PASS"; else echo "smoke: $fail FAIL"; fi
exit "$fail"
