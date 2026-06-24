# Contributing

## Ground rules

Same as `AGENTS.md` "Hard rules": no machine-specific values or secrets in git;
patches generated against the pin; idempotent installer; hooks fail open;
`VERSION == tag == CHANGELOG` at release.

## Dev loop

```bash
make lint     # ShellCheck -S warning
make test     # smoke (clones the pinned upstream, runs a real roundtrip)
make safety   # redaction + patch integrity
make check    # all three
```

## Changing the patch set

Patches live in `patches/` as `git diff` against the pinned commit.

- **New fix:** clone the pin, edit, `git diff scripts/X.sh > patches/NNNN-desc.patch`,
  then `make verify-patches`. Add it to `VENDORED.md`. Prefer fixes that are also
  clean upstream PRs.
- **Bump the pin:** update `AGMSG_PIN` in `.env.example` + `scripts/lib/paths.sh`,
  re-roll every patch against the new commit, `make verify-patches`, and update
  the SHA/date/notes in `VENDORED.md` (`make refresh-patches` prints the steps).

## Releasing

```bash
make bump V=minor          # bump VERSION + seed a CHANGELOG section
# fill the CHANGELOG section
make release-check         # assert VERSION present in CHANGELOG
make check                 # lint + smoke + safety
git commit -am "release: vX.Y.Z"
git tag -a vX.Y.Z -m vX.Y.Z && git push --follow-tags
```

The `release` workflow asserts `tag == VERSION == CHANGELOG`, runs the tests, and
drafts the GitHub release from the CHANGELOG section.
