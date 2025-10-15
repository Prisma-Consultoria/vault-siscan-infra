#!/usr/bin/env bash
# Gera e aplica políticas a partir de templates para um profissional específico.
# Uso:
#   ENV=prd ID_PROF=diego.123 VAULT_ADDR=https://vault.exemplo VAULT_TOKEN=<admin> ./scripts/generate_policy_for_prof.sh
set -euo pipefail

: "${ENV:?Definir ENV (dev|hml|prd)}"
: "${ID_PROF:?Definir ID_PROF (ex.: diego.123)}"
: "${VAULT_ADDR:?Definir VAULT_ADDR}"
: "${VAULT_TOKEN:?Definir VAULT_TOKEN}"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tmpl_prof="${BASE_DIR}/infra/vault/policies/policy-profissional-template.hcl"
tmpl_rpa="${BASE_DIR}/infra/vault/policies/policy-rpa-read-template.hcl"

[[ -f "$tmpl_prof" && -f "$tmpl_rpa" ]] || { echo "Templates não encontrados."; exit 1; }

# Substituir placeholders
tmp_prof="$(mktemp)"; tmp_rpa="$(mktemp)"
sed -e "s|<ENV>|${ENV}|g" -e "s|<ID_PROF>|${ID_PROF}|g" "$tmpl_prof" > "$tmp_prof"
sed -e "s|<ENV>|${ENV}|g" -e "s|<ID_PROF>|${ID_PROF}|g" "$tmpl_rpa"  > "$tmp_rpa"

# Nomes de políticas
POL_PROF="prof-${ENV}-${ID_PROF}"
POL_RPA="rpa-read-${ENV}-${ID_PROF}"

vault policy write "${POL_PROF}" "$tmp_prof"
vault policy write "${POL_RPA}" "$tmp_rpa"

rm -f "$tmp_prof" "$tmp_rpa"

echo "Políticas criadas/atualizadas:"
echo " - ${POL_PROF} (profissional)"
echo " - ${POL_RPA}  (RPA leitura estrita)"
