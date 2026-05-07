# __SERVICE_DISPLAY__ — Development Guide

## Project Overview

__SERVICE_DISPLAY__ is an Andy ecosystem microservice: __SERVICE_DESCRIPTION__

## Tech Stack

- **Runtime**: .NET 8.0
- **Frontend**: Angular 18 (standalone components, OIDC auth)
- **Database**: PostgreSQL (default), SQLite (embedded/Conductor mode)
- **ORM**: Entity Framework Core 8
- **Auth**: OAuth2/OIDC via Andy Auth (OpenIddict, JWT Bearer)
- **Authorization**: Andy RBAC (role-based access control)
- **Settings**: Andy Settings (centralized configuration)
- **API**: REST/Swagger + MCP (Model Context Protocol) + gRPC
- **Telemetry**: OpenTelemetry (traces, metrics, OTLP export)
- **Testing**: xUnit, WebApplicationFactory, Karma/Jasmine
- **Containerization**: Docker multi-stage, docker-compose

## Architecture

Clean Architecture with five layers:

| Layer | Project | Purpose |
|-------|---------|---------|
| Domain | `__SERVICE_PASCAL__.Domain` | Entities, enums, value objects — no dependencies |
| Application | `__SERVICE_PASCAL__.Application` | Interfaces, DTOs, contracts |
| Infrastructure | `__SERVICE_PASCAL__.Infrastructure` | EF Core, service implementations, external integrations |
| API | `__SERVICE_PASCAL__.Api` | REST controllers, MCP tools, gRPC services, auth, middleware |
| Shared | `__SERVICE_PASCAL__.Shared` | Types shared across projects |
| CLI | `__SERVICE_PASCAL__.Cli` | Command-line interface (System.CommandLine) |

**Dependency rule**: outer layers depend on inner layers, never the reverse. API → Infrastructure → Application → Domain.

## Repository Structure

```
__SERVICE_KEBAB__/
├── CLAUDE.md                    # This file
├── README.md
├── LICENSE                      # Apache 2.0
├── __SERVICE_PASCAL__.sln
├── Directory.Build.props        # Shared build properties (Rivoli AI metadata)
├── nuget.config                 # NuGet sources (nuget.org + local-packages/)
├── Dockerfile                   # Multi-stage: Node + .NET + Runtime (with cert injection)
├── docker-compose.yml           # PostgreSQL + API
├── docker-compose.embedded.yml  # SQLite mode (Conductor integration)
├── mkdocs.yml                   # Documentation site config
├── certs/                       # Corporate CA certificates (not committed)
├── client/                      # Angular 18 SPA
│   ├── src/app/
│   │   ├── core/auth/           # OIDC callback
│   │   ├── core/guards/         # Route guards (auth)
│   │   ├── core/interceptors/   # HTTP auth interceptor (Bearer token)
│   │   ├── features/            # Feature modules (dashboard, items, ...)
│   │   └── shared/services/     # API service layer
│   ├── src/environments/        # Environment configs (dev, docker, prod)
│   ├── angular.json
│   └── package.json
├── config/
│   └── registration.json        # Single registration manifest consumed by andy-auth, andy-rbac, andy-settings at seed time (OAuth clients + RBAC app + setting definitions). Schema: andy-service-template/docs/registration.schema.json
├── docs/                        # MkDocs documentation
├── examples/                    # Multi-language API usage examples
├── local-packages/              # Local NuGet packages
├── src/                         # .NET source projects
├── tests/                       # Unit + integration tests
└── tools/                       # CLI tool
```

## Coding Conventions

### C# Style
- .NET 8 with `<LangVersion>latest</LangVersion>`, nullable enabled, warnings as errors
- Use file-scoped namespaces (`namespace X;`)
- Use primary constructors where appropriate
- Prefer records for DTOs and value objects
- Async all the way — return `Task<T>`, use `CancellationToken`
- No `#region` blocks

