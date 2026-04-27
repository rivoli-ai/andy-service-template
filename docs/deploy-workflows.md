# Deploy Workflows — Andy Service Template

Canonical GitHub Actions workflows + `railway.json` template for deploying any Andy service to Railway (backend) and Vercel (Angular SPA, when present). Lifted from `rivoli-ai/andy-auth` and `rivoli-ai/andy-docs` working shape during E3-S1 (rivoli-ai/andy-service-template#6, part of the deploy-program tracked at rivoli-ai/conductor#845).

## What ships in `template/`

| File | Purpose |
|---|---|
| `template/railway.json` | Railway build + deploy config; minimal, points at the repo's `Dockerfile`, sets `/health` as the healthcheck path. |
| `template/.github/workflows/deploy-uat.yml` | UAT deploy: test → Railway backend → (optional) Vercel frontend → smoke tests. Triggered on push to `main` (or `develop` if you adopt that pattern). |
| `template/.github/workflows/deploy-production.yml` | Prod deploy: same shape as UAT plus `pg_dump` artifact backup, deployment tagging, automatic rollback on smoke-test failure. |
| `template/.github/workflows/ci.yml` | Pre-existing CI; this story adds an `actionlint` job at the top so workflow-file regressions (like the `if: secrets.X` parse error that bit `andy-docs` for two weeks) get caught at PR time. |

## Secret contract

The workflows read these secrets via `${{ secrets.* }}`. Set them at the repo level in **Settings → Secrets and variables → Actions**.

### Required (every Andy service)

| Secret | Used by |
|---|---|
| `RAILWAY_TOKEN_UAT` | UAT backend deploy |
| `RAILWAY_TOKEN_PROD` | Production backend deploy |
| `UAT_DATABASE_CONNECTION_STRING` | UAT EF migration step |
| `PROD_DATABASE_CONNECTION_STRING` | Production EF migration step + `pg_dump` backup |

### Required if the service has an Angular SPA at `client/`

The `deploy-frontend` job runs only if `client/package.json` exists (`if: ${{ hashFiles('client/package.json') != '' }}`).

| Secret | Used by |
|---|---|
| `VERCEL_TOKEN` | Vercel deploy (account-level token) |
| `VERCEL_ORG_ID` | Vercel deploy (org/team id) |
| `VERCEL_PROJECT_ID_UAT` | Vercel UAT project |
| `VERCEL_PROJECT_ID_PROD` | Vercel production project |
| `GITHUB_PACKAGES_TOKEN` | npm install of `@omnifex/*` packages from GitHub Packages registry |

### Optional

| Secret | Used by |
|---|---|
| `AWS_S3_BUCKET` | Production DB backup archive (skipped if unset) |
| `AWS_ACCESS_KEY_ID` | Same |
| `AWS_SECRET_ACCESS_KEY` | Same |

The S3 archive step uses an env-projection pattern (`env: HAS_S3: ${{ secrets.AWS_S3_BUCKET != '' && 'true' || 'false' }}` at the job level, gated on `if: env.HAS_S3 == 'true'`) because the `secrets` context is not allowed in `if:` evaluation directly. This pattern is the canonical fix per rivoli-ai/andy-docs#229 (E0-S1).

## Repo variables (not secrets)

| Variable | Used by |
|---|---|
| `UAT_API_URL` | UAT smoke-test step (`${UAT_API_URL}/health`) |
| `PROD_API_URL` | Production smoke-test step (`${PROD_API_URL}/health`) |

For canonical Andy services, these point at the `__SERVICE_SUFFIX__-api.{,uat.}wagram.ai` URLs per the E3-S3 wiring matrix (rivoli-ai/conductor#858).

## Adoption walkthrough (existing service)

1. Copy `template/railway.json` → `<your-repo>/railway.json`. Keep the `dockerfilePath` value if your Dockerfile is at the repo root; tweak otherwise.
2. Copy `template/.github/workflows/deploy-uat.yml` and `template/.github/workflows/deploy-production.yml` into your repo's `.github/workflows/`.
3. **If your service has an Angular SPA**: leave the `deploy-frontend` job. Otherwise it auto-skips.
4. Substitute the placeholders manually (or accept what `create-service.sh` already wrote for new services):
   - `__SERVICE_KEBAB__` → `andy-<your-service>`
   - `__SERVICE_SNAKE__` → `andy_<your_service>`
   - `__SERVICE_PASCAL__` → `Andy.<YourService>`
   - `__SERVICE_SUFFIX__` → `<your-service>` (just the part after `andy-`; this is the canonical Andy URL subdomain prefix per E3-S3)
5. Register all required secrets at the repo level (`gh secret set <NAME> -R rivoli-ai/<your-repo>`).
6. Register `UAT_API_URL` and `PROD_API_URL` repo variables (`gh variable set UAT_API_URL -R rivoli-ai/<your-repo> -b "https://<suffix>-api.uat.wagram.ai"`).
7. Push to `main` and watch the workflow run.

The `actionlint` job in `ci.yml` validates these workflow files on every PR; if it complains, fix the warning rather than disabling.

## Why these patterns

A few choices in here are deliberate; flagging the non-obvious ones.

### `if: ${{ hashFiles('client/package.json') != '' }}` for the frontend job

Backend-only services (e.g., `andy-auth`) don't have a `client/` directory. Without the gate, the `deploy-frontend` job would fail trying to `npm ci` an empty directory. `hashFiles` returns the empty string for non-existent paths, so the equality check works and the job auto-skips for backend-only services. No per-service workflow-file forking needed.

### Env-projection for optional secrets

`if: secrets.AWS_S3_BUCKET != ''` is **invalid YAML** in GitHub Actions — the `secrets` context can't appear in `if:` expressions. We project the secret into a literal `'true'`/`'false'` string at job-level `env:` (where `${{ secrets.* }}` IS allowed), then gate on `env.HAS_S3 == 'true'`. Same pattern works for any optional secret.

### `actionlint` as a CI job, not a pre-commit hook

Local pre-commit hooks are easy to bypass and varying-per-developer; CI runs on every PR uniformly. The cost is ~5 s extra per PR.

### Single replica via `numReplicas: 1` (per-service override)

The default `railway.json` doesn't pin replica count (Railway defaults to 1 anyway). Services with in-process workers that can't tolerate horizontal scaling — `andy-narration` is the current example — should override by adding `"numReplicas": 1` under `deploy` in their copy of `railway.json` and document why.

## Status of adoption (as of 2026-04-26)

| Service | `railway.json` | `deploy-uat.yml` | `deploy-production.yml` | `actionlint` |
|---|:---:|:---:|:---:|:---:|
| andy-auth | ✅ (pre-existing) | — | — | — |
| andy-docs | ✅ (pre-existing) | partial (E0-S1 fix landed) | partial (E0-S1 fix landed) | ✅ (E0-S1) |
| andy-rbac | — | — | — | — |
| andy-settings | — | — | — | — |
| andy-narration | — | — | — | — |
| andy-subscription | — (Fly.io currently) | — | — | — |

The remaining adoption work is tracked under E3-S4..S9 in rivoli-ai/conductor#845.

## Related

- rivoli-ai/conductor#845 — Epic E3 — Deploy Andy services to Railway + Vercel
- rivoli-ai/conductor#857 — E3-S2 — Register secrets across all six service repos
- rivoli-ai/conductor#858 — E3-S3 — Andy canonical domains + DNS + inter-service URL wiring matrix
- rivoli-ai/conductor#869 — E3-S10 — Database seeding contract
- rivoli-ai/andy-docs#229 — E0-S1 — origin of the env-projection pattern + actionlint gate
