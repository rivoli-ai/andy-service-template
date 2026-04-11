#!/usr/bin/env bash
# Copyright (c) Rivoli AI 2026. All rights reserved.
# Licensed under the Apache License, Version 2.0.
#
# Andy Service Template - Scaffold Generator
# Creates a new Andy ecosystem microservice from the template.
#
# Usage:
#   ./create-service.sh [options]
#   ./create-service.sh --name "andy-my-service" --target ../andy-my-service
#   ./create-service.sh --name "andy-subscription" --description "Subscription management" --port-https 5500

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template"

# --- Color output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --- Known port registry (for conflict detection) ---
# Format: "label:port" — bash 3.2 compatible (no associative arrays)
KNOWN_PORT_LIST=(
  "andy-auth-https:5001"
  "andy-auth-http:5002"
  "andy-auth-pg:5435"
  "andy-rbac-https:5003"
  "andy-rbac-http:5004"
  "andy-rbac-pg:5433"
  "andy-code-index-https:5101"
  "andy-code-index-http:5102"
  "andy-code-index-pg:5436"
  "andy-code-index-client:4201"
  "andy-containers-https:5200"
  "andy-containers-http:5201"
  "andy-containers-pg:5434"
  "andy-containers-client:4200"
  "andy-settings-https:5300"
  "andy-settings-http:5301"
  "andy-settings-pg:5438"
  "andy-narration-https:5310"
  "andy-narration-http:5311"
  "andy-narration-pg:5440"
  "andy-issues-https:5410"
  "andy-issues-http:5411"
  "andy-issues-pg:5443"
  "andy-issues-client:4203"
  "andy-agents-https:5420"
  "andy-agents-http:5421"
  "andy-agents-pg:5444"
  "andy-agents-client:4204"
  "andy-tasks-https:5430"
  "andy-tasks-http:5431"
  "andy-tasks-pg:5445"
  "andy-tasks-client:4205"
)

# --- Defaults ---
SERVICE_NAME=""
SERVICE_DESCRIPTION=""
TARGET_DIR=""
PORT_HTTPS=5400
PORT_HTTP=5401
PORT_PG=5442
PORT_CLIENT=4202
INIT_GIT=true
PORTS_FROM_CLI=false

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --name)        SERVICE_NAME="$2"; shift 2 ;;
    --description) SERVICE_DESCRIPTION="$2"; shift 2 ;;
    --target)      TARGET_DIR="$2"; shift 2 ;;
    --port-https)  PORT_HTTPS="$2"; PORTS_FROM_CLI=true; shift 2 ;;
    --port-http)   PORT_HTTP="$2"; PORTS_FROM_CLI=true; shift 2 ;;
    --port-pg)     PORT_PG="$2"; PORTS_FROM_CLI=true; shift 2 ;;
    --port-client) PORT_CLIENT="$2"; PORTS_FROM_CLI=true; shift 2 ;;
    --no-git)      INIT_GIT=false; shift ;;
    --help|-h)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --name NAME          Service name (e.g., andy-my-service)"
      echo "  --description DESC   Service description"
      echo "  --target DIR         Target directory (default: ../<name>)"
      echo "  --port-https PORT    API HTTPS port (default: 5400)"
      echo "  --port-http PORT     API HTTP port (default: 5401)"
      echo "  --port-pg PORT       PostgreSQL port (default: 5442)"
      echo "  --port-client PORT   Angular client port (default: 4202)"
      echo "  --no-git             Don't initialize git repository"
      echo "  --help               Show this help"
      exit 0
      ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Interactive prompts for missing values ---
if [[ -z "$SERVICE_NAME" ]]; then
  read -rp "Service name (e.g., andy-my-service): " SERVICE_NAME
fi

# Validate name format
if [[ ! "$SERVICE_NAME" =~ ^andy-[a-z][a-z0-9-]*$ ]]; then
  err "Service name must match 'andy-<name>' pattern (lowercase, hyphens ok)."
  err "Example: andy-my-service"
  exit 1
fi

if [[ -z "$SERVICE_DESCRIPTION" ]]; then
  read -rp "Service description: " SERVICE_DESCRIPTION
fi

if [[ -z "$TARGET_DIR" ]]; then
  TARGET_DIR="$SCRIPT_DIR/../$SERVICE_NAME"
fi

# Port prompts (skip if any ports were provided on CLI)
if [[ "$PORTS_FROM_CLI" != "true" ]]; then
  echo ""
  info "Port configuration (press Enter to accept defaults):"
  read -rp "  API HTTPS port [$PORT_HTTPS]: " input; PORT_HTTPS="${input:-$PORT_HTTPS}"
  read -rp "  API HTTP port [$PORT_HTTP]: " input; PORT_HTTP="${input:-$PORT_HTTP}"
  read -rp "  PostgreSQL port [$PORT_PG]: " input; PORT_PG="${input:-$PORT_PG}"
  read -rp "  Angular client port [$PORT_CLIENT]: " input; PORT_CLIENT="${input:-$PORT_CLIENT}"
