# Vendored upstream

agmsg-kit does **not** commit a copy of fujibee/agmsg. `install.sh` fetches it at
a pinned commit and applies the patches in `patches/`. This keeps the kit small,
makes every local change reviewable as a real diff, and lets those diffs go
upstream as PRs.

- **Upstream:** <https://github.com/fujibee/agmsg> (MIT)
- **Pinned:** `v1.1.2` = `9110be3154c4b00cfaebd8c91dcd393e1b59be5d`
- **Reviewed:** 2026-06-27

> **v1.1.1 → v1.1.2 bump (2026-06-27):** our `suggest=` fix was **merged upstream**
> (PR #224) and ships in v1.1.2, so **patch 0011 was dropped**. At the v1.1.2 tag
> the escaping (0010/0012) and ARG_MAX (0015) bugs are still present, so those
> patches remain; the maintainer is folding equivalent escaping into #221 (will
> retire 0010/0012 once released). All 5 remaining patches regenerated + verified
> against v1.1.2.

## Patch set (applied in order by `install.sh`)

| Patch | What | Status |
|---|---|---|
| `0010-send-escape-all-sql-fields.patch` | `send.sh` escapes `team/from/to/body` as SQL string literals (upstream escapes only `body`). | PR #223 (→ superseded by upstream #221) |
| `0012-rename-escape-sql-identifiers.patch` | `rename.sh`/`rename-team.sh` escape SQL identifiers in the `UPDATE`s. | with #223 (→ #221) |
| `0013-send-body-size-limit.patch` | `send.sh` rejects oversized bodies (`AGMSG_MAX_BODY_BYTES`; platform-aware default) — runaway cap **and** avoids the `Argument list too long` crash from passing the whole INSERT as one `sqlite3` arg (~32K Windows cmdline limit). | PR-ready |
| `0014-validate-agent-name.patch` | adds `agmsg_validate_agent_name` (rejects `. / \ " [ ]` / control), called in `join.sh` — closes the `$.agents.$NAME` JSON-path misrouting. **Stricter than upstream**; conservative charset. | PR #242 (maintainer-tracked follow-up) |
| `0015-send-sql-via-stdin.patch` | `send.sh` pipes the INSERT to `sqlite3` via stdin (not argv) — removes the ARG_MAX `Argument list too long` crash for large bodies. Stacks on 0010/0013. | PR #241 |

All five verified to apply cleanly to the pinned commit (in numeric order) and to
pass `bash -n` + the smoke roundtrip + behavioral 0013/0014/0015 tests. (0010,
0013, 0015 all touch `send.sh`; 0015 is generated to stack on 0010+0013.)

> **0011 (`suggest=`) was merged upstream** (PR #224, in v1.1.2) and is no longer
> a kit patch. PRs #241/#242 are open; #223 (0010/0012) will close in favor of #221.

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
