#!/usr/bin/env bash
# Copyright (c) Rivoli AI 2026. All rights reserved.
# Licensed under the Apache License, Version 2.0.
#
# register-service.sh — one-shot bridge to seed a running andy-auth /
# andy-rbac / andy-settings stack from a single config/registration.json
# manifest. Complements the refactored seeders (which read manifests at
# service startup) for cases where:
#
#   - a service was deployed after its target platform service started
#     (cloud envs where restarts are expensive)
#   - a consumer needs to preview the SQL that will be emitted (--dry-run)
#   - cron / CI needs to reconcile manifests against a shared cluster
#
# Tracks rivoli-ai/andy-service-template#3.
#
# Usage:
#   ./register-service.sh --manifest <path> --target <auth|rbac|settings|all>
#                         --mode <pg|sqlite> [--dry-run] [--apply]
#
# Environment variables (connection strings / file paths):
#   AUTH_PG_URL         — "host=localhost port=7435 dbname=andy_auth_dev user=postgres password=postgres"
#   RBAC_PG_URL         — same shape for andy-rbac's pg
#   SETTINGS_PG_URL     — same for andy-settings
#   AUTH_SQLITE_PATH    — /path/to/andy_auth.db (Conductor embedded)
#   RBAC_SQLITE_PATH    — /path/to/andy_rbac.db
#   SETTINGS_SQLITE_PATH— /path/to/andy_settings.db
#
# Requirements:
#   - jq (JSON parsing)
#   - psql (for --mode pg) and/or sqlite3 (for --mode sqlite)
#
# Known limitations:
#   1. Confidential OAuth clients (auth.apiClient) are SKIPPED: they need
#      PBKDF2-HMAC-SHA256 hashing per ASP.NET Core Identity's
#      PasswordHasher<> format, which this script can't replicate without
#      shelling out to .NET. Use the service-restart path for those —
#      andy-auth picks them up from the manifest directly.
#   2. Idempotent by existence-check on primary key columns (scope name,
#      client_id, app code, role code, setting key). Does NOT detect a
#      manifest edit of an already-seeded row — recreate by deleting first.
#   3. Public clients: Permissions JSON is built assuming standard
#      OpenIddict semantics. If the manifest declares unusual grant types
#      the mapping may need extension.

set -eo pipefail

# --- Color output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

MANIFEST=""
TARGET=""
MODE=""
DRY_RUN=true

while [[ $# -gt 0 ]]; do
  case $1 in
    --manifest) MANIFEST="$2"; shift 2 ;;
    --target)   TARGET="$2";   shift 2 ;;
    --mode)     MODE="$2";     shift 2 ;;
    --dry-run)  DRY_RUN=true;  shift ;;
    --apply)    DRY_RUN=false; shift ;;
    --help|-h)
      sed -n '2,45p' "$0"
      exit 0
      ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

[[ -z "$MANIFEST" ]] && { err "--manifest required"; exit 1; }
[[ -z "$TARGET" ]]   && { err "--target required (auth|rbac|settings|all)"; exit 1; }
[[ -z "$MODE" ]]     && { err "--mode required (pg|sqlite)"; exit 1; }
[[ ! -f "$MANIFEST" ]] && { err "Manifest not found: $MANIFEST"; exit 1; }

command -v jq >/dev/null || { err "jq required"; exit 1; }
if [[ "$MODE" == "pg" ]] && ! command -v psql >/dev/null; then
  err "psql required for --mode pg"; exit 1
fi
if [[ "$MODE" == "sqlite" ]] && ! command -v sqlite3 >/dev/null; then
  err "sqlite3 required for --mode sqlite"; exit 1
fi

SERVICE_NAME=$(jq -r '.service.name' "$MANIFEST")
SERVICE_DISPLAY=$(jq -r '.service.displayName' "$MANIFEST")
info "Manifest: $MANIFEST  (service: $SERVICE_NAME)"
info "Target: $TARGET  Mode: $MODE  Dry-run: $DRY_RUN"

