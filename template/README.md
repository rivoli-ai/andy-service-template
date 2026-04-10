# __SERVICE_DISPLAY__

__SERVICE_DESCRIPTION__

## Overview

__SERVICE_DISPLAY__ is a microservice in the [Andy ecosystem](https://github.com/rivoli-ai) providing __SERVICE_DESCRIPTION__.

### Features

- **REST API** - Full CRUD API with Swagger documentation
- **MCP Tools** - AI-assisted management via Model Context Protocol
- **gRPC** - High-performance RPC for service-to-service communication
- **Angular SPA** - Web-based management interface
- **CLI Tool** - Command-line resource management
- **OAuth2/OIDC** - Authentication via Andy Auth
- **RBAC** - Role-based access control via Andy RBAC
- **OpenTelemetry** - Distributed tracing, metrics, and logging

## Quick Start

```bash
# Start infrastructure
docker compose up -d postgres

# Run the API
cd src/__SERVICE_PASCAL__.Api
dotnet run

# Run the client (in a separate terminal)
cd client
npm install && npm start
```

## Architecture

| Layer | Project | Purpose |
|-------|---------|---------|
| Domain | `__SERVICE_PASCAL__.Domain` | Entities, enums |
| Application | `__SERVICE_PASCAL__.Application` | Interfaces, DTOs |
| Infrastructure | `__SERVICE_PASCAL__.Infrastructure` | EF Core, services |
| API | `__SERVICE_PASCAL__.Api` | REST, MCP, gRPC, auth |
| Shared | `__SERVICE_PASCAL__.Shared` | Shared types |
| CLI | `__SERVICE_PASCAL__.Cli` | Command-line tool |

## Documentation

Full documentation available at [rivoli-ai.github.io/__SERVICE_KEBAB__](https://rivoli-ai.github.io/__SERVICE_KEBAB__/).

## Ports

| Service | Port |
|---------|------|
| API HTTPS | __PORT_HTTPS__ |
| API HTTP | __PORT_HTTP__ |
| PostgreSQL | __PORT_PG__ |
| Client (Angular) | __PORT_CLIENT__ |

## Docker

```bash
# Full stack (PostgreSQL + API)
docker compose up -d

# Embedded mode (SQLite, for Conductor)
docker compose -f docker-compose.embedded.yml up -d
```

## Testing

```bash
# Backend tests
dotnet test

# Frontend tests
cd client && npm test
```

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.

Copyright (c) Rivoli AI 2026
