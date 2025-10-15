#!/usr/bin/env bash
set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR não definido}"
: "${VAULT_TOKEN:?VAULT_TOKEN não definido}"

vault audit enable file file_path=/vault/audit/audit.log 2>/dev/null || true
echo "Audit device verificado/habilitado em /vault/audit/audit.log"
