# Monthly upstream review

A 5-minute checklist to keep the pin current and the patch set honest. Upstream
([fujibee/agmsg](https://github.com/fujibee/agmsg)) moves fast and ships Windows
fixes regularly, so a stale pin can mean you're carrying a patch that's already
been solved (or solved better) upstream.

## Checklist

1. **New tags?**
   ```bash
   git ls-remote --tags https://github.com/fujibee/agmsg.git | tail
   ```
   Compare to `AGMSG_PIN` (in `.env.example` / `scripts/lib/paths.sh`) and
   `VENDORED.md`.

2. **Do our patches still fit the current pin / a candidate new pin?**
   ```bash
   make verify-patches            # applies the set to the pinned commit
   ```
   To test a candidate bump, set `AGMSG_PIN` locally and re-run.

3. **Were any of our fixes upstreamed (or superseded)?** Skim the upstream
   CHANGELOG / closed PRs for the areas we patch:
   - `send.sh` / `rename*.sh` SQL string escaping (our 0010 / 0012).
   - `check-inbox.sh` `suggest=` identity handling (our 0011).
   - Windows separator / CRLF handling (already superseded by `-escape off` —
     see VENDORED.md; **do not** re-add the old winfix).
   If a fix landed upstream, **drop that patch** and note it in `VENDORED.md`.

4. **New Windows / portability issues open?** Search the tracker for `windows`,
   `msys`, `cygpath`, `sqlite` — these are the ones most likely to affect this
   user's Git Bash setup.

5. **Bump deliberately.** If you move the pin: update `AGMSG_PIN` in both places,
   re-roll patches (`make refresh-patches` prints the steps), `make verify-patches`,
   update `VENDORED.md` (SHA + date + drift notes), and run `make check`.

## When NOT to bump

If `make check` is green and no upstream change touches our patched files or
your platform, leave the pin alone. Reproducibility beats chasing `main`.
