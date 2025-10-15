#!/usr/bin/env bash
set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR não definido}"
: "${VAULT_TOKEN:?VAULT_TOKEN não definido}"

# Auth methods
vault auth enable approle 2>/dev/null || true
vault auth enable userpass 2>/dev/null || true
# Em HML/PRD, preferir OIDC/LDAP e desabilitar userpass após migração.

# Mounts KV v2 por ambiente
for ENV in dev hml prd; do
  path="kv-siscan-${ENV}"
  vault secrets enable -path="${path}" -version=2 kv 2>/dev/null || true
  echo "KV v2 habilitado em: ${path}"
done
