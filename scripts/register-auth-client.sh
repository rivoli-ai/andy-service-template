#!/usr/bin/env bash
# Copyright (c) Rivoli AI 2026. All rights reserved.
# Register OAuth clients for an Andy service in Andy Auth.
#
# Usage:
#   ./scripts/register-auth-client.sh --name andy-my-service --port-https 5400 --port-client 4202

set -euo pipefail

SERVICE_NAME=""
PORT_HTTPS=""
PORT_CLIENT=""
AUTH_DB_HOST="localhost"
AUTH_DB_PORT="5435"
AUTH_DB_USER="postgres"
AUTH_DB_NAME="andy_auth_dev"
AUTH_DB_PASSWORD="postgres"

while [[ $# -gt 0 ]]; do
  case $1 in
    --name)        SERVICE_NAME="$2"; shift 2 ;;
    --port-https)  PORT_HTTPS="$2"; shift 2 ;;
    --port-client) PORT_CLIENT="$2"; shift 2 ;;
    --auth-host)   AUTH_DB_HOST="$2"; shift 2 ;;
    --auth-port)   AUTH_DB_PORT="$2"; shift 2 ;;
    --auth-user)   AUTH_DB_USER="$2"; shift 2 ;;
    --auth-db)     AUTH_DB_NAME="$2"; shift 2 ;;
    --auth-pass)   AUTH_DB_PASSWORD="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 --name <service-name> --port-https <port> --port-client <port>"
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SERVICE_NAME" || -z "$PORT_HTTPS" || -z "$PORT_CLIENT" ]]; then
  echo "Error: --name, --port-https, and --port-client are required" >&2
  exit 1
fi

SERVICE_KEBAB="$SERVICE_NAME"
SERVICE_PARTS_RAW=$(echo "$SERVICE_NAME" | sed 's/^andy-//')
SERVICE_PARTS=$(echo "$SERVICE_PARTS_RAW" | tr '-' '\n' | while read -r w; do first=$(echo "${w:0:1}" | tr '[:lower:]' '[:upper:]'); printf '%s' "${first}${w:1}"; done; echo)
SERVICE_DISPLAY="Andy ${SERVICE_PARTS}"

echo "Registering OAuth clients for $SERVICE_DISPLAY in Andy Auth..."
echo "  Auth DB: $AUTH_DB_HOST:$AUTH_DB_PORT/$AUTH_DB_NAME"

# Register scope
PGPASSWORD="$AUTH_DB_PASSWORD" psql -h "$AUTH_DB_HOST" -p "$AUTH_DB_PORT" -U "$AUTH_DB_USER" -d "$AUTH_DB_NAME" -c "
INSERT INTO \"OpenIddictScopes\" (\"Id\", \"Name\", \"DisplayName\", \"Resources\", \"ConcurrencyToken\")
SELECT
    gen_random_uuid()::text,
    'urn:${SERVICE_KEBAB}-api',
    '${SERVICE_DISPLAY} API',
    '[\"urn:${SERVICE_KEBAB}-api\"]',
    gen_random_uuid()::text
WHERE NOT EXISTS (
    SELECT 1 FROM \"OpenIddictScopes\" WHERE \"Name\" = 'urn:${SERVICE_KEBAB}-api'
);
"

echo ""
echo "Scope registered. OAuth clients should be added via DbSeeder.cs in andy-auth."
echo "See config/auth-seed.sql for the C# code snippet to add to:"
echo "  ../andy-auth/src/Andy.Auth.Server/Data/DbSeeder.cs"
echo ""
echo "After adding the code, restart Andy Auth to apply:"
echo "  cd ../andy-auth && docker compose restart server"
