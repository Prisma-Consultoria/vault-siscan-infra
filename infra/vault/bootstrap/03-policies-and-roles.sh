#!/usr/bin/env bash
set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR não definido}"
: "${VAULT_TOKEN:?VAULT_TOKEN não definido}"

# Políticas base (cópias dos templates em infra/vault/policies)
vault policy write operator infra/vault/policies/policy-operator.hcl

# Observação: políticas por profissional devem ser geradas a partir de templates
# (substituindo <ENV> e <ID_PROF>) e aplicadas no onboarding automatizado.

echo "Política 'operator' aplicada."
echo "Criando roles AppRole padrão para o RPA (por ambiente)..."

for ENV in dev hml prd; do
  ROLE="svc-rpa-siscan-${ENV}"
  vault write auth/approle/role/${ROLE} \
    token_ttl=20m \
    token_max_ttl=1h \
    secret_id_num_uses=1 \
    secret_id_ttl=15m \
    token_num_uses=0 \
    token_policies="default" 2>/dev/null || true
  echo "AppRole criado/atualizado: ${ROLE}"
done
