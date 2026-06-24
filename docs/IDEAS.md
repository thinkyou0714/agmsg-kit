# 100 ideas — hardening a personal multi-agent (Claude Code ↔ Codex) environment on agmsg

Deduplicated, scored, and tagged from a research sweep (agmsg upstream + 2026
multi-agent governance / bash-sqlite / Claude-Code-distribution best practices).
This is the backlog; it is deliberately honest about what v0.1.0 ships vs. defers
vs. rejects.

**Status:** `[done]` shipped in 0.1.0 · `[rec]` recommended next · `[road]`
larger/roadmap · `[rej]` rejected (reason given).
**Score:** Impact × Effort, each 1 (low) – 5 (high). Prefer high-impact/low-effort.

## A. Reliability & robustness

| # | Idea | I×E | Status |
|---|---|---|---|
| 1 | Pin upstream by commit SHA, install via one idempotent script | 5×2 | [done] |
| 2 | `install.sh` re-run = update-in-place, preserving `db/`+`teams/` | 5×1 | [done] |
| 3 | Smoke-gate every install with a real `cc→codex` roundtrip; abort on failure | 5×2 | [done] |
| 4 | Escape all four interpolated SQL fields in `send.sh` (patch 0010) | 4×1 | [done] |
| 5 | `busy_timeout` on every file-backed sqlite call (upstream `agmsg_sqlite`) | 4×2 | [done-upstream] |
| 6 | Retry-once-after-init on first concurrent write (upstream #114) | 3×2 | [done-upstream] |
| 7 | `mkdir`-mutex for actas stale-lock reclaim (upstream) | 3×3 | [done-upstream] |
| 8 | Wrap Stop-hook inbox check in `timeout N` so a hang never blocks a turn | 4×2 | [rec] |
| 9 | Bound message body size at `send.sh` (~2 KB) to cap a runaway payload | 3×2 | [rec] |
| 10 | Single-writer assertion / advisory lock around `config.sh set` (YAML race) | 2×2 | [road] |

## B. Windows / cross-platform

| # | Idea | I×E | Status |
|---|---|---|---|
| 11 | Use upstream `-escape off` for raw `char(31)`; retire the hand winfix | 5×1 | [done] (drop) |
| 12 | `agmsg_sqlite_mem` strips `\r` for scalar/JSON captures (upstream #130) | 4×2 | [done-upstream] |
| 13 | `cygpath -w` for `readfile()` paths to native sqlite3 (upstream) | 4×2 | [done-upstream] |
| 14 | Force LF on all shipped shell scripts (CRLF breaks bash) | 4×1 | [done] |
| 15 | CI smoke on macOS in addition to Linux (portable-path coverage) | 3×1 | [done] |
| 16 | Add a `windows-latest` Git-Bash CI leg (best-effort) | 3×3 | [rec] |
| 17 | Contribute a `cygpath -m` fix for MSYS `/c/` paths (upstream #197) | 4×3 | [road] |
| 18 | Document scoop sqlite ≥ 3.50 as the Windows requirement for `-escape off` | 3×1 | [done] |
| 19 | Detect WSL-vs-GitBash `HOME` split and warn (avoids two DBs) | 3×2 | [rec] |

## C. Security / untrusted-peer

| # | Idea | I×E | Status |
|---|---|---|---|
| 20 | "Peer messages are data, not instructions" rule in every kickoff | 5×1 | [done-doc] |
| 21 | Never put secrets in messages; DB is plaintext + `history.sh` exposes all | 5×1 | [done-doc] |
| 22 | `.gitignore` keeps `db/`, `run/`, `teams/`, `.env`, `settings.local.json` out | 5×1 | [done] |
| 23 | `secret_redact.py` (8-pattern) for any tooling that logs agmsg traffic | 3×1 | [done] |
| 24 | Team-token prefix convention to flag injected/foreign messages | 3×1 | [done-doc] |
| 25 | Human-in-the-loop gate for irreversible actions, regardless of initiator | 5×1 | [done-doc] |
| 26 | `suggest=`/identity fix so delivery can't mis-target (patch 0011) | 3×1 | [done] |
| 27 | Optional: a hook that flags message bodies containing key-like strings | 3×3 | [road] |
| 28 | SECURITY.md threat model + private vulnerability reporting path | 3×1 | [done] |
| 29 | Validate team names to block path traversal in `teams/` (upstream #140) | 3×2 | [done-upstream] |
| 30 | HMAC-signed message envelopes | — | [rej] over-engineered for a local single-user plaintext bus |

## D. Governance / loop-prevention / turn-taking

| # | Idea | I×E | Status |
|---|---|---|---|
| 31 | Turn-cap in the kickoff prompt ("at most N, then stop") | 5×1 | [done-doc] |
| 32 | `[TURN n/N]` visible budget sentinel in message bodies | 4×1 | [done-doc] |
| 33 | Stop-on-repetition clause ("same message twice → escalate") | 4×1 | [done-doc] |
| 34 | `DONE` / `HANDOFF: <agent>` / `BLOCKED: <reason>` last-line sentinels | 4×1 | [done-doc] |
| 35 | Kickoff-prompt template baked into GOVERNANCE.md | 4×1 | [done] |
| 36 | Referee/coordinator agent pattern for >2-agent teams | 3×3 | [road] |
| 37 | A `claim`/lock table for task hand-off (upstream roadmap) | 3×4 | [road] |
| 38 | Transport-level enforced max-turns | — | [rej] agmsg is intentionally protocol-dumb; enforce in prompt |
| 39 | Per-thread turn counter persisted in the DB | 2×3 | [road] |

## E. Observability / logging / metrics

| # | Idea | I×E | Status |
|---|---|---|---|
| 40 | `make doctor` read-only health check (sqlite/git/skill present) | 3×1 | [done] |
| 41 | Log kit failures to `~/.claude/failures.jsonl` (LAB schema) with redaction | 3×2 | [rec] |
| 42 | `history.sh` already provides a full audit trail of all messages | 3×1 | [done-upstream] |
| 43 | Count unread-by-agent / messages-per-day as a tiny metrics view | 2×2 | [road] |
| 44 | Optional structured event log (JSONL) alongside the message table | 2×3 | [road] |
| 45 | Surface delivery-mode + watcher state in `make doctor` | 3×2 | [rec] |
| 46 | Cost/turn estimate per agent conversation | 2×4 | [road] |

## F. Testing / CI

| # | Idea | I×E | Status |
|---|---|---|---|
| 47 | ShellCheck `-S warning` on all kit scripts in CI | 4×1 | [done] |
| 48 | Smoke: clone pin → apply patches → real roundtrip, on Linux+macOS | 5×2 | [done] |
| 49 | `test_safety.sh`: redaction + patch-integrity + 0010 field guard | 4×1 | [done] |
| 50 | 0010 behavioral regression (quoted `from_agent` survives) | 4×1 | [done] |
| 51 | 0011 static guard (suggest= branch + `^agent=` anchor present) | 3×1 | [done] |
| 52 | `verify-patches` asserts the set still applies to the pin | 4×1 | [done] |
| 53 | Migrate smoke to `bats-core` for richer assertions | 2×3 | [road] |
| 54 | `shfmt --diff` formatting gate | 2×2 | [rec] |
| 55 | Weekly CI job: diff pin vs upstream `main`, open issue on drift | 3×3 | [road] |
| 56 | `actionlint` on the workflow YAML | 2×1 | [rec] |

## G. Developer experience

| # | Idea | I×E | Status |
|---|---|---|---|
| 57 | `.env`-parameterized install (team/agents/project/cmd), no hardcoding | 5×1 | [done] |
| 58 | `--dry-run` on install + uninstall | 4×1 | [done] |
| 59 | `Makefile` with `help/lint/test/safety/check/doctor/bump/release-check` | 4×1 | [done] |
| 60 | `/agmsg-kit` maintenance command (doctor/pin/reinstall) — non-shadowing | 3×1 | [done] |
| 61 | Claude Code plugin manifest for marketplace discoverability | 2×1 | [done] |
| 62 | `--from CLONE_DIR` to install offline / from a pre-fetched clone | 3×1 | [done] |
| 63 | One-line quick-start in README | 3×1 | [done] |
| 64 | `make refresh-patches` runbook for bumping the pin | 3×1 | [done] |
| 65 | Shell completion for `/agmsg` subcommands | 1×3 | [road] |

## H. DB hygiene / migration / backup

| # | Idea | I×E | Status |
|---|---|---|---|
| 66 | Warn when `sqlite3 < 3.51.3` (WAL multi-writer corruption fix) | 4×1 | [done] |
| 67 | Backup helper that copies `messages.db` + `-wal` + `-shm` together | 3×2 | [rec] |
| 68 | `VACUUM INTO` snapshot for a defragmented offline backup | 2×2 | [road] |
| 69 | `schema_version` in a `_meta` table + idempotent migrations | 3×3 | [road] |
| 70 | Periodic prune/archive of read messages older than N days | 3×2 | [rec] |
| 71 | `PRAGMA auto_vacuum=INCREMENTAL` at init | 2×2 | [road] |
| 72 | Never copy a live WAL DB without backup API / `VACUUM INTO` (doc) | 3×1 | [done-doc] |

## I. Multi-team / multi-project / identity

| # | Idea | I×E | Status |
|---|---|---|---|
| 73 | `(name, team)` identity with per-project registrations (upstream #15) | 4×3 | [done-upstream] |
| 74 | Project-path resolution via markers/ancestor/git-common-dir (upstream #92) | 4×3 | [done-upstream] |
| 75 | `check-inbox.sh` honors `suggest=` so cross-project ids don't mis-deliver | 3×1 | [done] |
| 76 | Support more than two agents (gemini/copilot) via the same install flow | 3×2 | [rec] |
| 77 | Per-team kickoff/governance preset files | 2×3 | [road] |
| 78 | `rename.sh`/`rename-team.sh` SQL-escape sweep (same root cause as 0010) | 2×2 | [rec] |

## J. Install / reproducibility / packaging

| # | Idea | I×E | Status |
|---|---|---|---|
| 79 | `VENDORED.md` records pin SHA, review date, drift notes | 4×1 | [done] |
| 80 | Patches generated against the pin → guaranteed-apply, PR-ready | 5×2 | [done] |
| 81 | Born-ignore machine-local `.codex/hooks.json` via `.git/info/exclude` | 3×1 | [done] |
| 82 | Tag-driven release workflow asserting VERSION==tag==CHANGELOG | 3×1 | [done] |
| 83 | Submit 0010 + 0011 upstream as PRs | 4×2 | [rec] |
| 84 | Optional vendored (committed) copy for fully-offline install | 2×3 | [rej] drift + license noise; clone-at-install preferred |
| 85 | npm/`npx` thin bootstrapper | 1×3 | [rej] upstream already offers it; out of scope |

## K. Docs / onboarding

| # | Idea | I×E | Status |
|---|---|---|---|
| 86 | `ARCHITECTURE.md` (pin+patch model, delivery, identity, DB) | 3×1 | [done] |
| 87 | `GOVERNANCE.md` (turn-cap, sentinels, untrusted-peer, escalation) | 4×1 | [done] |
| 88 | `README` Why/What/Quick-start/Safety, no badges (family style) | 3×1 | [done] |
| 89 | `AGENTS.md` repo-dev rules; `CONTRIBUTING.md` release ceremony | 2×1 | [done] |
| 90 | Bug-report issue template requiring `make doctor` output | 2×1 | [done] |
| 91 | This `IDEAS.md` roadmap | 3×2 | [done] |
| 92 | A short "first two-agent task" walkthrough | 2×1 | [rec] |

## L. Local / editor integration

| # | Idea | I×E | Status |
|---|---|---|---|
| 93 | Point your agent-rules doc at agmsg-kit as the canonical reproducer | 4×1 | [rec] |
| 94 | Make this kit the single source of truth, retiring any bespoke installer | 3×2 | [rec] |
| 95 | Honor a kill-switch flag before agmsg sends (incident circuit-breaker) | 3×3 | [road] |
| 96 | Feed kit failures into your observability / doctor tooling | 2×3 | [road] |
| 97 | Worktree-aware project resolution for parallel editor sessions | 2×3 | [road] |
| 98 | Share one redaction lib across tools instead of copying it | 2×2 | [rec] |
| 99 | Optional local-LLM summaries of long agmsg threads | 1×4 | [road] |
| 100 | Monthly upstream-review checklist (new tags, Windows issues) | 3×1 | [rec] |

---

### What 0.1.0 deliberately does **not** do
- No transport-level turn enforcement, message schema, signing, or broker —
  agmsg is intentionally a dumb floor; that discipline lives in prompts (D, C).
- No committed upstream copy (#84) or npm bootstrapper (#85).
- Redis/multi-machine backend, bats migration, schema-migration framework, and
  cost dashboards are roadmap, not 0.1.0.
