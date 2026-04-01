# Repo-level convenience targets.
# Run from the repo root: make <target>

.PHONY: dev dev-logs dev-regen dev-no-ios stop sync-models check-models backend-dev ios-sim ios-sim-regen ios-sim-logs ios-gen help

# ── Local dev (no tunnels) ───────────────────────────────────────────────────

## Full local stack: Supabase + FastAPI + iOS Simulator (auto-configures .env and xcconfig).
dev:
	./dev.sh

## Same as dev but opens a 3-pane log view (FastAPI / Supabase / iOS). Requires tmux.
dev-logs:
	./dev-logs.sh

## Same as dev but runs tuist install + generate first (use after cloning).
dev-regen:
	./dev.sh --regen

## Start Supabase + FastAPI only — skip the iOS build.
dev-no-ios:
	./dev.sh --no-ios

## Stop all running services (FastAPI docker, Supabase, tmux log session).
stop:
	-cd backend && docker compose down
	-supabase stop --no-backup
	-tmux kill-session -t dev-stack 2>/dev/null

# ── Model sync ──────────────────────────────────────────────────────────────

## Generate Swift Codable structs from Pydantic schemas (source of truth).
## Output: ios/StarterApp/StarterApp/Models/GeneratedModels.swift
sync-models:
	cd backend && uv run python ../scripts/sync_models.py

## Dry-run: exit 1 if GeneratedModels.swift is out of sync with the schemas.
## Plug this into CI to catch schema drift before it reaches the app.
check-models:
	cd backend && uv run python ../scripts/sync_models.py --check

# ── Local dev ────────────────────────────────────────────────────────────────

## Start Supabase + backend (mirrors run.sh).
backend-dev:
	./run.sh

## Build and launch StarterApp on the newest available iPhone simulator.
ios-sim:
	./ios/StarterApp/run-sim.sh

## Same as ios-sim but runs tuist install + generate first (use after cloning or manifest changes).
ios-sim-regen:
	./ios/StarterApp/run-sim.sh --regen

## Build, launch, and stream console logs from the simulator.
ios-sim-logs:
	./ios/StarterApp/run-sim.sh --logs

## Re-generate the Xcode project after adding/removing Swift files.
ios-gen:
	cd ios/StarterApp && tuist generate

# ── Help ─────────────────────────────────────────────────────────────────────

help:
	@grep -E '^##' Makefile | sed 's/^## //'
