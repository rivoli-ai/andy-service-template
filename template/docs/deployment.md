# Deployment

## Docker Compose (Development)

```bash
# Full stack with PostgreSQL
docker compose up -d

# Embedded mode with SQLite (for Conductor)
docker compose -f docker-compose.embedded.yml up -d
```

## Docker Build

```bash
docker build -t __SERVICE_KEBAB__:latest .
```

## Kubernetes

### Prerequisites
- Kubernetes cluster
- `kubectl` configured
- Container registry access

### Deployment Steps

1. Build and push image:
```bash
docker build -t registry.example.com/__SERVICE_KEBAB__:latest .
docker push registry.example.com/__SERVICE_KEBAB__:latest
```

2. Create namespace and secrets:
```bash
kubectl create namespace __SERVICE_KEBAB__
kubectl create secret generic __SERVICE_KEBAB__-db \
  --from-literal=connection-string="Host=postgres;Port=5432;Database=__SERVICE_SNAKE__;Username=__SERVICE_SNAKE__;Password=CHANGE_ME"
```

3. Apply manifests (create your own or use Helm).

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ASPNETCORE_ENVIRONMENT` | Runtime environment | `Production` |
| `ASPNETCORE_URLS` | Listen URLs | `https://+:8443;http://+:8080` |
| `ConnectionStrings__DefaultConnection` | Database connection string | (see appsettings) |
| `Database__Provider` | `PostgreSql` or `Sqlite` | `PostgreSql` |
| `AndyAuth__Authority` | Andy Auth server URL | `https://localhost:5001` |
| `AndyAuth__Audience` | JWT audience | `urn:__SERVICE_KEBAB__-api` |
| `Rbac__ApiBaseUrl` | Andy RBAC server URL | `https://localhost:5003` |
| `Rbac__ApplicationCode` | RBAC application code | `__SERVICE_KEBAB__` |
| `OpenTelemetry__OtlpEndpoint` | OTLP collector endpoint | (empty) |

## Ports

| Service | Port |
|---------|------|
| API HTTPS | __PORT_HTTPS__ |
| API HTTP | __PORT_HTTP__ |
| PostgreSQL | __PORT_PG__ |
| Client (Angular) | __PORT_CLIENT__ |

## Conductor Integration

To embed this service in Conductor, use the SQLite configuration:

```bash
docker compose -f docker-compose.embedded.yml up -d
```

Or configure the API directly:
```bash
export Database__Provider=Sqlite
export ConnectionStrings__DefaultConnection="Data Source=__SERVICE_SNAKE__.db"
dotnet run --project src/__SERVICE_PASCAL__.Api
```
