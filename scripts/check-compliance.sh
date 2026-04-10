#!/usr/bin/env bash
# Copyright (c) Rivoli AI 2026. All rights reserved.
# Check an existing Andy service's compliance with the template standard.
#
# Usage:
#   ./scripts/check-compliance.sh /path/to/andy-my-service

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}PASS${NC} $*"; }
fail() { echo -e "  ${RED}FAIL${NC} $*"; FAILURES=$((FAILURES + 1)); }
warn() { echo -e "  ${YELLOW}WARN${NC} $*"; WARNINGS=$((WARNINGS + 1)); }

TARGET="${1:-}"
if [[ -z "$TARGET" || ! -d "$TARGET" ]]; then
  echo "Usage: $0 /path/to/andy-service"
  exit 1
fi

SERVICE_NAME=$(basename "$TARGET")
FAILURES=0
WARNINGS=0

echo "Checking compliance for: $SERVICE_NAME"
echo "Directory: $TARGET"
echo ""

# --- Structure checks ---
echo "=== Project Structure ==="

[[ -f "$TARGET/Dockerfile" ]]          && pass "Dockerfile" || fail "Dockerfile missing"
[[ -f "$TARGET/docker-compose.yml" ]]  && pass "docker-compose.yml" || fail "docker-compose.yml missing"
[[ -d "$TARGET/certs" ]]               && pass "certs/ directory" || fail "certs/ directory missing"
[[ -f "$TARGET/Directory.Build.props" ]] && pass "Directory.Build.props" || fail "Directory.Build.props missing"
[[ -f "$TARGET/nuget.config" ]]        && pass "nuget.config" || fail "nuget.config missing"
[[ -f "$TARGET/LICENSE" ]]             && pass "LICENSE" || fail "LICENSE missing"
[[ -f "$TARGET/README.md" ]]           && pass "README.md" || fail "README.md missing"
[[ -f "$TARGET/.gitignore" ]]          && pass ".gitignore" || fail ".gitignore missing"

echo ""
echo "=== Backend (.NET) ==="

# Find .sln file
sln_count=$(find "$TARGET" -maxdepth 1 -name "*.sln" | wc -l)
[[ "$sln_count" -gt 0 ]]  && pass "Solution file (.sln)" || fail "Solution file (.sln) missing"
[[ -d "$TARGET/src" ]]    && pass "src/ directory" || fail "src/ directory missing"
[[ -d "$TARGET/tests" ]]  && pass "tests/ directory" || fail "tests/ directory missing"
[[ -d "$TARGET/tools" ]]  && pass "tools/ (CLI) directory" || warn "tools/ (CLI) directory missing"

# Check for key project layers
if [[ -d "$TARGET/src" ]]; then
  domain_count=$(find "$TARGET/src" -maxdepth 1 -name "*Domain*" -type d | wc -l)
  app_count=$(find "$TARGET/src" -maxdepth 1 -name "*Application*" -type d | wc -l)
  infra_count=$(find "$TARGET/src" -maxdepth 1 -name "*Infrastructure*" -type d | wc -l)
  api_count=$(find "$TARGET/src" -maxdepth 1 -name "*Api*" -type d | wc -l)

  [[ "$domain_count" -gt 0 ]] && pass "Domain layer" || warn "Domain layer missing"
  [[ "$app_count" -gt 0 ]]    && pass "Application layer" || warn "Application layer missing"
  [[ "$infra_count" -gt 0 ]]  && pass "Infrastructure layer" || warn "Infrastructure layer missing"
  [[ "$api_count" -gt 0 ]]    && pass "API layer" || fail "API layer missing"
fi

echo ""
echo "=== Frontend (Angular) ==="

[[ -d "$TARGET/client" ]]                     && pass "client/ directory" || fail "client/ directory missing"
[[ -f "$TARGET/client/angular.json" ]]        && pass "angular.json" || fail "angular.json missing (if client/ exists)"
[[ -f "$TARGET/client/package.json" ]]        && pass "package.json" || fail "package.json missing (if client/ exists)"

echo ""
echo "=== Security ==="

# Check for auth integration
if grep -rq "AndyAuth" "$TARGET/src" 2>/dev/null; then
  pass "Andy Auth integration"
else
  fail "Andy Auth integration missing"
fi

if grep -rq "Rbac" "$TARGET/src" 2>/dev/null; then
  pass "Andy RBAC integration"
else
  warn "Andy RBAC integration missing"
fi

if grep -rq "https" "$TARGET/docker-compose.yml" 2>/dev/null; then
  pass "HTTPS in docker-compose"
else
  warn "HTTPS not configured in docker-compose"
fi

echo ""
echo "=== API Protocols ==="

if grep -rq "Swagger\|Swashbuckle\|OpenApi" "$TARGET/src" 2>/dev/null; then
  pass "Swagger/OpenAPI"
else
  fail "Swagger/OpenAPI missing"
fi

if grep -rq "McpServer\|ModelContextProtocol" "$TARGET/src" 2>/dev/null; then
  pass "MCP (Model Context Protocol)"
else
  warn "MCP integration missing"
fi

if grep -rq "Grpc\|\.proto" "$TARGET/src" 2>/dev/null; then
  pass "gRPC"
else
  warn "gRPC missing"
fi

echo ""
echo "=== Observability ==="

if grep -rq "OpenTelemetry" "$TARGET/src" 2>/dev/null; then
  pass "OpenTelemetry"
else
  warn "OpenTelemetry missing"
fi

if grep -rq "health" "$TARGET/src" 2>/dev/null; then
  pass "Health check endpoint"
else
  warn "Health check endpoint missing"
fi

echo ""
echo "=== Database ==="

if grep -rq "UseNpgsql\|PostgreSql" "$TARGET/src" 2>/dev/null; then
  pass "PostgreSQL support"
else
  fail "PostgreSQL support missing"
fi

if grep -rq "UseSqlite\|Sqlite" "$TARGET/src" 2>/dev/null; then
  pass "SQLite (embedded) support"
else
  warn "SQLite (embedded) support missing"
fi

echo ""
echo "=== CI/CD ==="

[[ -d "$TARGET/.github/workflows" ]] && pass "GitHub Actions directory" || fail "GitHub Actions missing"

echo ""
echo "=== Documentation ==="

[[ -d "$TARGET/docs" ]]      && pass "docs/ directory" || warn "docs/ directory missing"
[[ -d "$TARGET/examples" ]]  && pass "examples/ directory" || warn "examples/ directory missing"

echo ""
echo "=== Ports ==="

# Extract ports from docker-compose
if [[ -f "$TARGET/docker-compose.yml" ]]; then
  echo "  Configured ports:"
  grep -E '^\s+- "[0-9]+:[0-9]+"' "$TARGET/docker-compose.yml" | sed 's/^/    /'
fi

echo ""
echo "================================================"
echo -e "Results: ${GREEN}$(($(echo "$FAILURES $WARNINGS" | awk '{print 0}') == 0 ? 1 : 1)) checks${NC}"
echo -e "  Failures: ${RED}${FAILURES}${NC}"
echo -e "  Warnings: ${YELLOW}${WARNINGS}${NC}"

if [[ $FAILURES -gt 0 ]]; then
  echo ""
  echo "Fix the failures above to meet the Andy service template standard."
  exit 1
fi
