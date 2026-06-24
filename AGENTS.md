# AGENTS.md — agmsg-kit

Rules for any agent (or human) working **on this repo**. For how agents talk to
each other *through* agmsg, see `docs/GOVERNANCE.md`.

## What this project is

A kit around fujibee/agmsg: a reproducible, parameterized installer that pins
upstream by commit, applies PR-ready patches, and wires turn-mode delivery for
Claude Code ↔ Codex. It does not fork or vendor-commit upstream.

## Layout

- `install.sh` / `uninstall.sh` — orchestrators (clone pin → patch → upstream install → wire → smoke).
- `patches/` — local changes as `git diff` against the pinned commit. PR-ready.
- `scripts/lib/paths.sh` — the only place defaults + `.env` resolution live.
- `home/lib/secret_redact.py` — redaction lib (also in the codex-toolkit family).
- `tests/` — `smoke.sh` (network: clones the pin), `test_safety.sh` (offline).
- `docs/` — ARCHITECTURE, GOVERNANCE, IDEAS. `VENDORED.md` — the pin record.

## Build / test (run before declaring done)

```bash
make check        # shellcheck -S warning + smoke + safety
./install.sh --dry-run
```

## Hard rules

1. **No machine-specific values committed.** Team/agent/project names go in
   `.env` (gitignored). Defaults in `paths.sh` stay generic.
2. **No secrets in the repo or in messages.** The DB is plaintext.
3. **Patches are generated against the pin** (`clone → edit → git diff`), so they
   always apply. Bumping the pin → re-roll patches (`make refresh-patches`) +
   update `VENDORED.md`.
4. **Don't reintroduce the Windows `char(31)` winfix** on ≥ v1.1.0 — upstream's
   `-escape off` supersedes it (VENDORED.md).
5. **Installer stays idempotent** and preserves `db/` + `teams/` on re-run.
6. **Hooks never block a session** — delivery fails open.
7. **`VERSION` == git tag == `## [VERSION]` in CHANGELOG** at release.

## Conventions

- Bash: `#!/usr/bin/env bash`, `set -euo pipefail` (except test harnesses, which
  use `set -uo pipefail` so all checks run). LF line endings.
- Python: stdlib only. Conventional Commits (`feat:`, `fix:`, `docs:`).
