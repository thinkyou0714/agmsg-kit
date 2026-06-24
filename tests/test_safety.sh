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
if [ "$n" -ge 2 ]; then pass "patch set present ($n patches)"; else bad "expected >=2 patches, found $n"; fi

# Guard: the SQL-escaping fix must escape all four interpolated fields.
P0010="$ROOT/patches/0010-send-escape-all-sql-fields.patch"
if grep -qF '_agmsg_sqlesc "$TEAM"' "$P0010" && grep -qF '_agmsg_sqlesc "$FROM"' "$P0010" \
    && grep -qF '_agmsg_sqlesc "$TO"' "$P0010" && grep -qF '_agmsg_sqlesc "$BODY"' "$P0010"; then
    pass "0010 escapes team/from/to/body"
else
    bad "0010 does not escape all four fields"
fi

echo
if [ "$fail" = 0 ]; then echo "test_safety: PASS"; else echo "test_safety: $fail FAIL"; fi
exit "$fail"