fi

# --- Check port conflicts ---
echo ""
info "Checking for port conflicts..."
CONFLICT=false
for entry in "${KNOWN_PORT_LIST[@]}"; do
  key="${entry%%:*}"
  port="${entry##*:}"
  for chosen_port in $PORT_HTTPS $PORT_HTTP $PORT_PG $PORT_CLIENT; do
    if [[ "$port" == "$chosen_port" ]]; then
      warn "Port $chosen_port conflicts with $key (port $port)"
      CONFLICT=true
    fi
  done
done

if $CONFLICT; then
  read -rp "Continue with conflicting ports? [y/N]: " confirm
  if [[ "$confirm" != [yY] ]]; then
    err "Aborted. Choose different ports."
    exit 1
  fi
fi

# --- Derive name variants ---
# andy-my-service -> various forms
SERVICE_KEBAB="$SERVICE_NAME"                                                    # andy-my-service
SERVICE_SNAKE=$(echo "$SERVICE_NAME" | tr '-' '_')                               # andy_my_service

# Convert kebab-case to PascalCase (macOS compatible - no \b or \u)
to_pascal() {
  echo "$1" | tr '-' '\n' | while read -r word; do
    first=$(echo "${word:0:1}" | tr '[:lower:]' '[:upper:]')
    rest="${word:1}"
    printf '%s' "${first}${rest}"
  done
  echo
}

# Get the part after "andy-" and PascalCase it
SERVICE_PARTS_RAW=$(echo "$SERVICE_NAME" | sed 's/^andy-//')
SERVICE_PARTS=$(to_pascal "$SERVICE_PARTS_RAW")
SERVICE_PASCAL="Andy.${SERVICE_PARTS}"                                           # Andy.HwBridge
SERVICE_PASCAL_NOPUNCT=$(echo "$SERVICE_PASCAL" | tr -d '.')                     # AndyHwBridge
SERVICE_DISPLAY="Andy ${SERVICE_PARTS}"                                          # Andy HwBridge

echo ""
info "Service configuration:"
echo "  Name:        $SERVICE_NAME"
echo "  Pascal:      $SERVICE_PASCAL"
echo "  Display:     $SERVICE_DISPLAY"
echo "  Description: $SERVICE_DESCRIPTION"
echo "  Target:      $TARGET_DIR"
echo "  Ports:       HTTPS=$PORT_HTTPS  HTTP=$PORT_HTTP  PG=$PORT_PG  Client=$PORT_CLIENT"
echo ""

read -rp "Proceed? [Y/n]: " confirm
if [[ "$confirm" == [nN] ]]; then
  echo "Aborted."
  exit 0
fi

# --- Check target directory ---
if [[ -d "$TARGET_DIR" ]]; then
  err "Target directory already exists: $TARGET_DIR"
  read -rp "Overwrite? [y/N]: " confirm
  if [[ "$confirm" != [yY] ]]; then
    exit 1
  fi
  rm -rf "$TARGET_DIR"
fi

# --- Copy template ---
info "Copying template to $TARGET_DIR..."
cp -r "$TEMPLATE_DIR" "$TARGET_DIR"

# --- Generate GUIDs for .sln ---
info "Generating project GUIDs..."
gen_guid() {
  python3 -c "import uuid; print(str(uuid.uuid4()).upper())" 2>/dev/null || \
    uuidgen 2>/dev/null | tr '[:lower:]' '[:upper:]' || \
    cat /proc/sys/kernel/random/uuid 2>/dev/null | tr '[:lower:]' '[:upper:]' || \
    echo "$(date +%s)-$(od -An -tx4 -N16 /dev/urandom | tr -d ' \n')" | cut -c1-36
}

GUID_SRC=$(gen_guid)
GUID_DOMAIN=$(gen_guid)
GUID_APPLICATION=$(gen_guid)
GUID_INFRASTRUCTURE=$(gen_guid)
GUID_API=$(gen_guid)
GUID_SHARED=$(gen_guid)
GUID_TOOLS=$(gen_guid)
GUID_CLI=$(gen_guid)
GUID_TESTS=$(gen_guid)
GUID_TESTS_UNIT=$(gen_guid)
GUID_TESTS_INTEGRATION=$(gen_guid)

# --- Replace placeholders in all files ---
info "Replacing placeholders..."

