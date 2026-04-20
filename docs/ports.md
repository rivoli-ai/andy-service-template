# Port Registry

Canonical port assignments for every service in the Andy ecosystem across **three deployment modes**. The source of truth is `KNOWN_PORT_LIST` in [`create-service.sh`](../create-service.sh); this document is the human-friendly view and the single reference for seeding cross-service config (CORS allow-lists, OAuth redirect URIs, service-to-service URLs, etc.).

`./create-service.sh` consults that list when scaffolding a new service and refuses to reuse an assigned port. When you allocate ports for a new service, update the script **and** this document in the same PR.

## Three deployment modes

Every Andy service supports three ways to run. Ports are distinct per mode so you can run any combination side-by-side on the same machine.

| Mode | Use case | Range |
|---|---|---|
| **Local dotnet** | `dotnet run` on the host. HTTPS preferred; HTTP is a debug/diagnostic variant. | `5xxx` (services + pg), `42xx` (Angular) |
| **Docker** | Per-service `docker-compose.yml`. Offset `+2000` from the dotnet range so both can run at once. | `7xxx` (services + pg), `62xx` (Angular) |
| **Conductor embedded** | Bundled by the Swift shell in [`../conductor`](https://github.com/rivoli-ai/conductor). All traffic goes through a unified HTTP proxy on port `9100`. | Internal ports `9101+`, public via `http://localhost:9100/<prefix>` |

The offset choice — docker ports = dotnet ports + 2000 — keeps the two modes mechanically related (easy to remember, trivial to check) while guaranteeing no overlap because the dotnet ranges are all below 5500.

## Mode 1 — Local dotnet (canonical)

Each service runs natively via `dotnet run`. HTTPS is the production-shape port and the one every other service and redirect URI references. HTTP is for in-container health probes and curl debugging.

| Service | HTTPS | HTTP | Postgres | Angular client |
|---|---|---|---|---|
| andy-auth | 5001 | 5002 | 5435 | — |
| andy-rbac | 5003 | 5004 | 5433 | — |
| andy-code-index | 5101 | 5102 | 5436 | 4201 |
| andy-docs | 5110 | 5111 | 5437 | 4202 |
| andy-policies | 5112 | 5113 | 5439 | 4206 |
| andy-models | 5120 | 5121 | 5441 | 4207 |
| andy-containers | 5200 | 5201 | 5434 | 4200 |
| andy-settings | 5300 | 5301 | 5438 | — |
| andy-narration | 5310 | 5311 | 5440 | — |
| andy-issues | 5410 | 5411 | 5443 | 4203 |
| andy-agents | 5420 | 5421 | 5444 | 4204 |
| andy-tasks | 5430 | 5431 | 5445 | 4205 |

**Config touch-points per service (for dotnet mode):**
- `src/*.Api/Properties/launchSettings.json` — both `applicationUrl` profiles (`https` / `http`). Do not keep the VS-generated `7xxx` HTTPS defaults.
- `src/*.Api/Program.cs` — any `--urls` fallback passed when no launchSettings profile is active.
- `client/angular.json` — `serve.options.port` so `ng serve` doesn't auto-pick 4200.
- `docs/README.md` — the ports table at the bottom.

## Mode 2 — Docker-compose (offset `+2000`)

Each service ships a `docker-compose.yml` that binds the host-facing ports below. The guarantee: **a docker stack on these ports can coexist with a dotnet native run on the Mode 1 ports**, so you can compare behaviour or run half-and-half for debugging.

| Service | HTTPS | HTTP | Postgres | Angular client |
|---|---|---|---|---|
| andy-auth | 7001 | 7002 | 7435 | — |
| andy-rbac | 7003 | 7004 | 7433 | — |
| andy-code-index | 7101 | 7102 | 7436 | 6201 |
| andy-docs | 7110 | 7111 | 7437 | 6202 |
| andy-policies | 7112 | 7113 | 7439 | 6206 |
| andy-models | 7120 | 7121 | 7441 | 6207 |
| andy-containers | 7200 | 7201 | 7434 | 6200 |
| andy-settings | 7300 | 7301 | 7438 | — |
| andy-narration | 7310 | 7311 | 7440 | — |
| andy-issues | 7410 | 7411 | 7443 | 6203 |
| andy-agents | 7420 | 7421 | 7444 | 6204 |
| andy-tasks | 7430 | 7431 | 7445 | 6205 |

**Config touch-points (for docker mode):**
- `docker-compose.yml` — `ports:` entries on the service container, the postgres container, and the client container.
- `docker-compose.embedded.yml` — when the service has an "embedded / Conductor-style" compose variant, it uses the **Mode 3** table below, not this one.

## Mode 3 — Conductor embedded

When [Conductor](https://github.com/rivoli-ai/conductor) bundles services into its desktop launcher, it runs a **single unified HTTP proxy on port 9100** and routes by path prefix. Individual services listen on internal ports allocated at startup by `PortAllocator` (starting at `9101`); the numbers below are the `defaultPort` hints in `Conductor/Core/ServiceHost/Services/<Service>ServiceConfig.swift`.

Consumers — including the Conductor UI itself — always address services via the proxy, never by the internal port. Service-to-service URLs inside the embedded stack use `http://localhost:9100/<prefix>`.

| Service | Proxy prefix | Internal default port | Public URL |
|---|---|---|---|
| Unified proxy | — | 9100 | `http://localhost:9100` |
| andy-auth | `/auth` | 9101 | `http://localhost:9100/auth` |
| andy-rbac | `/rbac` | 9102 | `http://localhost:9100/rbac` |
| andy-containers | `/containers` | 9103 | `http://localhost:9100/containers` |
| andy-docs | `/docs` | 9105 | `http://localhost:9100/docs` |
| andy-mcp-gateway | `/mcp` | 9106 | `http://localhost:9100/mcp` |
| andy-code-index | `/code-index` | 9107 | `http://localhost:9100/code-index` |
| andy-issues | `/issues` | 9108 | `http://localhost:9100/issues` |
| andy-agents | `/agents` | 9109 | `http://localhost:9100/agents` |
| andy-tasks | `/tasks` | 9110 | `http://localhost:9100/tasks` |
| andy-policies | `/policies` | 9111 | `http://localhost:9100/policies` |
| andy-models | `/models` | 9112 | `http://localhost:9100/models` |

**Gaps:**

- `9104` was `andy-devpilot` before it was split into `andy-issues` + `andy-agents`. Reserved, don't reassign.
- `9113+` is the next free slot. Keep the standalone → embedded mapping monotonic so the Mode 1 and Mode 3 tables line up when reading.

**Config touch-points (for Conductor mode):**
- `Conductor/Core/ServiceHost/Services/<Service>ServiceConfig.swift` — `defaultPort`, `proxyPath`, service name.
- The service itself reads its listening port from env (the Swift shell passes it in) and does not hardcode `9101+` values.

## Cross-cutting implications

Anywhere in the ecosystem that refers to a service by URL must be aware of which mode(s) it needs to support. Three places that always need all three modes:

### andy-auth OAuth client redirect URIs (`DbSeeder.cs`)

Every `<service>-web` OAuth client must register the Angular client's `/callback` URL for every mode the service supports. For a typical SPA service (e.g. andy-tasks) that means:
```
RedirectUris: [
  // Mode 1 — dotnet native, HTTPS preferred
  "https://localhost:4205/callback",
  // Mode 2 — docker-compose
  "https://localhost:6205/callback",
  // Mode 3 — Conductor embedded (proxy path)
  "http://localhost:9100/tasks/callback",
]
```

### andy-auth CORS allow-list (`appsettings.*.json → CorsOrigins:AllowedOrigins`)

Must include every Angular client origin across every mode the service supports, both `http://` and `https://`. For a service with a client, six entries per service in the standalone + docker case, plus the Conductor proxy origin once shared.

### Service-to-service URLs in a service's own `appsettings.json`

Service-to-service URLs (e.g. `AndyAuth:Authority`, `Rbac:ApiBaseUrl`) are set per-mode and live in environment-specific `appsettings`:
- `appsettings.Development.json` — Mode 1 (dotnet)
- `appsettings.Docker.json` (or compose env overrides) — Mode 2
- Conductor injects URLs at startup, no static file

## Unassigned / legacy

| Service | Notes |
|---|---|
| `andy-mcp-gateway` | README currently uses `https://localhost:5001`, which collides with `andy-auth`. Needs a canonical assignment — probably in the 5500 range. |
| `andy-devpilot` | Deprecated; its responsibilities were split into `andy-issues` (story CRUD) and `andy-agents` (sandbox execution). |

## Next free slots (as of 2026-04-20)

- HTTPS / HTTP pair (Mode 1): `5130/5131`, `5210/5211`, `5400/5401`, `5500+`
- Postgres (Mode 1): `5442`, `5446+`
- Angular client (Mode 1): `4208+`
- Conductor embedded: `9113+`

Applying `+2000` to any newly assigned Mode 1 port gives the Mode 2 equivalent; no separate allocation needed.

## Workflow for adding a new service

1. Run `./create-service.sh --name andy-foo --description "…" --port-https NEW_PORT`. The script picks the next free HTTPS port (Mode 1) and derives HTTP (+1), Postgres (next in 5432–5499 range), and Angular client (next in 4200–4299 range) if you don't pass them.
2. The script writes Mode 1 values to `KNOWN_PORT_LIST` and the scaffolded service's `launchSettings.json`, `angular.json`, `Program.cs`, and `docker-compose.yml` — the last one using the Mode 2 values (Mode 1 + 2000).
3. Add a row to the **Mode 1** and **Mode 2** tables above.
4. If the service will also be embedded in Conductor, pick the next `9111+` slot, add a `<Service>ServiceConfig.swift` manifest in `../conductor/Conductor/Core/ServiceHost/Services/`, and add a row to the **Mode 3** table.
5. Update `andy-auth/src/Andy.Auth.Server/appsettings.Development.json → CorsOrigins:AllowedOrigins` with the new client's origins (http + https, Mode 1 + Mode 2), and add/update the OAuth client in `DbSeeder.cs` with the corresponding redirect URIs. Rebuild the andy-auth container.
6. Commit the script + this doc + the andy-auth sync in coordinated PRs (linked in the description).
