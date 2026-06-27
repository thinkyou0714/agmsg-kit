# Changelog

All notable changes to agmsg-kit. Format follows [Keep a Changelog](https://keepachangelog.com);
this project adheres to [Semantic Versioning](https://semver.org).

## [0.4.0] - 2026-06-27

### Added
- **`patches/0015-send-sql-via-stdin.patch`** — `send.sh` pipes the INSERT to
  `sqlite3` via **stdin** instead of as a command-line argument, **removing the
  ARG_MAX limit entirely**: a large body (code, diffs) that previously crashed
  with `Argument list too long` on Windows (~32K command line) now sends. This is
  the root-cause fix for what 0013 only guarded against. PR-ready.
- Weekly **upstream-drift CI** (`.github/workflows/upstream-drift.yml`) — opens
  (or reuses) an issue when the pinned commit falls behind the latest upstream
  tag, automating `docs/UPSTREAM-REVIEW.md`.

### Changed
- **0013's body-size cap is now a uniform 65536 bytes** (was platform-aware
  Windows-16000). With 0015 there is no command-line size limit, so the cap is
  purely a runaway-payload guard. An invalid `AGMSG_MAX_BODY_BYTES` still falls
  back to the default; `0` disables.

### Notes
- This ships the last high-value `[road]` item (#9b, stdin SQL) + #55 (drift CI).
  The remaining roadmap (referee/turn-enforcer agent, structured message schema,
  schema-migration framework, bats migration, cost metrics, local-LLM summaries)
  is intentionally **not** auto-built — those are architectural choices to make
  on request, not defaults for a focused kit.

## [0.3.1] - 2026-06-27

### Fixed
Three bugs an independent adversarial QA found in v0.3.0's own new code:
- **`backup.sh` silently exited 0 on a failed copy** (`cp … || true`) — a
  half-made backup could be mistaken for a good one before a `prune`, risking
  data loss. The DB copy now fails loudly (exit 1); `teams/` stays best-effort.
- **`patches/0013` counted characters, not bytes** (`${#BODY}`) — multibyte
  UTF-8 (e.g. ~16000 CJK chars ≈ 64 KB) slipped past the guard yet still
  overflowed the Windows command line. Now measures bytes via `printf … | wc -c`.
- **`patches/0013` silently bypassed the guard on an invalid
  `AGMSG_MAX_BODY_BYTES`** (`abc`, `-5`). Now an invalid/empty value falls back
  to the protective platform default; only a valid non-negative integer is
  honored (`0` still disables).

### Notes
- No pin bump: upstream has no new tag since v1.1.1 (`main` moved but unreleased).
- `#8` (wrap check-inbox in `timeout`) deferred with cause: Windows `timeout.exe`
  ≠ GNU `timeout`, and check-inbox is already bounded by `busy_timeout=5000`, so
  it nets ~0 value at real Windows risk — better as an upstream change.

## [0.3.0] - 2026-06-25

### Fixed
- **[security] `install.sh` failure log could leak a secret** — `_log_failure`
  fell back to writing the raw, unredacted message (and unescaped, malformed
  JSON) when `python3` was absent or `json.dumps` failed. Rewritten as a single
  redact→json pipe that **skips the line entirely on any failure** — never writes
  an unredacted byte, always valid JSON. (Found by independent QA.)

### Changed
- **Bumped upstream pin `v1.1.0` → `v1.1.1`** (`b4492e2`). Gains upstream's
  `delivery.sh` fix (`kill_all_watchers` now scoped to `(project,type)` — a
  silent cross-type watcher-teardown bug), Monitor-arg `printf %q` quoting (#188),
  watcher session-death teardown (#67), and the new `grok-build` driver. All kit
  patches verified to apply; the three bugs they fix still persist upstream.
- `backup.sh` now counts from the snapshot (not the live DB) and documents the
  hot-copy trade-off honestly.

### Added
- **`patches/0013-send-body-size-limit.patch`** — `send.sh` rejects oversized
  bodies (`AGMSG_MAX_BODY_BYTES`, default 16000 on Windows / 65536 elsewhere; 0
  disables). Catches runaway payloads **and** the obscure `Argument list too
  long` crash (send passes the whole INSERT as one `sqlite3` arg → overflows the
  ~32K Windows command line). REJECT, not truncate.
- **`patches/0014-validate-agent-name.patch`** — `agmsg_validate_agent_name`
  (rejects `. / \ " [ ]` / control), called in `join.sh`. Closes the
  `$.agents.$NAME` JSON-path misrouting for dotted/bracket names.
- `prune.sh` rejects `DAYS=0` (would delete every read message). Smoke now tests
  prune **behaviorally** (old-read deleted, recent-unread kept) and exercises
  0013/0014.

## [0.2.1] - 2026-06-25

### Added
- Opt-in structured failure logging: set `AGMSG_FAILURE_LOG` to a JSONL path and
  `install.sh` appends a redacted `{"ts","hook":"agmsg-kit","event":"install_fail","detail"}`
  line on failure. Off by default (the public kit writes nowhere); secrets are
  redacted via `secret_redact.py`. Integrates with a personal `failures.jsonl`.

## [0.2.0] - 2026-06-24

### Added
- `patches/0012` — `rename.sh` + `rename-team.sh` escape interpolated SQL
  identifiers (parity with 0010; PR-ready). The JSON-path interpolation in
  `rename.sh` is a separate concern, tracked in `docs/IDEAS.md`.
- `scripts/backup.sh` (`make backup`) — WAL-checkpointed snapshot of the message
  store + teams. `scripts/prune.sh` (`make prune DAYS=N`) — delete READ messages
  older than N days (unread never touched).
- `install.sh`: `--also TYPE:NAME` to join extra agents (e.g. gemini/copilot);
  WSL/Git-Bash HOME-split warning.
- `make doctor` now reports message count, live watcher pidfiles, and teams.
- `docs/WALKTHROUGH.md` (first two-agent task) and `docs/UPSTREAM-REVIEW.md`
  (monthly pin/patch review checklist).
- CI: `actionlint` on the workflows; best-effort `windows-latest` smoke leg
  (Git Bash + sqlite via choco), `continue-on-error` so it never blocks.

### Fixed
- `patches/0011` now uses portable `grep -Eq` (the previous `grep -q "A\|B"` is a
  GNU-only extension; on macOS BSD grep `\|` is literal, silently no-op'ing the
  `suggest=` guard). Smoke now exercises the alternation behaviorally.

## [0.1.0] - 2026-06-24

### Added
- Reproducible, parameterized installer (`install.sh`) that pins fujibee/agmsg at
  `v1.1.0`, applies the kit patch set, runs the upstream installer (update-in-place
  when already installed, preserving `db/` + `teams/`), joins the team, wires
  turn-mode delivery for Claude Code (`cc`) ↔ Codex (`codex`), and smoke-tests a
  `cc → codex` roundtrip.
- PR-ready patches: `0010` (`send.sh` escapes all four interpolated SQL fields,
  not just `body`) and `0011` (`check-inbox.sh` handles whoami `suggest=true` and
  anchors `^agent=`).
- `secret_redact.py` (8-pattern, `--selftest`); `docs/GOVERNANCE.md` (turn-cap,
  DONE/HANDOFF sentinels, untrusted-peer + no-secrets rules, human escalation);
  `docs/ARCHITECTURE.md`; `docs/IDEAS.md` (100-item, tagged, scored roadmap).
- CI: ShellCheck (`-S warning`) + smoke + safety on Linux & macOS; tag-driven
  release workflow asserting `VERSION == tag == CHANGELOG`.
- MIT license, fail-closed `.gitignore` (DB / `run/` / `teams/` / `.env` never
  committed), `.env.example` parameterization, `make` dev loop, `VENDORED.md`
  pin record, Claude Code plugin manifest + `/agmsg-kit` maintenance command.

### Notes
- The legacy Windows `char(31)`/CRLF "winfix" is intentionally **not** shipped —
  it is superseded upstream by v1.1.0's `-escape off` handling. See `VENDORED.md`.
