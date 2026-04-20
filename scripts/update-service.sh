#!/usr/bin/env bash
# Copyright (c) Rivoli AI 2026. All rights reserved.
# Compare an existing Andy service against the latest template and generate an update report.
#
# This script:
# 1. Generates a fresh template with the same service name/ports
# 2. Diffs the fresh template against the existing service
# 3. Produces a report of what needs updating
# 4. Optionally applies safe updates (CI/CD, docs structure)
#
# Usage:
#   ./scripts/update-service.sh /path/to/andy-my-service [--apply]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

TARGET="${1:-}"
APPLY=false
[[ "${2:-}" == "--apply" ]] && APPLY=true

if [[ -z "$TARGET" || ! -d "$TARGET" ]]; then
  echo "Usage: $0 /path/to/andy-service [--apply]"
  echo ""
  echo "  --apply   Apply safe updates (CI/CD workflows, docs structure)"
  exit 1
fi

SERVICE_NAME=$(basename "$TARGET")
TEMP_DIR=$(mktemp -d)
TEMP_SERVICE="$TEMP_DIR/$SERVICE_NAME"

echo "Update Assistant for: $SERVICE_NAME"
echo "Target: $TARGET"
echo ""

# --- Extract current configuration ---
echo "Detecting current configuration..."

# Try to extract ports from docker-compose
PORT_HTTPS=5400
PORT_HTTP=5401
PORT_PG=5442
PORT_CLIENT=4202

if [[ -f "$TARGET/docker-compose.yml" ]]; then
  extracted=$(grep -E '^\s+- "[0-9]+:8443"' "$TARGET/docker-compose.yml" | head -1 | grep -oE '[0-9]+:' | tr -d ':')
  [[ -n "$extracted" ]] && PORT_HTTPS="$extracted"

  extracted=$(grep -E '^\s+- "[0-9]+:8080"' "$TARGET/docker-compose.yml" | head -1 | grep -oE '[0-9]+:' | tr -d ':')
  [[ -n "$extracted" ]] && PORT_HTTP="$extracted"

  extracted=$(grep -E '^\s+- "[0-9]+:5432"' "$TARGET/docker-compose.yml" | head -1 | grep -oE '[0-9]+:' | tr -d ':')
  [[ -n "$extracted" ]] && PORT_PG="$extracted"
fi

# Try to extract description from README
DESCRIPTION="Andy ecosystem microservice"
if [[ -f "$TARGET/README.md" ]]; then
  desc=$(head -5 "$TARGET/README.md" | tail -1)
  [[ -n "$desc" ]] && DESCRIPTION="$desc"
fi

echo "  Detected ports: HTTPS=$PORT_HTTPS HTTP=$PORT_HTTP PG=$PORT_PG Client=$PORT_CLIENT"
echo ""

# --- Generate fresh template ---
echo "Generating fresh template for comparison..."
"$ROOT_DIR/create-service.sh" \
  --name "$SERVICE_NAME" \
  --description "$DESCRIPTION" \
  --target "$TEMP_SERVICE" \
  --port-https "$PORT_HTTPS" \
  --port-http "$PORT_HTTP" \
  --port-pg "$PORT_PG" \
  --port-client "$PORT_CLIENT" \
  --no-git <<< "Y" > /dev/null 2>&1

echo ""
echo "=== Update Report ==="
echo ""

# --- Compare key files ---
UPDATES=0

check_file() {
  local rel_path="$1"
  local category="$2"
  local safe="$3"  # "safe" = can be auto-applied, "review" = needs manual review

  if [[ ! -f "$TEMP_SERVICE/$rel_path" ]]; then
    return
  fi

  if [[ ! -f "$TARGET/$rel_path" ]]; then
    echo "  [MISSING] $rel_path ($category)"
    UPDATES=$((UPDATES + 1))
    if $APPLY && [[ "$safe" == "safe" ]]; then
      mkdir -p "$(dirname "$TARGET/$rel_path")"
      cp "$TEMP_SERVICE/$rel_path" "$TARGET/$rel_path"
      echo "           -> Applied: copied from template"
    fi
  elif ! diff -q "$TARGET/$rel_path" "$TEMP_SERVICE/$rel_path" > /dev/null 2>&1; then
    echo "  [DIFFERS] $rel_path ($category)"
    UPDATES=$((UPDATES + 1))
  fi
}

echo "--- CI/CD ---"
check_file ".github/workflows/ci.yml" "CI/CD" "safe"
check_file ".github/workflows/docs.yml" "CI/CD" "safe"
check_file ".github/workflows/docker.yml" "CI/CD" "safe"

echo ""
echo "--- Infrastructure ---"
check_file "Dockerfile" "Docker" "review"
check_file "docker-compose.yml" "Docker" "review"
check_file "docker-compose.embedded.yml" "Docker" "safe"
check_file "Directory.Build.props" "Build" "review"
check_file "nuget.config" "Build" "safe"

echo ""
echo "--- Documentation ---"
check_file "docs/index.md" "Docs" "safe"
check_file "docs/features.md" "Docs" "safe"
check_file "docs/architecture.md" "Docs" "safe"
check_file "docs/implementation.md" "Docs" "safe"
check_file "docs/testing.md" "Docs" "safe"
check_file "docs/deployment.md" "Docs" "safe"
check_file "docs/security.md" "Docs" "safe"
check_file "mkdocs.yml" "Docs" "safe"

echo ""
echo "--- Structure ---"
check_file "certs/.gitkeep" "Certs" "safe"
check_file "certs/README.md" "Certs" "safe"
check_file "config/registration.json" "Registration" "safe"

echo ""
echo "--- Compliance Check ---"
"$SCRIPT_DIR/check-compliance.sh" "$TARGET" 2>/dev/null || true

echo ""
echo "================================================"
echo "Total differences from template: $UPDATES"
if $APPLY; then
  echo "Safe updates have been applied. Review changes with 'git diff'."
fi

# Cleanup
rm -rf "$TEMP_DIR"
