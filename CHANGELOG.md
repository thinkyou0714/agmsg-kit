# Changelog

All notable changes to agmsg-kit. Format follows [Keep a Changelog](https://keepachangelog.com);
this project adheres to [Semantic Versioning](https://semver.org).

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
