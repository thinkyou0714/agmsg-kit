# agmsg-kit

A hardened, version-controlled **kit around** [fujibee/agmsg](https://github.com/fujibee/agmsg) —
the bash + SQLite mailbox that lets Claude Code and Codex (and Gemini/Copilot)
message each other directly instead of using you as a copy-paste relay.

agmsg-kit turns a hand-patched, one-off setup into a reproducible one: it pins
upstream by commit, ships root-cause fixes as reviewable patches, wires
turn-mode delivery for `cc ↔ codex`, and smoke-tests the roundtrip — with
governance, ShellCheck/CI, and secret hygiene baked in.

## Why

agmsg itself is great, but a *personal* setup tends to rot: scripts get
hand-edited for your platform with loose `.bak` files, the installer hardcodes
your team/agent names, and there's no test telling you the `cc → codex` path
still works after an upstream change. This kit fixes the meta-problem — it makes
the setup **reproducible, parameterized, hardened, and tested**, the same way
`codex-toolkit` does for Codex.

## What's inside

```
install.sh / uninstall.sh   Idempotent, parameterized, --dry-run installer
patches/                    PR-ready fixes applied on top of the pinned upstream
  0010-…sql-fields.patch    send.sh escapes team/from/to/body (not just body)
  0011-…suggest-identity    check-inbox.sh handles whoami suggest= + anchors ^agent=
scripts/lib/paths.sh        Single AGMSG_* parameter resolver (loads .env)
home/lib/secret_redact.py   8-pattern redaction (--selftest)
tests/                      smoke.sh (clone+patch+roundtrip) · test_safety.sh
docs/                       ARCHITECTURE · GOVERNANCE · IDEAS (100-item roadmap)
.github/workflows/          ShellCheck + smoke on Linux/macOS · tag release
VENDORED.md                 Pinned upstream commit + why the patch set is small
```

## Quick start

```bash
git clone https://github.com/thinkyou0714/agmsg-kit.git
cd agmsg-kit
cp .env.example .env          # set AGMSG_TEAM / AGMSG_CC / AGMSG_CO / AGMSG_PROJECT
./install.sh --dry-run        # preview
./install.sh                  # install: clone pin → patch → upstream install → wire → smoke
make check                    # lint + smoke + safety
```

Re-running `./install.sh` updates in place and **preserves your message DB and
team registrations**. After install, drive messaging with the upstream `/agmsg`
command; use `/agmsg-kit` only for kit maintenance (doctor/pin/reinstall).

## Design principles

- **No machine-specific values in git** — team/agent/project live in a gitignored `.env`.
- **No secrets, ever** — the message DB is plaintext; `.gitignore` and SECURITY.md enforce it.
- **Pin + patch, don't fork** — upstream fetched at a fixed commit; changes are clean diffs.
- **Verify, don't assume** — the patch set is *small on purpose*: three candidate
  fixes were already solved upstream at v1.1.0 and were dropped (see VENDORED.md).
- **Never block a session** — delivery hooks fail open.

## Safety

The message store is plaintext and `history.sh` shows every message to every team
member — so **secrets must never appear in a message body**. Irreversible actions
(push/deploy/delete) always pause for a human, regardless of which agent started
the chain. See `docs/GOVERNANCE.md` and `SECURITY.md`.

## License

MIT. Upstream agmsg (MIT) is fetched at install time at the pinned commit in
`VENDORED.md`, not redistributed here.
