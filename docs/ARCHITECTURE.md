# Architecture

## What agmsg-kit is (and is not)

agmsg-kit is a **kit around** [fujibee/agmsg](https://github.com/fujibee/agmsg),
not a fork. agmsg is the transport: a bash + SQLite mailbox that lets CLI coding
agents (Claude Code, Codex, Gemini, Copilot) message each other with no daemon,
socket, or broker — "the file is the shared floor."

The kit adds the things a fork would otherwise force you to maintain by hand:

- **Reproducibility** — upstream pinned by commit, installed by one idempotent,
  parameterized script instead of a one-off with hardcoded values.
- **Hardening** — root-cause fixes shipped as reviewable, PR-ready patches.
- **Governance** — a written multi-agent protocol (`docs/GOVERNANCE.md`).
- **Safety net** — ShellCheck + a real send→inbox roundtrip in CI, secret
  redaction, and a `.gitignore` that keeps the message DB and state out of git.

## Pin + patch overlay

```
install.sh
  ├─ Phase 0  deps: git, sqlite3 (warn if < 3.51.3 — WAL multi-writer fix)
  ├─ Phase 1  git clone fujibee/agmsg ; checkout AGMSG_PIN (v1.1.0)   [temp dir]
  ├─ Phase 2  git apply patches/*.patch   (idempotent: skips if already applied)
  ├─ Phase 3  bash <clone>/install.sh --cmd <name> [--update]   → ~/.agents/skills/<name>
  ├─ Phase 4  join.sh cc/codex ; delivery.sh set turn ; born-ignore .codex/hooks.json
  └─ Phase 5  smoke: send cc→codex ; assert inbox ; cleanup
```

The patches are generated *against the pinned commit* (`clone → edit → git diff`),
so they are guaranteed to apply, and each is a clean upstream contribution. If a
future pin bump moves the target lines, `make verify-patches` fails loudly rather
than silently no-op'ing — see `VENDORED.md` and `make refresh-patches`.

Upstream is fetched at install time and **not** redistributed here (keeps the
repo small and the license boundary clean).

## Delivery modes (set per project, per agent type)

| Mode | Mechanism | Latency | Notes |
|---|---|---|---|
| `turn` | `Stop` hook runs `check-inbox.sh` between turns | until next turn | the kit default; works for Codex/Copilot/Gemini |
| `monitor` | `SessionStart` launches a `watch.sh` poll stream | ~5 s | Claude Code only |
| `both` | monitor primary, turn fallback | ~5 s | Stop hook defers if a watcher is alive |
| `off` | manual `/agmsg` only | — | all agents |

The kit wires **`turn`** for both `cc` and `codex` — the mode verified on Windows
Git Bash. Switch with `/agmsg mode <mode>` after install.

## Identity (upstream, as of v1.1.0)

Agents are identified by `(name, team)`. `project_path` and `type` are metadata
held in a `registrations` array, so one agent works across many projects
(upstream issues #15, #92). `whoami.sh` emits one of: `agent=` (single),
`multiple=true`, `suggest=true` (registered only under another project), or
`not_joined=true`. Patch `0011` makes `check-inbox.sh` handle `suggest=`
correctly.

## Message store

```sql
CREATE TABLE messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  team TEXT NOT NULL, from_agent TEXT NOT NULL, to_agent TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  read_at TEXT
);
```

WAL journal mode; a partial index on unread `(team, to_agent, read_at)` and a
history index on `(team, created_at)`. All file-backed access goes through
`agmsg_sqlite`, which sets a `busy_timeout` and (on sqlite ≥ 3.50) passes
`-escape off` so the raw `char(31)` field separator survives — the upstream fix
that makes the old hand-applied Windows "winfix" unnecessary (`VENDORED.md`).

The DB is plaintext and readable by anyone on the machine; `history.sh` surfaces
every message to every team member. **Never put secrets in a message body**
(`SECURITY.md`, `docs/GOVERNANCE.md`).