### Naming
- Entities: plain names (`Item`, `Project`)
- DTOs: `{Name}Dto` (e.g., `ItemDto`)
- Request models: `Create{Name}Request`, `Update{Name}Request`
- Services: `I{Name}Service` (interface), `{Name}Service` (implementation)
- Controllers: `{Name}Controller` (plural resource name, e.g., `ItemsController`)
- MCP tools: static class `ServiceTools` with `[McpServerTool]` methods
- gRPC services: `{Name}GrpcService`
- Test classes: `{ClassUnderTest}Tests`

### API Design
- REST controllers and MCP tools share the same service layer — never duplicate business logic
- gRPC services also use the same service layer
- Controllers use `[Authorize]` by default; use `[AllowAnonymous]` only for health/public endpoints
- Return DTOs from controllers, never domain entities

### Frontend (Angular)
- Standalone components only (no NgModules)
- Use `angular-auth-oidc-client` for OIDC — never roll custom auth
- All API calls go through `ApiService` (typed HTTP methods)
- Route guards via `authGuard` (functional guard)
- HTTP interceptor attaches Bearer tokens to `/api` requests

## Common Commands

```bash
# Build
dotnet build

# Run tests
dotnet test

# Run tests with coverage
dotnet test --collect:"XPlat Code Coverage" --results-directory ./TestResults

# Run the API (Development mode)
ASPNETCORE_ENVIRONMENT=Development dotnet run --project src/__SERVICE_PASCAL__.Api

# Run the API with SQLite
Database__Provider=Sqlite dotnet run --project src/__SERVICE_PASCAL__.Api

# Frontend
cd client && npm install && npm start

# Frontend tests
cd client && npm test -- --watch=false --browsers=ChromeHeadless

# Docker (full stack)
docker compose up -d

# Docker (embedded/SQLite)
docker compose -f docker-compose.embedded.yml up -d

# CLI
dotnet run --project tools/__SERVICE_PASCAL__.Cli -- items list

# EF migrations (create)
dotnet ef migrations add MigrationName --project src/__SERVICE_PASCAL__.Infrastructure --startup-project src/__SERVICE_PASCAL__.Api

# EF migrations (apply)
dotnet ef database update --project src/__SERVICE_PASCAL__.Infrastructure --startup-project src/__SERVICE_PASCAL__.Api
```

## Ports

| Service | Port |
|---------|------|
| API HTTPS | __PORT_HTTPS__ |
| API HTTP | __PORT_HTTP__ |
| PostgreSQL | __PORT_PG__ |
| Client (Angular dev) | 4200 |
| Client (Docker) | __PORT_CLIENT__ |

## External Dependencies

| Service | dotnet | docker | embedded | Purpose |
|---------|--------|--------|----------|---------|
| Andy Auth | 5001 | 7001 | localhost:9100/auth | OAuth2/OIDC identity provider |
| Andy RBAC | 5003 | 7003 | localhost:9100/rbac | Role-based access control |
| Andy Settings | 5300 | 7301 | localhost:9100/settings | Centralized configuration |

