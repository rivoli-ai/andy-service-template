# Andy Service Template

Everything to get started and create a new service in the Andy ecosystem: API (REST/Swagger, MCP, gRPC), Angular front-end, PostgreSQL/SQLite, OpenTelemetry, integration with Andy Auth, Andy RBAC, and Andy Settings.

See [`docs/ports.md`](docs/ports.md) for the canonical port registry (standalone + Conductor-embedded).

## Quick Start

```bash
# Create a new service
./create-service.sh --name andy-my-service --description "My awesome service"

# Or interactive mode
./create-service.sh
```

## What You Get

A fully scaffolded microservice with:

| Feature | Implementation |
|---------|---------------|
| **Backend** | .NET 8 (Clean Architecture: Domain, Application, Infrastructure, Api, Shared) |
| **Frontend** | Angular 18 SPA with OIDC auth, route guards, interceptors |
| **API** | REST/Swagger + MCP (Model Context Protocol) + gRPC |
| **Database** | PostgreSQL (default) or SQLite (embedded for Conductor) |
| **Authentication** | OAuth2/OIDC via Andy Auth (JWT Bearer) |
| **Authorization** | Role-based access control via Andy RBAC |
| **Settings** | Centralized configuration via Andy Settings |
| **Observability** | OpenTelemetry (traces, metrics, logs) |
| **CLI** | Command-line tool with System.CommandLine |
| **Docker** | Multi-stage Dockerfile, docker-compose with cert support |
| **Secret Scanning** | Pre-commit hook + Gitleaks CI + `.gitleaks.toml` allowlist |
| **Code Assistant** | `CLAUDE.md` with architecture, conventions, commands |
| **CI/CD** | GitHub Actions (secret scan, build, test, docs, Docker push) |
| **Tests** | Unit (xUnit) + Integration (WebApplicationFactory) + Frontend (Karma) |
| **Docs** | MkDocs Material with architecture, security, deployment guides |
| **Examples** | C#, Python, JavaScript, Java, Go, Rust, PowerShell |

## Port Registry

All Andy ecosystem services use HTTPS by default. This is the port allocation:

| Service | API HTTPS | API HTTP | PostgreSQL | Client | Status |
|---------|-----------|----------|------------|--------|--------|
| andy-auth | 5001 | 5002 | 5435 | - | Reference |
| andy-rbac | 5003 | 5004 | 5433 | 5180 | Reference |
| andy-code-index | 5101 | 5102 | 5436 | 4201 | Reference |
| andy-containers | 5200 | 5201 | 5434 | 4200 | Reference |
| andy-settings | 5300 | 5301 | 5438 | - | Reference |
| andy-narration | 5310 | 5311 | 5440 | - | Reference |
| **Template default** | **5400** | **5401** | **5442** | **4202** | Template |
| andy-issues | 5410 | 5411 | 5443 | 4203 | Scaffolded |
| andy-agents | 5420 | 5421 | 5444 | 4204 | Scaffolded |
| andy-tasks | 5430 | 5431 | 5445 | 4205 | Scaffolded |

### Compliance Status

| Service | Clean Arch | Angular | Swagger | MCP | gRPC | Auth | RBAC | Settings | OTel | Docker | CI/CD | Secrets | CLAUDE.md |
|---------|-----------|---------|---------|-----|------|------|------|----------|------|--------|-------|---------|-----------|
| andy-auth | Y | N | Y | N | N | - | N | N | N | Y | N | N | N |
| andy-rbac | Y | Y | Y | N | N | Y | - | N | N | Y | N | N | N |
| andy-containers | Y | Y | Y | N | N | Y | N | N | N | Y | N | N | N |
| andy-settings | Y | N | Y | N | N | Y | Y | - | N | Y | N | N | N |
| andy-code-index | Y | N | Y | Y | N | Y | N | N | N | Y | N | N | N |
| andy-narration | Y | Y | Y | Y | N | Y | Y | N | conf | Y | Y | N | N |
| andy-issues | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| andy-agents | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| andy-tasks | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| **Template** | **Y** | **Y** | **Y** | **Y** | **Y** | **Y** | **Y** | **Y** | **Y** | **Y** | **Y** | **Y** | **Y** |

> Run `./scripts/check-compliance.sh ../andy-<service>` to audit any project.

## Scripts

