#!/usr/bin/env bash
# Verificações básicas para evitar versionamento de segredos e artefatos sensíveis.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail=0

echo ">> Verificando presença de arquivos potencialmente sensíveis…"

# Padrões proibidos no repositório
patterns=(
  "*.key" "*.pem" "*.crt" "*.cer" "*.p12"
  "unseal*" "root_token*" "*secret_id*" "*wrap_token*"
  "raft/*" "raft-snapshots/*" "backup*" "audit.log"
)

for p in "${patterns[@]}"; do
  if git ls-files -- "$p" >/dev/null 2>&1 && [[ -n "$(git ls-files -- "$p")" ]]; then
    echo "   [ERRO] Arquivo correspondente a '$p' está versionado:"
    git ls-files -- "$p"
    fail=1
  fi
done

# Verificar .env (exceto samples)
if git ls-files -- "**/.env" "**/.env.*" | grep -v -E "(.env\.dev\.sample|.env\.hml\.sample|.env\.prd\.sample)" | grep -q .; then
  echo "   [ERRO] Arquivos .env reais foram encontrados no versionamento."
  git ls-files -- "**/.env" "**/.env.*" | grep -v -E "(.env\.dev\.sample|.env\.hml\.sample|.env\.prd\.sample)"
  fail=1
fi

if [[ $fail -eq 0 ]]; then
  echo ">> OK: não foram encontrados artefatos sensíveis versionados."
else
  echo ">> Falhas encontradas. Remover arquivos e ajustar .gitignore antes de continuar."
  exit 1
fi