# --- SQL quoting helpers ---
# Postgres quoted identifiers: "Name"; SQLite lowercase snake_case.
# Every statement we emit uses ANSI-standard single-quote string quoting
# (doubled single quotes for escaping), which works in both dialects.
sql_escape() { printf '%s' "$1" | sed "s/'/''/g"; }

# --- AUTH: scope insert ---
auth_insert_scope() {
  local name="$1" display="$2"
  local name_esc display_esc
  name_esc=$(sql_escape "$name")
  display_esc=$(sql_escape "$display")

  if [[ "$MODE" == "pg" ]]; then
    cat <<EOF
INSERT INTO "OpenIddictScopes" ("Id", "Name", "DisplayName", "Resources", "ConcurrencyToken")
SELECT gen_random_uuid()::text, '$name_esc', '$display_esc', '["$name_esc"]', gen_random_uuid()::text
WHERE NOT EXISTS (SELECT 1 FROM "OpenIddictScopes" WHERE "Name" = '$name_esc');
EOF
  else
    cat <<EOF
INSERT OR IGNORE INTO OpenIddictScopes (Id, Name, DisplayName, Resources, ConcurrencyToken)
VALUES (lower(hex(randomblob(16))), '$name_esc', '$display_esc', '["$name_esc"]', lower(hex(randomblob(16))));
EOF
  fi
}

# --- AUTH: build Permissions JSON for a public client ---
auth_permissions_json() {
  local grants_json="$1"   # ["authorization_code","refresh_token"]
  local scopes_json="$2"   # ["email","profile","roles","scp:urn:andy-xxx-api"]
  local items=("ept:token")

  jq -e 'index("authorization_code")' <<<"$grants_json" >/dev/null 2>&1 \
    && items+=("ept:authorization" "gt:authorization_code" "rst:code")
  jq -e 'index("refresh_token")' <<<"$grants_json" >/dev/null 2>&1 \
    && items+=("gt:refresh_token")
  jq -e 'index("client_credentials")' <<<"$grants_json" >/dev/null 2>&1 \
    && items+=("gt:client_credentials")
  jq -e 'index("device_code")' <<<"$grants_json" >/dev/null 2>&1 \
    && items+=("gt:device_code" "ept:device_authorization")

  # Map scopes: "email"/"profile"/"roles" get "scp:" prefix; "scp:..." passed as-is.
  while IFS= read -r scope; do
    case "$scope" in
      scp:*)         items+=("$scope") ;;
      email|profile|roles) items+=("scp:$scope") ;;
      offline_access)      items+=("scp:offline_access") ;;
      *)                   items+=("scp:$scope") ;;
    esac
  done < <(jq -r '.[]' <<<"$scopes_json")

  # JSON-encode via jq
  printf '%s\n' "${items[@]}" | jq -R . | jq -cs .
}

auth_insert_public_client() {
  local client_json="$1"
  local cid display grants scopes redir post
  cid=$(jq -r '.clientId' <<<"$client_json")
  display=$(jq -r '.displayName' <<<"$client_json")
  grants=$(jq -c '.grantTypes // []' <<<"$client_json")
  scopes=$(jq -c '.scopes // []' <<<"$client_json")
  redir=$(jq -c '.redirectUris // []' <<<"$client_json")
  post=$(jq -c '.postLogoutRedirectUris // []' <<<"$client_json")

  local perms
  perms=$(auth_permissions_json "$grants" "$scopes")
  local cid_esc display_esc perms_esc redir_esc post_esc
  cid_esc=$(sql_escape "$cid")
  display_esc=$(sql_escape "$display")
  perms_esc=$(sql_escape "$perms")
  redir_esc=$(sql_escape "$redir")
  post_esc=$(sql_escape "$post")

  if [[ "$MODE" == "pg" ]]; then
    cat <<EOF
INSERT INTO "OpenIddictApplications" ("Id", "ClientId", "ClientType", "ConsentType", "DisplayName", "Permissions", "RedirectUris", "PostLogoutRedirectUris", "ConcurrencyToken")
SELECT gen_random_uuid()::text, '$cid_esc', 'public', 'implicit', '$display_esc', '$perms_esc', '$redir_esc', '$post_esc', gen_random_uuid()::text
WHERE NOT EXISTS (SELECT 1 FROM "OpenIddictApplications" WHERE "ClientId" = '$cid_esc');
EOF
  else
    cat <<EOF
INSERT OR IGNORE INTO OpenIddictApplications (Id, ClientId, ClientType, ConsentType, DisplayName, Permissions, RedirectUris, PostLogoutRedirectUris, ConcurrencyToken)
VALUES (lower(hex(randomblob(16))), '$cid_esc', 'public', 'implicit', '$display_esc', '$perms_esc', '$redir_esc', '$post_esc', lower(hex(randomblob(16))));
EOF
  fi
}