| Script | Purpose |
|--------|---------|
| `./create-service.sh` | Create a new service from the template |
| `./scripts/check-compliance.sh <path>` | Audit an existing service against the template |
| `./scripts/update-service.sh <path>` | Compare and optionally update an existing service |
| `./scripts/register-auth-client.sh` | Register OAuth clients in Andy Auth |
| `./scripts/register-rbac-application.sh` | Register application in Andy RBAC |

## Secret Scanning

Every generated service includes three layers of protection against committing secrets:

| Layer | Location | When |
|-------|----------|------|
| **Pre-commit hook** | `.githooks/pre-commit` | Before every local commit |
| **Gitleaks CI** | `.github/workflows/ci.yml` | Every push and PR (blocks build) |
| **Gitleaks config** | `.gitleaks.toml` | Allowlists dev-only defaults |

### Setup (after scaffolding)

```bash
# Install the pre-commit hook
./scripts/setup-git-hooks.sh
```

The hook scans staged files for: passwords, API keys, AWS credentials (`AKIA...`), GitHub PATs (`ghp_...`), OpenAI keys (`sk-...`), private keys, and database connection strings with embedded credentials.

Dev-only defaults (`_dev_password`, `devcert`, `Test123!`) are allowlisted in `.gitleaks.toml` and won't trigger alerts.

## Code Assistant

Each generated service includes a `CLAUDE.md` file providing AI code assistants with full context:
architecture, coding conventions, naming patterns, common commands, port assignments, auth/RBAC setup,
testing requirements, and database strategy. This follows the pattern established in `andy-cli`,
`andy-engine`, and `conductor`.

## Template Structure

```
template/
  .github/workflows/       CI/CD (secret scan, build, test, docs, Docker)
  .githooks/               Pre-commit secret scanning hook
  .gitleaks.toml           Gitleaks allowlist config
  CLAUDE.md                Code assistant development guide
  certs/                   Corporate CA certificates
  client/                  Angular 18 SPA
    src/app/
      core/auth/           OIDC authentication
      core/interceptors/   HTTP auth interceptor
      core/guards/         Route guards
      features/            Sample feature modules
      shared/services/     API service layer
  config/                  Auth & RBAC seed data
  docs/                    MkDocs documentation
  examples/                Multi-language API examples
  scripts/                 setup-git-hooks.sh
  src/
    *.Domain/              Entities, enums
    *.Application/         Interfaces, DTOs
    *.Infrastructure/      EF Core, services
    *.Api/                 REST, MCP, gRPC, Program.cs
    *.Shared/              Shared types
  tests/                   Unit & integration tests
  tools/                   CLI tool
  Dockerfile               Multi-stage (Node + .NET)
  docker-compose.yml       PostgreSQL + API
  docker-compose.embedded.yml  SQLite mode (Conductor)
```

## Updating Existing Services

### Code Assistant Workflow

To bring an existing service up to the latest template:

```bash
# 1. Check current compliance
./scripts/check-compliance.sh ../andy-my-service

# 2. Generate update report (and apply safe changes)
./scripts/update-service.sh ../andy-my-service --apply

# 3. Review the diff
cd ../andy-my-service && git diff

# 4. Run tests to ensure nothing broke
dotnet test
cd client && npm test
```

### AI-Assisted Updates

With a code assistant (Claude, etc.):

1. Generate a fresh template: `./create-service.sh --name andy-my-service --target /tmp/andy-my-service-fresh`
2. Ask the assistant to diff `/tmp/andy-my-service-fresh` against `../andy-my-service`
3. Let the assistant apply the structural changes while preserving business logic
4. Verify test coverage remains solid

## Andy Ecosystem Dependencies

```
                  ┌─────────────┐
                  │  Andy Auth  │  OAuth2/OIDC identity provider
                  │  port 5001  │
                  └──────┬──────┘
                         │ JWT tokens
         ┌───────────────┼───────────────┐
         │               │               │
   ┌─────▼─────┐  ┌─────▼─────┐  ┌─────▼─────┐
   │ Andy RBAC  │  │  Andy     │  │ Your new  │
   │ port 5003  │  │ Settings  │  │ service   │
   │            │  │ port 5300 │  │ port 54xx │
   └────────────┘  └───────────┘  └─────┬─────┘
                                        │
                                  ┌─────▼─────┐
                                  │ Conductor  │  Embedded mode
                                  │ (optional) │  (SQLite)
                                  └───────────┘
```

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.

Copyright (c) Rivoli AI 2026
