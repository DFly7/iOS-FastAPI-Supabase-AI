#!/usr/bin/env bash
set -euo pipefail

echo "==> Building backend Docker image..."
(cd backend && docker compose build)

# Hand off to run.sh — its trap handles all cleanup from here on.
exec "$(dirname "$0")/run.sh"