# Build sed expression
SED_ARGS=(
  -e "s|__SERVICE_NAME__|${SERVICE_NAME}|g"
  -e "s|__SERVICE_KEBAB__|${SERVICE_KEBAB}|g"
  -e "s|__SERVICE_SNAKE__|${SERVICE_SNAKE}|g"
  -e "s|__SERVICE_PASCAL__|${SERVICE_PASCAL}|g"
  -e "s|__SERVICE_PASCAL_NOPUNCT__|${SERVICE_PASCAL_NOPUNCT}|g"
  -e "s|__SERVICE_DISPLAY__|${SERVICE_DISPLAY}|g"
  -e "s|__SERVICE_DESCRIPTION__|${SERVICE_DESCRIPTION}|g"
  -e "s|__PORT_HTTPS__|${PORT_HTTPS}|g"
  -e "s|__PORT_HTTP__|${PORT_HTTP}|g"
  -e "s|__PORT_PG__|${PORT_PG}|g"
  -e "s|__PORT_CLIENT__|${PORT_CLIENT}|g"
  -e "s|__GUID_SRC__|${GUID_SRC}|g"
  -e "s|__GUID_DOMAIN__|${GUID_DOMAIN}|g"
  -e "s|__GUID_APPLICATION__|${GUID_APPLICATION}|g"
  -e "s|__GUID_INFRASTRUCTURE__|${GUID_INFRASTRUCTURE}|g"
  -e "s|__GUID_API__|${GUID_API}|g"
  -e "s|__GUID_SHARED__|${GUID_SHARED}|g"
  -e "s|__GUID_TOOLS__|${GUID_TOOLS}|g"
  -e "s|__GUID_CLI__|${GUID_CLI}|g"
  -e "s|__GUID_TESTS__|${GUID_TESTS}|g"
  -e "s|__GUID_TESTS_UNIT__|${GUID_TESTS_UNIT}|g"
  -e "s|__GUID_TESTS_INTEGRATION__|${GUID_TESTS_INTEGRATION}|g"
)

# Process all text files
find "$TARGET_DIR" -type f \( \
  -name "*.cs" -o -name "*.csproj" -o -name "*.sln" -o -name "*.json" -o \
  -name "*.yml" -o -name "*.yaml" -o -name "*.md" -o -name "*.ts" -o \
  -name "*.html" -o -name "*.scss" -o -name "*.css" -o -name "*.sql" -o \
  -name "*.proto" -o -name "*.conf" -o -name "*.toml" -o -name "*.rs" -o \
  -name "*.go" -o -name "*.java" -o -name "*.py" -o -name "*.mjs" -o \
  -name "*.ps1" -o -name "*.sh" -o -name "*.props" -o -name "*.config" -o \
  -name "Dockerfile" -o -name ".gitignore" \
  \) -not -path "*/.git/*" -not -path "*/node_modules/*" | while read -r file; do
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "${SED_ARGS[@]}" "$file"
  else
    sed -i "${SED_ARGS[@]}" "$file"
  fi
done

# --- Rename directories and files containing __SERVICE_PASCAL__ ---
info "Renaming directories and files..."

# Rename directories (deepest first to avoid breaking paths)
find "$TARGET_DIR" -depth -type d -name "*__SERVICE_PASCAL__*" | while read -r dir; do
  newdir=$(echo "$dir" | sed "s|__SERVICE_PASCAL__|${SERVICE_PASCAL}|g")
  mv "$dir" "$newdir"
done

# Rename files
find "$TARGET_DIR" -type f -name "*__SERVICE_PASCAL__*" | while read -r file; do
  newfile=$(echo "$file" | sed "s|__SERVICE_PASCAL__|${SERVICE_PASCAL}|g")
  mv "$file" "$newfile"
done

# --- Copy LICENSE from template repo ---
if [[ -f "$SCRIPT_DIR/LICENSE" ]]; then
  cp "$SCRIPT_DIR/LICENSE" "$TARGET_DIR/LICENSE"
fi

# --- Initialize git ---
if $INIT_GIT; then
  info "Initializing git repository..."
  cd "$TARGET_DIR"
  git init -q
  git add -A
  git commit -q -m "Initial commit from andy-service-template"
  cd "$SCRIPT_DIR"
fi

# --- Done ---
echo ""
ok "Service '$SERVICE_NAME' created at $TARGET_DIR"
echo ""
info "Next steps:"
echo "  1. cd $TARGET_DIR"
echo "  2. dotnet restore && dotnet build"
echo "  3. cd client && npm install"
echo "  4. Register OAuth client in Andy Auth (see config/auth-seed.sql)"
echo "  5. Register RBAC application in Andy RBAC (see config/rbac-seed.json)"
echo "  6. docker compose up -d postgres"
echo "  7. dotnet run --project src/${SERVICE_PASCAL}.Api"
echo ""
info "Port registry for this service:"
echo "  API HTTPS:   $PORT_HTTPS"
echo "  API HTTP:    $PORT_HTTP"
echo "  PostgreSQL:  $PORT_PG"
echo "  Client:      $PORT_CLIENT"
