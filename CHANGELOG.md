# Changelog

All notable changes to agmsg-kit. Format follows [Keep a Changelog](https://keepachangelog.com);
this project adheres to [Semantic Versioning](https://semver.org).

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
