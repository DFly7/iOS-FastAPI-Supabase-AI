<div align="center">

# iOS · FastAPI · Supabase Starter

**Production-ready template for shipping authenticated iOS apps with a FastAPI backend and Supabase — without the weeks of boilerplate.**

[![Backend CI](https://github.com/DFly7/iOS-FastAPI-Supabase-AI/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/DFly7/iOS-FastAPI-Supabase-AI/actions/workflows/backend-ci.yml)
[![Integration Tests](https://github.com/DFly7/iOS-FastAPI-Supabase-AI/actions/workflows/backend-integration.yml/badge.svg)](https://github.com/DFly7/iOS-FastAPI-Supabase-AI/actions/workflows/backend-integration.yml)
[![iOS CI](https://github.com/DFly7/iOS-FastAPI-Supabase-AI/actions/workflows/ios-ci.yml/badge.svg)](https://github.com/DFly7/iOS-FastAPI-Supabase-AI/actions/workflows/ios-ci.yml)
[![Migrations](https://github.com/DFly7/iOS-FastAPI-Supabase-AI/actions/workflows/supabase-migrations.yml/badge.svg)](https://github.com/DFly7/iOS-FastAPI-Supabase-AI/actions/workflows/supabase-migrations.yml)

![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?logo=fastapi&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.10-F05138?logo=swift&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-2.84-3ECF8E?logo=supabase&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)

</div>

---

## What this gives you

Spinning up an authenticated iOS app with a custom backend and a real database typically takes days of glue work. This template collapses it to a single `./run.sh`.

| Layer | Technology | What's wired up |
|-------|-----------|-----------------|
| **iOS** | SwiftUI + supabase-swift | Auth (sign up / sign in / sign out), JWT forwarded to backend, `BackendAPIService`, Tuist project generation |
| **Backend** | FastAPI + uv + Docker | JWT verification via Supabase JWKS, per-user profile endpoint, rate limiting, structured JSON logging, Sentry, Prometheus metrics, Resend email |
| **Database** | Supabase (Postgres 17) | `profiles` table, Row-Level Security policies, `handle_new_user` trigger, seed hooks |
| **Local infra** | Supabase CLI + Docker Compose | Full Supabase stack locally (API · Studio · Auth · Storage · Realtime), backend on port 8000, HTTPS tunnels for physical device testing |
| **CI/CD** | GitHub Actions | Backend unit tests, Docker image push to GHCR, integration tests against live local Supabase, iOS build + test on macOS, automated production migration push |

---

## Architecture

```
iPhone (or Simulator)
        │ SUPABASE_URL (tunnel or localhost)
        │ BACKEND_URL  (tunnel or localhost)
        ▼
┌─ instatunnel / ngrok / cloudflared ─┐
│  HTTPS → localhost:54321 (Supabase) │
│  HTTPS → localhost:8000  (FastAPI)  │
└─────────────────────────────────────┘
        │
        ▼
┌─── Mac (localhost) ─────────────────────────┐
│                                             │
│  Supabase CLI   (:54321)                    │
│  ├─ Postgres 17  (:5432)                    │
│  ├─ PostgREST    (:54321/rest/v1)           │
│  ├─ GoTrue Auth  (:54321/auth/v1)           │
│  └─ Supabase Studio (:54323) ←── browser   │
│                                             │
│  FastAPI (Docker Compose)  (:8000)          │
│  └─ reaches Supabase via                   │
│     host.docker.internal:54321             │
│     (no tunnel required)                   │
└─────────────────────────────────────────────┘
```

---

## What's already built

### SwiftUI iOS App
- **Auth flow** — Sign up, sign in, sign out with supabase-swift; session persisted across launches
- **Authenticated API calls** — `BackendAPIService` attaches the Supabase JWT to every request
- **Config via xcconfig** — `SUPABASE_URL`, `BACKEND_URL`, and `SUPABASE_ANON_KEY` injected at build time; no secrets in source
- **Tuist** — `Project.swift` defines the target, dependencies (Supabase, PostHog), URL scheme, and entitlements; no committed `.xcodeproj` drift
- **Deep link auth redirect** — `com.example.starter://` URL scheme wired to Supabase auth

### FastAPI Backend
- **JWKS JWT verification** — validates Supabase-issued tokens without a shared secret; HTTP client reused across requests
- **Auth middleware** — `AuthContextMiddleware` extracts `user_id` and attaches it to every request's context
- **Request ID middleware** — every request gets a unique `X-Request-ID` for tracing
- **Structured logging** — `structlog` with JSON output in production, human-readable in dev; log level auto-set per environment
- **Rate limiting** — `slowapi` with configurable default rate; exempt `GET /healthz`
- **Prometheus metrics** — opt-in `/metrics` endpoint for scraping
- **Sentry** — opt-in error tracking with Starlette + FastAPI integrations
- **Resend email** — helper service ready to send transactional email
- **CORS** — correctly handles `allow_credentials` with explicit origins
- **Environment-aware config** — single `Settings` class via `pydantic-settings`; sensible defaults, all overridable via env vars
- **`GET /healthz`** — unauthenticated health check
- **`GET /api/v1/ping`** — open ping
- **`GET /api/v1/secure-test`** — requires valid JWT
- **`GET /api/v1/me/profile`** — returns the authenticated user's profile from Postgres

### Supabase
- **`profiles` table** — auto-created for every new user via `handle_new_user` trigger on `auth.users`
- **Row-Level Security** — users can only read and update their own profile
- **Seed file** — `supabase/seed.sql` runs on every `supabase start` for local dev
- **Local Studio** — full Supabase dashboard at `http://127.0.0.1:54323`

### Testing
- **Unit tests** — pytest with async support; services and auth helpers tested in isolation
- **Integration tests** — spin up a real local Supabase instance via `supabase start`; test the full auth → backend → DB round trip
- **iOS tests** — Swift Testing unit tests + XCUITest UI tests scaffolded and running in CI

### CI / CD (GitHub Actions)
- `backend-ci.yml` — lint, test, build Docker image, push to GHCR on `main`
- `backend-integration.yml` — install Supabase CLI, `supabase start`, run integration tests against it
- `ios-ci.yml` — `tuist generate`, `xcodebuild test` on macOS-15
- `supabase-migrations.yml` — push migrations to your hosted Supabase project when `supabase/migrations/**` changes on `main`

---

## Getting started

> Full step-by-step instructions, tunnel options (instatunnel / ngrok / Cloudflare), and environment variable reference are in **[local-setup.md](local-setup.md)**.

### 1. Install tools

```sh
# mise manages Python, uv, Tuist, and the Supabase CLI at pinned versions
curl https://mise.run | sh
mise install   # run from repo root
```

Also install **[Docker Desktop](https://www.docker.com/products/docker-desktop/)**.

### 2. Configure environment

```sh
# Backend
cp backend/.env.example backend/.env
# Fill in SUPABASE_PUBLIC_ANON_KEY after step 3

# iOS
cp ios/StarterApp/Config.example.xcconfig ios/StarterApp/Config-Debug.xcconfig
cp ios/StarterApp/Config.example.xcconfig ios/StarterApp/Config-Release.xcconfig
# Edit both: set DEVELOPMENT_TEAM, PRODUCT_BUNDLE_IDENTIFIER, SUPABASE_ANON_KEY, URLs
```

### 3. Start everything

```sh
./run.sh
```

This starts Supabase, the backend (Docker Compose), and two HTTPS tunnels — then prints the live URLs. **Ctrl+C stops everything cleanly.**

```
All services running:
  Supabase API  → https://my-supa-api.instatunnel.dev
  Backend API   → https://my-backend-api.instatunnel.dev
  Supabase UI   → http://127.0.0.1:54323 (local only)
```

### 4. Generate and open the iOS project

```sh
cd ios/StarterApp
tuist install && tuist generate
open StarterApp.xcodeproj
```

Build and run on Simulator or a physical device.

---

## Repo layout

```
.
├── ios/StarterApp/          # SwiftUI app (Tuist)
├── backend/                 # FastAPI (uv + Docker)
│   ├── app/
│   │   ├── api/v1/          # Route handlers
│   │   ├── core/            # Config, auth (JWKS), rate limiting
│   │   ├── middleware/      # Request ID, auth context, access log
│   │   ├── repositories/    # Data access layer
│   │   ├── schemas/         # Pydantic models
│   │   └── services/        # Business logic, email
│   └── tests/               # Unit + integration tests
├── supabase/                # Supabase CLI project
│   └── migrations/          # SQL migrations (versioned)
├── .github/workflows/       # CI/CD pipelines
├── .mise.toml               # Pinned tool versions (Python, uv, Tuist, Supabase CLI)
├── run.sh                   # Start everything (Supabase + backend + tunnels)
├── build-run.sh             # Rebuild Docker image, then run.sh
└── local-setup.md           # Full local dev runbook
```

---

## Tool versions

All versions are pinned in `.mise.toml` and kept in sync with CI:

| Tool | Version |
|------|---------|
| Python | 3.12 |
| uv | 0.11.2 |
| Tuist | 4.44.3 |
| Supabase CLI | 2.84.2 |

---

## Local ports

| Service | Port | URL |
|---------|------|-----|
| Supabase API | 54321 | `http://127.0.0.1:54321` |
| Supabase Studio | 54323 | `http://127.0.0.1:54323` |
| FastAPI backend | 8000 | `http://127.0.0.1:8000` |

---

## Customising

- **Rename the app** — update `PRODUCT_BUNDLE_IDENTIFIER` in xcconfig, `CFBundleURLSchemes` in `Project.swift`, and `additional_redirect_urls` in `supabase/config.toml`
- **Add a migration** — create a file in `supabase/migrations/` following the timestamp naming convention; it runs automatically on `supabase start` and in CI
- **Add a backend route** — add a handler in `backend/app/api/v1/`, register it in `router.py`
- **Add a Swift dependency** — add it to `Tuist/Package.swift`, re-run `tuist install && tuist generate`
- **Configure Sentry / Resend** — uncomment the relevant lines in `backend/.env` and fill in your keys

---

<div align="center">

Built to skip the setup. Start building features.

</div>
