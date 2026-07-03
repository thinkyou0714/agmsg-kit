---
name: run-checks
description: Run agmsg-kit's checks (smoke roundtrip, safety, shell lint). Use when asked to test, lint, verify, or check the installer/patches.
---

Run the repo checks and report results concisely.

1. Ensure lint tools are present (SessionStart bootstrap pip-installs `ruff`+`codespell`; `shellcheck` is usually pre-installed on web).
2. Targets: `make test` (smoke roundtrip + patch regressions), `make safety` (secret_redact + SQL-escaping/suggest regressions), `make check` (= lint + test + safety). Patch integrity: `make verify-patches`.
3. Summarize: which target passed/failed and the first failing assertion/file per failure.
4. Do not edit scripts or patches unless asked; the upstream pin + patch set are load-bearing.