Ports above are sourced from each dependency's `config/registration.json` —
see [Cross-service URLs](#cross-service-urls) for how they reach this service
without being hardcoded.

## Cross-service URLs

**Rule:** never hardcode another Andy service's URL or port in this repo. URLs
must come from configuration generated by `scripts/sync-dep-ports.sh` from
each dependency's `config/registration.json`.

### Three runtime modes

| Mode | When | URL pattern |
|------|------|-------------|
| `dotnet` | `dotnet run` / debugger; deps also run on host | `https://localhost:<dotnetHttps>` |
| `docker` | `docker compose up`; deps also containerized | `https://host.docker.internal:<dockerHttps>` |
| `embedded` | bundled inside Conductor | `http://localhost:9100/<embeddedProxyPrefix>` |

### How it works

1. `scripts/sync-dep-ports.sh` reads sibling repos' registration manifests
   (default search root `..`, override via `ANDY_SIBLING_ROOT`) and writes:
   - `.env.dotnet`, `.env.docker`, `.env.embedded` — one per mode
   - `.env` — copy of `.env.docker` (so `docker compose up` works zero-config)
2. `docker-compose.yml` reads `.env` automatically and forwards values via the
   `${VAR:-default}` form, translating canonical names (`ANDY_AUTH_AUTHORITY`)
   to the .NET `__`-separated form (`AndyAuth__Authority`).
3. `scripts/run-dev.sh` and `scripts/run-embedded.sh` source the appropriate
   `.env.<mode>` and apply the same translation before invoking `dotnet run`.
4. The Angular build is compile-time, so `client/scripts/set-environment.js`
   reads `.env.<mode>` and emits `client/src/environments/environment.<mode>.ts`
   as a `prebuild` / `prestart` step. Those `.ts` files are gitignored — the
   committed source is `environment.template.ts`.

### Daily flow

```bash
# After cloning or after a dep moves ports
./scripts/sync-dep-ports.sh

# Containerized run (deps also containerized on host)
docker compose up -d --build

# Host-mode run (deps via `dotnet run` on host)
./scripts/run-dev.sh

# Conductor-style embedded (deps via http://localhost:9100/<prefix>)
./scripts/run-embedded.sh
```

### CI gate

`./scripts/sync-dep-ports.sh --check` exits non-zero if any committed `.env.*`
file would be regenerated. Wire this into CI so a dep that changes ports must
trigger a `.env.*` refresh in this repo before merging.

### Never do

- Paste a port literal into `docker-compose*.yml`, `appsettings*.json`,
  `client/src/environments/*.ts`, or any helper script.
- Edit a generated `.env.<mode>` or `environment.<mode>.ts` by hand — re-run
  the generator instead.
- Add a new sibling-service URL without sourcing it from that sibling's
  `config/registration.json` via `sync-dep-ports.sh` (extend the script's
  `DEPS` list rather than hardcoding the URL).

## Database

- **PostgreSQL** (default): Set `Database:Provider` to `PostgreSql` in appsettings
- **SQLite** (embedded): Set `Database:Provider` to `Sqlite` — used for Conductor bundling
- Auto-migration runs in Development mode
- Design-time factory in `Infrastructure/Data/DesignTimeDbContextFactory.cs`

## Authentication & Authorization

- **Auth bypass**: When `AndyAuth:Authority` is empty, all endpoints are open (dev convenience)
- **JWT Bearer**: When configured, API requires valid tokens from Andy Auth
- **Test user**: `test@andy.local` / `Test123!` (seeded in Andy Auth for non-production)
- **RBAC**: Application code `__SERVICE_KEBAB__` registered in Andy RBAC with admin/user/viewer roles
- **Swagger**: Bearer security scheme configured — use "Authorize" button in Swagger UI

## Testing Requirements

- **Always write tests** for new code in `tests/` assemblies
- **Run `dotnet test` before claiming completion**
- Unit tests use EF Core InMemory provider
- Integration tests use `WebApplicationFactory<Program>`
- Frontend tests use Karma/Jasmine with ChromeHeadless

## Code Quality

- `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` — zero warnings policy
- Run `dotnet format` before committing
- All tests must pass before push
- Copyright header: `// Copyright (c) Rivoli AI 2026. All rights reserved.`

## Secret Scanning

- **Pre-commit hook** (local): `.githooks/pre-commit` scans staged files for passwords, API keys,
  tokens, private keys. Install via `./scripts/setup-git-hooks.sh`. Bypass for known dev defaults
  with `git commit --no-verify`.
- **GitHub secret scanning** if enabled at the org level.

**Never commit**: real API keys, production passwords, private keys, personal tokens.
**Allowed**: dev-only defaults like `_dev_password`, `Test123!`, `devcert`.

## CI/CD

- **ci.yml**: Build + test (.NET and Angular) on push/PR
- **docs.yml**: Deploy MkDocs to GitHub Pages on push to main
- **docker.yml**: Build and push Docker image on version tags

## Template Origin

This project was scaffolded from [andy-service-template](https://github.com/rivoli-ai/andy-service-template).
Run `check-compliance.sh` from the template repo to verify template compliance.
