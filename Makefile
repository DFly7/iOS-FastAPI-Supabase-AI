# Run from the repo root: make <target>
# Pass extra flags directly:  make dev ARGS="--regen --sim-logs"

.PHONY: dev dev-logs stop sync-models check-models ios-gen help

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

# ── Models ───────────────────────────────────────────────────────────────────

sync-models: ## Generate Swift Codable structs from Pydantic schemas
	cd backend && uv run python ../scripts/sync_models.py

check-models: ## Dry-run: exit 1 if GeneratedModels.swift is out of sync (use in CI)
	cd backend && uv run python ../scripts/sync_models.py --check

# ── Help ─────────────────────────────────────────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
