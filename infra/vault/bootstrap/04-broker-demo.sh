#!/usr/bin/env bash
set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR não definido}"
: "${VAULT_TOKEN:?VAULT_TOKEN não definido}"

ENV=${1:-prd}
ID_PROF=${2:-diego.123}
KV_DATA_PATH="kv-siscan-${ENV}/data/credenciais/${ID_PROF}"
KV_META_PATH="kv-siscan-${ENV}/metadata/credenciais/${ID_PROF}"
POLICY_NAME="wrap-read-${ENV}-${ID_PROF}"

TMP_POLICY="$(mktemp)"
cat > "${TMP_POLICY}" <<POL
path "${KV_DATA_PATH}" { capabilities = ["read"] }
path "${KV_META_PATH}" { capabilities = ["read"] }
path "kv-siscan-${ENV}/data/credenciais"     { capabilities = [] }
path "kv-siscan-${ENV}/metadata/credenciais" { capabilities = [] }
POL

vault policy write "${POLICY_NAME}" "${TMP_POLICY}"
rm -f "${TMP_POLICY}"

# Token filho de vida curta
CHILD_TOKEN_JSON=$(vault token create -policy="${POLICY_NAME}" -ttl=2m -format=json)
CHILD_TOKEN=$(echo "$CHILD_TOKEN_JSON" | jq -r '.auth.client_token')

# Response wrapping (entregar ao robô apenas o wrap_token)
WRAP_JSON=$(VAULT_TOKEN="$CHILD_TOKEN" vault token create -wrap-ttl=60s -format=json)
WRAP_TOKEN=$(echo "$WRAP_JSON" | jq -r '.wrap_info.token')

echo "wrap_token: ${WRAP_TOKEN}"
echo "Uso no RPA (exemplo):"
echo 'VAULT_TOKEN=$(vault unwrap -field=token ${wrap_token})'
echo "vault kv get kv-siscan-${ENV}/credenciais/${ID_PROF}"
