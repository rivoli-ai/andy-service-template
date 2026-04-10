#!/usr/bin/env bash
# Copyright (c) Rivoli AI 2026. All rights reserved.
# Register an Andy service application in Andy RBAC.
#
# Usage:
#   ./scripts/register-rbac-application.sh --name andy-my-service

set -euo pipefail

SERVICE_NAME=""
RBAC_DB_HOST="localhost"
RBAC_DB_PORT="5433"
RBAC_DB_USER="postgres"
RBAC_DB_NAME="andy_rbac"
RBAC_DB_PASSWORD="postgres"

while [[ $# -gt 0 ]]; do
  case $1 in
    --name)      SERVICE_NAME="$2"; shift 2 ;;
    --rbac-host) RBAC_DB_HOST="$2"; shift 2 ;;
    --rbac-port) RBAC_DB_PORT="$2"; shift 2 ;;
    --rbac-user) RBAC_DB_USER="$2"; shift 2 ;;
    --rbac-db)   RBAC_DB_NAME="$2"; shift 2 ;;
    --rbac-pass) RBAC_DB_PASSWORD="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 --name <service-name>"
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SERVICE_NAME" ]]; then
  echo "Error: --name is required" >&2
  exit 1
fi

SERVICE_KEBAB="$SERVICE_NAME"
SERVICE_PARTS_RAW=$(echo "$SERVICE_NAME" | sed 's/^andy-//')
SERVICE_PARTS=$(echo "$SERVICE_PARTS_RAW" | tr '-' '\n' | while read -r w; do first=$(echo "${w:0:1}" | tr '[:lower:]' '[:upper:]'); printf '%s' "${first}${w:1}"; done; echo)
SERVICE_DISPLAY="Andy ${SERVICE_PARTS}"

echo "Registering RBAC application: $SERVICE_DISPLAY"
echo "  RBAC DB: $RBAC_DB_HOST:$RBAC_DB_PORT/$RBAC_DB_NAME"
echo ""
echo "Add this to the andy-rbac DataSeeder.cs:"
echo "  ../andy-rbac/src/Andy.Rbac.Api/Data/DataSeeder.cs"
echo ""
echo "1. Add the application to SeedApplicationsAsync():"
echo ""
echo '  new Application'
echo '  {'
echo "    Code = \"${SERVICE_KEBAB}\","
echo "    Name = \"${SERVICE_DISPLAY}\","
echo "    Description = \"...\""
echo '  },'
echo ""
echo "2. Add the case to SeedApplicationDataAsync():"
echo ""
echo "  case \"${SERVICE_KEBAB}\":"
echo "    await Seed${SERVICE_PARTS}Async(db, app, ct);"
echo "    break;"
echo ""
echo "3. Create the seed method (see config/rbac-seed.json for full code)"
echo ""
echo "After adding, restart Andy RBAC:"
echo "  cd ../andy-rbac && docker compose restart"
