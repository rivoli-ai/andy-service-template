# Port Registry

Canonical port assignments for every service in the Andy ecosystem. The source of truth is `KNOWN_PORT_LIST` in [`create-service.sh`](../create-service.sh); this document is the human-friendly view.

`./create-service.sh` consults that list when scaffolding a new service and refuses to reuse an assigned port. When you allocate a port for a new service, update both the script and this document in the same PR.

## Standalone deployment

Each service runs on its own host (or its own `docker-compose.yml`) and binds the ports below. The HTTP port is a plain-text debug variant used inside containers and on CI; production traffic always uses HTTPS.

| Service | HTTPS | HTTP | Postgres | Angular client |
|---|---|---|---|---|
| andy-auth | 5001 | 5002 | 5435 | — |
| andy-rbac | 5003 | 5004 | 5433 | — |
| andy-code-index | 5101 | 5102 | 5436 | 4201 |
| andy-docs | 5110 | 5111 | 5437 | 4202 |
| andy-containers | 5200 | 5201 | 5434 | 4200 |
| andy-settings | 5300 | 5301 | 5438 | — |
| andy-narration | 5310 | 5311 | 5440 | — |
| andy-issues | 5410 | 5411 | 5443 | 4203 |
| andy-agents | 5420 | 5421 | 5444 | 4204 |
| andy-tasks | 5430 | 5431 | 5445 | 4205 |

### Unassigned / legacy

| Service | Notes |
|---|---|
| `andy-mcp-gateway` | README currently uses `https://localhost:5001`, which collides with `andy-auth`. Needs a canonical assignment — probably in the 5500 range. |
| `andy-devpilot` | Deprecated; its responsibilities were split into `andy-issues` (story CRUD) and `andy-agents` (sandbox execution). |

### Next free slots (as of 2026-04-16)

- HTTPS / HTTP pair: `5112/5113`, `5120/5121`, `5210/5211`, `5400/5401`, `5500+`
- Postgres: `5439`, `5441`, `5442`, `5446+`
- Angular client: `4206+`

## Conductor embedded deployment

When [Conductor](https://github.com/rivoli-ai/conductor) bundles services into its local launcher, it runs a **single unified HTTP proxy on port 9100** and routes by path prefix. Individual services listen on dynamic ports allocated at startup by `PortAllocator` (starting at `9101`); the numbers below are the `defaultPort` hints in `Conductor/Core/ServiceHost/Services/*ServiceConfig.swift`.

Consumers (including the Conductor UI itself) address the services through the proxy, never by their internal port.

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

Gaps:

- **9104** was `andy-devpilot` before it was removed. Still reserved in case of cherry-picks from an old Conductor branch; don't reassign.
- **9109+** is the next available slot for a new embedded service. Keep the standalone → embedded mapping monotonic so the two tables line up in the head when reading.

### Why different from standalone?

The embedded range (`9100+`) is deliberately far away from the standalone range (`5000+`, `4200+`) so a developer can run the andy-auth standalone server at `5001` and the Conductor-embedded copy at `9100/auth` on the same machine without colliding. No service talks to another by hard-coded port — everything goes through the proxy (embedded) or OIDC discovery + service discovery config (standalone).

## Workflow for adding a new service

1. Run `./create-service.sh --name andy-foo --description "..." --port-https NEW_PORT`. The script picks the next free HTTPS port and derives HTTP (+1), Postgres (next in 5432–5499 range), and Angular client (next in 4200–4299 range) if you don't pass them explicitly.
2. Verify the script added `andy-foo-https`, `andy-foo-http`, `andy-foo-pg`, and (if there's a client) `andy-foo-client` to `KNOWN_PORT_LIST`.
3. Add a row to the **Standalone** table above.
4. If the service will also be embedded in Conductor, pick the next `9109+` slot and add a row to the **Conductor embedded** table.
5. Commit the script + this doc in the same PR.
