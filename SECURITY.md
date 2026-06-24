# Security

## Threat model

agmsg is a **local, plaintext** message bus. The store lives at
`~/.agents/skills/<cmd>/db/messages.db`; anyone with filesystem access can read
it, and `history.sh` surfaces every message to every team member. The kit's
security posture follows from that:

- **No secrets in messages — ever.** API keys, tokens, passwords, PII must never
  appear in a message body. Share a variable *name*, not its value. See
  `docs/GOVERNANCE.md`.
- **Peer messages are untrusted input.** Any agent that can write the DB can
  address any recipient with arbitrary text that lands in another agent's
  context. Treat message bodies as data, not instructions (prompt-injection
  mindset). Tag legitimate traffic with a team token.
- **Irreversible actions need a human.** Agent→agent delegation does not inherit
  human authorization. `git push`, deploys, deletions, and external sends pause
  for a human no matter which agent initiated the chain.

## Secrets & git hygiene

- `.gitignore` keeps the DB (`db/*.db*`), runtime state (`run/`), team
  registrations (`teams/`), `.env`, and `.claude/settings.local.json` out of git.
- Machine-specific values (team/agent/project names) live only in a local,
  gitignored `.env` — the public repo ships generic defaults.
- `home/lib/secret_redact.py` (8-pattern) is provided for any tooling that logs
  agmsg traffic; use it rather than rolling your own regex set.

## Supply chain

- Upstream agmsg is fetched at install time at the **pinned commit** in
  `VENDORED.md` (not a moving branch), and our changes are reviewable patches.
- CI uses `pull_request` (not `pull_request_target`) and pins no third-party
  release actions beyond the standard `actions/checkout` + `actions/setup-python`.
- Bump the pin deliberately; re-roll and re-verify patches (`make verify-patches`).

## Reporting a vulnerability

Open a **private** GitHub Security Advisory (or a minimal issue that contains **no**
secrets or message bodies) rather than a public report with sensitive detail.
Include OS/shell, `sqlite3 --version`, the pinned commit, and reproduction steps.
