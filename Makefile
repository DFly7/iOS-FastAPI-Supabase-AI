# Run from the repo root: make <target>
# Pass extra flags directly:  make dev ARGS="--regen --sim-logs"

.PHONY: dev dev-logs stop sync-models check-models ios-gen ios-test ios-test-ui help

# Auto-detect latest available iPhone simulator; override with UDID: make ios-test SIM_ID=<udid>
SIM_ID ?= $(shell xcrun simctl list devices available | grep -i iphone | tail -1 | grep -oEi '[0-9A-F-]{36}')

# ── Local dev ────────────────────────────────────────────────────────────────

dev: ## Full local stack: Supabase + FastAPI + iOS Simulator
	./scripts/dev.sh $(ARGS)

dev-logs: ## Same as dev + 3-pane log view (FastAPI / Supabase / iOS)
	./scripts/dev-logs.sh $(ARGS)

stop: ## Stop all running services (Docker, Supabase, tmux log session)
	-cd backend && docker compose down
	-supabase stop --no-backup
	-tmux kill-session -t dev-stack 2>/dev/null

# ── iOS ──────────────────────────────────────────────────────────────────────

ios-gen: ## Re-generate the Xcode project (after adding/removing Swift files)
	cd ios/StarterApp && tuist generate

ios-test: ## Run unit tests on Simulator  (override: SIM_ID=<udid>)
	@[ -n "$(SIM_ID)" ] || (echo "No iPhone simulator found — install one via Xcode ▸ Settings ▸ Platforms"; exit 1)
	set -o pipefail && cd ios/StarterApp && xcodebuild test \
		-workspace StarterApp.xcworkspace \
		-scheme StarterApp \
		-only-testing:StarterAppTests \
		-destination 'platform=iOS Simulator,id=$(SIM_ID)' \
		2>&1 | bundle exec xcpretty --color

ios-test-ui: ## Run UI tests on Simulator  (override: SIM_ID=<udid>)
	@[ -n "$(SIM_ID)" ] || (echo "No iPhone simulator found — install one via Xcode ▸ Settings ▸ Platforms"; exit 1)
	set -o pipefail && cd ios/StarterApp && xcodebuild test \
		-workspace StarterApp.xcworkspace \
		-scheme StarterApp \
		-only-testing:StarterAppUITests \
		-destination 'platform=iOS Simulator,id=$(SIM_ID)' \
		2>&1 | bundle exec xcpretty --color

# ── Distribution ─────────────────────────────────────────────────────────────

setup-dist: ## One-time wizard: configure signing, create App Store record, seed certs repo
	./scripts/setup-dist.sh

create-app: ## Create App Store Connect record + register App ID (idempotent)
	cd ios/StarterApp && bundle exec fastlane create_app

beta: ## Build and upload to TestFlight via Fastlane
	cd ios/StarterApp && bundle exec fastlane beta

release: ## Submit to App Store via Fastlane (review not triggered automatically)
	cd ios/StarterApp && bundle exec fastlane release

# ── Models ───────────────────────────────────────────────────────────────────

sync-models: ## Generate Swift Codable structs from Pydantic schemas
	cd backend && uv run python ../scripts/sync_models.py

check-models: ## Dry-run: exit 1 if GeneratedModels.swift is out of sync (use in CI)
	cd backend && uv run python ../scripts/sync_models.py --check

# ── Help ─────────────────────────────────────────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
