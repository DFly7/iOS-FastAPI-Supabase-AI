#!/usr/bin/env bash
# scripts/_lib.sh — Shared helpers sourced by dev.sh and dev-logs.sh.
# Requires REPO_ROOT to be set by the caller before sourcing.

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
BACKEND_DIR="$REPO_ROOT/backend"
ENV_FILE="$BACKEND_DIR/.env"
ENV_EXAMPLE="$BACKEND_DIR/.env.example"
XCCONFIG="$REPO_ROOT/ios/StarterApp/Config-Debug.xcconfig"
XCCONFIG_EXAMPLE="$REPO_ROOT/ios/StarterApp/Config.example.xcconfig"
IOS_DIR="$REPO_ROOT/ios/StarterApp"
IOS_SIM="$REPO_ROOT/scripts/ios-sim.sh"

# ---------------------------------------------------------------------------
# URLs
# ---------------------------------------------------------------------------
SUPA_LOCAL_URL="http://127.0.0.1:54321"
SUPA_DOCKER_URL="http://host.docker.internal:54321"
BACKEND_LOCAL_URL="http://127.0.0.1:8000"
BACKEND_HEALTHZ="$BACKEND_LOCAL_URL/healthz"

# ---------------------------------------------------------------------------
# Config file helpers
# ---------------------------------------------------------------------------

# Upsert KEY=VALUE in a .env-style file (adds if missing, updates if wrong)
upsert_env() {
  local file="$1" key="$2" value="$3"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    local current
    current=$(grep "^${key}=" "$file" | cut -d= -f2-)
    if [[ "$current" != "$value" ]]; then
      sed -i '' "s|^${key}=.*|${key}=${value}|" "$file"
      echo "    updated $key"
    fi
  else
    echo "${key}=${value}" >> "$file"
    echo "    added   $key"
  fi
}

# Upsert KEY = VALUE in an xcconfig file
upsert_xcconfig() {
  local file="$1" key="$2" value="$3"
  if grep -q "^${key} = " "$file" 2>/dev/null; then
    local current
    current=$(grep "^${key} = " "$file" | sed "s|^${key} = ||")
    if [[ "$current" != "$value" ]]; then
      sed -i '' "s|^${key} = .*|${key} = ${value}|" "$file"
      echo "    updated $key"
    fi
  else
    echo "${key} = ${value}" >> "$file"
    echo "    added   $key"
  fi
}

# Convert a plain URL to xcconfig-safe form: http://  →  http:/$()/
xcconfig_url() { echo "$1" | sed 's|://|:/$()/|'; }

# ---------------------------------------------------------------------------
# Bootstrap steps
# ---------------------------------------------------------------------------

# Start Supabase and export SUPA_ANON_KEY.
start_supabase() {
  echo "==> Starting Supabase (local)…"
  cd "$REPO_ROOT"
  supabase start

  echo "==> Reading Supabase credentials…"
  local status
  status=$(supabase status 2>/dev/null)

  # CLI >= 2.x → "Publishable" column; CLI 1.x fallback → "anon key" row
  SUPA_ANON_KEY=$(echo "$status" | grep "Publishable" | awk '{print $4}')
  if [[ -z "$SUPA_ANON_KEY" ]]; then
    SUPA_ANON_KEY=$(echo "$status" | grep "anon key" | awk '{print $NF}')
  fi

  [[ -n "$SUPA_ANON_KEY" ]] || {
    echo "Error: Could not read anon key from 'supabase status'."
    echo "       Output was:"
    echo "$status"
    exit 1
  }
  echo "    anon key: ${SUPA_ANON_KEY:0:24}…"
}

# Write/update backend/.env with Supabase connection details.
# Requires SUPA_ANON_KEY to be set (call start_supabase first).
configure_backend_env() {
  echo "==> Configuring backend/.env…"
  if [[ ! -f "$ENV_FILE" ]]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    echo "    created from .env.example"
  fi
  upsert_env "$ENV_FILE" "SUPABASE_URL"             "$SUPA_DOCKER_URL"
  upsert_env "$ENV_FILE" "SUPABASE_PUBLIC_ANON_KEY" "$SUPA_ANON_KEY"
}

# Write/update ios/StarterApp/Config-Debug.xcconfig.
# Requires SUPA_ANON_KEY to be set (call start_supabase first).
configure_ios_xcconfig() {
  echo "==> Configuring ios/Config-Debug.xcconfig…"
  if [[ ! -f "$XCCONFIG" ]]; then
    cp "$XCCONFIG_EXAMPLE" "$XCCONFIG"
    echo "    created from Config.example.xcconfig"
  fi
  upsert_xcconfig "$XCCONFIG" "BACKEND_URL"       "$(xcconfig_url "$BACKEND_LOCAL_URL")"
  upsert_xcconfig "$XCCONFIG" "SUPABASE_URL"      "$(xcconfig_url "$SUPA_LOCAL_URL")"
  upsert_xcconfig "$XCCONFIG" "SUPABASE_ANON_KEY" "$SUPA_ANON_KEY"
}

# Run tuist install (if needed) then tuist generate.
# $1 = "true" to force tuist install (--regen flag).
run_tuist() {
  local regen="${1:-false}"
  command -v tuist &>/dev/null || {
    echo "Error: 'tuist' not found. Install from https://docs.tuist.dev"
    exit 1
  }
  if [[ "$regen" == "true" ]] || [[ ! -d "$IOS_DIR/Tuist/.build" ]]; then
    echo "==> tuist install (resolving packages)…"
    (cd "$IOS_DIR" && tuist install)
  fi
  echo "==> tuist generate (refreshing Xcode project)…"
  (cd "$IOS_DIR" && tuist generate --no-open)
}

# Poll /healthz until the backend responds or times out.
wait_for_backend() {
  echo "==> Waiting for backend to be ready…"
  local max=60 i=0
  until curl -sf "$BACKEND_HEALTHZ" &>/dev/null; do
    i=$((i + 1))
    [[ $i -ge $max ]] && {
      echo "Error: Backend did not respond at $BACKEND_HEALTHZ after ${max}s."
      echo "       Check logs: docker compose logs -f  (in backend/)"
      exit 1
    }
    printf '.'
    sleep 1
  done
  echo " ready."
}
