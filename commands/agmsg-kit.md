---
description: agmsg-kit maintenance — doctor, show/compare the pinned upstream, reinstall (does NOT shadow /agmsg)
---

You are running an agmsg-kit maintenance action. This command manages the
*installer/kit*; the day-to-day messaging command is the upstream `/agmsg`
(do not duplicate it here).

Locate the agmsg-kit checkout (ask the user if unknown). Then, based on the
argument:

- `doctor` (default): run `make doctor` and report sqlite3 version, git, and
  whether the skill is installed at `~/.agents/skills/<cmd>`.
- `pin`: print `AGMSG_PIN` from `.env`/`scripts/lib/paths.sh`, then run
  `git ls-remote --tags https://github.com/fujibee/agmsg.git | tail` and tell
  the user whether a newer upstream tag exists than the pinned one.
- `reinstall`: re-run `./install.sh` (idempotent; preserves `db/` + `teams/`).
  **Confirm with the user before running**, since it rewrites skill scripts.
- `check`: run `make check` (lint + smoke + safety) and report PASS/FAIL.

Never print message bodies or anything that could contain secrets.
