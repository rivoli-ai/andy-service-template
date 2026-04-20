# Security

## Authentication

### Andy Auth (OAuth2/OIDC)

This service integrates with [Andy Auth](https://github.com/rivoli-ai/andy-auth) for authentication:

- **Protocol**: OAuth 2.0 Authorization Code with PKCE
- **Token format**: JWT Bearer tokens
- **Authority**: Configured via `AndyAuth:Authority`
- **Audience**: `urn:__SERVICE_KEBAB__-api`

### OAuth Client Registration

Two OAuth clients are registered in Andy Auth:

1. **`__SERVICE_KEBAB__-api`** (Confidential) - For service-to-service communication
2. **`__SERVICE_KEBAB__-web`** (Public) - For the Angular SPA

See `config/registration.json` (the `auth` section) for the OAuth client declarations — andy-auth reads manifests from every sibling service at startup and seeds its OpenIddict catalog from them.

### Test User

- **Email**: `test@andy.local`
- **Password**: `Test123!`
- **Role**: User (with super-admin in RBAC)

## Authorization

### Andy RBAC

Role-based access control is provided by [Andy RBAC](https://github.com/rivoli-ai/andy-rbac):

- **Application code**: `__SERVICE_KEBAB__`
- **Roles**: admin, user, viewer
- **Actions**: read, write, delete, admin

See `config/registration.json` (the `rbac` section) for the application, resource types, and roles. andy-rbac reads sibling manifests on startup and seeds its catalog from them.

## Transport Security

- **HTTPS everywhere**: TLS is enforced from development to production
- **Self-signed certs**: Generated automatically in Docker for development
- **Corporate CAs**: Supported via the `certs/` directory
- **Certificate injection**: At build time and runtime in Docker

## API Security

- **Swagger**: Bearer authentication scheme configured
- **MCP**: Requires authorization
- **gRPC**: Uses the same Bearer authentication
- **Health endpoint**: Unauthenticated (for load balancer probes)

## Best Practices

- Never commit secrets to the repository
- Use environment variables for sensitive configuration
- Rotate tokens and passwords regularly
- Review RBAC permissions periodically
