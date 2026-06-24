# agmsg-kit — dev tasks. Run `make help`.
SHELL := /usr/bin/env bash
VERSION := $(shell tr -d '[:space:]' < VERSION)

SH_FILES := install.sh uninstall.sh scripts/bump-version.sh scripts/lib/paths.sh tests/smoke.sh tests/test_safety.sh

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: lint
lint: ## ShellCheck all shell scripts (-S warning)
	@shellcheck -S warning $(SH_FILES)
	@echo "lint: OK"

.PHONY: test
test: ## Run the smoke test (roundtrip + patch regressions)
	@bash tests/smoke.sh

.PHONY: safety
safety: ## Run the safety test (secret_redact + SQL-escaping/suggest regressions)
	@bash tests/test_safety.sh

.PHONY: check
check: lint test safety ## Lint + smoke + safety (run before committing)
	@echo "check: ALL PASS"

.PHONY: verify-patches
verify-patches: ## Assert the patch set applies cleanly to the pinned upstream
	@bash tests/smoke.sh

.PHONY: refresh-patches
refresh-patches: ## How to re-roll patches after bumping the pin (prints guidance)
	@echo "To bump the upstream pin and re-roll patches:"
	@echo "  1. Update AGMSG_PIN in .env.example + scripts/lib/paths.sh to the new commit."
	@echo "  2. Clone the new pin, hand-apply each patch's intent, 'git diff > patches/NNNN-*.patch'."
	@echo "  3. 'make verify-patches' must pass. Update VENDORED.md (SHA, date, drift notes)."

.PHONY: doctor
doctor: ## Read-only health check of the installed skill
	@command -v sqlite3 >/dev/null && echo "  sqlite3: $$(sqlite3 --version | awk '{print $$1}')" || echo "  sqlite3: MISSING"
	@command -v git >/dev/null && echo "  git: ok" || echo "  git: MISSING"
	@SK="$${AGMSG_SKILL_DIR:-$$HOME/.agents/skills/agmsg}"; \
		[ -f "$$SK/.agmsg" ] && echo "  installed: $$SK" || echo "  installed: no ($$SK)"

.PHONY: bump
bump: ## Bump version: make bump V=patch|minor|major|X.Y.Z
	@bash scripts/bump-version.sh "$(V)"

.PHONY: release-check
release-check: ## Assert VERSION == CHANGELOG section exists
	@grep -q "^## \[$(VERSION)\]" CHANGELOG.md || { echo "CHANGELOG.md missing ## [$(VERSION)] section"; exit 1; }
	@echo "release-check: VERSION=$(VERSION) present in CHANGELOG"
