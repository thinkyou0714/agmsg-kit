#!/usr/bin/env bash
# test_safety.sh — redaction + patch-integrity guards. No network needed.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
pass() { printf '  ok   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

LIB="$ROOT/home/lib/secret_redact.py"

echo "== secret_redact =="
if python3 "$LIB" --selftest >/dev/null 2>&1; then pass "--selftest 8/8"; else bad "--selftest"; fi

out="$(printf 'Authorization: Bearer abcdef0123456789ABCDEF\n' | python3 "$LIB")"
if printf '%s' "$out" | grep -q '\*\*\*' && ! printf '%s' "$out" | grep -q 'abcdef0123456789'; then
    pass "Bearer token redacted via stdin"
else
    bad "Bearer token not redacted: $out"
fi

out="$(printf 'token=abcdef0123456789ABCDEFGH\n' | python3 "$LIB")"
if printf '%s' "$out" | grep -qF 'token=***'; then pass "token= redacted"; else bad "token= not redacted: $out"; fi

echo "== patch integrity =="
n=0
for p in "$ROOT"/patches/*.patch; do
    [ -f "$p" ] || continue
    n=$((n + 1))
    if [ -s "$p" ] && head -1 "$p" | grep -q '^diff --git'; then
        pass "well-formed patch $(basename "$p")"
    else
        bad "malformed/empty patch $(basename "$p")"
    fi
done
if [ "$n" -ge 3 ]; then pass "patch set present ($n patches)"; else bad "expected >=3 patches, found $n"; fi

# Guard: 0012 escapes identifiers in both rename scripts.
P0012="$ROOT/patches/0012-rename-escape-sql-identifiers.patch"
if [ -f "$P0012" ] && grep -qF '_agmsg_sqlesc "$NEW_NAME"' "$P0012" && grep -qF '_agmsg_sqlesc "$NEW_TEAM"' "$P0012"; then
    pass "0012 escapes rename + rename-team identifiers"
else
    bad "0012 missing rename identifier escaping"
fi

# Guard: 0011 uses the portable grep -Eq form (not GNU-only \|).
P0011="$ROOT/patches/0011-check-inbox-handle-suggest-identity.patch"
if grep -qF 'grep -Eq "not_joined=true|suggest=true"' "$P0011"; then
    pass "0011 uses portable grep -Eq"
else
    bad "0011 not using portable grep -Eq (BSD grep would no-op)"
fi

# Guard: the SQL-escaping fix must escape all four interpolated fields.
P0010="$ROOT/patches/0010-send-escape-all-sql-fields.patch"
if grep -qF '_agmsg_sqlesc "$TEAM"' "$P0010" && grep -qF '_agmsg_sqlesc "$FROM"' "$P0010" \
    && grep -qF '_agmsg_sqlesc "$TO"' "$P0010" && grep -qF '_agmsg_sqlesc "$BODY"' "$P0010"; then
    pass "0010 escapes team/from/to/body"
else
    bad "0010 does not escape all four fields"
fi

echo "== opt-in failure log (AGMSG_FAILURE_LOG) =="
flog="$(mktemp)"
# Trigger a die() via an unknown flag; assert a redacted JSON line is appended.
AGMSG_FAILURE_LOG="$flog" bash "$ROOT/install.sh" --bogus-flag-xyz >/dev/null 2>&1
if [ -s "$flog" ] && grep -q '"hook":"agmsg-kit"' "$flog" && grep -q '"event":"install_fail"' "$flog"; then
    pass "failure logged as JSON to AGMSG_FAILURE_LOG"
else
    bad "no JSON failure line written"
fi
# Valid JSON?
if python3 -c 'import json,sys; [json.loads(l) for l in open(sys.argv[1]) if l.strip()]' "$flog" 2>/dev/null; then
    pass "failure log lines are valid JSON"
else
    bad "failure log line is not valid JSON"
fi
# Default OFF: AGMSG_FAILURE_LOG unset in this shell -> die path unchanged.
out="$(bash "$ROOT/install.sh" --bogus-flag-xyz 2>&1)"
if printf '%s' "$out" | grep -q 'unknown arg'; then pass "still dies cleanly with log off"; else bad "die path changed with log off"; fi

echo
if [ "$fail" = 0 ]; then echo "test_safety: PASS"; else echo "test_safety: $fail FAIL"; fi
exit "$fail"
