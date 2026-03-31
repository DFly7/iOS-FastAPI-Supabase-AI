# GitHub Actions — secrets for CI

Add secrets under **GitHub → your repository → Settings → Secrets and variables → Actions**.  
Use **repository secrets** unless you rely on [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) (this repo uses an environment only for production migrations).

| Secret | Required | Used by |
|--------|----------|---------|
| `SUPABASE_ACCESS_TOKEN` | Yes, for hosted DB migrations | [supabase-migrations.yml](workflows/supabase-migrations.yml) |
| `SUPABASE_PROJECT_ID` | Yes, for hosted DB migrations | supabase-migrations |
| `SUPABASE_DB_PASSWORD` | Yes, for hosted DB migrations | supabase-migrations |
| `SUPABASE_URL` | Optional | [backend-ci.yml](workflows/backend-ci.yml) — only if you wire real Supabase into unit tests |
| `SUPABASE_ANON_KEY` | Optional | backend-ci — map to env as `SUPABASE_PUBLIC_ANON_KEY` (see workflow comments) |

Secrets are **not** available to workflows triggered from forks on `pull_request`; keep default CI jobs passing without real credentials (as in `backend-ci.yml` today).

---

## Required: Supabase migrations (`supabase-migrations.yml`)

Runs on pushes to `main` that touch `supabase/migrations/` (and on `workflow_dispatch`). The job uses GitHub Environment **`production`** — create that environment if it does not exist; you can add protection rules and required reviewers there.

| Secret | Description |
|--------|-------------|
| `SUPABASE_ACCESS_TOKEN` | Personal access token from [Supabase account tokens](https://supabase.com/dashboard/account/tokens). |
| `SUPABASE_PROJECT_ID` | Project ref (short id), e.g. from **Project Settings → General** in the Supabase dashboard — *not* the full `https://….supabase.co` URL. |
| `SUPABASE_DB_PASSWORD` | Database password for the linked Supabase project (used by `supabase link` / `supabase db push`). |

---

## Optional: backend unit tests against a hosted project (`backend-ci.yml`)

Default CI runs `pytest` with `-m "not integration"` and placeholder Supabase env vars in the workflow. To hit a real Supabase project from that job, uncomment the `env:` lines in the **Run tests** step and add:

| Secret | Maps to app env var |
|--------|---------------------|
| `SUPABASE_URL` | `SUPABASE_URL` |
| `SUPABASE_ANON_KEY` | `SUPABASE_PUBLIC_ANON_KEY` |

Naming matches the commented example in `backend-ci.yml` (`SUPABASE_ANON_KEY` is the secret name; the FastAPI app still reads `SUPABASE_PUBLIC_ANON_KEY`).

---

## No repository secrets needed

| Workflow | Notes |
|----------|--------|
| [backend-integration.yml](workflows/backend-integration.yml) | Uses `supabase start` locally and `supabase status -o env` — credentials are generated in the job. |
| [ios-ci.yml](workflows/ios-ci.yml) | Builds with `Config.example.xcconfig` copies; Simulator build does not require Supabase keys. |
| Docker push in `backend-ci.yml` | Uses `GITHUB_TOKEN` (automatically provided; **do not** create a secret named `GITHUB_TOKEN`). |

---

## Related: local / runtime env (not all are CI secrets)

See `backend/.env.example` for full app configuration (`ENVIRONMENT`, `RESEND_*`, `SENTRY_DSN`, etc.). Those are for local or deployed runtimes, not wired into the current GitHub Actions workflows unless you add new jobs.
