# Vendored upstream

agmsg-kit does **not** commit a copy of fujibee/agmsg. `install.sh` fetches it at
a pinned commit and applies the patches in `patches/`. This keeps the kit small,
makes every local change reviewable as a real diff, and lets those diffs go
upstream as PRs.

- **Upstream:** <https://github.com/fujibee/agmsg> (MIT)
- **Pinned:** `v1.1.0` = `e3031b8336e4cde99af863718d318df436e74206`
- **Reviewed:** 2026-06-24

## Patch set (applied in order by `install.sh`)

| Patch | What | Status |
|---|---|---|
| `0010-send-escape-all-sql-fields.patch` | `send.sh` escapes `team/from/to/body` as SQL string literals (upstream escapes only `body`). Correctness + injection hardening. | PR-ready |
| `0011-check-inbox-handle-suggest-identity.patch` | `check-inbox.sh` treats whoami `suggest=true` like `not_joined`, and anchors `^agent=` so it can't substring-match `agents=`. | PR-ready |

Both verified to apply cleanly to the pinned commit and to pass `bash -n` +
the smoke roundtrip.

## Why the patch set is small (verify, don't assume)

Three fixes considered during research were **already resolved upstream at
v1.1.0** and were therefore dropped rather than shipped blindly:

- **Windows `char(31)` / CRLF "winfix" — SUPERSEDED.** v1.1.0 added an
  `agmsg_sqlite` wrapper that probes and uses `-escape off` (sqlite ≥ 3.50) to
  keep raw record separators, plus `agmsg_sqlite_mem` (`tr -d '\r'`) and
  `cygpath -w` for `readfile()` paths. This is a cleaner fix than the older
  hand-applied `char(31)→char(9)` patch. **Do NOT reintroduce that patch on
  ≥ v1.1.0** — it would fight upstream's solution.
- **Windows `claude.exe` SessionStart dedup — FIXED.** `session-start.sh` now
  resolves the agent PID via `agmsg_agent_pid <type>` (matches per-type
  binaries, incl. `claude.exe`).
- **`history.sh` reverse portability — already `tail -r || tac || awk`.**

## Pending upstream (not in our patch set)

- PR #211 (MSYS2 compat shim) — open at review time.
- Issue #197 (MSYS `/c/` path to native `sqlite3`) — open; partially mitigated
  by v1.1.0's `cygpath` handling.

## Bumping the pin

See `make refresh-patches`. After changing `AGMSG_PIN` (`.env.example` +
`scripts/lib/paths.sh`), regenerate each patch against the new commit, re-run
`make verify-patches`, and update the SHA + date + drift notes above.
