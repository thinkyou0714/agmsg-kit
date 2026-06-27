# Vendored upstream

agmsg-kit does **not** commit a copy of fujibee/agmsg. `install.sh` fetches it at
a pinned commit and applies the patches in `patches/`. This keeps the kit small,
makes every local change reviewable as a real diff, and lets those diffs go
upstream as PRs.

- **Upstream:** <https://github.com/fujibee/agmsg> (MIT)
- **Pinned:** `v1.1.1` = `b4492e2019a140938292b7684bd3bad23c2774f5`
- **Reviewed:** 2026-06-25

> **v1.1.0 → v1.1.1 bump (2026-06-25):** gains upstream's `delivery.sh`
> `kill_all_watchers` `(project,type)` scoping fix, Monitor-arg `printf %q`
> quoting (#188), watcher session-death teardown (#67), and the `grok-build`
> driver. All 5 kit patches verified to apply cleanly to v1.1.1; the bugs they
> fix all still persist upstream.

## Patch set (applied in order by `install.sh`)

| Patch | What | Status |
|---|---|---|
| `0010-send-escape-all-sql-fields.patch` | `send.sh` escapes `team/from/to/body` as SQL string literals (upstream escapes only `body`). | PR-ready |
| `0011-check-inbox-handle-suggest-identity.patch` | `check-inbox.sh` treats whoami `suggest=true` like `not_joined` + anchors `^agent=`. | PR-ready |
| `0012-rename-escape-sql-identifiers.patch` | `rename.sh`/`rename-team.sh` escape SQL identifiers in the `UPDATE`s. | PR-ready |
| `0013-send-body-size-limit.patch` | `send.sh` rejects oversized bodies (`AGMSG_MAX_BODY_BYTES`; platform-aware default) — runaway cap **and** avoids the `Argument list too long` crash from passing the whole INSERT as one `sqlite3` arg (~32K Windows cmdline limit). | PR-ready |
| `0014-validate-agent-name.patch` | adds `agmsg_validate_agent_name` (rejects `. / \ " [ ]` / control), called in `join.sh` — closes the `$.agents.$NAME` JSON-path misrouting. **Stricter than upstream** (rejects exotic names); conservative charset. | PR-ready |
| `0015-send-sql-via-stdin.patch` | `send.sh` pipes the INSERT to `sqlite3` via stdin (not argv) — removes the ARG_MAX `Argument list too long` crash for large bodies. Stacks on 0010/0013. | PR-ready |

All six verified to apply cleanly to the pinned commit (in numeric order) and to
pass `bash -n` + the smoke roundtrip + behavioral 0013/0014/0015 tests. (0010,
0013, 0015 all touch `send.sh`; 0015 is generated to stack on 0010+0013.)

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
