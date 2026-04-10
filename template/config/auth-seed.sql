-- Copyright (c) Rivoli AI 2026. All rights reserved.
-- Andy Auth seed data for __SERVICE_DISPLAY__
--
-- This SQL registers the OAuth clients for this service in the Andy Auth database.
-- Run against the andy_auth_dev database (port 5435 by default).
--
-- Usage:
--   psql -h localhost -p 5435 -U postgres -d andy_auth_dev -f config/auth-seed.sql
--
-- Alternatively, add the client registration to andy-auth's DbSeeder.cs.
-- See: ../andy-auth/src/Andy.Auth.Server/Data/DbSeeder.cs

-- =============================================================================
-- 1. Register API resource scope
-- =============================================================================
INSERT INTO "OpenIddictScopes" ("Id", "Name", "DisplayName", "Resources", "ConcurrencyToken")
SELECT
    gen_random_uuid()::text,
    'urn:__SERVICE_KEBAB__-api',
    '__SERVICE_DISPLAY__ API',
    '["urn:__SERVICE_KEBAB__-api"]',
    gen_random_uuid()::text
WHERE NOT EXISTS (
    SELECT 1 FROM "OpenIddictScopes" WHERE "Name" = 'urn:__SERVICE_KEBAB__-api'
);

-- =============================================================================
-- 2. Register confidential API client (service-to-service)
-- =============================================================================
-- Note: ClientSecret must be hashed. For dev, add via DbSeeder.cs instead.
-- The C# seeder handles password hashing automatically.

-- =============================================================================
-- 3. Register public web client (Angular SPA)
-- =============================================================================
-- Note: Public clients have no secret, but redirect URIs must be registered.
-- For dev, add via DbSeeder.cs instead.

-- =============================================================================
-- DbSeeder.cs snippet (add to andy-auth SeedClientsAsync method):
-- =============================================================================
/*
// __SERVICE_DISPLAY__ API Client
var __SERVICE_SNAKE__ApiClient = await manager.FindByClientIdAsync("__SERVICE_KEBAB__-api");
if (__SERVICE_SNAKE__ApiClient != null)
{
    await manager.DeleteAsync(__SERVICE_SNAKE__ApiClient);
    _logger.LogInformation("Deleted existing OAuth client: __SERVICE_KEBAB__-api");
}

await manager.CreateAsync(new OpenIddictApplicationDescriptor
{
    ClientId = "__SERVICE_KEBAB__-api",
    ClientSecret = "__SERVICE_KEBAB__-secret-change-in-production",
    DisplayName = "__SERVICE_DISPLAY__ API",
    ConsentType = OpenIddictConstants.ConsentTypes.Implicit,
    Permissions =
    {
        OpenIddictConstants.Permissions.Endpoints.Authorization,
        OpenIddictConstants.Permissions.Endpoints.Token,
        OpenIddictConstants.Permissions.Endpoints.Introspection,
        OpenIddictConstants.Permissions.Endpoints.Revocation,

        OpenIddictConstants.Permissions.GrantTypes.AuthorizationCode,
        OpenIddictConstants.Permissions.GrantTypes.RefreshToken,
        OpenIddictConstants.Permissions.GrantTypes.ClientCredentials,

        OpenIddictConstants.Permissions.Scopes.Email,
        OpenIddictConstants.Permissions.Scopes.Profile,
        OpenIddictConstants.Permissions.Scopes.Roles,
        "scp:urn:__SERVICE_KEBAB__-api",

        OpenIddictConstants.Permissions.ResponseTypes.Code
    },
    RedirectUris =
    {
        new Uri("https://localhost:__PORT_HTTPS__/callback"),
    },
    PostLogoutRedirectUris =
    {
        new Uri("https://localhost:__PORT_HTTPS__/"),
    }
});

_logger.LogInformation("Created OAuth client: __SERVICE_KEBAB__-api");

// __SERVICE_DISPLAY__ Web Client (Angular SPA)
var __SERVICE_SNAKE__WebClient = await manager.FindByClientIdAsync("__SERVICE_KEBAB__-web");
if (__SERVICE_SNAKE__WebClient != null)
{
    await manager.DeleteAsync(__SERVICE_SNAKE__WebClient);
    _logger.LogInformation("Deleted existing OAuth client: __SERVICE_KEBAB__-web");
}

await manager.CreateAsync(new OpenIddictApplicationDescriptor
{
    ClientId = "__SERVICE_KEBAB__-web",
    DisplayName = "__SERVICE_DISPLAY__ Web",
    ClientType = OpenIddictConstants.ClientTypes.Public,
    ConsentType = OpenIddictConstants.ConsentTypes.Implicit,
    Permissions =
    {
        OpenIddictConstants.Permissions.Endpoints.Authorization,
        OpenIddictConstants.Permissions.Endpoints.Token,

        OpenIddictConstants.Permissions.GrantTypes.AuthorizationCode,
        OpenIddictConstants.Permissions.GrantTypes.RefreshToken,

        OpenIddictConstants.Permissions.Scopes.Email,
        OpenIddictConstants.Permissions.Scopes.Profile,
        OpenIddictConstants.Permissions.Scopes.Roles,
        "scp:urn:__SERVICE_KEBAB__-api",

        OpenIddictConstants.Permissions.ResponseTypes.Code
    },
    RedirectUris =
    {
        new Uri("https://localhost:__PORT_CLIENT__/callback"),
        new Uri("https://localhost:4200/callback"),
    },
    PostLogoutRedirectUris =
    {
        new Uri("https://localhost:__PORT_CLIENT__/"),
        new Uri("https://localhost:4200/"),
    }
});

_logger.LogInformation("Created OAuth client: __SERVICE_KEBAB__-web");
*/