# --- AUTH: full SQL ---
generate_auth_sql() {
  local audience display
  audience=$(jq -r '.auth.audience // empty' "$MANIFEST")
  display=$(jq -r '.service.displayName' "$MANIFEST")

  [[ -n "$audience" ]] && auth_insert_scope "$audience" "$display API"

  # Public clients: webClient, cliClient (skip apiClient)
  for section in webClient cliClient; do
    local client
    client=$(jq -c ".auth.$section // empty" "$MANIFEST")
    if [[ -n "$client" && "$client" != "null" ]]; then
      local type
      type=$(jq -r '.clientType // "public"' <<<"$client")
      if [[ "$type" == "confidential" ]]; then
        warn "Skipping confidential client $(jq -r .clientId <<<"$client") — needs PBKDF2 hashing (use service-restart path)."
        continue
      fi
      auth_insert_public_client "$client"
    fi
  done

  # Warn if apiClient present — skipped.
  if [[ $(jq -r '.auth.apiClient // empty' "$MANIFEST") != "" ]]; then
    warn "Skipping confidential apiClient $(jq -r '.auth.apiClient.clientId' "$MANIFEST") — use service-restart path."
  fi
}

# --- RBAC: app + resource types + roles ---
generate_rbac_sql() {
  local code name desc
  code=$(jq -r '.rbac.applicationCode // empty' "$MANIFEST")
  [[ -z "$code" ]] && { info "Manifest has no rbac section"; return; }
  name=$(jq -r '.rbac.applicationName' "$MANIFEST")
  desc=$(jq -r '.rbac.description // .service.description' "$MANIFEST")

  local code_esc name_esc desc_esc
  code_esc=$(sql_escape "$code")
  name_esc=$(sql_escape "$name")
  desc_esc=$(sql_escape "$desc")

  if [[ "$MODE" == "pg" ]]; then
    cat <<EOF
INSERT INTO applications ("Id", "Code", "Name", "Description", "CreatedAt")
SELECT gen_random_uuid(), '$code_esc', '$name_esc', '$desc_esc', NOW() AT TIME ZONE 'UTC'
WHERE NOT EXISTS (SELECT 1 FROM applications WHERE "Code" = '$code_esc');
EOF
  else
    cat <<EOF
INSERT OR IGNORE INTO applications (Id, Code, Name, Description, CreatedAt)
VALUES (lower(hex(randomblob(16))), '$code_esc', '$name_esc', '$desc_esc', CURRENT_TIMESTAMP);
EOF
  fi

  # Resource types
  jq -c '.rbac.resourceTypes // [] | .[]' "$MANIFEST" | while IFS= read -r rt; do
    local rcode rname rsup
    rcode=$(jq -r '.code' <<<"$rt")
    rname=$(jq -r '.name' <<<"$rt")
    rsup=$(jq -r '.supportsInstances // false' <<<"$rt")
    local rcode_esc rname_esc
    rcode_esc=$(sql_escape "$rcode")
    rname_esc=$(sql_escape "$rname")
    local sup_val="0"
    [[ "$rsup" == "true" ]] && sup_val="1"
    [[ "$MODE" == "pg" ]] && sup_val=$([[ "$rsup" == "true" ]] && echo TRUE || echo FALSE)

    if [[ "$MODE" == "pg" ]]; then
      cat <<EOF
INSERT INTO resource_types ("Id", "ApplicationId", "Code", "Name", "SupportsInstances", "CreatedAt")
SELECT gen_random_uuid(), a."Id", '$rcode_esc', '$rname_esc', $sup_val, NOW() AT TIME ZONE 'UTC'
FROM applications a
WHERE a."Code" = '$code_esc'
  AND NOT EXISTS (SELECT 1 FROM resource_types rt WHERE rt."ApplicationId" = a."Id" AND rt."Code" = '$rcode_esc');
EOF
    else
      cat <<EOF
INSERT OR IGNORE INTO resource_types (Id, ApplicationId, Code, Name, SupportsInstances, CreatedAt)
SELECT lower(hex(randomblob(16))), a.Id, '$rcode_esc', '$rname_esc', $sup_val, CURRENT_TIMESTAMP
FROM applications a WHERE a.Code = '$code_esc';
EOF
    fi
  done

  # Roles
  jq -c '.rbac.roles // [] | .[]' "$MANIFEST" | while IFS= read -r role; do
    local rcode rname rdesc risys
    rcode=$(jq -r '.code' <<<"$role")
    rname=$(jq -r '.name' <<<"$role")
    rdesc=$(jq -r '.description // ""' <<<"$role")
    risys=$(jq -r '.isSystem // true' <<<"$role")
    local rcode_esc rname_esc rdesc_esc
    rcode_esc=$(sql_escape "$rcode")
    rname_esc=$(sql_escape "$rname")
    rdesc_esc=$(sql_escape "$rdesc")
    local sys_val="0"
    [[ "$risys" == "true" ]] && sys_val="1"
    [[ "$MODE" == "pg" ]] && sys_val=$([[ "$risys" == "true" ]] && echo TRUE || echo FALSE)

    if [[ "$MODE" == "pg" ]]; then
      cat <<EOF
INSERT INTO roles ("Id", "ApplicationId", "Code", "Name", "Description", "IsSystem", "CreatedAt")
SELECT gen_random_uuid(), a."Id", '$rcode_esc', '$rname_esc', '$rdesc_esc', $sys_val, NOW() AT TIME ZONE 'UTC'
FROM applications a
WHERE a."Code" = '$code_esc'
  AND NOT EXISTS (SELECT 1 FROM roles r WHERE r."ApplicationId" = a."Id" AND r."Code" = '$rcode_esc');
EOF
    else
      cat <<EOF
INSERT OR IGNORE INTO roles (Id, ApplicationId, Code, Name, Description, IsSystem, CreatedAt)
SELECT lower(hex(randomblob(16))), a.Id, '$rcode_esc', '$rname_esc', '$rdesc_esc', $sys_val, CURRENT_TIMESTAMP
FROM applications a WHERE a.Code = '$code_esc';
EOF
    fi
  done
}

