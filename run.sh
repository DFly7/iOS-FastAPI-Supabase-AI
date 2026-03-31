#!/usr/bin/env bash
set -euo pipefail

# ── Edit these two values once ──────────────────────────────────────────────
SUPA_SUBDOMAIN="my-supa-api"
BACKEND_SUBDOMAIN="my-backend-api"
# ────────────────────────────────────────────────────────────────────────────

cleanup() {
  echo ""
  echo "==> Shutting down..."
  # Kill all background jobs spawned by this script
  jobs -p | xargs -r kill 2>/dev/null || true
}
trap cleanup INT TERM EXIT

echo "==> Starting Supabase (this exits once all containers are healthy)..."
supabase start

echo "==> Starting backend..."
(cd backend && docker compose up) &

echo "==> Starting tunnels..."
instatunnel 54321 --subdomain "$SUPA_SUBDOMAIN" &
instatunnel 8000  --subdomain "$BACKEND_SUBDOMAIN" &

echo ""
echo "All services running:"
echo "  Supabase API  → https://${SUPA_SUBDOMAIN}.instatunnel.dev"
echo "  Backend API   → https://${BACKEND_SUBDOMAIN}.instatunnel.dev"
echo "  Supabase UI   → http://127.0.0.1:54323 (local only)"
echo ""
echo "Press Ctrl+C to stop everything."
wait