# --- SETTINGS: setting definitions ---
generate_settings_sql() {
  local app_code
  app_code=$(jq -r '.service.name' "$MANIFEST")
  jq -c '.settings.definitions // [] | .[]' "$MANIFEST" | while IFS= read -r def; do
    local key display desc cat dtype dv secret scopes
    key=$(jq -r '.key' <<<"$def")
    display=$(jq -r '.displayName // .key' <<<"$def")
    desc=$(jq -r '.description // ""' <<<"$def")
    cat=$(jq -r '.category // ""' <<<"$def")
    dtype=$(jq -r '.dataType' <<<"$def")
    dv=$(jq -cr '.defaultValue // empty' <<<"$def")
    secret=$(jq -r '.isSecret // false' <<<"$def")
    scopes=$(jq -cr '.allowedScopes // ["Machine","Application","User"]' <<<"$def")

    local key_esc display_esc desc_esc cat_esc dv_esc scopes_esc
    key_esc=$(sql_escape "$key")
    display_esc=$(sql_escape "$display")
    desc_esc=$(sql_escape "$desc")
    cat_esc=$(sql_escape "$cat")
    dv_esc=$(sql_escape "$dv")
    scopes_esc=$(sql_escape "$scopes")
    local secret_val="0"
    [[ "$secret" == "true" ]] && secret_val="1"
    [[ "$MODE" == "pg" ]] && secret_val=$([[ "$secret" == "true" ]] && echo TRUE || echo FALSE)

    if [[ "$MODE" == "pg" ]]; then
      cat <<EOF
INSERT INTO "SettingDefinitions" ("Id", "Key", "ApplicationCode", "DisplayName", "Description", "Category", "DataType", "DefaultValueJson", "IsSecret", "AllowedScopesJson", "CreatedAt", "UpdatedAt")
VALUES (gen_random_uuid(), '$key_esc', '$app_code', '$display_esc', '$desc_esc', '$cat_esc', '$dtype', NULLIF('$dv_esc', ''), $secret_val, '$scopes_esc', NOW() AT TIME ZONE 'UTC', NOW() AT TIME ZONE 'UTC')
ON CONFLICT ("Key") DO NOTHING;
EOF
    else
      cat <<EOF
INSERT OR IGNORE INTO SettingDefinitions (Id, Key, ApplicationCode, DisplayName, Description, Category, DataType, DefaultValueJson, IsSecret, AllowedScopesJson, CreatedAt, UpdatedAt)
VALUES (lower(hex(randomblob(16))), '$key_esc', '$app_code', '$display_esc', '$desc_esc', '$cat_esc', '$dtype', NULLIF('$dv_esc', ''), $secret_val, '$scopes_esc', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
EOF
    fi
  done
}

# --- Apply runners ---
apply_pg() {
  local target="$1" sql="$2"
  local url_var="${target^^}_PG_URL"  # AUTH_PG_URL etc.
  local url="${!url_var:-}"
  if [[ -z "$url" ]]; then
    warn "$url_var not set; printing SQL instead of applying."
    echo "$sql"
    return
  fi
  info "Applying to $target via psql ($url_var)"
  echo "$sql" | psql "$url"
}

apply_sqlite() {
  local target="$1" sql="$2"
  local path_var="${target^^}_SQLITE_PATH"
  local path="${!path_var:-}"
  if [[ -z "$path" ]]; then
    warn "$path_var not set; printing SQL instead of applying."
    echo "$sql"
    return
  fi
  info "Applying to $target via sqlite3 ($path)"
  echo "$sql" | sqlite3 "$path"
}

run_one() {
  local target="$1"
  local sql=""
  case "$target" in
    auth)     sql=$(generate_auth_sql) ;;
    rbac)     sql=$(generate_rbac_sql) ;;
    settings) sql=$(generate_settings_sql) ;;
    *) err "Unknown target: $target"; exit 1 ;;
  esac

  if [[ -z "$sql" ]]; then
    info "No SQL generated for target=$target (manifest has nothing relevant)"
    return
  fi

  if $DRY_RUN; then
    echo "-- === Target: $target (Mode: $MODE) ==="
    echo "$sql"
    echo
    return
  fi

  case "$MODE" in
    pg)     apply_pg "$target" "$sql" ;;
    sqlite) apply_sqlite "$target" "$sql" ;;
  esac
}

TARGETS=()
if [[ "$TARGET" == "all" ]]; then
  TARGETS=(auth rbac settings)
else
  TARGETS=("$TARGET")
fi

for t in "${TARGETS[@]}"; do
  run_one "$t"
done

ok "register-service.sh complete"
